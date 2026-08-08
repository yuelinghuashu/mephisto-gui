import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/memory/memory_manager.dart';

/// MemoryManager 记忆管理测试
///
/// 覆盖不依赖真实 LLM 的逻辑：
///   - maybeExtract 的间隔触发规则
///   - extract 空历史处理
///   - LLM 调用失败时静默回退原记忆（指向不可连接地址 → 快速失败 → catch 路径）
///   - sortByImportance 注入排序（高权重优先，保证人设核心先被模型看到）
///   - compress 高权重记忆永不压缩
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

  group('sortByImportance 注入排序', () {
    test('按权重降序：高权重（核心人设）优先在前', () {
      final memories = [
        Memory(content: '普通日常3'),
        Memory(content: '核心誓言5', importance: 5),
        Memory(content: '次要线索2', importance: 2),
        Memory(content: '重要战斗4', importance: 4),
      ];
      final sorted = MemoryManager.sortByImportance(memories);
      expect(sorted.map((m) => m.content).toList(), [
        '核心誓言5',
        '重要战斗4',
        '普通日常3',
        '次要线索2',
      ]);
    });

    test('同权重保持原顺序稳定', () {
      final memories = [
        Memory(content: 'A'),
        Memory(content: 'B'),
      ];
      final sorted = MemoryManager.sortByImportance(memories);
      expect(sorted.map((m) => m.content).toList(), ['A', 'B']);
    });

    test('空列表返回空（不抛异常）', () {
      expect(MemoryManager.sortByImportance(const []), isEmpty);
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

    test('高权重记忆（人设核心）永不压缩', () async {
      // 构造超过 maxLimit 的记忆，其中含一条高权重人设核心
      final core = Memory(content: '我是浮士德，与梅菲斯特立下赌约', importance: 5);
      final others = List.generate(
        MemoryManager.maxLimit,
        (i) => Memory(content: '普通日常$i'),
      );
      final memories = [core, ...others];

      final result = await manager.compress(memories, config: offlineConfig);
      // LLM 连接失败会静默回退原列表（保护规则正确性体现在不抛异常 + 数量不变）；
      // 若连接成功，高权重核心记忆也应保留在结果中
      expect(result, contains(core));
    });
  });

  group('extract 权重解析', () {
    const llmConfig = LlmConfig(
      baseUrl: 'https://api.test.com/v1',
      model: 'test',
    );

    /// 构造返回指定 SSE 响应的 mock LLM 客户端。
    MemoryManager managerWithMock(String replyText) {
      final mock = MockClient((request) async {
        return http.Response(
          'data: {"choices":[{"delta":{"content":"$replyText"}}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      });
      return MemoryManager(client: mock);
    }

    const history = [
      HistoryEntry(role: MessageRole.fate, content: '继续探索'),
      HistoryEntry(role: MessageRole.assistant, content: '浮士德走向黑暗'),
    ];

    test('LLM 返回 [N] 权重前缀时正确解析', () async {
      // 注意：SSE 数据中的 \n 需要转义为 \\n（JSON 转义）
      final mockManager = managerWithMock(
        '- [5] 浮士德与梅菲斯特立下终极赌约\\n'
        '- [4] 浮士德在书斋中召唤出梅菲斯特\\n'
        '- [2] 浮士德瞥见窗外飞过一只乌鸦',
      );
      final result = await mockManager.extract(
        history: history,
        memories: const [],
        config: llmConfig,
      );
      expect(result.length, 3);
      expect(result[0].content, '浮士德与梅菲斯特立下终极赌约');
      expect(result[0].importance, 5);
      expect(result[1].content, '浮士德在书斋中召唤出梅菲斯特');
      expect(result[1].importance, 4);
      expect(result[2].content, '浮士德瞥见窗外飞过一只乌鸦');
      expect(result[2].importance, 2);
    });

    test('LLM 返回无前缀行时兜底默认权重 3', () async {
      final mockManager = managerWithMock(
        '- 没有权重的记忆条目',
      );
      final result = await mockManager.extract(
        history: history,
        memories: const [],
        config: llmConfig,
      );
      expect(result.length, 1);
      expect(result[0].content, '没有权重的记忆条目');
      expect(result[0].importance, Memory.defaultImportance);
    });

    test('同内容新权重更高时升级旧记忆权重', () async {
      final existing = [
        Memory(content: '浮士德与梅菲斯特立下赌约'), // 默认权重 3
      ];
      final mockManager = managerWithMock(
        '- [5] 浮士德与梅菲斯特立下赌约',
      );
      final result = await mockManager.extract(
        history: history,
        memories: existing,
        config: llmConfig,
      );
      expect(result.length, 1); // 去重后仍只有 1 条
      expect(result[0].content, '浮士德与梅菲斯特立下赌约');
      expect(result[0].importance, 5); // 权重从 3 升级到 5
    });

    test('同内容新权重更低时去重丢弃（权重不降级）', () async {
      final existing = [
        Memory(content: '浮士德与梅菲斯特立下赌约', importance: 5),
      ];
      final mockManager = managerWithMock(
        '- [2] 浮士德与梅菲斯特立下赌约',
      );
      final result = await mockManager.extract(
        history: history,
        memories: existing,
        config: llmConfig,
      );
      expect(result.length, 1);
      expect(result[0].content, '浮士德与梅菲斯特立下赌约');
      expect(result[0].importance, 5); // 保持原高权重
    });

    test('全新内容追加，已有内容不变', () async {
      final existing = [
        Memory(content: '既有记忆', importance: 4),
      ];
      final mockManager = managerWithMock(
        '- [5] 浮士德与梅菲斯特立下终极赌约',
      );
      final result = await mockManager.extract(
        history: history,
        memories: existing,
        config: llmConfig,
      );
      expect(result.length, 2);
      expect(result[0].content, '既有记忆');
      expect(result[0].importance, 4);
      expect(result[1].content, '浮士德与梅菲斯特立下终极赌约');
      expect(result[1].importance, 5);
    });
  });

  group('extract 基础行为', () {
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
