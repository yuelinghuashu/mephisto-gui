import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'llm_settings_provider.dart';
import 'narrative_memory_provider.dart';
import 'narrative_rule_provider.dart';
import 'narrative_window_provider.dart';

/// 单轮生成所需的全部用户配置快照
///
/// 统一封装叙事生成所需的用户偏好：
///   - [llmConfig]：主 LLM 配置（API Key / Base URL / Model / 超时 / 重试）
///   - [auxLlmConfig]：辅助任务 LLM 配置（记忆提取/压缩使用；
///     null 时所有任务共用主配置）
///   - [narrativeRules]：用户自定义叙事约束
///   - [maxHistoryMessages]：历史消息窗口上限（null = 全部发送）
///   - [maxMemories]：每轮记忆注入条数上限（null = 全部注入）
class GenerationSettings {
  /// 主 LLM 配置（主叙事使用）
  final LlmConfig llmConfig;

  /// 辅助任务 LLM 配置（记忆提取/压缩使用；null = 共用主配置）
  final LlmAuxConfig? auxLlmConfig;

  /// 叙事规则（设置页自定义约束）
  final String narrativeRules;

  /// 历史消息窗口上限（null = 不限制 = 全部发送）
  final int? maxHistoryMessages;

  /// 记忆注入条数上限（null = 不限制 = 全部注入）
  final int? maxMemories;

  const GenerationSettings({
    required this.llmConfig,
    this.auxLlmConfig,
    required this.narrativeRules,
    this.maxHistoryMessages,
    this.maxMemories,
  });
}

/// 单轮生成配置 Provider
///
/// 统一读取生成所需的全部用户偏好，消除单角色 [NarrativeNotifier] 与
/// 多角色 [StageNarrativeNotifier] 中重复的配置读取样板（约 4 行 × 2 处）。
///
/// 设计要点：
///   - 非 `autoDispose`：Notifier 的 async 生成流程中调用 `ref.refresh` 时，
///     autoDispose 会在 Notifier 重建/释放时销毁 provider 导致 Ref 失效异常，
///     因此使用普通 `FutureProvider` 确保 provider 存活整个容器生命周期
///   - 调用方（Notifier `_generateCore`）使用 `ref.refresh(...)` 强制刷新，
///     确保每次生成都读取最新持久化配置（改 key 后不重启也能立即生效）
final generationSettingsProvider = FutureProvider<GenerationSettings>((ref) async {
  // 确保每次读取最新持久化的 LLM 配置（readConfig 不写 state，避免多余重建）
  final config = await ref.read(llmConfigProvider.future);
  // 读取辅助任务模型配置（未启用/无持久化时为 null → 共用主配置）
  final auxConfig = await ref
      .read(llmSettingsProvider.notifier)
      .readAuxConfig();
  final narrativeRules = ref.read(narrativeRuleProvider);
  final maxHistoryMessages = ref
      .read(narrativeWindowProvider)
      .maxHistoryMessages;
  final maxMemories = ref
      .read(narrativeMemoryLimitProvider)
      .maxMemories;
  return GenerationSettings(
    llmConfig: config,
    auxLlmConfig: auxConfig,
    narrativeRules: narrativeRules,
    maxHistoryMessages: maxHistoryMessages,
    maxMemories: maxMemories,
  );
});
