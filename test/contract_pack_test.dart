import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/services/contract_pack.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 契约打包服务测试：命运树 / 舞台目录 ↔ ZIP 导出 / 导入
///
/// 覆盖：
///   - [packContractTree]：只打包指定母版前缀下的 .meph（母版 + 子版，不含其他母版）
///   - [packStage]：打包舞台目录内全部 .meph，以舞台名前缀组织，便于还原
///   - [unpackMeph]：平铺 / 舞台目录两种 zip 布局的还原、自动防重名续号
///   - 非 .meph 文件（如 .txt）不参与打包 / 导入
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory contractsDir;

  setUp(() async {
    contractsDir = await Directory.systemTemp.createTemp('mephisto_pack_test_');
    // 契约目录指向临时目录
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': contractsDir.path,
    });
  });

  tearDown(() async {
    if (contractsDir.existsSync()) {
      await contractsDir.delete(recursive: true);
    }
    // 清理 Zip Slip 防御测试可能写入的父目录残留（防御测试运行前写入）
    final stale = File('${contractsDir.parent.path}/evil.meph');
    if (stale.existsSync()) {
      await stale.delete();
    }
  });

  File touch(String name, {String content = 'content'}) {
    final file = File('${contractsDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  group('packContractTree（命运树打包）', () {
    test('只打包指定母版前缀下的 .meph（母版 + 子版），不含其他母版', () async {
      // 母版 faust + 其子版；另一个独立母版 gilgamesh 不应被打包
      touch('faust.meph');
      touch('faust.dark.meph');
      touch('faust.child.meph');
      touch('gilgamesh.meph');

      final bytes = await packContractTree('faust.meph', dir: contractsDir);
      final entries = ZipDecoder()
          .decodeBytes(bytes)
          .map((e) => e.name)
          .toList();

      expect(entries, contains('faust.meph'));
      expect(entries, contains('faust.dark.meph'));
      expect(entries, contains('faust.child.meph'));
      expect(
        entries,
        isNot(contains('gilgamesh.meph')),
        reason: '只打包含目标母版前缀的契约，其他母版不进入包',
      );
    });

    test('缺失的文件跳过不中断；非 .meph 文件不参与打包', () async {
      // 引用一个不存在的文件 + 一个 .txt
      final missing = File('${contractsDir.path}/ghost.meph');
      missing.writeAsStringSync('x');
      await missing.delete(); // 参考文件在列表读出前已删除 → 跳过
      touch('faust.meph');
      touch('notes.txt');

      final bytes = await packContractTree('faust.meph', dir: contractsDir);
      final entries = ZipDecoder()
          .decodeBytes(bytes)
          .map((e) => e.name)
          .toList();

      expect(entries, contains('faust.meph'));
      expect(entries, isNot(contains('ghost.meph')));
      expect(entries, isNot(contains('notes.txt')), reason: '非 .meph 不打包');
    });
  });

  group('packStage（舞台目录打包）', () {
    test('打包全部角色卡 + 存档，以舞台名前缀组织', () async {
      final stage = Directory('${contractsDir.path}/Kurukshetra')..createSync();
      // 舞台内角色卡 + .child 存档 + 应被忽略的非 .meph
      File('${stage.path}/Arjuna.meph').writeAsStringSync('阿周那');
      File('${stage.path}/Arjuna.child.meph').writeAsStringSync('存档');
      File('${stage.path}/readme.txt').writeAsStringSync('备注');

      final bytes = await packStage(stage.path);
      final entries = ZipDecoder()
          .decodeBytes(bytes)
          .map((e) => e.name)
          .toList();

      expect(entries, contains('Kurukshetra/Arjuna.meph'));
      expect(entries, contains('Kurukshetra/Arjuna.child.meph'));
      expect(
        entries,
        isNot(anyElement(contains('readme.txt'))),
        reason: '非 .meph 不入包',
      );
    });

    test('舞台目录不存在时抛异常', () {
      expect(
        () => packStage('${contractsDir.path}/Nope'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('舞台目录不存在'),
          ),
        ),
      );
    });
  });

  group('unpackMeph（ZIP 导入还原）', () {
    test('平铺布局：母版 + 子版按文件名还原到契约目录', () async {
      // 用 packContractTree 生成一个合法 zip，再导入到新目录
      touch('faust.meph');
      touch('faust.dark.meph');
      final bytes = await packContractTree('faust.meph', dir: contractsDir);

      // 清空目录后导入（模拟还原到空目录）
      contractsDir.deleteSync(recursive: true);
      contractsDir.createSync();
      final count = await unpackMeph(bytes);

      expect(count, 2);
      expect(File('${contractsDir.path}/faust.meph').existsSync(), isTrue);
      expect(File('${contractsDir.path}/faust.dark.meph').existsSync(), isTrue);
      expect(
        File('${contractsDir.path}/faust.meph').readAsStringSync(),
        'content',
      );
    });

    test('舞台目录布局：保留一级目录（舞台自动还原）', () async {
      // 手工构造「舞台名/角色.meph」布局的 zip（内容用 UTF-8 编码）
      final content = utf8.encode('阿周那原子');
      final archive = Archive();
      archive.addFile(
        ArchiveFile('Kurukshetra/Arjuna.meph', content.length, content),
      );
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final count = await unpackMeph(bytes);

      expect(count, 1);
      expect(
        File('${contractsDir.path}/Kurukshetra/Arjuna.meph').existsSync(),
        isTrue,
        reason: '舞台子目录应自动创建还原',
      );
      expect(
        File('${contractsDir.path}/Kurukshetra/Arjuna.meph').readAsStringSync(),
        '阿周那原子',
      );
    });

    test('重名自动续号：faust.meph → faust (2).meph', () async {
      touch('faust.meph'); // 预先占用目标名
      final bytes = await packContractTree('faust.meph', dir: contractsDir);

      final count = await unpackMeph(bytes);

      expect(count, 1);
      expect(
        File('${contractsDir.path}/faust (2).meph').existsSync(),
        isTrue,
        reason: '重名文件应追加 (N) 序号而非覆盖',
      );
    });

    test('zip 中的非 .meph 条目（.txt / 目录）被忽略', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('faust.meph', 3, 'abc'.codeUnits))
        ..addFile(ArchiveFile('readme.txt', 3, '123'.codeUnits));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final count = await unpackMeph(bytes);

      expect(count, 1, reason: '只导入 .meph，忽略 .txt');
      expect(File('${contractsDir.path}/faust.meph').existsSync(), isTrue);
      expect(File('${contractsDir.path}/readme.txt').existsSync(), isFalse);
    });

    test('Zip Slip 防御：路径穿越条目（../ 跳出契约目录）被拒绝', () async {
      // 恶意 zip：条目名使用 ../ 试图写入契约目录之外
      final archive = Archive()
        ..addFile(ArchiveFile('../evil.meph', 3, 'x'.codeUnits))
        ..addFile(ArchiveFile('../../evil2.meph', 3, 'x'.codeUnits))
        ..addFile(
          ArchiveFile('Kurukshetra/../../evil3.meph', 3, 'x'.codeUnits),
        );
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final count = await unpackMeph(bytes);

      // 恶意条目全部被拒绝（不写入契约目录，也不写入外部）
      expect(count, 0, reason: '路径穿越条目应被拒绝，不导入');
      expect(File('${contractsDir.path}/evil.meph').existsSync(), isFalse);
      expect(
        File('${contractsDir.parent.path}/evil.meph').existsSync(),
        isFalse,
        reason: '不得写入契约目录的父目录（Zip Slip）',
      );
      expect(
        File('${contractsDir.path}/Kurukshetra/evil3.meph').existsSync(),
        isFalse,
      );
    });

    test('合法舞台目录路径（Kurukshetra/Arjuna.meph）不受影响', () async {
      final content = utf8.encode('正常内容');
      final archive = Archive()
        ..addFile(ArchiveFile('Camlann/Arthur.meph', content.length, content));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final count = await unpackMeph(bytes);

      expect(count, 1);
      expect(
        File('${contractsDir.path}/Camlann/Arthur.meph').existsSync(),
        isTrue,
        reason: '合法的一级舞台子目录应正常还原',
      );
    });
  });
}
