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
  };
}

/// 用户发送消息：追加命运消息 + 历史条目 + 进入生成状态。
NarrativeState _onMessageSent(NarrativeState state, String content) {
  final trimmed = content.trim();
  return state.copyWith(
    messages: [...state.messages, Message.fate(trimmed)],
    history: [
      ...state.history,
      HistoryEntry(role: MessageRole.fate, content: trimmed),
    ],
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
    history: [
      ...next.history,
      HistoryEntry(role: MessageRole.assistant, content: reply),
    ],
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
    messages: [
      for (final h in restored.history)
        switch (h.role) {
          MessageRole.fate => Message.fate(h.content),
          MessageRole.assistant => Message.assistant(h.content),
          MessageRole.system => Message.system(h.content),
        },
    ],
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
  return state.copyWith(
    attachedFileNames: [...state.attachedFileNames, fileName],
    attachedContexts: [...state.attachedContexts, content],
  );
}

/// 移除指定索引的附加上下文（越界忽略）。
NarrativeState _onContextRemoved(NarrativeState state, int index) {
  if (index < 0 || index >= state.attachedFileNames.length) return state;
  return state.copyWith(
    attachedFileNames: [...state.attachedFileNames]..removeAt(index),
    attachedContexts: [...state.attachedContexts]..removeAt(index),
  );
}

/// 清空所有附加上下文。
NarrativeState _onContextsCleared(NarrativeState state) {
  return state.copyWith(attachedFileNames: [], attachedContexts: []);
}