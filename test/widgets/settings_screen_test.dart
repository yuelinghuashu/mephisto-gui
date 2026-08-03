import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/providers/providers.dart';
import 'package:mephisto/screens/settings_screen.dart';
import 'package:mephisto/services/prompt/system_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置页 Widget 测试
///
/// 覆盖：
///   - 区块渲染（外观/宽度/规则/契约目录/LLM 配置）
///   - 主题模式切换（持久化到 SharedPreferences）
///   - 叙事规则编辑+保存 / 恢复默认
///   - LLM 后端切换（Ollama 隐藏 API Key + 自动填充 URL）
///
/// 注意：不点击「测试连接」按钮（会发起真实网络请求）；
/// 契约目录指向临时路径避免触发 path_provider。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': '/tmp/mephisto_settings_test',
      'mephisto_theme_mode': 'system',
      'mephisto_narrative_rules': defaultNarrativeRules,
    });
  });

  Widget buildSettings() {
    return const ProviderScope(child: MaterialApp(home: SettingsScreen()));
  }

  testWidgets('渲染全部配置区块', (tester) async {
    await tester.pumpWidget(buildSettings());
    await tester.pumpAndSettle();

    expect(find.text('◉  外观'), findsOneWidget);
    expect(find.text('📐  叙事内容宽度'), findsOneWidget);
    expect(find.text('📜  叙事规则'), findsOneWidget);
    expect(find.text('⚜  契约目录'), findsOneWidget);
    expect(find.text('⚚  LLM 配置'), findsOneWidget);
    // 主题选项
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('亮色'), findsOneWidget);
    expect(find.text('暗色'), findsOneWidget);
    // LLM 后端选项
    expect(find.text('OpenAI 兼容'), findsOneWidget);
    expect(find.text('本地 Ollama'), findsOneWidget);
  });

  testWidgets('主题模式切换为暗色并持久化', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 初始为跟随系统
    expect(container.read(themeModeProvider), ThemeMode.system);

    // 点击「暗色」
    await tester.tap(find.text('暗色'));
    await tester.pumpAndSettle();

    // Provider 状态已更新
    expect(container.read(themeModeProvider), ThemeMode.dark);
    // 持久化到 SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mephisto_theme_mode'), 'dark');
  });

  testWidgets('叙事规则编辑保存与恢复默认', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 编辑规则文本框（页面有多个 TextField，叙事规则是唯一 maxLines: null 的）
    final ruleField = find.byWidgetPredicate(
      (w) => w is TextField && w.maxLines == null,
    );
    expect(ruleField, findsOneWidget);
    await tester.enterText(ruleField, '以冷峻白描风格叙事');
    // 页面较长，「保存规则」按钮可能在视口外，先滚动到可见再点击
    await tester.ensureVisible(find.text('保存规则'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存规则'));
    await tester.pumpAndSettle();

    // Provider 更新 + 持久化
    expect(container.read(narrativeRuleProvider), '以冷峻白描风格叙事');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mephisto_narrative_rules'), '以冷峻白描风格叙事');

    // 恢复默认（页面有两处「恢复默认」：叙事规则区 + LLM 配置区；
    // 叙事规则区先渲染 → 取 .first）
    await tester.ensureVisible(find.text('恢复默认').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认').first);
    await tester.pumpAndSettle();
    expect(container.read(narrativeRuleProvider), defaultNarrativeRules);
  });

  testWidgets('LLM 后端切换：Ollama 隐藏 API Key 并填充本地 URL', (tester) async {
    await tester.pumpWidget(buildSettings());
    await tester.pumpAndSettle();

    // 初始 OpenAI 兼容：API Key 输入框存在
    expect(find.text('API Key'), findsOneWidget);

    // LLM 配置区块在页面底部，先滚动到可见再点击「本地 Ollama」
    await tester.ensureVisible(find.text('本地 Ollama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地 Ollama'));
    await tester.pumpAndSettle();

    // API Key 隐藏；Base URL 输入框值已自动填充为本地地址
    // （本地地址同时出现在输入框值和 hint 文本中 → findsNWidgets(2)）
    expect(find.text('API Key'), findsNothing);
    expect(find.text('http://localhost:11434/v1'), findsNWidgets(2));
    // 直接校验输入框值更精确
    final baseUrlField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'http://localhost:11434/v1').first,
    );
    expect(baseUrlField.controller?.text, 'http://localhost:11434/v1');
  });

  // ============================================================
  // 契约目录区：平台自适应分支
  // ============================================================
  // 通过 debugDefaultTargetPlatformOverride 模拟移动端平台，
  // 验证契约目录区不再隐藏按钮，而是按平台能力渲染。

  testWidgets('Android：显示「切换为外部存储」按钮（不隐藏）', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      // Android 分支的说明文案
      expect(
        find.textContaining('契约保存在应用的私有空间'),
        findsOneWidget,
      );
      // 存储切换按钮存在（而非隐藏/删除）
      await tester.ensureVisible(find.text('切换为外部存储'));
      await tester.pumpAndSettle();
      expect(find.text('切换为外部存储'), findsOneWidget);
    } finally {
      // 必须在测试体内复位：debugAssertAllFoundationVarsUnset 在
      // 测试体结束后立即校验，addTearDown 执行太晚
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS：显示「更改目录」按钮且点击如实提示（不隐藏）', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      // iOS 分支的说明文案
      expect(
        find.textContaining('iOS 系统沙盒限制'),
        findsOneWidget,
      );
      // 「更改目录」按钮存在
      await tester.ensureVisible(find.text('更改目录'));
      await tester.pumpAndSettle();
      expect(find.text('更改目录'), findsOneWidget);

      // 点击 → 如实提示沙盒限制（而非无响应）
      await tester.tap(find.text('更改目录'));
      await tester.pumpAndSettle();
      expect(find.textContaining('无法更改位置'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
