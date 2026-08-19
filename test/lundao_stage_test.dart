import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/engine/rule_engine.dart';
import 'package:mephisto/services/parser/meph_parser.dart';

/// 三教论道舞台（Lundao）审计测试
///
/// 验证舞台的三份角色卡：
///   - 可被 parser 解析（真实模板解析组已覆盖，此处补引擎语义验证）
///   - 梦境框架世界观自洽（公共世界观 = Kongzi.meph 首卡）
///   - 引擎模拟：站队某家 → 该家辩势/维度值增长、终局阈值可达
///   - 终局互斥：三卡终局规则各自独立（互斥组只在卡内生效）
///   - 反模式 9 防护：否定句不误触发（成句引用设计）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Contract kongzi;
  late Contract laozhi;
  late Contract shijia;

  setUpAll(() async {
    kongzi = parseMeph(
      await rootBundle.loadString('assets/contracts/Lundao/Kongzi.meph'),
    );
    laozhi = parseMeph(
      await rootBundle.loadString('assets/contracts/Lundao/Laozhi.meph'),
    );
    shijia = parseMeph(
      await rootBundle.loadString('assets/contracts/Lundao/Shijiamouni.meph'),
    );
  });

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

  test('三份角色卡均可解析，角色名正确', () {
    expect(kongzi.roleName, '孔子');
    expect(laozhi.roleName, '老子');
    expect(shijia.roleName, '释迦牟尼');
  });

  test('公共世界观（Kongzi 首卡）承载梦境框架', () {
    // 舞台公共世界观 = 文件名字典序第一张卡（Kongzi）的【世界观】
    expect(kongzi.worldview, contains('嵩山'));
    expect(kongzi.worldview, contains('天地之中'));
    expect(kongzi.worldview, contains('入梦'));
    expect(kongzi.worldview, contains('三位圣人'));
  });

  test('站队儒家：仁礼之谈使孔子辩势增长，终局可达', () {
    var state = Map<String, StateValue>.from(kongzi.stateMap);
    for (var i = 0; i < 10; i++) {
      state = runRules(kongzi, '己所不欲，勿施于人，仁者爱人，克己复礼', state);
    }
    expect(
      (state['辩势'] as IntValue).value,
      greaterThan(70),
      reason: '持续以儒家经典论辩，孔子辩势应显著增长',
    );
    expect((state['仁德'] as IntValue).value, greaterThanOrEqualTo(70));
  });

  test('站队道家：道法自然之谈使老子辩势增长，终局可达', () {
    var state = Map<String, StateValue>.from(laozhi.stateMap);
    for (var i = 0; i < 10; i++) {
      state = runRules(laozhi, '上善若水，道法自然，为道日损，知者不言', state);
    }
    expect(
      (state['辩势'] as IntValue).value,
      greaterThan(70),
      reason: '持续以道家经典论辩，老子辩势应显著增长',
    );
    expect((state['道心'] as IntValue).value, greaterThanOrEqualTo(70));
  });

  test('站队佛家：般若空观之谈使释迦牟尼辩势增长，终局可达', () {
    var state = Map<String, StateValue>.from(shijia.stateMap);
    for (var i = 0; i < 10; i++) {
      state = runRules(shijia, '色即是空，应作如是观，应无所住而生其心', state);
    }
    expect(
      (state['辩势'] as IntValue).value,
      greaterThan(70),
      reason: '持续以佛家经典论辩，释迦牟尼辩势应显著增长',
    );
    expect((state['觉悟'] as IntValue).value, greaterThanOrEqualTo(70));
  });

  test('终局互斥：三家终局规则只在各自卡内触发（卡间状态独立）', () {
    // 孔子辩势满、仁德满 → 仅孔子终局注入；老子/释迦不受影响
    var kState = Map<String, StateValue>.from(kongzi.stateMap)
      ..['辩势'] = const IntValue(90)
      ..['仁德'] = const IntValue(80);
    var lState = Map<String, StateValue>.from(laozhi.stateMap)
      ..['辩势'] = const IntValue(50);
    var sState = Map<String, StateValue>.from(shijia.stateMap)
      ..['辩势'] = const IntValue(50);

    final kResult = RuleEngine(
      rules: kongzi.rules,
      roleName: kongzi.roleName,
    ).run(input: '仁者爱人', state: kState);
    final lResult = RuleEngine(
      rules: laozhi.rules,
      roleName: laozhi.roleName,
    ).run(input: '仁者爱人', state: lState);
    final sResult = RuleEngine(
      rules: shijia.rules,
      roleName: shijia.roleName,
    ).run(input: '仁者爱人', state: sState);

    expect(kResult.injectedMemories, isNotEmpty, reason: '孔子达终局 → 注入胜利叙事');
    expect(lResult.injectedMemories, isEmpty, reason: '老子未达终局 → 无注入');
    expect(sResult.injectedMemories, isEmpty, reason: '释迦牟尼未达终局 → 无注入');
  });

  test('反模式 9：否定句不误触发（「不作为」不触发道家，成句「为道日损」才触发）', () {
    // 「无为」是道家核心概念、正常加分（修复前老子自己的「无为」不加分是 bug）；
    // 但「不作为」这种否定/转义语境不应触发——触发词是成句而非单字「无/为」
    var state = Map<String, StateValue>.from(laozhi.stateMap);
    state = runRules(laozhi, '我说的是不作为的意思', state);
    expect(
      state['辩势'],
      const IntValue(50),
      reason: '「不作为」不含「道法自然/无为/上善若水」等触发词，不应加分',
    );
    // 成句引用确实触发
    state = runRules(laozhi, '为道日损，复归于朴', state);
    expect(
      (state['辩势'] as IntValue).value,
      greaterThan(50),
      reason: '道家成句「为道日损」应触发加分',
    );
  });

  test('点名交锋不加辩势：玩家点名他教论道时，被点名者涨辩势，其余只加维度', () {
    // 舞台共享输入下，玩家「点名老子谈道」——老子本家涨辩势；
    // 孔子/释迦的「应答」规则只加维度（仁德/觉悟）不推动自己胜利，
    // 否则点名会干扰站队方向（修复前孔/释各 +3 辩势，三家同时涨）。
    var kState = Map<String, StateValue>.from(kongzi.stateMap);
    var lState = Map<String, StateValue>.from(laozhi.stateMap);
    var sState = Map<String, StateValue>.from(shijia.stateMap);
    kState = runRules(kongzi, '老子说，道法自然，无为而治', kState);
    lState = runRules(laozhi, '老子说，道法自然，无为而治', lState);
    sState = runRules(shijia, '老子说，道法自然，无为而治', sState);

    // 老子：本家「道法自然」触发 → 辩势 53
    expect((lState['辩势'] as IntValue).value, 53, reason: '老子本家论道应涨辩势');
    // 孔子/释迦：点名回应只加维度、不加辩势
    expect((kState['辩势'] as IntValue).value, 50, reason: '孔子回应老子不应推动自己辩势');
    expect((sState['辩势'] as IntValue).value, 50, reason: '释迦回应老子不应推动自己辩势');
    expect((kState['仁德'] as IntValue).value, 62, reason: '孔子应加仁德维度');
    expect((sState['觉悟'] as IntValue).value, 62, reason: '释迦应加觉悟维度');
  });

  test('站队方向唯一：站队儒家 5 轮，仅孔子辩势显著增长', () {
    var kState = Map<String, StateValue>.from(kongzi.stateMap);
    var lState = Map<String, StateValue>.from(laozhi.stateMap);
    var sState = Map<String, StateValue>.from(shijia.stateMap);
    const rujia = '仁者爱人，克己复礼，己所不欲勿施于人';
    for (var i = 0; i < 5; i++) {
      kState = runRules(kongzi, rujia, kState);
      lState = runRules(laozhi, rujia, lState);
      sState = runRules(shijia, rujia, sState);
    }
    expect(
      (kState['辩势'] as IntValue).value,
      greaterThan(80),
      reason: '站队儒家 → 孔子辩势显著增长',
    );
    expect(
      (lState['辩势'] as IntValue).value,
      50,
      reason: '儒家输入不应推动老子辩势（无「克儒」拆招）',
    );
    expect(
      (sState['辩势'] as IntValue).value,
      50,
      reason: '儒家输入不应推动释迦辩势（无「克儒」拆招）',
    );
  });
}
