import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/app/theme.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:mephisto/providers/home_section_visibility_provider.dart';
import 'package:mephisto/providers/stage_provider.dart';

import 'section_header.dart';
import 'stage_card_with_meta.dart';

/// 舞台列表区（首页聚合入口）
///
/// 单行紧凑卡片 + 角色芯片列表，支持与单角色契约卡一致的多选/批量删除。
/// 多选集合由 home_screen 全局 [HomeSelectionController] 维护。
class StageSection extends ConsumerWidget {
  /// 点击舞台卡片的回调
  final void Function(String dirPath) onStageTap;

  /// 长按舞台卡片回调（普通模式进入多选）
  final void Function(String dirPath)? onStageLongPress;

  /// 多选模式下点击舞台卡片回调（切换选中）
  final void Function(String dirPath)? onStageToggleSelect;

  /// 舞台行「⋮ 菜单」操作回调
  final void Function(String dirPath, String action)? onStageMenu;

  /// 是否处于多选模式
  final bool isSelectMode;

  /// 指定舞台是否被选中
  final bool Function(String dirPath)? isStageSelected;

  /// 点击舞台内某角色的回调（按角色选择舞台叙事入口）
  final void Function(String stagePath, String roleName, {bool restoreSave})?
  onRoleTap;

  /// 长按角色芯片回调（弹出快捷菜单：母版开局 / 续玩存档 / 删除）
  final void Function(String stagePath, String roleName)? onRoleLongPress;

  const StageSection({
    super.key,
    required this.onStageTap,
    this.onStageLongPress,
    this.onStageToggleSelect,
    this.onStageMenu,
    this.isSelectMode = false,
    this.isStageSelected,
    this.onRoleTap,
    this.onRoleLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final stagesAsync = ref.watch(stageListProvider);
    return stagesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stages) {
        if (stages.isEmpty) return const SizedBox.shrink();
        final visibility = ref.watch(homeSectionVisibilityProvider);
        // 多选模式或折叠状态：只显示标题（折叠时不渲染卡片列表）。
        // 多选模式下强制展开（折叠状态下看不到卡片就无法勾选）
        final collapsed = !isSelectMode && visibility.stageCollapsed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              leadingIcon: Icons.theater_comedy,
              title: l10n.homeStageSectionTitle,
              count: stages.length,
              trailing: IconButton(
                icon: Icon(
                  collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                  color: AppTheme.gold,
                ),
                tooltip: collapsed
                    ? l10n.homeSectionExpand
                    : l10n.homeSectionCollapse,
                onPressed: () => ref
                    .read(homeSectionVisibilityProvider.notifier)
                    .toggleStageCollapsed(),
              ),
            ),
            if (!collapsed)
              for (final stage in stages) ...[
                StageCardWithMeta(
                  stage: stage,
                  onTap: () => onStageTap(stage.path),
                  onLongPress: onStageLongPress == null
                      ? null
                      : () => onStageLongPress!(stage.path),
                  isSelectMode: isSelectMode,
                  isSelected: isStageSelected?.call(stage.path) ?? false,
                  onToggleSelect: onStageToggleSelect == null
                      ? null
                      : () => onStageToggleSelect!(stage.path),
                  onMenu: onStageMenu == null
                      ? null
                      : (action) => onStageMenu!(stage.path, action),
                  onRoleTap: onRoleTap == null || isSelectMode
                      ? null
                      : (roleName, {restoreSave = false}) => onRoleTap!(
                          stage.path,
                          roleName,
                          restoreSave: restoreSave,
                        ),
                  onRoleLongPress: onRoleLongPress == null || isSelectMode
                      ? null
                      : (roleName) => onRoleLongPress!(stage.path, roleName),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
