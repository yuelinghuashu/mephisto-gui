import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/models.dart';

part 'narrative_state.freezed.dart';

/// 叙事状态
///
/// 这是叙事会话的完整快照，包含所有动态数据。
/// 每次用户交互（发消息、规则触发、状态变化）都会创建新的状态对象。
///
/// 由 freezed 生成 `copyWith` / `==` / `hashCode` / `toString`，
/// 消除手写 Equatable props 与全 null 短路样板。
@freezed
abstract class NarrativeState with _$NarrativeState {
  /// 静态契约数据（来自 .meph 文件）
  const factory NarrativeState({
    required Contract contract,
    @Default('faust.meph') String sourceFileName,
    @Default(<Message>[]) List<Message> messages,
    @Default(<String, StateValue>{}) Map<String, StateValue> currentState,
    @Default(<Memory>[]) List<Memory> memories,
    @Default(<HistoryEntry>[]) List<HistoryEntry> history,
    @Default(false) bool isGenerating,
    @Default('') String streamingContent,
    @Default('') String lastError,
    @Default(<String>[]) List<String> attachedFileNames,
    @Default(<String>[]) List<String> attachedContexts,
  }) = _NarrativeState;

  /// freezed 需要私有构造函数以支持 getter 扩展
  const NarrativeState._();

  // ============================================================
  // 便捷访问（UI 常用）
  // ============================================================

  /// 角色名（来自契约）
  String get roleName => contract.roleName;

  /// 当前分支名（子版时返回分支名；母版返回空字符串）。
  ///
  /// 用于标题栏展示，帮助用户识别进入的是哪个版本。
  /// 例如：
  ///   - `faust.meph` → ''（母版，不显示）
  ///   - `faust.child.meph` → '存档'（默认存档分支）
  ///   - `faust.dark.meph` → 'dark'（自定义分支）
  String get branchName {
    final base = sourceFileName.replaceAll('.meph', '');
    final dotIndex = base.indexOf('.');
    if (dotIndex == -1 || dotIndex == base.length - 1) return '';
    final name = base.substring(dotIndex + 1);
    return name == 'child' ? '存档' : name;
  }

  /// 规则数量
  int get ruleCount => contract.rules.length;

  /// 消息数量
  int get messageCount => messages.length;

  /// 记忆数量
  int get memoryCount => memories.length;

  /// 历史条目数量
  int get historyCount => history.length;
}