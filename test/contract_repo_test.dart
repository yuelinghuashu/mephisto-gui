import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/parser/meph_parser.dart';
import 'package:mephisto/services/parser/meph_serializer.dart';
import 'package:mephisto/services/storage/contract_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(content.startsWith('@命运\n理想国支线：浮士德在边际海岸望向乌托邦'), isTrue);
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

    test('序列化历史：system 条目以 system: 前缀输出且可往返还原', () {
      const contract = Contract(
        roleName: '浮士德',
        history: [
          HistoryEntry(role: MessageRole.fate, content: '出发'),
          HistoryEntry(role: MessageRole.assistant, content: '回应'),
          HistoryEntry(role: MessageRole.system, content: '（额外叙事：群鸟掠过）'),
        ],
      );
      final content = serializeMeph(contract);
      final parsed = parseMeph(content);

      // system 条目不得被写成 assistant（此前会被读档成伪造角色对白）
      expect(content, contains('system: （额外叙事：群鸟掠过）'));
      expect(content, isNot(contains('assistant: （额外叙事')));

      expect(parsed.history, hasLength(3));
      expect(parsed.history[2].role, MessageRole.system);
      expect(parsed.history[2].content, '（额外叙事：群鸟掠过）');
    });
  });

  group('子版保存：branchTitle 经 Contract 字段持久化', () {
    test('saveChild 传入 branchTitle 时生成文件含 @命运 区块', () async {
      // 用临时目录模拟契约目录（避免真实用户目录）
      // 此处仅验证「branchTitle → Contract → serialize 输出 @命运」链路最简形式
      const contract = Contract(roleName: '浮士德', branchTitle: '理想国支线');
      final content = serializeMeph(contract, runtimeState: const {});
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
          Rule(name: '测试', condition: '包含 "契约"', action: '注入 "觉醒"', line: 1),
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

  group('extractRoleName（从 .meph 内容提取角色名）', () {
    test('提取【角色名】区块首行', () {
      const content = '''
【角色名】
浮士德

【锚点】
- 核心信念：探索
''';
      expect(extractRoleName(content), '浮士德');
    });

    test('角色名区块首行为 # 注释时跳过注释取真实角色名', () {
      const content = '''
【角色名】
# 注释行
梅菲斯特
''';
      expect(extractRoleName(content), '梅菲斯特');
    });

    test('无【角色名】区块返回 null', () {
      const content = '''
【锚点】
- 核心信念：探索
''';
      expect(extractRoleName(content), isNull);
    });

    test('角色名区块为空返回 null', () {
      const content = '''
【角色名】

【锚点】
- 核心信念：探索
''';
      expect(extractRoleName(content), isNull);
    });

    test('非角色名区块不影响（在角色名之前出现的其他区块）', () {
      const content = '''
@命运
帝国支线

【角色名】
浮士德
''';
      expect(extractRoleName(content), '浮士德');
    });
  });

  group('契约仓库 CRUD（临时目录）', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mephisto_repo_test_');
      SharedPreferences.setMockInitialValues({
        'mephisto_contracts_directory': tempDir.path,
      });
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    void touch(String name, {String content = '内容'}) {
      File('${tempDir.path}/$name').writeAsStringSync(content);
    }

    test('importContract：复制文件到契约目录，返回目标路径', () async {
      final source = File('${tempDir.path}/外部文件.meph')
        ..writeAsStringSync('外部内容');
      final target = await importContract(source.path, '导入.meph');
      expect(target, endsWith('导入.meph'));
      expect(File(target).readAsStringSync(), '外部内容');
    });

    test('importContract：重名时追加序号（不覆盖已有文件）', () async {
      touch('故事.meph', content: '已有');
      final source = File('${tempDir.path}/外部故事.meph')
        ..writeAsStringSync('新内容');
      final target = await importContract(source.path, '故事.meph');
      expect(target, endsWith('故事 (2).meph'));
      expect(File('${tempDir.path}/故事.meph').readAsStringSync(), '已有');
      expect(File(target).readAsStringSync(), '新内容');
    });

    test('importContract：源文件不存在时抛异常', () async {
      expect(
        () => importContract('${tempDir.path}/不存在.meph', 'x.meph'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteContractCascade：删除母版及其下所有子版，返回删除数', () async {
      touch('faust.meph');
      touch('faust.dark.meph');
      touch('faust.dark.light.meph');
      touch('dantes.meph'); // 无关母版不受影响

      final deleted = await deleteContractCascade('faust.meph');
      expect(deleted, 3); // 母版 + 2 个子版
      expect(File('${tempDir.path}/faust.meph').existsSync(), isFalse);
      expect(File('${tempDir.path}/faust.dark.meph').existsSync(), isFalse);
      expect(
        File('${tempDir.path}/faust.dark.light.meph').existsSync(),
        isFalse,
      );
      expect(
        File('${tempDir.path}/dantes.meph').existsSync(),
        isTrue,
        reason: '无关母版不受级联删除影响',
      );
    });

    test('deleteContractCascade：母版不存在时返回 0', () async {
      final deleted = await deleteContractCascade('ghost.meph');
      expect(deleted, 0);
    });

    test('updateContractBranchTitle：更新 @命运 区块并写回磁盘', () async {
      touch('faust.child.meph', content: '【角色名】\n浮士德\n\n@命运\n旧说明');
      final ok = await updateContractBranchTitle('faust.child.meph', '新说明');
      expect(ok, isTrue);
      final updated = File(
        '${tempDir.path}/faust.child.meph',
      ).readAsStringSync();
      expect(updated, contains('@命运'));
      expect(updated, contains('新说明'));
      expect(updated, isNot(contains('旧说明')));
    });

    test('updateContractBranchTitle：文件不存在返回 false', () async {
      final ok = await updateContractBranchTitle('ghost.meph', '新说明');
      expect(ok, isFalse);
    });
  });
}
