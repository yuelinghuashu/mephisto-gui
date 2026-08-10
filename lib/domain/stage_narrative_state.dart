/// 舞台叙事状态
///
/// 多角色舞台的完整快照：一个舞台 + 全部角色的独立运行时状态 + 共享对话流。
/// 每次用户交互（发消息、规则触发）都会创建新的状态对象。
///
/// 与 [NarrativeState]（单角色）的关系：
///   - 单角色：1 个 [Contract] + 1 个 [currentState] + 1 个 [memories]
///   - 多角色舞台：N 个角色契约 + N 组独立运行时状态/记忆/历史
///
/// 本类**不替代** [NarrativeState]（现有 323 测试零改动），
/// 是为多角色舞台独立演进的领域模型。
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'models.dart';
import 'stage_models.dart';

part 'stage_narrative_state.freezed.dart';

/// 单个角色的运行时状态（在舞台内独立演进）
@freezed
abstract class RoleRunState with _$RoleRunState {
  /// 该角色的运行时状态值（规则引擎执行后）
  const factory RoleRunState({
    @Default(<String, StateValue>{}) Map<String, StateValue> currentState,
    @Default(<Memory>[]) List<Memory> memories,
    @Default(<HistoryEntry>[]) List<HistoryEntry> history,
  }) = _RoleRunState;

  /// freezed 需要私有构造函数以支持 getter 扩展
  const RoleRunState._();
}

/// 舞台叙事状态
@freezed
abstract class StageNarrativeState with _$StageNarrativeState {
  /// 舞台数据（null = 尚未加载）
  const factory StageNarrativeState({
    StageLoaded? stage,
    @Default('') String stagePath,
    @Default(<String, RoleRunState>{}) Map<String, RoleRunState> roles,
    @Default(<Message>[]) List<Message> messages,
    @Default(false) bool isGenerating,
    @Default('') String streamingContent,
    @Default('') String lastError,
    @Default(<DiceResult>[]) List<DiceResult> diceResults,
    @Default('') String lastRollInfo,
    @Default(<String>[]) List<String> attachedFileNames,
    @Default(<String>[]) List<String> attachedContexts,
  }) = _StageNarrativeState;

  /// freezed 需要私有构造函数以支持 getter 扩展
  const StageNarrativeState._();

  // ============================================================
  // 便捷访问
  // ============================================================

  /// 舞台名（未加载时为空）
  String get stageName => stage?.info.name ?? '';

  /// 角色数（未加载时为 0）
  int get characterCount => stage?.characters.length ?? 0;

  /// 消息数
  int get messageCount => messages.length;

  /// 各角色消息段数统计（有戏份的角色名列表）
  List<String> get speakingRoles {
    final rolesWithContent = <String>{};
    for (final msg in messages.where((m) => m.role == MessageRole.assistant)) {
      // 舞台的 assistant 消息以 `【角色名】` 开头记录
      final match = RegExp(r'^【(.+?)】').firstMatch(msg.content);
      if (match != null) rolesWithContent.add(match[1]!);
    }
    return rolesWithContent.toList();
  }
}