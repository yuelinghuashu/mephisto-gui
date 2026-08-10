import 'dart:async';

/// 流式输出节流合并缓冲
///
/// LLM SSE 以 chunk 高频到达，若每 chunk 都触发 Riverpod 通知，
/// 会导致 UI 频繁重建（尤其在 50ms 内几十个 chunk 的场景）。
/// 本类在指定窗口内累积所有 chunk，窗口结束时统一提交一次，
/// 显著减少通知次数。
///
/// 被单角色 [NarrativeNotifier] 与多角色 [StageNarrativeNotifier]
/// 共享使用，消除两者之间约 50 行的重复实现。
class StreamThrottleBuffer {
  /// 流式输出节流合并缓冲的累积窗口
  final Duration flushInterval;

  /// 流式输出节流合并缓冲（窗口内累积后一次性提交）
  final StringBuffer _buffer = StringBuffer();

  /// 流式输出节流定时器
  Timer? _timer;

  /// 当前缓冲中是否还有未提交的内容
  bool get isDirty => _buffer.isNotEmpty;

  StreamThrottleBuffer({
    this.flushInterval = const Duration(milliseconds: 50),
  });

  /// 追加流式 chunk：累积到缓冲，按 [flushInterval] 节流窗口统一提交。
  ///
  /// [onFlush] 在窗口结束时被调用，携带窗口内累积的全部内容。
  void addChunk(String chunk, void Function(String pending) onFlush) {
    _buffer.write(chunk);
    // 定时器语义是「最后一片 chunk 后 flushInterval 提交」
    _timer ??= Timer(flushInterval, () => flush(onFlush));
  }

  /// 立即提交缓冲中的流式内容（不等待窗口结束）。
  ///
  /// 在生成结束时须显式调用，确保剩余缓冲内容不丢失。
  void flush(void Function(String pending) onFlush) {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) return;
    final pending = _buffer.toString();
    _buffer.clear();
    onFlush(pending);
  }

  /// 清空缓冲与定时器（Notifier dispose 时调用，防止泄漏）。
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
  }
}
