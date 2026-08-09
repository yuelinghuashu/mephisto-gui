import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/narrative_error.dart';
import '../domain/narrative_event.dart';
import '../domain/narrative_reducer.dart';
import '../domain/narrative_state.dart';
import '../services/memory/memory_manager.dart';
import '../services/narrative_turn_service.dart';
import '../services/parser/meph_parser.dart';
import '../services/session/child_save_store.dart';
import '../services/session/session_saver.dart';
import '../services/storage/meph_file_name.dart';
import 'contract_provider.dart';
import 'llm_settings_provider.dart';
import 'narrative_memory_provider.dart';
import 'narrative_rule_provider.dart';
import 'narrative_window_provider.dart';

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
///     本 Notifier 只负责「当前舞台这一角色」的状态编排（消息/历史/状态/记忆/存档）。
///   - 未来多角色舞台，调度器可对每个角色各自调用 [NarrativeTurnService.generate]
///     并与 `Future.wait` 并发执行，角色上下文天然隔离。
class NarrativeNotifier extends Notifier<NarrativeState> {
  /// 流式输出节流合并缓冲的累积窗口。
  ///
  /// LLM SSE 以 chunk 高频到达，若每 chunk 都触发 Riverpod 通知，
  /// 会导致 UI 频繁重建（尤其在 50ms 内几十个 chunk 的场景）。
  /// 在窗口内累积所有 chunk，窗口结束时统一提交一次，显著减少通知次数。
  static const Duration streamFlushInterval = Duration(milliseconds: 50);

  /// 流式输出节流合并缓冲（[streamFlushInterval] 窗口内累积后一次性提交）
  final StringBuffer _streamBuffer = StringBuffer();

  /// 流式输出节流定时器
  Timer? _streamTimer;

  /// 当前生成任务的取消信号（用户点击「停止生成」后完成）
  ///
  /// 每次发送新消息时重新创建；[stopGenerating] 触发完成，
  /// [NarrativeTurnService] 和 [LlmClient] 收到后提前终止 SSE 读取。
  Completer<void>? _generationCancel;

  /// 同步生成中标志位（双保险防重入）
  ///
  /// 与 [NarrativeState.isGenerating] 的区别：
  ///   - `isGenerating` 是状态字段，通过 [MessageSent] dispatch 后异步生效，
  ///     在状态更新前的微任务间隙，极端情况下仍可能有第二次 `sendMessage` 进入
  ///   - 本标志在 `sendMessage` 入口立即同步置位，彻底消除竞态窗口，
  ///     并在 `_generateCore` 成功/失败后统一复位
  bool _isGeneratingInFlight = false;

  /// 追加流式 chunk：累积到缓冲，按 50ms 节流窗口统一提交（减少 Riverpod 通知）。
  void _appendStreamChunk(String chunk) {
    _streamBuffer.write(chunk);
    // 定时器语义是「最后一片 chunk 后 50ms 提交」
    _streamTimer ??= Timer(
      streamFlushInterval,
      _flushStreamBuffer,
    );
  }

  /// 提交缓冲中的流式内容到状态。
  void _flushStreamBuffer() {
    _streamTimer?.cancel();
    _streamTimer = null;
    if (_streamBuffer.isEmpty) return;
    final pending = _streamBuffer.toString();
    _streamBuffer.clear();
    state = state.copyWith(streamingContent: state.streamingContent + pending);
  }

  /// 状态迁移统一走 [narrativeReducer]
  void _dispatch(NarrativeEvent event) {
    state = narrativeReducer(state, event);
  }

