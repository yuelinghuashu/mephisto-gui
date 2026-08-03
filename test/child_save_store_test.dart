import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/session/child_save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ChildSaveStore 子版存档存储测试
///
/// 通过 SharedPreferences 覆盖契约目录到临时目录，
/// 验证文件的实际保存/恢复/列表/删除。
void main() {
  late Directory tempDir;

  setUp(() async {
    // 创建临时目录作为契约目录
    tempDir = await Directory.systemTemp.createTemp('mephisto_test_');
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  const masterFileName = 'faust.meph';
  const contract = Contract(
    roleName: '浮士德',
    worldview: '充满契约的世界',
    background: '求道者',
    state: [
      StateItem(key: '灵魂完整度', value: IntValue(50)),
    ],
  );

  test('保存默认子版生成 faust.child.meph', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {'灵魂完整度': IntValue(40)},
      memories: const [],
      history: const [],
    );
    expect(fileName, 'faust.child.meph');
    final file = File('${tempDir.path}/$fileName');
    expect(file.existsSync(), isTrue);
  });

  test('同母版重复保存自动递增文件名', () async {
    final first = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    final second = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    final third = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(first, 'faust.child.meph');
    expect(second, 'faust.child2.meph');
    expect(third, 'faust.child3.meph');
  });

  test('自定义分支生成 faust.<分支名>.meph', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
      branchName: 'dark',
    );
    expect(fileName, 'faust.dark.meph');
    expect(File('${tempDir.path}/$fileName').existsSync(), isTrue);
  });

  test('overwriteFileName 直接覆盖指定文件', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {'灵魂完整度': IntValue(30)},
      memories: const [],
      history: const [],
      overwriteFileName: 'faust.special.meph',
    );
    expect(fileName, 'faust.special.meph');
    // 再次覆盖同一个文件，不递增
    final again = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {'灵魂完整度': IntValue(20)},
      memories: const [],
      history: const [],
      overwriteFileName: 'faust.special.meph',
    );
    expect(again, 'faust.special.meph');
  });

  test('子版内容包含运行时状态与记忆', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {'灵魂完整度': IntValue(25)},
      memories: [Memory(content: '契约定下')],
      history: const [
        HistoryEntry(role: MessageRole.fate, content: '继续前行'),
        HistoryEntry(role: MessageRole.assistant, content: '浮士德沉默'),
      ],
    );
    final restored = await ChildSaveStore.restore(fileName);
    expect(restored, isNotNull);
    expect(restored!.roleName, '浮士德');
    expect(restored.stateMap['灵魂完整度'], const IntValue(25));
    expect(restored.memories.first.content, '契约定下');
    expect(restored.history.length, 2);
  });

  test('restore 不存在的文件返回 null', () async {
    final restored = await ChildSaveStore.restore('nope.meph');
    expect(restored, isNull);
  });

  test('列出所有子版文件', () async {
    await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
      branchName: 'dark',
    );
    final children = await ChildSaveStore.listChildFiles(masterFileName);
    expect(children, contains('faust.child.meph'));
    expect(children, contains('faust.dark.meph'));
    expect(children, isNot(contains('faust.meph')));
  });

  test('delete 删除子版文件', () async {
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(await ChildSaveStore.exists(fileName), isTrue);
    expect(await ChildSaveStore.delete(fileName), isTrue);
    expect(await ChildSaveStore.exists(fileName), isFalse);
    // 重复删除返回 false
    expect(await ChildSaveStore.delete(fileName), isFalse);
  });

  test('exists 检查文件是否存在', () async {
    expect(await ChildSaveStore.exists('noexist.meph'), isFalse);
    final fileName = await ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(await ChildSaveStore.exists(fileName), isTrue);
  });
}