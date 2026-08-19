import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/prompt/stage_system_prompt.dart';
import 'package:mephisto/services/storage/stage_repo.dart';

/// 舞台系统提示词构建测试
void main() {
  const contract1 = Contract(
    roleName: '浮士德',
    worldview: '书斋与契约的世界',
    background: '穷尽一生求道的学者',
    state: [StateItem(key: '灵魂完整度', value: IntValue(80))],
  );
  const contract2 = Contract(
    roleName: '梅菲斯特',
    anchor: [StateItem(key: '风格', value: StringValue('狡黠的契约者'))],
    background: '来自深渊的契约者',
  );

  const stage = StageLoaded(
    info: StageInfo(
      path: '/tmp/stages/浮士德与梅菲斯特',
      name: '浮士德与梅菲斯特',
      characterCount: 2,
    ),
    characters: [
      StageCharacter(fileName: '浮士德.meph', contract: contract1),
      StageCharacter(fileName: '梅菲斯特.meph', contract: contract2),
    ],
  );

  test('包含两位角色定义与公共世界观', () {
    final prompt = buildStageSystemPrompt(
      stage: stage,
      roleStates: const {},
      roleMemories: const {},
    );
    expect(prompt, contains('你同时扮演以下 2 位角色'));
    expect(prompt, contains('你是浮士德。'));
    expect(prompt, contains('你是梅菲斯特。'));
    expect(prompt, contains('书斋与契约的世界'));
  });

  test('角色状态独立注入', () {
    final prompt = buildStageSystemPrompt(
      stage: stage,
      roleStates: const {
        '浮士德': {'灵魂完整度': IntValue(80)},
      },
      roleMemories: const {},
    );
    expect(prompt, contains('灵魂完整度：80'));
  });

  test('角色记忆独立注入 + 按重要性排序', () {
    final prompt = buildStageSystemPrompt(
      stage: stage,
      roleStates: const {},
      roleMemories: {
        '浮士德': [
          Memory(content: '低权重记忆', importance: 2),
          Memory(content: '高权重记忆', importance: 4),
        ],
      },
    );
    final faustIndex = prompt.indexOf('浮士德');
    final mephistoIndex = prompt.indexOf('梅菲斯特');
    expect(faustIndex, lessThan(mephistoIndex));
    // 浮士德记忆在自己的区块内
    expect(prompt.indexOf('高权重记忆'), lessThan(prompt.indexOf('低权重记忆')));
  });

  test('maxMemories 裁剪超出上限的记忆', () {
    final prompt = buildStageSystemPrompt(
      stage: stage,
      roleStates: const {},
      roleMemories: {
        '浮士德': [
          Memory(content: '记忆1'),
          Memory(content: '记忆2', importance: 5),
          Memory(content: '记忆3', importance: 2),
        ],
      },
      maxMemories: 2,
    );
    // 高权重(5)必带 + 次高(3)补足 → 记忆2 和 记忆1 注入
    expect(prompt, contains('记忆2'));
    expect(prompt, contains('记忆1'));
    expect(prompt, isNot(contains('记忆3')));
  });

  test('输出格式区块列出所有角色名（全景叙事流）', () {
    final prompt = buildStageSystemPrompt(
      stage: stage,
      roleStates: const {},
      roleMemories: const {},
    );
    expect(prompt, contains('【输出格式】'));
    // v2：不再要求 `【角色名】` 分节，而是列出舞台角色名供叙述自然调用
    expect(prompt, contains('浮士德、梅菲斯特'));
    expect(prompt, contains('严禁使用 `【角色名】` 等方括号标记分节'));
  });

  test('自定义叙事约束整体替换默认约束', () {
    const custom = '【自定义约束】自定义规则内容';
    final prompt = buildStageSystemPrompt(
      stage: stage,
      roleStates: const {},
      roleMemories: const {},
      narrativeRules: custom,
    );
    expect(prompt, contains('【自定义约束】'));
    expect(prompt, isNot(contains('【分节要求】')));
  });

  test('附加上下文注入', () {
    final prompt = buildStageSystemPrompt(
      stage: stage,
      roleStates: const {},
      roleMemories: const {},
      attachedContexts: const ['黄金时代的魔法学院'],
    );
    expect(prompt, contains('黄金时代的魔法学院'));
  });
}
