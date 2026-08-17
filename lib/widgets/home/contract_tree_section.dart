import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../providers/contract_provider.dart';
import '../../providers/home_section_visibility_provider.dart';
import '../../providers/home_selection_controller.dart';
import '../../providers/recent_edit_provider.dart';
import 'contract_card.dart';
import 'home_brand_header.dart';
import 'section_header.dart';
import 'stage_section.dart';

/// 首页契约树 + 舞台聚合 + 最近编辑（只读渲染区）
///
/// 从 `_HomeScreenState` 拆出的「契约列表（单行紧凑卡片）+ 多角色舞台聚合入口 +
/// 最近编辑」纯渲染逻辑。所有交互通过回调注入，本 Widget 不持有任何 State 生命周期。
class ContractTreeSection extends ConsumerWidget {
  /// 已加载的契约树组（由 HomeScreen 从 `contractGroupListProvider` 获取）
  final List<ContractGroup> groups;

  /// 首页全局多选/展开控制器（HomeScreen 通过 ListenableBuilder 重绘）
  final HomeSelectionController selection;

  // ---- 契约树回调 ----
  /// 母版卡片点击（普通进入叙事）
  final void Function(ContractInfo info) onMasterTap;

  /// 母版行 ⋮ 菜单
  final void Function(BuildContext context, ContractInfo master, String action)
  onMasterMenu;

  /// 子版行 ⋮ 菜单
  final void Function(ContractInfo child, String action) onChildMenu;

  /// 子版卡片点击（进入对应分支叙事）
  final void Function(ContractInfo child) onChildTap;

  /// 子版卡片长按（进入多选）
  final void Function(ContractInfo child) onChildLongPress;

  /// 「最近编辑」入口点击（直接进入对应叙事页）
  final void Function(ContractInfo info) onEnterNarrative;

  // ---- 舞台回调 ----

  /// 舞台点击（进入叙事）
  final void Function(String stagePath) onStageTap;

  /// 舞台长按（进入多选）
  final void Function(String stagePath)? onStageLongPress;

  /// 多选模式舞台点击（切换选中）
  final void Function(String stagePath)? onStageToggleSelect;

  /// 舞台行 ⋮ 菜单
  final void Function(String stagePath, String action)? onStageMenu;

  /// 舞台内角色点击
  final void Function(String stagePath, String roleName, {bool restoreSave})?
  onRoleTap;

  /// 普通模式角色芯片长按（弹出快捷菜单）
  final void Function(String stagePath, String roleName)? onRoleLongPress;

  const ContractTreeSection({
    super.key,
    required this.groups,
    required this.selection,
    required this.onMasterTap,
    required this.onMasterMenu,
    required this.onChildMenu,
    required this.onChildTap,
    required this.onChildLongPress,
    required this.onEnterNarrative,
    required this.onStageTap,
    this.onStageLongPress,
    this.onStageToggleSelect,
    this.onStageMenu,
    this.onRoleTap,
    this.onRoleLongPress,
  });

