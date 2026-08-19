import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/providers/llm_settings_provider.dart';
import 'package:mephisto/providers/stage_narrative_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// StageNarrativeNotifier 单元测试
///
/// 覆盖舞台加载、生成闭环（分节解析 + 状态写回）、自动存档（各角色独立
/// 子版写入舞台目录）。网络层通过 mock HTTP 客户端隔离。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory stageDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_stage_provider_');
    stageDir = Directory('${tempDir.path}/浮士德与梅菲斯特');
    await stageDir.create(recursive: true);
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });

    // 舞台角色卡：浮士德（带规则）+ 梅菲斯特
    await File('${stageDir.path}/浮士德.meph').writeAsString(
      '【角色名】\n浮士德\n\n'
      '【世界观】\n书斋与契约的世界\n\n'
      '【状态】\n- 灵魂完整度：80\n\n'
      '【规则】\n'
      '[堕落加深] if 包含 "堕落" -> 状态.灵魂完整度 -= 10\n',
    );
    await File('${stageDir.path}/梅菲斯特.meph').writeAsString(
      '【角色名】\n梅菲斯特\n\n'
      '【背景】\n来自深渊的契约者\n',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<ProviderContainer> buildContainer() async {
    final container = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(
          MockClient((request) async => throw Exception('mock 网络错误')),
        ),
      ],
    );
    addTearDown(() async {
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
    });
    return container;
  }

  /// 轮询等待生成流程结束
  Future<void> waitForGeneration(
    ProviderContainer container, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (container.read(stageNarrativeProvider).isGenerating) {
      if (DateTime.now().isAfter(deadline)) {
        fail('舞台生成流程超时未结束');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('加载舞台：初始化各角色状态', () async {
    final container = await buildContainer();
    final notifier = container.read(stageNarrativeProvider.notifier);

    final ok = await notifier.loadStage(stageDir.path);
    expect(ok, isTrue);

    final state = container.read(stageNarrativeProvider);
    expect(state.stageName, '浮士德与梅菲斯特');
    expect(state.characterCount, 2);
    expect(state.roles['浮士德']!.currentState['灵魂完整度'], const IntValue(80));
    expect(state.roles['梅菲斯特']!.currentState, isEmpty);
    expect(state.isGenerating, isFalse);
  });

  test('加载不存在的舞台 → false + 错误提示', () async {
    final container = await buildContainer();
    final notifier = container.read(stageNarrativeProvider.notifier);

    final ok = await notifier.loadStage('${tempDir.path}/不存在');
    expect(ok, isFalse);
    expect(container.read(stageNarrativeProvider).lastError, isNotEmpty);
  });

  test('生成闭环：LLM 失败 → 本地多角色回复 + 各角色独立存档', () async {
    final container = await buildContainer();
    final notifier = container.read(stageNarrativeProvider.notifier);

    await notifier.loadStage(stageDir.path);
    await notifier.sendMessage('命运降临');

    await waitForGeneration(container);
    final state = container.read(stageNarrativeProvider);

    // 消息流：命运 + 双角色回复
    expect(state.messages.first.content, '命运降临');
    expect(state.messages, hasLength(3));
    expect(state.isGenerating, isFalse);

    // 各角色存档独立写入舞台目录
    expect(File('${stageDir.path}/浮士德.child.meph').existsSync(), isTrue);
    expect(File('${stageDir.path}/梅菲斯特.child.meph').existsSync(), isTrue);
    // 各自存档包含该角色的历史
    final faustSave = await File(
      '${stageDir.path}/浮士德.child.meph',
    ).readAsString();
    expect(faustSave, contains('【历史】'));
  });

  test('规则状态变更应用到对应角色', () async {
    final container = await buildContainer();
    final notifier = container.read(stageNarrativeProvider.notifier);

    await notifier.loadStage(stageDir.path);
    await notifier.sendMessage('我堕落了');
    await waitForGeneration(container);

    final state = container.read(stageNarrativeProvider);
    // 浮士德规则触发：80 - 10 = 70；梅菲斯特无规则 → 状态不变
    expect(state.roles['浮士德']!.currentState['灵魂完整度'], const IntValue(70));
  });

  test('loadStage restoreSaves=false → 跳过存档、直接进入母版空开局', () async {
    final container = await buildContainer();
    final notifier = container.read(stageNarrativeProvider.notifier);

    // 先正常加载并推进一次，产生存档
    await notifier.loadStage(stageDir.path);
    await notifier.sendMessage('命运降临');
    await waitForGeneration(container);
    expect(File('${stageDir.path}/浮士德.child.meph').existsSync(), isTrue);

    // 重新开始：restoreSaves=false → 不恢复存档 → 母版空开局
    notifier.resetSession();
    final restartOk = await notifier.loadStage(
      stageDir.path,
      restoreSaves: false,
    );
    expect(restartOk, isTrue);
    final state = container.read(stageNarrativeProvider);
    // 无历史/消息 → 母版开局（即使磁盘有存档也不恢复）
    expect(state.messages, isEmpty);
    expect(state.roles['浮士德']!.history, isEmpty);
    expect(state.roles['梅菲斯特']!.history, isEmpty);
    // 角色状态回契约初始值
    expect(state.roles['浮士德']!.currentState['灵魂完整度'], const IntValue(80));
  });

  test('reloadStage 恢复各角色存档', () async {
    final container = await buildContainer();
    final notifier = container.read(stageNarrativeProvider.notifier);

    await notifier.loadStage(stageDir.path);
    await notifier.sendMessage('命运降临');
    await waitForGeneration(container);

    // 重置后恢复
    notifier.resetSession();
    expect(container.read(stageNarrativeProvider).messages, isEmpty);

    final restored = await notifier.restoreStage();
    expect(restored, isTrue);
    final state = container.read(stageNarrativeProvider);
    expect(state.messages, isNotEmpty);
  });

  test('resetSession 清空动态数据保留舞台', () async {
    final container = await buildContainer();
    final notifier = container.read(stageNarrativeProvider.notifier);

    await notifier.loadStage(stageDir.path);
    await notifier.sendMessage('命运降临');
    await waitForGeneration(container);

    notifier.resetSession();
    final state = container.read(stageNarrativeProvider);
    expect(state.stage, isNotNull);
    expect(state.messages, isEmpty);
    expect(state.isGenerating, isFalse);
  });
}
