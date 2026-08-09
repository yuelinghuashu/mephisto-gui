import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/storage/stage_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 舞台目录发现测试
///
/// 约定：契约根目录下的一层子目录 = 多角色舞台，内含 N 份 .meph 角色卡。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_stage_test_');
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('一层子目录含 .meph → 识别为舞台', () async {
    // 舞台目录：群像剧/（含 3 份角色卡）
    final stageDir = Directory('${tempDir.path}/群像剧');
    stageDir.createSync(recursive: true);
    File('${stageDir.path}/浮士德.meph').writeAsStringSync('【角色名】\n浮士德\n');
    File('${stageDir.path}/梅菲斯特.meph').writeAsStringSync('【角色名】\n梅菲斯特\n');
    File('${stageDir.path}/格雷琴.meph').writeAsStringSync('【角色名】\n格雷琴\n');

    final stages = await listStages();
    expect(stages, hasLength(1));
    expect(stages.first.name, '群像剧');
    expect(stages.first.characterCount, 3);
  });

  test('空目录 / 非 .meph 目录 → 不算舞台', () async {
    // 空目录
    Directory('${tempDir.path}/空舞台').createSync(recursive: true);
    // 仅含 .txt 的目录
    final txtDir = Directory('${tempDir.path}/无契约');
    txtDir.createSync(recursive: true);
    File('${txtDir.path}/笔记.txt').writeAsStringSync('hello');

    final stages = await listStages();
    expect(stages, isEmpty);
  });

  test('深层子目录不做递归（仅一层子目录为舞台）', () async {
    // 外层目录看似舞台
    final outer = Directory('${tempDir.path}/外层');
    outer.createSync(recursive: true);
    // 但舞台角色都在更深一层
    Directory('${outer.path}/更内层').createSync(recursive: true);
    File('${outer.path}/更内层/角色.meph').writeAsStringSync('【角色名】\n角色\n');

    final stages = await listStages();
    // 外层目录自身不含 .meph → 不算舞台；深层不递归 → 结果为空
    expect(stages, isEmpty);
  });

  test('多个舞台按路径字典序返回', () async {
    // 建两个舞台：b_stage / a_stage
    for (final name in ['b_stage', 'a_stage']) {
      final dir = Directory('${tempDir.path}/$name');
      dir.createSync(recursive: true);
      File('${dir.path}/角色.meph').writeAsStringSync('【角色名】\n角色\n');
    }

    final stages = await listStages();
    expect(stages, hasLength(2));
    expect(stages.map((s) => s.name).toList(), ['a_stage', 'b_stage']);
  });

  test('isStageDirectory 判定有效舞台', () async {
    final stageDir = Directory('${tempDir.path}/舞台A');
    stageDir.createSync(recursive: true);
    File('${stageDir.path}/角色.meph').writeAsStringSync('【角色名】\n角色\n');

    expect(await isStageDirectory('${tempDir.path}/舞台A'), isTrue);
    expect(await isStageDirectory('${tempDir.path}/不存在'), isFalse);
  });

  test('listStageRoles 列出舞台内角色卡（字典序）', () async {
    final stageDir = Directory('${tempDir.path}/舞台B');
    stageDir.createSync(recursive: true);
    File('${stageDir.path}/b角色.meph').writeAsStringSync('【角色名】\nb\n');
    File('${stageDir.path}/a角色.meph').writeAsStringSync('【角色名】\na\n');
    File('${stageDir.path}/非契约.txt').writeAsStringSync('x');

    final roles = await listStageRoles('${tempDir.path}/舞台B');
    expect(roles, ['a角色.meph', 'b角色.meph']);
    expect(roles, isNot(contains('非契约.txt')));
  });

  test('loadStage 独立解析各角色卡为契约', () async {
    final stageDir = Directory('${tempDir.path}/三重奏');
    stageDir.createSync(recursive: true);
    File('${stageDir.path}/浮士德.meph').writeAsStringSync(
      '【角色名】\n浮士德\n\n【状态】\n- 灵魂完整度：100\n',
    );
    File('${stageDir.path}/梅菲斯特.meph').writeAsStringSync(
      '【角色名】\n梅菲斯特\n\n【状态】\n- 蛊惑值：50\n',
    );

    final loaded = await loadStage('${tempDir.path}/三重奏');
    expect(loaded, isNotNull);
    expect(loaded!.characters, hasLength(2));
    // 不依赖中文码点排序的直觉，按角色名精确定位验证
    final faust =
        loaded.characters.firstWhere((c) => c.roleName == '浮士德');
    final mephisto =
        loaded.characters.firstWhere((c) => c.roleName == '梅菲斯特');
    // 各自状态独立解析（互不污染）
    expect(faust.contract.stateMap['灵魂完整度'], const IntValue(100));
    expect(mephisto.contract.stateMap['蛊惑值'], const IntValue(50));
  });

  test('loadStage 公共世界观取第一个角色（字典序）', () async {
    final stageDir = Directory('${tempDir.path}/世界观测试');
    stageDir.createSync(recursive: true);
    File('${stageDir.path}/a角色.meph').writeAsStringSync(
      '【角色名】\na\n\n【世界观】\n这是一个公共世界。\n',
    );
    File('${stageDir.path}/b角色.meph').writeAsStringSync(
      '【角色名】\nb\n\n【世界观】\n另一个世界。\n',
    );

    final loaded = await loadStage('${tempDir.path}/世界观测试');
    expect(loaded, isNotNull);
    // 字典序第一个角色（a 先于 b）的世界观作公共世界观。
    // 世界观区块保留尾部换行（.meph 区块既有语义），断言用 trim 忽略。
    expect(loaded!.commonWorldview.trim(), '这是一个公共世界。');
    // 每个角色仍保留自己的世界观（不覆盖）
    expect(loaded.characters[1].contract.worldview.trim(), '另一个世界。');
  });

  test('loadStage 角色卡损坏时跳过，其余正常加载', () async {
    final stageDir = Directory('${tempDir.path}/损坏容错');
    stageDir.createSync(recursive: true);
    File('${stageDir.path}/好角色.meph').writeAsStringSync(
      '【角色名】\n完好\n',
    );
    File('${stageDir.path}/坏角色.meph').writeAsStringSync(
      '这不是合法契约【无角色名',
    );

    final loaded = await loadStage('${tempDir.path}/损坏容错');
    expect(loaded, isNotNull);
    expect(loaded!.characters, hasLength(1));
    expect(loaded.characters.first.roleName, '完好');
  });

  test('loadStage 目录不存在或无可用角色 → 返回 null', () async {
    expect(await loadStage('${tempDir.path}/不存在'), isNull);

    final emptyDir = Directory('${tempDir.path}/全坏');
    emptyDir.createSync(recursive: true);
    File('${emptyDir.path}/坏角色.meph').writeAsStringSync('非法内容');
    expect(await loadStage('${tempDir.path}/全坏'), isNull);
  });
}