  /// 合并「单角色契约 + 多角色舞台」两侧最近编辑，返回全局最新入口。
  ///
  /// 内部委托 [recentEditProvider]（Riverpod memoized Provider），
  /// 仅在依赖数据变化时重算，避免每次 build 都递归遍历 + watch。
  RecentEditEntry? _computeRecentEntry(
    WidgetRef ref,
    List<ContractInfo> allContractInfos,
  ) {
    final data = ref.watch(recentEditProvider).value;
    if (data == null) return null;

    // 根据类型构建正确的 onTap 回调：
    //   - 舞台：targetPath 是舞台目录路径 → onStageTap
    //   - 契约：从已收集的 ContractInfo 列表中找到对应文件 → onEnterNarrative
    if (data.isStage) {
      return RecentEditEntry(
        label: data.label,
        lastModified: data.lastModified,
        onTap: () => onStageTap(data.targetPath),
      );
    }

    // 契约侧：从调用方传入的 ContractInfo 列表中查找对应文件
    final match = allContractInfos
        .where((info) => info.fileName == data.targetPath)
        .firstOrNull;
    if (match == null) return null;

    return RecentEditEntry(
      label: match.roleName,
      lastModified: match.lastModified,
      onTap: () => onEnterNarrative(match),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isSelectMode = selection.isSelectMode;
    final visibility = ref.watch(homeSectionVisibilityProvider);
    // 多选模式下强制展开（折叠状态下看不到卡片就无法勾选）
    final contractCollapsed = !isSelectMode && visibility.contractCollapsed;
    // 预先计算每棵契约树的全部节点信息（一次性递归收集），
    // 避免在 childSelection 构建与 onLongPress 回调中对同一棵树反复递归遍历。
    final groupInfosCache = <String, List<ContractInfo>>{
      for (final group in groups) group.master.fileName: group.allInfos,
    };

    // 「最近编辑」：合并单角色契约 + 多角色舞台两侧候选，取全局最新入口。
    final recentEntry = _computeRecentEntry(ref, [
      for (final infos in groupInfosCache.values) ...infos,
    ]);

    // ---- 惰性列表：固定头部（品牌/舞台/契约标题）按索引映射，契约卡片懒构建 ----
    // 旧实现用 `ListView(children: [...])` 一次性构建全部契约卡；契约库上百时
    // 首帧 build 与内存 O(N)、滚动无懒加载。改用 `ListView.builder`：
    //   - 头部固定项（品牌/舞台/标题）少而稳定，作为前 N 个索引
    //   - 契约卡按 `groups[index - headerCount]` 懒构建，视口外不实例化
    // StageSection 内部舞台数通常个位数，保持整块构建（不拆散其独立滚动语义）。
    final headerCount = isSelectMode ? 1 : 4; // 多选时隐藏品牌/标题区
    final cardCount = contractCollapsed ? 0 : groups.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      itemCount: headerCount + cardCount,
      itemBuilder: (context, index) {
        if (index < headerCount) {
          return _buildHeaderItem(
            context,
            ref,
            index,
            l10n,
            recentEntry,
            isSelectMode,
            contractCollapsed,
          );
        }
        // ---- 契约卡片（懒构建：仅视口内实例化） ----
        final group = groups[index - headerCount];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ContractCard(
            group: group,
            isSelectMode: isSelectMode,
            isSelected: selection.isSelected(group.master.fileName),
            onTap: () => onMasterTap(group.master),
            onLongPress: () {
              if (!isSelectMode) {
                // 长按节点 → 级联选中其整棵子树
                final subtreeNames =
                    (groupInfosCache[group.master.fileName] ??
                            const <ContractInfo>[])
                        .map((i) => i.fileName)
                        .toList();
                selection.enterSelectMode(
                  group.master.fileName,
                  cascadeNames: subtreeNames,
                  expandNodes: subtreeNames,
                );
              }
            },
            onMenu: (action) => onMasterMenu(context, group.master, action),
            // 分支选择器：点击分支进入对应契约
            onBranchTap: onChildTap,
            // 分支选择器内 ⋮ 菜单：按 isChild 自动分发到母版/子版菜单处理。
            // 母版走 onMasterMenu（含编辑/导出/级联删除），子版走 onChildMenu。
            onBranchMenu: (info, action) {
              if (info.isChild) {
                onChildMenu(info, action);
              } else {
                onMasterMenu(context, info, action);
              }
            },
          ),
        );
      },
    );
  }

  /// 构建列表头部的固定项（按索引映射）。
  ///
  /// [index] 为列表索引；头部项数由 [headerCount] 决定：
  ///   - 普通模式（headerCount=4）：0=品牌区，1=舞台区，2=契约标题，3=间距
  ///   - 多选模式（headerCount=1）：0=舞台区（品牌/标题隐藏，聚焦操作）
  Widget _buildHeaderItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    AppLocalizations l10n,
    RecentEditEntry? recentEntry,
    bool isSelectMode,
    bool contractCollapsed,
  ) {
    if (isSelectMode) {
      // 多选模式：仅舞台区（强制展开）
      return _buildStageSection(ref, isSelectMode, contractCollapsed);
    }
    switch (index) {
      case 0:
        // ---- 品牌展示区（多选模式下隐藏，聚焦操作） ----
        return HomeBrandHeader(recentEntry: recentEntry);
      case 1:
        return _buildStageSection(ref, isSelectMode, contractCollapsed);
      case 2:
        // ---- 单角色契约分区标题（仅普通模式显示，多选时聚焦操作） ----
        return SectionHeader(
          leadingIcon: Icons.menu_book_outlined,
          title: l10n.homeContractSectionTitle,
          count: groups.length,
          trailing: IconButton(
            icon: Icon(
              contractCollapsed ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: AppTheme.gold,
            ),
            tooltip: contractCollapsed
                ? l10n.homeSectionExpand
                : l10n.homeSectionCollapse,
            onPressed: () => ref
                .read(homeSectionVisibilityProvider.notifier)
                .toggleContractCollapsed(),
          ),
        );
      default:
        return const SizedBox(height: 4);
    }
  }

  /// 构建舞台聚合入口（普通/多选模式共用；舞台数通常个位数，整块构建）。
  Widget _buildStageSection(
    WidgetRef ref,
    bool isSelectMode,
    bool contractCollapsed,
  ) {
    return StageSection(
      onStageTap: onStageTap,
      onStageLongPress: isSelectMode ? null : onStageLongPress,
      onStageToggleSelect: isSelectMode ? onStageToggleSelect : null,
      onStageMenu: isSelectMode ? null : onStageMenu,
      isSelectMode: isSelectMode,
      isStageSelected: selection.isStageSelected,
      onRoleTap: isSelectMode
          ? null
          : (stagePath, roleName, {restoreSave = false}) =>
                onRoleTap!(stagePath, roleName, restoreSave: restoreSave),
      onRoleLongPress: isSelectMode ? null : onRoleLongPress,
    );
  }
}
