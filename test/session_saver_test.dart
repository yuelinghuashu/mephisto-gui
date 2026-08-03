import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/session/child_save_store.dart';
import 'package:mephisto/services/session/session_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SessionSaver 存档服务单测
///
/// 覆盖「当前文件子版覆盖 / 母版 .child 递增」「另存为分支以母版前缀命名」
/// 以及快照序列化完整性，验证从 [NarrativeNotifier] 下沉的存档决策逻辑。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const contract = Contract(
    roleName: '浮士德',
    worldview: '充满契约的世界',
    state: [StateItem(key: '灵魂完整度', value: IntValue(50))],
  );

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_saver_test_');
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });
    // 仅写入母版；默认子版由 saveCurrent(母版) 生成，测试保持干净状态
    await File('${tempDir.path}/faust.meph').writeAsString(
      '【角色名】\n浮士德\n',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  const currentState = {'灵魂完整度': IntValue(70)};
  final memories = [Memory(content: '与梅菲斯特立下契约')];
  final history = [
    const HistoryEntry(role: MessageRole.fate, content: '继续前行'),
    const HistoryEntry(role: MessageRole.assistant, content: '浮士德沉默着。'),
  ];

  group('SessionSaver.saveCurrent', () {
    test('母版文件名 → 生成 .child 子版', () async {
      expect(File('${tempDir.path}/faust.child.meph').existsSync(), isFalse);
      final saved = await SessionSaver.saveCurrent(
        sourceFileName: 'faust.meph',
        contract: contract,
        currentState: currentState,
        memories: memories,
        history: history,
      );

      expect(saved, 'faust.child.meph');
      expect(File('${tempDir.path}/faust.child.meph').existsSync(), isTrue);
      // 不应生成递增文件
      expect(File('${tempDir.path}/faust.child2.meph').existsSync(), isFalse);
    });

    test('子版文件名 → 直接覆盖原文件而非生成递增新文件', () async {
      // 先存在默认子版，验证 saveCurrent 覆盖而非递增
      await File('${tempDir.path}/faust.child.meph').writeAsString(
        '【角色名】\n浮士德\n',
      );
      final saved = await SessionSaver.saveCurrent(
        sourceFileName: 'faust.child.meph',
        contract: contract,
        currentState: currentState,
        memories: memories,
        history: history,
      );

      expect(saved, 'faust.child.meph');
      expect(File('${tempDir.path}/faust.child2.meph').existsSync(), isFalse);
    });

    test('快照序列化完整性：保存含状态/记忆/历史的快照后可完整恢复', () async {
      await SessionSaver.saveCurrent(
        sourceFileName: 'faust.meph',
        contract: contract,
        currentState: currentState,
        memories: memories,
        history: history,
      );

      final restored = await ChildSaveStore.restore('faust.child.meph');
      expect(restored, isNotNull);
      // 运行时状态写回
      expect(restored!.stateMap['灵魂完整度'], const IntValue(70));
      // 记忆写回
      expect(restored.memories.map((m) => m.content), contains('与梅菲斯特立下契约'));
      // 历史写回
      expect(restored.history, hasLength(2));
      expect(restored.history.first.role, MessageRole.fate);
      expect(restored.history.first.content, '继续前行');
    });
  });

  group('SessionSaver.saveAsBranch', () {
    test('从母版另存为分支 → faust.<分支名>.meph', () async {
      final saved = await SessionSaver.saveAsBranch(
        sourceFileName: 'faust.meph',
        branchName: 'dark',
        contract: contract,
        currentState: currentState,
        memories: memories,
        history: history,
      );

      expect(saved, 'faust.dark.meph');
      expect(File('${tempDir.path}/faust.dark.meph').existsSync(), isTrue);
    });

    test('从子版另存为分支 → 以母版前缀命名，不产生 child.dark', () async {
      // 先存在默认子版，验证其不受另存为分支影响
      await File('${tempDir.path}/faust.child.meph').writeAsString(
        '【角色名】\n浮士德\n',
      );
      final saved = await SessionSaver.saveAsBranch(
        sourceFileName: 'faust.child.meph',
        branchName: 'dark',
        contract: contract,
        currentState: currentState,
        memories: memories,
        history: history,
      );

      expect(saved, 'faust.dark.meph');
      expect(File('${tempDir.path}/faust.dark.meph').existsSync(), isTrue);
      // 不应产生以 child 为前缀的分支文件
      expect(File('${tempDir.path}/child.dark.meph').existsSync(), isFalse);
      // 原 child 文件不受影响
      expect(File('${tempDir.path}/faust.child.meph').existsSync(), isTrue);
    });
  });
}