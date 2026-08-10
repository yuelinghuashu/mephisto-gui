/// 舞台存储：多角色舞台的目录级发现与管理
///
/// 命名约定（与单角色「母版 .meph → 同目录 .child.meph」保持统一）：
///   - 舞台 = 契约根目录下的**一层子目录**，文件夹名 = 舞台前缀
///   - 舞台内含 N 份平级 .meph 角色卡（如 浮士德.meph / 梅菲斯特.meph）
///   - 每个角色各自生成独立子版存档：`舞台/浮士德.child.meph`
///
/// 不做深层嵌套：舞台目录内只放平级 .meph，不支持子目录
/// （避免与「单角色子版基于 `.` 分段推导」混淆）。
///
/// 纯数据类（StageInfo / StageCharacter / StageLoaded）已拆至
/// `domain/stage_models.dart`，本文件 re-export 保持外部 API 不变。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/models.dart';
import '../../domain/stage_models.dart';
import '../parser/meph_parser.dart';
import 'contract_dir.dart';
import 'meph_file_name.dart';

export '../../domain/stage_models.dart';

/// 列出舞台目录内所有**母版角色卡**文件名（字典序）。
///
/// 排除 `.child.meph` 存档：舞台角色发现只认母版角色卡。
/// 舞台叙事的自动存档（`角色名.child.meph`）不应被当成独立角色——
/// 否则 Kurukshetra 这类已玩过的舞台会在首页出现「两个阿周那 + 两个迦尔纳」。
///
/// 注：[stageLastModified]（最近活动）**故意不过滤**存档：
/// 存档更新代表舞台有新活动，这正是「最近活动」的预期含义。
Future<List<String>> _listRoleCards(Directory dir) async {
  final names = await listMephFileNames(dir);
  return names.where((name) => !isChildFileName(name)).toList();
}

/// 列出契约根目录下所有有效舞台（一层子目录且含至少一个 .meph 角色卡）。
///
/// 异步目录扫描（复用 [getContractsDirectory] + 目录级 `list()`），
/// 避免同步 IO 阻塞 UI 事件循环。返回按目录路径字典序排序。
Future<List<StageInfo>> listStages() async {
  final root = await getContractsDirectory();
  if (!await root.exists()) return const [];

  final stages = <StageInfo>[];
  await for (final entity in root.list()) {
    // 只取一层子目录作为舞台候选（不做深层递归）
    if (entity is! Directory) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.isEmpty) continue;

    // 目录内含至少一个母版角色卡才算有效舞台（存档不算）
    final roles = await _listRoleCards(entity);
    if (roles.isEmpty) continue;

    stages.add(
      StageInfo(
        path: entity.path,
        name: name,
        characterCount: roles.length,
      ),
    );
  }

  stages.sort((a, b) => a.path.compareTo(b.path));
  return stages;
}

/// 判断指定目录是否为有效舞台（存在且含至少一个母版角色卡）。
Future<bool> isStageDirectory(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return false;
  final roles = await _listRoleCards(dir);
  return roles.isNotEmpty;
}

/// 计算舞台的「最近活动时间」：舞台目录内所有 .meph 文件的最大 mtime。
///
/// 包括角色卡与其 `.child.meph` 存档（存档更新即代表舞台有新活动）。
/// 返回值：最近修改时间；目录不存在或无 .meph 时返回 null。
///
/// 异步实现（复用 [listMephFileNames] + 异步 `lastModified`），
/// 避免同步 IO 阻塞 UI 事件循环（与首页契约列表的 mtime 读取保持一致）。
Future<DateTime?> stageLastModified(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return null;
  final names = await listMephFileNames(dir);
  if (names.isEmpty) return null;

  DateTime? latest;
  for (final name in names) {
    try {
      final file = File('$dirPath/$name');
      if (!await file.exists()) continue;
      final mtime = await file.lastModified();
      if (latest == null || mtime.isAfter(latest)) latest = mtime;
    } catch (_) {
      // 单个文件读取失败（权限/IO 异常）忽略，不影响整体
    }
  }
  return latest;
}

/// 列出指定舞台目录内所有母版角色卡文件名（字典序）。
///
/// 排除 `.child.meph` 存档：角色发现只认母版角色卡（见 [_listRoleCards]）。
/// [loadStage] 依赖此列表，因此加载/计数/首页角色预览均自动只含真角色。
Future<List<String>> listStageRoles(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return const [];
  return _listRoleCards(dir);
}

