import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/services/parser/meph_formatter.dart';
import 'package:mephisto/services/parser/meph_parser.dart';

/// Mephisto 契约格式化器测试
///
/// 移植自 vscode-mephisto 插件的 `src/test/formatting.test.ts`，
/// 验证：缩进、空行压缩、列表/键值规整、规则行规范化、运算符空格自动修复。
void main() {
  group('格式化 - 基础结构', () {
    test('区块标题顶格，内容缩进 2 空格', () {
      final input = [
        '【角色名】',
        '测试角色',
        '【状态】',
        '- 生命值: 100',
        '- 等级: 1',
      ].join('\n');

      final formatted = formatMephText(input);
      final lines = formatted.split('\n');

      expect(lines[0], '【角色名】');
      expect(lines[1], '  测试角色');
      expect(lines[2], '【状态】');
    });

    test('词法错误时不格式化（区块外游离内容）', () {
      const invalid = '游离内容\n【角色名】\n测试角色';
      final formatted = formatMephText(invalid);
      expect(formatted, invalid, reason: '解析错误时应不动作');
    });

    test('注释行保留并缩进', () {
      final input = [
        '【角色名】',
        '# 这是一个注释',
        '测试角色',
      ].join('\n');

      final formatted = formatMephText(input);
      final lines = formatted.split('\n');

      expect(lines[1], '  # 这是一个注释');
    });

    test('压缩多余缩进', () {
      final input = [
        '【角色名】',
        '    测试角色（缩进过多）',
      ].join('\n');

      final formatted = formatMephText(input);
      final lines = formatted.split('\n');

      expect(lines[1], '  测试角色（缩进过多）');
    });

    test('连续空行压缩为单个，区块间统一分隔', () {
      final input = [
        '【角色名】',
        '测试角色',
        '',
        '',
        '',
        '【状态】',
        '- 生命值: 100',
        '',
        '',
        '【规则】',
        '[攻击] if true -> attack',
      ].join('\n');

      final formatted = formatMephText(input);
      final lines = formatted.split('\n');

      final roleIdx = lines.indexWhere((l) => l.contains('角色名'));
      final stateIdx = lines.indexWhere((l) => l.contains('状态'));
      final ruleIdx = lines.indexWhere((l) => l.contains('规则'));

      expect(stateIdx - roleIdx, 3, reason: '【角色名】与【状态】间应有 1 空行');
      expect(ruleIdx - stateIdx, 3, reason: '【状态】与【规则】间应有 1 空行');
    });
  });

  group('格式化 - 内容行规范化', () {
    test('列表项 - 后单空格、键值冒号后单空格', () {
      final input = [
        '【状态】',
        '-    灵魂完整度：  50',
        '-   体力:   100',
      ].join('\n');

      final formatted = formatMephText(input);
      final lines = formatted.split('\n');

      expect(lines[1], '  - 灵魂完整度： 50');
      expect(lines[2], '  - 体力: 100');
    });
  });

  group('格式化 - 规则行规范化', () {
    test('修复 ]if 缺失空格与多余空格', () {
      final input = [
        '【规则】',
        '[梅菲斯特]if包含 "契约" || 包含 "代价" -> 注入 "内容"',
        '[灵魂代价]  if  包含 "代价" -> 注入 "内容"',
      ].join('\n');

      final formatted = formatMephText(input);
      final lines = formatted.split('\n');

      expect(lines[1], contains('[梅菲斯特] if'));
      expect(lines[2], contains('[灵魂代价] if 包含'));
    });

    test('规则行空白规整与运算符空格', () {
      final input = [
        '【规则】',
        '[梅菲斯特]    if  包含   "梅菲斯特"  ||  包含   "契约"   ->   注入  "测试"',
      ].join('\n');

      final formatted = formatMephText(input);
      final lines = formatted.split('\n');
      final ruleLine = lines[1];

      expect(ruleLine.startsWith('  ['), isTrue, reason: '规则行应缩进');
      expect(ruleLine, contains('if 包含'));
      expect(ruleLine, contains('"梅菲斯特" ||'));
      expect(ruleLine, contains('|| 包含'));
      expect(ruleLine, contains('-> 注入'));
      expect(ruleLine, contains('梅菲斯特"'), reason: '字符串内容应保留');
    });

    test('全密集规则行自动补全空格', () {
      final input = ['【规则】', '[测试]if包含"内容"||包含"其他"->注入"测试"'].join('\n');

      final formatted = formatMephText(input);
      final ruleLine = formatted.split('\n')[1];

      expect(ruleLine, contains('] if'));
      expect(ruleLine, contains('if 包含'));
      expect(ruleLine, contains('"内容" ||'));
      expect(ruleLine, contains('|| 包含'));
      expect(ruleLine, contains('-> 注入'));
    });

    test('赋值号 = 前后补空格', () {
      final input = ['【规则】', '[测试] if true -> 注入 "内容" && 状态.位置=天堂'].join('\n');

      final formatted = formatMephText(input);
      final ruleLine = formatted.split('\n')[1];

      expect(ruleLine, contains('状态.位置 = 天堂'));
    });

    test('复合赋值运算符保持整体（+= -= *=）', () {
      final input = [
        '【规则】',
        '[梅菲斯特] if 状态.生命>=10 && 状态.生命+=10 -> 注入 "测试"',
        '[灵魂代价] if 状态.魔力-=5 && 状态.体力*=2 -> 注入 "内容"',
      ].join('\n');

      final formatted = formatMephText(input);
      final ruleLine1 = formatted.split('\n')[1];
      final ruleLine2 = formatted.split('\n')[2];

      expect(ruleLine1, contains('状态.生命 >= 10'));
      expect(ruleLine1, contains('状态.生命 += 10'));
      expect(ruleLine1, isNot(contains('+ =')));
      expect(ruleLine2, contains('状态.魔力 -= 5'));
      expect(ruleLine2, contains('状态.体力 *= 2'));
      expect(ruleLine2, isNot(contains('- =')));
    });

    test('被空格拆开的比较运算符自动合并（< = → <=）', () {
      final input = [
        '【规则】',
        '[梅菲斯特] if 状态.生命 < = 10 && 状态.攻击 > = 5 && 状态.等级 = = 3 && 状态.魔力 ! = 0 -> 注入 "测试"',
        '[灵魂代价] if 状态.位置 = 天堂 -> 注入 "内容"',
      ].join('\n');

      final formatted = formatMephText(input);
      final ruleLine1 = formatted.split('\n')[1];
      final ruleLine2 = formatted.split('\n')[2];

      expect(ruleLine1, contains('状态.生命 <= 10'));
      expect(ruleLine1, contains('状态.攻击 >= 5'));
      expect(ruleLine1, contains('状态.等级 == 3'));
      expect(ruleLine1, contains('状态.魔力 != 0'));
      expect(ruleLine1, isNot(contains('< =')));
      expect(ruleLine2, contains('状态.位置 = 天堂'));
    });

    test('被空格拆开的复合赋值运算符自动合并（- = → -=），单独减号不受影响', () {
      final input = [
        '【规则】',
        '[梅菲斯特] if 状态.生命 - = 10 -> 注入 "测试"',
        '[灵魂代价] if 状态.魔力 + = 5 && 状态.体力 - 10 -> 注入 "内容"',
      ].join('\n');

      final formatted = formatMephText(input);
      final ruleLine1 = formatted.split('\n')[1];
      final ruleLine2 = formatted.split('\n')[2];

      expect(ruleLine1, contains('状态.生命 -= 10'));
      expect(ruleLine1, isNot(contains('- =')));
      expect(ruleLine2, contains('状态.魔力 += 5'));
      expect(ruleLine2, contains('状态.体力 - 10'), reason: '单独减法应保持不变');
    });

    test('被空格拆开的 DSL 关键词自动合并（不 包含 → 不包含）', () {
      final input = [
        '【规则】',
        '[梅菲斯特] if   不 包含   "黑暗" -> 注入 "测试"',
        '[灵魂代价] if 包 含 "契约" -> 注入 "内容"',
      ].join('\n');

      final formatted = formatMephText(input);
      final ruleLine1 = formatted.split('\n')[1];
      final ruleLine2 = formatted.split('\n')[2];

      expect(ruleLine1, contains('不包含 "黑暗"'));
      expect(ruleLine1, isNot(contains('不 包含')));
      expect(ruleLine2, contains('包含 "契约"'));
      expect(ruleLine2, isNot(contains('包 含')));
    });

    test('格式化合并关键词空格后可被 parseMeph 解析', () {
      // 原文本含 `不 包含`（parseMeph 会拒绝），格式化后应修复
      final input = [
        '【规则】',
        '[低语] if 不 包含 "真实" -> 注入 "阴影"',
      ].join('\n');

      final formatted = formatMephText(input);
      expect(formatted, contains('不包含 "真实"'));

      final reparsed = parseMeph(formatted);
      expect(reparsed.rules, hasLength(1));
      expect(reparsed.rules.first.condition, contains('不包含 "真实"'));
    });

    test('被空格拆开的注入/状态/roll 关键词自动合并（含 roll 内部空格）', () {
      final input = [
        '【规则】',
        '[注] if 包含 "x" -> 注 入 "阴影"',
        '[状] if 状 态.灵魂完整度 < 30 -> 注入 "低语"',
        '[骰1] if roll (1d100) >= 70 -> 注入 "a"',
        '[骰2] if roll( 1d100) >= 70 -> 注入 "b"',
        '[骰3] if roll(1 d100) >= 70 -> 注入 "c"',
        '[骰4] if roll(1d 100) >= 70 -> 注入 "d"',
      ].join('\n');

      final formatted = formatMephText(input);

      // 格式化应合并被空格拆开的关键词
      expect(formatted, contains('注入 "阴影"'));
      expect(formatted, isNot(contains('注 入')));
      expect(formatted, contains('状态.灵魂完整度'));
      expect(formatted, isNot(contains('状 态.')));
      // roll 各变体全部规范为 roll(1d100)
      expect(formatted, contains('roll(1d100)'));
      expect(formatted, isNot(contains('roll (')));
      expect(formatted, isNot(contains('roll( ')));
      expect(formatted, isNot(contains('1 d100')));
      expect(formatted, isNot(contains('1d 100')));
    });
  });

  group('格式化 - 语义保持', () {
    test('格式化修复运算符空格后 parseMeph 可解析且语义不变', () {
      // 原文本含 `! =` / `+ =`（parseMeph 会拒绝），格式化后应被自动修复
      const sample = '''
【角色名】
测试

【锚点】
- 核心信念: 求知

【状态】
-    灵魂完整度 ：  85

【规则】
[堕落] if   包含 "黑暗" ||   状态.灵魂完整度 < 30 ->  注入 "阴影" && 状态.灵魂完整度 -= 5
[低语] if 状态.位置 ! = "书斋" -> 状态.灵魂完整度 + = 10
''';

      final formatted = formatMephText(sample);
      // 格式化应自动修复被空格拆开的运算符
      expect(formatted, contains('状态.位置 != "书斋"'));
      expect(formatted, contains('状态.灵魂完整度 += 10'));

      // 修复后应能通过 parseMeph 完整解析
      final reparsed = parseMeph(formatted);
      expect(reparsed.roleName, '测试');
      expect(reparsed.anchor, hasLength(1));
      expect(reparsed.rules, hasLength(2));
      expect(reparsed.rules.first.condition, contains('包含 "黑暗"'));
      expect(reparsed.rules.first.action, contains('状态.灵魂完整度 -= 5'));
      expect(reparsed.rules.last.condition, contains('状态.位置 != "书斋"'));
      expect(reparsed.rules.last.action, contains('状态.灵魂完整度 += 10'));
    });
  });
}