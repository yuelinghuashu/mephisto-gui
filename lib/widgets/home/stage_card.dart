import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/app/theme.dart';
import 'package:mephisto/domain/stage_color_palette.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:mephisto/providers/stage_provider.dart';
import 'package:mephisto/services/storage/stage_repo.dart';
import 'package:mephisto/widgets/home/relative_time.dart';

import '../card_menu.dart';
import 'home_card_common.dart';
import 'section_header.dart';

/// 首页舞台聚合卡：展示一个多角色舞台（目录）的概要信息。
///
/// 交互与单角色契约卡保持一致：
///   - 点击卡片主体 → 进入舞台叙事页
///   - 右侧下箭头（`expand_more` / `expand_less`）→ 展开/收起舞台内角色列表
///   - 右上 ⋮ 菜单 → 进入 / 重命名 / 删除
///   - 长按 → 进入多选模式 + 勾选批量删除
///
/// 通过 [HomeCardShell] 统一骨架，与单角色契约卡共享相同的卡片容器、
/// 主行布局、展开区样式与多选交互。
class StageCard extends StatelessWidget {
  /// 舞台信息
  final StageInfo info;

  /// 舞台角色名列表（来自 `loadStage` 解析；空时隐藏预览）
  final List<String> roleNames;

  /// 角色名 → 角色卡文件名映射（如 `阿周那 → Arjuna.meph`）。
  ///
  /// 删除角色/存档时必须使用实际文件名（.meph），不能用中文角色名去
  /// 匹配文件名（角色名与文件名可能不一致，如内置 Kurukshetra 舞台）。
  final Map<String, String> roleFileNames;

  /// 存在 `.child.meph` 存档的角色名集合（展开区显示「有存档」徽标）
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

  /// 是否展开（显示舞台内角色列表）
  final bool isExpanded;

  /// 切换展开/收起回调
  final VoidCallback? onToggleExpanded;

  /// 点击舞台内某角色的回调（按角色选择母版/子版入口）。
  ///
  ///   - [roleName]：被点击的角色名
  ///   - [restoreSave]：true = 该角色使用 `.child.meph` 子版存档续玩；
  ///     false = 该角色从母版文件干净开局。
  ///
  /// 无论选择母版还是子版，最终都进入同一个多角色共享舞台
  /// （[StageNarrativeScreen]），只是被点角色按指定文件整合：
  /// 其余角色保持各自存档续玩。
  final void Function(String roleName, {bool restoreSave})? onRoleTap;

  /// 角色行 ⋮ 菜单回调（删除单个角色卡 / 删除存档）。
  ///
  /// 参数为 角色名 + 角色卡文件名 + 操作名；删除时必须使用文件名
  /// 定位目标 .meph 文件（角色名与文件名不一定一致）。
  final void Function(String roleName, String fileName, String action)?
      onRoleMenu;

  /// 多选模式下点击角色卡的回调（切换角色选中状态）。
  ///
  /// 参数为 角色名 + 角色卡文件名 + 是否子版；携带文件名使批量删除
  /// 可直接定位目标文件（角色名与文件名不一定一致）。
  final void Function(String roleName, String fileName, {bool isChild})?
      onRoleToggleSelect;

  /// 普通模式长按角色卡的回调（进入多选并选中该角色）。
  ///
  /// 参数为 角色名 + 角色卡文件名 + 是否子版；携带文件名使多选删除
  /// key 中可直接定位目标文件。
  final void Function(String roleName, String fileName, {bool isChild})?
      onRoleLongPress;

  /// 多选模式下指定角色是否被选中（母版/子版分别查询）。
  ///
  /// 参数为 角色名 + 角色卡文件名 + 是否子版。
  final bool Function(String roleName, String fileName, {bool isChild})?
      isRoleSelected;

