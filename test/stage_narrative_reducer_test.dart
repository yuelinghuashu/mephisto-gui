import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/domain/stage_models.dart';
import 'package:mephisto/domain/stage_narrative_event.dart';
import 'package:mephisto/domain/stage_narrative_reducer.dart';
import 'package:mephisto/domain/stage_narrative_state.dart';

/// 舞台叙事 Reducer 纯函数测试
void main() {
  const stage = StageLoaded(
    info: StageInfo(path: '/tmp/stages/test', name: 'test', characterCount: 2),
    characters: [
      StageCharacter(
        fileName: '浮士德.meph',
        contract: Contract(
          roleName: '浮士德',
          state: [StateItem(key: '灵魂完整度', value: IntValue(80))],
        ),
      ),
      StageCharacter(
        fileName: '梅菲斯特.meph',
        contract: Contract(roleName: '梅菲斯特', background: '来自深渊的契约者'),
      ),
    ],
  );

  test('StageLoaded：初始化各角色状态', () {
    final next = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: {
          '浮士德': {'灵魂完整度': IntValue(80)},
          '梅菲斯特': <String, StateValue>{},
        },
      ),
    );
    expect(next.stageName, 'test');
    expect(next.characterCount, 2);
    expect(next.roles['浮士德']!.currentState['灵魂完整度'], const IntValue(80));
    expect(next.roles['梅菲斯特']!.currentState, isEmpty);
    expect(next.isGenerating, isFalse);
  });

  test('StageLoaded：共享消息流取各角色最长历史重建（不丢其他角色历史）', () {
    // 第一个角色历史短（1 条），第二个角色历史长（3 条）——
    // 修复前只取第一个角色历史 → 丢失 2 条；修复后应取最长的那份
    final stageWithUnevenHistories = StageLoaded(
      info: stage.info,
      characters: const [
        StageCharacter(
          fileName: '浮士德.meph',
          contract: Contract(
            roleName: '浮士德',
            history: [
              HistoryEntry(role: MessageRole.fate, content: '第一轮指引'),
            ],
          ),
        ),
        StageCharacter(
          fileName: '梅菲斯特.meph',
          contract: Contract(
            roleName: '梅菲斯特',
            history: [
              HistoryEntry(role: MessageRole.fate, content: '第一轮指引'),
              HistoryEntry(role: MessageRole.assistant, content: '【浮士德】浮士德回应。'),
              HistoryEntry(role: MessageRole.assistant, content: '【梅菲斯特】梅菲斯特回应。'),
            ],
          ),
        ),
      ],
    );

    final next = stageNarrativeReducer(
      const StageNarrativeState(),
      StageLoadedEvent(
        stage: stageWithUnevenHistories,
        stagePath: '/tmp/stages/test',
        initialStates: <String, Map<String, StateValue>>{},
      ),
    );
    // 应从历史最长（3 条）的角色重建，而不是只有第一条
    expect(next.messages, hasLength(3));
    expect(next.messages.first.content, '第一轮指引');
    expect(next.messages[1].content, contains('浮士德'));
    expect(next.messages[2].content, contains('梅菲斯特'));
  });

  test('StageMessageSent：追加命运消息 + 进入生成状态', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: <String, Map<String, StateValue>>{},
      ),
    );
    final sent = stageNarrativeReducer(loaded, const StageMessageSent('继续前行'));
    expect(sent.messages, hasLength(1));
    expect(sent.messages.first.role, MessageRole.fate);
    expect(sent.messages.first.content, '继续前行');
    expect(sent.isGenerating, isTrue);
  });

  test('完整共享流镜像：fate + 所有角色段落写入每个角色的 history', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: {
          '浮士德': {'灵魂完整度': IntValue(80)},
          '梅菲斯特': <String, StateValue>{},
        },
      ),
    );
    // 1. 用户发消息：fate 应镜像到所有角色 history
    final sent = stageNarrativeReducer(loaded, const StageMessageSent('继续前行'));
    expect(sent.roles['浮士德']!.history, hasLength(1));
    expect(sent.roles['浮士德']!.history[0].role, MessageRole.fate);
    expect(sent.roles['浮士德']!.history[0].content, '继续前行');
    expect(sent.roles['梅菲斯特']!.history, hasLength(1));
    expect(sent.roles['梅菲斯特']!.history[0].content, '继续前行');

    // 2. AI 回复：所有角色段落镜像到每个角色 history
    final replied = stageNarrativeReducer(
      sent,
      const StageReplySucceeded(
        replies: {
          '浮士德': '浮士德回应。',
          '梅菲斯特': '梅菲斯特回应。',
        },
        newStates: {
          '浮士德': {'灵魂完整度': IntValue(70)},
          '梅菲斯特': <String, StateValue>{},
        },
        injectedMemories: {
          '浮士德': <Memory>[],
          '梅菲斯特': <Memory>[],
        },
        overflow: '',
        rollInfo: '',
        diceResults: [],
        lastError: '',
      ),
    );

    // 每个角色 history = [fate, 浮士德段, 梅菲斯特段]（完整共享流）
    for (final roleName in ['浮士德', '梅菲斯特']) {
      final history = replied.roles[roleName]!.history;
      expect(history, hasLength(3));
      expect(history[0].role, MessageRole.fate);
      expect(history[0].content, '继续前行');
      expect(history[1].role, MessageRole.assistant);
      expect(history[1].content, contains('【浮士德】'));
      expect(history[2].role, MessageRole.assistant);
      expect(history[2].content, contains('【梅菲斯特】'));
    }

    // 3. 用任一角色 history 重建消息流 → 完整重现（fate + 双段）
    final rebuilt = stageHistoryToMessages(
      replied.roles['梅菲斯特']!.history,
    );
    expect(rebuilt, hasLength(3));
    expect(rebuilt[0].role, MessageRole.fate);
    expect(rebuilt[1].content, contains('浮士德'));
    expect(rebuilt[2].content, contains('梅菲斯特'));
  });

  test('StageReplySucceeded：各角色状态/记忆独立更新 + 消息追加', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: {
          '浮士德': {'灵魂完整度': IntValue(80)},
          '梅菲斯特': <String, StateValue>{},
        },
      ),
    );
    final replied = stageNarrativeReducer(
      loaded,
      StageReplySucceeded(
        replies: {'浮士德': '浮士德站在书斋窗前。', '梅菲斯特': '梅菲斯特从阴影中走出。'},
        newStates: {
          '浮士德': const {'灵魂完整度': IntValue(70)},
          '梅菲斯特': const <String, StateValue>{},
        },
        injectedMemories: {
          '浮士德': [Memory(content: '契约定下', importance: 4)],
          '梅菲斯特': const <Memory>[],
        },
        overflow: '',
        rollInfo: '',
        diceResults: const [],
        lastError: '',
      ),
    );
    expect(replied.isGenerating, isFalse);
    // 状态更新
    expect(replied.roles['浮士德']!.currentState['灵魂完整度'], const IntValue(70));
    // 记忆注入
    expect(
      replied.roles['浮士德']!.memories.map((m) => m.content),
      contains('契约定下'),
    );
    // 消息追加：2 段角色回复（各以【角色名】开头）
    expect(replied.messages, hasLength(2));
    expect(replied.messages.last.content, contains('【梅菲斯特】'));
    // history 镜像完整共享流：每个角色都记录本轮**所有**角色段落（而非只自己的）
    expect(replied.roles['浮士德']!.history, hasLength(2));
    expect(replied.roles['梅菲斯特']!.history, hasLength(2));
    expect(replied.roles['浮士德']!.history[0].content, contains('【浮士德】'));
    expect(replied.roles['浮士德']!.history[1].content, contains('【梅菲斯特】'));
    expect(replied.roles['梅菲斯特']!.history[0].content, contains('【浮士德】'));
    expect(replied.roles['梅菲斯特']!.history[1].content, contains('【梅菲斯特】'));
  });

  test('StageReplySucceeded：无戏份角色不分段', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: <String, Map<String, StateValue>>{},
      ),
    );
    final replied = stageNarrativeReducer(
      loaded,
      const StageReplySucceeded(
        replies: {'浮士德': '浮士德独白。'},
        newStates: {'浮士德': <String, StateValue>{}},
        injectedMemories: {'浮士德': <Memory>[]},
        overflow: '',
        rollInfo: '',
        diceResults: [],
        lastError: '',
      ),
    );
    expect(replied.messages, hasLength(1));
    expect(replied.messages.first.content, contains('【浮士德】'));
  });

  test('StageReplySucceeded：多角色共享全景文本 → 只渲染一条（去重）', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: <String, Map<String, StateValue>>{},
      ),
    );
    // v2 全景叙事：两个角色被提及，turn service 给两者映射同一段全文
    const sharedText =
        '浮士德站在书斋窗前喃喃自语。梅菲斯特从阴影中走出，笑道："那么，让我与你做一场交易如何？"';
    final replied = stageNarrativeReducer(
      loaded,
      const StageReplySucceeded(
        replies: {'浮士德': sharedText, '梅菲斯特': sharedText},
        newStates: <String, Map<String, StateValue>>{},
        injectedMemories: <String, List<Memory>>{},
        overflow: '',
        rollInfo: '',
        diceResults: [],
        lastError: '',
      ),
    );
    // 只生成一条全景消息（不重复渲染两位角色的相同气泡）
    expect(replied.messages, hasLength(1));
    expect(replied.messages.first.content, sharedText);
    // roleTag 为空 → UI 以标准气泡渲染（全景视角，不附着单一角色色板）
    expect(replied.messages.first.roleTag, isNull);
    // history 镜像：每位角色都记录这条全景消息（存档可完整重现共享流）
    expect(replied.roles['浮士德']!.history, hasLength(1));
    expect(replied.roles['梅菲斯特']!.history, hasLength(1));
    expect(replied.roles['浮士德']!.history.first.content, sharedText);
  });

  test('StageGenerationFailed：重置生成状态 + 记录错误', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: <String, Map<String, StateValue>>{},
      ),
    );
    final failed = stageNarrativeReducer(
      loaded,
      const StageGenerationFailed('provider.generation_failed'),
    );
    expect(failed.isGenerating, isFalse);
    expect(failed.lastError, 'provider.generation_failed');
  });

  test('StageSessionReset：清空动态数据保留舞台', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: {
          '浮士德': {'灵魂完整度': IntValue(80)},
          '梅菲斯特': <String, StateValue>{},
        },
      ),
    );
    final reset = stageNarrativeReducer(loaded, const StageSessionReset());
    expect(reset.stage, isNotNull);
    expect(reset.roles['浮士德']!.currentState['灵魂完整度'], const IntValue(80));
    expect(reset.messages, isEmpty);
    expect(reset.isGenerating, isFalse);
  });

  test('StageContextAttached：多选追加附件上下文', () {
    final next = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageContextAttached(fileName: '设定.txt', content: '世界观补充'),
    );
    expect(next.attachedFileNames, ['设定.txt']);
    expect(next.attachedContexts, ['世界观补充']);

    final second = stageNarrativeReducer(
      next,
      const StageContextAttached(fileName: '人物.md', content: '角色补充'),
    );
    expect(second.attachedFileNames, ['设定.txt', '人物.md']);
    expect(second.attachedContexts, ['世界观补充', '角色补充']);
  });

  test('StageContextRemoved：独立移除指定附件（越界忽略）', () {
    final withTwo = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageContextAttached(fileName: '设定.txt', content: '世界观补充'),
    );
    final added = stageNarrativeReducer(
      withTwo,
      const StageContextAttached(fileName: '人物.md', content: '角色补充'),
    );

    // 移除索引 0：保留索引 1
    final removedFirst = stageNarrativeReducer(
      added,
      const StageContextRemoved(0),
    );
    expect(removedFirst.attachedFileNames, ['人物.md']);
    expect(removedFirst.attachedContexts, ['角色补充']);

    // 越界：状态不变
    final outOfRange = stageNarrativeReducer(
      added,
      const StageContextRemoved(99),
    );
    expect(outOfRange.attachedFileNames, ['设定.txt', '人物.md']);
  });

  test('StageSessionReset：清空动态数据保留舞台（含附件）', () {
    final loaded = stageNarrativeReducer(
      const StageNarrativeState(),
      const StageLoadedEvent(
        stage: stage,
        stagePath: '/tmp/stages/test',
        initialStates: {
          '浮士德': {'灵魂完整度': IntValue(80)},
          '梅菲斯特': <String, StateValue>{},
        },
      ),
    );
    final withAttachment = stageNarrativeReducer(
      loaded,
      const StageContextAttached(fileName: '设定.txt', content: '世界观补充'),
    );
    expect(withAttachment.attachedFileNames, ['设定.txt']);

    final reset = stageNarrativeReducer(
      withAttachment,
      const StageSessionReset(),
    );
    expect(reset.stage, isNotNull);
    expect(reset.roles['浮士德']!.currentState['灵魂完整度'], const IntValue(80));
    expect(reset.messages, isEmpty);
    expect(reset.isGenerating, isFalse);
    expect(reset.attachedFileNames, isEmpty);
    expect(reset.attachedContexts, isEmpty);
  });
}
