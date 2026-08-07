import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/parser/meph_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MephParser - 真实模板解析', () {
    test('解析 faust.meph（faust 模板）', () async {
      final text = await rootBundle.loadString('assets/contracts/faust.meph');
      final contract = parseMeph(text);

      // 角色名
      expect(contract.roleName, '浮士德');

      // 锚点
      expect(contract.anchor, hasLength(3));
      expect(contract.anchor[0].key, '核心信念');
      expect(contract.anchor[1].key, '欲望');
      expect(contract.anchor[2].key, '绝对禁忌');

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

      // 规则（覆盖全语法：注入/状态赋值/复合赋值/复合动作/LLM指令/互斥组/括号/骰子）
      expect(contract.rules, hasLength(14));
      expect(contract.rules.first.name, '灵魂危机');
      expect(contract.rules.first.condition, '状态.灵魂完整度 < 30');
      expect(contract.rules.first.action, startsWith('注入 '));
      // 行号递增
      expect(contract.rules[0].line, lessThan(contract.rules[1].line));
    });

    test('解析 dantes.meph（互斥组 + 数值状态 + 复合动作）', () async {
      final text = await rootBundle.loadString('assets/contracts/dantes.meph');
      final contract = parseMeph(text);

      expect(contract.roleName, '埃德蒙·唐泰斯');
      expect(contract.anchor, hasLength(6));

      // 数值类型推断
      expect(contract.state, hasLength(4));
      final hp = contract.state.firstWhere((s) => s.key == '生命值');
      expect(hp.value, const IntValue(100));
      final alert = contract.state.firstWhere((s) => s.key == '警惕度');
      expect(alert.value, const IntValue(30));
      final mood = contract.state.firstWhere((s) => s.key == '心绪');
      expect(mood.value, const StringValue('期待'));

      // 互斥组剥离
      final dream = contract.rules.firstWhere((r) => r.name == '船长之梦');
      expect(dream.group, '答话');
      expect(dream.action, contains('谦逊地笑道'));
      expect(dream.condition, contains('包含 "船长"'));

      // 状态变更动作（复合赋值 + 简单赋值）
      final wind = contract.rules.firstWhere((r) => r.name == '风声');
      expect(wind.action, '状态.警惕度 += 15');
      final safe = contract.rules.firstWhere((r) => r.name == '平安');
      expect(safe.action, '状态.警惕度 = 30');

      // 掷骰条件保留原样
      final omen = contract.rules.firstWhere((r) => r.name == '吉兆');
      expect(omen.condition, contains('roll(1d100)'));
      expect(omen.action, startsWith('注入 '));
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
      // 互斥组「抉择」：答应 = 踏入波拿巴党
      final agree = contract.rules.firstWhere((r) => r.name == '答允密使');
      expect(agree.group, '抉择');
    });

    test('解析 faust.utopia.meph（官方示范子版：理想国 / 乌托邦线）', () async {
      final text = await rootBundle.loadString(
        'assets/contracts/faust.utopia.meph',
      );
      final contract = parseMeph(text);

      expect(contract.roleName, '浮士德');
      // 状态：前所未有的平静（契约临界设定）
      final state = {for (final s in contract.state) s.key: s.value};
      expect(state['情绪'], const StringValue('前所未有的平静'));
      // 记忆/历史为运行时产物，契约模板不应预置
      expect(contract.memories, isEmpty);
      expect(contract.history, isEmpty);
      // 呼应原典「满足即终结」的规则
      final critical = contract.rules.firstWhere((r) => r.name == '契约临界');
      expect(critical.condition, contains('roll(1d100)'));
      // 「说出停留」：浮士德亲口说出原典台词
      final stay = contract.rules.firstWhere((r) => r.name == '说出停留');
      expect(stay.action, contains('请停留一下'));
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
}
