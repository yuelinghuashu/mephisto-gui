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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Completer<String?> completer;

  /// 当前被重命名的文件（默认 faust.meph 已存在于契约目录）
  String currentName = 'faust.meph';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_rename_test_');
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

  Future<void> openDialog(WidgetTester tester) async {
    completer = Completer<String?>();
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

    // 歌德.meph 在目录中不存在 → 异步校验通过
    await tester.enterText(find.byType(TextField), '歌德.meph');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(await completer.future, '歌德.meph');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('非法名称（无 .meph 后缀）回车不关闭', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '歌德');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '歌德.meph');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    expect(await completer.future, '歌德.meph');
  });

  testWidgets('取消返回 null', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await completer.future, isNull);
  });

  testWidgets('目标文件名已存在（非自身）→ 阻止提交并展示错误', (tester) async {
    await openDialog(tester);

    // dantes.meph 已存在于契约目录 → 异步校验拦截
    await tester.enterText(find.byType(TextField), 'dantes.meph');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    // 对话框未关闭 + 错误提示出现（重名提交已被异步校验拦截）
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('该文件名已存在，请更换'), findsOneWidget);
    // 注：不用 completer.isCompleted 断言「对话框未关闭」——
    //   openDialog 用 completer.complete(Future) 包装，Dart 的 Completer 在
    //   complete() 被调用时即置为 completed（其值待 Future resolve），
    //   因此 isCompleted 从打开对话框起恒为 true，无法反映对话框真实状态。
    //   对话框是否关闭由上面的 find.byType(TextField) 断言保证。

    // 改为合法新名后仍可提交
    await tester.enterText(find.byType(TextField), '歌德.meph');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    expect(await completer.future, '歌德.meph');
  });

  testWidgets('重命名为自身名 → 放行', (tester) async {
    await openDialog(tester);

    // 输入当前文件名 faust.meph（自身）→ 异步校验放行
    await tester.enterText(find.byType(TextField), 'faust.meph');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    expect(await completer.future, 'faust.meph');
    expect(find.byType(TextField), findsNothing);
  });
}