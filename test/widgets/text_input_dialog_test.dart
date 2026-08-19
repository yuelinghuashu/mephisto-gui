import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/widgets/dialogs/text_input_dialog.dart';
import 'test_helpers.dart';

/// TextInputDialog 通用文本输入对话框测试
///
/// 核心回归场景：
///   - 完整交互生命周期不抛「controller after dispose」异常
///     （此前实现通过 whenComplete 过早 dispose 导致崩溃）
///   - 回车 = 确认提交
///   - 校验失败时不关闭
///   - 取消返回 null
void main() {
  late Completer<String?> completer;

  Future<void> openDialog(WidgetTester tester) async {
    completer = Completer<String?>();
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () {
                completer.complete(
                  TextInputDialog.show(
                    context,
                    title: '测试标题',
                    labelText: '测试标签',
                    hintText: '测试提示',
                    validate: (v) => v.isNotEmpty,
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

  testWidgets('回车提交：完整生命周期不抛 controller after dispose', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'dark');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(await completer.future, 'dark');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('点击确认按钮提交', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'dark');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(await completer.future, 'dark');
  });

  testWidgets('校验失败时不关闭对话框', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'dark');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(await completer.future, 'dark');
  });

  testWidgets('取消按钮返回 null', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await completer.future, isNull);
  });

  testWidgets('初始值显示在输入框中', (tester) async {
    completer = Completer<String?>();
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () {
                completer.complete(
                  TextInputDialog.show(
                    context,
                    title: '测试标题',
                    labelText: '测试标签',
                    initialValue: 'faust.meph',
                    validate: (v) => v.isNotEmpty,
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

    expect(find.text('faust.meph'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await completer.future, isNull);
  });
}
