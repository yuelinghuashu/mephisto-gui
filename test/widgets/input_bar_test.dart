import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:mephisto/widgets/narrative/input_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// InputBar 交互边界测试
///
/// 覆盖近期修复的三个键盘交互 bug：
///   1. 桌面端 Enter 直接发送（而非第一次换行、第二次才提交）
///   2. 方向键区域 Numpad Enter 同样发送（而非换行）
///   3. ↑ / ↓ 历史回溯跨会话持久化（退出重进不丢失）
///
/// 通过 MaterialApp.theme.platform 控制 `_isDesktop` 判定
/// （默认 linux = 桌面端；android = 移动端）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 构建带指定平台主题的 MaterialApp（控制 InputBar._isDesktop 判定）。
  Widget buildApp({
    required Widget home,
    TargetPlatform platform = TargetPlatform.linux,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('zh'), Locale('en')],
        home: home,
      ),
    );
  }

  /// 构建独立 InputBar（注入回调，默认桌面端 linux）。
  Widget buildInputBar({
    required ValueChanged<String> onSend,
    TargetPlatform platform = TargetPlatform.linux,
  }) {
    return buildApp(
      platform: platform,
      home: Scaffold(
        body: InputBar(isGenerating: false, onSend: onSend, onStop: () {}),
      ),
    );
  }

  testWidgets('桌面端：主键盘 Enter 直接发送且不换行', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(buildInputBar(onSend: sent.add));

    await tester.enterText(find.byType(TextField), '命运指引');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'linux');
    await tester.pump();

    // 发送回调被调用（第一次回车即提交）
    expect(sent, ['命运指引']);
    // 输入框已清空
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('桌面端：方向键区域 Numpad Enter 同样发送且不换行', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(buildInputBar(onSend: sent.add));

    await tester.enterText(find.byType(TextField), '调查地窖');
    await tester.sendKeyEvent(
      LogicalKeyboardKey.numpadEnter,
      platform: 'linux',
    );
    await tester.pump();

    // Numpad Enter 同样触发发送（修复：漏匹配 numpadEnter 导致换行）
    expect(sent, ['调查地窖']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('桌面端：Shift+Enter 不触发发送（放行给换行）', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(buildInputBar(onSend: sent.add));

    await tester.enterText(find.byType(TextField), '多行');
    // 按住 Shift → Enter（_handleKeyEvent 应返回 ignored 放行，不触发 _sendMessage）
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.shiftLeft,
      platform: 'linux',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'linux');
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.shiftLeft,
      platform: 'linux',
    );
    await tester.pump();

    // 核心断言：Shift 按下时 Enter 不触发发送
    expect(sent, isEmpty);
  });

  testWidgets('桌面端：发送后 ↑ 回溯最近历史（跨会话持久化）', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(buildInputBar(onSend: sent.add));

    // 发送两条历史
    await tester.enterText(find.byType(TextField), '第一条');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'linux');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '第二条');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'linux');
    await tester.pump();

    // ↑ 回溯：最近一条
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp, platform: 'linux');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '第二条',
    );

    // 再 ↑ 回溯：更早一条
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp, platform: 'linux');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '第一条',
    );
  });

  // 注：持久化 round-trip（写入 → 重建容器 → 恢复）已由
  // input_history_provider_test.dart 的「持久化 round-trip」覆盖；
  // ↑ 回溯 UI 行为已由「发送后 ↑ 回溯最近历史」覆盖。
  // 两者组合的 widget 测试受 testWidgets FakeAsync 与真实异步 IO 的
  // 时序矛盾影响不稳定，故不在此重复（避免脆弱测试）。

  testWidgets('移动端：软键盘提交动作触发发送（走 onSubmitted）', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(
      buildInputBar(onSend: sent.add, platform: TargetPlatform.android),
    );

    await tester.enterText(find.byType(TextField), '移动端输入');
    // 移动端软键盘「发送」动作
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(sent, ['移动端输入']);
  });
}
