import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/memory/memory_manager.dart';

/// MemoryManager 记忆管理测试
///
/// 覆盖不依赖真实 LLM 的逻辑：
///   - maybeExtract 的间隔触发规则
///   - extract 空历史处理
///   - LLM 调用失败时静默回退原记忆（指向不可连接地址 → 快速失败 → catch 路径）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 注入不可连接的 LLM 配置，保证请求快速失败且不依赖本地环境
  const offlineConfig = LlmConfig(
    baseUrl: 'http://127.0.0.1:1',
    model: 'test',
  );
  const manager = MemoryManager();

  group('maybeExtract 间隔触发', () {
    test('round=0 不触发', () async {
      final result = await manager.maybeExtract(
        history: const [],
        memories: const [],
        config: offlineConfig,
      );
      expect(result, isNull);
    });

    test('round 不是 extractInterval 倍数不触发', () async {
      final history = List.generate(4, (i) => HistoryEntry(
            role: i.isEven ? MessageRole.fate : MessageRole.assistant,
            content: '第$i轮',
          ));
      // 4 轮中有 2 个 fate（round=2），extractInterval=3，不是 3 的倍数
      final result = await manager.maybeExtract(
        history: history,
        memories: const [],
        config: offlineConfig,
      );
      expect(result, isNull);
    });

    test('round 是 extractInterval 倍数时触发 extract', () async {
      final history = List.generate(6, (i) => HistoryEntry(
            role: i.isEven ? MessageRole.fate : MessageRole.assistant,
            content: '第$i轮',
          ));
      // 6 轮中有 3 个 fate（round=3），extractInterval=3，触发
      final result = await manager.maybeExtract(
        history: history,
        memories: const [],
        config: offlineConfig,
      );
      // 不可连接 → 静默回退原记忆（空列表）
      expect(result, isEmpty);
    });
  });

  group('compress 压缩', () {
    test('未超过 maxLimit 时直接返回原列表', () async {
      final memories = List.generate(10, (i) => Memory(content: '记忆$i'));
      final result = await manager.compress(memories, config: offlineConfig);
      // 数量 ≤ 30 → 不触发压缩，返回原列表
      expect(result, same(memories));
      expect(result.length, 10);
    });

    test('超过 maxLimit 但 LLM 失败时静默回退原列表', () async {
      final memories = List.generate(
        MemoryManager.maxLimit + 1,
        (i) => Memory(content: '记忆$i'),
      );
      final result = await manager.compress(memories, config: offlineConfig);
      // 超限会构造压缩提示，但不可连接 → 静默回退原列表（不抛异常）
      expect(result, same(memories));
      expect(result.length, MemoryManager.maxLimit + 1);
    });
  });

  group('extract', () {
    test('空历史返回原记忆', () async {
      final memories = [Memory(content: '已有记忆')];
      final result = await manager.extract(
        history: const [],
        memories: memories,
        config: offlineConfig,
      );
      expect(result, same(memories));
    });

    test('LLM 失败静默回退原记忆（无异常抛出）', () async {
      final memories = [Memory(content: '既有记忆')];
      final result = await manager.extract(
        history: const [
          HistoryEntry(role: MessageRole.fate, content: '继续探索'),
          HistoryEntry(role: MessageRole.assistant, content: '浮士德沉默'),
        ],
        memories: memories,
        config: offlineConfig,
      );
      // 不可连接 → 网络请求失败 → catch 返回原列表
      expect(result, same(memories));
    });
  });
}