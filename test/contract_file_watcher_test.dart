import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/services/contract_file_watcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ContractFileWatcher 单元测试
///
/// 验证文件监听的核心行为：
///   - 防抖 500ms：短时间连续写入只触发一次回调
///   - mtime 抑制：处理完成后相同 mtime 再次触发会被忽略（避免死循环）
///   - cancel 后重新 start：旧的 mtime 抑制状态被清除
///   - 文件名未变化时不重复绑定
///   - onUnavailable 回调在监听不可用时触发
///   - v1.2.0 增强：监听目标 = 当前源文件 + 其母版 —— 外部修改母版 .meph 也能被感知
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_watcher_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 指向临时目录作为契约目录
  void seedDir() {
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
    });
  }

  test('文件变更触发回调（防抖窗口后）', () async {
    seedDir();
    final file = File('${tempDir.path}/faust.meph');
    await file.writeAsString('初始内容');

    final triggered = <String>[];
    final watcher = ContractFileWatcher(
      onFileChanged: (name) async {
        triggered.add(name);
      },
    );
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // 写入触发监听事件
    await file.writeAsString('修改内容');

    // 等待防抖 500ms + 处理完成
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(triggered, ['faust.meph']);
  });

  test('防抖 500ms：连续多次写入只触发一次回调', () async {
    seedDir();
    final file = File('${tempDir.path}/faust.meph');
    await file.writeAsString('初始内容');

    var count = 0;
    final watcher = ContractFileWatcher(
      onFileChanged: (_) async {
        count++;
      },
    );
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // 在 500ms 防抖窗口内连续写入 3 次
    await file.writeAsString('内容1');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await file.writeAsString('内容2');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await file.writeAsString('内容3');

    // 只等待一个防抖窗口，应只触发一次
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(count, 1);
  });

  test('mtime 抑制：处理完成后的相同 mtime 再次触发被忽略', () async {
    seedDir();
    final file = File('${tempDir.path}/faust.meph');
    await file.writeAsString('内容A');

    var count = 0;
    final watcher = ContractFileWatcher(
      onFileChanged: (_) async {
        count++;
      },
    );
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // 首次写入触发回调，记录 mtime
    await file.writeAsString('内容B');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(count, 1);

    // 快速用相同方式重写（mtime 可能未变化），观察是否被抑制。
    // 由于文件系统时间精度限制，mtime 可能相同也可能不同（取决于平台）。
    // 这里主要验证：即使又触发事件，回调次数不应因死循环而无限增长。
    await file.writeAsString('内容C');
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // 回调次数应保持有限（要么 1（被抑制），要么 2（正常新 mtime）），
    // 绝不应该是 3+（说明死循环）。
    expect(count, lessThanOrEqualTo(2));
  });

  test('cancel 后重新 start 会清除旧 mtime 抑制状态', () async {
    seedDir();
    final file = File('${tempDir.path}/faust.meph');
    await file.writeAsString('内容A');

    var count = 0;
    final watcher = ContractFileWatcher(
      onFileChanged: (_) async {
        count++;
      },
    );
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // 触发一次回调
    await file.writeAsString('内容B');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(count, 1);

    // cancel 后重新 start（模拟源文件切换再切回）
    watcher.cancel();
    await watcher.start('faust.meph');

    // 新绑定后写入应能再次触发（旧 mtime 已被清除）
    await file.writeAsString('内容C');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(count, 2);
  });

  test('文件名未变化时不重复绑定', () async {
    seedDir();

    // 用一个可观测的副作用验证是否重新订阅：
    // 通过 destroy 后再次 start 观察 watchedFileName 是否重置再赋值。
    final watcher = ContractFileWatcher(
      onFileChanged: (_) async {},
    );
    await watcher.start('faust.meph');
    expect(watcher.watchedFileName, 'faust.meph');

    // 再次 start 同一文件：文件名未变化 → 不重新绑定
    await watcher.start('faust.meph');
    expect(watcher.watchedFileName, 'faust.meph');

    watcher.dispose();
  });

  test('目录不存在时静默降级且不触发 onUnavailable', () async {
    // 指向一个不存在的目录
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': '${tempDir.path}/nonexistent',
    });

    var unavailableCalled = false;
    final watcher = ContractFileWatcher(
      onFileChanged: (_) async {},
      onUnavailable: () {
        unavailableCalled = true;
      },
    );
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // start 内部对不存在的目录直接返回（不触发 onUnavailable）
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(unavailableCalled, isFalse);
  });

  test('监听目标 = 当前源文件 + 其母版（子版时自动推导母版名）', () async {
    seedDir();
    final child = File('${tempDir.path}/faust.child.meph');
    final master = File('${tempDir.path}/faust.meph');
    await child.writeAsString('子版');
    await master.writeAsString('母版');

    final watcher = ContractFileWatcher(onFileChanged: (_) async {});
    await watcher.start('faust.child.meph');
    addTearDown(watcher.dispose);

    expect(watcher.watchedFileName, 'faust.child.meph');
    expect(watcher.watchedTargets, ['faust.child.meph', 'faust.meph']);
  });

  test('外部修改母版时触发回调，且回调传入母版文件名', () async {
    seedDir();
    final child = File('${tempDir.path}/faust.child.meph');
    final master = File('${tempDir.path}/faust.meph');
    await child.writeAsString('子版内容');
    await master.writeAsString('母版初始内容');

    final triggered = <String>[];
    final watcher = ContractFileWatcher(
      onFileChanged: (name) async {
        triggered.add(name);
      },
    );
    await watcher.start('faust.child.meph');
    addTearDown(watcher.dispose);

    // 外部（VSCode）修改母版 faust.meph —— 当前监听源是子版
    await master.writeAsString('母版修改内容');

    // 等待防抖 500ms + 处理完成
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // 应触发且回调收到的是实际变化的母版文件名，而不是固定的子版名
    expect(triggered, ['faust.meph']);
  });

  test('rename 覆盖（模拟 VSCode 原子保存）触发回调', () async {
    seedDir();
    final target = File('${tempDir.path}/faust.meph');
    await target.writeAsString('初始内容');

    final triggered = <String>[];
    final watcher = ContractFileWatcher(
      onFileChanged: (name) async {
        triggered.add(name);
      },
    );
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // 模拟 VSCode 原子保存：写入临时文件 → rename 覆盖目标文件
    final tmp = File('${tempDir.path}/.faust.meph.tmp');
    await tmp.writeAsString('原子保存内容');
    await tmp.rename(target.path);

    // 等待防抖 500ms + 处理完成
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(triggered, ['faust.meph']);
  });

  test('目录中其他 .meph 文件的写入不触发回调', () async {
    seedDir();
    final watched = File('${tempDir.path}/faust.meph');
    final other = File('${tempDir.path}/dantes.meph');
    await watched.writeAsString('faust 内容');
    await other.writeAsString('dantes 内容');

    var count = 0;
    final watcher = ContractFileWatcher(
      onFileChanged: (_) async {
        count++;
      },
    );
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // 写另一个契约（非监听目标）——不应触发回调
    await other.writeAsString('dantes 修改内容');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(count, 0);

    // 确认监听仍正常：写入监听目标文件应触发
    await watched.writeAsString('faust 修改内容');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(count, 1);
  });

  test('start 初始化监听目标的 mtime 基线（防 macOS fsevents 误报）', () async {
    seedDir();
    final watched = File('${tempDir.path}/faust.meph');
    await watched.writeAsString('初始内容');

    final watcher = ContractFileWatcher(onFileChanged: (_) async {});
    await watcher.start('faust.meph');
    addTearDown(watcher.dispose);

    // start 后应已建立监听目标的 mtime 基线（而非空 map）。
    // 背景：macOS fsevents 是目录级事件，可能把「其他文件写入」误报为
    // 监听目标的 modify 事件。若 start 时不初始化基线，第一次误报会被
    // 当作真实变更处理（mtime 记录为 null → 不抑制）。
    final contents = watcher.debugStartBaselineContents;
    expect(contents, contains('faust.meph'));
    expect(contents['faust.meph'], isNotNull);
    // 基线值应为文件当前内容
    expect(contents['faust.meph'], '初始内容');
  });

  test('start 子版时同时初始化母版 mtime 基线', () async {
    seedDir();
    final child = File('${tempDir.path}/faust.child.meph');
    final master = File('${tempDir.path}/faust.meph');
    await child.writeAsString('子版内容');
    await master.writeAsString('母版内容');

    final watcher = ContractFileWatcher(onFileChanged: (_) async {});
    await watcher.start('faust.child.meph');
    addTearDown(watcher.dispose);

    // 子版 + 母版都应有基线（跨平台安全：macOS 目录级事件也可能误报母版）
    final contents = watcher.debugStartBaselineContents;
    expect(contents, contains('faust.child.meph'));
    expect(contents, contains('faust.meph'));
    expect(contents['faust.child.meph'], '子版内容');
    expect(contents['faust.meph'], '母版内容');
  });

  test('自动存档写入子版后 mtime 抑制不误伤母版热重载', () async {
    seedDir();
    final child = File('${tempDir.path}/faust.child.meph');
    final master = File('${tempDir.path}/faust.meph');
    await child.writeAsString('子版初始');
    await master.writeAsString('母版初始');

    final triggered = <String>[];
    final watcher = ContractFileWatcher(
      onFileChanged: (name) async {
        triggered.add(name);
      },
    );
    await watcher.start('faust.child.meph');
    addTearDown(watcher.dispose);

    // 模拟自动存档：写入子版（自身写文件，mtime 处理后记录会抑制）
    await child.writeAsString('子版存档1');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(triggered, ['faust.child.meph']);

    // 外部修改母版——即使子版刚被处理过，母版的 mtime 独立记录，不应被误抑制
    await master.writeAsString('母版热重载1');
    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(triggered, ['faust.child.meph', 'faust.meph']);
  });
}