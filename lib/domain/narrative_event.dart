/// 叙事状态事件（Reducer 风格状态机的输入）
library;

import 'config.dart';
import 'contract.dart';
import 'entities.dart';
import 'values.dart';

/// 叙事状态事件基类（密封，穷尽匹配安全）。
sealed class NarrativeEvent {
  const NarrativeEvent();
}

/// 用户发送消息（命运指引）。
class MessageSent extends NarrativeEvent {
  final String content;
  const MessageSent(this.content);
}

/// AI 回复成功生成。
class ReplySucceeded extends NarrativeEvent {
  final String reply;
  final Map<String, StateValue> newState;
  final List<Memory> injectedMemories;
  final String rollInfo;
  final List<DiceResult> diceResults;
  final String lastError;
  const ReplySucceeded({
    required this.reply,
    required this.newState,
    required this.injectedMemories,
    required this.rollInfo,
    required this.diceResults,
    required this.lastError,
  });
}

/// 生成失败（LLM 调用异常或未预期错误）。
class GenerationFailed extends NarrativeEvent {
  final String message;
  const GenerationFailed(this.message);
}

/// 从子版存档恢复会话。
class SessionRestored extends NarrativeEvent {
  final Contract restored;
  final String fileName;
  const SessionRestored({required this.restored, required this.fileName});
}

/// 会话重置（保留契约，清空动态数据）。
class SessionReset extends NarrativeEvent {
  const SessionReset();
}

/// 更新单个状态值。
class StateValueSet extends NarrativeEvent {
  final String key;
  final StateValue value;
  const StateValueSet({required this.key, required this.value});
}

/// 附加上下文（会话级，多选追加）。
class ContextAttached extends NarrativeEvent {
  final String fileName;
  final String content;
  const ContextAttached({required this.fileName, required this.content});
}

/// 移除指定索引的附加上下文。
class ContextRemoved extends NarrativeEvent {
  final int index;
  const ContextRemoved(this.index);
}

/// 清空所有附加上下文。
class ContextsCleared extends NarrativeEvent {
  const ContextsCleared();
}