import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/session/child_save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ChildSaveStore 舞台目录存档测试
///
/// 验证 [ChildSaveStore] / [SessionSaver] 支持写入舞台子目录的能力：
///   - targetDir 保存到舞台目录（舞台/角色.child.meph）
///   - restore / listChildFiles / exists / delete 支持 dirPath
///   - 未传 targetDir / dirPath 时回落全局契约目录（向后兼容）
void main() {
  late Directory tempDir;
  late Directory stageDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_stage_test_');
    stageDir = Directory('${tempDir.path}/舞台');
    await stageDir.create(recursive: true);
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  const masterFileName = '浮士德.meph';
  const contract = Contract(
    roleName: '浮士德',
    worldview: '充满契约的世界',
    state: [StateItem(key: '灵魂完整度', value: IntValue(50))],
  );

  test('targetDir 保存到舞台目录', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {'灵魂完整度': IntValue(40)},
      memories: const [],
      history: const [],
      targetDir: stageDir,
    );
    expect(fileName, '浮士德.child.meph');
    // 舞台目录中生成，全局契约目录中没有
    expect(File('${stageDir.path}/$fileName').existsSync(), isTrue);
    expect(File('${tempDir.path}/$fileName').existsSync(), isFalse);
  });

  test('restore 支持 dirPath 从舞台目录恢复', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {'灵魂完整度': IntValue(30)},
      memories: [Memory(content: '舞台事件')],
      history: const [
        HistoryEntry(role: MessageRole.fate, content: '继续'),
        HistoryEntry(role: MessageRole.assistant, content: '梅菲斯特低语'),
      ],
      targetDir: stageDir,
    );
    final restored = await ChildSaveStore.restore(
      fileName,
      dirPath: stageDir.path,
    );
    expect(restored, isNotNull);
    expect(restored!.stateMap['灵魂完整度'], const IntValue(30));
    expect(restored.memories.first.content, '舞台事件');
    expect(restored.history.length, 2);

    // 不带 dirPath（全局目录）恢复返回 null
    expect(await ChildSaveStore.restore(fileName), isNull);
  });

  test('listChildFiles / exists / delete 支持舞台目录', () async {
    await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
      targetDir: stageDir,
    );
    await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
      branchName: 'dark',
      targetDir: stageDir,
    );

    final children = await ChildSaveStore.listChildFiles(
      masterFileName,
      dirPath: stageDir.path,
    );
    expect(children, contains('浮士德.child.meph'));
    expect(children, contains('浮士德.dark.meph'));

    expect(
      await ChildSaveStore.exists('浮士德.child.meph', dirPath: stageDir.path),
      isTrue,
    );
    expect(await ChildSaveStore.exists('浮士德.child.meph'), isFalse);

    expect(
      await ChildSaveStore.delete('浮士德.child.meph', dirPath: stageDir.path),
      isTrue,
    );
    expect(
      await ChildSaveStore.exists('浮士德.child.meph', dirPath: stageDir.path),
      isFalse,
    );
  });

  test('未传 targetDir 时仍写全局契约目录（向后兼容）', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(fileName, '浮士德.child.meph');
    expect(File('${tempDir.path}/$fileName').existsSync(), isTrue);
  });
}
