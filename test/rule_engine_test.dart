import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/engine/condition.dart';
import 'package:mephisto/services/engine/dice.dart';
import 'package:mephisto/services/engine/executor.dart';
import 'package:mephisto/services/engine/rule_engine.dart';

void main() {
  group('条件编译缓存', () {
    test('compileCondition 返回可复用的 AST 节点', () {
      // 同一条件字符串重复编译返回同一实例（缓存命中）
      final a = compileCondition('包含 "攻击" || 状态.情绪 == "暴怒"');
      final b = compileCondition('包含 "攻击" || 状态.情绪 == "暴怒"');
      expect(a, same(b));
      expect(a, isA<OrNode>());
    });

    test('编译后 AST 求值与字符串直接求值结果一致', () {
      final state = <String, StateValue>{
        '灵魂完整度': const IntValue(50),
        '情绪': const StringValue('暴怒'),
      };
      // && 优先级高于 ||（与旧字符串求值一致），等价于 (攻击 && 状态>30) || 情绪=="暴怒"
      const cond = '包含 "攻击" && 状态.灵魂完整度 > 30 || 状态.情绪 == "暴怒"';
      final compiled = compileCondition(cond);
      expect(compiled, isNotNull);
      expect(compiled, isA<OrNode>());

      // 编译 AST 求值
      final viaAst = compiled!.eval(input: '我要攻击', state: state);
      // 字符串直接求值（内部同样走编译缓存）
      final viaString = evalCondition(cond, input: '我要攻击', state: state);
      expect(viaAst, viaString);
      expect(viaAst, isTrue);

      // 不匹配场景（输入不匹配 && 情绪不匹配）同样一致
      final state2 = <String, StateValue>{'灵魂完整度': const IntValue(10)};
      final viaAstFalse = compiled.eval(input: '我在防御', state: state2);
      final viaStringFalse = evalCondition(cond, input: '我在防御', state: state2);
      expect(viaAstFalse, viaStringFalse);
      expect(viaAstFalse, isFalse);
    });

    test('无法编译的条件返回 null（评估视为不匹配）', () {
      expect(compileCondition('无法识别语法'), isNull);
      expect(compileCondition('非状态 100'), isNull);
    });

    test('括号分组：整体包裹剥除后递归编译', () {
      // 整个条件被一对括号完整包裹
      final node = compileCondition('(包含 "攻击" || 包含 "战斗")');
      expect(node, isA<OrNode>());
      expect(node!.eval(input: '战斗开始', state: const <String, StateValue>{}), isTrue);
      expect(node.eval(input: '我在休息', state: const <String, StateValue>{}), isFalse);
    });

    test('括号分组：&& 与括号内的 || 组合求值', () {
      const state = <String, StateValue>{};
      // `包含 "深渊" && (包含 "凝视" || 包含 "回望")`
      expect(
        evalCondition(
          '包含 "深渊" && (包含 "凝视" || 包含 "回望")',
          input: '低头望向深渊，深渊也在凝视我',
          state: state,
        ),
        isTrue, // 包含"深渊"且包含"凝视"
      );
      expect(
        evalCondition(
          '包含 "深渊" && (包含 "凝视" || 包含 "回望")',
          input: '我凝视着远方',
          state: state,
        ),
        isFalse, // 不含"深渊"
      );
      expect(
        evalCondition(
          '包含 "深渊" && (包含 "凝视" || 包含 "回望")',
          input: '深渊在我脚下',
          state: state,
        ),
        isFalse, // 含"深渊"但既不含"凝视"也不含"回望"
      );
      // 多个括号分组嵌套
      expect(
        evalCondition(
          '(包含 "a" || 包含 "b") && (包含 "c" || 包含 "d")',
          input: 'b 和 c',
          state: state,
        ),
        isTrue,
      );
    });
  });

  group('条件评估', () {
    test('包含/不包含', () {
      const state = <String, StateValue>{};
      expect(evalCondition('包含 "攻击"', input: '我要攻击', state: state), isTrue);
      expect(evalCondition('包含 "攻击"', input: '我在防御', state: state), isFalse);
      expect(evalCondition('不包含 "真实"', input: '一切都是虚假', state: state), isTrue);
      expect(evalCondition('不包含 "真实"', input: '这是真实', state: state), isFalse);
    });

    test('状态数值比较', () {
      final state = <String, StateValue>{'灵魂完整度': const IntValue(50)};
      expect(evalCondition('状态.灵魂完整度 < 30', input: '', state: state), isFalse);
      expect(evalCondition('状态.灵魂完整度 > 30', input: '', state: state), isTrue);
      expect(evalCondition('状态.灵魂完整度 == 50', input: '', state: state), isTrue);
      expect(evalCondition('状态.灵魂完整度 != 50', input: '', state: state), isFalse);
      expect(evalCondition('状态.灵魂完整度 >= 50', input: '', state: state), isTrue);
      expect(evalCondition('状态.灵魂完整度 <= 49', input: '', state: state), isFalse);
    });

    test('状态字符串比较', () {
      final state = <String, StateValue>{'情绪': const StringValue('暴怒')};
      expect(evalCondition('状态.情绪 == "暴怒"', input: '', state: state), isTrue);
      expect(evalCondition('状态.情绪 != "书斋"', input: '', state: state), isTrue);
      expect(evalCondition('状态.情绪 == "平静"', input: '', state: state), isFalse);
    });

    test('逻辑与/或', () {
      final state = <String, StateValue>{'情绪': const StringValue('暴怒')};
      expect(
        evalCondition('包含 "攻击" || 包含 "战斗"', input: '战斗开始', state: state),
        isTrue,
      );
      expect(
        evalCondition('包含 "攻击" && 状态.情绪 == "暴怒"', input: '攻击', state: state),
        isTrue,
      );
      expect(
        evalCondition('包含 "攻击" && 状态.情绪 == "平静"', input: '攻击', state: state),
        isFalse,
      );
    });

    test('状态不存在返回 false', () {
      const state = <String, StateValue>{};
      expect(evalCondition('状态.不存在 > 10', input: '', state: state), isFalse);
    });
  });

  group('骰子', () {
    test('默认阈值：1d100 >= 50', () {
      final rs = RollStore();
      final (matched, total) = evalRoll('roll(1d100)', rs);
      expect(total, inInclusiveRange(1, 100));
      expect(matched, total >= 50);
    });

    test('1d2 安科二元判定：1 = 成功，2 = 失败', () {
      // 用 RollStore 掷骰并验证判定方向与安科规则一致：
      //   matched ⇔ total == 1（掷出 1 = 成功，掷出 2 = 失败）
      final rs = RollStore();
      final total = rs.roll('roll(1d2)');
      final (matched, _) = evalRoll('roll(1d2)', rs);
      expect(total, inInclusiveRange(1, 2));
      expect(matched, total == 1,
        reason: '安科 1d2 判定：掷出 1 = 成功（是），掷出 2 = 失败（否）');
    });

    test('1d2 自定义阈值：>= 2 表示掷出 2 才成功（显式指定方向）', () {
      final rs = RollStore();
      final (matched1, _) = evalRoll('roll(1d2) >= 1', rs);
      expect(matched1, isTrue, reason: 'roll(1d2) >= 1 永远成功');
      final (matched2, _) = evalRoll('roll(1d2) > 2', rs);
      expect(matched2, isFalse, reason: 'roll(1d2) > 2 永远失败');
    });

    test('自定义阈值：必然成功/必然失败', () {
      final rs = RollStore();
      final (matched1, _) = evalRoll('roll(1d100) >= 1', rs);
      expect(matched1, isTrue);
      final (matched2, _) = evalRoll('roll(1d100) > 100', rs);
      expect(matched2, isFalse);
    });

    test('RollStore 缓存保证同值', () {
      final rs = RollStore();
      final a = rs.roll('roll(1d100)');
      final b = rs.roll('roll(1d100)');
      expect(a, b);
      expect(a, inInclusiveRange(1, 100));

      // 条件判定与提取使用同一骰值
      rs.roll('roll(1d100)');
      final results = extractDiceResults('战斗判定', 'roll(1d100) >= 1', rs);
      expect(results, hasLength(1));
      expect(results.first.ruleName, '战斗判定');
      expect(results.first.expression, 'roll(1d100)');
      expect(results.first.value, rs.get('roll(1d100)'));
      expect(results.first.success, isTrue);
    });
  });

  group('动作执行', () {
    test('注入：追加记忆 + {角色名} 替换', () {
      final state = <String, StateValue>{};
      final memories = <String>[];
      final r = executeAction(
        '注入 "阴影在{角色名}脚边蠕动"',
        input: '',
        state: state,
        memories: memories,
        roleName: '浮士德',
      );
      expect(r, isEmpty);
      expect(memories, ['阴影在浮士德脚边蠕动']);
    });

    test('状态简单赋值', () {
      final state = <String, StateValue>{'心绪': const StringValue('期待')};
      final r = setState('状态.心绪 = "愤懑"', state);
      expect(r, startsWith('📊'));
      expect(state['心绪'], const StringValue('愤懑'));
    });

    test('状态复合赋值（int 保持 int）', () {
      final state = <String, StateValue>{'警惕度': const IntValue(85)};
      setState('状态.警惕度 += 10', state);
      expect(state['警惕度'], const IntValue(95));
      setState('状态.警惕度 -= 5', state);
      expect(state['警惕度'], const IntValue(90));
    });

    test('复合动作：注入 && 状态变更', () {
      final state = <String, StateValue>{'警惕度': const IntValue(50)};
      final memories = <String>[];
      executeAction(
        '注入 "黑暗蔓延" && 状态.警惕度 += 10',
        input: '',
        state: state,
        memories: memories,
        roleName: '埃德蒙·唐泰斯',
      );
      expect(memories, ['黑暗蔓延']);
      expect(state['警惕度'], const IntValue(60));
    });
  });

  group('规则引擎', () {
    Rule rule(String name, String cond, String action, {String group = ''}) =>
        Rule(name: name, condition: cond, action: action, group: group, line: 1);

    test('被动规则批量执行：状态变更 + 记忆注入', () {
      final engine = RuleEngine(
        rules: [
          rule('风声', '包含 "政治"', '状态.警惕度 += 10'),
          rule('码头低语', '包含 "政治"', '注入 "码头上传来低语"'),
        ],
        roleName: '埃德蒙·唐泰斯',
      );
      final result = engine.run(
        input: '我要谈论政治',
        state: {'警惕度': const IntValue(85)},
      );
      // 被动规则被批量化执行，直接验证结果而非 passiveMatched 标志
      expect(result.newState['警惕度'], const IntValue(95));
      expect(result.injectedMemories, ['码头上传来低语']);
      expect(result.activeRule, isNull);
    });

    test('主动规则互斥匹配：只取第一个', () {
      final engine = RuleEngine(
        rules: [
          rule('攻击', '包含 "攻击"', '全力攻击'),
          rule('防御', '包含 "攻击"', '防御姿态'),
        ],
        roleName: '埃德蒙·唐泰斯',
      );
      final result = engine.run(input: '攻击敌人', state: const <String, StateValue>{});
      expect(result.activeRule?.name, '攻击');
    });

    test('主动规则互斥组：同组两条都匹配时只触发第一条', () {
      final engine = RuleEngine(
        rules: [
          rule('攻击', '包含 "攻击"', '全力攻击', group: 'combat'),
          rule('防御', '包含 "攻击"', '防御姿态', group: 'combat'),
        ],
        roleName: '埃德蒙·唐泰斯',
      );
      final result = engine.run(input: '攻击敌人', state: const <String, StateValue>{});
      expect(result.activeRule?.name, '攻击');
      expect(result.activeRule?.action, '全力攻击');
    });

    test('主动规则互斥组：同组第一条不匹配、第二条匹配时触发第二条', () {
      final engine = RuleEngine(
        rules: [
          rule('攻击', '包含 "偷袭"', '全力攻击', group: 'combat'),
          rule('防御', '包含 "防御"', '防御姿态', group: 'combat'),
        ],
        roleName: '埃德蒙·唐泰斯',
      );
      final result = engine.run(input: '采取防御姿态', state: const <String, StateValue>{});
      expect(result.activeRule?.name, '防御');
      expect(result.activeRule?.action, '防御姿态');
    });

    test('主动规则互斥组：不同组的主动规则互不影响', () {
      final engine = RuleEngine(
        rules: [
          rule('攻击', '包含 "攻击"', '全力攻击', group: 'combat'),
          rule('逃跑', '包含 "逃跑"', '转身就跑', group: 'escape'),
        ],
        roleName: '埃德蒙·唐泰斯',
      );
      // 第一条匹配即返回，不同组的规则不影响
      final result1 = engine.run(
        input: '攻击敌人',
        state: const <String, StateValue>{},
      );
      expect(result1.activeRule?.name, '攻击');
      // 第二条匹配返回
      final result2 = engine.run(
        input: '我要逃跑',
        state: const <String, StateValue>{},
      );
      expect(result2.activeRule?.name, '逃跑');
    });

    test('互斥组：组内只触发第一个匹配', () {
      final engine = RuleEngine(
        rules: [
          rule('攻击', '包含 "攻击"', '状态.位置 = "战场"', group: 'combat'),
          rule('防御', '包含 "攻击"', '状态.位置 = "防御位"', group: 'combat'),
        ],
        roleName: '埃德蒙·唐泰斯',
      );
      final result = engine.run(
        input: '攻击',
        state: <String, StateValue>{'位置': const StringValue('马赛港')},
      );
      // 被动规则被批量化执行，直接验证结果而非 passiveMatched 标志
      expect(result.newState['位置'], const StringValue('战场'));
    });

    test('无匹配时 activeRule 为 null', () {
      final engine = RuleEngine(
        rules: [rule('无关', '包含 "xyz"', '指令')],
        roleName: '浮士德',
      );
      final result = engine.run(input: '你好', state: const <String, StateValue>{});
      expect(result.activeRule, isNull);
      expect(result.rollInfo, isEmpty);
    });

    test('主动规则动作作为指令返回', () {
      final engine = RuleEngine(
        rules: [rule('归航', '包含 "码头"', '大笑')],
        roleName: '埃德蒙·唐泰斯',
      );
      final result = engine.run(input: '船已靠上码头', state: const <String, StateValue>{});
      expect(result.activeRule?.action, '大笑');
    });

  });
}
