import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/services/storage/meph_file_name.dart';

/// .meph 文件名解析共享工具测试
///
/// 命名规则是多级命运树 + 存档系统的数据安全核心：
///   - `faust.meph`               → [faust]（母版根）
///   - `faust.dark.meph`          → [faust, dark]（一级分支）
///   - `faust.dark.light.meph`    → [faust, dark, light]（二级分支）
///   - `faust.child.meph`         → [faust, child]（默认存档）
///
/// 这些函数被存档保存/恢复、级联重命名/删除、首页树构建多处依赖，
/// 任何一处解析偏差都会导致存档定位错误（数据丢失风险），因此独立成测。
void main() {
  group('splitBaseName / 层级', () {
    test('基础名去 .meph 后按 . 分段', () {
      expect(splitBaseName('faust.meph'), ['faust']);
      expect(splitBaseName('faust.dark.meph'), ['faust', 'dark']);
      expect(splitBaseName('faust.dark.light.meph'),
          ['faust', 'dark', 'light']);
      expect(splitBaseName('faust.child.meph'), ['faust', 'child']);
    });

    test('fileNameDepth：母版根为 0，逐级 +1', () {
      expect(fileNameDepth('faust.meph'), 0);
      expect(fileNameDepth('faust.dark.meph'), 1);
      expect(fileNameDepth('faust.dark.light.meph'), 2);
      expect(fileNameDepth('faust.child.meph'), 1);
    });
  });

  group('isChildFileName / extractMasterPrefix', () {
    test('母版根不是子版，其余都是', () {
      expect(isChildFileName('faust.meph'), isFalse);
      expect(isChildFileName('faust.dark.meph'), isTrue);
      expect(isChildFileName('faust.child.meph'), isTrue);
    });

    test('extractMasterPrefix 恒取第一段', () {
      expect(extractMasterPrefix('faust.meph'), 'faust');
      expect(extractMasterPrefix('faust.dark.light.meph'), 'faust');
      expect(extractMasterPrefix('joan_of_arc.meph'), 'joan_of_arc');
    });
  });

  group('extractBranchName / extractBranchPath', () {
    test('母版根无分支名 / 分支路径', () {
      expect(extractBranchName('faust.meph'), isNull);
      expect(extractBranchPath('faust.meph'), isNull);
    });

    test('一级分支：分支名 = 最后一段，分支路径 = 第一段', () {
      expect(extractBranchName('faust.dark.meph'), 'dark');
      expect(extractBranchPath('faust.dark.meph'), 'faust');
    });

    test('多级分支：分支路径为去掉最后一段的完整前缀', () {
      expect(extractBranchName('faust.dark.light.meph'), 'light');
      expect(extractBranchPath('faust.dark.light.meph'), 'faust.dark');
    });

    test('存档名分支名按最后一段取（child）', () {
      expect(extractBranchName('faust.child.meph'), 'child');
      expect(extractBranchPath('faust.dark.child.meph'), 'faust.dark');
    });
  });

  group('stripChildSuffix（当前分支路径）', () {
    test('去掉 .child 存档尾段', () {
      expect(stripChildSuffix('faust.meph'), 'faust');
      expect(stripChildSuffix('faust.dark.meph'), 'faust.dark');
      // .child 是存档后缀，非分支
      expect(stripChildSuffix('faust.child.meph'), 'faust');
      expect(stripChildSuffix('faust.dark.child.meph'), 'faust.dark');
      // 存档自身再保留层级前缀
      expect(stripChildSuffix('faust.dark.light.child.meph'),
          'faust.dark.light');
    });

    test('不含 .child 时原样返回基础名', () {
      expect(stripChildSuffix('faust.meph'), 'faust');
      expect(stripChildSuffix('faust.dark.light.meph'), 'faust.dark.light');
    });
  });

  group('defaultChildFileName（默认存档名）', () {
    test('母版 → 母版.child.meph', () {
      expect(defaultChildFileName('faust.meph'), 'faust.child.meph');
    });

    test('分支 → 分支.child.meph（非母版根）', () {
      expect(defaultChildFileName('faust.dark.meph'), 'faust.dark.child.meph');
      expect(
          defaultChildFileName('faust.dark.light.meph'),
          'faust.dark.light.child.meph');
    });

    test('存档自身 → 不再追加 .child（防 child.child 嵌套）', () {
      expect(
          defaultChildFileName('faust.dark.child.meph'),
          'faust.dark.child.meph',
          reason: '已是存档则返回自身，避免生成 faust.dark.child.child.meph');
    });

    test('中文/带下划线文件名兼容', () {
      expect(defaultChildFileName('浮士德.meph'), '浮士德.child.meph');
      expect(
          defaultChildFileName('joan_of_arc.meph'),
          'joan_of_arc.child.meph');
    });
  });

  group('defaultChildSuffix 常量', () {
    test('与存档命名规则一致', () {
      expect(defaultChildSuffix, '.child');
    });
  });
}
