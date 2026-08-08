import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/providers/contract_provider.dart';
import 'package:mephisto/providers/home_selection_controller.dart';

/// [HomeSelectionController] 多选/展开状态控制器测试
///
/// 验证：
///   - 进入多选模式 + 级联选中子树
///   - 单个节点切换选中（最后一个取消时自动退出多选）
///   - 子树级联切换（取消母版 → 取消整棵子树）
///   - 全选/取消全选
///   - 契约树展开/收起状态切换
///   - 只读视角（无法从外部修改控制器内部状态）
void main() {
  // 辅助：构建三级契约树
  ContractInfo info(
    String fileName, {
    String roleName = '角色',
    bool isChild = false,
  }) {
    return ContractInfo(
      fileName: fileName,
      roleName: roleName,
      isChild: isChild,
    );
  }

  ContractGroup treeGroup({
    required ContractInfo master,
    List<ContractGroup> children = const [],
  }) {
    return ContractGroup(master: master, children: children);
  }

  group('进入多选 + 级联选中', () {
    test('enterSelectMode 进入多选并选中节点', () {
      final controller = HomeSelectionController();

      controller.enterSelectMode('faust.meph');

      expect(controller.isSelectMode, isTrue);
      expect(controller.isSelected('faust.meph'), isTrue);
      expect(controller.selectedCount, 1);
    });

    test('enterSelectMode 级联选中子树 + 自动展开子节点', () {
      final controller = HomeSelectionController();

      controller.enterSelectMode(
        'faust.meph',
        cascadeNames: ['faust.dark.meph', 'faust.dark.light.meph'],
        expandNodes: ['faust.dark.meph'],
      );

      expect(controller.isSelected('faust.meph'), isTrue);
      expect(controller.isSelected('faust.dark.meph'), isTrue);
      expect(controller.isSelected('faust.dark.light.meph'), isTrue);
      expect(controller.expandedGroups.contains('faust.dark.meph'), isTrue);
    });
  });

  group('单节点切换', () {
    test('toggleSelect 切换选中/取消', () {
      final controller = HomeSelectionController();
      controller.enterSelectMode('faust.meph');

      controller.toggleSelect('faust.meph');
      expect(controller.isSelected('faust.meph'), isFalse);
      // 最后一个取消 → 自动退出多选
      expect(controller.isSelectMode, isFalse);
    });

    test('切换选中另一个节点不退出多选', () {
      final controller = HomeSelectionController();
      controller.enterSelectMode('faust.meph');

      controller.toggleSelect('faust.dark.meph');
      expect(controller.isSelectMode, isTrue);
      expect(controller.isSelected('faust.dark.meph'), isTrue);
      expect(controller.selectedCount, 2);
    });
  });

  group('子树级联切换', () {
    test('选中母版 → 级联选中整棵子树', () {
      final controller = HomeSelectionController();
      final tree = treeGroup(
        master: info('faust.meph'),
        children: [
          treeGroup(
            master: info('faust.dark.meph', isChild: true),
            children: [
              treeGroup(master: info('faust.dark.light.meph', isChild: true)),
            ],
          ),
        ],
      );

      controller.toggleSelectSubtree(tree);

      expect(controller.isSelected('faust.meph'), isTrue);
      expect(controller.isSelected('faust.dark.meph'), isTrue);
      expect(controller.isSelected('faust.dark.light.meph'), isTrue);
    });

    test('取消母版 → 取消整棵子树并保持多选模式（若还有其他选中）', () {
      final controller = HomeSelectionController();
      final tree = treeGroup(
        master: info('faust.meph'),
        children: [
          treeGroup(master: info('faust.dark.meph', isChild: true)),
        ],
      );

      // 先选整棵子树，再额外选中另一个文件
      controller.toggleSelectSubtree(tree);
      controller.toggleSelect('other.meph');

      // 取消母版 → 取消子树所有文件
      controller.toggleSelectSubtree(tree);
      expect(controller.isSelected('faust.meph'), isFalse);
      expect(controller.isSelected('faust.dark.meph'), isFalse);
      // 其他文件仍在选 → 多选模式保持
      expect(controller.isSelected('other.meph'), isTrue);
      expect(controller.isSelectMode, isTrue);
    });
  });

  group('全选 + 退出', () {
    test('selectAll 全选所有契约（含递归子节点）', () {
      final controller = HomeSelectionController();
      final trees = [
        treeGroup(
          master: info('faust.meph'),
          children: [treeGroup(master: info('faust.dark.meph'))],
        ),
        treeGroup(master: info('dantes.meph')),
      ];

      controller.selectAll(trees);

      expect(controller.selectedCount, 3);
      expect(controller.isSelected('faust.meph'), isTrue);
      expect(controller.isSelected('faust.dark.meph'), isTrue);
      expect(controller.isSelected('dantes.meph'), isTrue);
    });

    test('exitSelectMode 清空选中并退出多选', () {
      final controller = HomeSelectionController();
      controller.enterSelectMode('faust.meph');

      controller.exitSelectMode();

      expect(controller.isSelectMode, isFalse);
      expect(controller.selectedCount, 0);
    });
  });

  group('契约树展开状态', () {
    test('toggleChildrenExpanded 切换展开/收起', () {
      final controller = HomeSelectionController();

      controller.toggleChildrenExpanded('faust.meph');
      expect(controller.expandedGroups.contains('faust.meph'), isTrue);

      controller.toggleChildrenExpanded('faust.meph');
      expect(controller.expandedGroups.contains('faust.meph'), isFalse);
    });
  });

  group('只读视角', () {
    test('返回的 selected 集合不可变（无法从外部修改）', () {
      final controller = HomeSelectionController();
      controller.enterSelectMode('faust.meph');

      // 尝试从外部修改只读视角
      expect(
        () => controller.selected.add('hack.meph'),
        throwsUnsupportedError,
      );
      expect(controller.selectedCount, 1);
    });
  });
}