import 'package:flutter/material.dart';
import 'package:mephisto/app/theme.dart';
import 'package:mephisto/constants/menu_actions.dart';
import 'package:mephisto/domain/stage_color_palette.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:mephisto/services/storage/stage_repo.dart';
import 'package:mephisto/widgets/home/relative_time.dart';

import '../card_menu.dart';
import 'home_card_common.dart';
import 'role_chip.dart';

/// 首页舞台聚合卡（单行紧凑版）
///
/// 替代旧版「展开区双层迷你卡片」，改为单行标题 + 角色芯片列表：
///   - 第一行：舞台名 + 角色数徽标（`👥 N`）+ 最近活动时间 + ⋮ 菜单
///   - 第二行：角色芯片（最多 3 个 + 更多计数）
///   - 点击卡片 → 进入舞台叙事
///   - 点击角色芯片 → 进入该角色视角的舞台叙事
///   - 长按角色芯片 → 弹出快捷菜单（由调用方处理）
///
/// 多角色舞台的核心能力完全保留：
///   - 角色存档（`.child.meph`）通过 💾 徽标体现
///   - 角色级操作（删除存档/重新开始）通过角色 chip 长按上下文菜单访问
class StageCard extends StatelessWidget {
  /// 舞台信息
  final StageInfo info;

  /// 舞台角色名列表（来自 `loadStage` 解析；空时隐藏预览）
  final List<String> roleNames;

  /// 存在 `.child.meph` 存档的角色名集合（显示 💾 徽标）
  final Set<String> savedRoleNames;

  /// 最近活动时间（null 时隐藏）
  final DateTime? lastModified;

  /// 点击舞台卡片的回调（进入叙事）
  final VoidCallback onTap;

  /// 长按舞台卡片的回调（普通模式进入多选）
  final VoidCallback? onLongPress;

  /// 是否处于多选模式
  final bool isSelectMode;

  /// 当前舞台是否被选中（多选模式下）
  final bool isSelected;

  /// 多选模式下点击舞台的回调（切换选中）
  final VoidCallback? onToggleSelect;

  /// 舞台行「⋮ 菜单」操作回调（参数为操作名）
  final ValueChanged<String>? onMenu;

  /// 点击舞台内某角色的回调。
  ///
  ///   - [roleName]：被点击的角色名
  ///   - [restoreSave]：true = 使用 `.child.meph` 存档续玩；
  ///     false = 从母版文件干净开局。
  final void Function(String roleName, {bool restoreSave})? onRoleTap;

  /// 长按角色芯片的回调（弹出快捷菜单）。
  final void Function(String roleName)? onRoleLongPress;

  const StageCard({
    super.key,
    required this.info,
    this.roleNames = const [],
    this.savedRoleNames = const {},
    this.lastModified,
    required this.onTap,
    this.onLongPress,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.onMenu,
    this.onRoleTap,
    this.onRoleLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // 角色色板（与叙事页一致：字典序 → 主题色）
    final roleColors = assignRoleColors(roleNames);
    // 最多展示前 3 位角色，其余用「+N」汇总
    const maxVisibleRoles = 3;
    final visibleRoles = roleNames.take(maxVisibleRoles).toList();
    final hasMore = roleNames.length > maxVisibleRoles;

    return HomeCardShell(
      isSelectMode: isSelectMode,
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      onToggleSelect: onToggleSelect,
      titleColumn: _buildTitleColumn(theme, l10n),
      // 尾部：⋮ 菜单（保留，操作完整）
      trailing: !isSelectMode && onMenu != null
          ? _buildMenu(context, l10n)
          : null,
      // 单行下方：角色芯片列表
      collapsedContent: roleNames.isNotEmpty
          ? Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final role in visibleRoles)
                  RoleChip(
                    roleName: role,
                    color: roleColors[role] ?? AppTheme.gold,
                    hasSave: savedRoleNames.contains(role),
                    onTap: onRoleTap == null || isSelectMode
                        ? null
                        : () => onRoleTap!(role, restoreSave: true),
                    onLongPress: onRoleLongPress == null || isSelectMode
                        ? null
                        : () => onRoleLongPress!(role),
                  ),
                if (hasMore)
                  Text(
                    '+${roleNames.length - maxVisibleRoles}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary(theme.brightness),
                    ),
                  ),
              ],
            )
          : null,
      // 非选中状态下的金色描边（与单角色契约卡风格对齐）
      normalBorderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.3)),
    );
  }

  /// 构建两行标题列：
  ///   - 第一行：舞台名
  ///   - 第二行：角色数量 + 最近活动
  Widget _buildTitleColumn(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // 第二行：仅保留最近活动时间（角色数由下方角色芯片自然表达）
        if (lastModified != null)
          Text(
            l10n.stageCardLastModified(formatRelativeTime(lastModified!, l10n)),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary(theme.brightness),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  /// 舞台行 ⋮ 操作菜单（续玩/重新开始/导出/重命名/删除）
  Widget _buildMenu(BuildContext context, AppLocalizations l10n) {
    return buildCardMenu(
      menuItems: [
        CardMenuItem(
          menuActionEnter,
          Icons.play_arrow_outlined,
          l10n.contractCardEnter,
        ),
        CardMenuItem(
          menuActionRestart,
          Icons.restart_alt,
          l10n.stageCardRestart,
        ),
        CardMenuItem(
          menuActionExport,
          Icons.archive_outlined,
          l10n.stageCardExport,
        ),
        CardMenuItem(
          menuActionRename,
          Icons.drive_file_rename_outline,
          l10n.contractCardRename,
        ),
        CardMenuItem(
          menuActionDelete,
          Icons.delete_outline,
          l10n.contractCardDelete,
        ),
      ],
      onSelected: onMenu!,
      tooltip: l10n.contractCardOperations,
    );
  }
}
