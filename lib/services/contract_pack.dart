/// 契约打包服务：命运树/舞台目录 ↔ ZIP 导出/导入
///
/// 对外提供：
///   - [packContractTree]：将母版 + 全部子版打包为 zip（内存字节，供保存对话框写入）
///   - [packStage]：将整个舞台目录打包为 zip
///   - [unpackMeph]：解压 zip 中的 .meph / .child.meph 文件到契约目录（自动防重名）
///
/// 使用标准 ZIP 格式（`archive` 包），无需自定义格式：
///   - 导出 = 收集文件 → ZipEncoder → 用户选择位置保存 .zip
///   - 导入 = 选择 .zip → ZipDecoder → 提取 .meph → 复制到契约目录
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

import 'storage/contract_dir.dart';

/// 将一组文件打包为 zip 字节。
///
/// 参数：
///   - files: 待打包文件（绝对路径列表）
///   - fileNames: 打包后的相对路径名（与 files 对齐）
///
/// 仅打包仍存在的文件；缺失文件跳过不中断。
Future<Uint8List> _buildZip(
  List<String> files,
  List<String> fileNames,
) async {
  final archive = Archive();

  for (var i = 0; i < files.length; i++) {
    final file = File(files[i]);
    if (!await file.exists()) continue;
    final bytes = await file.readAsBytes();
    archive.addFile(ArchiveFile(fileNames[i], bytes.length, bytes));
  }

  final encoder = ZipEncoder();
  return Uint8List.fromList(encoder.encode(archive));
}

/// 打包单棵命运树（母版 + 全部子版）为 zip。
///
/// 参数：
///   - masterFileName: 母版文件名（如 `faust.meph`）
///   - dir: 契约目录（null 时使用当前契约目录）
///
/// 打包内容 = 「母版文件名前缀」开头的全部 .meph（含 .child.meph 存档）。
Future<Uint8List> packContractTree(
  String masterFileName, {
  Directory? dir,
}) async {
  final targetDir = dir ?? await getContractsDirectory();
  final prefix = masterFileName.replaceAll('.meph', '');

  final names = await targetDir
      .list()
      .where((e) => e is File && e.path.endsWith('.meph'))
      .map((e) => e.path.split(Platform.pathSeparator).last)
      .where((name) => name == masterFileName || name.startsWith('$prefix.'))
      .toList();

  final files = names.map((name) => '${targetDir.path}/$name').toList();
  return _buildZip(files, names);
}

/// 打包整个舞台目录为 zip。
///
/// 打包内容 = 舞台目录内全部 .meph（角色卡 + .child.meph 存档）。
Future<Uint8List> packStage(
  String stageDirPath, {
  String? stageName,
}) async {
  final dir = Directory(stageDirPath);
  if (!await dir.exists()) throw Exception('舞台目录不存在: $stageDirPath');

  final name = stageName ?? stageDirPath.split(Platform.pathSeparator).last;
  final names = await dir
      .list()
      .where((e) => e is File && e.path.endsWith('.meph'))
      .map((e) => e.path.split(Platform.pathSeparator).last)
      .toList();

  final files = names.map((n) => '$stageDirPath/$n').toList();
  // 舞台 zip 内文件以舞台名前缀组织，便于还原到契约目录
  final archiveNames = names.map((n) => '$name/$n').toList();
  return _buildZip(files, archiveNames);
}

/// 从 zip 中提取全部 .meph 文件到契约目录（自动防重名 + 续号）。
///
/// 兼容两种 zip 布局：
///   - 平铺：`faust.meph` / `faust.dark.meph`（单契约导出）
///   - 舞台目录：`Kurukshetra/阿周那.meph` / `Kurukshetra/Arjuna.child.meph`
///     解压时保留一级目录（舞台目录自动还原）。
///
/// 返回值：成功导入的文件数。
Future<int> unpackMeph(Uint8List bytes) async {
  final archive = ZipDecoder().decodeBytes(bytes);
  final root = await getContractsDirectory();

  var count = 0;
  for (final entry in archive) {
    if (entry.isFile == false) continue;
    final name = entry.name;
    if (!name.endsWith('.meph')) continue;

    // 目录结构：`舞台名/文件名.meph` → 创建目标子目录
    final segments = name.replaceAll('\\', '/').split('/');
    final fileName = segments.last;
    final subDir = segments.length > 1 ? segments[segments.length - 2] : null;

    Directory targetDir = root;
    if (subDir != null) {
      targetDir = Directory('${root.path}/$subDir');
      await targetDir.create(recursive: true);
    }

    // 防重名（追加序号，如 `faust (2).meph`）
    final target = await _uniqueTarget(targetDir, fileName);
    await target.writeAsBytes(entry.content);
    count++;
  }
  return count;
}

/// 生成不冲突的目标文件（重名时追加 ` (N)` 序号）。
Future<File> _uniqueTarget(Directory dir, String fileName) async {
  var targetName = fileName;
  final baseName = fileName.replaceAll('.meph', '');
  var counter = 2;
  while (File('${dir.path}/$targetName').existsSync()) {
    targetName = '$baseName ($counter).meph';
    counter++;
  }
  return File('${dir.path}/$targetName');
}