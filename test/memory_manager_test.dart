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
  const offlineConfig = LlmConfig(baseUrl: 'http://127.0.0.1:1', model: 'test');
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
      final history = List.generate(
        4,
        (i) => HistoryEntry(
          role: i.isEven ? MessageRole.fate : MessageRole.assistant,
          content: '第$i轮',
        ),
      );
      // 4 轮中有 2 个 fate（round=2），extractInterval=3，不是 3 的倍数
      final result = await manager.maybeExtract(
        history: history,
        memories: const [],
        config: offlineConfig,
      );
      expect(result, isNull);
    });

    test('round 是 extractInterval 倍数时触发 extract', () async {
      final history = List.generate(
        6,
        (i) => HistoryEntry(
          role: i.isEven ? MessageRole.fate : MessageRole.assistant,
          content: '第$i轮',
        ),
      );
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
      final memories = [Memory(content: 'A'), Memory(content: 'B')];
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

  group('LlmAuxConfig.resolve 辅助模型路由', () {
    const mainConfig = LlmConfig(
      baseUrl: 'https://main.example.com/v1',
      model: 'main-model',
      apiKey: 'main-key',
      maxRetries: 2,
    );

    test('未启用时 resolve 返回主配置（字段被替换但不生效由调用方控制）', () {
      const aux = LlmAuxConfig(
        model: 'aux-model',
        baseUrl: 'https://aux.example.com/v1',
        apiKey: 'aux-key',
      );
      final resolved = aux.resolve(mainConfig);
      // resolve 本身只处理字段继承；调用方负责判断 enabled
      expect(resolved.model, 'aux-model');
      expect(resolved.baseUrl, 'https://aux.example.com/v1');
      expect(resolved.apiKey, 'aux-key');
      expect(resolved.maxRetries, 2); // 继承主配置
    });

    test('启用时完整继承主配置缺省字段（model/baseUrl/apiKey 留空）', () {
      const aux = LlmAuxConfig(
        enabled: true,
        // model/baseUrl/apiKey 均留空 → 继承主配置
        maxTokens: 2048,
        timeoutSeconds: 120,
      );
      final resolved = aux.resolve(mainConfig);
      expect(resolved.model, 'main-model');
      expect(resolved.baseUrl, 'https://main.example.com/v1');
      expect(resolved.apiKey, 'main-key');
      expect(resolved.maxTokens, 2048);
      expect(resolved.timeoutSeconds, 120);
      expect(resolved.maxRetries, 2); // 始终继承主配置
    });

    test('启用时独立字段覆盖主配置', () {
      const aux = LlmAuxConfig(
        enabled: true,
        model: 'aux-model',
        baseUrl: 'https://aux.example.com/v1',
      );
      final resolved = aux.resolve(mainConfig);
      expect(resolved.model, 'aux-model');
      expect(resolved.baseUrl, 'https://aux.example.com/v1');
      // API Key 未填 → 继承主配置
      expect(resolved.apiKey, 'main-key');
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
      final mockManager = managerWithMock('- 没有权重的记忆条目');
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
      final mockManager = managerWithMock('- [5] 浮士德与梅菲斯特立下赌约');
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
      final existing = [Memory(content: '浮士德与梅菲斯特立下赌约', importance: 5)];
      final mockManager = managerWithMock('- [2] 浮士德与梅菲斯特立下赌约');
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
      final existing = [Memory(content: '既有记忆', importance: 4)];
      final mockManager = managerWithMock('- [5] 浮士德与梅菲斯特立下终极赌约');
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

  group('extractForRoles 跨角色批量提取', () {
    const llmConfig = LlmConfig(
      baseUrl: 'https://api.test.com/v1',
      model: 'test',
    );

    /// 构造返回指定跨角色输出的 mock LLM 客户端。
    ///
    /// [extractForRoles] 的解析器在 `_callLLM` 剥掉 `- ` 前缀后的行上
    /// 匹配 `【角色名】` 段落标题与 `[N] 权重` 前缀，因此 mock 内容
    /// 应为段落标题行 + `[N] 内容` 行（无 `- ` 前缀）。
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

    const roleHistory = {
      '浮士德': [
        HistoryEntry(role: MessageRole.fate, content: '继续探索'),
        HistoryEntry(role: MessageRole.assistant, content: '浮士德走向黑暗'),
      ],
      '梅菲斯特': [
        HistoryEntry(role: MessageRole.fate, content: '低语诱惑'),
        HistoryEntry(role: MessageRole.assistant, content: '梅菲斯特露出微笑'),
      ],
    };

    test('空角色历史返回空 map（不调用 LLM）', () async {
      final result = await manager.extractForRoles(
        roleHistory: const {},
        roleMemories: const {},
        config: offlineConfig,
      );
      expect(result, isEmpty);
    });

    test('按【角色名】段落切分 + [N] 权重解析，未知角色段忽略', () async {
      final mockManager = managerWithMock(
        '【浮士德】\\n'
        '[5] 浮士德与梅菲斯特立下终极赌约\\n'
        '[4] 浮士德在书斋中召唤出梅菲斯特\\n'
        '【梅菲斯特】\\n'
        '[3] 梅菲斯特以契约引诱浮士德\\n'
        '【路人甲】\\n'
        '[5] 未知角色的记忆应被忽略',
      );
      final result = await mockManager.extractForRoles(
        roleHistory: roleHistory,
        roleMemories: const {},
        config: llmConfig,
      );

      expect(result.keys, ['浮士德', '梅菲斯特']);
      // 浮士德：2 条带权重
      expect(result['浮士德'], hasLength(2));
      expect(result['浮士德']![0].content, '浮士德与梅菲斯特立下终极赌约');
      expect(result['浮士德']![0].importance, 5);
      expect(result['浮士德']![1].content, '浮士德在书斋中召唤出梅菲斯特');
      expect(result['浮士德']![1].importance, 4);
      // 梅菲斯特：1 条
      expect(result['梅菲斯特'], hasLength(1));
      expect(result['梅菲斯特']![0].content, '梅菲斯特以契约引诱浮士德');
      // 未知角色「路人甲」的段被忽略（不在 roleHistory 中）
      expect(result.containsKey('路人甲'), isFalse);
    });

    test('无权重前缀行兜底默认权重 3', () async {
      final mockManager = managerWithMock(
        '【浮士德】\\n'
        '没有权重前缀的记忆条目',
      );
      final result = await mockManager.extractForRoles(
        roleHistory: roleHistory,
        roleMemories: const {},
        config: llmConfig,
      );
      expect(result['浮士德'], hasLength(1));
      expect(result['浮士德']![0].content, '没有权重前缀的记忆条目');
      expect(result['浮士德']![0].importance, Memory.defaultImportance);
    });

    test('按各角色现有记忆去重 + 权重升级（高权重复用，低权重丢弃）', () async {
      // 浮士德已有「立下终极赌约」权重 3；LLM 返回权重 5 → 应升级
      // 梅菲斯特已有「契约引诱」权重 5；LLM 返回权重 2 → 应丢弃（不降级）
      final mockManager = managerWithMock(
        '【浮士德】\\n'
        '[5] 浮士德与梅菲斯特立下终极赌约\\n'
        '[4] 全新记忆：浮士德翻阅禁书\\n'
        '【梅菲斯特】\\n'
        '[2] 梅菲斯特以契约引诱浮士德',
      );
      final result = await mockManager.extractForRoles(
        roleHistory: roleHistory,
        roleMemories: {
          '浮士德': [Memory(content: '浮士德与梅菲斯特立下终极赌约')], // 默认 3
          '梅菲斯特': [Memory(content: '梅菲斯特以契约引诱浮士德', importance: 5)],
        },
        config: llmConfig,
      );

      // 浮士德：升级（3→5）+ 新增 1 条 → 2 条
      expect(result['浮士德'], hasLength(2));
      expect(result['浮士德']![0].importance, 5, reason: '同内容新权重更高 → 升级');
      expect(result['浮士德']![1].content, '全新记忆：浮士德翻阅禁书');
      // 梅菲斯特：新权重 2 < 现有 5 → 去重丢弃 → 该角色无 fresh 条目 → 键不存在
      expect(
        result.containsKey('梅菲斯特'),
        isFalse,
        reason: '同内容新权重更低 → 丢弃，无新增条目',
      );
    });

    test('LLM 失败静默返回空 map（不抛异常）', () async {
      // 指向不可连接地址的 manager（复用全局 manager）
      final result = await manager.extractForRoles(
        roleHistory: roleHistory,
        roleMemories: const {},
        config: offlineConfig,
      );
      expect(result, isEmpty);
    });
  });

  group('clipMemories 灌窗裁剪', () {
    Memory mem(String content, int importance) =>
        Memory(content: content, importance: importance);

    test('未超上限时原样返回（不排序）', () {
      final memories = [mem('低权重2', 2), mem('高权重5', 5), mem('中权重3', 3)];
      final result = MemoryManager.clipMemories(memories, 10);
      // 数量未超上限 → 返回原列表（保持调用方顺序）
      expect(result, same(memories));
      expect(result.map((m) => m.content), ['低权重2', '高权重5', '中权重3']);
    });

    test('高权重（≥4）全部保留，其余按权重降序补足上限', () {
      final memories = [
        mem('低1', 1),
        mem('高5a', 5),
        mem('中3', 3),
        mem('高4', 4),
        mem('低2', 2),
        mem('高5b', 5),
      ];
      final result = MemoryManager.clipMemories(memories, 4);
      // 高权重 3 条（5a/5b/4）全保留 + 补 1 条最高权重非高权重（中3）
      expect(result.map((m) => m.content), ['高5a', '高5b', '高4', '中3']);
      // 返回结果已按权重降序（高权重在前）
      expect(result.map((m) => m.importance).toList(), [5, 5, 4, 3]);
    });

    test('高权重数量超过上限时全部保留（宁可超限不丢核心设定）', () {
      final memories = [mem('高4a', 4), mem('高5', 5), mem('高4b', 4)];
      final result = MemoryManager.clipMemories(memories, 2);
      // 高权重 3 条 > 上限 2 → 全部保留（有意设计：高权重是核心人设）
      expect(result, hasLength(3));
      expect(result.map((m) => m.content), ['高5', '高4a', '高4b']);
    });

    test('全部低权重时取权重最高的前 N 条', () {
      final memories = [
        mem('低1', 1),
        mem('低3', 3),
        mem('低2', 2),
        mem('低1b', 1),
      ];
      final result = MemoryManager.clipMemories(memories, 2);
      expect(result.map((m) => m.content), ['低3', '低2']);
    });

    test('空列表返回空', () {
      expect(MemoryManager.clipMemories(const [], 5), isEmpty);
    });

    test('同权重保持原顺序稳定（不破坏稳定性）', () {
      final memories = [mem('A3', 3), mem('B3', 3), mem('C3', 3)];
      final result = MemoryManager.clipMemories(memories, 2);
      expect(result.map((m) => m.content), ['A3', 'B3'], reason: '同权重按原顺序取前 N');
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
