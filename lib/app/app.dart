import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

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
  Widget build(BuildContext context) {
    // 从持久化设置读取主题模式（默认跟随系统）
    final themeMode = ref.watch(themeModeProvider);
    // 从持久化设置读取界面语言（默认简体中文）
    final language = ref.watch(languageProvider);

    return MaterialApp(
      title: 'Mephisto',
      // 应用界面语言（由用户偏好决定，而非跟随系统）
      locale: Locale(language),
      // 本地化委托：AppLocalizations + Flutter 内置组件本地化
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

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
