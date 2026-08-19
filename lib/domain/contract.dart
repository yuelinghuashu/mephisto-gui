/// Mephisto 叙事引擎 - 契约模型
///
/// 包含完整契约 [Contract] 的定义。
/// 这是叙事引擎的核心数据结构，代表完整的角色设定和运行时快照。
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'entities.dart';
import 'values.dart';

part 'contract.freezed.dart';

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
///
/// 由 freezed 生成 `copyWith` / `==` / `hashCode` / `toString`，
/// 消除手写 Equatable props 与全 null 短路样板。
@freezed
abstract class Contract with _$Contract {
  // ==========================================================
  // 用户区块
  // ==========================================================

  const factory Contract({
    /// 角色名（必选）
    required String roleName,

    /// 锚点（核心人格设定，推荐）
    @Default(<StateItem>[]) List<StateItem> anchor,
    @Default('') String worldview,
    @Default('') String background,
    @Default('') String opening,

    /// 初始状态
    @Default(<StateItem>[]) List<StateItem> state,

    /// 规则列表
    @Default(<Rule>[]) List<Rule> rules,

    /// 分支的一句话描述（来自系统保留区块 `@命运`）
    ///
    /// 仅子版可能有；用户在「另存为分支」时填写。
    /// 非空时 serializer 输出 `@命运` 区块，首页据此展示「命运一句话」。
    @Default('') String branchTitle,

    /// 记忆
    @Default(<Memory>[]) List<Memory> memories,

    /// 历史
    @Default(<HistoryEntry>[]) List<HistoryEntry> history,
  }) = _Contract;

  /// freezed 需要私有构造函数以支持 getter 扩展
  const Contract._();

  /// 空契约兜底（角色名为 '角色'）。
  factory Contract.empty() => const Contract(roleName: '角色');

  /// 从状态列表构建状态映射（键 → 值）。
  Map<String, StateValue> get stateMap {
    return {for (final item in state) item.key: item.value};
  }
}
