import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../screens/home_screen.dart';
import '../screens/narrative_screen.dart';
import '../screens/settings_screen.dart';
import 'theme.dart';

/// Mephisto 应用根 Widget
///
/// 配置说明：
///   - 同时支持亮色/暗色两种主题
///   - 主题模式来自 [themeModeProvider]，支持跟随系统/亮色/暗色
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 各 Notifier 已在 build() 中自动从 SharedPreferences 恢复持久化偏好
    // （主题 / LLM 配置 / 叙事宽度 / 叙事规则），此处无需手动逐项 load。
  }

  @override
  Widget build(BuildContext context) {
    // 从持久化设置读取主题模式（默认跟随系统）
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Mephisto',

      /// 亮色主题（当系统为亮色时使用）
      theme: AppTheme.light(),

      /// 暗色主题（当系统为暗色时使用）
      darkTheme: AppTheme.dark(),

      /// 主题模式（跟随系统/强制亮色/强制暗色）
      themeMode: themeMode,

      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/narrative': (_) => const NarrativeScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}