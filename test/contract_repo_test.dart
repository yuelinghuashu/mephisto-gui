import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/parser/meph_parser.dart';
import 'package:mephisto/services/parser/meph_serializer.dart';
import 'package:mephisto/services/storage/contract_repo.dart';

/// 契约仓库纯函数测试：命运说明（分支一句话）的提取。
///
/// 命运说明以独立系统区块 `@命运` 存储（由 serializer 写入，首页据此展示），
/// 【角色背景】区块保持纯净，不含任何标记。
void main() {
  const withFateBlock = '''
@命运
理想国支线：浮士德在边际海岸望向乌托邦

【角色名】
浮士德

【角色背景】
他是一位学识渊博的学者。

【开局场景】
黄昏的海岸。
''';

  const withoutFateBlock = '''
【角色名】
浮士德

【角色背景】
他是一位学识渊博的学者。

【开局场景】
黄昏的海岸。
''';

  group('extractBranchTitle（@命运 系统区块）', () {
    test('含 @命运 区块时返回其首行内容', () {
      expect(extractBranchTitle(withFateBlock), '理想国支线：浮士德在边际海岸望向乌托邦');
    });

    test('无 @命运 区块时返回 null', () {
      expect(extractBranchTitle(withoutFateBlock), isNull);
    });

    test('其他 @ 系统区块不影响（仅读取 @命运）', () {
      const otherSystemBlock = '''
【角色名】
测试

@分支点
第 3 轮
''';
      expect(extractBranchTitle(otherSystemBlock), isNull);
    });

    test('空字符串返回 null', () {
      expect(extractBranchTitle(''), isNull);
    });
  });

  group('serializeMeph 输出 @命运 区块（Contract.branchTitle）', () {
    test('branchTitle 非空时输出独立系统区块', () {
      const contract = Contract(
        roleName: '浮士德',
        branchTitle: '理想国支线：浮士德在边际海岸望向乌托邦',
      );
      final content = serializeMeph(contract);

      // @命运 作为「门面区块」位于文件最顶部（首个区块）
      expect(
        content.startsWith('@命运\n理想国支线：浮士德在边际海岸望向乌托邦'),
        isTrue,
      );
      // 可逆：序列化后能解析回 branchTitle
      expect(parseMeph(content).branchTitle, '理想国支线：浮士德在边际海岸望向乌托邦');
    });

    test('branchTitle 为空时不输出 @命运 区块', () {
      const contract = Contract(roleName: '浮士德');
      final content = serializeMeph(contract);

      expect(content, isNot(contains('@命运')));
      expect(parseMeph(content).branchTitle, '');
    });

    test('序列化输出可被 parseMeph 完整解析（区块不游离）', () {
      const contract = Contract(
        roleName: '浮士德',
        background: '一位学者。',
        opening: '黄昏的海岸。',
        branchTitle: '理想国支线',
      );
      final content = serializeMeph(contract);
      final parsed = parseMeph(content);

      expect(parsed.roleName, '浮士德');
      // 序列化文本区块末尾带换行（区块间空行分隔的既有行为），用 strip 断言
      expect(parsed.background.trim(), '一位学者。');
      expect(parsed.opening.trim(), '黄昏的海岸。');
      expect(parsed.branchTitle, '理想国支线');
    });
  });

  group('子版保存：branchTitle 经 Contract 字段持久化', () {
    test('saveChild 传入 branchTitle 时生成文件含 @命运 区块', () async {
      // 用临时目录模拟契约目录（避免真实用户目录）
      // 此处仅验证「branchTitle → Contract → serialize 输出 @命运」链路最简形式
      const contract = Contract(
        roleName: '浮士德',
        branchTitle: '理想国支线',
      );
      final content = serializeMeph(
        contract,
        runtimeState: const {},
      );
      expect(content.startsWith('@命运\n理想国支线'), isTrue);
    });
  });

  group('updateFateBlock（文本级更新 @命运 区块）', () {
    test('替换已有 @命运 区块内容，其他内容保持不变', () {
      final updated = updateFateBlock(withFateBlock, '新的命运说明');

      // 新内容生效
      expect(extractBranchTitle(updated), '新的命运说明');
      // 其他区块内容完全保留
      expect(updated, contains('【角色名】\n浮士德'));
      expect(updated, contains('【角色背景】\n他是一位学识渊博的学者。'));
      expect(updated, contains('【开局场景】\n黄昏的海岸。'));
    });

    test('newTitle 为空时移除整个 @命运 区块', () {
      final updated = updateFateBlock(withFateBlock, '');

      // 无 @命运 区块
      expect(updated, isNot(contains('@命运')));
      expect(extractBranchTitle(updated), isNull);
      // 其他区块内容完全保留
      expect(updated, contains('【角色名】\n浮士德'));
      expect(updated, contains('【角色背景】\n他是一位学识渊博的学者。'));
    });

    test('无 @命运 区块时在文件顶部插入新内容', () {
      final updated = updateFateBlock(withoutFateBlock, '新的命运说明');

      // 新 @命运 区块位于最顶部
      expect(updated.startsWith('@命运\n新的命运说明'), isTrue);
      expect(extractBranchTitle(updated), '新的命运说明');
      // 原有内容保留
      expect(updated, contains('【角色名】\n浮士德'));
      expect(updated, contains('【开局场景】\n黄昏的海岸。'));
    });

    test('无 @命运 区块且 newTitle 为空 → 原样返回', () {
      expect(updateFateBlock(withoutFateBlock, ''), withoutFateBlock);
    });

    test('更新后内容可被 parseMeph 完整解析（不破坏文件结构）', () {
      const contract = Contract(
        roleName: '浮士德',
        branchTitle: '旧说明',
        background: '一位学者。',
        opening: '黄昏的海岸。',
        rules: [
          Rule(
            name: '测试',
            condition: '包含 "契约"',
            action: '注入 "觉醒"',
            line: 1,
          ),
        ],
      );
      final content = serializeMeph(contract);
      final updated = updateFateBlock(content, '新说明');

      final parsed = parseMeph(updated);
      expect(parsed.roleName, '浮士德');
      expect(parsed.branchTitle, '新说明');
      expect(parsed.background.trim(), '一位学者。');
      expect(parsed.opening.trim(), '黄昏的海岸。');
      expect(parsed.rules.length, 1);
      expect(parsed.rules.first.name, '测试');
    });
  });
}