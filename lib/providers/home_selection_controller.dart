import 'package:flutter/foundation.dart';

import 'contract_provider.dart';

/// 首页多选/展开状态控制器
///
/// 将 [HomeScreen] State 中的多选状态与契约树展开状态抽离为独立的
/// [ChangeNotifier]，使状态逻辑可脱离 Widget 独立单元测试。
///
/// 职责范围：
///   - 多选模式开关（_isSelectMode）
///   - 选中契约文件名集合（_selected）
///   - 契约树展开状态（_expandedGroups）
///
/// 不包含文件操作（删除/导入/重命名等），那些仍依赖 UI 上下文
/// （ScaffoldMessenger / Navigator / ref），由 State 桥接。
class HomeSelectionController extends ChangeNotifier {
  /// 多选模式下选中的契约文件名
  final Set<String> _selected = {};

  /// 是否为多选模式
  bool _isSelectMode = false;

  /// 已展开节点的文件名集合（含所有层级，点击展开/收起）
  final Set<String> _expandedGroups = {};

  // ============================================================
  // 只读状态（供 UI 读取）
  // ============================================================

  /// 选中的契约文件名集合（只读视角）
  Set<String> get selected => Set.unmodifiable(_selected);

  /// 选中数量
  int get selectedCount => _selected.length;

  /// 是否为多选模式
  bool get isSelectMode => _isSelectMode;

  /// 已展开节点的文件名集合（只读视角）
  Set<String> get expandedGroups => Set.unmodifiable(_expandedGroups);

  /// 指定文件名是否被选中
  bool isSelected(String fileName) => _selected.contains(fileName);

  // ============================================================
  // 多选操作
  // ============================================================

  /// 进入多选模式，并选中指定节点（可级联选中其整棵子树）。
  ///
  /// 参数：
  ///   - fileName: 长按的节点文件名
  ///   - cascadeNames: 长按节点时一并选中的子树文件名（递归）
  ///   - expandNodes: 进入多选时自动展开的节点（使级联选中的节点立即可见）
  void enterSelectMode(
    String fileName, {
    List<String> cascadeNames = const [],
    List<String>? expandNodes,
  }) {
    _isSelectMode = true;
    _selected.add(fileName);
    _selected.addAll(cascadeNames);
    if (expandNodes != null) {
      _expandedGroups.addAll(expandNodes);
    }
    notifyListeners();
  }

  /// 切换单个节点的选中状态（不联动子树）。
  void toggleSelect(String fileName) {
    if (_selected.contains(fileName)) {
      _selected.remove(fileName);
      // 取消最后一个选中时自动退出多选
      if (_selected.isEmpty) _isSelectMode = false;
    } else {
      // 选中节点 → 确保进入多选模式（不依赖调用方前置状态）
      _isSelectMode = true;
      _selected.add(fileName);
    }
    notifyListeners();
  }

  /// 切换某节点的选中状态（级联联动其整棵子树）。
  void toggleSelectSubtree(ContractGroup group) {
    final subtreeNames = group.allInfos.map((i) => i.fileName).toSet();
    final masterName = group.master.fileName;

    if (_selected.contains(masterName)) {
      // 取消节点 → 同时取消其下整棵子树
      _selected.removeAll(subtreeNames);
      if (_selected.isEmpty) _isSelectMode = false;
    } else {
      // 选中节点 → 确保进入多选模式，同时选中其下整棵子树
      _isSelectMode = true;
      _selected.addAll(subtreeNames);
    }
    notifyListeners();
  }

  /// 退出多选模式
  void exitSelectMode() {
    _isSelectMode = false;
    _selected.clear();
    notifyListeners();
  }

  /// 全选所有契约（含所有层级子节点）。
  void selectAll(List<ContractGroup> groups) {
    for (final group in groups) {
      _selected.addAll(group.allInfos.map((i) => i.fileName));
    }
    notifyListeners();
  }

  // ============================================================
  // 契约树展开操作
  // ============================================================

  /// 切换某节点的展开/收起
  void toggleChildrenExpanded(String fileName) {
    if (_expandedGroups.contains(fileName)) {
      _expandedGroups.remove(fileName);
    } else {
      _expandedGroups.add(fileName);
    }
    notifyListeners();
  }
}