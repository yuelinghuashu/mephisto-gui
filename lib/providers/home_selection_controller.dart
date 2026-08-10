import 'package:flutter/foundation.dart';

import 'contract_provider.dart';

/// 首页多选/展开状态控制器
///
/// 将 [HomeScreen] State 中的多选状态与契约树/舞台展开状态抽离为独立的
/// [ChangeNotifier]，使状态逻辑可脱离 Widget 独立单元测试。
///
/// 职责范围：
///   - 多选模式开关（_isSelectMode）
///   - 选中契约文件名集合（_selected）
///   - 选中舞台目录路径集合（_selectedStages）
///   - 选中舞台内角色集合（_selectedStageRoles，key = "舞台路径|角色名|文件名|isChild"）
///   - 契约树展开状态（_expandedGroups）
///   - 舞台展开状态（_expandedStages）
///
/// 不包含文件操作（删除/导入/重命名等），那些仍依赖 UI 上下文
/// （ScaffoldMessenger / Navigator / ref），由 State 桥接。
class HomeSelectionController extends ChangeNotifier {
  /// 多选模式下选中的契约文件名
  final Set<String> _selected = {};

  /// 多选模式下选中的舞台目录路径（与契约并集）
  final Set<String> _selectedStages = {};

  /// 多选模式下选中的舞台内角色（key = "舞台路径|角色名|文件名|isChild"）
  ///
  /// 角色级多选允许在展开区单独勾选某个角色（母版卡或子版存档卡），
  /// 与单角色契约树「每节点独立选中」的心智对齐。
  final Set<String> _selectedStageRoles = {};

  /// 是否为多选模式
  bool _isSelectMode = false;

  /// 已展开节点的文件名集合（含所有层级，点击展开/收起）
  final Set<String> _expandedGroups = {};

  /// 已展开的舞台目录路径集合（对齐契约树 [expandedGroups]）
  final Set<String> _expandedStages = {};

  // ============================================================
  // 只读状态（供 UI 读取）
  // ============================================================

  /// 选中的契约文件名集合（只读视角）
  Set<String> get selected => Set.unmodifiable(_selected);

  /// 选中数量
  int get selectedCount => _selected.length;

  /// 选中舞台的数量
  int get selectedStageCount => _selectedStages.length;

  /// 选中的舞台目录路径集合（只读视角）
  Set<String> get selectedStages => Set.unmodifiable(_selectedStages);

  /// 选中的舞台内角色 key 集合（只读视角）
  Set<String> get selectedStageRoles => Set.unmodifiable(_selectedStageRoles);

  /// 选中的舞台内角色数量
  int get selectedStageRoleCount => _selectedStageRoles.length;

  /// 是否同时选中了契约/舞台/角色（用于 AppBar 标题合并计数）
  int get totalSelectedCount =>
      _selected.length + _selectedStages.length + _selectedStageRoles.length;

  /// 是否为多选模式
  bool get isSelectMode => _isSelectMode;

  /// 已展开节点的文件名集合（只读视角）
  Set<String> get expandedGroups => Set.unmodifiable(_expandedGroups);

  /// 已展开的舞台目录路径集合（只读视角）
  Set<String> get expandedStages => Set.unmodifiable(_expandedStages);

  /// 指定文件名是否被选中
  bool isSelected(String fileName) => _selected.contains(fileName);

  /// 指定舞台目录是否被选中
  bool isStageSelected(String dirPath) => _selectedStages.contains(dirPath);

