import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/narrative_event.dart';
import '../domain/narrative_reducer.dart';
import '../domain/narrative_state.dart';
import '../services/memory/memory_manager.dart';
import '../services/narrative_turn_service.dart';
import '../services/parser/meph_parser.dart';
import '../services/session/child_save_store.dart';
import '../services/session/session_saver.dart';
import '../services/storage/contract_repo.dart';
import 'contract_provider.dart';
import 'llm_settings_provider.dart';
import 'narrative_rule_provider.dart';

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
  /// 流式输出节流合并缓冲（50ms 窗口内累积 chunk 后一次性提交）
  final StringBuffer _streamBuffer = StringBuffer();

  /// 流式输出节流定时器
  Timer? _streamTimer;

  /// 追加流式 chunk：累积到缓冲，按节流窗口统一提交，减少 Riverpod 通知。
  void _appendStreamChunk(String chunk) {
    _streamBuffer.write(chunk);
    // 每次有新 chunk 到达时，重置 50ms 一次性定时器；
    // 定时器触发即提交缓冲 —— 语义是「最后一片 chunk 后 50ms 提交」。
    _streamTimer ??= Timer(const Duration(milliseconds: 50), _flushStreamBuffer);
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

  /// 将事件应用到状态（Reducer 风格：所有状态迁移统一走 [narrativeReducer]）。
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
    });

    // 读取当前母版文件名（用于子版命名）
    final sourceName =
        ref.watch(currentContractNameProvider).value ?? defaultContractName;
    // 契约加载失败时回退到空契约（避免崩溃）
    final contract = ref.watch(contractProvider).value ?? Contract.empty();
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
    if (state.isGenerating) return;

    final trimmed = content.trim();
    _dispatch(MessageSent(trimmed));

    _generateReply(trimmed);
  }

  /// 生成 AI 回复（委托 [NarrativeTurnService]，结果写回状态）。
  ///
  /// 全局兜底：生成流程中任何未预期异常（如 Provider 加载失败、规则引擎异常）
  /// 都会在此捕获并重置生成状态，避免 UI 永久卡在"生成中"。
  Future<void> _generateCore(String userInput) async {
    final sharedClient = ref.read(httpClientProvider);
    final service = NarrativeTurnService(client: sharedClient);
    // 每次发消息都强制 refresh（重新读 SharedPreferences），
    // 确保改 key 后不重启也能立即用新配置；llmConfigProvider 是 autoDispose
    final config = await ref.refresh(llmConfigProvider.future);
    final narrativeRules = ref.read(narrativeRuleProvider);

    final result = await service.generate(
      userInput: userInput,
      contract: state.contract,
      currentState: state.currentState,
      memories: state.memories,
      // 历史消息 = 除去最后一条（本次命运指引）的所有消息
      priorMessages: state.messages.take(state.messages.length - 1).toList(),
      attachedContexts: state.attachedContexts,
      narrativeRules: narrativeRules,
      config: config,
      onChunk: _appendStreamChunk,
    );

    // 流式输出结束：先 flush 缓冲中的剩余 chunk，再聚合提交
    _flushStreamBuffer();

    // 聚合本轮所有变化（状态/记忆/骰子/回复/错误），一次性批量提交：
    // 状态迁移统一走 reducer（narrativeReducer），减少 Riverpod 通知与 UI 重建。
    _dispatch(ReplySucceeded(
      reply: result.reply,
      newState: result.newState,
      injectedMemories: result.injectedMemories,
      rollInfo: result.rollInfo,
      diceResults: result.diceResults,
      lastError: result.lastError,
    ));

    // 记忆提取 + 自动保存子版（串行执行：先提取记忆，确保保存的快照包含最新记忆）
    await _maybeExtractMemories(config: config);
    await _autoSaveChild();
  }

  /// 生成回复的全局兜底包装：任何未预期异常都重置生成状态，避免卡死。
  Future<void> _generateReply(String userInput) async {
    try {
      await _generateCore(userInput);
    } catch (e, st) {
      debugPrint('生成回复异常: $e\n$st');
      // 重置生成状态 + 抛出错误信息，避免 UI 永久停留在"生成中"（走 reducer）
      _flushStreamBuffer();
      _dispatch(const GenerationFailed('生成回复时发生异常，请重试'));
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
    return _saveDefault(errorMessage: '自动存档失败，进度未写入磁盘');
  }

  /// 保存当前会话为子版文件。返回保存的文件名；失败返回 null 并经
  /// [NarrativeState.lastError] 暴露错误（UI 已监听并提示）。
  ///
  /// 参数：
  ///   - branchName: 可选自定义分支名（如 'dark'）；null 时使用默认 `.child`
  ///
  /// 保存成功后更新 [NarrativeState.sourceFileName] 为实际保存的文件名，
  /// 使后续保存操作识别当前已打开的是子版，直接覆盖原文件而非重复新建。
  Future<String?> saveChild({String? branchName}) async {
    // 用户显式指定分支名 → 「另存为分支」：以母版名为基础生成新分支文件
    // （如 faust.dark.meph），而不是基于当前文件名（否则从子版另存会得到 child.dark）
    if (branchName != null && branchName.isNotEmpty) {
      return _performSave(
        errorMessage: '存档失败，请检查契约目录权限或磁盘空间',
        saver: () => SessionSaver.saveAsBranch(
          sourceFileName: state.sourceFileName,
          branchName: branchName,
          contract: state.contract,
          currentState: state.currentState,
          memories: state.memories,
          history: state.history,
        ),
      );
    }

    // 默认保存：复用「子版覆盖 / 母版 .child 递增」的共享路径
    return _saveDefault(
      errorMessage: '存档失败，请检查契约目录权限或磁盘空间',
    );
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
  Future<bool> deleteSave() => deleteChild(defaultChildFileName(state.sourceFileName));

  /// 列出当前母版的所有子版文件。
  Future<List<String>> listChildFiles() =>
      ChildSaveStore.listChildFiles(state.sourceFileName);

  /// 记忆提取（委托 MemoryManager；LLM 配置由调用方传入）。
  Future<void> _maybeExtractMemories({LlmConfig? config}) async {
    final manager = MemoryManager(client: ref.read(httpClientProvider));
    final updated = await manager.maybeExtract(
      history: state.history,
      memories: state.memories,
      config: config,
    );
    if (updated != null) {
      state = state.copyWith(memories: updated);
    }
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

  /// 热重载规则：解析新内容并**仅应用规则区块**，保留契约其余全部字段。
  ///
  /// 用于「叙事页内编辑当前契约」的运行时热更新：
  ///   - 规则只在下一轮输入时由规则引擎重新求值，改规则不影响当前对话/
  ///     状态/记忆，是最安全且有价值的实时调整对象
  ///   - 角色名/锚点/世界观/背景/开局场景/初始状态等「角色人格本体」区块
  ///     一律保留原运行版本——运行中改动它们会导致叙事前后矛盾（如历史
  ///     回复仍是旧角色口吻），因此即使编辑器里改动了也不生效
  ///   - [NarrativeState.currentState] / [NarrativeState.memories] /
  ///     [NarrativeState.history] / [NarrativeState.messages] 全部保留，
  ///     不丢失任何运行进度
  ///   - 解析失败时不生效，仅记录错误（编辑器已有实时校验双保险）
  void hotReloadContract(String content) {
    try {
      final newContract = parseMeph(content);
      final old = state.contract;
      state = state.copyWith(
        contract: Contract(
          roleName: old.roleName,
          anchor: old.anchor,
          worldview: old.worldview,
          background: old.background,
          opening: old.opening,
          state: old.state,
          rules: newContract.rules, // 仅应用规则区块
          memories: old.memories,
          history: old.history,
        ),
      );
    } catch (e) {
      debugPrint('契约热重载失败: $e');
      state = state.copyWith(lastError: '契约热重载失败，已保留原设定');
    }
  }
}

// ============================================================
// Provider 定义
// ============================================================

/// 叙事状态 Provider。
final narrativeProvider = NotifierProvider<NarrativeNotifier, NarrativeState>(
  NarrativeNotifier.new,
);
