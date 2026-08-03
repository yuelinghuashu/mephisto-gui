
import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/llm/client.dart';
import 'package:mephisto/services/narrative_turn_service.dart';

/// NarrativeTurnService 单测：mock LLM 客户端，隔离网络
void main() {
  Contract contract({
    String roleName = '浮士德',
    List<Rule> rules = const [],
    Map<String, StateValue> initialState = const {},
    List<Memory> memories = const [],
  }) {
    return Contract(
      roleName: roleName,
      rules: [
        ...rules,
        const Rule(
          name: '注入记忆',
          condition: '包含 "记忆"',
          action: '注入 "黑暗的种子"',
          line: 1,
        ),
      ],
      state: [
        for (final e in initialState.entries)
          StateItem(key: e.key, value: e.value),
      ],
    );
  }

  LlmConfig config = const LlmConfig(
    baseUrl: 'http://localhost:9999',
    model: 'mock',
  );

  // 固定 LLM 返回，记录收到的消息
  final capturedMessages = <List<LlmMessage>>[];
  NarrativeTurnService serviceReturning(String reply) => NarrativeTurnService(
    clientFactory: (config) => MockLlmClient(
      reply: reply,
      capturedMessages: capturedMessages,
    ),
  );

  test('规则引擎状态变更被写回', () async {
    // 契约规则：输入含"堕落"时堕落指数 +10
    const c = Contract(
      roleName: '浮士德',
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
    final s = serviceReturning('浮士德沉默着。');
    final result = await s.generate(
      userInput: '我堕落了',
      contract: c,
      currentState: const {'堕落指数': IntValue(50)},
      memories: const [],
      priorMessages: const [],
      attachedContexts: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.newState['堕落指数'], const IntValue(60));
    expect(result.reply, '浮士德沉默着。');
    expect(result.lastError, isEmpty);
  });

  test('记忆注入被返回', () async {
    final s = serviceReturning('回应');
    final result = await s.generate(
      userInput: '黑暗的记忆',
      contract: contract(),
      currentState: const {},
      memories: const [],
      priorMessages: const [],
      attachedContexts: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.injectedMemories.map((m) => m.content), ['黑暗的种子']);
  });

  test('骰子判定信息被返回（roll 必然成功）', () async {
    final s = serviceReturning('回应');
    // 用 roll(1d100) >= 1 保证必然成功（1d100 掷出 1~100 恒满足）
    const c2 = Contract(
      roleName: '浮士德',
      rules: [
        Rule(
          name: '命运骰',
          condition: 'roll(1d100) >= 1',
          action: '注入 "命运骰已掷"',
          line: 1,
        ),
      ],
    );
    final result = await s.generate(
      userInput: '掷骰',
      contract: c2,
      currentState: const {},
      memories: const [],
      priorMessages: const [],
      attachedContexts: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.rollInfo, isNotEmpty);
    expect(
      result.injectedMemories.map((m) => m.content),
      contains('命运骰已掷'),
    );
  });

  test('LLM 异常时回退本地回复并记录错误', () async {
    final s = NarrativeTurnService(
      clientFactory: (config) => ThrowingLlmClient(),
    );
    final result = await s.generate(
      userInput: '为何如此',
      contract: contract(),
      currentState: const {},
      memories: const [],
      priorMessages: const [],
      attachedContexts: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.reply, isNotEmpty);
    expect(result.reply, contains('为什么'));
    expect(result.lastError, contains('LLM 调用失败'));
  });

  test('LLM 返回空时回退本地回复', () async {
    final s = serviceReturning('');
    final result = await s.generate(
      userInput: '契约',
      contract: contract(),
      currentState: const {},
      memories: const [],
      priorMessages: const [],
      attachedContexts: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(result.reply, isNotEmpty);
  });

  test('系统消息不出现在发送给 LLM 的历史中', () async {
    capturedMessages.clear();
    final s = serviceReturning('回应');
    await s.generate(
      userInput: '继续',
      contract: contract(),
      currentState: const {},
      memories: const [],
      priorMessages: [
        Message.fate('第一句'),
        Message.assistant('回应一'),
        Message.system('骰子结算'),
      ],
      attachedContexts: const [],
      narrativeRules: '默认',
      config: config,
      onChunk: (_) {},
    );
    expect(capturedMessages, hasLength(1));
    final messages = capturedMessages.first;
    // 系统消息不应进入历史（但 should have system prompt at [0]）
    expect(messages.any((m) => m.content == '骰子结算'), isFalse);
    expect(messages.map((m) => m.role), containsAll(['user', 'assistant']));
  });
}

/// 固定返回指定文本的 mock LLM 客户端
class MockLlmClient extends LlmClient {
  final String reply;
  final List<List<LlmMessage>> capturedMessages;

  MockLlmClient({required this.reply, required this.capturedMessages, String? model})
      : super(
          apiKey: '',
          baseUrl: 'http://localhost:9999',
          model: model ?? 'mock',
        );

  @override
  Future<String> generateStream({
    required List<LlmMessage> messages,
    required void Function(String chunk) onChunk,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    capturedMessages.add(messages);
    onChunk(reply);
    return reply;
  }
}

/// 直接抛异常的 mock LLM 客户端
class ThrowingLlmClient extends LlmClient {
  ThrowingLlmClient()
      : super(
          apiKey: '',
          baseUrl: 'http://localhost:9999',
          model: 'mock',
        );

  @override
  Future<String> generateStream({
    required List<LlmMessage> messages,
    required void Function(String chunk) onChunk,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    throw Exception('mock 网络错误');
  }
}