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
/// 新 UI 语义（单行紧凑卡片）：
///   - 母版卡片显示角色名 + 文件名 + 「分支 · N」入口 + ⋮ 菜单
///   - 点击「分支 · N」弹出 [HomeBranchSheet] 列出母版 + 全部子版
///   - 多选模式下「分支 · N」入口与 ⋮ 菜单均隐藏
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
      child: localizedAppWithRoutes(
        home: const HomeScreen(),
        // 注册叙事页路由（空占位），避免点击分支/子版触发 pushNamed 找不到路由
        routes: {'/narrative': (_) => const SizedBox.shrink()},
      ),
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

  testWidgets('点击「分支 · N」弹出分支选择器：列出母版+子版，可进入对应分支', (tester) async {
    // 多级树：faust → dark → light
    await tester.pumpWidget(buildHome(groups: nestedGroups()));
    await tester.pumpAndSettle();

    // 初始只显示母版角色名，子版文件名不直接展示
    expect(find.text('faust'), findsOneWidget);
    expect(find.text('faust.dark.light.meph'), findsNothing);

    // faust 有 1 个直接子节点 → 显示「分支 · 1」入口
    expect(find.text('分支 · 1'), findsOneWidget);

    // 点击分支入口 → 弹出 BottomSheet（列出母版 + 直接子版）
    await tester.tap(find.text('分支 · 1'));
    await tester.pumpAndSettle();

    // BottomSheet 标题 = 母版角色名；母版入口 + 一级子版 dark 均可见。
    // faust 出现 3 次：首页卡片角色名 + BottomSheet 标题 + 母版入口
    expect(find.text('faust'), findsNWidgets(3));
    expect(find.text('faust.meph'), findsNWidgets(2)); // 卡片文件名 + 母版入口副标题
    expect(find.text('dark'), findsOneWidget); // 一级子版分支名

    // 点击一级子版 → 关闭 BottomSheet 并进入叙事页（pushNamed /narrative）
    await tester.tap(find.text('dark'));
    await tester.pumpAndSettle();
    // 已跳转到叙事页占位（SizedBox.shrink），首页卡片不再可见
    expect(find.text('faust'), findsNothing);
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

    // 无溢出异常（Flutter 测试默认 FlutterError.onError 会捕获 RenderFlex overflow）
    expect(tester.takeException(), isNull);

    // 母版卡片本身正常渲染
    expect(find.text('faust'), findsOneWidget);
    expect(find.text('faust.meph'), findsOneWidget);

    // 点击「分支 · 1」→ 弹出分支选择器
    await tester.tap(find.text('分支 · 1'));
    await tester.pumpAndSettle();

    // 分支选择器内部：命运描述截断展示（未完整铺满）
    final titleText = tester.widget<Text>(
      find.textContaining('命运：理想国支线里浮士德在边际海岸望向乌托邦的那一天'),
    );
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);

    // 文件名同样被省略号截断
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
    // 子版文件不在首页卡片中直接显示（通过「分支 · N」入口访问）
    expect(find.text('faust.child.meph'), findsNothing);
    // 有子版的母版显示「分支 · 2」，无子版的 dantes 不显示
    expect(find.text('分支 · 2'), findsOneWidget);
    expect(find.textContaining('分支 ·'), findsOneWidget);
  });

  testWidgets('分支选择器列出全部子版并可关闭', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    // 点击「分支 · 2」→ 弹出 BottomSheet
    await tester.tap(find.text('分支 · 2'));
    await tester.pumpAndSettle();

    // BottomSheet：母版入口 + 2 个子版。
    // faust 出现 3 次：首页卡片角色名 + BottomSheet 标题 + 母版入口
    expect(find.text('faust'), findsNWidgets(3));
    expect(find.text('child'), findsOneWidget);
    expect(find.text('dark'), findsOneWidget);
    expect(find.text('faust.child.meph'), findsOneWidget);
    expect(find.text('faust.dark.meph'), findsOneWidget);

    // 点击关闭按钮 → BottomSheet 消失
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('child'), findsNothing);
    expect(find.text('dark'), findsNothing);
  });

  testWidgets('长按母版进入多选并级联选中子版', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    // 长按母版角色名行
    await tester.longPress(find.text('faust'));
    await tester.pumpAndSettle();

    // 顶部显示选中计数，母版 + 2 子版全部被选中
    expect(find.text('已选 3 项'), findsOneWidget);
    // 屏幕上仅渲染母版卡片 → 只有 1 个选中勾选图标可见
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // 多选模式下「分支 · N」入口隐藏
    expect(find.textContaining('分支 ·'), findsNothing);

    // 退出多选
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();
    expect(find.text('已选 3 项'), findsNothing);
  });

  testWidgets('长按母版进入多选：级联选中整棵子树，分支入口隐藏', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    // 长按母版（不手动展开任何内容）
    await tester.longPress(find.text('faust'));
    await tester.pumpAndSettle();

    // 母版 + 2 子版全部被选中
    expect(find.text('已选 3 项'), findsOneWidget);
    // 屏幕上仅渲染母版卡片 → 只有 1 个选中勾选图标可见
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // 多选模式下：分支入口（「分支 · N」）隐藏、⋮ 菜单隐藏
    expect(find.textContaining('分支 ·'), findsNothing);
    expect(find.byTooltip('操作'), findsNothing);

    // 点击母版行取消级联选中（含整棵子树）→ 多选模式自动退出（AppBar 恢复普通模式）
    await tester.tap(find.text('faust'));
    await tester.pumpAndSettle();
    expect(find.text('已选 0 项'), findsNothing);
    // 普通 AppBar 恢复：显示「新建契约」操作按钮
    expect(find.byTooltip('新建契约'), findsOneWidget);
  });

  testWidgets('多选模式：其他列表不再显示「分支」入口，可继续切换选中', (tester) async {
    // faust（级联目标）+ goethe（有其他子版）
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

    // 普通模式：两个母版均有「分支 · 1」入口
    expect(find.text('分支 · 1'), findsNWidgets(2));

    // 长按 faust 进入多选
    await tester.longPress(find.text('faust'));
    await tester.pumpAndSettle();

    // 多选模式下：所有「分支 · N」入口隐藏
    expect(find.textContaining('分支 ·'), findsNothing);
    expect(find.text('已选 2 项'), findsOneWidget);

    // 点击 goethe 母版行 → 级联选中其整棵子树（goethe + goethe.utopia）
    await tester.tap(find.text('goethe'));
    await tester.pumpAndSettle();
    expect(find.text('已选 4 项'), findsOneWidget);
    // 屏幕上仅渲染两个母版卡片 → 只有 2 个选中勾选图标可见
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });

  testWidgets('批量删除：确认对话框 → 取消 → 多选保持不变', (tester) async {
    // 注意：此处不验证真实文件删除——widget 测试运行在 FakeAsync zone，
    // 真实文件系统 IO（File.delete）的异步回调无法由 fake clock 驱动，
    // 会挂起测试。文件系统层面的删除已由 narrative_provider_test
    // （saveChild/delete 路径）与 contract_provider_test（deleteContract）覆盖。
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

    // 再次打开确认对话框 → 仍可正常弹出（删除流程 UI 完整）
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('删除契约'), findsOneWidget);

    // 再取消 → 多选保持；通过 AppBar「取消」按钮退出多选
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsOneWidget);
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNothing);
    // 普通 AppBar 恢复（设置按钮可见）
    expect(find.byTooltip('设置'), findsOneWidget);
  });
}