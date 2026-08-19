import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/domain/narrative_event.dart';
import 'package:mephisto/domain/narrative_reducer.dart';
import 'package:mephisto/domain/narrative_state.dart';

void main() {
  const contract = Contract(
    roleName: '测试角色',
    state: [StateItem(key: '生命值', value: IntValue(100))],
  );

  NarrativeState base() => NarrativeState(
    contract: contract,
    sourceFileName: 'test.meph',
    currentState: contract.stateMap,
  );

  group('narrativeReducer - 核心状态迁移', () {
    test('MessageSent 追加命运消息并进入生成状态', () {
      final s = narrativeReducer(base(), const MessageSent('你来了'));
      expect(s.messages, hasLength(1));
      expect(s.messages.first.role, MessageRole.fate);
      expect(s.isGenerating, isTrue);
    });

    test('ReplySucceeded 应用新状态 + 回复并清空生成标志', () {
      final s = narrativeReducer(
        narrativeReducer(base(), const MessageSent('攻击')),
        const ReplySucceeded(
          reply: '你挥剑',
          newState: {'生命值': IntValue(90)},
          injectedMemories: [],
          rollInfo: '',
          diceResults: [],
          lastError: '',
        ),
      );
      expect(s.messages, hasLength(2));
      expect(s.messages.last.role, MessageRole.assistant);
      expect(s.currentState['生命值'], const IntValue(90));
      expect(s.isGenerating, isFalse);
    });

    test('ReplySucceeded 携带 rollInfo 时插入系统消息', () {
      final s = narrativeReducer(
        narrativeReducer(base(), const MessageSent('掷骰')),
        const ReplySucceeded(
          reply: '回应',
          newState: {},
          injectedMemories: [],
          rollInfo: '[测试] roll(1d100) = 85/100 ✦',
          diceResults: [],
          lastError: '',
        ),
      );
      expect(s.messages[1].role, MessageRole.system);
    });

    test('GenerationFailed / SessionReset / StateValueSet', () {
      final failed = narrativeReducer(base(), const GenerationFailed('出错了'));
      expect(failed.isGenerating, isFalse);
      expect(failed.lastError, '出错了');

      final reset = narrativeReducer(
        narrativeReducer(
          base(),
          const ContextAttached(fileName: 'a.txt', content: '设定'),
        ),
        const SessionReset(),
      );
      expect(reset.messages, isEmpty);
      // 会话级附加上下文也被清空
      expect(reset.attachedFileNames, isEmpty);
      expect(reset.attachedContexts, isEmpty);

      final set = narrativeReducer(
        base(),
        const StateValueSet(key: '生命值', value: IntValue(50)),
      );
      expect(set.currentState['生命值'], const IntValue(50));
    });

    test('SessionRestored 整体替换为恢复快照', () {
      const restored = Contract(
        roleName: '恢复角色',
        state: [StateItem(key: '等级', value: IntValue(5))],
        history: [HistoryEntry(role: MessageRole.fate, content: '恢复前对话')],
      );
      final s = narrativeReducer(
        base(),
        const SessionRestored(restored: restored, fileName: 'restore.meph'),
      );
      expect(s.contract.roleName, '恢复角色');
      expect(s.sourceFileName, 'restore.meph');
      expect(s.messages, hasLength(1));
      expect(s.currentState['等级'], const IntValue(5));
    });

    test('ContextAttached / ContextRemoved / ContextsCleared', () {
      var s = narrativeReducer(
        base(),
        const ContextAttached(fileName: 'a.txt', content: '设定'),
      );
      expect(s.attachedFileNames, ['a.txt']);
      s = narrativeReducer(s, const ContextRemoved(0));
      expect(s.attachedFileNames, isEmpty);
      s = narrativeReducer(
        s,
        const ContextAttached(fileName: 'b.txt', content: '追加'),
      );
      s = narrativeReducer(s, const ContextsCleared());
      expect(s.attachedContexts, isEmpty);
    });
  });
}
