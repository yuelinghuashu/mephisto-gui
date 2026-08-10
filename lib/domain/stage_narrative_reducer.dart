/// 舞台叙事状态纯函数 Reducer
///
/// 将 [StageNarrativeState] 的所有状态迁移收敛为单个纯函数：
///   - `reduce(state, event)` 无副作用，输入相同 → 输出相同
///   - 每类 [StageNarrativeEvent] 对应一个清晰的状态迁移（可独立单测）
///   - Notifier 只负责副作用（LLM / 存档），状态迁移全部委托这里
library;

import 'models.dart';
import 'reducer_utils.dart';
import 'stage_models.dart';
import 'stage_narrative_event.dart';
import 'stage_narrative_state.dart';

/// 舞台历史转消息：复用共享 [historyToMessages]（原 `stageHistoryToMessages`
/// 与单角色版完全相同，已合并为 `reducer_utils.dart` 中的唯一实现）。
/// 保留此别名避免破坏既有调用点（stage_narrative_provider / 测试）。
List<Message> stageHistoryToMessages(List<HistoryEntry> history) =>
    historyToMessages(history);

/// 应用事件到当前状态，返回新状态（纯函数，不修改原状态）。
StageNarrativeState stageNarrativeReducer(
  StageNarrativeState state,
  StageNarrativeEvent event,
) {
  return switch (event) {
    StageLoadedEvent(:final stage, :final stagePath, :final initialStates) =>
      _onStageLoaded(state, stage, stagePath, initialStates),
    StageMessageSent(:final content) => _onStageMessageSent(state, content),
    StageReplySucceeded(
      :final replies,
      :final newStates,
      :final injectedMemories,
      :final overflow,
      :final rollInfo,
      :final diceResults,
      :final lastError,
    ) =>
      _onStageReplySucceeded(
        state,
        replies: replies,
        newStates: newStates,
        injectedMemories: injectedMemories,
        overflow: overflow,
        rollInfo: rollInfo,
        diceResults: diceResults,
        lastError: lastError,
      ),
    StageGenerationFailed(:final message) => _onStageGenerationFailed(
      state,
      message,
    ),
    StageSessionRestored(:final restoredByRole, :final messages) =>
      _onStageSessionRestored(state, restoredByRole, messages),
    StageSessionReset() => _onStageSessionReset(state),
    StageContextAttached(:final fileName, :final content) =>
      _onStageContextAttached(state, fileName, content),
    StageContextRemoved(:final index) => _onStageContextRemoved(state, index),
  };
}

