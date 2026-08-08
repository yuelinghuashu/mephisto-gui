import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/contract_provider.dart';
import '../providers/home_selection_controller.dart';
import '../widgets/home/contract_card.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_branch_sheet.dart';
import '../widgets/home/home_brand_header.dart';
import '../widgets/home/home_state_views.dart';
import 'home/home_menu_actions.dart';
import 'home/home_operations.dart';

/// 首页：契约选择
///
/// 展示用户 `contracts/` 目录中的所有 .meph 契约文件（含角色名）。
/// 采用「多级命运树」递归层级结构（文件名 `.` 分段表达派生链）：
///   - 母版卡片默认只显示自身
///   - 有子节点时卡片右侧显示展开箭头「▾」，点击展开子节点（逐级缩进的嵌套卡片）
///   - 每个节点右下都有「⋮ 操作菜单」，提供一致的 进入/预览/重命名/删除
///
/// 支持：
///   - 单击任意节点进入对应叙事
///   - 长按节点进入多选模式（级联选中其整棵子树）
///   - 导入本地 .meph 文件
///
/// 职责拆分（本类只做「组装 + 导航 + 委托」）：
///   - 多选/展开状态：[_selection]（独立 Controller）
///   - 文件操作：`home_operations.dart`（导入/删除/编辑/新建/恢复内置）
///   - 菜单/重命名/删除确认：`home_menu_actions.dart`
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 多选/展开状态控制器（状态逻辑已抽离，可独立单元测试）
  final HomeSelectionController _selection = HomeSelectionController();

  /// 是否正在恢复内置角色（空状态恢复按钮的加载态）
  bool _isRestoring = false;

  /// 递归收集一棵 [ContractGroup] 子树的所有契约信息（含自身）。
  static List<ContractInfo> _collectInfos(ContractGroup group) => group.allInfos;

  // ============================================================
  // 状态委托（桥接 Controller）
  //
  // `HomeSelectionController` 是 `ChangeNotifier`，`build()` 中通过
  // `ListenableBuilder` 监听其变化自动重绘，无需手动 `setState`。
  // 仅 `_isRestoring`（空状态恢复按钮的加载态）使用 `setState`。
  // ============================================================

  /// 进入多选模式，并选中指定节点（可级联选中其整棵子树）。
  ///
  /// 参数：
  ///   - fileName: 长按的节点文件名
  ///   - cascadeNames: 长按节点时一并选中的子树文件名（递归）
  ///   - expandNodes: 进入多选时自动展开的节点（使级联选中的节点立即可见）
  void _enterSelectMode(
    String fileName, {
    List<String> cascadeNames = const [],
    List<String>? expandNodes,
  }) {
    _selection.enterSelectMode(
      fileName,
      cascadeNames: cascadeNames,
      expandNodes: expandNodes,
    );
  }

  /// 切换单个节点的选中状态（不联动子树）。
  void _toggleSelect(String fileName) {
    _selection.toggleSelect(fileName);
  }

  /// 切换某节点的选中状态（级联联动其整棵子树）。
  void _toggleSelectSubtree(ContractGroup group) {
    _selection.toggleSelectSubtree(group);
  }

  /// 退出多选模式
  void _exitSelectMode() {
    _selection.exitSelectMode();
  }

  /// 全选所有契约（含所有层级子节点）
  void _selectAll(List<ContractGroup> groups) {
    _selection.selectAll(groups);
  }

  /// 切换某节点的展开/收起
  void _toggleChildrenExpanded(String fileName) {
    _selection.toggleChildrenExpanded(fileName);
  }

  /// 刷新契约列表 providers（带 mounted 保护）。
  void _refreshLists() {
    if (!mounted) return;
    ref.invalidate(contractGroupListProvider);
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  // ============================================================
  // 文件操作委托（实现在 home_operations.dart）
  // ============================================================

  /// 删除选中的契约文件。
  Future<void> _deleteSelected() {
    return deleteSelectedContract(
      ref,
      context,
      _selection,
      onExitSelectMode: _exitSelectMode,
      onRefreshLists: _refreshLists,
    );
  }

  /// 导入本地 .meph 文件。
  Future<void> _importContract() {
    return importContractFiles(
      context,
      onRefreshLists: _refreshLists,
    );
  }

  /// 恢复内置角色模板。
  Future<void> _restoreBuiltin() {
    return restoreBuiltinContracts(
      context,
      onRestoringChanged: (value) => setState(() => _isRestoring = value),
      onRefreshLists: _refreshLists,
    );
  }

  /// 编辑契约（母版源文本）。
  Future<void> _editContract(ContractInfo info) {
    return editContractFile(
      context,
      fileName: info.fileName,
      onRefreshLists: _refreshLists,
    );
  }

  /// 新建空白契约。
  Future<void> _newContract() {
    return newContractFile(
      ref,
      context,
      onRefreshLists: _refreshLists,
    );
  }

  // ============================================================
  // 菜单/重命名/删除委托（实现在 home_menu_actions.dart）
  // ============================================================

  /// 处理母版行「⋮ 菜单」操作。
  Future<void> _handleMasterMenu(
    BuildContext context,
    ContractInfo master,
    String action,
  ) {
    return handleNodeMenu(
      context,
      master,
      action,
      includeEdit: true,
      onEdit: () => _editContract(master),
      onOpenNarrative: _openNarrative,
      onRename: _renameDialog,
      onDelete: () => _confirmCascadeDelete(master),
    );
  }

  /// 处理子版行「⋮ 菜单」操作。
  Future<void> _handleChildMenu(
    BuildContext context,
    ContractInfo child,
    String action,
  ) {
    return handleNodeMenu(
      context,
      child,
      action,
      includeEdit: false,
      onEdit: () async {}, // 子版不可编辑
      onOpenNarrative: _openNarrative,
      onRename: _renameDialog,
      onDelete: () => _confirmDeleteChild(child),
    );
  }

  /// 重命名对话框 + 级联重命名。
  Future<void> _renameDialog(ContractInfo info) {
    return renameContractDialog(
      context,
      info,
      onRefreshLists: _refreshLists,
    );
  }

  /// 确认并级联删除母版及其下所有子版。
  Future<void> _confirmCascadeDelete(ContractInfo master) {
    return confirmCascadeDelete(
      context,
      master,
      onRefreshLists: _refreshLists,
    );
  }

  /// 确认并删除单个子版。
  Future<void> _confirmDeleteChild(ContractInfo child) {
    return confirmDeleteChild(
      context,
      child,
      onRefreshLists: _refreshLists,
    );
  }

  // ============================================================
  // 导航
  // ============================================================

  /// 切换契约并进入叙事。
  ///
  /// 等待叙事页返回后刷新契约列表，确保叙事过程中新生成的子版文件
  /// 能立即在首页显示（否则 provider 缓存命中，需要重启才能看到）。
  Future<void> _openNarrative(ContractInfo info) async {
    await switchContract(ref, info.fileName);
    if (mounted) {
      await Navigator.pushNamed(context, '/narrative');
      _refreshLists();
    }
  }

  /// 处理母版卡片点击。
  ///
  /// 移动端：弹出分支选择器（列出母版本体 + 全部子版，一步直达）。
  /// 桌面端：保持原有行为——有子节点时展开/收起，无子节点时直接进入。
  Future<void> _onMasterTap(BuildContext context, ContractGroup group) async {
    if (!_selection.isSelectMode &&
        MediaQuery.sizeOf(context).width < 600 &&
        group.hasChildren) {
      // 移动端：弹出分支选择器 BottomSheet
      await HomeBranchSheet.show(
        context,
        group: group,
        onEnter: _openNarrative,
      );
      return;
    }

    // 桌面端：保持原有行为
    if (_selection.isSelectMode) {
      _toggleSelectSubtree(group);
    } else {
      _openNarrative(group.master);
    }
  }

  // ============================================================
  // 视图构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(contractGroupListProvider);

    // 通过 ListenableBuilder 监听 _selection 的变化自动重绘，
    // 替代原先手动 `setState(() => _selection.xxx())` 的样板。
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        // 全部契约文件数（递归收集所有节点，含所有层级）
        final allFiles = groupsAsync.value?.expand(_collectInfos).toList() ?? [];

        return Scaffold(
          appBar: _selection.isSelectMode
              ? HomeSelectModeAppBar(
                  selectedCount: _selection.selectedCount,
                  totalCount: allFiles.length,
                  onDelete:
                      _selection.selectedCount == 0 ? null : _deleteSelected,
                  onCancel: _exitSelectMode,
                  onToggleSelectAll: () {
                    // 全部选中时再点全选 = 取消全选
                    if (_selection.selectedCount == allFiles.length) {
                      _exitSelectMode();
                    } else {
                      _selectAll(groupsAsync.value ?? const []);
                    }
                  },
                )
              : HomeAppBar(
                  onNewContract: _newContract,
                  onImportContract: _importContract,
                ),
          body: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => HomeErrorState(error: e),
            data: (groups) {
              if (groups.isEmpty) {
                return HomeEmptyState(
                  onRestoreBuiltin: _restoreBuiltin,
                  isRestoring: _isRestoring,
                );
              }
              return _buildContractList(context, theme, groups);
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // 契约列表（多级命运树）
  // ============================================================

  Widget _buildContractList(
    BuildContext context,
    ThemeData theme,
    List<ContractGroup> groups,
  ) {
    // 预先计算每棵契约树的全部节点信息（一次性递归收集），
    // 避免在 childSelection 构建与 onLongPress 回调中对同一棵树反复递归遍历
    // （大型层级树场景下减少重复 O(N) 遍历）。
    final groupInfosCache = <String, List<ContractInfo>>{
      for (final group in groups) group.master.fileName: group.allInfos,
    };

    // 垂直列表。深层分支的横向滚动由 [ContractCard] 子节点区按需内嵌
    // （仅展开的子节点区有深层后代时出现），不在此全局加宽/滚动。
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        // ---- 品牌展示区（多选模式下隐藏，聚焦操作） ----
        if (!_selection.isSelectMode) const HomeBrandHeader(),

        // ---- 每棵命运树（母版为根，递归渲染子节点） ----
        for (final group in groups) ...[
          ContractCard(
            group: group,
            childrenExpanded: _selection.expandedGroups.contains(
              group.master.fileName,
            ),
            expandedChildren: _selection.expandedGroups,
            onToggleNode: _toggleChildrenExpanded,
            isSelectMode: _selection.isSelectMode,
            isSelected: _selection.isSelected(group.master.fileName),
            childSelection: {
              for (final info in groupInfosCache[group.master.fileName] ??
                  const <ContractInfo>[])
                info.fileName: _selection.isSelected(info.fileName),
            },
            onTap: () => _onMasterTap(context, group),
            onLongPress: () {
              if (!_selection.isSelectMode) {
                // 长按节点 → 级联选中其整棵子树
                // 同时自动展开该子树路径，使被级联选中的节点立即可见
                final subtreeNames =
                    (groupInfosCache[group.master.fileName] ??
                            const <ContractInfo>[])
                        .map((i) => i.fileName)
                        .toList();
                _enterSelectMode(
                  group.master.fileName,
                  cascadeNames: subtreeNames,
                  expandNodes: subtreeNames,
                );
              }
            },
            onMenu: (action) => _handleMasterMenu(context, group.master, action),
            onChildTap: (child) {
              if (_selection.isSelectMode) {
                _toggleSelect(child.fileName);
              } else {
                _openNarrative(child);
              }
            },
            onChildLongPress: (child) {
              if (!_selection.isSelectMode) {
                // 长按子节点 → 单独选中（不级联）
                _enterSelectMode(child.fileName);
              }
            },
            onChildMenu: (child, action) =>
                _handleChildMenu(context, child, action),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}