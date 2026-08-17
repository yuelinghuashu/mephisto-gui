import '../services/stream_throttle.dart';

/// 流式输出协调器（单角色 / 多角色 Notifier 共用）
///
/// 将两个 Notifier（[NarrativeNotifier] 与 [StageNarrativeNotifier]）中
/// 逐字相同的「流式输出五件套」收敛为一个 mixin：
///   - `ThrottledStreamBuffer _streaming`（节流合并 + StringBuffer 累积）
///   - `bool _revealInstant`（「立即显示全文」标志）
///   - [_appendStreamChunk]：追加 chunk（跳过打字机模式静默忽略）
///   - [_flushStreamBuffer]：立即提交缓冲
///   - [revealStreaming]：跳过剩余打字机动画
///   - [_resetStreamingForNewRound]：新一轮生成前复位（清缓冲 + 复位标志）
///   - [disposeStreaming]：Notifier dispose 时释放定时器
///
/// 混入方只需提供「流式内容写回状态」的更新器 [applyStreamingContent]
/// （两个 Notifier 均为 `state = state.copyWith(streamingContent: ...)`）。
///
/// 注意：混入方必须自行在 `ref.onDispose` 中调用 [disposeStreaming]。
mixin StreamingCoordinator {
  /// 流式内容累积器（节流合并 + StringBuffer 一体化）
  ///
  /// 复用 [ThrottledStreamBuffer]，避免以 `state.streamingContent + pending`
  /// 每 50ms 创建新字符串（长叙事文本下 O(n²) 拼接开销）。
  final ThrottledStreamBuffer _streaming = ThrottledStreamBuffer();

  /// 是否已进入「立即显示全文」模式。
  ///
  /// 用户点击「⏩ 显示全文」后置位：后续流式 chunk 不再走 50ms 节流，
  /// 直接累积进 StringBuffer 并整串提交状态，跳过打字机动画。
  bool _revealInstant = false;

  /// 追加流式 chunk：累积到缓冲，按节流窗口统一提交（减少 Riverpod 通知）。
  ///
  /// 已进入「跳过打字机」模式时静默忽略后续 chunk（不触发 UI 重建），
  /// 完整内容由生成完毕后的 ReplySucceeded 一次性写入消息列表。
  /// 注意：不能在此处触发取消生成——那会中止 LLM 生成导致回复截断。
  void appendStreamChunk(String chunk) {
    if (_revealInstant) {
      // 已进入「跳过打字机」模式：静默忽略后续 chunk，
      // 不触发 UI 重建（打字机动画消失）；
      // 完整内容由 LLM 生成完毕后的 ReplySucceeded 一次性写入消息列表。
      // 注意：不能在此处调用 cancelGeneration()——那会中止 LLM 生成，
      // 导致回复被截断。
    } else {
      _streaming.append(chunk, _applyStreamChunk);
    }
  }

  /// 提交缓冲中的流式内容到状态。
  void flushStreamBuffer() {
    _streaming.flush(_applyStreamChunk);
  }

  /// 立即显示全部流式内容（跳过剩余打字机动画）。
  ///
  /// 触发时机：用户点击「⏩ 显示全文」。
  ///
  /// 打字机效果的真实来源是 LLM 经 SSE 逐 chunk 返回内容（而非 UI 节流），
  /// 「跳过打字机」的正确语义是**停止 UI 逐字更新**，而非**中止 LLM 生成**。
  /// 因此：
  ///   1. 立即 flush 当前已到达的流式内容到 UI（用户立刻看到已有全文）
  ///   2. 置位 `_revealInstant`——后续 chunk 静默忽略，UI 不再逐字跳动
  ///   3. LLM 继续在后台完整生成，结束后由 ReplySucceeded 携带完整
  ///      `reply` 一次性写入消息列表，保证内容不截断
  void revealStreaming() {
    _revealInstant = true;
    flushStreamBuffer();
  }

  /// 新一轮生成前复位流式状态（清空累积器 + 复位「显示全文」标志）。
  ///
  /// 避免旧一轮的跳过打字机状态泄漏到新一轮。
  void resetStreamingForNewRound() {
    _revealInstant = false;
    _streaming.reset();
  }

  /// 释放节流定时器（Notifier dispose 时调用，防止泄漏）。
  void disposeStreaming() {
    _streaming.dispose();
  }

  /// 将累积的流式内容写入状态（StringBuffer 累积 → 一次性 toString）。
  ///
  /// 由混入方实现：`state = state.copyWith(streamingContent: fullContent)`。
  void applyStreamingContent(String fullContent);

  /// 将待提交内容写入累积器并返回完整拼接结果，随后调用
  /// [applyStreamingContent] 写回状态。
  void _applyStreamChunk(String pending) {
    applyStreamingContent(_streaming.applyAndGet(pending));
  }
}
