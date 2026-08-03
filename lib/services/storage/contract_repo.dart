/// 契约仓库：契约文件的 CRUD 与文件名校验
///
/// 与 [contract_dir.dart]（目录管理）分离，本文件负责：
///   - 契约文件读写/删除/导入/重命名（依赖契约目录）
///   - 子版/母版文件名校验与提取
///   - 角色名提取
library;

import 'dart:io';

import 'contract_dir.dart';

// ============================================================
// 契约 CRUD
// ============================================================

/// 列出所有 .meph 契约文件
///
/// 返回值：契约文件名列表（如 ['faust.meph', 'dantes.meph']）。
Future<List<String>> listContracts() async {
  final dir = await getContractsDirectory();
  return listMephFileNames(dir);
}

/// 读取指定契约文件的内容
///
/// 参数：
///   - name: 契约文件名（如 `faust.meph`）
///
/// 返回值：契约文件完整内容；文件不存在时返回 null。
Future<String?> readContract(String name) async {
  final dir = await getContractsDirectory();
  final file = File('${dir.path}/$name');
  if (!file.existsSync()) return null;
  return file.readAsString();
}

/// 保存契约文件（创建或覆盖）
///
/// 参数：
///   - name: 契约文件名（如 `my_story.meph`）
///   - content: 契约文件完整内容
Future<void> saveContract(String name, String content) async {
  final dir = await getContractsDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsString(content);
}

/// 删除契约文件
///
/// 参数：
///   - name: 契约文件名
///
/// 返回值：是否删除成功（false 表示文件不存在或删除失败）。
Future<bool> deleteContract(String name) async {
  final dir = await getContractsDirectory();
  final file = File('${dir.path}/$name');
  if (!file.existsSync()) return false;
  try {
    await file.delete();
    return true;
  } catch (_) {
    return false;
  }
}

/// 导入本地 .meph 文件到契约目录。
///
/// 参数：
///   - sourcePath: 本地 .meph 文件的完整路径
///   - fileName: 目标文件名（如 `my_story.meph`）
///
/// 返回值：保存后的完整文件路径；导入失败时抛出异常。
Future<String> importContract(String sourcePath, String fileName) async {
  final dir = await getContractsDirectory();
  final source = File(sourcePath);
  if (!source.existsSync()) {
    throw Exception('源文件不存在: $sourcePath');
  }

  // 处理重名：追加序号（如 `my_story (2).meph`）
  var targetName = fileName;
  final baseName = fileName.replaceAll('.meph', '');
  var counter = 2;
  while (File('${dir.path}/$targetName').existsSync()) {
    targetName = '$baseName ($counter).meph';
    counter++;
  }

  final target = File('${dir.path}/$targetName');
  await source.copy(target.path);
  return target.path;
}

/// 重命名契约文件。
///
/// 参数：
///   - oldName: 旧文件名（如 `faust.meph`）
///   - newName: 新文件名（如 `歌德.meph`）
///
/// 返回值：是否重命名成功（false 表示旧文件不存在或新文件已存在）。
Future<bool> renameContract(String oldName, String newName) async {
  final dir = await getContractsDirectory();
  final oldFile = File('${dir.path}/$oldName');
  final newFile = File('${dir.path}/$newName');
  if (!oldFile.existsSync() || newFile.existsSync()) return false;
  try {
    await oldFile.rename(newFile.path);
    return true;
  } catch (_) {
    return false;
  }
}

/// 是否可安全使用新文件名（契约目录中不存在同名文件）。
///
/// 返回值：true 表示名称可用；false 表示冲突。
Future<bool> isContractNameAvailable(String name) async {
  final dir = await getContractsDirectory();
  return !File('${dir.path}/$name').existsSync();
}

/// 级联删除母版及其下所有子版。
///
/// 参数：
///   - masterFileName: 母版文件名（如 `faust.meph`）
///
/// 返回值：删除的文件总数（母版 + 子版）。
Future<int> deleteContractCascade(String masterFileName) async {
  final dir = await getContractsDirectory();
  final masterPrefix = extractMasterPrefix(masterFileName);

  var deleted = 0;
  // 先删除母版
  if (await deleteContract(masterFileName)) deleted++;

  // 再删除该母版下的所有子版（`母版前缀.*.meph` 且非母版自身）
  final children = listMephFileNames(dir)
      .where((name) => name != masterFileName)
      .where((name) => name.startsWith('$masterPrefix.'))
      .toList();
  for (final child in children) {
    if (await deleteContract(child)) deleted++;
  }

  return deleted;
}

// ============================================================
// 文件名校验与角色名提取
// ============================================================

/// 解析文件名的「基础名 + 首个点分隔的下标」。
///
/// 返回基础名（去掉 `.meph` 后缀）与第一个 `.` 的下标（无点时为 -1）。
/// 三个文件名校验函数（[isChildFileName] / [extractMasterPrefix] /
/// [extractBranchName]）共用此解析，消除重复的 `replaceAll + indexOf` 样板。
(String base, int dotIndex) _splitBaseName(String fileName) {
  final base = fileName.replaceAll('.meph', '');
  return (base, base.indexOf('.'));
}

/// 判断文件名是否为子版文件（`baseName.suffix.meph`，suffix 非空且非母版自身）。
///
/// 例如：
///   - `faust.meph` -> false（母版）
///   - `faust.child.meph` / `faust.dark.meph` -> true（子版）
bool isChildFileName(String fileName) {
  final (base, dotIndex) = _splitBaseName(fileName);
  return dotIndex != -1 && dotIndex != base.length - 1;
}

/// 提取母版基础名（如 `faust.child.meph` -> `faust`，`faust.meph` -> `faust`）。
String extractMasterPrefix(String fileName) {
  final (base, dotIndex) = _splitBaseName(fileName);
  if (dotIndex == -1) return base;
  return base.substring(0, dotIndex);
}

/// 提取子版分支名（如 `faust.dark.meph` -> `dark`，`faust.child.meph` -> `child`）。
///
/// 仅子版文件有分支名；母版（`faust.meph`）返回 null。
/// 统一实现，消除各处重复的 `replaceAll('.meph', '') + indexOf('.')` 样板。
String? extractBranchName(String fileName) {
  final (base, dotIndex) = _splitBaseName(fileName);
  if (dotIndex == -1 || dotIndex == base.length - 1) return null;
  return base.substring(dotIndex + 1);
}

/// 从 .meph 内容中提取【角色名】。
///
/// 解析规则：
///   - 找到 `【角色名】` 区块标题行
///   - 取其后的第一行非空、非注释内容作为角色名
///
/// 返回 null 表示提取失败（未找到区块或内容为空）。
String? extractRoleName(String content) {
  final lines = content.split('\n');
  var inRoleNameBlock = false;

  for (final line in lines) {
    final trimmed = line.trim();

    // 检测区块标题
    if (trimmed.startsWith('【') && trimmed.endsWith('】')) {
      final title = trimmed.substring(1, trimmed.length - 1).trim();
      inRoleNameBlock = title == '角色名';
      continue;
    }

    // 在角色名区块内：取第一行非空、非注释内容
    if (inRoleNameBlock) {
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      return trimmed;
    }
  }

  return null;
}