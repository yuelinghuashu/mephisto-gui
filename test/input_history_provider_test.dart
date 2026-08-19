import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/providers/input_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 输入历史 Provider 单元测试
///
/// 覆盖方案 A1（全局单列表）的关键行为：
///   - 持久化 round-trip：写后重建容器可恢复
///   - 相邻重复去重
///   - 上限 maxHistory 条
///   - 存储键固定、JSON 损坏时安全回退默认值
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 在 ProviderScope 中读取 Notifier。
  InputHistoryNotifier notifierOf(ProviderContainer container) =>
      container.read(inputHistoryProvider.notifier);

  test('初始状态为空列表', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(inputHistoryProvider), isEmpty);
  });

  test('push：追加到列表末尾并持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = notifierOf(container);

    await notifier.push('第一条');
    await notifier.push('第二条');

    expect(container.read(inputHistoryProvider), ['第一条', '第二条']);
  });

  test('push：相邻重复不追加（去重）', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = notifierOf(container);

    await notifier.push('相同');
    await notifier.push('相同'); // 相邻重复 → 忽略
    await notifier.push('不同');

    expect(container.read(inputHistoryProvider), ['相同', '不同']);
  });

  test('push：超过 maxHistory 条时移除最旧条目', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = notifierOf(container);

    for (var i = 1; i <= 6; i++) {
      await notifier.push('第$i条');
    }

    // 上限 5 条，第 1 条被挤出
    expect(container.read(inputHistoryProvider), [
      '第2条',
      '第3条',
      '第4条',
      '第5条',
      '第6条',
    ]);
  });

  test('持久化 round-trip：重建容器后历史仍可恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final container1 = ProviderContainer();
    // 先触发 build 并等待其调度的 load 完全完成，
    // 避免 dispose 时 pending microtask 访问已销毁的 ref
    notifierOf(container1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await notifierOf(container1).push('持久化的历史');
    container1.dispose();

    // 新容器（模拟应用重启）→ AutoLoadNotifier.build 自动从 SharedPreferences 恢复
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    // 必须先 read 触发 build（build 返回默认值），
    // 再等待 load 异步从 SharedPreferences 恢复历史
    notifierOf(container2);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container2.read(inputHistoryProvider), ['持久化的历史']);
  });

  test('存储键固定为 mephisto_input_history', () {
    expect(InputHistoryNotifier.key, 'mephisto_input_history');
  });

  test('JSON 损坏：自动回退默认空列表（不影响主流程）', () async {
    SharedPreferences.setMockInitialValues({
      InputHistoryNotifier.key: '{{ 非法 JSON',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 等待 build 微任务尝试恢复（decode 失败 → catch → 保持默认值）
    await Future<void>.delayed(Duration.zero);

    expect(container.read(inputHistoryProvider), isEmpty);
  });
}
