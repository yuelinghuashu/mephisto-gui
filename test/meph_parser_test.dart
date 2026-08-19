import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/parser/meph_parser.dart';
import 'package:mephisto/services/parser/meph_serializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MephParser - 真实模板解析', () {
    test('解析 faust.meph（faust 模板）', () async {
      final text = await rootBundle.loadString('assets/contracts/faust.meph');
      final contract = parseMeph(text);

      // 角色名
      expect(contract.roleName, '浮士德');

      // 锚点（含新增的「说话风格」——与其他模板保持一致）
      expect(contract.anchor, hasLength(4));
      expect(contract.anchor[0].key, '核心信念');
      expect(contract.anchor[1].key, '欲望');
      expect(contract.anchor[2].key, '行为基线');
      expect(contract.anchor[3].key, '说话风格');

      // 状态（含类型推断）
      expect(contract.state, hasLength(3));
      expect(contract.state[0].key, '灵魂完整度');
      expect(contract.state[0].value, const IntValue(100));
      expect(contract.state[1].value, const StringValue('永不满足'));
      expect(contract.state[2].value, const StringValue('书斋'));

      // 文本区块
      expect(contract.worldview, contains('16 世纪的德意志'));
      expect(contract.background, contains('梅菲斯特签订了契约'));
      expect(contract.opening, contains('烛火摇曳'));

      // 规则（纯状态机化后：状态变更/骰子/LLM指令/互斥组），共 8 条
      expect(contract.rules, hasLength(8));
      expect(contract.rules.first.name, '情绪流转');
      expect(contract.rules.first.action, '状态.情绪 = "满足"');
      // 行号递增
      expect(contract.rules[0].line, lessThan(contract.rules[1].line));
      // 「侵蚀」互斥组包含两条规则（暗影缠身 + 烛火映心）
      final erosionRules = contract.rules
          .where((r) => r.group == '侵蚀')
          .toList();
      expect(erosionRules, hasLength(2));
    });

    test('解析 dantes.meph（基督山伯爵：复仇 + 互斥组 + 骰子）', () async {
      final text = await rootBundle.loadString('assets/contracts/dantes.meph');
      final contract = parseMeph(text);

      expect(contract.roleName, '基督山伯爵');
      expect(contract.anchor, hasLength(6));

      // 数值类型推断
      expect(contract.state, hasLength(6));
      final hp = contract.state.firstWhere((s) => s.key == '生命');
      expect(hp.value, const IntValue(100));
      final hatred = contract.state.firstWhere((s) => s.key == '仇恨');
      expect(hatred.value, const IntValue(80));
      final plan = contract.state.firstWhere((s) => s.key == '谋划');
      expect(plan.value, const IntValue(70));
      final forgiveness = contract.state.firstWhere((s) => s.key == '宽恕');
      expect(forgiveness.value, const IntValue(0));

      // 互斥组「终局」：放下与毁灭互斥
      final release = contract.rules.firstWhere((r) => r.name == '放下');
      expect(release.group, '终局');
      final destroy = contract.rules.firstWhere((r) => r.name == '毁灭');
      expect(destroy.group, '终局');

      // 骰子判定（棋局）
      final chess = contract.rules.firstWhere((r) => r.name == '棋局');
      expect(chess.condition, contains('roll(1d100)'));

      // 仇恨巅峰终局
      final judgment = contract.rules.firstWhere((r) => r.name == '天平方正');
      expect(judgment.action, contains('注入'));
    });

    test('解析 dantes.bonapart.meph（官方示范子版：波拿巴党卧底线）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/dantes.bonapart.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '埃德蒙·唐泰斯');
      // 状态：伊夫堡地牢，警惕度提升
      final state = {for (final s in contract.state) s.key: s.value};
      expect(state['位置'], const StringValue('伊夫堡地牢'));
      expect(state['警惕度'], const IntValue(70));
      // 记忆/历史为运行时产物，契约模板不应预置
      expect(contract.memories, isEmpty);
      expect(contract.history, isEmpty);
      // 波拿巴线核心规则
      final shake = contract.rules.firstWhere((r) => r.name == '身份动摇');
      expect(shake.condition, contains('波拿巴'));
      expect(shake.action, '状态.心绪 = "恐惧"');
    });

    test('解析 joan_of_arc.meph（贞德：天启信仰 + 互斥组 + 骰子）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/joan_of_arc.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '贞德 · 达尔克');
      // 状态（数值 + 字符串）
      expect(contract.state, hasLength(5));
      final faith = contract.state.firstWhere((s) => s.key == '信仰');
      expect(faith.value, const IntValue(90));
      final morale = contract.state.firstWhere((s) => s.key == '士气');
      expect(morale.value, const IntValue(85));
      // 核心规则
      final revelation = contract.rules.firstWhere((r) => r.name == '天启');
      expect(revelation.condition, contains('圣米迦勒'));
      expect(revelation.action, contains('状态.信仰 += 5'));
      // 状态机：质疑削弱信仰
      final doubt = contract.rules.firstWhere((r) => r.name == '动摇');
      expect(doubt.action, contains('状态.信仰 -= 5'));
      // 骰子判定
      final verdict = contract.rules.firstWhere((r) => r.name == '主之裁决');
      expect(verdict.condition, contains('roll(1d100)'));
    });

    test('解析 Camlann/Arthur.meph（终战亚瑟：王权威严 + 互斥组 + 骰子）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/Camlann/Arthur.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '亚瑟 · 潘德拉贡');
      // 状态
      expect(contract.state, hasLength(5));
      final authority = contract.state.firstWhere((s) => s.key == '王权威严');
      expect(authority.value, const IntValue(80));
      // 核心规则
      final excalibur = contract.rules.firstWhere((r) => r.name == '湖中剑');
      expect(excalibur.condition, contains('Excalibur'));
      expect(excalibur.action, contains('状态.王权威严 += 5'));
      // 互斥组「决断」：死战与悲悯互斥
      final death = contract.rules.firstWhere((r) => r.name == '死战');
      expect(death.group, '决断');
      // 骰子判定
      final fate = contract.rules.firstWhere((r) => r.name == '命运裁决');
      expect(fate.condition, contains('roll(1d100)'));
      // 复合动作：注入 + 状态变化
      final dying = contract.rules.firstWhere((r) => r.name == '临终');
      expect(dying.action, contains('状态.生命 = 0'));
    });

    test('解析 Camlann/Mordred.meph（莫德雷德：怨毒 + 互斥组 + 复合动作）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/Camlann/Mordred.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '莫德雷德');
      // 状态
      expect(contract.state, hasLength(5));
      final resentment = contract.state.firstWhere((s) => s.key == '怨毒');
      expect(resentment.value, const IntValue(40));
      // 核心规则
      final patricide = contract.rules.firstWhere((r) => r.name == '弑父');
      expect(patricide.condition, contains('亚瑟'));
      expect(patricide.action, contains('状态.怨毒 += 10'));
      // 互斥组「心病」：阴影积怨
      final shadow = contract.rules.firstWhere((r) => r.name == '阴影');
      expect(shadow.group, '心病');
      // 互斥组「心魔」：尝试放下的心魔
      final innerDemon = contract.rules.firstWhere((r) => r.name == '心魔');
      expect(innerDemon.group, '心魔');
      // 骰子判定
      final arrogance = contract.rules.firstWhere((r) => r.name == '狂傲');
      expect(arrogance.condition, contains('roll(1d100)'));
      // 状态机
      final obsession = contract.rules.firstWhere((r) => r.name == '王座执念');
      expect(obsession.action, contains('状态.战意 += 10'));
    });

    test('解析 gilgamesh.meph（吉尔伽美什：求索 + 互斥组 + 骰子）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/gilgamesh.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '吉尔伽美什');
      // 状态
      expect(contract.state, hasLength(6));
      final sovereignty = contract.state.firstWhere((s) => s.key == '王权');
      expect(sovereignty.value, const IntValue(90));
      final pursuit = contract.state.firstWhere((s) => s.key == '求索');
      expect(pursuit.value, const IntValue(80));
      // 核心规则
      final memory = contract.rules.firstWhere((r) => r.name == '追忆');
      expect(memory.condition, contains('恩奇都'));
      expect(memory.action, contains('状态.求索 += 5'));
      // 互斥组「命运」：抗争与接纳互斥
      final struggle = contract.rules.firstWhere((r) => r.name == '抗争');
      expect(struggle.group, '命运');
      // 骰子判定（蛇的谎言）
      final snake = contract.rules.firstWhere((r) => r.name == '蛇之窃');
      expect(snake.condition, contains('roll(1d100)'));
      // 复合动作：注入 + 状态变化
      final returnRule = contract.rules.firstWhere((r) => r.name == '归来');
      expect(returnRule.action, contains('状态.王权 += 15'));
      expect(returnRule.action, contains('状态.哀恸 -= 20'));
    });

    test('解析 arthur_sword.meph（少年亚瑟：石中剑 + 互斥组 + 复合动作）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/arthur_sword.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '亚瑟');
      // 状态（王者之望：少年亚瑟只有一点正直种子，初始值低）
      expect(contract.state, hasLength(5));
      final evidence = contract.state.firstWhere((s) => s.key == '王者之望');
      expect(evidence.value, const IntValue(10));
      // 核心规则
      final sword = contract.rules.firstWhere((r) => r.name == '王选之剑');
      expect(sword.condition, contains('石中剑'));
      expect(sword.action, contains('状态.王者之望 += 10'));
      // 互斥组「抉择」：迟疑与担当互斥
      final hesitate = contract.rules.firstWhere((r) => r.name == '迟疑');
      expect(hesitate.group, '抉择');
      // 骰子判定
      final fate = contract.rules.firstWhere((r) => r.name == '命运抉择');
      expect(fate.condition, contains('roll(1d100)'));
    });

    test('解析 faust.imperial.meph（浮士德子版：帝国金殿 / 权柄幻象线）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/faust.imperial.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '浮士德');
      // 状态：权柄幻象线的核心状态集
      final state = {for (final s in contract.state) s.key: s.value};
      expect(state['位置'], const StringValue('金殿'));
      expect(state['皇眷'], const IntValue(50));
      expect(state['权力欲'], const IntValue(60));
      // 记忆/历史为运行时产物，契约模板不应预置
      expect(contract.memories, isEmpty);
      expect(contract.history, isEmpty);
      // @命运 区块（分支一句话）
      expect(contract.branchTitle, contains('帝国金殿'));
      // 场景链：金殿 → 召唤厅
      final summon = contract.rules.firstWhere((r) => r.name == '海伦之召');
      expect(summon.condition, contains('状态.位置 == "金殿"'));
      expect(summon.action, contains('状态.位置 = "召唤厅"'));
      // 互斥组「抉择」：弄权与清醒互斥
      final powermove = contract.rules.firstWhere((r) => r.name == '弄权');
      expect(powermove.group, '抉择');
      final clarity = contract.rules.firstWhere((r) => r.name == '清醒');
      expect(clarity.group, '抉择');
      // 互斥组「终局」：沉沦与觉醒互斥
      final fall = contract.rules.firstWhere((r) => r.name == '契约临界');
      expect(fall.group, '终局');
      final awakening = contract.rules.firstWhere((r) => r.name == '觉醒');
      expect(awakening.group, '终局');
      // 骰子判定（幻觉侵蚀 / 海伦降临）
      final illusion = contract.rules.firstWhere((r) => r.name == '帝国幻象');
      expect(illusion.condition, contains('roll(1d100)'));
      final helen = contract.rules.firstWhere((r) => r.name == '美之降临');
      expect(helen.condition, contains('roll(1d100)'));
    });

    test('解析 Lundao/Kongzi.meph（三教论道：儒家 · 梦境世界观）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/Lundao/Kongzi.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '孔子');
      // 梦境框架承载于公共世界观（Kongzi 为字典序首卡）
      expect(contract.worldview, contains('嵩山'));
      expect(contract.worldview, contains('入梦'));
      // 状态：辩势/仁德/执念
      final state = {for (final s in contract.state) s.key: s.value};
      expect(state['辩势'], const IntValue(50));
      expect(state['仁德'], const IntValue(60));
      // 终局规则（儒道胜）绑定双阈值
      final win = contract.rules.firstWhere((r) => r.name == '儒道胜');
      expect(win.condition, contains('状态.辩势 >= 80'));
      expect(win.condition, contains('状态.仁德 >= 70'));
      // 点名交锋（应答规则）：只加维度不加辩势（推动胜利的只有本家规则）
      final respond = contract.rules.firstWhere((r) => r.name == '应答老子');
      expect(respond.action, contains('仁德'), reason: '应答只加维度，不推辩势');
      // 记忆/历史为运行时产物，契约模板不应预置
      expect(contract.memories, isEmpty);
      expect(contract.history, isEmpty);
    });

    test('解析 Lundao/Laozhi.meph（三教论道：道家）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/Lundao/Laozhi.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '老子');
      final state = {for (final s in contract.state) s.key: s.value};
      expect(state['辩势'], const IntValue(50));
      expect(state['道心'], const IntValue(60));
      // 终局规则（道胜）
      final win = contract.rules.firstWhere((r) => r.name == '道胜');
      expect(win.condition, contains('状态.辩势 >= 80'));
      expect(win.condition, contains('状态.道心 >= 70'));
      // 点名交锋（应答规则）：只加维度不加辩势
      final respond = contract.rules.firstWhere((r) => r.name == '应答孔子');
      expect(respond.action, contains('道心'), reason: '应答只加维度，不推辩势');
    });

    test('解析 Lundao/Shijiamouni.meph（三教论道：佛家）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/Lundao/Shijiamouni.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '释迦牟尼');
      final state = {for (final s in contract.state) s.key: s.value};
      expect(state['辩势'], const IntValue(50));
      expect(state['觉悟'], const IntValue(60));
      // 终局规则（佛胜）
      final win = contract.rules.firstWhere((r) => r.name == '佛胜');
      expect(win.condition, contains('状态.辩势 >= 80'));
      expect(win.condition, contains('状态.觉悟 >= 70'));
      // 点名交锋（应答规则）：只加维度不加辩势
      final respond = contract.rules.firstWhere((r) => r.name == '应答孔子');
      expect(respond.action, contains('觉悟'), reason: '应答只加维度，不推辩势');
    });
  });

  group('MephParser - 值类型推断', () {
    test('整数/浮点/布尔/引号字符串', () {
      final contract = parseMeph('''
【角色名】
测试

【状态】
- 生命值：100
- 堕落指数：85.5
- 启用：true
- 情绪："暴怒"
- 空值：
''');
      final state = {for (final s in contract.state) s.key: s.value};
      expect(state['生命值'], const IntValue(100));
      expect(state['堕落指数'], const DoubleValue(85.5));
      expect(state['启用'], const BoolValue(true));
      expect(state['情绪'], const StringValue('暴怒'));
      expect(state['空值'], const StringValue(''));
    });

    test('中英文冒号均可作为分隔符', () {
      final contract = parseMeph('''
【角色名】
测试

【状态】
- key: value
- 键：值
''');
      expect(contract.state[0].key, 'key');
      expect(contract.state[0].value, const StringValue('value'));
      expect(contract.state[1].key, '键');
      expect(contract.state[1].value, const StringValue('值'));
    });
  });

  group('MephParser - 历史与记忆', () {
    test('解析历史（fate/assistant + \\n 转义）', () {
      final contract = parseMeph('''
【角色名】
测试

【历史】
- fate: 第一行\\n第二行
- assistant：回应
''');
      expect(contract.history, hasLength(2));
      expect(contract.history[0].role, MessageRole.fate);
      expect(contract.history[0].content, '第一行\n第二行');
      expect(contract.history[1].role, MessageRole.assistant);
      expect(contract.history[1].content, '回应');
    });

    test('解析历史（system 前缀，舞台额外叙事）', () {
      final contract = parseMeph('''
【角色名】
测试

【历史】
- fate: 出发
- assistant：回应
- system: （额外叙事：群鸟掠过）
''');
      expect(contract.history, hasLength(3));
      expect(contract.history[2].role, MessageRole.system);
      expect(contract.history[2].content, '（额外叙事：群鸟掠过）');
    });

    test('解析历史：非法前缀报错（fate/assistant/system 之外）', () {
      expect(
        () => parseMeph('''
【角色名】
测试

【历史】
- 用户: 你好
'''),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains("'fate:'"),
          ),
        ),
      );
    });

    test('解析记忆', () {
      final contract = parseMeph('''
【角色名】
测试

【记忆】
- 浮士德与梅菲斯特签订了契约
- 浮士德正在书斋中
''');
      expect(contract.memories, hasLength(2));
      expect(contract.memories[0].content, '浮士德与梅菲斯特签订了契约');
    });

    test('解析记忆：可选结构化前缀 [权重] 拆分为重要性', () {
      final contract = parseMeph('''
【角色名】
测试

【记忆】
- [4] 浮士德与梅菲斯特立下赌约
- [2] 浮士德在书斋研读古卷
- 无前缀旧格式记忆
''');
      expect(contract.memories, hasLength(3));

      // 带 [权重] 前缀 → importance 被解析，前缀从内容中剥离
      expect(contract.memories[0].content, '浮士德与梅菲斯特立下赌约');
      expect(contract.memories[0].importance, 4);

      expect(contract.memories[1].content, '浮士德在书斋研读古卷');
      expect(contract.memories[1].importance, 2);

      // 无前缀 → 兜底默认权重（向后兼容）
      expect(contract.memories[2].content, '无前缀旧格式记忆');
      expect(contract.memories[2].importance, Memory.defaultImportance);
    });

    test('记忆权重序列化回环：parseMeph(serializeMeph(contract)) 保留 importance', () {
      // 构造含权重元数据的契约（Memory 非 const 构造，故不用 const）
      final contract = Contract(
        roleName: '浮士德',
        memories: [
          Memory(content: '核心主线', importance: 5),
          Memory(content: '普通记忆', importance: 2),
          Memory(content: '默认值记忆'), // 纯默认 → 序列化不输出前缀
        ],
      );

      final serialized = serializeMeph(contract);
      final reparsed = parseMeph(serialized);

      // 权重前缀回环
      expect(reparsed.memories[0].content, '核心主线');
      expect(reparsed.memories[0].importance, 5);

      expect(reparsed.memories[1].content, '普通记忆');
      expect(reparsed.memories[1].importance, 2);

      // 纯默认值保持原样输出，解析回默认权重
      expect(reparsed.memories[2].content, '默认值记忆');
      expect(reparsed.memories[2].importance, Memory.defaultImportance);
    });
  });

  group('MephParser - 错误处理', () {
    test('区块外内容报错', () {
      expect(
        () => parseMeph('这是一段游离内容\n【角色名】\n测试'),
        throwsA(isA<MephParseError>()),
      );
    });

    test('重复区块报错', () {
      expect(
        () => parseMeph('【角色名】\nA\n【角色名】\nB'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('重复的区块'),
          ),
        ),
      );
    });

    test('规则缺少 -> 报错', () {
      expect(
        () => parseMeph('【规则】\n[规则] if 条件'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('->'),
          ),
        ),
      );
    });

    test('复合运算符中间有空格报错（状态.+ = 值）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 包含 "x" -> 状态.堕落指数 + = 10'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('复合运算符'),
          ),
        ),
      );
    });

    test('复合运算符中间有空格报错（状态.- = 值）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 包含 "x" -> 状态.堕落指数 - = 10'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('复合运算符'),
          ),
        ),
      );
    });

    test('复合动作中某段复合运算符有空格报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 包含 "x" -> 注入 "暗影" && 状态.堕落指数 + = 10'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('复合运算符'),
          ),
        ),
      );
    });

    test('合法复合/简单赋值不误报', () {
      final contract = parseMeph('''
【角色名】
测试

【规则】
[合法1] if 包含 "x" -> 状态.堕落指数 -= 5
[合法2] if 包含 "y" -> 状态.位置 = "书斋"
[合法3] if 包含 "z" -> 状态.灵魂完整度 == "完整"
''');
      // 均正常解析
      expect(contract.rules, hasLength(3));
    });

    test('比较运算符中间有空格报错（状态.> = 值）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 状态.灵魂完整度 > = 30 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('比较运算符'),
          ),
        ),
      );
    });

    test('比较运算符中间有空格报错（状态.= = 值）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 状态.情绪 = = "暴怒" -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('比较运算符'),
          ),
        ),
      );
    });

    test('比较运算符中间有空格报错（状态.! = 值）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 状态.位置 ! = "书斋" -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('比较运算符'),
          ),
        ),
      );
    });

    test('比较运算符中间有空格报错（roll.> = 阈值）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1d100) > = 80 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('比较运算符'),
          ),
        ),
      );
    });

    test('合法比较条件不误报', () {
      final contract = parseMeph('''
【角色名】
测试

【规则】
[合法1] if 状态.灵魂完整度 < 30 && 包含 "x" -> 注入 "a"
[合法2] if 状态.灵魂完整度 >= 70 || 状态.情绪 == "满足" -> 注入 "b"
[合法3] if 状态.位置 != "书斋" && roll(1d100) >= 60 -> 注入 "c"
''');
      // 均正常解析
      expect(contract.rules, hasLength(3));
    });

    test('关键词「不包含」中间有空格报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 不 包含 "黑暗" -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('不包含'),
          ),
        ),
      );
    });

    test('关键词「包含」中间有空格报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 包 含 "黑暗" -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('包含'),
          ),
        ),
      );
    });

    test('关键词空格不误报（合法包含/不包含 + 引号内文字）', () {
      final contract = parseMeph('''
【角色名】
测试

【规则】
[合法1] if 包含 "黑暗" && 不包含 "真实" -> 注入 "a"
[合法2] if 包含 "我不 包含你的话" -> 注入 "b"
''');
      // 均正常解析（引号内 "不 包含" 不应误报）
      expect(contract.rules, hasLength(2));
    });

    test('关键词「注入」中间有空格报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 包含 "x" -> 注 入 "阴影"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('注入'),
          ),
        ),
      );
    });

    test('关键词「状态」中间有空格报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 状 态.灵魂完整度 < 30 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('状态'),
          ),
        ),
      );
    });

    test('roll 与 ( 之间有空格报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if roll (1d100) >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('roll'),
          ),
        ),
      );
    });

    test('roll 后缺少左括号报错（roll 1d100 / roll1d100）', () {
      // roll 与表达式之间缺失 '('（有空格）：条件静默失效，必须报错
      expect(
        () => parseMeph('【规则】\n[错误] if roll 1d100 >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('缺少'),
          ),
        ),
      );
      // roll 与表达式之间缺失 '('（无空格）：同样静默失效
      expect(
        () => parseMeph('【规则】\n[错误] if roll1d100 >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('缺少'),
          ),
        ),
      );
    });

    test('roll 左括号未闭合报错（roll(1d100 无右括号）', () {
      // 条件末尾完全没有 ')'：roll 表达式无法识别，静默失效
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1d100 >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('缺少'),
          ),
        ),
      );
      // 括号内部内容直到行尾都未闭合
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1d100 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('缺少'),
          ),
        ),
      );
    });

    test('roll 括号内开头有空格报错（骰子表达式格式）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if roll( 1d100) >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('骰子表达式'),
          ),
        ),
      );
    });

    test('roll 括号内 d 前有空格报错（骰子表达式格式）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1 d100) >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('骰子表达式'),
          ),
        ),
      );
    });

    test('roll 括号内 d 后有空格报错（骰子表达式格式）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1d 100) >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('骰子表达式'),
          ),
        ),
      );
    });

    test('roll 多骰语法（2d100）报错（不兼容，显式拒绝）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if roll(2d100) >= 70 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('骰子表达式'),
          ),
        ),
      );
    });

    test('roll 非受支持面数（1d6）报错（仅支持 1d2 / 1d100）', () {
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1d6) >= 4 -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('骰子表达式'),
          ),
        ),
      );
      // 合法面数不误报：1d2 与 1d100
      final ok = parseMeph('''
【角色名】
测试

【规则】
[合法1] if roll(1d2) >= 2 -> 注入 "x"
[合法2] if roll(1d100) >= 70 -> 注入 "y"
''');
      expect(ok.rules, hasLength(2));
    });

    test('roll 非法格式（缺 d / 非数字 / 缺面数）报错', () {
      // roll(d100) 缺骰子个数
      expect(
        () => parseMeph('【规则】\n[错误] if roll(d100) >= 70 -> 注入 "x"'),
        throwsA(isA<MephParseError>()),
      );
      // roll(1dx) 面数非数字
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1dx) >= 70 -> 注入 "x"'),
        throwsA(isA<MephParseError>()),
      );
      // roll(1d) 缺面数
      expect(
        () => parseMeph('【规则】\n[错误] if roll(1d) >= 70 -> 注入 "x"'),
        throwsA(isA<MephParseError>()),
      );
    });

    test('条件括号不匹配报错', () {
      // 缺右括号
      expect(
        () => parseMeph('【规则】\n[错误] if (包含 "深渊" || 包含 "凝视" -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('括号不匹配'),
          ),
        ),
      );
      // 多余右括号
      expect(
        () => parseMeph('【规则】\n[错误] if 包含 "深渊") && 包含 "凝视" -> 注入 "x"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('括号不匹配'),
          ),
        ),
      );
    });

    test('复合动作 && 缺空格分隔报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 包含 "x" -> 注入 "a" &&状态.堕落指数 += 5'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('&&'),
          ),
        ),
      );
    });

    test('互斥组缺少闭合 ] 报错', () {
      expect(
        () => parseMeph('【规则】\n[错误] if 包含 "x" -> [group:combat 注入 "a"'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('互斥组'),
          ),
        ),
      );
    });

    test('合法语法不误报（括号匹配 && 标准分隔 互斥组合法）', () {
      final contract = parseMeph('''
【角色名】
测试

【规则】
[合法1] if (包含 "a" || 包含 "b") && 状态.灵魂完整度 < 30 -> 注入 "x" && 状态.堕落指数 += 5
[合法2] if 包含 "c" -> [group:侵蚀] 注入 "y"
[合法3] if roll(1d100) >= 70 -> 注入 "z"
''');
      // 均正常解析
      expect(contract.rules, hasLength(3));
      expect(contract.rules[1].group, '侵蚀');
    });

    test('关键词空格不误报（合法 roll/注入/状态 + 引号内文字 + roll 合法无空格）', () {
      final contract = parseMeph('''
【角色名】
测试

【规则】
[合法1] if roll(1d100) >= 70 && 状态.灵魂完整度 < 30 -> 注入 "注 入任何事"
[合法2] if 状态.位置 == "书斋" -> 注入 "a"
''');
      // 均正常解析（roll 无空格、引号内 "注 入" 不应误报）
      expect(contract.rules, hasLength(2));
    });

    test('列表项不以 - 开头报错', () {
      expect(
        () => parseMeph('【状态】\n灵魂完整度：50'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('列表项'),
          ),
        ),
      );
    });

    test('没有有效区块报错', () {
      expect(
        () => parseMeph('# 只有注释\n\n\n'),
        throwsA(
          isA<MephParseError>().having(
            (e) => e.message,
            'message',
            contains('没有有效区块'),
          ),
        ),
      );
    });
  });

  group('MephParser - 回归修复', () {
    test('角色名区块首行为 # 注释时跳过注释取真实角色名', () {
      // 回归：旧版 _parseRoleName 不跳过注释行，角色名被解析成 "# 这是注释"
      final contract = parseMeph('''
【角色名】
# 这是注释
浮士德
''');
      expect(contract.roleName, '浮士德');
    });

    test('条件中的括号出现在引号字符串内时不误报括号不匹配', () {
      // 回归：旧版 _validateParenBalance 不屏蔽引号，`包含 "("` 被误报
      final contract = parseMeph('''
【角色名】
测试

【规则】
[查括号] if 包含 "(" -> 注入 "内容"
[查右括号] if 不包含 ")" -> 注入 "内容"
''');
      expect(contract.rules, hasLength(2));
      expect(contract.rules[0].condition, '包含 "("');
      expect(contract.rules[1].condition, '不包含 ")"');
    });

    test('散文区块内的 【未知】 行并入文本区块，内容不丢失', () {
      // 回归：旧版将散文中的 `【传说】` 行切为未知区块并静默忽略，
      // 其后的全部文本从世界观中丢失
      final contract = parseMeph('''
【角色名】
测试

【世界观】
16 世纪的德意志，神秘学与契约的世界。

【传说】
有一位以灵魂换取知识的学者。

【开局场景】
烛火摇曳的书斋。
''');
      expect(contract.worldview, contains('16 世纪的德意志'));
      expect(
        contract.worldview,
        contains('有一位以灵魂换取知识的学者'),
        reason: '未知区块内容应并入前一个文本型区块，而非静默丢失',
      );
      expect(contract.worldview, contains('【传说】'), reason: '未知区块标题行作为散文的一部分保留');
    });

    test('结构化区块（规则/记忆）后的未知区块仍静默忽略（草稿宽容）', () {
      final contract = parseMeph('''
【角色名】
测试

【规则】
[测试] if 包含 "x" -> 注入 "内容"

【草稿】
这段草稿不应混入规则解析。
''');
      expect(contract.rules, hasLength(1));
      expect(contract.rules[0].name, '测试');
    });

    test('锚点字符串值带引号序列化，往返保留类型与内容', () {
      // 回归：旧版锚点用 item.value.value 直接输出，`"10"` 往返变数字、
      // 值内含 `：`/`:` 时在第一个冒号处截断
      final contract = parseMeph('''
【角色名】
测试

【锚点】
- 核心信念: "10"
- 口头禅: "他说道：你好"
- 座右铭: 真理

【状态】
- 灵魂完整度: 85
''');
      final anchorByKey = {for (final a in contract.anchor) a.key: a.value};
      expect(anchorByKey['核心信念'], isA<StringValue>());
      expect(anchorByKey['核心信念']!.value, '10');
      expect(anchorByKey['口头禅']!.value, '他说道：你好');

      // 序列化 → 解析往返：类型与内容完整保留
      final roundtrip = parseMeph(serializeMeph(contract));
      final roundtripByKey = {for (final a in roundtrip.anchor) a.key: a.value};
      expect(roundtripByKey['核心信念'], isA<StringValue>());
      expect(roundtripByKey['核心信念']!.value, '10');
      expect(roundtripByKey['口头禅']!.value, '他说道：你好');
      expect(roundtripByKey['座右铭']!.value, '真理');
    });

    test('字符串值含双引号时序列化往返不残留反斜杠', () {
      // 回归：旧版 _formatStateValue 转义 `"` 为 `\"` 但 unquote 不反转义，
      // 往返后内容带反斜杠损坏
      final contract = parseMeph('''
【角色名】
测试

【状态】
- 台词: "他说\\"你好\\"然后离开"
''');
      final state = contract.stateMap;
      expect(state['台词'], isA<StringValue>());
      expect(state['台词']!.value, '他说"你好"然后离开');

      final roundtrip = parseMeph(serializeMeph(contract));
      expect(roundtrip.stateMap['台词']!.value, '他说"你好"然后离开');
    });
  });
}
