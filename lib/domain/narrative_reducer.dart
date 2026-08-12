/// 叙事状态纯函数 Reducer
///
/// 将 [NarrativeState] 的所有状态迁移收敛为单个纯函数：
///   - `reduce(state, event)` 无副作用，输入相同 → 输出相同
///   - 每类 [NarrativeEvent] 对应一个清晰的状态迁移（可独立单测）
///   - 配合事件回放可实现「存档分叉考古」与多角色隔离
///   - Notifier 只负责副作用（LLM / 存档 / 记忆），状态迁移全部委托这里
library;

import 'models.dart';
import 'narrative_event.dart';
import 'narrative_state.dart';
import 'reducer_utils.dart';

/// 在历史末尾追加一条条目（共享辅助，消除多处同步复制列表的样板）。
List<HistoryEntry> _appendHistoryEntry(
  NarrativeState state,
  MessageRole role,
  String content,
) {
  return [
    ...state.history,
    HistoryEntry(role: role, content: content),
  ];
}

/// 应用事件到当前状态，返回新状态（纯函数，不修改原状态）。
NarrativeState narrativeReducer(NarrativeState state, NarrativeEvent event) {
  return switch (event) {
    MessageSent(:final content) => _onMessageSent(state, content),
    ReplySucceeded(
      :final reply,
      :final newState,
      :final injectedMemories,
      :final rollInfo,
      :final diceResults,
      :final lastError,
    ) =>
      _onReplySucceeded(
        state,
        reply: reply,
        newState: newState,
        injectedMemories: injectedMemories,
        rollInfo: rollInfo,
        diceResults: diceResults,
        lastError: lastError,
      ),
    GenerationFailed(:final message) => _onGenerationFailed(state, message),
    SessionRestored(:final restored, :final fileName) =>
      _onSessionRestored(state, restored, fileName),
    SessionReset() => _onSessionReset(state),
    StateValueSet(:final key, :final value) => _onStateValueSet(state, key, value),
    ContextAttached(:final fileName, :final content) =>
      _onContextAttached(state, fileName, content),
    ContextRemoved(:final index) => _onContextRemoved(state, index),
    ContextsCleared() => _onContextsCleared(state),
    MessageDeleted(:final index, :final cascadeFate) =>
      _onMessageDeleted(state, index, cascadeFate),
  };
}

/// 用户发送消息：追加命运消息 + 历史条目 + 进入生成状态。
NarrativeState _onMessageSent(NarrativeState state, String content) {
  final trimmed = content.trim();
  return state.copyWith(
    messages: [...state.messages, Message.fate(trimmed)],
    history: _appendHistoryEntry(state, MessageRole.fate, trimmed),
    isGenerating: true,
    streamingContent: '',
  );
}

/// AI 回复成功：应用新状态 + 记忆注入 + 系统消息（骰子）+ 回复 + 清空生成标志。
NarrativeState _onReplySucceeded(
  NarrativeState state, {
  required String reply,
  required Map<String, StateValue> newState,
  required List<Memory> injectedMemories,
  required String rollInfo,
  required List<DiceResult> diceResults,
  required String lastError,
}) {
  // 聚合本轮所有变化（当前状态、注入记忆）
  var next = state.copyWith(
    currentState: newState,
    memories: injectedMemories.isEmpty
        ? state.memories
        : [...state.memories, ...injectedMemories],
  );

  // 骰子结果以系统消息展示（携带结构化数据供 UI 渲染）
  if (rollInfo.isNotEmpty) {
    next = next.copyWith(
      messages: [
        ...next.messages,
        Message.system(rollInfo, diceResults: diceResults),
      ],
    );
  }

  // 写回回复 + 清空生成状态
  return next.copyWith(
    messages: [...next.messages, Message.assistant(reply)],
    history: _appendHistoryEntry(next, MessageRole.assistant, reply),
    isGenerating: false,
    streamingContent: '',
    // 错误信息提示（放在最后，避免被覆盖）
    lastError: lastError,
  );
}

/// 生成失败：重置生成状态 + 记录错误。
NarrativeState _onGenerationFailed(NarrativeState state, String message) {
  return state.copyWith(
    isGenerating: false,
    streamingContent: '',
    lastError: message,
  );
}

