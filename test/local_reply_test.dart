import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/engine/local_reply.dart';

void main() {
  // 无风格词的契约（默认语气）
  Contract contract({String roleName = '浮士德'}) {
    return Contract(roleName: roleName);
  }

  group('localReply - 关键词分支', () {
    test('为什么/为何 → 烛火与知识求索', () {
      final reply = localReply('为什么你要这么做？', contract: contract());
      expect(reply, contains('为什么'));
      expect(reply, contains('烛火'));
      expect(reply, contains('知识'));
    });

    test('够了/停下 → 月光与寂静', () {
      final reply = localReply('够了，停下吧', contract: contract());
      expect(reply, contains('停'));
      expect(reply, contains('月光'));
    });

    test('契约/灵魂 → 书斋阴影与灵魂燃烧', () {
      final reply = localReply('关于我们的契约', contract: contract());
      expect(reply, contains('契约'));
      expect(reply, contains('灵魂'));
      expect(reply, contains('书斋'));
    });

    test('求索/真理 → 彼岸与追问', () {
      final reply = localReply('我一生都在求索真理', contract: contract());
      expect(reply, contains('求索'));
      expect(reply, contains('彼岸'));
    });

    test('默认分支 → 契约书与值得被追问', () {
      final reply = localReply('我仰望星空', contract: contract());
      expect(reply, contains('契约书'));
      expect(reply, contains('值得被追问'));
    });
  });

  group('localReply - 动态角色名替换', () {
    test('浮士德契约 → 回复出现浮士德', () {
      final reply = localReply('我仰望星空', contract: contract());
      expect(reply, contains('浮士德'));
    });

    test('但丁契约（埃德蒙·唐泰斯）→ 回复出现正确角色名而非浮士德', () {
      final reply = localReply(
        '你小心在黑暗中摸索，试图找到一丝线索',
        contract: contract(roleName: '埃德蒙·唐泰斯'),
      );
      expect(reply, contains('埃德蒙·唐泰斯'));
      expect(reply, isNot(contains('浮士德')));
    });

    test('任意自定义角色名均可替换', () {
      final reply = localReply('我仰望星空', contract: contract(roleName: '旅人'));
      expect(reply, contains('旅人'));
    });
  });

  group('localReply - 不产生锚点病句', () {
    test('锚点核心信念值不会被硬塞进叙事模板', () {
      const c = Contract(
        roleName: '埃德蒙·唐泰斯',
        // 核心信念是完整的价值观陈述（非形容词），不应被插入叙事
        anchor: [StateItem(key: '核心信念', value: StringValue('做人要正直，问心无愧'))],
      );
      final reply = localReply('你小心在黑暗中摸索', contract: c);
      // 不应出现"目光做人要正直，问心无愧"这类病句
      expect(reply, isNot(contains('目光做人')));
      expect(reply, isNot(contains('做人要正直，问心无愧')));
    });
  });
}
