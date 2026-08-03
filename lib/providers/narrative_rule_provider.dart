import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/prompt/system_prompt.dart';
import 'prefs_notifier.dart';

/// 叙事规则偏好控制器
///
/// 管理用户在设置页自定义的叙事输出约束（规则列表），
/// 持久化到 SharedPreferences。
/// 默认值引用 [defaultNarrativeRules]（定义在 system_prompt.dart）。
class NarrativeRuleController extends PrefsNotifier<String> {
  /// SharedPreferences 存储键
  @override
  String get key => _key;

  static const String _key = 'mephisto_narrative_rules';

  @override
  String get defaultValue => defaultNarrativeRules;

  @override
  String? fromStorage(String raw) => raw.isEmpty ? null : raw;

  @override
  String toStorage(String value) => value;

  /// 保存叙事规则（空值回退默认）
  @override
  Future<void> save(String rules) {
    final finalRules = rules.trim().isEmpty
        ? defaultNarrativeRules
        : rules.trim();
    return super.save(finalRules);
  }

  /// 恢复默认规则
  Future<void> reset() => clear();
}

/// 叙事规则 Provider
final narrativeRuleProvider = NotifierProvider<NarrativeRuleController, String>(
  NarrativeRuleController.new,
);
