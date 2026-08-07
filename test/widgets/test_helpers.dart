import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

/// 给测试中的 MaterialApp 注入本地化委托（与 app.dart 保持一致）。
///
/// 所有 widget 测试的 MaterialApp 必须配置 localizationsDelegates +
/// supportedLocales，否则 `AppLocalizations.of(context)` 无法解析。
///
/// 默认 locale 为 `zh`（与生产默认一致），测试断言的中文文案可保持原样。
Widget localizedApp({
  required Widget home,
  Locale locale = const Locale('zh'),
  List<Locale> supportedLocales = const [Locale('zh'), Locale('en')],
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: supportedLocales,
    home: home,
  );
}

/// 带 routes 的本地化 MaterialApp（用于测试路由跳转，如叙事页 → 设置页）。
Widget localizedAppWithRoutes({
  required Widget home,
  Map<String, WidgetBuilder> routes = const {},
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('zh'), Locale('en')],
    routes: routes,
    home: home,
  );
}
