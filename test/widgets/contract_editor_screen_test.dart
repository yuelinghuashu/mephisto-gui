import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/screens/contract_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

/// 契约编辑器 Widget 测试
///
/// 覆盖（全部为无真实文件写入的路径，避免 FakeAsync 与文件 IO 冲突）：
///   - 编辑模式渲染（文件名 + 预填内容）
///   - 实时校验：输入非法 .meph → 防抖后显示错误条
///   - 格式化按钮：规整规则行运算符空格
///   - 保存时格式错误 → SnackBar 提示（parseMeph 抛错后 return，不触达文件 IO）
///
/// 合法内容的真实保存（写文件）由 contract_repo 的服务单测覆盖。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 契约目录指向临时路径（避免真实保存触发 path_provider；
    // 本测试实际不点击会写入的保存路径）
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': '/tmp/mephisto_editor_test',
    });
  });

  const validOpening = '''
【角色名】
浮士德

【开局场景】
烛火摇曳的书斋。
''';

  Widget buildEditor() {
    return localizedApp(
      home: const ContractEditorScreen(
        // 编辑模式（非新建）：不触发 assets 模板加载
        fileName: 'faust.meph',
        initialContent: validOpening,
      ),
    );
  }

  testWidgets('编辑模式渲染：标题 + 文件名 + 预填内容', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('✏️ 编辑契约'), findsOneWidget);
    // 编辑模式无文件名输入框（仅新建模式显示）→ 验证编辑区预填内容
    expect(find.byType(TextField), findsOneWidget); // 仅编辑区
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, contains('浮士德'));
    expect(field.controller!.text, contains('烛火摇曳的书斋'));
  });

  testWidgets('实时校验：输入非法 .meph → 显示错误条', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    // 初始合法 → 错误条不显示
    expect(find.byIcon(Icons.error_outline), findsNothing);

    // 输入非法内容（规则缺 '->'）
    await tester.enterText(
      find.byType(TextField).last, // 编辑区 TextField
      '【角色名】\n浮士德\n\n【规则】\n[测试] if 包含 "x" 缺少箭头\n',
    );
    // 等待 400ms 防抖 + 校验
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 错误条显示（含行号定位）
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining("规则缺少 '->'"), findsOneWidget);
  });

  testWidgets('格式化按钮：规整规则行运算符空格', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    // 输入含被空格拆开运算符的规则（格式化器会自动修复）
    const messy = '''
【角色名】
浮士德

【规则】
[堕落] if 包含 "堕落" -> 状态.堕落指数 + = 10
''';
    await tester.enterText(find.byType(TextField).last, messy);
    await tester.pumpAndSettle();

    // 点击格式化按钮
    await tester.tap(find.byTooltip('格式化文本（调整缩进、空行并修复运算符空格）'));
    await tester.pumpAndSettle();

    // 规则行被规整为 `+=`（运算符空格被合并）
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, contains('状态.堕落指数 += 10'));
  });

  testWidgets('保存格式错误 → SnackBar 提示（不写入文件）', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    // 输入非法内容
    await tester.enterText(
      find.byType(TextField).last,
      '【角色名】\n浮士德\n\n【规则】\n[测试] 不是合法规则\n',
    );

    // 点击保存 → parseMeph 抛错 → SnackBar 错误提示 + 不关闭页面
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    // 「格式错误」同时出现在实时校验错误条与 SnackBar 提示中
    expect(find.textContaining('格式错误'), findsWidgets);
    // 页面仍在（未返回）
    expect(find.text('✏️ 编辑契约'), findsOneWidget);
  });
}
