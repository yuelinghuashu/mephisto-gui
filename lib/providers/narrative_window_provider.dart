import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_notifier.dart';

/// 历史消息窗口档位
///
/// 控制发送给 LLM 的历史对话条数上限（不含本轮用户指引）。
/// 对话无限增长时，保留最近 N 条可以：
///   - 控制 token 消耗（API 成本）
///   - 防止超长上下文稀释模型注意力、降低响应质量
enum NarrativeWindow {
  narrow,
  medium,
  wide,
  full,
}

/// 历史窗口档位扩展
extension NarrativeWindowExtension on NarrativeWindow {
  /// 对应最大历史消息条数（null 表示不限制 = 全部发送）
  int? get maxHistoryMessages => switch (this) {
    NarrativeWindow.narrow => 20,
    NarrativeWindow.medium => 40,
    NarrativeWindow.wide => 60,
    NarrativeWindow.full => null,
  };
}

/// 历史窗口偏好控制器
///
/// 将用户选择的历史消息窗口偏好持久化到 SharedPreferences。
class NarrativeWindowController extends PrefsNotifier<NarrativeWindow> {
  /// SharedPreferences 存储键
  @override
  String get key => _key;

  static const String _key = 'mephisto_narrative_window';

  @override
  NarrativeWindow get defaultValue => NarrativeWindow.medium;

  @override
  NarrativeWindow? fromStorage(String raw) =>
      NarrativeWindow.values.asNameMap()[raw];

  @override
  String toStorage(NarrativeWindow value) => value.name;

  /// 设置窗口档位
  Future<void> setWindow(NarrativeWindow window) => save(window);
}

/// 历史消息窗口 Provider
final narrativeWindowProvider =
    NotifierProvider<NarrativeWindowController, NarrativeWindow>(
      NarrativeWindowController.new,
    );