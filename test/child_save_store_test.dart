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

  // ============================================================
  // saveCurrent（默认存档）行为
  // ============================================================

  test('saveCurrent 从母版首次保存生成 faust.child.meph', () async {
    final fileName = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.meph',
      contract: contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(fileName, 'faust.child.meph');
  });

  test('saveCurrent 从母版重复开始自动递增 child2 / child3', () async {
    // 模拟「每轮从首页打开母版重新游玩」→ 每次都应生成新的递增存档
    final first = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.meph',
      contract: contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    final second = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.meph',
      contract: contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    final third = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.meph',
      contract: contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(first, 'faust.child.meph');
    expect(second, 'faust.child2.meph');
    expect(third, 'faust.child3.meph');
  });

  test('saveCurrent 打开的存档自身持续覆盖不递增', () async {
    // 首次从母版开始 → 自动生成 child.meph
    final first = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.meph',
      contract: contract,
      currentState: const {'灵魂完整度': IntValue(50)},
      memories: const [],
      history: const [],
    );
    expect(first, 'faust.child.meph');

    // 在 child.meph 内继续对话 → 覆盖自己，不产生 child2
    final second = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.child.meph',
      contract: contract,
      currentState: const {'灵魂完整度': IntValue(40)},
      memories: const [],
      history: const [],
    );
    expect(second, 'faust.child.meph');
    expect(File('${tempDir.path}/faust.child2.meph').existsSync(), isFalse);

    // child2 存档内继续对话 → 覆盖 child2 自己
    final third = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.child2.meph',
      contract: contract,
      currentState: const {'灵魂完整度': IntValue(30)},
      memories: const [],
      history: const [],
    );
    expect(third, 'faust.child2.meph');
    expect(File('${tempDir.path}/faust.child.meph').existsSync(), isTrue);
    expect(File('${tempDir.path}/faust.child2.meph').existsSync(), isTrue);
  });

  test('saveCurrent 分支拥有独立存档且各自递增', () async {
    // 母版分支 dark：首次保存 → faust.dark.child.meph
    final darkFirst = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.dark.meph',
      contract: contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(darkFirst, 'faust.dark.child.meph');

    // 再次从 dark 分支重新开始 → faust.dark.child2.meph
    final darkSecond = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.dark.meph',
      contract: contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(darkSecond, 'faust.dark.child2.meph');

    // dark 存档内继续 → 覆盖自己
    final darkInSession = await ChildSaveStore.saveCurrent(
      sourceFileName: 'faust.dark.child2.meph',
      contract: contract,
      currentState: const {},
      memories: const [],
      history: const [],
    );
    expect(darkInSession, 'faust.dark.child2.meph');
    expect(File('${tempDir.path}/faust.dark.child3.meph').existsSync(), isFalse);
  });
}
