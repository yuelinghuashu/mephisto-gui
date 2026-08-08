import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/services/storage/contract_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [renameContractCascade] 级联重命名测试
///
/// 验证母版重命名时，其下所有子版前缀一并同步：
///   - `faust.meph` → `歌德.meph`
///   - `faust.dark.meph` → `歌德.dark.meph`
///   - `faust.dark.light.meph` → `歌德.dark.light.meph`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_rename_test_');
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('母版 + 所有子版前缀级联同步', () async {
    // 创建母版 + 多级子版
    for (final name in [
      'faust.meph',
      'faust.dark.meph',
      'faust.dark.light.meph',
    ]) {
      File('${tempDir.path}/$name').writeAsStringSync('内容\n');
    }

    final ok = await renameContractCascade('faust.meph', '歌德.meph');
    expect(ok, isTrue);

    // 母版已重命名
    expect(File('${tempDir.path}/faust.meph').existsSync(), isFalse);
    expect(File('${tempDir.path}/歌德.meph').existsSync(), isTrue);

    // 一级子版前缀同步
    expect(File('${tempDir.path}/faust.dark.meph').existsSync(), isFalse);
    expect(File('${tempDir.path}/歌德.dark.meph').existsSync(), isTrue);

    // 二级子版前缀同步
    expect(File('${tempDir.path}/faust.dark.light.meph').existsSync(), isFalse);
    expect(File('${tempDir.path}/歌德.dark.light.meph').existsSync(), isTrue);
  });

  test('母版不存在 → 返回 false 且不执行任何重命名', () async {
    File('${tempDir.path}/faust.meph').writeAsStringSync('内容\n');
    File('${tempDir.path}/faust.dark.meph').writeAsStringSync('内容\n');

    final ok = await renameContractCascade('不存在的.meph', '新名字.meph');
    expect(ok, isFalse);

    // 现有文件保持原样
    expect(File('${tempDir.path}/faust.meph').existsSync(), isTrue);
    expect(File('${tempDir.path}/faust.dark.meph').existsSync(), isTrue);
  });

  test('子版重命名冲突 → 返回 false', () async {
    File('${tempDir.path}/faust.meph').writeAsStringSync('内容\n');
    File('${tempDir.path}/faust.dark.meph').writeAsStringSync('内容\n');
    // 目标子版名冲突
    File('${tempDir.path}/歌德.dark.meph').writeAsStringSync('内容\n');

    final ok = await renameContractCascade('faust.meph', '歌德.meph');
    expect(ok, isFalse);
  });
}