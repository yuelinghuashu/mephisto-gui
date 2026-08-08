import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/prompt/system_prompt.dart';

/// buildSystemPrompt 提示词渲染测试
void main() {
  const baseContract = Contract(
    roleName: '浮士德',
    anchor: [
      StateItem(key: '风格', value: StringValue('沉思而炽热的求道者')),
      StateItem(key: '年龄', value: StringValue('暮年')),
    ],
    worldview: '一个充满神秘学与契约的世界',
    background: '曾以灵魂换取无限体验的学者',
    opening: '书斋的烛火在夜风中摇曳',
    state: [
      StateItem(key: '灵魂完整度', value: IntValue(50)),
    ],
    rules: [
      Rule(name: '契约激活', condition: '包含 "契约"', action: '状态.灵魂完整度 -= 10', line: 1),
    ],
  );

  test('身份声明为你是角色名', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
    );
    expect(prompt, contains('你是浮士德'));
  });

  test('包含角色设定与背景', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
    );
    expect(prompt, contains('你的背景：曾以灵魂换取无限体验的学者'));
    expect(prompt, contains('作为浮士德，你在这个场景中如何行动和回应？'));
  });

  test('锚点风格被提取为角色修饰', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
    );
    expect(prompt, contains('一个沉思而炽热的求道者的存在'));
  });

  test('背景文字注入', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
    );
    expect(prompt, contains('你的背景：曾以灵魂换取无限体验的学者'));
  });

  test('当前状态渲染（运行时值优先）', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {'灵魂完整度': IntValue(10)},
    );
    expect(prompt, contains('- 灵魂完整度：10'));
    // 运行时值覆盖契约初始值（契约初始值 50 不应出现）
    expect(prompt, isNot(contains('- 灵魂完整度：50')));
  });

  test('记忆注入', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
      memories: [Memory(content: '契约定下：以灵魂换取体验')],
    );
    expect(prompt, contains('- 契约定下：以灵魂换取体验'));
  });

  test('用户自定义约束整体替换默认', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
      narrativeRules: '以冷峻白描叙事',
    );
    expect(prompt, contains('以冷峻白描叙事'));
    // 默认约束不应再出现
    expect(prompt, isNot(contains('禁止只有玩家独角戏')));
  });

  test('未传约束时使用默认约束', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
    );
    expect(prompt, contains('禁止只有玩家独角戏'));
  });

  test('约束在开头和结尾各出现一次', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
      narrativeRules: '以浮士德诗句对白风格输出',
    );
    // 出现两次：开头【格式要求】+ 结尾【要求】
    expect(prompt.split('以浮士德诗句对白风格输出').length - 1, 2);
  });

  test('占位符 {角色名} 被替换', () {
    const contract = Contract(
      roleName: '埃德蒙·唐泰斯',
      worldview: '马赛港口的年轻水手{角色名}',
      background: '{角色名}刚刚远航归来',
    );
    final prompt = buildSystemPrompt(
      contract: contract,
      currentState: const {},
    );
    expect(prompt, contains('马赛港口的年轻水手埃德蒙·唐泰斯'));
    expect(prompt, contains('埃德蒙·唐泰斯刚刚远航归来'));
    expect(prompt, isNot(contains('{角色名}')));
  });

  test('附加上下文注入', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
      attachedContexts: const ['补充设定：书斋的镜子里住着一道影子'],
    );
    expect(prompt, contains('补充设定：书斋的镜子里住着一道影子'));
  });

  test('规则追加展示', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
    );
    expect(prompt, contains('追加规则'));
    expect(prompt, contains('当包含 "契约"时：状态.灵魂完整度 -= 10'));
  });

  test('记忆灌窗裁剪：maxMemories 超限时高权重全部保留 + 低权重按降序补足', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
      memories: [
        Memory(content: '核心誓言', importance: 5),
        Memory(content: '重要战斗', importance: 4),
        Memory(content: '次要线索', importance: 2),
        Memory(content: '普通日常'),
        Memory(content: '边缘细节', importance: 1),
      ],
      maxMemories: 3,
    );
    // 高权重（5、4）必带，且只能再补 1 条权重最高的低权重（3）
    expect(prompt, contains('- 核心誓言'));
    expect(prompt, contains('- 重要战斗'));
    expect(prompt, contains('- 普通日常'));
    // 被裁剪的记忆不在本轮提示词中（仍在存档里，并非遗忘）
    expect(prompt, isNot(contains('- 次要线索')));
    expect(prompt, isNot(contains('- 边缘细节')));
  });

  test('记忆灌窗裁剪：未传 maxMemories 时全部注入（向后兼容）', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
      memories: [
        Memory(content: '核心誓言', importance: 5),
        Memory(content: '普通日常'),
        Memory(content: '边缘细节', importance: 1),
      ],
    );
    expect(prompt, contains('- 核心誓言'));
    expect(prompt, contains('- 普通日常'));
    expect(prompt, contains('- 边缘细节'));
  });

  test('记忆灌窗裁剪：高权重数量超过上限时全部保留（人设核心永不丢弃）', () {
    final prompt = buildSystemPrompt(
      contract: baseContract,
      currentState: const {},
      memories: [
        Memory(content: '誓言一', importance: 5),
        Memory(content: '誓言二', importance: 4),
        Memory(content: '誓言三', importance: 4),
        Memory(content: '普通记忆'),
      ],
      maxMemories: 2,
    );
    // 上限 2 但高权重有 3 条 → 高权重全部保留（宁可超一点也不丢人设核心）
    expect(prompt, contains('- 誓言一'));
    expect(prompt, contains('- 誓言二'));
    expect(prompt, contains('- 誓言三'));
    expect(prompt, isNot(contains('- 普通记忆')));
  });
}
