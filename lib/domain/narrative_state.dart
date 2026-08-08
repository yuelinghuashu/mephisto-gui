import 'package:equatable/equatable.dart';

import '../domain/models.dart';

/// 叙事状态
///
/// 这是叙事会话的完整快照，包含所有动态数据。
/// 每次用户交互（发消息、规则触发、状态变化）都会创建新的状态对象。
class NarrativeState extends Equatable {
  /// 静态契约数据（来自 .meph 文件）
  final Contract contract;

  final String sourceFileName;

  /// 每轮对话增加
  final List<Message> messages;

  /// 规则触发时变化
  final Map<String, StateValue> currentState;

  /// 每 N 轮提取一次
  final List<Memory> memories;

  final List<HistoryEntry> history;

  final bool isGenerating;

  final String streamingContent;

  /// 无错误时为空
  final String lastError;

  /// 会话级，支持多选
  final List<String> attachedFileNames;

  /// 会话级，作为补充上下文注入 LLM
  final List<String> attachedContexts;

  const NarrativeState({
    required this.contract,
    this.sourceFileName = 'faust.meph',
    this.messages = const [],
    this.currentState = const {},
    this.memories = const [],
    this.history = const [],
    this.isGenerating = false,
    this.streamingContent = '',
    this.lastError = '',
    this.attachedFileNames = const [],
    this.attachedContexts = const [],
  });

  /// 创建状态的副本（用于更新）。
  ///
  /// 性能优化：所有参数均为 null（无任何字段变化）时直接返回 `this`，
  /// 避免创建相同内容的新对象——流式输出过程中 [NarrativeNotifier] 会在
  /// 50ms 节流窗口内频繁调用 copyWith，短路可减少无谓的对象创建与
  /// Equatable 比较（以及 Riverpod 通知）。
  NarrativeState copyWith({
    Contract? contract,
    String? sourceFileName,
    List<Message>? messages,
    Map<String, StateValue>? currentState,
    List<Memory>? memories,
    List<HistoryEntry>? history,
    bool? isGenerating,
    String? streamingContent,
    String? lastError,
    List<String>? attachedFileNames,
    List<String>? attachedContexts,
  }) {
    // 所有参数均为 null → 无变化，直接返回自身
    if (contract == null &&
        sourceFileName == null &&
        messages == null &&
        currentState == null &&
        memories == null &&
        history == null &&
        isGenerating == null &&
        streamingContent == null &&
        lastError == null &&
        attachedFileNames == null &&
        attachedContexts == null) {
      return this;
    }

    return NarrativeState(
      contract: contract ?? this.contract,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      messages: messages ?? this.messages,
      currentState: currentState ?? this.currentState,
      memories: memories ?? this.memories,
      history: history ?? this.history,
      isGenerating: isGenerating ?? this.isGenerating,
      streamingContent: streamingContent ?? this.streamingContent,
      lastError: lastError ?? this.lastError,
      attachedFileNames: attachedFileNames ?? this.attachedFileNames,
      attachedContexts: attachedContexts ?? this.attachedContexts,
    );
  }

  // ============================================================
  // 便捷访问（UI 常用）
  // ============================================================

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

  int get ruleCount => contract.rules.length;

  int get messageCount => messages.length;

  int get memoryCount => memories.length;

  int get historyCount => history.length;

  @override
  List<Object?> get props => [
    contract,
    sourceFileName,
    messages,
    currentState,
    memories,
    history,
    isGenerating,
    streamingContent,
    lastError,
    attachedFileNames,
    attachedContexts,
  ];
}
