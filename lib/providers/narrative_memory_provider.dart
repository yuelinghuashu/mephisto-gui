import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_notifier.dart';

/// 记忆注入上限档位
///
/// 控制每轮发送给 LLM 的记忆条数上限。
/// 记忆无限增长时，限制注入条数可以：
///   - 控制 token 消耗（API 成本）
///   - 防止超长记忆列表稀释模型注意力
/// 超过上限时高权重（≥4）全部保留 + 其余按权重降序补足。
enum NarrativeMemoryLimit { compact, standard, extended, full }

/// 记忆注入上限档位扩展
extension NarrativeMemoryLimitExtension on NarrativeMemoryLimit {
  /// 对应最大记忆注入条数（null 表示不限制 = 全部注入）
  int? get maxMemories => switch (this) {
    NarrativeMemoryLimit.compact => 10,
    NarrativeMemoryLimit.standard => 20,
    NarrativeMemoryLimit.extended => 30,
    NarrativeMemoryLimit.full => null,
  };
}

/// 记忆注入上限偏好控制器
///
/// 将用户选择的记忆注入档位持久化到 SharedPreferences。
class NarrativeMemoryController extends PrefsNotifier<NarrativeMemoryLimit> {
  /// SharedPreferences 存储键
  @override
  String get key => _key;

  static const String _key = 'mephisto_narrative_memory_limit';

  @override
  NarrativeMemoryLimit get defaultValue => NarrativeMemoryLimit.standard;

  @override
  NarrativeMemoryLimit? fromStorage(String raw) =>
      NarrativeMemoryLimit.values.asNameMap()[raw];

  @override
  String toStorage(NarrativeMemoryLimit value) => value.name;

  /// 设置档位
  Future<void> setLimit(NarrativeMemoryLimit limit) => save(limit);
}

/// 记忆注入上限 Provider
final narrativeMemoryLimitProvider =
    NotifierProvider<NarrativeMemoryController, NarrativeMemoryLimit>(
      NarrativeMemoryController.new,
    );