/// 删除舞台内单个角色卡文件（母版 .meph），并**级联删除其子版存档**。
///
/// 对齐单角色契约树的「删除母版 → 级联删除整棵子树」语义：
/// 删除 `Arjuna.meph` 时一并删除 `Arjuna.child.meph`（存在才删）。
/// 只想重置进度（仅删存档）请使用 [deleteStageRoleChild]。
///
/// 参数：
///   - dirPath: 舞台目录绝对路径
///   - fileName: 角色卡文件名（如 `阿周那.meph`）
///
/// 返回值：是否删除成功（false = 文件不存在或删除失败）。
Future<bool> deleteStageRoleCard(String dirPath, String fileName) async {
  // 先删母版 .meph
  final file = File('$dirPath/$fileName');
  var masterDeleted = false;
  if (await file.exists()) {
    try {
      await file.delete();
      masterDeleted = true;
    } catch (_) {
      return false;
    }
  }

  // 级联删除对应子版存档（存在才删，删除失败不影响母版删除成功）
  final childName = defaultChildFileName(fileName);
  final childFile = File('$dirPath/$childName');
  if (await childFile.exists()) {
    try {
      await childFile.delete();
    } catch (_) {
      // 子版删除失败不阻断母版删除结果（下次刷新时会重新探测）
    }
  }

  return masterDeleted;
}

/// 删除舞台内某个角色的 .child.meph 存档。
///
/// 参数：
///   - dirPath: 舞台目录绝对路径
///   - roleFileName: 母版角色卡文件名（如 `阿周那.meph`）
///
/// 自动根据 [meph_file_name.defaultChildFileName] 推导存档名；
/// 返回值：是否删除成功。
Future<bool> deleteStageRoleChild(String dirPath, String roleFileName) async {
  final childName = defaultChildFileName(roleFileName);
  final file = File('$dirPath/$childName');
  if (!await file.exists()) return false;
  try {
    await file.delete();
    return true;
  } catch (_) {
    return false;
  }
}

/// 删除整个舞台目录（含所有角色卡与 .child.meph 存档）。
///
/// 返回值：是否删除成功（目录不存在或删除失败时返回 false）。
Future<bool> deleteStage(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return false;
  try {
    await dir.delete(recursive: true);
    return true;
  } catch (_) {
    return false;
  }
}

/// 重命名舞台目录。
///
/// 参数：
///   - dirPath: 舞台目录绝对路径（如 `~/Mephisto/contracts/Kurukshetra`）
///   - newName: 新舞台名（如 `摩诃婆罗多`）；不含路径分隔符
///
/// 返回值：是否重命名成功（false 表示旧目录不存在、新目录已存在或重命名失败）。
Future<bool> renameStage(String dirPath, String newName) async {
  if (newName.isEmpty ||
      newName.contains('/') ||
      newName.contains(Platform.pathSeparator)) {
    return false;
  }
  final dir = Directory(dirPath);
  if (!await dir.exists()) return false;

  final parent = dir.parent;
  final target = Directory('${parent.path}/$newName');
  if (await target.exists()) return false;

  try {
    await dir.rename(target.path);
    return true;
  } catch (_) {
    return false;
  }
}

/// 加载舞台：遍历舞台目录内所有 .meph 角色卡，各自独立解析为 [Contract]。
///
/// 角色文件缺失/解析失败时**跳过该文件**（不中断整个舞台加载），
/// 保证个别损坏角色卡不会导致整个舞台不可进入。
///
/// 返回值：加载成功的 [StageLoaded]；目录不存在或**无任何可用角色**时返回 null。
Future<StageLoaded?> loadStage(String dirPath) async {
  final roles = await listStageRoles(dirPath);
  if (roles.isEmpty) return null;

  final characters = <StageCharacter>[];
  for (final name in roles) {
    try {
      final file = File('$dirPath/$name');
      if (!await file.exists()) continue;
      final content = await file.readAsString();
      final contract = parseMeph(content);
      // 探测该角色是否存在 `.child.meph` 存档（首页舞台卡片展示用）
      final saveFile = File('$dirPath/${defaultChildFileName(name)}');
      characters.add(
        StageCharacter(
          fileName: name,
          contract: contract,
          hasSave: await saveFile.exists(),
        ),
      );
    } catch (e) {
      // 单份角色卡解析失败 → 跳过，不拖垮整个舞台
      debugPrint('舞台角色加载失败: $dirPath/$name ($e)');
    }
  }

  if (characters.isEmpty) return null;

  return StageLoaded(
    info: StageInfo(
      path: dirPath,
      // 舞台名 = 文件夹名（路径最后一段）
      name: dirPath.split(Platform.pathSeparator).last,
      characterCount: characters.length,
    ),
    characters: characters,
  );
}