/// 从子版恢复：整体替换为恢复的会话快照。
NarrativeState _onSessionRestored(
  NarrativeState state,
  Contract restored,
  String fileName,
) {
  return state.copyWith(
    contract: restored,
    sourceFileName: fileName,
    messages: historyToMessages(restored.history),
    currentState: restored.stateMap,
    memories: restored.memories,
    history: restored.history,
    isGenerating: false,
    streamingContent: '',
  );
}

/// 会话重置：保留契约，清空动态数据（含会话级附加上下文）。
NarrativeState _onSessionReset(NarrativeState state) {
  return state.copyWith(
    messages: [],
    currentState: state.contract.stateMap,
    memories: [],
    history: [],
    isGenerating: false,
    streamingContent: '',
    attachedFileNames: [],
    attachedContexts: [],
  );
}

/// 更新单个状态值。
NarrativeState _onStateValueSet(
  NarrativeState state,
  String key,
  StateValue value,
) {
  final newState = Map<String, StateValue>.from(state.currentState);
  newState[key] = value;
  return state.copyWith(currentState: newState);
}

/// 附加上下文（会话级，多选追加）。
NarrativeState _onContextAttached(
  NarrativeState state,
  String fileName,
  String content,
) {
  final (fileNames, contexts) = appendAttachment(
    state.attachedFileNames,
    state.attachedContexts,
    fileName,
    content,
  );
  return state.copyWith(
    attachedFileNames: fileNames,
    attachedContexts: contexts,
  );
}

/// 移除指定索引的附加上下文（越界忽略）。
NarrativeState _onContextRemoved(NarrativeState state, int index) {
  final removed = removeAttachmentAt(
    state.attachedFileNames,
    state.attachedContexts,
    index,
  );
  if (removed == null) return state;
  final (fileNames, contexts) = removed;
  return state.copyWith(
    attachedFileNames: fileNames,
    attachedContexts: contexts,
  );
}

/// 清空所有附加上下文。
NarrativeState _onContextsCleared(NarrativeState state) {
  return state.copyWith(attachedFileNames: [], attachedContexts: []);
}

/// 删除指定索引的消息（连同其对应的历史条目）。
///
/// 规则：
///   - 删除 `messages[index]`（越界忽略）
///   - 同时从 `history` 中移除对应角色的条目（按 MessageRole 匹配）
///   - `cascadeFate=true` 且被删消息为 assistant 时，同时删除其前一条 fate
///     消息与对应的历史条目（「重新生成」场景：删回复 + 删指引 → 重新发送）
///
/// 消息列表与历史列表的映射关系：
///   - `messages` 可能包含系统消息（骰子结算卡片），这些不会出现在 `history` 中
///   - 因此不能直接用索引对应，需按角色 + 内容裁剪
NarrativeState _onMessageDeleted(
  NarrativeState state,
  int index,
  bool cascadeFate,
) {
  if (index < 0 || index >= state.messages.length) return state;

  // 确定要删除的消息索引集合（级联删除时含前一条 fate）
  final deleteIndices = <int>{index};
  if (cascadeFate) {
    // 若删除的是 assistant 消息，向前找最近的 fate 消息一并删除
    if (state.messages[index].role == MessageRole.assistant) {
      for (var i = index - 1; i >= 0; i--) {
        if (state.messages[i].role == MessageRole.fate) {
          deleteIndices.add(i);
          break;
        }
      }
    }
  }

  // 从 messages 中移除
  final messages = <Message>[
    for (var i = 0; i < state.messages.length; i++)
      if (!deleteIndices.contains(i)) state.messages[i],
  ];

  // 从 history 中同步移除对应的命运/角色条目。
  // history 不含系统消息，按角色与内容裁剪：
  //   - 被删除的 fate 消息 → 移除 history 中第一条角色为 fate 且内容相同的条目
  //   - 被删除的 assistant 消息 → 移除 history 中第一条角色为 assistant 且内容相同的条目
  var history = state.history;
  for (final idx in deleteIndices) {
    final msg = state.messages[idx];
    if (msg.role == MessageRole.system) continue; // 系统消息不进 history
    final role = msg.role;
    final content = msg.content;
    final entryIndex = history.indexWhere(
      (h) => h.role == role && h.content == content,
    );
    if (entryIndex != -1) {
      history = [
        ...history.take(entryIndex),
        ...history.skip(entryIndex + 1),
      ];
    }
  }

  return state.copyWith(messages: messages, history: history);
}
