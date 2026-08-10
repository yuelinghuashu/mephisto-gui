/// 舞台叙事状态事件（Reducer 风格状态机的输入）
library;

import 'models.dart';
import 'stage_models.dart';

/// 舞台叙事状态事件基类（密封，穷尽匹配安全）。
sealed class StageNarrativeEvent {
  const StageNarrativeEvent();
}

/// 舞台加载成功（含各角色初始状态初始化）。
class StageLoadedEvent extends StageNarrativeEvent {
  /// 舞台数据
  final StageLoaded stage;

  /// 舞台目录绝对路径
  final String stagePath;

  /// 各角色初始运行时状态（角色名 → 初始状态；规则引擎从 contract.stateMap 起步）
  final Map<String, Map<String, StateValue>> initialStates;

  const StageLoadedEvent({
    required this.stage,
    required this.stagePath,
    required this.initialStates,
  });
}

/// 用户发送消息（命运指引）。
class StageMessageSent extends StageNarrativeEvent {
  final String content;
  const StageMessageSent(this.content);
}

/// AI 回复成功生成（各角色各自更新的状态/记忆/回复）。
class StageReplySucceeded extends StageNarrativeEvent {
  /// 各角色段落（角色名 → 该角色的叙事文本）
  final Map<String, String> replies;

  /// 各角色规则引擎运行后的新状态（角色名 → 新状态）
  final Map<String, Map<String, StateValue>> newStates;

  /// 各角色规则引擎注入的新记忆（角色名 → 注入记忆）
  final Map<String, List<Memory>> injectedMemories;

  /// 未被任何已声明角色匹配的 LLM 输出（前言/总结/未知角色段）
  final String overflow;

  /// 骰子判定信息（非空时调用方以系统消息插入叙事流）
  final String rollInfo;

  /// 骰子判定结构化结果（供 UI 渲染「命运结算」卡片）
  final List<DiceResult> diceResults;

  /// 最近一次 LLM 错误信息
  final String lastError;

  const StageReplySucceeded({
    required this.replies,
    required this.newStates,
    required this.injectedMemories,
    required this.overflow,
    required this.rollInfo,
    required this.diceResults,
    required this.lastError,
  });
}

/// 生成失败（LLM 调用异常或未预期错误）。
class StageGenerationFailed extends StageNarrativeEvent {
  final String message;
  const StageGenerationFailed(this.message);
}

/// 从舞台角色存档恢复会话。
class StageSessionRestored extends StageNarrativeEvent {
  /// 各角色名 → 恢复的契约（含运行时状态/记忆/历史）
  final Map<String, Contract> restoredByRole;

  /// 恢复后的共享消息流（从各角色历史去重合并）
  final List<Message> messages;

  const StageSessionRestored({
    required this.restoredByRole,
    required this.messages,
  });
}

/// 会话重置（保留舞台，清空动态数据）。
class StageSessionReset extends StageNarrativeEvent {
  const StageSessionReset();
}

/// 附加上下文（会话级，多选追加）。
class StageContextAttached extends StageNarrativeEvent {
  final String fileName;
  final String content;
  const StageContextAttached({required this.fileName, required this.content});
}

/// 移除指定索引的附加上下文（越界忽略）。
class StageContextRemoved extends StageNarrativeEvent {
  final int index;
  const StageContextRemoved(this.index);
}
