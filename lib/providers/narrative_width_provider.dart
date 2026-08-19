import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_notifier.dart';

/// 叙事内容宽度档位
///
/// 供桌面端用户选择叙事界面（消息流 + 输入区）的最大宽度：
///   - [narrow]：560px，适合小窗口 / 紧凑阅读
///   - [medium]：720px，平衡阅读（默认）
///   - [wide]：960px，大屏舒适阅读
///   - [full]：无限宽，最大化利用屏幕
///
/// 移动端由于屏幕宽度通常小于最小档位（560px），会自动占满全宽，不受影响。
enum NarrativeWidth { narrow, medium, wide, full }

/// 叙事宽度档位扩展
extension NarrativeWidthExtension on NarrativeWidth {
  /// 对应最大宽度（null 表示无限 = 满屏）
  double? get maxWidth => switch (this) {
    NarrativeWidth.narrow => 560,
    NarrativeWidth.medium => 720,
    NarrativeWidth.wide => 960,
    NarrativeWidth.full => null,
  };
}

/// 叙事宽度偏好控制器
///
/// 将用户选择的叙事内容宽度持久化到 SharedPreferences。
class NarrativeWidthController extends PrefsNotifier<NarrativeWidth> {
  /// SharedPreferences 存储键
  @override
  String get key => _key;

  static const String _key = 'mephisto_narrative_width';

  @override
  NarrativeWidth get defaultValue => NarrativeWidth.medium;

  @override
  NarrativeWidth? fromStorage(String raw) =>
      NarrativeWidth.values.asNameMap()[raw];

  @override
  String toStorage(NarrativeWidth value) => value.name;

  /// 设置宽度偏好（兼容旧调用名）
  Future<void> setWidth(NarrativeWidth width) => save(width);
}

/// 叙事内容宽度 Provider
final narrativeWidthProvider =
    NotifierProvider<NarrativeWidthController, NarrativeWidth>(
      NarrativeWidthController.new,
    );