  /// 指定舞台内角色是否被选中（母版/子版分别查询）
  bool isStageRoleSelected(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild = false,
  }) =>
      _selectedStageRoles.contains(
        _stageRoleKey(stagePath, roleName, fileName, isChild: isChild),
      );

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
    // 注意：加入级联子树/展开节点前不立即通知——统一在全部修改完成后
    // 一次性 notify，避免 UI 先收到「仅 master 选中」的中间态。
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
    _toggleInSet(_selected, fileName);
  }

  /// 切换单个舞台的选中状态。
  void toggleStageSelect(String dirPath) {
    _toggleInSet(_selectedStages, dirPath);
  }

  /// 切换舞台内某角色的选中状态（勾选母版/存档 → 批量删除该角色）。
  ///
  /// [fileName] 为角色卡文件名（如 `Arjuna.meph`），key 中携带文件名
  /// 使批量删除可直接定位目标文件（角色名与文件名不一定一致）。
  void toggleStageRoleSelect(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild = false,
  }) {
    _toggleInSet(
      _selectedStageRoles,
      _stageRoleKey(stagePath, roleName, fileName, isChild: isChild),
    );
  }

  /// 进入多选模式并选中指定舞台，**级联选中其内所有角色**并自动展开舞台。
  ///
  /// 对齐单角色契约树「长按母版 → 级联选中整棵子树 + 自动展开」语义。
  ///
  /// 参数：
  ///   - [dirPath]：舞台目录绝对路径
  ///   - [roleKeys]：舞台内全部角色 key（母版卡 + 子版存档卡），
  ///     格式为 `"舞台路径|角色名|角色卡文件名|isChild"`。
  ///     由调用方（HomeScreen）基于 `stageProvider` 加载的角色构建。
  void enterStageSelectMode(String dirPath, List<String> roleKeys) {
    // 一次性通知，避免 UI 先收到「仅舞台选中」的中间态
    _isSelectMode = true;
    _selectedStages.add(dirPath);
    _selectedStageRoles.addAll(roleKeys);
    // 自动展开舞台，使被级联选中的角色立即可见
    _expandedStages.add(dirPath);
    notifyListeners();
  }

  /// 切换舞台展开/收起（对齐契约树 [toggleChildrenExpanded]）
  void toggleStageExpanded(String dirPath) {
    if (_expandedStages.contains(dirPath)) {
      _expandedStages.remove(dirPath);
    } else {
      _expandedStages.add(dirPath);
    }
    notifyListeners();
  }

  /// 进入多选模式并选中舞台内某角色（长按角色卡）。
  void enterStageRoleSelectMode(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild = false,
  }) {
    _isSelectMode = true;
    _selectedStageRoles.add(
      _stageRoleKey(stagePath, roleName, fileName, isChild: isChild),
    );
    notifyListeners();
  }

  // ============================================================
  // 共享操作原语（契约文件/舞台目录/舞台角色三集合统一逻辑）
  // ============================================================

  /// 切换指定 key 在某集合中的选中状态。
  ///
  /// 契约文件名集合（[_selected]）、舞台目录路径集合（[_selectedStages]）
  /// 与舞台角色集合（[_selectedStageRoles]）的切换逻辑完全一致：
  /// 已在集合 → 移除并清理唯一选中；不在集合 → 确保进入多选模式并加入。
  /// 通过本原语消除三处复制粘贴。
  void _toggleInSet(Set<String> set, String key) {
    if (set.contains(key)) {
      set.remove(key);
      // 取消最后一个选中时自动退出多选
      if (_selected.isEmpty &&
          _selectedStages.isEmpty &&
          _selectedStageRoles.isEmpty) {
        _isSelectMode = false;
      }
    } else {
      // 选中节点 → 确保进入多选模式（不依赖调用方前置状态）
      _isSelectMode = true;
      set.add(key);
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
      if (_selected.isEmpty &&
          _selectedStages.isEmpty &&
          _selectedStageRoles.isEmpty) {
        _isSelectMode = false;
      }
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
    _selectedStages.clear();
    _selectedStageRoles.clear();
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

  /// 舞台角色选中集合的 key 格式："舞台路径|角色名|角色卡文件名|isChild"
  ///
  /// 携带 [fileName] 使批量删除可直接定位角色卡/存档文件（角色名与
  /// 文件名不一定一致，如 `阿周那` → `Arjuna.meph`）。
  static String _stageRoleKey(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild = false,
  }) =>
      '$stagePath|$roleName|$fileName|$isChild';
}