/// 舞台存储：多角色舞台的目录级发现与管理
///
/// 命名约定（与单角色「母版 .meph → 同目录 .child.meph」保持统一）：
///   - 舞台 = 契约根目录下的**一层子目录**，文件夹名 = 舞台前缀
///   - 舞台内含 N 份平级 .meph 角色卡（如 浮士德.meph / 梅菲斯特.meph）
///   - 每个角色各自生成独立子版存档：`舞台/浮士德.child.meph`
///
/// 不做深层嵌套：舞台目录内只放平级 .meph，不支持子目录
/// （避免与「单角色子版基于 `.` 分段推导」混淆）。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/models.dart';
import '../parser/meph_parser.dart';
import 'contract_dir.dart';

/// 舞台信息
class StageInfo {
  /// 舞台目录绝对路径
  final String path;

  /// 舞台名（= 文件夹名）
  final String name;

  /// 舞台内角色卡数量（.meph 文件数）
  final int characterCount;

  const StageInfo({
    required this.path,
    required this.name,
    required this.characterCount,
  });
}

/// 舞台内单个角色卡（独立解析为一份 [Contract]）。
class StageCharacter {
  /// 角色卡文件名（如 `浮士德.meph`）
  final String fileName;

  /// 完整解析的角色契约（含状态/记忆/历史，运行时各自更新）
  final Contract contract;

  const StageCharacter({
    required this.fileName,
    required this.contract,
  });

  /// 角色名（来自契约【角色名】区块）
  String get roleName => contract.roleName;
}

/// 舞台加载结果：一个舞台 + 其全部角色
class StageLoaded {
  /// 舞台元信息
  final StageInfo info;

  /// 按字典序排列的角色列表
  final List<StageCharacter> characters;

  const StageLoaded({
    required this.info,
    required this.characters,
  });

  /// 公共世界观：取**第一个角色**（字典序）的【世界观】。
  ///
  /// 用户约定：舞台内第一份角色卡承载舞台公共世界观。
  String get commonWorldview =>
      characters.isEmpty ? '' : characters.first.contract.worldview;

  /// 角色数
  int get characterCount => characters.length;
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

    // 目录内含至少一个 .meph 才算有效舞台
    final roles = await listMephFileNames(entity);
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

/// 判断指定目录是否为有效舞台（存在且含至少一个 .meph 角色卡）。
Future<bool> isStageDirectory(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return false;
  final roles = await listMephFileNames(dir);
  return roles.isNotEmpty;
}

/// 列出指定舞台目录内所有 .meph 角色卡文件名（字典序）。
Future<List<String>> listStageRoles(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return const [];
  return listMephFileNames(dir);
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
      characters.add(
        StageCharacter(fileName: name, contract: contract),
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
