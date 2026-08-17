import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/contract_provider.dart';
import '../card_menu.dart';
import 'home_branch_sheet.dart';
import 'home_card_common.dart';

/// 契约卡片（单行紧凑版）
///
/// 纯文字布局，无冗余图标：
///   - 第一行：角色名 + 右侧「分支 · N」金色文字（点击弹出分支选择器）
///   - 第二行：文件名
///   - 右侧 ⋮ 菜单 → 保留原有操作（进入/预览/编辑/导出/重命名/删除）
///
/// 分支理念完全保留：所有子版文件依然存在，通过「分支 · N」入口访问。
class ContractCard extends StatelessWidget {
  /// 当前树节点（含其下所有子节点）
  final ContractGroup group;

  /// 是否处于多选模式
  final bool isSelectMode;

  /// 当前节点是否被选中（多选模式下）
  final bool isSelected;

  /// 单击节点回调（多选切换选中 / 普通进入叙事）
  final VoidCallback onTap;

  /// 长按节点回调（普通模式级联进入多选）
  final VoidCallback onLongPress;

  /// 节点行「⋮ 菜单」操作回调（参数为操作名）
  final ValueChanged<String> onMenu;

  /// 点击分支选择器回调（进入对应契约叙事）
  final ValueChanged<ContractInfo> onBranchTap;

  /// 分支选择器内分支项「⋮ 菜单」操作回调（参数为分支信息 + 操作名）
  final void Function(ContractInfo info, String action)? onBranchMenu;

  const ContractCard({
    super.key,
    required this.group,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
    required this.onBranchTap,
    this.onBranchMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = group.master;
    final childCount = group.children.length;

    return HomeCardShell(
      isSelectMode: isSelectMode,
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      onToggleSelect: onTap,
      titleColumn: _buildTitleColumn(theme, info),
      // 尾部：「分支 · N」文字入口 + ⋮ 菜单
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 分支文字入口：点击弹出分支选择器（无图标，纯文字清晰可读）
          if (childCount > 0 && !isSelectMode)
            _BranchTextButton(
              count: childCount,
              onTap: () => HomeBranchSheet.show(
                context,
                group: group,
                onEnter: onBranchTap,
                onMenu: onBranchMenu,
              ),
            ),
          // ⋮ 操作菜单（仅普通模式显示）
          if (!isSelectMode) _buildNodeMenu(context),
        ],
      ),
      // 紧凑内边距（单行条目，降低垂直占用）
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  /// 构建两行标题列：
  ///   - 第一行：角色名（母版根）/ 命运一句话（子版）
  ///   - 第二行：文件名
  Widget _buildTitleColumn(ThemeData theme, ContractInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- 第一行：角色名或命运一句话 ----
        Text(
          info.depth == 0
              ? info.roleName
              : (info.branchTitle ?? info.branchName ?? info.fileName),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: info.depth == 0
                ? theme.colorScheme.onSurface
                : AppTheme.gold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // ---- 第二行：文件名 ----
        Text(
          info.fileName,
          // labelSmall 已含 11px + textSecondary 默认值，无需重复覆盖
          style: theme.textTheme.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 节点行 ⋮ 操作菜单（进入/预览/编辑/导出/重命名/删除）
  PopupMenuButton<String> _buildNodeMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 母版根（depth == 0）显示编辑/导出，子版不显示
    return buildCardMenu(
      menuItems: buildContractMenuItems(
        isMaster: group.master.depth == 0,
        l10n: l10n,
      ),
      onSelected: onMenu,
      tooltip: l10n.contractCardOperations,
    );
  }
}

/// 分支文字入口（金色「分支 · N」，点击弹出分支选择器）
///
/// 不使用图标：`account_tree_outlined` 在 12px 下视觉可读性差，
/// 纯文字 + 数字更清晰易点。
class _BranchTextButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _BranchTextButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          AppLocalizations.of(context).contractBranchCount(count),
          // labelMedium 已含 12px 默认值，仅覆盖颜色/字重
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppTheme.gold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
