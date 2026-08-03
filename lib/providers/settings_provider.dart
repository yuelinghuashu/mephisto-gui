import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_notifier.dart';

/// 设置持久化 Provider
///
/// 管理所有应用级用户偏好，当前支持：
///   - 主题模式（跟随系统/亮色/暗色）
class SettingsController extends PrefsNotifier<ThemeMode> {
  /// SharedPreferences 存储键
  @override
  String get key => _themeModeKey;

  static const String _themeModeKey = 'mephisto_theme_mode';

  @override
  ThemeMode get defaultValue => ThemeMode.system;

  @override
  ThemeMode? fromStorage(String raw) => ThemeMode.values.asNameMap()[raw];

  @override
  String toStorage(ThemeMode value) => value.name;

  /// 设置主题模式（兼容旧调用名）
  Future<void> setThemeMode(ThemeMode mode) => save(mode);
}

/// 主题模式 Provider
final themeModeProvider = NotifierProvider<SettingsController, ThemeMode>(
  SettingsController.new,
);
