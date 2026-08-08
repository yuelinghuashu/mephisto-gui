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

  /// 锚点（核心人格设定，推荐）
  final List<StateItem> anchor;

  final String worldview;

  final String background;

  final String opening;

  final List<StateItem> state;

  final List<Rule> rules;

  // ==========================================================
  // 系统区块（由程序自动生成）
  // ==========================================================

  /// 分支的一句话描述（来自系统保留区块 `@命运`）
  ///
  /// 仅子版可能有；用户在「另存为分支」时填写。
  /// 非空时 serializer 输出 `@命运` 区块，首页据此展示「命运一句话」。
  final String branchTitle;

  final List<Memory> memories;

  final List<HistoryEntry> history;

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

  factory Contract.empty() => const Contract(roleName: '角色');

  /// 创建副本（仅更新指定字段，其余保留原值）。
  ///
  /// 用于状态迁移/保存路径中「保留大部分字段、仅替换部分区块」的场景，
  /// 避免手工复制全部字段导致未来新增字段时漏同步。
  Contract copyWith({
    String? roleName,
    List<StateItem>? anchor,
    String? worldview,
    String? background,
    String? opening,
    List<StateItem>? state,
    List<Rule>? rules,
    String? branchTitle,
    List<Memory>? memories,
    List<HistoryEntry>? history,
  }) {
    return Contract(
      roleName: roleName ?? this.roleName,
      anchor: anchor ?? this.anchor,
      worldview: worldview ?? this.worldview,
      background: background ?? this.background,
      opening: opening ?? this.opening,
      state: state ?? this.state,
      rules: rules ?? this.rules,
      branchTitle: branchTitle ?? this.branchTitle,
      memories: memories ?? this.memories,
      history: history ?? this.history,
    );
  }

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
