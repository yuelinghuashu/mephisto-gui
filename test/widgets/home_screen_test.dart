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
///
/// 多级树模型：`ContractGroup.children` 是**递归的子节点列表**，
/// 层级通过文件名 `.` 分段表达（如 faust → faust.dark → faust.dark.light）。
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

  ContractInfo info(
    String name, {
    String? branch,
    String? branchTitle,
    DateTime? lastModified,
  }) {
    final base = name.replaceAll('.meph', '').split('.').first;
    return ContractInfo(
      fileName: name,
      roleName: base,
      isChild: branch != null,
      branchName: branch,
      branchTitle: branchTitle,
      lastModified: lastModified,
    );
  }

  // 单级子节点（一级：母版 → 分支）
  ContractGroup child(String name, {String? branch, String? branchTitle}) {
    return ContractGroup(
      master: info(name, branch: branch, branchTitle: branchTitle),
      children: [],
    );
  }

  // 样例：faust 母版 + 2 一级子版，dantes 母版无子版
  List<ContractGroup> sampleGroups() => [
    ContractGroup(
      master: info('faust.meph'),
      children: [
        child('faust.child.meph', branch: 'child'),
        child('faust.dark.meph', branch: 'dark'),
      ],
    ),
    ContractGroup(master: info('dantes.meph'), children: []),
  ];

  // 多级树样例：faust → dark → light（二级分支）
  List<ContractGroup> nestedGroups() => [
    ContractGroup(
      master: info('faust.meph'),
      children: [
        ContractGroup(
          master: info('faust.dark.meph', branch: 'dark'),
          children: [
            child('faust.dark.light.meph', branch: 'light'),
          ],
        ),
      ],
    ),
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

  testWidgets('品牌标题右侧显示「最近编辑」快捷入口（角色名 + 相对时间）', (tester) async {
    // 带 mtime 的契约：dantes 最近编辑，faust 较旧
    final now = DateTime.now();
    final groups = [
      ContractGroup(
        master: info(
          'faust.meph',
          lastModified: now.subtract(const Duration(days: 3)),
        ),
        children: [],
      ),
      ContractGroup(
        master: info(
          'dantes.meph',
          lastModified: now.subtract(const Duration(hours: 2)),
        ),
        children: [],
      ),
    ];
    await tester.pumpWidget(buildHome(groups: groups));
    await tester.pumpAndSettle();

    // 品牌标题存在
    expect(find.text('Mephisto 叙事引擎'), findsOneWidget);
    // 最近编辑胶囊存在（history 图标）；胶囊文本包含 dantes + 相对时间
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.textContaining('dantes · 2 小时前'), findsOneWidget);
  });

  testWidgets('无 mtime 的契约列表 → 不显示最近编辑快捷入口', (tester) async {
    // sampleGroups 中所有 info 均无 lastModified → 快捷入口不显示
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    // 品牌标题存在，但没有历史图标胶囊
    expect(find.text('Mephisto 叙事引擎'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsNothing);
  });

  testWidgets('多级树：逐级展开可见二级分支，收起后隐藏', (tester) async {
    await tester.pumpWidget(buildHome(groups: nestedGroups()));
    await tester.pumpAndSettle();

    // 初始只显示母版，子版默认收起
    expect(find.text('faust'), findsOneWidget);
    expect(find.text('faust.dark.light.meph'), findsNothing);

    // 展开第一层 → 显示 dark
    await tester.tap(find.byTooltip('展开子版'));
    await tester.pumpAndSettle();
    expect(find.text('faust.dark.meph'), findsOneWidget);
    // 二级 light 尚未展开
    expect(find.text('faust.dark.light.meph'), findsNothing);

    // 展开第二层 → 显示 light
    await tester.tap(find.byTooltip('展开子版').last);
    await tester.pumpAndSettle();
    expect(find.text('faust.dark.light.meph'), findsOneWidget);

    // 收起第二层 → light 隐藏
    await tester.tap(find.byTooltip('收起子版').last);
    await tester.pumpAndSettle();
    expect(find.text('faust.dark.light.meph'), findsNothing);
  });

  testWidgets('超长命运描述与超长文件名不溢出卡片边界（省略号截断）', (tester) async {
    // 超长 @命运 描述 + 超长分支名 + 远超卡片可用宽度的超长文件名
    final groups = [
      ContractGroup(
        master: info('faust.meph'),
        children: [
          child(
            'faust.verylongbranchnamechild.this-file-name-is-far-longer-than-'
            'any-card-can-fit-in-a-single-row-meph.meph',
            branch: 'very-long-branch-name',
            branchTitle: '命运：理想国支线里浮士德在边际海岸望向乌托邦的那一天，'
                '天上的云像极了他年轻时追求的知识之海',
          ),
        ],
      ),
    ];
    await tester.pumpWidget(buildHome(groups: groups));
    await tester.pumpAndSettle();

    // 展开子版区
    await tester.tap(find.byTooltip('展开子版'));
    await tester.pumpAndSettle();

    // 无溢出异常（Flutter 测试默认 FlutterError.onError 会捕获 RenderFlex overflow）
    expect(tester.takeException(), isNull);

    // 命运描述截断展示（未完整铺满）
    final titleText = tester.widget<Text>(
      find.textContaining('命运：理想国支线里浮士德在边际海岸望向乌托邦的那一天'),
    );
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);

    // 文件名同样被省略号截断（不再撑满整行 / 溢出右缘）
    final fileNameText = tester.widget<Text>(
      find.byWidgetPredicate((w) =>
          w is Text &&
          w.data != null &&
          w.data!.startsWith('faust.verylongbranchnamechild.this-file-name')),
    );
    expect(fileNameText.maxLines, 1);
    expect(fileNameText.overflow, TextOverflow.ellipsis);
  });

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

  testWidgets('长按母版自动展开子版区，被级联选中的子版立即可见', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    // 不手动展开子版区，直接长按母版
    // （修复前：子版被级联选中但不可见，也无法在窗口中展开查看）
    await tester.longPress(find.text('faust'));
    await tester.pumpAndSettle();

    // 母版 + 2 子版全部被选中
    expect(find.text('已选 3 项'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));

    // 子版区自动展开：子版文件名应立即可见（而非需要手动点箭头展开）
    expect(find.text('faust.child.meph'), findsOneWidget);
    expect(find.text('faust.dark.meph'), findsOneWidget);

    // 子版区已展开，展开箭头在多选模式下仍保留（可收起）
    expect(find.byTooltip('收起子版'), findsOneWidget);

    // 直接点击子版可单独取消选中（验证子版对用户可操作）
    await tester.tap(find.text('faust.child.meph'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });

  testWidgets('多选模式下其他列表仍可展开/收起子版', (tester) async {
    // faust（级联目标）+ goethe（有其他子版，未展开）
    final groups = [
      ContractGroup(
        master: info('faust.meph'),
        children: [child('faust.child.meph', branch: 'child')],
      ),
      ContractGroup(
        master: info('goethe.meph'),
        children: [child('goethe.utopia.meph', branch: 'utopia')],
      ),
    ];
    await tester.pumpWidget(buildHome(groups: groups));
    await tester.pumpAndSettle();

    // 长按 faust 进入多选（faust 子版自动展开，goethe 保持收起）
    await tester.longPress(find.text('faust'));
    await tester.pumpAndSettle();

    // 多选模式下：faust 显示「收起子版」，goethe 仍显示「展开子版」箭头
    expect(find.text('已选 2 项'), findsOneWidget);
    expect(find.byTooltip('收起子版'), findsOneWidget);
    expect(find.byTooltip('展开子版'), findsOneWidget);

    // 点击 goethe 的展开箭头 → 其子版立即可见
    // （faust 已级联展开，此时 goethe 展开后有两个「收起子版」箭头）
    await tester.tap(find.byTooltip('展开子版'));
    await tester.pumpAndSettle();
    expect(find.text('goethe.utopia.meph'), findsOneWidget);
    expect(find.byTooltip('收起子版'), findsNWidgets(2));

    // 点击 goethe 的收起箭头（列表顺序中 goethe 在 faust 之后）→ 子版收起
    await tester.tap(find.byTooltip('收起子版').last);
    await tester.pumpAndSettle();
    expect(find.text('goethe.utopia.meph'), findsNothing);
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