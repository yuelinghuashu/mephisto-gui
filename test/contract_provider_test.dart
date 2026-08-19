import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/narrative_error.dart';
import 'package:mephisto/providers/contract_provider.dart';
import 'package:mephisto/services/parser/meph_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_contract_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 初始化 SharedPreferences 指向临时目录 + 种子标记已置位（跳过 ensureContracts 复制）。
  Future<void> seedPrefs({String contractName = 'faust.meph'}) async {
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
      'mephisto_current_contract': contractName,
      // 标记已种子（按目录绑定）：ensureContracts 直接 return，不复制内置模板，
      // 确保测试真实覆盖「用户文件缺失/损坏 → assets 兜底」路径
      'mephisto_contracts_seeded_${tempDir.path}': true,
    });
  }

  test('解析 assets 中的 faust.meph 得到正确契约', () async {
    final source = await rootBundle.loadString('assets/contracts/faust.meph');
    final contract = parseMeph(source);

    expect(contract.roleName, '浮士德');
    expect(contract.anchor, hasLength(4));
    expect(contract.state, hasLength(3));
    // 纯状态机化后共 8 条规则
    expect(contract.rules, hasLength(8));
    expect(contract.worldview, isNotEmpty);
    expect(contract.opening, isNotEmpty);
    // 规则带行号
    expect(contract.rules.first.line, greaterThan(0));
    // 互斥组规则被正确提取（「侵蚀」组含暗影缠身与烛火映心）
    expect(contract.rules.any((r) => r.group == '侵蚀'), isTrue);
  });

  group('contractProvider - 用户目录文件损坏时 assets 兜底', () {
    test('用户文件含语法错误（空格拆分复合运算符）→ 回退 assets 内置模板 + 兜底提示', () async {
      await seedPrefs();
      // 写入损坏的 faust.meph：复合运算符中间有空格，parseMeph 会抛错
      await File('${tempDir.path}/faust.meph').writeAsString(
        '【角色名】\n浮士德\n\n【规则】\n'
        '[损坏] if 包含 "堕落" -> 状态.灵魂完整度 + = 10\n',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final contract = await container.read(contractProvider.future);
      // 回退到 assets 内置 faust.meph：角色名浮士德，开局场景完整
      expect(contract.roleName, '浮士德');
      expect(contract.opening, isNotEmpty);
      expect(contract.rules, isNotEmpty);
      // 兜底提示已置位（Provider 层暴露错误码，由 UI 层翻译）
      expect(
        container.read(contractFallbackNoticeProvider),
        narrativeErrorContractFallback,
      );
    });

    test('用户文件缺失 → 回退 assets 内置模板 + 兜底提示', () async {
      await seedPrefs(contractName: 'dantes.meph');
      // 目录为空（无 dantes.meph，种子已置位不复制）→ contractProvider 走 assets 兜底
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final contract = await container.read(contractProvider.future);
      // assets 内置 dantes.meph：角色名基督山伯爵
      expect(contract.roleName, '基督山伯爵');
      expect(contract.opening, isNotEmpty);
      expect(
        container.read(contractFallbackNoticeProvider),
        narrativeErrorContractFallback,
      );
    });

    test('用户文件正常加载 → 兜底提示为空', () async {
      await seedPrefs();
      // 写入合法的 faust.meph
      await File(
        '${tempDir.path}/faust.meph',
      ).writeAsString('【角色名】\n浮士德\n\n【世界观】\n充满契约的世界\n');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final contract = await container.read(contractProvider.future);
      expect(contract.roleName, '浮士德');
      // 正常加载：不显示兜底提示
      expect(container.read(contractFallbackNoticeProvider), isNull);
    });
  });

  group('contractProvider - 自定义契约缺失时最终兜底', () {
    test('用户自定义契约（非内置名）缺失 → 返回空契约 + 兜底提示', () async {
      // 当前契约名指向用户自定义契约（非内置模板名），但文件不存在
      await seedPrefs(contractName: 'my_story.meph');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 不再抛异常：contractProvider 保证始终成功返回
      final contract = await container.read(contractProvider.future);
      // 空契约兜底（roleName: '角色'），叙事页不崩溃
      expect(contract.roleName, '角色');
      expect(contract.opening, isEmpty);
      expect(contract.rules, isEmpty);
      // 兜底提示已置位：叙事页顶部警告条可见
      expect(
        container.read(contractFallbackNoticeProvider),
        narrativeErrorContractFallback,
      );
    });
  });

  group('buildContractTree - 孤儿节点处理', () {
    test('父链缺失的子版 → 占位根 + 真实子节点', () {
      // 只有 faust.dark 子版，没有 faust 母版根
      final infos = [
        ContractInfo(
          fileName: 'faust.dark.meph',
          roleName: '浮士德·黑暗面',
          isChild: true,
        ),
      ];

      final groups = buildContractTree(infos);

      // faust 占位根 → faust.dark 真实节点
      expect(groups, hasLength(1));
      expect(groups.first.master.fileName, 'faust.meph');
      expect(groups.first.hasChildren, isTrue);
      expect(groups.first.children.first.master.fileName, 'faust.dark.meph');
    });

    test('孤儿深链 → 占位根 + 多级子树', () {
      // 只有 faust.dark.light 二级子版，没有 faust 和 faust.dark
      final infos = [
        ContractInfo(
          fileName: 'faust.dark.light.meph',
          roleName: '光',
          isChild: true,
        ),
      ];

      final groups = buildContractTree(infos);

      // faust 占位根 → faust.dark 占位 → faust.dark.light 真实节点
      expect(groups, hasLength(1));
      expect(groups.first.master.fileName, 'faust.meph');
      expect(groups.first.hasChildren, isTrue);
      expect(groups.first.children.first.master.fileName, 'faust.dark.meph');
      expect(
        groups.first.children.first.children.first.master.fileName,
        'faust.dark.light.meph',
      );
    });
  });

  group('buildContractTree - 深度守卫', () {
    test('超过 maxContractDepth 层级 → 截断为叶子节点', () {
      // 构造 maxContractDepth+1 层（当前常量为 8）的超长链
      final segments = List.generate(maxContractDepth + 1, (i) => 'x$i');
      final deepName = '${segments.join('.')}.meph';
      final infos = [
        ContractInfo(fileName: deepName, roleName: '深度角色', isChild: true),
      ];

      final groups = buildContractTree(infos);

      // 能正常构建、不栈溢出；至少存在顶层根
      expect(groups, hasLength(1));
    });
  });

  group('contractGroupListProvider - 最近编辑排序', () {
    test('顶层母版树按「子树最近编辑」降序排列', () async {
      await seedPrefs();
      // 创建两个母版 + 手动写入 mtime（旧 faust / 新 dantes）
      await File('${tempDir.path}/faust.meph').writeAsString('【角色名】\n浮士德\n');
      await File('${tempDir.path}/dantes.meph').writeAsString('【角色名】\n唐泰斯\n');
      // 调整 mtime：dantes 最新，faust 较旧
      final now = DateTime.now();
      await File(
        '${tempDir.path}/faust.meph',
      ).setLastModified(now.subtract(const Duration(days: 2)));
      await File(
        '${tempDir.path}/dantes.meph',
      ).setLastModified(now.subtract(const Duration(hours: 1)));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final groups = await container.read(contractGroupListProvider.future);
      expect(groups, hasLength(2));
      // 最近编辑的 dantes 排在最前
      expect(groups.first.master.fileName, 'dantes.meph');
      expect(groups.last.master.fileName, 'faust.meph');
    });

    test('子版最新编辑时间反映到母版树排序（自动保存子版后母版树靠前）', () async {
      await seedPrefs();
      // 两个母版：faust（有子版），dantes（无子版）
      await File('${tempDir.path}/faust.meph').writeAsString('【角色名】\n浮士德\n');
      await File('${tempDir.path}/dantes.meph').writeAsString('【角色名】\n唐泰斯\n');
      // dantes 母版最近编辑（更"新"）
      final now = DateTime.now();
      await File(
        '${tempDir.path}/dantes.meph',
      ).setLastModified(now.subtract(const Duration(hours: 2)));
      await File(
        '${tempDir.path}/faust.meph',
      ).setLastModified(now.subtract(const Duration(days: 2)));
      // faust 的子版在 1 小时前被编辑（自动保存）→ 整棵 faust 树比 dantes 新
      await File(
        '${tempDir.path}/faust.child.meph',
      ).writeAsString('【角色名】\n浮士德\n【历史】\n');
      await File(
        '${tempDir.path}/faust.child.meph',
      ).setLastModified(now.subtract(const Duration(hours: 1)));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final groups = await container.read(contractGroupListProvider.future);
      expect(groups, hasLength(2));
      // faust 树整体比 dantes 新（因为子版刚被自动保存过）→ faust 排前
      expect(groups.first.master.fileName, 'faust.meph');
      expect(groups.first.latestModified, isNotNull);
    });
  });
}
