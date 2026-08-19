import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/narrative_error.dart';
import '../domain/narrative_event.dart';
import '../domain/narrative_reducer.dart';
import '../domain/narrative_state.dart';
import '../domain/reducer_utils.dart';
import '../services/memory/memory_extraction_service.dart';
import '../services/memory/memory_manager.dart';
import '../services/narrative_turn_service.dart';
import '../services/parser/meph_parser.dart';
import '../services/session/child_save_store.dart';
import '../services/storage/meph_file_name.dart' as meph_file_name;
import 'contract_provider.dart';
import 'generation_coordinator.dart';
import 'generation_settings_provider.dart';
import 'llm_settings_provider.dart';
import 'streaming_coordinator.dart';

// ============================================================
// 叙事状态管理器（Notifier）
// ============================================================

/// 叙事状态管理器：管理会话状态变化。
///
/// 存档机制（母版/子版）：
///   - 母版文件（如 faust.meph）只读，永不修改
///   - 运行时的对话/状态/记忆/历史会生成子版文件（如 faust.child.meph）
///   - 若当前打开的就是子版（如 faust.child.meph），保存时直接改写原文件
///   - 存档委托 [ChildSaveStore]，提示词由 [NarrativeTurnService] 构建
///
/// 职责说明：
///   - 单轮生成管线已抽至 [NarrativeTurnService]（规则引擎 → 提示词 → LLM → 兜底），
///     本 Notifier 只负责「当前叙事会话」的状态编排（消息/历史/状态/记忆/存档）。
///   - 流式输出状态机由 [StreamingCoordinator] mixin 管理。
class NarrativeNotifier extends Notifier<NarrativeState>
    with GenerationCoordinator<NarrativeState>, StreamingCoordinator {
  /// 会话变更版本号（任何状态迁移 / 新消息发送时递增）。
  ///
  /// 用于 [regenerateMessage] 的「删除 → 存档 → 重新发送」三步间的
  /// 并发守卫：删除消息后若用户又发送了新消息（或发生其他状态迁移），
  /// 版本号变化 → 放弃重新发送，避免重生成叠在用户新对话之上造成
  /// 状态错乱（此前三步无守卫，`await _autoSaveChild()` 期间用户
  /// 输入可插入，重生成基于错误状态继续）。
  int _mutationCount = 0;

  /// 流式内容写回状态（StreamingCoordinator 钩子）。
  @override
  void applyStreamingContent(String fullContent) {
    // 已 dispose（Notifier 重建/销毁）后不再写状态——在途生成可能
    // 仍在 flush 流式缓冲，写已释放的 state 会触发断言/状态错乱
    if (isGenerationDisposed) return;
    state = state.copyWith(streamingContent: fullContent);
  }

  /// 状态迁移统一走 [narrativeReducer]
  void _dispatch(NarrativeEvent event) {
    state = narrativeReducer(state, event);
    _mutationCount++;
  }

  @override
  NarrativeState build() {
    // Notifier 重建（契约切换/Provider 失效）时清理流式定时器，避免泄漏
    ref.onDispose(() {
      disposeStreaming();
      disposeGeneration();
    });

    // 读取当前母版文件名（用于子版命名）
    final sourceName =
        ref.watch(currentContractNameProvider).value ?? defaultContractName;
    // 契约加载兜底：`contractProvider` 自身已保证始终返回成功——
    //   用户文件正常加载 / 内置模板兜底（含 notice）/
    //   空契约兜底（含 notice），因此本 Notifier 的 error 分支实际
    //   不会被触发。这里仍保留 `when` 显式处理 loading/error 作为
    //   极端防御：`ref.watch(contractProvider).value` 在 error 状态会
    //   重新抛出异常导致整个 Notifier 崩溃，因此用 `.when` 保证叙事页
    //   永不因 provider 异常而崩溃。
    final contract = ref
        .watch(contractProvider)
        .when(
          data: (c) => c,
          loading: Contract.empty,
          error: (_, _) => Contract.empty(),
        );
    return NarrativeState(
      contract: contract,
      sourceFileName: sourceName,
      currentState: contract.stateMap,
      // 继承契约自带的记忆/历史（打开子版时这些区块已包含运行时数据）
      memories: contract.memories,
      history: contract.history,
      // 从契约自带历史重建 UI 消息列表：
      // 打开子版时历史区块包含完整对话，需要在叙事界面完整还原而非空白显示。
      // 母版无历史区块 → messages 为空 → 正常显示开局场景。
      messages: historyToMessages(contract.history),
    );
  }

  /// 发送消息（用户输入 → 叙事推进）。
  /// 发送消息（用户输入 → 叙事推进）。
  ///
  /// 编排骨架与 [StageNarrativeNotifier.sendMessage] 完全一致
  /// （守卫 → beginGeneration → 复位流式 → dispatch → 生成 → 收尾），
  /// 通过 [GenerationCoordinator.runGeneration] 统一收尾（try/catch/finally）。
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    // 二次守卫：生成中禁止再次发送（UI 已禁用输入，极端连点/竞态时兜底）。
    // 复用 [GenerationCoordinator.canSend]（同步标志位 + 状态字段双保险）
    if (!canSend(isGenerating: state.isGenerating)) return;

    // 入口立即置位同步标志（在 dispatch 之前），确保并发/连点无法穿透
    beginGeneration();

    // 新一轮生成：清空流式累积器 + 复位「显示全文」标志，
    // 避免旧一轮的跳过打字机状态泄漏到新一轮（StreamingCoordinator）
    resetStreamingForNewRound();

    final trimmed = content.trim();
    _dispatch(MessageSent(trimmed));

    await runGeneration(
      userInput: trimmed,
      core: _generateCore,
      // 生成失败：重置生成状态 + 抛出错误信息，避免 UI 永久停留在"生成中"
      //（走 reducer）。错误以错误码形式暴露（provider.generation_failed），
      // 由 UI 层本地化翻译。
      onFailure: () {
        flushStreamBuffer();
        _dispatch(const GenerationFailed(narrativeErrorGenFailed));
      },
      onError: (e, st) => debugPrint('生成回复异常: $e\n$st'),
    );
  }

  /// 停止生成时 flush 流式缓冲（GenerationCoordinator 钩子）。
  @override
  void onGenerationStop() {
    flushStreamBuffer();
  }

  /// 生成 AI 回复（委托 [NarrativeTurnService]，结果写回状态）。
  ///
  /// 全局兜底：生成流程中任何未预期异常（如 Provider 加载失败、规则引擎异常）
  /// 都会在此捕获并重置生成状态，避免 UI 永久卡在"生成中"。
  Future<void> _generateCore(String userInput) async {
    // 复用全局 [NarrativeTurnService] 单例（轻量无状态，共享 HTTP 连接池）
    final service = ref.read(narrativeTurnServiceProvider);
    // 统一读取生成所需配置（配置变更后 force refresh 确保拿到最新值）
    final settings = await ref.refresh(generationSettingsProvider.future);

    final result = await service.generate(
      userInput: userInput,
      contract: state.contract,
      currentState: state.currentState,
      memories: state.memories,
      // 历史消息 = 除去最后一条（本次命运指引）的所有消息。
      // 正常流程中 [_dispatch(MessageSent)] 已先追加用户消息，故列表至少 1 条；
      // 但此处防御性处理空列表极端情况（避免未来调用顺序变更导致 take(-1) 越界）。
      priorMessages: state.messages.length > 1
          ? state.messages.take(state.messages.length - 1).toList()
          : const [],
      attachedContexts: state.attachedContexts,
      narrativeRules: settings.narrativeRules,
      config: settings.llmConfig,
      onChunk: appendStreamChunk,
      // 当前生成任务的取消信号（停止生成时触发）
      cancelSignal: generationCancelSignal,
      // 上下文窗口上限（保留最近 N 条历史消息，控制 token 消耗）
      maxHistoryMessages: settings.maxHistoryMessages,
      // 记忆注入灌窗：每轮最多带入 N 条记忆（用户可配置；null = 全部注入），
      // 超过时高权重（≥4）全部保留 + 其余按权重降序补足，
      // 防止超长记忆列表无条件灌入导致 token 膨胀
      maxMemories: settings.maxMemories,
    );

    // 流式输出结束：先 flush 缓冲中的剩余 chunk，再聚合提交
    flushStreamBuffer();

    // 聚合本轮所有变化（状态/记忆/骰子/回复/错误），一次性批量提交：
    // 状态迁移统一走 reducer（narrativeReducer），减少 Riverpod 通知与 UI 重建。
    _dispatch(
      ReplySucceeded(
        reply: result.reply,
        newState: result.newState,
        injectedMemories: result.injectedMemories,
        rollInfo: result.rollInfo,
        diceResults: result.diceResults,
        lastError: result.lastError,
      ),
    );

    // 先自动保存子版：优先保证进度持久化，不依赖 LLM 的慢速记忆提取。
    // 记忆提取（MemoryManager）内部有 try-catch + 超时保护，异步执行不阻塞
    // 生成本轮的完成（避免 `_isGeneratingInFlight` 长时间占位导致用户无法发下一条）。
    // 提取成功更新 state.memories 后，下次自动保存自然包含新记忆。
    await _autoSaveChild();
    unawaited(
      _maybeExtractMemories(
        config: settings.llmConfig,
        auxConfig: settings.auxLlmConfig,
      ),
    );
  }

  /// 执行子版保存，统一处理「更新 [sourceFileName] + 错误提示」样板。
  ///
  /// 所有保存路径（自动保存 / 默认保存 / 另存为分支）最终都委托此方法，
  /// 消除多份几乎相同的 `SessionSaver.save + state 更新 + 错误处理` 重复。
  ///
  /// 参数：
  ///   - saver: 实际执行存档的闭包（委托 [SessionSaver] 的对应方法）
  ///   - errorMessage: 保存失败时写入 [NarrativeState.lastError] 的提示
  Future<String?> _performSave({
    required String errorMessage,
    required Future<String> Function() saver,
  }) async {
    try {
      final savedFileName = await saver();
      // 记住当前会话的实际存档文件，避免下次保存/自动保存时重复生成新文件
      if (savedFileName != state.sourceFileName) {
        state = state.copyWith(sourceFileName: savedFileName);
      }
      return savedFileName;
    } catch (e) {
      debugPrint('$errorMessage: $e');
      state = state.copyWith(lastError: errorMessage);
      return null;
    }
  }

  /// 默认保存路径：当前已是子版则直接覆盖原文件；母版生成/递增默认 `.child` 子版。
  ///
  /// 被 [_autoSaveChild] 与 [saveChild]（无分支名）共用，
  /// 存档决策委托 [SessionSaver.saveCurrent]（子版覆盖 / 母版 .child 递增）。
  ///
  /// 保存失败时通过 [NarrativeState.lastError] 暴露错误（UI 已监听并提示），
  /// 而不是让异常冒泡为未处理错误。
  Future<String?> _saveDefault({required String errorMessage}) {
    return _performSave(
      errorMessage: errorMessage,
      saver: () => ChildSaveStore.saveCurrent(
        sourceFileName: state.sourceFileName,
        contract: state.contract,
        currentState: state.currentState,
        memories: state.memories,
        history: state.history,
      ),
    );
  }

  /// 自动保存：若当前即为子版则改写原文件；母版则生成/写入 `.child` 子版。
  ///
  /// 保存成功后更新 [NarrativeState.sourceFileName] 为实际保存的文件名，
  /// 使后续自动保存识别当前已打开的是子版，直接覆盖原文件而非生成递增新文件。
  Future<String?> _autoSaveChild() {
    return _saveDefault(errorMessage: narrativeErrorAutoSaveFail);
  }

  /// 保存当前会话为子版文件。返回保存的文件名；失败返回 null 并经
  /// [NarrativeState.lastError] 暴露错误（UI 已监听并提示）。
  ///
  /// 参数：
  ///   - branchName: 可选自定义分支名（如 'dark'）；null 时使用默认 `.child`
  ///   - branchTitle: 可选「命运一句话」（另存为分支时填写），
  ///     以 `@命运:` 标记注入子版【角色背景】；null/空则沿用既有说明
  ///
  /// 保存成功后更新 [NarrativeState.sourceFileName] 为实际保存的文件名，
  /// 使后续保存操作识别当前已打开的是子版，直接覆盖原文件而非重复新建。
  Future<String?> saveChild({String? branchName, String? branchTitle}) async {
    // 用户显式指定分支名 → 「另存为分支」：以母版名为基础生成新分支文件
    // （如 faust.dark.meph），而不是基于当前文件名（否则从子版另存会得到 child.dark）
    if (branchName != null && branchName.isNotEmpty) {
      return _performSave(
        errorMessage: narrativeErrorSaveFail,
        saver: () => ChildSaveStore.saveAsBranch(
          sourceFileName: state.sourceFileName,
          branchName: branchName,
          branchTitle: branchTitle,
          contract: state.contract,
          currentState: state.currentState,
          memories: state.memories,
          history: state.history,
        ),
      );
    }

    // 默认保存：复用「子版覆盖 / 母版 .child 递增」的共享路径
    return _saveDefault(errorMessage: narrativeErrorSaveFail);
  }

  /// 从指定子版文件恢复会话；成功返回 true。
  Future<bool> restoreChild(String fileName) async {
    final restored = await ChildSaveStore.restore(fileName);
    if (restored == null) return false;

    _dispatch(SessionRestored(restored: restored, fileName: fileName));
    return true;
  }

  /// 恢复默认子版（`faust.child.meph`）；成功返回 true。
  Future<bool> restoreSession() {
    return restoreChild(
      meph_file_name.defaultChildFileName(state.sourceFileName),
    );
  }

  /// 删除指定子版文件。
  Future<bool> deleteChild(String fileName) => ChildSaveStore.delete(fileName);

  /// 删除默认子版。
  Future<bool> deleteSave() =>
      deleteChild(meph_file_name.defaultChildFileName(state.sourceFileName));

  /// 列出当前母版的所有子版文件。
  Future<List<String>> listChildFiles() =>
      ChildSaveStore.listChildFiles(state.sourceFileName);

  /// 记忆提取（委托 MemoryManager；LLM 配置由调用方传入）。
  ///
  /// 提取是异步后台任务，期间用户可能继续发消息（新对话产生新记忆/规则
  /// 注入新记忆）。因此写回时必须**安全合并**而非直接覆盖：
  ///   - 若提取期间无新对话（history 长度未变），直接采用提取结果
  ///   - 若期间有新对话（history 长度变化），则以「当前 memories」为准，
  ///     仅将新提取结果中**当前不存在**的新条目追加到末尾——
  ///     保证提取期间新产生的记忆不会被旧提取结果覆盖（记忆是角色不崩
  ///     人设的根基，丢失即人设崩塌风险）
  ///
  /// **权重制取舍**：合并后若超过 [MemoryManager.maxLimit]，触发
  /// [MemoryManager.compress] 压缩——低权重（1-3 星）记忆优先被 LLM
  /// 压缩为摘要/舍弃以节省 token 与上下文，高权重（≥4 星）默认永不
  /// 丢弃（保护人设核心）。本方法不新增重复的取舍规则，完全复用
  /// MemoryManager 已有的权重制压缩逻辑。
  ///
  /// **立即持久化**：记忆写回成功后触发一次静默自动存档（[_autoSaveChild]）。
  /// 原因：`_generateCore` 中 `await _autoSaveChild()` 发生在记忆提取**之前**，
  /// 若提取在最后一轮对话后异步完成，新记忆不会立即写盘——用户此时关闭
  /// 应用即丢失。这里的二次保存确保新记忆立即持久化。文件监听 mtime 抑制
  /// 已避免自触发死循环；保存失败时 [_performSave] 内部设置 `lastError` 由
  /// UI 提示（数据安全值得告知）。
  Future<void> _maybeExtractMemories({
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    // 提取时快照 history 长度，用于检测提取期间是否发生了新对话
    final historyLengthAtStart = state.history.length;

    // 复用全局 [MemoryManager] 单例（轻量无状态，共享 HTTP 连接池）
    final manager = ref.read(memoryManagerProvider);

    // 委托 [MemoryExtractionService]（与多角色版共享安全合并逻辑）
    final updated = await ref
        .read(memoryExtractionServiceProvider)
        .extractWithSafeMerge(
          manager: manager,
          input: MemoryExtractionInput(
            history: state.history,
            memories: state.memories,
            historyLengthAtStart: historyLengthAtStart,
          ),
          // 提取完成后用「当前最新」长度与记忆做合并判断：
          // input 内是提取启动时的快照，若用它比较则长度恒等，
          // 安全合并会退化为直接覆盖（提取期间新记忆丢失）。
          currentHistoryLength: state.history.length,
          currentMemories: state.memories,
          config: config,
          auxConfig: auxConfig,
        );
    if (updated == null) return;

    state = state.copyWith(memories: updated);

    // 记忆写回后静默触发自动存档，确保新提取的记忆立即持久化
    // （saveCurrent 保存的是当前 state 最新快照，含提取期间的新对话，
    //   无覆盖风险；mtime 抑制防文件监听死循环）
    await _autoSaveChild();
  }

  /// 构造默认子版文件名（`faust.meph` → `faust.child.meph`；
  /// `faust.dark.meph` → `faust.dark.child.meph`）。
  ///
  /// 委托共享工具 [meph_file_name.defaultChildFileName]（与
  /// [StageNarrativeNotifier] 完全一致，为唯一实现）。
  static String defaultChildFileName(String masterFileName) =>
      meph_file_name.defaultChildFileName(masterFileName);

  /// 重新生成指定 assistant 回复。
  ///
  /// 流程：删除该回复 + 其前一条命运指引（`cascadeFate: true`）
  /// → 再以同一条指引内容重新发送，触发新一轮生成。
  ///
  /// **并发守卫**：删除 → 存档 → 重新发送三步间存在 await 间隙，
  /// 用户可能在此期间发送新消息（或发生其他状态迁移）。通过
  /// [_mutationCount] 版本号检测：删除后版本号若已变化，说明会话
  /// 已不在「刚删除该回复」的状态，放弃重新发送——避免重生成叠在
  /// 用户新对话之上造成消息错位。
  Future<void> regenerateMessage(int index) async {
    if (state.isGenerating) return;
    if (index < 0 || index >= state.messages.length) return;
    final message = state.messages[index];
    if (message.role != MessageRole.assistant) return;

    // 找到其前一条 fate 指引的内容（用于重新发送）
    String? fateContent;
    for (var i = index - 1; i >= 0; i--) {
      if (state.messages[i].role == MessageRole.fate) {
        fateContent = state.messages[i].content;
        break;
      }
    }
    if (fateContent == null) return;

    // 删除回复 + 指引（级联）；_dispatch 会递增 _mutationCount
    _dispatch(MessageDeleted(index, cascadeFate: true));
    // 记录删除后的版本号：await 存档后若已变化 → 有并发修改，放弃重发
    final versionAfterDelete = _mutationCount;

    // 删除后更新当前状态引用（_dispatch 已更新 state）
    await _autoSaveChild();

    // 并发守卫：存档期间用户发了新消息 / 状态被迁移 → 放弃重新发送
    if (_mutationCount != versionAfterDelete) return;
    if (!canSend(isGenerating: state.isGenerating)) return;

    // 重新发送同一条命运指引
    sendMessage(fateContent);
  }

  /// 附加上下文（会话级，支持多选追加）。
  void attachContext(String fileName, String content) {
    _dispatch(ContextAttached(fileName: fileName, content: content));
  }

  /// 移除指定索引的附加上下文。
  void removeAttachedContext(int index) {
    _dispatch(ContextRemoved(index));
  }

  /// 清空所有附加上下文。
  void clearAttachedContexts() {
    _dispatch(const ContextsCleared());
  }

  /// 更新单个状态值。
  void setState(String key, StateValue value) {
    _dispatch(StateValueSet(key: key, value: value));
  }

  /// 重置会话（保留契约，清空动态数据）。
  void resetSession() {
    _dispatch(const SessionReset());
  }

  /// 热重载契约：解析新内容并**应用规则 + 记忆中区块**，保留其他静态字段。
  ///
  /// 用于「叙事页内编辑当前契约」的运行时热更新：
  ///   - **规则**：只在下一轮输入时由规则引擎重新求值，改规则不影响当前
  ///     对话/状态/记忆，是最安全且有价值的实时调整对象
  ///   - **记忆**：记忆是运行时数据（用户可在编辑器/VSCode 中直接修改
  ///     `[N]` 前缀调整权重），因此支持热更新。文件监听重新解析出的
  ///     `[N] 前缀` 记忆会回写 [NarrativeState.memories]，即时生效
  ///   - 角色名/锚点/世界观/背景/开局场景/初始状态等「角色人格本体」区块
  ///     一律保留原运行版本——运行中改动它们会导致叙事前后矛盾（如历史
  ///     回复仍是旧角色口吻），因此即使编辑器里改动了也不生效
  ///   - [NarrativeState.currentState] / [NarrativeState.history] /
  ///     [NarrativeState.messages] 全部保留，不丢失任何运行进度
  ///   - 解析失败时不生效，仅记录错误（编辑器已有实时校验双保险）
  void hotReloadContract(String content) {
    try {
      final newContract = parseMeph(content);
      state = state.copyWith(
        contract: state.contract.copyWith(
          rules: newContract.rules, // 仅应用规则区块
        ),
        // 记忆是运行时数据，支持热更新：
        // 用户在应用内修改权重并自动存档后，文件含最新权重；
        // 文件监听重新解析 → 回写 memories → 与内存状态保持一致
        memories: newContract.memories,
      );
    } catch (e) {
      debugPrint('契约热重载失败: $e');
      state = state.copyWith(lastError: narrativeErrorHotReloadFail);
    }
  }
}

// ============================================================
// Provider 定义
// ============================================================

/// 单轮叙事生成服务 Provider
///
/// 轻量无状态服务，全局复用同一实例（避免每轮对话重复构造 [NarrativeTurnService]）。
/// 共享 [httpClientProvider] 中的 HTTP 客户端，实现连接复用。
final narrativeTurnServiceProvider = Provider<NarrativeTurnService>((ref) {
  return NarrativeTurnService(client: ref.watch(httpClientProvider));
});

/// 记忆管理服务 Provider
///
/// 与 [narrativeTurnServiceProvider] 同理，全局复用 [MemoryManager] 单例。
final memoryManagerProvider = Provider<MemoryManager>((ref) {
  return MemoryManager(client: ref.watch(httpClientProvider));
});

/// 记忆提取编排服务 Provider
///
/// 轻量无状态单例，单角色与多角色 Notifier 共享「记忆提取 → 安全合并」管线。
final memoryExtractionServiceProvider = Provider<MemoryExtractionService>((
  ref,
) {
  return const MemoryExtractionService();
});

/// 叙事状态 Provider。
final narrativeProvider = NotifierProvider<NarrativeNotifier, NarrativeState>(
  NarrativeNotifier.new,
);
