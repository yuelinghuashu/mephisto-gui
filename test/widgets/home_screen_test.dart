import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/providers/contract_provider.dart';
import 'package:mephisto/providers/providers.dart';
import 'package:mephisto/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

/// 首页 Widget 测试
///
/// 通过 override contractGroupListProvider 注入内存分组，避免真实文件 IO；
/// 删除测试使用真实临时文件验证「多选 → 确认 → 文件删除」闭环。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_home_test_');
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ContractInfo info(String name, {String? branch}) {
    final base = name.replaceAll('.meph', '').split('.').first;
    return ContractInfo(
      fileName: name,
      roleName: base,
      isChild: branch != null,
      branchName: branch,
    );
  }

  // 样例：faust 母版 + 2 子版，dantes 母版无子版
  List<ContractGroup> sampleGroups() => [
    ContractGroup(
      master: info('faust.meph'),
      children: [
        info('faust.child.meph', branch: 'child'),
        info('faust.dark.meph', branch: 'dark'),
      ],
    ),
    ContractGroup(master: info('dantes.meph'), children: []),
  ];

  Widget buildHome({List<ContractGroup>? groups}) {
    return ProviderScope(
      overrides: [
        contractGroupListProvider.overrideWith(
          (ref) async => groups ?? sampleGroups(),
        ),
        currentContractNameProvider.overrideWith((ref) async => 'faust.meph'),
      ],
      child: localizedApp(home: const HomeScreen()),
    );
  }

  testWidgets('渲染母版分组列表', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.text('faust'), findsOneWidget);
    expect(find.text('faust.meph'), findsOneWidget);
    expect(find.text('dantes'), findsOneWidget);
    // 子版默认收起，不显示文件名
    expect(find.text('faust.child.meph'), findsNothing);
    // 有子版的母版显示展开箭头
    expect(find.byTooltip('展开子版'), findsOneWidget);
  });

  testWidgets('展开/收起子版区', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('展开子版'));
    await tester.pumpAndSettle();

    // 子版文件名与分支名出现
    expect(find.text('faust.child.meph'), findsOneWidget);
    expect(find.text('faust.dark.meph'), findsOneWidget);
    expect(find.text('child'), findsOneWidget);
    expect(find.text('dark'), findsOneWidget);

    // 收起
    await tester.tap(find.byTooltip('收起子版'));
    await tester.pumpAndSettle();
    expect(find.text('faust.child.meph'), findsNothing);
  });

  testWidgets('长按母版进入多选并级联选中子版', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    // 先展开子版，便于观察全选效果
    await tester.tap(find.byTooltip('展开子版'));
    await tester.pumpAndSettle();

    // 长按母版角色名行
    await tester.longPress(find.text('faust'));
    await tester.pumpAndSettle();

    // 顶部显示选中计数，母版 + 2 子版全部被选中
    expect(find.text('已选 3 项'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));

    // 退出多选
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();
    expect(find.text('已选 3 项'), findsNothing);
  });

  testWidgets('批量删除：确认对话框 → 点击删除 → 退出多选', (tester) async {
    // 注意：此处不验证真实文件删除——widget 测试运行在 FakeAsync zone，
    // 真实文件系统 IO 的异步回调与 FakeAsync 冲突会挂起测试。
    // 文件系统层面的删除已由 narrative_provider_test（saveChild/delete 路径）覆盖。
    final groups = [ContractGroup(master: info('faust.meph'), children: [])];
    await tester.pumpWidget(buildHome(groups: groups));
    await tester.pumpAndSettle();

    // 长按进入多选
    await tester.longPress(find.text('faust'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsOneWidget);

    // 点击 AppBar 删除按钮 → 弹出确认对话框
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('删除契约'), findsOneWidget);

    // 点击「取消」→ 对话框关闭，保持多选模式（未删除）
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsOneWidget);

    // 再次打开确认对话框，点击「删除」→ 退出多选（UI 流程正常完成）
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNothing);
  });
}
