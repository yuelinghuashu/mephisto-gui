/// 舞台领域模型（纯数据类，无 IO）
///
/// 从 `services/storage/stage_repo.dart` 拆出的数据类，使 domain 层可安全引用
/// （domain 不依赖 services）。`stage_repo.dart` re-export 本文件，保持外部
/// `import 'stage_repo.dart'` 的 API 完全不变。
library;

import 'package:equatable/equatable.dart';

import 'contract.dart';

/// 舞台信息
class StageInfo extends Equatable {
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

  @override
  List<Object?> get props => [path, name, characterCount];
}

/// 舞台内单个角色卡（独立解析为一份 [Contract]）。
class StageCharacter extends Equatable {
  /// 角色卡文件名（如 `浮士德.meph`）
  final String fileName;

  /// 完整解析的角色契约（含状态/记忆/历史，运行时各自更新）
  final Contract contract;

  /// 该角色是否存在 `.child.meph` 存档（有推进会话）。
  ///
  /// 由 [stage_repo.loadStage] 在扫描舞台目录时探测；
  /// 首页舞台卡片展开区据此显示「💾 有存档」徽标。
  final bool hasSave;

  const StageCharacter({
    required this.fileName,
    required this.contract,
    this.hasSave = false,
  });

  /// 角色名（来自契约【角色名】区块）
  String get roleName => contract.roleName;

  @override
  List<Object?> get props => [fileName, contract, hasSave];
}

/// 舞台加载结果：一个舞台 + 其全部角色
class StageLoaded extends Equatable {
  /// 舞台元信息
  final StageInfo info;

  /// 按字典序排列的角色列表
  final List<StageCharacter> characters;

  const StageLoaded({required this.info, required this.characters});

  /// 公共世界观：取**第一个角色**（字典序）的【世界观】。
  ///
  /// 用户约定：舞台内第一份角色卡承载舞台公共世界观。
  String get commonWorldview =>
      characters.isEmpty ? '' : characters.first.contract.worldview;

  /// 角色数
  int get characterCount => characters.length;

  @override
  List<Object?> get props => [info, characters];
}