/// 附加上下文（会话级，多选追加）。
StageNarrativeState _onStageContextAttached(
  StageNarrativeState state,
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
StageNarrativeState _onStageContextRemoved(
  StageNarrativeState state,
  int index,
) {
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

/// 舞台加载成功：初始化舞台 + 各角色初始状态。
StageNarrativeState _onStageLoaded(
  StageNarrativeState state,
  StageLoaded stage,
  String stagePath,
  Map<String, Map<String, StateValue>> initialStates,
) {
  final roles = <String, RoleRunState>{};
  for (final character in stage.characters) {
    final roleName = character.roleName;
    roles[roleName] = RoleRunState(
      currentState: Map<String, StateValue>.from(
        initialStates[roleName] ?? character.contract.stateMap,
      ),
      // 从角色契约自带的记忆（打开子版时已包含运行时数据）
      memories: List<Memory>.from(character.contract.memories),
      // 从角色契约自带历史回放共享消息流（打开子版时完整还原）
      history: List<HistoryEntry>.from(character.contract.history),
    );
  }

  // 共享消息流：取各角色中最长的历史重建（history 最长的角色通常
  // 拥有最完整的戏份历史，能覆盖更多轮的对话——避免只取第一个角色
  // 导致其他角色的历史段落丢失）
  final messages = stage.characters.isEmpty
      ? const <Message>[]
      : stageHistoryToMessages(
          stage.characters
              .map((c) => c.contract.history)
              .reduce((a, b) => a.length >= b.length ? a : b),
        );

  return state.copyWith(
    stage: stage,
    stagePath: stagePath,
    roles: roles,
    messages: messages,
    isGenerating: false,
    streamingContent: '',
    lastError: '',
    diceResults: const [],
    lastRollInfo: '',
    // 会话级附件是临时数据：加载新舞台时清空，避免残留上舞台的附件
    attachedFileNames: [],
    attachedContexts: [],
  );
}

/// 用户发送消息：追加命运消息 + 镜像到所有角色历史 + 进入生成状态。
///
/// 命运指引（fate）写入**每个角色**的 history，而非只入共享消息流——
/// 使任意角色的存档都能完整重现共享对话流（对齐单角色 [NarrativeState]
/// 的 history 语义：fate / assistant / system 三相并存）。
StageNarrativeState _onStageMessageSent(
  StageNarrativeState state,
  String content,
) {
  final trimmed = content.trim();
  return state.copyWith(
    messages: [...state.messages, Message.fate(trimmed)],
    // 镜像到所有角色：每个角色都记录这条命运指引
    roles: {
      for (final e in state.roles.entries)
        e.key: e.value.copyWith(
          history: [
            ...e.value.history,
            HistoryEntry(role: MessageRole.fate, content: trimmed),
          ],
        ),
    },
    isGenerating: true,
    streamingContent: '',
    lastError: '',
  );
}

/// AI 回复成功：各角色分批写回状态/记忆 + 追加各角色消息段。
StageNarrativeState _onStageReplySucceeded(
  StageNarrativeState state, {
  required Map<String, String> replies,
  required Map<String, Map<String, StateValue>> newStates,
  required Map<String, List<Memory>> injectedMemories,
  required String overflow,
  required String rollInfo,
  required List<DiceResult> diceResults,
  required String lastError,
}) {
  // 1. 各角色独立更新状态/记忆
  var nextRoles = Map<String, RoleRunState>.from(state.roles);
  for (final entry in newStates.entries) {
    final roleName = entry.key;
    final role = nextRoles[roleName];
    if (role == null) continue;
    nextRoles[roleName] = role.copyWith(
      currentState: entry.value,
      memories: [
        ...role.memories,
        ...(injectedMemories[roleName] ?? const <Memory>[]),
      ],
    );
  }

  var next = state.copyWith(roles: nextRoles);

  // 2. 骰子结果以系统消息展示（携带结构化数据供 UI 渲染）
  if (rollInfo.isNotEmpty) {
    next = next.copyWith(
      messages: [
        ...next.messages,
        Message.system(rollInfo, diceResults: diceResults),
      ],
      diceResults: diceResults,
      lastRollInfo: rollInfo,
    );
  }

  // 3. 各角色段落追加为 assistant 消息
  //    本轮所有角色段落 + overflow 统一镜像到**每个角色**的 history
  //    （而非只写自己的段落），使任意角色存档都能完整重现共享对话流。
  //
  //    v2 全景叙事去重：多角色共享同一段文本（同一篇小说，多位角色被提及）
  //    时，只生成**一条**消息而非 N 条重复气泡。共享文本不加 `【角色名】`
  //    前缀、roleTag 为空 → UI 以标准气泡渲染（全景视角，不附着单一角色色板）。
  final roleHistories = Map<String, List<HistoryEntry>>.from({
    for (final e in next.roles.entries) e.key: e.value.history,
  });
  // 本轮产生的完整共享段落（fate 已在发消息时入史，此处只含角色段 + overflow）
  final roundEntries = <HistoryEntry>[];
  var messages = [...next.messages];

  // 按文本分组：同一段文本对应的所有角色（去重边界判断）
  final textToRoles = <String, List<String>>{};
  for (final entry in replies.entries) {
    textToRoles.putIfAbsent(entry.value, () => []).add(entry.key);
  }
  for (final MapEntry(key: text, value: sharedRoles) in textToRoles.entries) {
    // 多位角色共享同一段文本 → 全景消息（单条，无角色标签）
    if (sharedRoles.length > 1) {
      messages.add(Message.assistant(text));
      roundEntries.add(
        HistoryEntry(role: MessageRole.assistant, content: text),
      );
      continue;
    }
    // 单一角色自己的段落 → 正常角色消息
    final roleName = sharedRoles.first;
    // 段落文本以 `【角色名】` 开头（解析器已去掉标题，这里重新加上供 UI 展示）
    final displayText = text.startsWith('【') ? text : '【$roleName】\n$text';
    // 附加 roleTag：UI 按角色名查色板着色气泡（M3 多角色视觉）
    messages.add(Message.assistant(displayText, roleTag: roleName));
    roundEntries.add(
      HistoryEntry(role: MessageRole.assistant, content: displayText),
    );
  }

  // 4. 若有未归位的文本（overflow），追加为系统消息说明（可选）
  if (overflow.isNotEmpty) {
    messages.add(Message.system('（额外叙事：$overflow）'));
    roundEntries.add(
      HistoryEntry(role: MessageRole.system, content: '（额外叙事：$overflow）'),
    );
  }

  // 本轮完整共享段落镜像写入每个角色的 history
  final rolesWithHistory = {
    for (final e in roleHistories.entries)
      e.key: nextRoles[e.key]!.copyWith(history: [...e.value, ...roundEntries]),
  };

  return next.copyWith(
    roles: rolesWithHistory,
    messages: messages,
    isGenerating: false,
    streamingContent: '',
    lastError: lastError,
  );
}

/// 生成失败：重置生成状态 + 记录错误。
StageNarrativeState _onStageGenerationFailed(
  StageNarrativeState state,
  String message,
) {
  return state.copyWith(
    isGenerating: false,
    streamingContent: '',
    lastError: message,
  );
}

/// 从舞台角色存档恢复会话。
StageNarrativeState _onStageSessionRestored(
  StageNarrativeState state,
  Map<String, Contract> restoredByRole,
  List<Message> messages,
) {
  final roles = Map<String, RoleRunState>.from(state.roles);
  for (final entry in restoredByRole.entries) {
    final contract = entry.value;
    final role = roles[entry.key];
    if (role == null) continue;
    roles[entry.key] = role.copyWith(
      currentState: contract.stateMap,
      memories: List<Memory>.from(contract.memories),
      history: List<HistoryEntry>.from(contract.history),
    );
  }

  return state.copyWith(
    roles: roles,
    messages: List<Message>.from(messages),
    isGenerating: false,
    streamingContent: '',
    lastError: '',
    // 会话级附件是临时数据：恢复会话时清空，避免残留旧附件引用
    attachedFileNames: [],
    attachedContexts: [],
  );
}

/// 会话重置：保留舞台，清空动态数据（含会话级附加上下文）。
StageNarrativeState _onStageSessionReset(StageNarrativeState state) {
  final stage = state.stage;
  final roles = <String, RoleRunState>{};
  if (stage != null) {
    for (final character in stage.characters) {
      final roleName = character.roleName;
      roles[roleName] = RoleRunState(currentState: character.contract.stateMap);
    }
  }

  return state.copyWith(
    roles: roles,
    messages: [],
    isGenerating: false,
    streamingContent: '',
    lastError: '',
    diceResults: const [],
    lastRollInfo: '',
    attachedFileNames: [],
    attachedContexts: [],
  );
}
