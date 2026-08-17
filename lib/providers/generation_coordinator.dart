import 'dart:async';

/// 生成编排协调器（单角色 / 多角色 Notifier 共用）
///
/// 两个 Notifier（[NarrativeNotifier] 与 [StageNarrativeNotifier]）的
/// 「生成中编排」逻辑完全一致：
///   - 同步防重入标志 `_isGeneratingInFlight`（双保险防并发/连点穿透）
///   - 取消信号 `_generationCancel`（用户点击「停止生成」后完成，
///     服务端收到后提前终止 SSE 读取）
///   - [stopGenerating]：立即 flush 流式缓冲 + 触发取消信号
///   - dispose 清理（Notifier 重建时释放 Timer / 信号 / 标志位）
///
/// 通过 `State` 泛型约束：T 是 Notifier 的 state 类型，混入方需实现
/// `onStopFlush()`（停止前刷出流式缓冲）。将两处约 40 行重复消除为单份。
mixin GenerationCoordinator<T> {
  /// 当前生成任务的取消信号（用户点击「停止生成」后完成）
  ///
  /// 每次发送新消息时重新创建；[stopGenerating] 触发完成，
  /// 服务端（LlmClient）收到后提前终止 SSE 读取。
  Completer<void>? _generationCancel;

  /// 同步生成中标志位（双保险防重入）
  ///
  /// 与 state.isGenerating 的区别：
  ///   - isGenerating 是状态字段，通过 dispatch 后异步生效，
  ///     在状态更新前的微任务间隙，极端情况下仍可能有第二次 sendMessage 进入
  ///   - 本标志在 sendMessage 入口立即同步置位，彻底消除竞态窗口，
  ///     并在生成成功/失败后统一复位
  bool _isGeneratingInFlight = false;

  /// 二次守卫：生成中禁止再次发送（UI 已禁用输入，极端连点/竞态时兜底）。
  /// 返回 true 表示可以继续发送（未被拒绝）。
  bool canSend({required bool isGenerating}) {
    if (isGenerating || _isGeneratingInFlight) return false;
    return true;
  }

  /// 进入生成状态（在 dispatch 之前调用，确保并发/连点无法穿透）。
  void beginGeneration() {
    _isGeneratingInFlight = true;
    // 每次发送创建新的取消信号（覆盖上次生成可能遗留的已取消信号）
    _generationCancel = Completer<void>();
  }

  /// 生成结束（成功/失败/异常均须调用，复位同步标志位）。
  void endGeneration() {
    _isGeneratingInFlight = false;
    // 清理已完成/已取消的生成信号引用，避免悬挂引用占用内存
    _generationCancel = null;
  }

  /// 当前生成任务的取消信号 Future（传给服务端）。
  ///
  /// 命名避免与 `service.generate(cancelSignal: ...)` 的命名参数同名，
  /// 使调用处 `cancelSignal: generationCancelSignal` 清晰无歧义。
  Future<void>? get generationCancelSignal => _generationCancel?.future;

  /// 触发当前生成任务的取消信号（协作式取消）。
  ///
  /// 与 [stopGenerating] 的区别：只触发取消信号，不 flush 流式缓冲。
  /// 用于「⏩ 立即显示全文」场景——调用方已自行 flush 缓冲，
  /// 这里仅让 LlmClient 在下一条 SSE 数据行处停止读取并返回已累积内容。
  void cancelGeneration() {
    _generationCancel?.complete();
  }

  /// 停止当前生成：立即 flush 已到达的流式内容并触发取消信号。
  ///
  /// 协作式取消：不会中断底层 http 连接，而是让 LlmClient 在下一个
  /// SSE 数据行处停止读取并返回已累积内容，随后生成流程正常收尾。
  void stopGenerating() {
    // 立即 flush 已到达的流式内容，避免遗留在缓冲中
    onGenerationStop();
    cancelGeneration();
  }

  /// 停止生成时的流式缓冲 flush 钩子（由混入方实现）。
  void onGenerationStop();

  /// 执行一轮完整生成的「收尾编排」：try/catch/finally 统一处理。
  ///
  /// 单角色 [NarrativeNotifier.sendMessage] 与多角色
  /// [StageNarrativeNotifier.sendMessage] 的生成段骨架完全一致，收敛为
  /// 统一实现：
  ///   - 成功/失败都必须在 finally 中复位同步标志位 [endGeneration]，
  ///     允许用户发送下一条（防卡死）
  ///   - 失败时调用 [onFailure]（flush 流式缓冲 + dispatch 失败事件），
  ///     错误信息经 [onError] 记录（含堆栈）
  ///
  /// 参数：
  ///   - [userInput]: 本轮命运指引（原样传给 [core]）
  ///   - [core]: 实际生成管线（_generateCore，含 LLM 调用/存档/记忆提取）
  ///   - [onFailure]: 生成失败的收尾（dispatch GenerationFailed 事件）
  ///   - [onError]: 异常记录回调（debugPrint 带堆栈）
  Future<void> runGeneration({
    required String userInput,
    required Future<void> Function(String input) core,
    required void Function() onFailure,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) async {
    try {
      await core(userInput);
    } catch (e, st) {
      onError(e, st);
      onFailure();
    } finally {
      // 无论成功/失败/异常，都必须复位同步标志位，允许下一次发送
      endGeneration();
    }
  }

  /// Notifier dispose 清理（防止 Timer / 信号泄漏）。
  void disposeGeneration() {
    _generationCancel = null;
    _isGeneratingInFlight = false;
  }
}
