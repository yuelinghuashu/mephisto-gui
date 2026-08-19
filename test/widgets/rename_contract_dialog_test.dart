import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/widgets/dialogs/rename_contract_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

/// RenameContractDialog 重命名契约对话框测试
///
/// 覆盖：
///   - 输入框预填当前文件名
///   - 合法 .meph 名称 + 回车 → 返回新名称
///   - 非法名称（缺 .meph 后缀）→ 回车不关闭
///   - 取消返回 null
///   - 目标文件名已存在（非自身）→ 阻止提交并展示错误提示
///   - 重命名为自身名 → 放行
///   - 子版重命名时显示命运说明输入框并返回修改后的值
///   - 母版重命名时不显示命运说明输入框
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Completer<(String, String?)?> completer;

  /// 当前被重命名的文件（默认 faust.meph 已存在于契约目录）
  String currentName = 'faust.meph';

  /// 是否为子版（决定是否显示命运说明输入框）
  bool showFateField = false;

  /// 当前命运说明初始值（预填用）
  String? initialFateTitle;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_rename_test_');
    // 重置流程状态变量（避免测试间状态泄漏）
    currentName = 'faust.meph';
    showFateField = false;
    initialFateTitle = null;
    // mock 契约目录：faust.meph 已存在（当前文件），dantes.meph 已存在（重名目标）
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
      'mephisto_current_contract': currentName,
      // 按目录绑定种子标记
      'mephisto_contracts_seeded_${tempDir.path}': true,
    });
    await File('${tempDir.path}/faust.meph').writeAsString('【角色名】\n浮士德\n');
    await File('${tempDir.path}/dantes.meph').writeAsString('【角色名】\n埃德蒙·唐泰斯\n');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void resetFlowState({
    String name = 'faust.meph',
    bool showFate = false,
    String? fateTitle,
  }) {
    currentName = name;
    showFateField = showFate;
    initialFateTitle = fateTitle;
  }

  Future<void> openDialog(WidgetTester tester) async {
    completer = Completer<(String, String?)?>();
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () {
                completer.complete(
                  RenameContractDialog.show(
                    context,
                    currentName: currentName,
                    initialBranchTitle: initialFateTitle,
                    showBranchTitleField: showFateField,
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('输入框预填当前文件名', (tester) async {
    await openDialog(tester);
    expect(find.text('faust.meph'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('合法 .meph 名称 + 回车返回新名称', (tester) async {
    await openDialog(tester);

    // 歌德.meph 在目录中不存在 → 异步校验通过。
    // 注意：isContractNameAvailable → File.exists() 是真实异步 IO，
    // FakeAsync zone 中无法由 fake clock 驱动完成，需 runAsync 给真实事件循环时间。
    await tester.enterText(find.byType(TextField), '歌德.meph');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(await completer.future, ('歌德.meph', null));
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('非法名称（无 .meph 后缀）回车不关闭', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '歌德');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // 合法名称提交 → 异步校验（真实 IO）需 runAsync 完成
    await tester.enterText(find.byType(TextField), '歌德.meph');
    await tester.tap(find.text('重命名'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(await completer.future, ('歌德.meph', null));
  });

  testWidgets('取消返回 null', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await completer.future, isNull);
  });

  testWidgets('目标文件名已存在（非自身）→ 阻止提交并展示错误', (tester) async {
    await openDialog(tester);

    // dantes.meph 已存在于契约目录 → 异步校验拦截（真实 IO 需 runAsync）
    await tester.enterText(find.byType(TextField), 'dantes.meph');
    await tester.tap(find.text('重命名'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // 对话框未关闭 + 错误提示出现（重名提交已被异步校验拦截）
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('该文件名已存在，请更换'), findsOneWidget);

    // 改为合法新名后仍可提交（同样需要 runAsync 完成真实 IO）
    await tester.enterText(find.byType(TextField), '歌德.meph');
    await tester.tap(find.text('重命名'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(await completer.future, ('歌德.meph', null));
  });

  testWidgets('重命名为自身名 → 放行', (tester) async {
    await openDialog(tester);

    // 输入当前文件名 faust.meph（自身）→ 异步校验放行
    await tester.enterText(find.byType(TextField), 'faust.meph');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    expect(await completer.future, ('faust.meph', null));
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('子版显示命运说明输入框并返回修改后的值', (tester) async {
    resetFlowState(
      name: 'faust.dark.meph',
      showFate: true,
      fateTitle: '旧的命运说明',
    );
    await openDialog(tester);

    // 两个输入框：文件名 + 命运说明
    expect(find.byType(TextField), findsNWidgets(2));
    // 命运说明预填当前值
    expect(find.text('旧的命运说明'), findsOneWidget);

    // 修改命运说明后提交（faust.dark.meph 非当前名 → 异步校验需 runAsync）
    await tester.enterText(find.byType(TextField).first, 'faust.dark.meph');
    await tester.enterText(find.byType(TextField).last, '新的命运说明');
    await tester.tap(find.text('重命名'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(await completer.future, ('faust.dark.meph', '新的命运说明'));
  });

  testWidgets('母版不显示命运说明输入框', (tester) async {
    // 保持默认：母版（faust.meph）不显示命运说明
    await openDialog(tester);

    expect(find.byType(TextField), findsOneWidget);
  });
}
