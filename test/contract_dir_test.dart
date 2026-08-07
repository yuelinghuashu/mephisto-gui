import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/services/storage/contract_dir.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 契约目录管理测试：ensureContracts 种子逻辑
///
/// 核心验证：
///   1. 目录未种子 → 首次调用复制内置模板（faust.meph / dantes.meph）
///   2. 目录已种子 → 不自动恢复被删除的模板（尊重用户删除）
///   3. 切换新目录 → 新目录自动获得内置模板（种子标记按目录绑定）
///   4. force: true → 无视种子标记，强制恢复缺失的内置模板
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_dir_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 指向临时目录作为契约目录
  void seedDir(String path) {
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': path,
    });
  }

  test('目录未种子 → 首次调用复制内置模板（含官方示范子版）', () async {
    seedDir(tempDir.path);

    await ensureContracts();

    // 母版契约
    expect(File('${tempDir.path}/faust.meph').existsSync(), isTrue);
    expect(File('${tempDir.path}/dantes.meph').existsSync(), isTrue);
    // 官方示范子版（命运支流枝叶）
    expect(File('${tempDir.path}/dantes.bonapart.meph').existsSync(), isTrue);
    expect(File('${tempDir.path}/faust.utopia.meph').existsSync(), isTrue);
    // 内容是完整的内置模板（非空）
    final faust = File('${tempDir.path}/faust.meph').readAsStringSync();
    expect(faust, contains('【角色名】'));
    expect(faust, contains('浮士德'));
  });

  test('目录已种子 → 不自动恢复被删除的模板', () async {
    seedDir(tempDir.path);
    await ensureContracts();

    // 用户删除 faust.meph
    File('${tempDir.path}/faust.meph').deleteSync();
    expect(File('${tempDir.path}/faust.meph').existsSync(), isFalse);

    // 再次调用 ensureContracts：种子标记已置位，不恢复
    await ensureContracts();
    expect(File('${tempDir.path}/faust.meph').existsSync(), isFalse);
    // dantes.meph 未被删除仍存在
    expect(File('${tempDir.path}/dantes.meph').existsSync(), isTrue);
  });

  test('切换到新目录（种子标记按目录绑定）→ 新目录自动复制内置模板', () async {
    // 第一个目录：种子 + 复制
    seedDir(tempDir.path);
    await ensureContracts();
    expect(File('${tempDir.path}/faust.meph').existsSync(), isTrue);

    // 切换到新目录（模拟用户在设置页修改契约目录）
    final newDir = Directory('${tempDir.path}/new_contracts');
    seedDir(newDir.path);

    // 旧版的全局标记已置位（模拟遗留数据）；新目录无绑定标记
    await ensureContracts();

    // 新目录应获得内置模板（核心 bug 修复验证）
    expect(File('${newDir.path}/faust.meph').existsSync(), isTrue);
    expect(File('${newDir.path}/dantes.meph').existsSync(), isTrue);
  });

  test('force: true → 无视种子标记，强制恢复缺失的内置模板', () async {
    seedDir(tempDir.path);
    await ensureContracts();

    // 用户删除两个内置模板
    File('${tempDir.path}/faust.meph').deleteSync();
    File('${tempDir.path}/dantes.meph').deleteSync();

    // 正常调用不恢复（种子已置位）
    await ensureContracts();
    expect(File('${tempDir.path}/faust.meph').existsSync(), isFalse);

    // force: true 强制恢复
    await ensureContracts(force: true);
    expect(File('${tempDir.path}/faust.meph').existsSync(), isTrue);
    expect(File('${tempDir.path}/dantes.meph').existsSync(), isTrue);
  });

  test('force: true 不覆盖用户已有的同名文件', () async {
    seedDir(tempDir.path);
    await ensureContracts();

    // 用户自定义修改了 dantes.meph
    const customContent = '【角色名】\n自定义角色\n';
    File('${tempDir.path}/dantes.meph').writeAsStringSync(customContent);

    // force 恢复：dantes.meph 已存在 → 不覆盖
    await ensureContracts(force: true);
    expect(
      File('${tempDir.path}/dantes.meph').readAsStringSync(),
      customContent,
    );
    // 缺失的其他模板被恢复
    expect(File('${tempDir.path}/faust.meph').existsSync(), isTrue);
  });

  test('listMephFileNames 排序并过滤 .meph 文件', () async {
    final dir = Directory('${tempDir.path}/list_test');
    dir.createSync(recursive: true);
    File('${dir.path}/b.meph').writeAsStringSync('');
    File('${dir.path}/a.meph').writeAsStringSync('');
    File('${dir.path}/c.txt').writeAsStringSync('');
    File('${dir.path}/a.child.meph').writeAsStringSync('');

    final names = await listMephFileNames(dir);
    expect(names, ['a.child.meph', 'a.meph', 'b.meph']); // 字典序
    expect(names, isNot(contains('c.txt')));
  });
}