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

Future<List<String>> listContracts() async {
  final dir = await getContractsDirectory();
  return listMephFileNames(dir);
}

/// 读取契约文件内容（文件不存在时返回 null）
Future<String?> readContract(String name) async {
  final dir = await getContractsDirectory();
  final file = File('${dir.path}/$name');
  if (!file.existsSync()) return null;
  return file.readAsString();
}

Future<void> saveContract(String name, String content) async {
  final dir = await getContractsDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsString(content);
}

/// 删除契约文件（false = 文件不存在或删除失败）
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

/// 导入本地 .meph 文件到契约目录（失败时抛出异常）
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

/// 级联重命名母版及其下所有子版（同步子树文件名前缀）。
///
/// 例如 `faust.meph` → `歌德.meph` 时，一并重命名：
///   - `faust.dark.meph` → `歌德.dark.meph`
///   - `faust.dark.light.meph` → `歌德.dark.light.meph`
///
/// 参数：
///   - oldMasterName: 旧母版文件名（如 `faust.meph`）
///   - newMasterName: 新母版文件名（如 `歌德.meph`）
///
/// 返回值：是否全部重命名成功（母版或任一子版失败时返回 false）。
Future<bool> renameContractCascade(
  String oldMasterName,
  String newMasterName,
) async {
  // 母版重命名失败直接返回
  if (!await renameContract(oldMasterName, newMasterName)) return false;

  final oldPrefix = oldMasterName.replaceAll('.meph', '');
  final newPrefix = newMasterName.replaceAll('.meph', '');

  // 同步所有子版前缀（`旧前缀.*.meph` 且非母版自身）
  final dir = await getContractsDirectory();
  final allNames = await listMephFileNames(dir);
  final children = allNames
      .where((name) => name != oldMasterName)
      .where((name) => name.startsWith('$oldPrefix.'))
      .toList();
  for (final child in children) {
    final suffix = child.substring(oldPrefix.length);
    final ok = await renameContract(child, '$newPrefix$suffix');
    if (!ok) return false;
  }
  return true;
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
  final allNames = await listMephFileNames(dir);
  final children = allNames
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

/// 解析文件名为「基础名（去 `.meph` 后缀）的路径段列表」。
///
/// 多级树模型：文件名中的 `.` 分段即层级。
///   - `faust.meph`                 → [faust]
///   - `faust.dark.meph`            → [faust, dark]
///   - `faust.dark.light.meph`      → [faust, dark, light]
/// 各文件名校验函数共用此解析，消除重复的 `replaceAll + indexOf` 样板。
List<String> _splitBaseName(String fileName) {
  return fileName.replaceAll('.meph', '').split('.');
}

/// 判断文件名是否为子版文件（母版根 后还有路径段）。
///
/// 例如：
///   - `faust.meph` -> false（母版）
///   - `faust.child.meph` / `faust.dark.meph` -> true（一级子版）
///   - `faust.dark.light.meph` -> true（二级子版）
bool isChildFileName(String fileName) => _splitBaseName(fileName).length >= 2;

/// 提取母版基础名（如 `faust.child.meph` -> `faust`，`faust.dark.light.meph` -> `faust`）。
String extractMasterPrefix(String fileName) => _splitBaseName(fileName).first;

/// 提取子版分支名（取路径最后一段；如 `faust.dark.meph` -> `dark`，
/// `faust.dark.light.meph` -> `light`）。
///
/// 仅子版文件有分支名；母版（`faust.meph`）返回 null。
String? extractBranchName(String fileName) {
  final segments = _splitBaseName(fileName);
  return segments.length >= 2 ? segments.last : null;
}

/// 提取子版「分支路径」（去掉最后一段分支名后的完整前缀）。
///
/// 用于多级树中确定父节点路径：
///   - `faust.dark.meph`            -> `faust`（父即母版）
///   - `faust.dark.light.meph`      -> `faust.dark`（父为一级分支）
///   - `faust.meph`（母版）         -> null（无父）
String? extractBranchPath(String fileName) {
  final segments = _splitBaseName(fileName);
  if (segments.length < 2) return null;
  return segments.take(segments.length - 1).join('.');
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

/// 命运说明系统保留区块名（`@命运`）
///
/// 「另存为分支」时可填写一句「命运说明」描述这条支流走向，保存子版时
/// 由 serializer 输出为独立系统区块 `@命运`，首页据此显示「命运一句话」。
/// 无该区块（如母版或未填写）时返回 null，首页回落为显示分支名。
const String fateBlockTitle = '@命运';

/// 从 .meph 内容中提取「命运说明」（分支的一句话描述）。
///
/// 读取 `@命运` 系统保留区块的首行非空内容；未找到区块/内容为空返回 null。
///
/// 仅子版文件可能含该区块；母版/旧分支无标记时返回 null。
String? extractBranchTitle(String content) {
  final lines = content.split('\n');
  var inFateBlock = false;

  for (final line in lines) {
    final trimmed = line.trim();

    // 检测区块标题（@命运 或 用户 【区块】）
    if (trimmed.startsWith('@') || (trimmed.startsWith('【') && trimmed.endsWith('】'))) {
      final isFate = trimmed == fateBlockTitle;
      // 进入 @命运 区块：开始收集内容
      inFateBlock = isFate;
      continue;
    }

    // 在 @命运 区块内：取首个非空、非注释内容行
    if (inFateBlock) {
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      return trimmed;
    }
  }

  return null;
}

/// 更新 .meph 内容中的 `@命运` 系统区块（命运说明）。
///
/// 纯文本级操作：不经过 parseMeph/serializeMeph 重建，避免丢失子版文件
/// 中的运行时状态/记忆/历史等动态内容。
///
/// 参数：
///   - content: 原 .meph 文件完整内容
///   - newTitle: 新的命运说明；空字符串时移除整个 `@命运` 区块（若存在）
///
/// 返回值：更新后的 .meph 文件内容。
String updateFateBlock(String content, String newTitle) {
  final trimmedTitle = newTitle.trim();

  // 逐行扫描，在 @命运 区块边界内记录其区间；其余内容原样保留
  final lines = content.split('\n');
  var fateStart = -1; // @命运 区块标题行下标
  var fateEnd = lines.length; // 区块结束行下标（不含）

  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();

    // 记录 @命运 区块标题行
    if (trimmed == fateBlockTitle) {
      fateStart = i;
      // 查找区块结束（下一个 @ 或 【 标题行）
      for (var j = i + 1; j < lines.length; j++) {
        final inner = lines[j].trim();
        if (inner.startsWith('@') ||
            (inner.startsWith('【') && inner.endsWith('】'))) {
          fateEnd = j;
          break;
        }
      }
      break;
    }
  }

  // ---- 原内容无 @命运 区块 ----
  if (fateStart == -1) {
    if (trimmedTitle.isEmpty) return content; // 无区块且无新说明 → 原样返回
    // 新说明 → 插入到文件最顶部（与 serializer 输出位置一致）
    final buffer = StringBuffer();
    buffer.writeln('@命运');
    buffer.writeln(trimmedTitle);
    buffer.writeln();
    // 原内容去除开头的空行，保持整洁
    var start = 0;
    while (start < lines.length && lines[start].trim().isEmpty) {
      start++;
    }
    if (start < lines.length) {
      buffer.write(lines.sublist(start).join('\n'));
    }
    return buffer.toString();
  }

  // ---- 原内容存在 @命运 区块 ----
  final header = lines.sublist(0, fateStart); // 区块标题前的行
  final tail = lines.sublist(fateEnd); // 区块后的行

  final buffer = StringBuffer();
  if (header.isNotEmpty) {
    buffer.write(header.join('\n'));
    buffer.write('\n');
  }

  if (trimmedTitle.isNotEmpty) {
    buffer.writeln('@命运');
    buffer.writeln(trimmedTitle);
    buffer.writeln();
  }

  if (tail.isNotEmpty) {
    final tailText = tail.join('\n');
    // 去除尾部前导空行（原区块末尾的空行由新区块输出的空行替代）
    var trimmedTail = tailText;
    while (trimmedTail.startsWith('\n')) {
      trimmedTail = trimmedTail.substring(1);
    }
    buffer.write(trimmedTail);
  }

  return buffer.toString();
}

/// 更新契约文件中的命运说明（`@命运` 区块）并写回磁盘。
///
/// 参数：
///   - fileName: 契约文件名（如 `faust.dark.meph`）
///   - newTitle: 新的命运说明；空字符串时移除整个 `@命运` 区块
///
/// 返回值：是否更新成功（false 表示文件不存在或写入失败）。
Future<bool> updateContractBranchTitle(
  String fileName,
  String newTitle,
) async {
  final dir = await getContractsDirectory();
  final file = File('${dir.path}/$fileName');
  if (!file.existsSync()) return false;
  try {
    final content = await file.readAsString();
    final updated = updateFateBlock(content, newTitle);
    if (updated == content) return true; // 无变化，视为成功
    await file.writeAsString(updated);
    return true;
  } catch (_) {
    return false;
  }
}