  const StageCard({
    super.key,
    required this.info,
    this.roleNames = const [],
    this.roleFileNames = const {},
    this.savedRoleNames = const {},
    this.lastModified,
    required this.onTap,
    this.onLongPress,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.onMenu,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.onRoleTap,
    this.onRoleMenu,
    this.onRoleToggleSelect,
    this.onRoleLongPress,
    this.isRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // 角色色板（与叙事页一致：字典序 → 主题色）
    final roleColors = assignRoleColors(roleNames);
    // 预览最多显示前 3 位角色
    final previewRoles = roleNames.take(3).toList();
    final hasMore = roleNames.length > previewRoles.length;
    final hasRoles = roleNames.isNotEmpty;

    return HomeCardShell(
      isSelectMode: isSelectMode,
      isSelected: isSelected,
      isExpanded: isExpanded,
      // 点击：普通模式进叙事 / 多选模式切换选中 → 统一走 onTap
      onTap: onTap,
      onLongPress: onLongPress,
      onToggleSelect: onToggleSelect,
      // 前导：舞台图标（多选时由 SelectCheckbox 自动替换）
      leading: isSelectMode
          ? null
          : const Icon(Icons.theater_comedy, color: AppTheme.gold, size: 24),
      titleColumn: _buildTitleColumn(theme, l10n),
      // 尾部：展开箭头 + ⋮ 菜单
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 展开/收起按钮（与单角色契约卡一致：箭头在前，下箭头展开/上箭头收起）
          if (hasRoles)
            ExpandArrow(
              isExpanded: isExpanded,
              onPressed: onToggleExpanded,
              tooltip: isExpanded
                  ? l10n.contractCardCollapseChildren
                  : l10n.contractCardExpandChildren,
            ),
          // ⋮ 操作菜单（仅普通模式显示，放在箭头之后 = 最右）
          if (!isSelectMode && onMenu != null) _buildMenu(context, l10n),
        ],
      ),
      // 非展开态：角色名预览（色板圆点 + 角色名，前 3 位 + 更多计数）
      collapsedContent: !isExpanded && hasRoles
          ? Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final role in previewRoles)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: roleColors[role] ?? AppTheme.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        role,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary(theme.brightness),
                        ),
                      ),
                    ],
                  ),
                if (hasMore)
                  Text(
                    '+${roleNames.length - previewRoles.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary(theme.brightness),
                    ),
                  ),
              ],
            )
          : null,
      // 展开区：完整角色列表（母版行 + 子版行两级可点入口）
      expandedContent: hasRoles
          ? _buildExpandedContent(theme, l10n, roleColors)
          : null,
      // 非选中状态下的金色描边（与单角色契约树的命运树风格对齐）
      normalBorderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.3)),
    );
  }

  /// 构建标题列：舞台名 + 角色数量 + 最近活动
  Widget _buildTitleColumn(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.name,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // 底部信息行：角色数量 + 最近活动
        Row(
          children: [
            Text(
              l10n.stageCardCharacterCount(info.characterCount),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (lastModified != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.stageCardLastModified(
                    formatRelativeTime(lastModified!, l10n),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary(theme.brightness),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建展开区：每个角色 = 迷你角色卡片（母版 + 有存档时的子版）。
  ///
  /// 与单角色契约树的「母版/子版直接点选」心智对齐，同时保留多角色自己的特征：
  ///   - 母版卡片：点击 → 该角色从母版文件整合进舞台
  ///   - 子版卡片（仅有存档时显示）：点击 → 从子版存档整合
  ///
  /// 每个卡片有独立的 ⋮ 操作菜单（删除母版角色卡 / 删除存档），
  /// 补足了此前多角色展开区「无长按删除」的能力缺失。
  Widget _buildExpandedContent(
    ThemeData theme,
    AppLocalizations l10n,
    Map<String, Color> roleColors,
  ) {
    final canInteract = !isSelectMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in roleNames) ...[
          const SizedBox(height: 2),
          // ---- 母版卡片 ----
          _buildRoleCard(
            theme: theme,
            l10n: l10n,
            roleColor: roleColors[role] ?? AppTheme.gold,
            roleName: role,
            fileName: roleFileNames[role] ?? role,
            isChild: false,
            canInteract: canInteract,
            onTap: canInteract && onRoleTap != null
                ? () => onRoleTap!(role, restoreSave: false)
                : null,
            onToggleSelect: onRoleToggleSelect == null
                ? null
                : () => onRoleToggleSelect!(
                    role,
                    roleFileNames[role] ?? role,
                    isChild: false,
                  ),
            onLongPress: onRoleLongPress == null
                ? null
                : () => onRoleLongPress!(
                    role,
                    roleFileNames[role] ?? role,
                    isChild: false,
                  ),
            isSelected:
                isRoleSelected?.call(role, roleFileNames[role] ?? role, isChild: false) ??
                    false,
            menuItems: _buildRoleMenuItems(l10n),
            onMenu: canInteract && onRoleMenu != null
                ? (action) =>
                    onRoleMenu!(role, roleFileNames[role] ?? role, action)
                : null,
          ),
          // ---- 子版卡片（仅存在存档时显示）----
          if (savedRoleNames.contains(role))
            _buildRoleCard(
              theme: theme,
              l10n: l10n,
              roleColor: AppTheme.gold,
              roleName: role,
              fileName: roleFileNames[role] ?? role,
              isChild: true,
              canInteract: canInteract,
              onTap: canInteract && onRoleTap != null
                  ? () => onRoleTap!(role, restoreSave: true)
                  : null,
              onToggleSelect: onRoleToggleSelect == null
                  ? null
                  : () => onRoleToggleSelect!(
                      role,
                      roleFileNames[role] ?? role,
                      isChild: true,
                    ),
              onLongPress: onRoleLongPress == null
                  ? null
                  : () => onRoleLongPress!(
                      role,
                      roleFileNames[role] ?? role,
                      isChild: true,
                    ),
              isSelected:
                  isRoleSelected?.call(role, roleFileNames[role] ?? role, isChild: true) ??
                      false,
              menuItems: _buildChildMenuItems(l10n),
              onMenu: canInteract && onRoleMenu != null
                  ? (action) =>
                      onRoleMenu!(role, roleFileNames[role] ?? role, action)
                  : null,
            ),
        ],
      ],
    );
  }

  /// 母版角色行的菜单项：进入 / 预览 / 编辑 / 删除（级联删存档）
  List<CardMenuItem> _buildRoleMenuItems(AppLocalizations l10n) {
    return [
      CardMenuItem('enter', Icons.play_arrow_outlined, l10n.contractCardEnter),
      CardMenuItem(
        'preview',
        Icons.visibility_outlined,
        l10n.contractCardPreview,
      ),
      CardMenuItem('edit', Icons.edit_outlined, l10n.contractCardEdit),
      CardMenuItem(
        'delete_role',
        Icons.delete_outline,
        l10n.stageCardDeleteRole,
      ),
    ];
  }

  /// 子版存档卡菜单项：预览 / 删除存档。
  ///
  /// **不提供「进入」**：子版卡本身点击 = 续玩存档（restoreSave=true），
  /// 菜单重复进入会造成与母版菜单「从母版开局」的语义混淆。
  /// 子版不可编辑（对齐单角色子版），仅保留 预览 / 删除存档。
  List<CardMenuItem> _buildChildMenuItems(AppLocalizations l10n) {
    return [
      CardMenuItem(
        'preview',
        Icons.visibility_outlined,
        l10n.contractCardPreview,
      ),
      CardMenuItem(
        'delete_child',
        Icons.delete_outline,
        l10n.stageCardDeleteChild,
      ),
    ];
  }

  /// 构建单个角色的迷你卡片（母版或子版）。
  ///
  /// 对齐单角色 [ContractCard] 子版行的迷你卡片风格：
  ///   - 圆角内卡片背景 + 色板圆点 + 角色名 + 副标题 + ▶ + ⋮ 菜单
  Widget _buildRoleCard({
    required ThemeData theme,
    required AppLocalizations l10n,
    required Color roleColor,
    required String roleName,
    required String fileName,
    required bool isChild,
    required bool canInteract,
    required VoidCallback? onTap,
    required VoidCallback? onToggleSelect,
    required VoidCallback? onLongPress,
    required bool isSelected,
    required List<CardMenuItem> menuItems,
    required void Function(String action)? onMenu,
  }) {
    final textSecondary = AppTheme.textSecondary(theme.brightness);
    final labelText = isChild ? l10n.stageCardRoleChild(roleName) : roleName;
    final subtitleText = isChild
        ? l10n.stageCardRoleChildSubtitle
        : l10n.stageCardRoleMaster;

    return Container(
      margin: EdgeInsets.only(left: isChild ? 20 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: isSelected ? AppTheme.gold : roleColor.withValues(alpha: 0.15),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        onTap: onToggleSelect ?? onTap,
        onLongPress: isSelectMode ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              // 前导：多选模式显示 Checkbox，普通模式显示色点
              if (isSelectMode) ...[
                SelectCheckbox(
                  isSelected: isSelected,
                  brightness: theme.brightness,
                ),
                const SizedBox(width: 10),
              ] else ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isChild
                        ? roleColor.withValues(alpha: 0.5)
                        : roleColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // 标题 + 副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labelText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 角色行 ⋮ 菜单（普通模式显示）
              if (canInteract && onMenu != null && menuItems.isNotEmpty)
                buildCardMenu(
                  menuItems: menuItems,
                  onSelected: onMenu,
                  tooltip: l10n.contractCardOperations,
                  iconSize: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 舞台行 ⋮ 操作菜单（续玩/重新开始/导出/重命名/删除）
  Widget _buildMenu(BuildContext context, AppLocalizations l10n) {
    return buildCardMenu(
      menuItems: [
        CardMenuItem(
          'enter',
          Icons.play_arrow_outlined,
          l10n.contractCardEnter,
        ),
        CardMenuItem('restart', Icons.restart_alt, l10n.stageCardRestart),
        CardMenuItem('export', Icons.archive_outlined, l10n.stageCardExport),
        CardMenuItem(
          'rename',
          Icons.drive_file_rename_outline,
          l10n.contractCardRename,
        ),
        CardMenuItem('delete', Icons.delete_outline, l10n.contractCardDelete),
      ],
      onSelected: onMenu!,
      tooltip: l10n.contractCardOperations,
    );
  }
}

/// 舞台列表区（首页聚合入口）
///
/// 支持与单角色契约卡一致的多选/批量删除：长按进入多选、勾选、批量删除。
/// 舞台多选集合与**展开状态**均由 home_screen 全局 [HomeSelectionController]
/// 维护（`expandedStages`），使长按舞台时能级联选中其内角色并自动展开。
class StageSection extends ConsumerWidget {
  /// 点击舞台卡片的回调
  final void Function(String dirPath) onStageTap;

  /// 长按舞台卡片回调（普通模式进入多选）
  final void Function(String dirPath)? onStageLongPress;

  /// 已展开的舞台目录路径集合（来自 HomeSelectionController）
  final Set<String> expandedStages;

  /// 切换舞台展开/收起回调（桥接到 HomeSelectionController）
  final ValueChanged<String>? onToggleStageExpanded;

  /// 多选模式下点击舞台卡片回调（切换选中）
  final void Function(String dirPath)? onStageToggleSelect;

  /// 舞台行「⋮ 菜单」操作回调
  final void Function(String dirPath, String action)? onStageMenu;

  /// 是否处于多选模式
  final bool isSelectMode;

  /// 指定舞台是否被选中
  final bool Function(String dirPath)? isStageSelected;

  /// 点击舞台内某角色的回调（按角色选择母版/子版入口）
  final void Function(String stagePath, String roleName, {bool restoreSave})?
  onRoleTap;

  /// 舞台内角色行 ⋮ 菜单回调（删除角色卡 / 删除存档）。
  ///
  /// 参数为 舞台路径 + 角色名 + 角色卡文件名 + 操作名；删除时必须
  /// 使用角色卡文件名定位目标 .meph 文件（角色名与文件名不一定一致）。
  final void Function(
    String stagePath,
    String roleName,
    String fileName,
    String action,
  )?
  onRoleMenu;

  /// 多选模式下点击角色卡回调（切换角色选中状态）。
  ///
  /// 参数为 舞台路径 + 角色名 + 角色卡文件名 + 是否子版。
  final void Function(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild,
  })?
  onRoleToggleSelect;

  /// 普通模式长按角色卡回调（进入多选并选中该角色）。
  ///
  /// 参数为 舞台路径 + 角色名 + 角色卡文件名 + 是否子版。
  final void Function(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild,
  })?
  onRoleLongPress;

  /// 多选模式下指定角色是否被选中（母版/子版分别查询）。
  ///
  /// 参数为 舞台路径 + 角色名 + 角色卡文件名 + 是否子版。
  final bool Function(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild,
  })?
  isRoleSelected;

  const StageSection({
    super.key,
    required this.onStageTap,
    required this.expandedStages,
    this.onToggleStageExpanded,
    this.onStageLongPress,
    this.onStageToggleSelect,
    this.onStageMenu,
    this.isSelectMode = false,
    this.isStageSelected,
    this.onRoleTap,
    this.onRoleMenu,
    this.onRoleToggleSelect,
    this.onRoleLongPress,
    this.isRoleSelected,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              leadingIcon: Icons.theater_comedy,
              title: l10n.homeStageSectionTitle,
              count: stages.length,
            ),
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
                isExpanded: expandedStages.contains(stage.path),
                onToggleExpanded: onToggleStageExpanded == null
                    ? null
                    : () => onToggleStageExpanded!(stage.path),
                onRoleTap: onRoleTap == null
                    ? null
                    : (roleName, {restoreSave = false}) => onRoleTap!(
                        stage.path,
                        roleName,
                        restoreSave: restoreSave,
                      ),
                onRoleMenu: onRoleMenu == null
                    ? null
                    : (roleName, fileName, action) => onRoleMenu!(
                        stage.path,
                        roleName,
                        fileName,
                        action,
                      ),
                onRoleToggleSelect: onRoleToggleSelect == null
                    ? null
                    : (roleName, fileName, {isChild = false}) =>
                          onRoleToggleSelect!(
                            stage.path,
                            roleName,
                            fileName,
                            isChild: isChild,
                          ),
                onRoleLongPress: onRoleLongPress == null
                    ? null
                    : (roleName, fileName, {isChild = false}) =>
                          onRoleLongPress!(
                            stage.path,
                            roleName,
                            fileName,
                            isChild: isChild,
                          ),
                isRoleSelected: isRoleSelected == null
                    ? null
                    : (roleName, fileName, {isChild = false}) =>
                          isRoleSelected!(
                            stage.path,
                            roleName,
                            fileName,
                            isChild: isChild,
                          ),
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

/// 带元数据加载的舞台卡片
///
/// 通过 `stageProvider(stage.path)` 异步加载角色名列表 + `stageLastModifiedProvider`
/// 缓存读取最近活动时间。加载完成前显示基础卡片（无预览），不阻塞列表渲染。
///
/// 使用 Riverpod 缓存替代原先的 `FutureBuilder`（每次 build 重新发起磁盘
/// mtime 读取）：多选切换等父级重建不再触发无效 IO；舞台列表刷新时
/// 通过 `invalidate(stageListProvider)` 一并失效缓存。
class StageCardWithMeta extends ConsumerWidget {
  final StageInfo stage;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final ValueChanged<String>? onMenu;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final void Function(String roleName, {bool restoreSave})? onRoleTap;
  final void Function(String roleName, String fileName, String action)?
      onRoleMenu;
  final void Function(String roleName, String fileName, {bool isChild})?
      onRoleToggleSelect;
  final void Function(String roleName, String fileName, {bool isChild})?
      onRoleLongPress;
  final bool Function(String roleName, String fileName, {bool isChild})?
      isRoleSelected;

  const StageCardWithMeta({
    super.key,
    required this.stage,
    required this.onTap,
    this.onLongPress,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.onMenu,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.onRoleTap,
    this.onRoleMenu,
    this.onRoleToggleSelect,
    this.onRoleLongPress,
    this.isRoleSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageAsync = ref.watch(stageProvider(stage.path));
    final characters = stageAsync.value?.characters ?? const <StageCharacter>[];
    final roleNames = characters.map((c) => c.roleName).toList();
    // 角色名 → 角色卡文件名映射（删除角色/存档时直接使用文件名定位）
    final roleFileNames = {
      for (final c in characters) c.roleName: c.fileName,
    };
    // 有存档的角色名集合（来自 loadStage 探测的 hasSave）
    final savedRoleNames = {
      for (final c in characters)
        if (c.hasSave) c.roleName,
    };

    // 最近活动时间：由 Riverpod 缓存（无监听时释放，刷新舞台列表时一并失效）
    final lastModifiedAsync = ref.watch(stageLastModifiedProvider(stage.path));

    return StageCard(
      info: stage,
      roleNames: roleNames,
      roleFileNames: roleFileNames,
      savedRoleNames: savedRoleNames,
      lastModified: lastModifiedAsync.value,
      onTap: onTap,
      onLongPress: onLongPress,
      isSelectMode: isSelectMode,
      isSelected: isSelected,
      onToggleSelect: onToggleSelect,
      onMenu: onMenu,
      isExpanded: isExpanded,
      onToggleExpanded: onToggleExpanded,
      onRoleTap: onRoleTap,
      onRoleMenu: onRoleMenu,
      onRoleToggleSelect: onRoleToggleSelect,
      onRoleLongPress: onRoleLongPress,
      isRoleSelected: isRoleSelected,
    );
  }
}
