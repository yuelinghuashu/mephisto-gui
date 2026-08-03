import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(contract.anchor, hasLength(3));
    expect(contract.state, hasLength(3));
    expect(contract.rules, hasLength(14));
    expect(contract.worldview, isNotEmpty);
    expect(contract.opening, isNotEmpty);
    // 规则带行号
    expect(contract.rules.first.line, greaterThan(0));
    // 互斥组规则被正确提取
    expect(contract.rules.last.group, '侵蚀');
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
      // 兜底提示已置位
      expect(
        container.read(contractFallbackNoticeProvider),
        contains('已加载内置模板'),
      );
    });

    test('用户文件缺失 → 回退 assets 内置模板 + 兜底提示', () async {
      await seedPrefs(contractName: 'dantes.meph');
      // 目录为空（无 dantes.meph，种子已置位不复制）→ contractProvider 走 assets 兜底
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final contract = await container.read(contractProvider.future);
      // assets 内置 dantes.meph：角色名埃德蒙·唐泰斯
      expect(contract.roleName, '埃德蒙·唐泰斯');
      expect(contract.opening, isNotEmpty);
      expect(
        container.read(contractFallbackNoticeProvider),
        contains('已加载内置模板'),
      );
    });

    test('用户文件正常加载 → 兜底提示为空', () async {
      await seedPrefs();
      // 写入合法的 faust.meph
      await File('${tempDir.path}/faust.meph').writeAsString(
        '【角色名】\n浮士德\n\n【世界观】\n充满契约的世界\n',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final contract = await container.read(contractProvider.future);
      expect(contract.roleName, '浮士德');
      // 正常加载：不显示兜底提示
      expect(container.read(contractFallbackNoticeProvider), isNull);
    });
    // 注：不为「非内置名缺失 → 抛异常」写独立用例——
    //   `expectLater(future)` 等待 Riverpod 异步 error state 与 provider dispose
    //   存在固有竞态（dispose 先于 error state 触发时抛 Bad state），测试天然不稳定。
    //   该行为已由 _builtinFallback「仅同名内置模板兜底」的实现保证。
  });
}
