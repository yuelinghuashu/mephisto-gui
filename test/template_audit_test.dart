import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/engine/rule_engine.dart';
import 'package:mephisto/services/parser/meph_parser.dart';

/// 内置模板规则质量审计——用真实引擎对模板跑「模拟对局」验证规则设计
///
/// 本测试集同时承担两个职责：
///   1. 模板修改的回归护栏：任何对 assets/contracts 的修改若破坏
///      本测试断言的规则语义，会立即失败
///   2. 设计意图验证：断言规则行为与注释宣称的意图一致
///      （否定句不误触发、状态方向正确、关键词无冲突、终局闭环）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Contract> loadTemplate(String name) async {
    final content = await rootBundle.loadString('assets/contracts/$name');
    return parseMeph(content);
  }

  /// 执行一轮规则并返回新状态 map
  Map<String, StateValue> runRules(
    Contract c,
    String input,
    Map<String, StateValue> state,
  ) {
    final result = RuleEngine(
      rules: c.rules,
      roleName: c.roleName,
    ).run(input: input, state: state);
    return result.newState;
  }

  group('A类：规则语义与模板意图一致（回归护栏）', () {
    test('Camlann/Arthur 临终：否定句「我不会倒下」不误杀；垂死时明确倒下才归零', () async {
      final c = await loadTemplate('Camlann/Arthur.meph');
      var state = Map<String, StateValue>.from(c.stateMap);

      // 满血时否定句：不触发（生命 100 > 30 守卫）
      state = runRules(c, '我绝不会倒下！', state);
      expect(state['生命'], const IntValue(100), reason: '满血时「我不会倒下」不应触发生命归零');

      // 生命垂危 + 明确倒下：触发临终
      state['生命'] = const IntValue(20);
      state = runRules(c, '我撑不住了，倒下了', state);
      expect(state['生命'], const IntValue(0), reason: '生命 ≤30 且明确倒下时才应触发临终归零');
    });

    test('dantes.bonapart 坚守清白：拒绝诱惑时警惕度提高（+5 而非降到 50）', () async {
      final c = await loadTemplate('dantes.bonapart.meph');
      var state = Map<String, StateValue>.from(c.stateMap);
      expect(state['警惕度'], const IntValue(70));
      state = runRules(c, '我拒绝相信他们的谎言', state);
      expect(
        state['警惕度'],
        const IntValue(75),
        reason: '「拒绝」触发坚守清白，警惕度应从 70 提高到 75（注释「提高警惕」）',
      );
    });

    test('gilgamesh 蛇之窃：「找到仙草」只强化求索，不被当被窃惩罚', () async {
      final c = await loadTemplate('gilgamesh.meph');
      var state = Map<String, StateValue>.from(c.stateMap);
      // 先走到世界尽头
      state = runRules(c, '我出发前往海边', state);
      state = runRules(c, '我抵达了世界尽头', state);
      expect(state['位置'], const StringValue('世界尽头'));

      // 多次「找到了仙草」直到接近求索上限 200：只走 [永生] +5，绝不触发 [蛇之窃]
      var steps = 0;
      while ((state['求索'] as IntValue).value < 195) {
        final before = (state['求索'] as IntValue).value;
        state = runRules(c, '我找到了仙草', state);
        expect(
          (state['求索'] as IntValue).value - before,
          5,
          reason: '「找到仙草」是正面强化（永生+5），不得被蛇之窃概率惩罚',
        );
        steps++;
      }
      expect(steps, greaterThan(10), reason: '求索未达上限时应持续 +5');
      // 明确表达被窃才可能触发惩罚；「仙草被蛇偷走」含「仙草」仍会走
      // 永生 +5（原设计），但不得再叠加蛇之窃 -30（此前会 +5 又概率 -30）
      final before = (state['求索'] as IntValue).value;
      state = runRules(c, '仙草被蛇偷走了', state);
      final after = (state['求索'] as IntValue).value;
      // 只可能是 +5（永生）或 -25（永生+蛇之窃同时触发）——若蛇之窃已
      // 被「被窃语境」限定，此处单次仍可能掷骰不中；改为断言「绝无
      // 纯 -30 惩罚」（即不存在「只有蛇之窃、没有永生」的路径）。
      expect(
        after - before,
        anyOf(5, -25),
        reason: '含「仙草」必然触发永生 +5；蛇之窃仅在被窃语境下概率叠加惩罚',
      );
    });

    test('faust 灵魂维系：普通对话不强制拉回，濒死语境才触发', () async {
      final c = await loadTemplate('faust.meph');
      var state = Map<String, StateValue>.from(c.stateMap);
      // 灵魂 26 → 输入「黑暗」→ 暗影缠身 -5 = 21
      state['灵魂完整度'] = const IntValue(26);
      state = runRules(c, '黑暗笼罩了书斋', state);
      expect((state['灵魂完整度'] as IntValue).value, 21);

      // 普通对话（无濒死语境）：不再无条件拉回，保持 21（可继续跌入深渊）
      state = runRules(c, '我望向窗外', state);
      expect(
        (state['灵魂完整度'] as IntValue).value,
        21,
        reason: '普通对话不应无条件触发灵魂维系拉回 30——否则玩家无法跌入 25 以下',
      );

      // 濒死语境：契约拉回
      state = runRules(c, '我感觉灵魂快要消散了', state);
      expect(
        (state['灵魂完整度'] as IntValue).value,
        30,
        reason: '濒死/消散语境才应触发灵魂维系拉回',
      );
    });

    test('Camlann/Mordred 心魔：否定句「我不会原谅」不减怨毒；明确放下才触发', () async {
      final c = await loadTemplate('Camlann/Mordred.meph');
      var state = Map<String, StateValue>.from(c.stateMap);
      // 初始怨毒 40。输入「我绝不会原谅父亲」：含「父亲」触发 [弑父] +10=50，
      // 但 [心魔] 不应触发（无肯定放下语境）——验证心魔不减怨毒
      state = runRules(c, '我绝不会原谅父亲', state);
      expect(
        state['怨毒'],
        const IntValue(50),
        reason: '「我不会原谅」触发弑父 +10，但不得触发心魔 -15（否则应为 40）',
      );

      // 明确放下：心魔 -15 → 50-15=35
      state = runRules(c, '我愿意原谅这一切', state);
      expect(state['怨毒'], const IntValue(35), reason: '「我愿意原谅」才应触发心魔减怨毒');
    });
  });

  group('B类：状态机闭环 / 终局完整性（回归护栏）', () {
    test('faust 终局无锁已修复：达成「终局」后再说「满足」不再被覆盖', () async {
      final c = await loadTemplate('faust.meph');
      var state = Map<String, StateValue>.from(c.stateMap);
      state['情绪'] = const StringValue('终局');
      state = runRules(c, '我很满足，这一切都很美好', state);
      expect(
        state['情绪'],
        const StringValue('终局'),
        reason: '终局状态不得被「情绪流转」改回「满足」——终局应锁定',
      );
    });

    test('Kurukshetra/Arjuna 看见亲人：提及迦尔纳（兄长）触发心绪挣扎', () async {
      final c = await loadTemplate('Kurukshetra/Arjuna.meph');
      var state = Map<String, StateValue>.from(c.stateMap);
      state['心绪'] = const StringValue('坚定');
      state = runRules(c, '我要射向对面的迦尔纳', state);
      expect(
        state['心绪'],
        const StringValue('痛苦'),
        reason: '「看见亲人」应含兄长迦尔纳——提及他唤起心绪挣扎',
      );
    });

    test('dantes 宽恕路线有终局：宽恕盈满 + 仇恨消解时触发宽恕彼岸', () async {
      final c = await loadTemplate('dantes.meph');
      var state = Map<String, StateValue>.from(c.stateMap);
      state['宽恕'] = const IntValue(90);
      state['仇恨'] = const IntValue(40);
      final r = RuleEngine(
        rules: c.rules,
        roleName: c.roleName,
      ).run(input: '我选择宽恕，放下这一切', state: state);
      expect(
        r.injectedMemories,
        isNotEmpty,
        reason: '宽恕≥80 且仇恨≤60 时应触发「宽恕彼岸」终局注入',
      );
    });

    test('faust 终局一次性：达成终局后反复触发不再重复注入', () async {
      final c = await loadTemplate('faust.meph');
      // 构造「满足」状态 + 连续输入「停留」多次
      var state = Map<String, StateValue>.from(c.stateMap);
      state['情绪'] = const StringValue('满足');
      var injections = 0;
      for (var i = 0; i < 5; i++) {
        final r = RuleEngine(
          rules: c.rules,
          roleName: c.roleName,
        ).run(input: '我真美啊，请停留一下', state: state);
        state = r.newState;
        injections += r.injectedMemories.length;
      }
      expect(injections, 1, reason: '终局注入应只触发一次（情绪流转已置「终局」锁），不得每轮重复');
    });

    test('dantes 终局互斥：复仇终局触发后，宽恕终局不再触发', () async {
      final c = await loadTemplate('dantes.meph');
      // 先走复仇线达终局（归途=已决、仇恨清零）
      var state = Map<String, StateValue>.from(c.stateMap);
      state['仇恨'] = const IntValue(120);
      final revenge = RuleEngine(
        rules: c.rules,
        roleName: c.roleName,
      ).run(input: '我要毁灭一切！', state: state);
      expect(revenge.injectedMemories, isNotEmpty, reason: '复仇终局应触发');
      expect(revenge.newState['归途'], const StringValue('已决'));
      expect(revenge.newState['仇恨'], const IntValue(0), reason: '终局后仇恨清零');

      // 终局后再凑宽恕条件：不应再触发宽恕彼岸（归途已决锁）
      var after = revenge.newState;
      after['宽恕'] = const IntValue(90);
      final second = RuleEngine(
        rules: c.rules,
        roleName: c.roleName,
      ).run(input: '我宽恕了，放下仇恨', state: after);
      expect(second.injectedMemories, isEmpty, reason: '归途已决后宽恕彼岸不得再触发（双终局互斥）');
    });

    test('数值封顶：joan 生命不为负、士气/信仰封顶；gilgamesh 哀恸不为负', () async {
      // joan：连续负伤，生命下限 0
      final joan = await loadTemplate('joan_of_arc.meph');
      var jState = Map<String, StateValue>.from(joan.stateMap)
        ..['位置'] = const StringValue('奥尔良');
      for (var i = 0; i < 15; i++) {
        jState = runRules(joan, '我中箭了，流血不止', jState);
      }
      expect(
        (jState['生命'] as IntValue).value,
        greaterThanOrEqualTo(0),
        reason: '生命不得为负（下限 0 守卫）',
      );
      // 士气软上限 200：守卫 `< 200` 允许最后一次 +10 冲到 205（软上限特性），
      // 但绝不允许无限累加（此前实测可达 325）
      expect(
        (jState['士气'] as IntValue).value,
        lessThanOrEqualTo(205),
        reason: '士气软上限 200（软上限允许单次增量小幅超限，禁止无限累加）',
      );
      expect(
        (jState['信仰'] as IntValue).value,
        lessThanOrEqualTo(120),
        reason: '信仰封顶 120',
      );

      // gilgamesh：归来后哀恸不为负、归乡锁一次性
      final gil = await loadTemplate('gilgamesh.meph');
      var gState = Map<String, StateValue>.from(gil.stateMap)
        ..['位置'] = const StringValue('世界尽头')
        ..['求索'] = const IntValue(120);
      for (var i = 0; i < 3; i++) {
        gState = runRules(gil, '我明白了，该回家了', gState);
      }
      expect(
        (gState['哀恸'] as IntValue).value,
        greaterThanOrEqualTo(0),
        reason: '哀恸不得为负',
      );
      expect(gState['归乡'], const StringValue('已归'));
    });
  });
}
