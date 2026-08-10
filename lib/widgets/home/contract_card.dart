import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/contract_provider.dart';
import '../card_menu.dart';
import 'home_card_common.dart';

/// 契约树节点卡片（递归渲染多级「命运树」）
///
/// 接受一个递归 [ContractGroup] 节点，渲染其自身行（[master]）+ 可展开的子节点区。
/// 子节点区内的每个子 [ContractGroup] 递归渲染为嵌套卡片，形成多级树状分级：
///
/// ```
/// faust.meph                     ← ContractCard(node: faust)
/// └─ faust.dark.meph             ← ContractCard(node: faust.dark)
///     └─ faust.dark.light.meph   ← ContractCard(node: faust.dark.light)
/// ```
///
/// 层级引导：子节点卡片以「缩进 + 金色圆点」标记隶属关系（移动/桌面统一）。
///
/// 展开状态由 home_screen 全局维护（[expandedChildren] 集合），
/// 递归渲染时每个子节点都能拿到完整集合，展开/收起动作统一转发给上层。
class ContractCard extends StatelessWidget {
  /// 当前树节点（含其下递归子节点）
  final ContractGroup group;

  /// 该节点子区是否展开
  final bool childrenExpanded;

  /// home_screen 全局维护的「已展开节点」文件名集合（含所有层级）
  final Set<String> expandedChildren;

  /// 切换某节点展开/收起（home_screen 接收 fileName）
  final ValueChanged<String> onToggleNode;

  /// 是否处于多选模式
  final bool isSelectMode;

  /// 当前节点是否被选中（多选模式下）
  final bool isSelected;

  /// 子节点选中状态映射（fileName → 是否选中）
  final Map<String, bool> childSelection;

  /// 单击节点回调（多选切换选中 / 普通进入叙事）
  final VoidCallback onTap;

  /// 长按节点回调（普通模式级联进入多选）
  final VoidCallback onLongPress;

  /// 节点行「⋮ 菜单」操作回调（参数为操作名）
  final ValueChanged<String> onMenu;

  /// 点击子节点回调（多选切换选中 / 普通进入对应分支）
  final ValueChanged<ContractInfo> onChildTap;

  /// 长按子节点回调
  final ValueChanged<ContractInfo> onChildLongPress;

  /// 子节点行「⋮ 菜单」回调（参数为 子节点信息 + 操作名）
  final void Function(ContractInfo child, String action) onChildMenu;

  const ContractCard({
    super.key,
    required this.group,
    required this.childrenExpanded,
    required this.expandedChildren,
    required this.onToggleNode,
    required this.isSelectMode,
    required this.isSelected,
    required this.childSelection,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
    required this.onChildTap,
    required this.onChildLongPress,
    required this.onChildMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = group.master;
    // 移动端紧凑模式：更小缩进与内边距，为窄屏让出横向空间（层级引导不变）。
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.mobileBreakpoint;
    // 缩进：移动端 8px（紧凑）；桌面端 12px（层级分级）。
    final indent = info.depth * (isMobile ? 8.0 : 12.0);

    final l10n = AppLocalizations.of(context);

    return Container(
      margin: EdgeInsets.only(left: indent),
      child: HomeCardShell(
        isSelectMode: isSelectMode,
        isSelected: isSelected,
        isExpanded: childrenExpanded && group.hasChildren,
        // 点击：普通模式进叙事 / 多选模式切换选中 → 统一走 onTap
        // （HomeCardShell 已自动根据 isSelectMode 分发到 onToggleSelect）
        onTap: onTap,
        onLongPress: onLongPress,
        onToggleSelect: onTap,
        // 前导图标：多选模式由 SelectCheckbox 自动替换
        leading: isSelectMode
            ? null // 多选模式由 HomeCardShell 自动显示 Checkbox
            : _buildLeadingIcon(info),
        titleColumn: _buildTitleColumn(theme, info),
        // 尾部：展开箭头 + ⋮ 菜单
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 子节点展开/收起按钮（仅存在子节点时显示）
            if (group.hasChildren)
              ExpandArrow(
                isExpanded: childrenExpanded,
                onPressed: () => onToggleNode(info.fileName),
                tooltip: childrenExpanded
                    ? l10n.contractCardCollapseChildren
                    : l10n.contractCardExpandChildren,
              ),
            // ⋮ 操作菜单（仅普通模式显示）
            if (!isSelectMode) _buildNodeMenu(context),
          ],
        ),
        // 展开区：子节点列表
        expandedContent: group.hasChildren
            ? _buildChildrenSection(context, theme, isMobile)
            : null,
        // 内边距：移动端紧凑
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 4 : 6,
        ),
        leadingSpacing: isMobile ? 6 : 8,
      ),
    );
  }

  /// 构建前导层级图标（母版用根，子版用圆点）
  Widget _buildLeadingIcon(ContractInfo info) {
    return Icon(
      info.depth == 0 ? Icons.graphic_eq : Icons.circle,
      size: info.depth == 0 ? 16 : 8,
      color: AppTheme.gold,
    );
  }

  /// 构建标题列：角色名 / 分支说明 / 文件名
  Widget _buildTitleColumn(ThemeData theme, ContractInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 母版根显示角色名；子版不重复显示（与母版相同），
        // 只展示分支说明 + 文件名
        if (info.depth == 0)
          Text(
            info.roleName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        // 分支说明（仅子版有）：命运一句话为主，未填写时回落为分支名
        if (info.branchName != null) ...[
          const SizedBox(height: 2),
          Text(
            info.branchTitle ?? info.branchName!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.gold,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        Text(
          info.fileName,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary(theme.brightness),
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 构建子节点区：每行「圆点 + 递归子卡片」，层级关系由缩进表达。
  Widget _buildChildrenSection(
    BuildContext context,
    ThemeData theme,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in group.children) ...[
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 层级引导圆点（金色小圆点标记子分支）
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.circle, size: 6, color: AppTheme.gold),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ContractCard(
                  group: child,
                  childrenExpanded: expandedChildren
                      .contains(child.master.fileName),
                  expandedChildren: expandedChildren,
                  onToggleNode: onToggleNode,
                  isSelectMode: isSelectMode,
                  isSelected: childSelection[
                          child.master.fileName] ??
                      false,
                  childSelection: childSelection,
                  onTap: () => onChildTap(child.master),
                  onLongPress: () => onChildLongPress(child.master),
                  onMenu: (action) => onChildMenu(child.master, action),
                  onChildTap: onChildTap,
                  onChildLongPress: onChildLongPress,
                  onChildMenu: onChildMenu,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 6),
        ],
      ],
    );
  }

  /// 节点行 ⋮ 操作菜单（进入/预览/编辑/导出/重命名/删除）
  PopupMenuButton<String> _buildNodeMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return buildCardMenu(
      menuItems: [
        CardMenuItem('enter', Icons.play_arrow_outlined, l10n.contractCardEnter),
        CardMenuItem('preview', Icons.visibility_outlined, l10n.contractCardPreview),
        if (group.master.depth == 0) ...[
          CardMenuItem('edit', Icons.edit_outlined, l10n.contractCardEdit),
          // 导出（命运树 ZIP）：仅在母版根显示，导出整棵母版子树
          CardMenuItem('export', Icons.archive_outlined, l10n.contractCardExport),
        ],
        CardMenuItem('rename', Icons.drive_file_rename_outline, l10n.contractCardRename),
        CardMenuItem('delete', Icons.delete_outline, l10n.contractCardDelete),
      ],
      onSelected: onMenu,
      tooltip: l10n.contractCardOperations,
    );
  }
}