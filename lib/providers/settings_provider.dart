import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/storage_keys.dart';
import 'prefs_notifier.dart';

/// 设置持久化 Provider
///
/// 管理所有应用级用户偏好，当前支持：
///   - 主题模式（跟随系统/亮色/暗色）
class SettingsController extends PrefsNotifier<ThemeMode> {
  /// SharedPreferences 存储键（统一来自 [themeModeKey]）
  @override
  String get key => themeModeKey;

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

/// 语言偏好控制器
///
/// 管理用户选择的界面语言，持久化到 SharedPreferences。
/// 当前支持：`zh`（简体中文，默认）/ `en`（English）。
class AppLanguageController extends PrefsNotifier<String> {
  /// SharedPreferences 存储键（统一来自 [languageKey]）
  @override
  String get key => languageKey;

  @override
  String get defaultValue => 'zh';

  @override
  String? fromStorage(String raw) =>
      (raw == 'zh' || raw == 'en') ? raw : null;

  @override
  String toStorage(String value) => value;

  /// 设置界面语言（`zh` / `en`）
  Future<void> setLanguage(String language) => save(language);
}

/// 界面语言 Provider（`zh` = 简体中文，`en` = English）
final languageProvider = NotifierProvider<AppLanguageController, String>(
  AppLanguageController.new,
);