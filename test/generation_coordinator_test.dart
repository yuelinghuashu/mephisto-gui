import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/providers/generation_coordinator.dart';

/// GenerationCoordinator 取消信号幂等测试
///
/// 覆盖「停止生成」窗口期内的重复点击防护：
///   - 用户快速双击「停止」按钮 → 第二次 [stopGenerating] 不得抛
///     `StateError`（`Completer.complete()` 对已完成信号二次调用会抛错）
///   - 重复 [cancelGeneration] 同样幂等
///   - 生成结束后 [endGeneration] 清空信号引用，后续调用安全
void main() {
  group('GenerationCoordinator 取消信号幂等', () {
    test('stopGenerating 二次调用不抛 StateError（双击停止按钮场景）', () {
      final coordinator = _TestCoordinator();
      coordinator.beginGeneration();
      coordinator.stopGenerating();

      // 第二次调用（窗口期内 _generationCancel 尚未置 null 且已完成）
      // 此前会抛 StateError: "Future already completed"
      expect(coordinator.stopGenerating, returnsNormally);
      expect(coordinator.flushCount, 2);
    });

    test('cancelGeneration 二次调用不抛 StateError', () {
      final coordinator = _TestCoordinator();
      coordinator.beginGeneration();
      coordinator.cancelGeneration();

      expect(coordinator.cancelGeneration, returnsNormally);
    });

    test('endGeneration 后（信号引用已清空）调用 stopGenerating 安全', () {
      final coordinator = _TestCoordinator();
      coordinator.beginGeneration();
      coordinator.stopGenerating();
      coordinator.endGeneration();

      // 信号已置 null：?. 短路，不触发任何操作
      expect(coordinator.stopGenerating, returnsNormally);
      expect(coordinator.flushCount, 2); // 第一次的 flush 仍在
    });

    test('未 beginGeneration 时调用 stopGenerating 安全', () {
      final coordinator = _TestCoordinator();
      expect(coordinator.stopGenerating, returnsNormally);
      expect(coordinator.cancelGeneration, returnsNormally);
    });

    test('beginGeneration 创建全新信号（旧已取消信号不泄漏）', () async {
      final coordinator = _TestCoordinator();
      coordinator.beginGeneration();
      final signal1 = coordinator.generationCancelSignal;
      coordinator.cancelGeneration();
      expect(signal1, isNotNull);
      await signal1; // 已完成信号 await 正常返回

      // 新一轮生成：信号被替换为新 Completer（旧已完成信号被丢弃）
      coordinator.beginGeneration();
      final signal2 = coordinator.generationCancelSignal;
      expect(signal2, isNotNull);
      expect(signal2, isNot(same(signal1)));
      // 新信号尚未完成：await 会挂起（用 timeout 检测不会立即返回）
      var completed = false;
      unawaited(signal2!.then((_) => completed = true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(completed, isFalse);

      coordinator.cancelGeneration();
      await signal2; // 取消后正常完成
    });
  });

  group('dispose 后在途生成短路', () {
    test(
      'disposeGeneration 后 runGeneration 失败收尾不调用 onFailure（不写已释放状态）',
      () async {
        final coordinator = _TestCoordinator();
        coordinator.beginGeneration();
        coordinator.disposeGeneration();

        var failureCalled = false;
        await coordinator.runGeneration(
          userInput: 'x',
          core: (_) async => throw Exception('在途生成异常'),
          onFailure: () => failureCalled = true,
          onError: (_, _) {},
        );

        // 已 dispose → 不再 dispatch 失败事件（状态已释放）
        expect(failureCalled, isFalse);
        // 内部标志仍复位（允许后续正常使用）
        expect(coordinator.canSend(isGenerating: false), isTrue);
      },
    );

    test('disposeGeneration 后 stopGenerating 不再 flush 流式缓冲', () {
      final coordinator = _TestCoordinator();
      coordinator.beginGeneration();
      coordinator.disposeGeneration();

      coordinator.stopGenerating();
      // dispose 后 flush 被短路：onGenerationStop 不被调用
      expect(coordinator.flushCount, 0);
    });

    test(
      'disposeGeneration 后 applyStreamingContent 守卫可见（isGenerationDisposed）',
      () {
        final coordinator = _TestCoordinator();
        expect(coordinator.isGenerationDisposed, isFalse);
        coordinator.disposeGeneration();
        expect(coordinator.isGenerationDisposed, isTrue);
      },
    );
  });
}

class _TestCoordinator with GenerationCoordinator<void> {
  int flushCount = 0;

  @override
  void onGenerationStop() {
    flushCount++;
  }
}
