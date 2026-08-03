import 'package:equatable/equatable.dart';

import '../domain/models.dart';

/// 叙事状态
///
/// 这是叙事会话的完整快照，包含所有动态数据。
/// 每次用户交互（发消息、规则触发、状态变化）都会创建新的状态对象。
class NarrativeState extends Equatable {
  /// 契约数据（静态，来自 .meph 文件）
  final Contract contract;

  /// 契约源文件名（如 `faust.meph`，用于子版存档命名）
  final String sourceFileName;

  /// 消息列表（动态，每轮对话增加）
  final List<Message> messages;

  /// 当前状态值（动态，规则触发时变化）
  final Map<String, StateValue> currentState;

  /// 记忆列表（动态，每 N 轮提取一次）
  final List<Memory> memories;

  /// 历史列表（动态，存档格式）
  final List<HistoryEntry> history;

  /// 是否正在生成 AI 回复
  final bool isGenerating;

  /// 当前流式输出的内容（生成中）
  final String streamingContent;

  /// 最近一次 LLM 错误信息（用于 UI 提示；无错误时为空）
  final String lastError;

  /// 附件文件名列表（会话级，用于 UI 展示，支持多选）
  final List<String> attachedFileNames;

  /// 附件内容列表（会话级，作为补充上下文注入 LLM）
  final List<String> attachedContexts;

  /// 构造函数
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

  /// 创建状态的副本（用于更新）
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

  /// 获取角色名
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

  /// 获取规则数量
  int get ruleCount => contract.rules.length;

  /// 获取消息数量（用于显示计数）
  int get messageCount => messages.length;

  /// 获取记忆数量
  int get memoryCount => memories.length;

  /// 获取历史数量
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