  @override
  NarrativeState build() {
    // Notifier 重建（契约切换/Provider 失效）时清理流式定时器，避免泄漏
    ref.onDispose(() {
      _streamTimer?.cancel();
      _streamTimer = null;
      _streamBuffer.clear();
      _generationCancel = null;
      _isGeneratingInFlight = false;
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
  void sendMessage(String content) {
    if (content.trim().isEmpty) return;
    // 二次守卫：生成中禁止再次发送（UI 已禁用输入，极端连点/竞态时兜底）
    // 同步标志位 + 状态字段双保险，彻底消除「状态更新前重复进入」的竞态窗口
    if (state.isGenerating || _isGeneratingInFlight) return;

    // 入口立即置位同步标志（在 dispatch 之前），确保并发/连点无法穿透
    _isGeneratingInFlight = true;

    final trimmed = content.trim();
    // 每次发送创建新的取消信号（覆盖上次生成可能遗留的已取消信号）
    _generationCancel = Completer<void>();
    _dispatch(MessageSent(trimmed));

    _generateReply(trimmed);
  }

  /// 停止当前生成：触发取消信号，让 LLM 流式读取提前终止。
  ///
  /// 协作式取消：不会中断底层 http 连接，而是让 [LlmClient] 在下一个
  /// SSE 数据行处停止读取并返回已累积内容，随后生成流程正常走
  /// [ReplySucceeded] 收尾（含自动存档），状态不会卡在「生成中」。
  void stopGenerating() {
    // 立即 flush 已到达的流式内容，避免遗留在缓冲中
    _flushStreamBuffer();
    _generationCancel?.complete();
  }

  /// 生成 AI 回复（委托 [NarrativeTurnService]，结果写回状态）。
  ///
  /// 全局兜底：生成流程中任何未预期异常（如 Provider 加载失败、规则引擎异常）
  /// 都会在此捕获并重置生成状态，避免 UI 永久卡在"生成中"。
  Future<void> _generateCore(String userInput) async {
    // 复用全局 [NarrativeTurnService] 单例（轻量无状态，共享 HTTP 连接池）
    final service = ref.read(narrativeTurnServiceProvider);
    // 每次发消息都强制 refresh（重新读 SharedPreferences），
    // 确保改 key 后不重启也能立即用新配置；llmConfigProvider 是 autoDispose
    final config = await ref.refresh(llmConfigProvider.future);
    final narrativeRules = ref.read(narrativeRuleProvider);
    // 上下文窗口：保留最近 N 条历史消息（用户可在设置页调整；null = 全部发送）
    final maxHistoryMessages = ref
        .read(narrativeWindowProvider)
        .maxHistoryMessages;
    // 记忆注入灌窗：每轮最多带入 N 条记忆（用户可在设置页调整；null = 全部注入）
    final maxMemories = ref.read(narrativeMemoryLimitProvider).maxMemories;

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
      narrativeRules: narrativeRules,
      config: config,
      onChunk: _appendStreamChunk,
      // 当前生成任务的取消信号（停止生成时触发）
      cancelSignal: _generationCancel?.future,
      // 上下文窗口上限（保留最近 N 条历史消息，控制 token 消耗）
      maxHistoryMessages: maxHistoryMessages,
      // 记忆注入灌窗：每轮最多带入 N 条记忆（用户可配置；null = 全部注入），
      // 超过时高权重（≥4）全部保留 + 其余按权重降序补足，
      // 防止超长记忆列表无条件灌入导致 token 膨胀
      maxMemories: maxMemories,
    );

    // 流式输出结束：先 flush 缓冲中的剩余 chunk，再聚合提交
    _flushStreamBuffer();

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
    unawaited(_maybeExtractMemories(config: config));
  }

  /// 生成回复的全局兜底包装：任何未预期异常都重置生成状态，避免卡死。
  Future<void> _generateReply(String userInput) async {
    try {
      await _generateCore(userInput);
    } catch (e, st) {
      debugPrint('生成回复异常: $e\n$st');
      // 重置生成状态 + 抛出错误信息，避免 UI 永久停留在"生成中"（走 reducer）
      // 错误以错误码形式暴露（provider.generation_failed），由 UI 层本地化翻译
      _flushStreamBuffer();
      _dispatch(const GenerationFailed(narrativeErrorGenFailed));
    } finally {
      // 无论成功/失败/异常，都必须复位同步标志位，允许下一次发送
      _isGeneratingInFlight = false;
      // 清理已完成/已取消的生成信号引用，避免悬挂引用占用内存
      _generationCancel = null;
    }
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
      saver: () => SessionSaver.saveCurrent(
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
        saver: () => SessionSaver.saveAsBranch(
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
    return restoreChild(defaultChildFileName(state.sourceFileName));
  }

  /// 删除指定子版文件。
  Future<bool> deleteChild(String fileName) => ChildSaveStore.delete(fileName);

  /// 删除默认子版。
  Future<bool> deleteSave() =>
      deleteChild(defaultChildFileName(state.sourceFileName));

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
  Future<void> _maybeExtractMemories({LlmConfig? config}) async {
    // 提取时快照 history 长度，用于检测提取期间是否发生了新对话
    final historyLengthAtStart = state.history.length;

    // 复用全局 [MemoryManager] 单例（轻量无状态，共享 HTTP 连接池）
    final manager = ref.read(memoryManagerProvider);
    final updated = await manager.maybeExtract(
      history: state.history,
      memories: state.memories,
      config: config,
    );
    if (updated == null) return;

    // 提取期间没有新对话 → 直接采用提取结果（无覆盖风险）
    if (state.history.length == historyLengthAtStart) {
      state = state.copyWith(memories: updated);
    } else {
      // 提取期间有新对话 → 安全合并：
      // 以当前 memories 为基底，仅追加「新提取结果中当前不存在」的条目。
      // 利用 Memory 的 Equatable props（按 content 比较）判断是否已存在。
      final currentContents = state.memories.map((m) => m.content).toSet();
      final fresh = updated
          .where((m) => !currentContents.contains(m.content))
          .toList();
      if (fresh.isEmpty) return; // 无新增条目，保持现状

      var combined = [...state.memories, ...fresh];
      // 遵循权重制取舍：合并后超限触发 compress（低权重优先压缩/舍弃，
      // 高权重保护不丢）——而非无脑追加导致列表膨胀失控
      if (combined.length > MemoryManager.maxLimit) {
        combined = await manager.compress(combined, config: config);
      }
      state = state.copyWith(memories: combined);
    }

    // 记忆写回后静默触发自动存档，确保新提取的记忆立即持久化
    // （saveCurrent 保存的是当前 state 最新快照，含提取期间的新对话，
    //   无覆盖风险；mtime 抑制防文件监听死循环）
    await _autoSaveChild();
  }

  /// 构造默认子版文件名（`faust.meph` → `faust.child.meph`）。
  static String defaultChildFileName(String masterFileName) =>
      '${extractMasterPrefix(masterFileName)}${ChildSaveStore.defaultChildSuffix}.meph';

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

/// 叙事状态 Provider。
final narrativeProvider = NotifierProvider<NarrativeNotifier, NarrativeState>(
  NarrativeNotifier.new,
);
