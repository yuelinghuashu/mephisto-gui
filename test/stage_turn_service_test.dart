import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/llm/client.dart';
import 'package:mephisto/services/stage_turn_service.dart';
import 'package:mephisto/services/storage/stage_repo.dart';

/// StageTurnService 单测：mock LLM 客户端，隔离网络
void main() {
  const contract1 = Contract(
    roleName: '浮士德',
    worldview: '书斋与契约的世界',
    rules: [
      Rule(
        name: '堕落加深',
        condition: '包含 "堕落"',
        action: '状态.堕落指数 += 10',
        line: 1,
      ),
    ],
    state: [StateItem(key: '堕落指数', value: IntValue(50))],
  );
  const contract2 = Contract(
    roleName: '梅菲斯特',
    background: '来自深渊的契约者',
    rules: [
      Rule(name: '注入记忆', condition: '包含 "背叛"', action: '注入 "契约的裂痕"', line: 1),
    ],
  );

  const stage = StageLoaded(
    info: StageInfo(path: '/tmp/stages/test', name: 'test', characterCount: 2),
    characters: [
      StageCharacter(fileName: '浮士德.meph', contract: contract1),
      StageCharacter(fileName: '梅菲斯特.meph', contract: contract2),
    ],
  );

  LlmConfig config = const LlmConfig(
    baseUrl: 'http://localhost:9999',
    model: 'mock',
  );

  // 固定 LLM 返回，记录收到的消息
  final capturedMessages = <List<LlmMessage>>[];
  StageTurnService serviceReturning(String reply) => StageTurnService(
    clientFactory: (config) =>
        MockLlmClient(reply: reply, capturedMessages: capturedMessages),
  );

  final Map<String, Map<String, StateValue>> emptyStates = {};
  final Map<String, List<Memory>> emptyMemories = {};

  test('多角色分节解析：每位角色各自一段回复', () async {
    const reply = '''
【浮士德】
浮士德站在书斋窗前，喃喃道。

【梅菲斯特】
梅菲斯特从阴影中走出。
''';
    final s = serviceReturning(reply);
    final result = await s.generate(
      userInput: '命运降临',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.replies['浮士德'], contains('浮士德站在书斋窗前'));
    expect(result.replies['梅菲斯特'], contains('梅菲斯特从阴影中走出'));
    expect(result.lastError, isEmpty);
  });

  test('角色规则引擎独立运行：各角色状态独立更新', () async {
    final s = serviceReturning('回应');
    final result = await s.generate(
      userInput: '我堕落了',
      stage: stage,
      roleStates: {
        // 每位角色从契约初始状态初始化（与真实打开舞台行为一致）
        '浮士德': const {'堕落指数': IntValue(50)},
        '梅菲斯特': const <String, StateValue>{},
      },
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    // 浮士德的规则触发（堕落指数 +10）；梅菲斯特无相关规则 → 状态不变
    expect(result.newStates['浮士德']!['堕落指数'], const IntValue(60));
    expect(result.newStates['梅菲斯特'], isEmpty);
  });

  test('角色记忆注入独立：仅触发对应角色的规则', () async {
    final s = serviceReturning('回应');
    final result = await s.generate(
      userInput: '背叛的阴影',
      stage: stage,
      roleStates: {
        '浮士德': const {'堕落指数': IntValue(50)},
        '梅菲斯特': const <String, StateValue>{},
      },
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(
      result.injectedMemories['梅菲斯特']!.map((m) => m.content),
      contains('契约的裂痕'),
    );
    // 浮士德无「背叛」规则 → 无注入
    expect(result.injectedMemories['浮士德'], isEmpty);
  });

  test('LLM 异常时回退本地多角色回复并记录错误', () async {
    final s = StageTurnService(clientFactory: (config) => ThrowingLlmClient());
    final result = await s.generate(
      userInput: '为何如此',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.replies.containsKey('浮士德'), isTrue);
    expect(result.replies.containsKey('梅菲斯特'), isTrue);
    expect(result.lastError, contains('LLM 调用失败'));
  });

  test('LLM 返回空时回退本地多角色回复', () async {
    final s = serviceReturning('');
    final result = await s.generate(
      userInput: '契约',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.replies.containsKey('浮士德'), isTrue);
    expect(result.replies.containsKey('梅菲斯特'), isTrue);
  });

  test('历史中系统消息不发送给 LLM', () async {
    capturedMessages.clear();
    final s = serviceReturning('回应');
    await s.generate(
      userInput: '继续',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: [
        Message.fate('第一句'),
        Message.assistant('回应一'),
        Message.system('骰子结算'),
      ],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    final messages = capturedMessages.first;
    // 系统消息不应进入历史（但系统提示词应该存在于 [0]）
    expect(messages.any((m) => m.content == '骰子结算'), isFalse);
    // 系统提示词应包含多角色定义
    expect(messages.first.role, 'system');
    expect(messages.first.content, contains('浮士德'));
    expect(messages.first.content, contains('梅菲斯特'));
  });

  test('上下文窗口：超过 maxHistoryMessages 时只保留最近 N 条', () async {
    capturedMessages.clear();
    final s = serviceReturning('回应');
    final history = [
      Message.fate('第1句'),
      Message.assistant('回应1'),
      Message.fate('第2句'),
      Message.assistant('回应2'),
      Message.fate('第3句'),
    ];
    await s.generate(
      userInput: '本轮',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: history,
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
      maxHistoryMessages: 3,
    );
    final messages = capturedMessages.first;
    // 系统 prompt [0] + 截断后的 3 条历史 + 本轮用户输入 [last]
    expect(messages, hasLength(5));
    expect(messages.map((m) => m.content), contains('第2句'));
    expect(messages.map((m) => m.content), contains('第3句'));
    expect(messages.map((m) => m.content), isNot(contains('第1句')));
  });

  test('LLM 不分节输出时归入首角色段落', () async {
    final s = serviceReturning('整段不分节的叙事文本。');
    final result = await s.generate(
      userInput: '继续',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.replies.containsKey('浮士德'), isTrue);
    expect(result.overflow, contains('整段不分节的叙事文本'));
  });

  test('全景叙事提及分发：一篇小说同时提及多位角色 → 各自获得全文', () async {
    const reply = '浮士德站在书斋窗前喃喃自语。梅菲斯特从阴影中走出，笑道："那么，与我做一场交易如何？"';
    final s = serviceReturning(reply);
    final result = await s.generate(
      userInput: '交易',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    // 两位都被提及 → 各自映射到同一段全文（供 reducer 去重渲染为一条）
    expect(result.replies['浮士德'], contains('浮士德站在书斋窗前'));
    expect(result.replies['梅菲斯特'], contains('梅菲斯特从阴影中走出'));
    expect(result.replies['浮士德'], result.replies['梅菲斯特']);
    // overflow 清空：全文已归位给角色，不会在 UI 重复出现
    expect(result.overflow, isEmpty);
  });

  test('全景叙事提及分发：仅一人被提及 → 仅该角色有戏份', () async {
    final s = serviceReturning('浮士德独自站在书斋窗前。');
    final result = await s.generate(
      userInput: '继续',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.replies.containsKey('浮士德'), isTrue);
    expect(result.replies.containsKey('梅菲斯特'), isFalse);
  });

  test('LLM 仍输出旧分节格式 → 兼容分节解析', () async {
    const reply = '''
【浮士德】
浮士德站在书斋窗前。

【梅菲斯特】
梅菲斯特从阴影中走出。
''';
    final s = serviceReturning(reply);
    final result = await s.generate(
      userInput: '继续',
      stage: stage,
      roleStates: emptyStates,
      roleMemories: emptyMemories,
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    // 旧分节格式：角色名出现在标题中 → 提及归属已覆盖；
    // 各角色的 sections 是分节后的独立文本（标题行被 parseStageMentions 识别为提及）
    expect(result.replies.containsKey('浮士德'), isTrue);
    expect(result.replies.containsKey('梅菲斯特'), isTrue);
  });

  test('空舞台（无角色）不崩溃：不访问 characters.first，返回空结果', () async {
    const emptyStage = StageLoaded(
      info: StageInfo(
        path: '/tmp/stages/empty',
        name: 'empty',
        characterCount: 0,
      ),
      characters: [],
    );
    final s = serviceReturning('一段无法分节的溢出文本');
    final result = await s.generate(
      userInput: '继续',
      stage: emptyStage,
      roleStates: const {},
      roleMemories: const {},
      historyMessages: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    // 空舞台防御：返回空 replies，不抛 RangeError（characters.first）
    expect(result.replies, isEmpty);
    expect(result.newStates, isEmpty);
  });
}

/// 固定返回指定文本的 mock LLM 客户端
class MockLlmClient extends LlmClient {
  final String reply;
  final List<List<LlmMessage>> capturedMessages;

  MockLlmClient({
    required this.reply,
    required this.capturedMessages,
    String? model,
  }) : super(
         apiKey: '',
         baseUrl: 'http://localhost:9999',
         model: model ?? 'mock',
       );

  @override
  Future<String> generateStream({
    required List<LlmMessage> messages,
    required void Function(String chunk) onChunk,
    Duration timeout = const Duration(seconds: 60),
    Future<void>? cancelSignal,
    int maxRetries = defaultMaxRetries,
  }) async {
    capturedMessages.add(messages);
    onChunk(reply);
    return reply;
  }
}

/// 直接抛异常的 mock LLM 客户端
class ThrowingLlmClient extends LlmClient {
  ThrowingLlmClient()
    : super(apiKey: '', baseUrl: 'http://localhost:9999', model: 'mock');

  @override
  Future<String> generateStream({
    required List<LlmMessage> messages,
    required void Function(String chunk) onChunk,
    Duration timeout = const Duration(seconds: 60),
    Future<void>? cancelSignal,
    int maxRetries = defaultMaxRetries,
  }) async {
    throw Exception('mock 网络错误');
  }
}
