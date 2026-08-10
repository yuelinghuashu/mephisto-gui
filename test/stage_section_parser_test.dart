import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/services/parser/stage_section_parser.dart';

/// 舞台分节解析器测试
void main() {
  const roleNames = ['浮士德', '梅菲斯特'];

  test('按角色分节完整解析', () {
    const reply = '''
【浮士德】
浮士德站在书斋窗前。

【梅菲斯特】
梅菲斯特从阴影中走出。
''';
    final result = parseStageSections(reply: reply, roleNames: roleNames);
    expect(result.sections['浮士德'], '浮士德站在书斋窗前。');
    expect(result.sections['梅菲斯特'], '梅菲斯特从阴影中走出。');
    expect(result.overflow, isEmpty);
  });

  test('标题同行跟内容也能正确解析', () {
    const reply = '''
【浮士德】浮士德站在书斋窗前。

【梅菲斯特】
梅菲斯特从阴影中走出。
''';
    final result = parseStageSections(reply: reply, roleNames: roleNames);
    expect(result.sections['浮士德'], '浮士德站在书斋窗前。');
    expect(result.sections['梅菲斯特'], '梅菲斯特从阴影中走出。');
  });

  test('无戏份角色不分节（键不存在）', () {
    const reply = '''
【浮士德】
浮士德站在书斋窗前。
''';
    final result = parseStageSections(reply: reply, roleNames: roleNames);
    expect(result.sections.containsKey('浮士德'), isTrue);
    expect(result.sections.containsKey('梅菲斯特'), isFalse);
    expect(result.sectionOf('梅菲斯特'), isNull);
    expect(result.isEmpty, isFalse);
  });

  test('空回复返回空结果', () {
    final result = parseStageSections(reply: '', roleNames: roleNames);
    expect(result.isEmpty, isTrue);
    expect(result.overflow, isEmpty);
  });

  test('未知角色名归入 overflow', () {
    const reply = '''
【浮士德】
浮士德站在书斋窗前。

【神秘人】
神秘身影一闪而过。
''';
    final result = parseStageSections(reply: reply, roleNames: roleNames);
    expect(result.sections.keys, ['浮士德']);
    expect(result.overflow, contains('神秘人'));
  });

  test('全角/半角括号容错', () {
    const reply = '''
[浮士德]
浮士德站在书斋窗前。

【梅菲斯特】
梅菲斯特从阴影中走出。
''';
    final result = parseStageSections(reply: reply, roleNames: roleNames);
    expect(result.sections['浮士德'], '浮士德站在书斋窗前。');
    expect(result.sections['梅菲斯特'], isNotNull);
  });

  test('标题前后空白容忍 + 分节前引言归入 overflow', () {
    const reply = '''
以下是对命运的回应：

 【浮士德】
浮士德站在书斋窗前。
''';
    final result = parseStageSections(reply: reply, roleNames: roleNames);
    expect(result.sections['浮士德'], '浮士德站在书斋窗前。');
    expect(result.overflow, contains('以下是对命运的回应'));
  });

  test('isSectionHeaderLine 识别纯标题行', () {
    expect(isSectionHeaderLine('【浮士德】'), isTrue);
    expect(isSectionHeaderLine('【 浮士德 】'), isTrue);
    expect(isSectionHeaderLine('[浮士德]'), isTrue);
    expect(isSectionHeaderLine('【浮士德】正文'), isFalse);
    expect(isSectionHeaderLine('浮士德站在窗前'), isFalse);
  });

  group('parseStageMentions（全景叙事提及归属）', () {
    test('多人被提及 → 每位角色共享全文，overflow 清空（避免重复）', () {
      const reply = '''
阿周那拉满神弓，甘狄沃的弦光如日。迦尔纳从战车上跃下，黄金甲已失，
裸露的胸膛只余束胸布带。“因陀罗啊，你赐我的神枪……”他触摸腰间低语。
阿周那的箭尖在落日中微微颤动。
''';
      final result = parseStageMentions(reply: reply, roleNames: ['阿周那', '迦尔纳']);
      expect(result.sections['阿周那'], contains('阿周那'));
      expect(result.sections['迦尔纳'], contains('迦尔纳'));
      // 被提及者共享同一段全文
      expect(result.sections['阿周那'], result.sections['迦尔纳']);
      // 有角色被提及 → overflow 为空，文本已全部归位（不会重复出现）
      expect(result.overflow, isEmpty);
    });

    test('仅一人被提及 → 只有该角色有戏份', () {
      const reply = '浮士德独自站在书斋窗前。';
      final result = parseStageMentions(
        reply: reply,
        roleNames: ['浮士德', '梅菲斯特'],
      );
      expect(result.sections.containsKey('浮士德'), isTrue);
      expect(result.sections.containsKey('梅菲斯特'), isFalse);
    });

    test('空回复 → 空结果', () {
      final result = parseStageMentions(reply: '', roleNames: ['浮士德']);
      expect(result.isEmpty, isTrue);
      expect(result.overflow, isEmpty);
    });

    test('无人被提及 → sections 为空，全文进 overflow', () {
      const reply = '一片沉默笼罩战场。';
      final result = parseStageMentions(
        reply: reply,
        roleNames: ['阿周那', '迦尔纳'],
      );
      expect(result.isEmpty, isTrue);
      expect(result.overflow, contains('沉默'));
    });
  });
}
