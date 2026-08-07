/// Mephisto 叙事引擎 - 契约模型
///
/// 包含完整契约 [Contract] 的定义。
/// 这是叙事引擎的核心数据结构，代表完整的角色设定和运行时快照。
library;

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'entities.dart';
import 'values.dart';

// ============================================================
// 契约模型（核心）
// ============================================================

/// 完整契约
///
/// 表示一个完整的 .meph 契约文件，包含所有用户书写和系统生成的区块。
///
/// 区块分类：
///   用户区块（由创作者书写）：
///     - [roleName]：角色名（必选）
///     - [anchor]：锚点（推荐，核心人格设定）
///     - [worldview]：世界观（可选）
///     - [background]：角色背景（可选）
///     - [opening]：开局场景（可选）
///     - [state]：初始状态（可选）
///     - [rules]：规则列表（可选）
///
///   系统区块（由程序自动生成）：
///     - [memories]：记忆
///     - [history]：历史
@immutable
class Contract extends Equatable {
  // ==========================================================
  // 用户区块
  // ==========================================================

  /// 角色名（必选）
  final String roleName;

  /// 锚点列表（推荐，核心人格设定）
  final List<StateItem> anchor;

  /// 世界观（可选）
  final String worldview;

  /// 角色背景（可选）
  final String background;

  /// 开局场景（可选）
  final String opening;

  /// 初始状态（可选）
  final List<StateItem> state;

  /// 规则列表（可选）
  final List<Rule> rules;

  // ==========================================================
  // 系统区块（由程序自动生成）
  // ==========================================================

  /// 命运说明（分支的一句话描述，来自系统保留区块 `@命运`）
  ///
  /// 仅子版可能有；用户在「另存为分支」时填写。
  /// 非空时 serializer 输出 `@命运` 区块，首页据此展示「命运一句话」。
  final String branchTitle;

  /// 记忆列表
  final List<Memory> memories;

  /// 历史列表
  final List<HistoryEntry> history;

  /// 构造函数
  const Contract({
    required this.roleName,
    this.anchor = const [],
    this.worldview = '',
    this.background = '',
    this.opening = '',
    this.state = const [],
    this.rules = const [],
    this.branchTitle = '',
    this.memories = const [],
    this.history = const [],
  });

  /// 创建空契约
  factory Contract.empty() => const Contract(roleName: '角色');

  /// 获取状态映射（用于快速查找）
  Map<String, StateValue> get stateMap {
    return {for (final item in state) item.key: item.value};
  }

  @override
  List<Object?> get props => [
    roleName,
    anchor,
    worldview,
    background,
    opening,
    state,
    rules,
    branchTitle,
    memories,
    history,
  ];
}
