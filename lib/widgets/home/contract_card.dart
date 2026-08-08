import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../providers/contract_provider.dart';
import '../contract_menu_item.dart';

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
/// 树状视觉：子节点区左侧画金色竖主干（[_TreeTrunkPainter]），
/// 每个子节点行前放横枝 + 圆点（[_TreeBranchPainter]），
/// 形成「母版为根 → 主干 → 横枝 → 叶」的连续折线。
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
    // 移动端紧凑模式：隐藏树状装饰、使用更小缩进，为窄屏让出更多横向空间。
    // 桌面端保留完整树状分支视觉。
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    // 缩进：移动端 8px（紧凑）；桌面端 12px（树状分级）。
    final indent = info.depth * (isMobile ? 8.0 : 12.0);

    return Container(
      margin: EdgeInsets.only(left: indent),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: isSelected
              ? const BorderSide(color: AppTheme.gold, width: 2)
              : BorderSide.none,
        ),
        child: Column(
          children: [
            // ---- 当前节点行 ----
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 16,
                  vertical: isMobile ? 4 : 6,
                ),
                child: Row(
                  children: [
                    // 多选模式：显示单选框
                    if (isSelectMode) ...[
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? AppTheme.gold
                            : AppTheme.textSecondary(theme.brightness),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // 非多选模式：树根图标（母版用根，子版用枝点）
                    if (!isSelectMode) ...[
                      Icon(
                        info.depth == 0 ? Icons.graphic_eq : Icons.circle,
                        size: info.depth == 0 ? 16 : 8,
                        color: AppTheme.gold,
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                    ],
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 母版根显示角色名；子版不重复显示（与母版相同），
                          // 只展示分支信息 + 文件名
                          if (info.depth == 0)
                            Text(
                              info.roleName,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          // 分支信息：命运一句话为主 + 分支名为副（仅子版有）
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
                            // 命运一句话与分支名不同（如「命运：xxx」带分支名后缀）时，
                            // 以小字展示分支名，保留文件本身的命名信息
                            if (info.branchTitle != null)
                              Text(
                                info.branchName!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textSecondary(
                                    theme.brightness,
                                  ),
                                  fontSize: 10,
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
                      ),
                    ),
                    // 子节点展开/收起按钮（仅存在子节点时显示）
                    if (group.hasChildren)
                      IconButton(
                        icon: Icon(
                          childrenExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        onPressed: () => onToggleNode(info.fileName),
                        tooltip: childrenExpanded
                            ? AppLocalizations.of(context)
                                .contractCardCollapseChildren
                            : AppLocalizations.of(context)
                                .contractCardExpandChildren,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    // ⋮ 操作菜单（仅普通模式显示）
                    if (!isSelectMode) ...[
                      _buildNodeMenu(context),
                    ],
                  ],
                ),
              ),
            ),

            // ---- 子节点区 ----
            // 桌面端：树状主干 + 横枝装饰，形成「命运树」折线视觉。
            // 移动端：隐藏树装饰，仅用圆点引导，最大化释放窄屏横向空间。
            if (childrenExpanded && group.hasChildren)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    isMobile ? 8 : 16,
                    isMobile ? 8 : 14,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ---- 树状主干（仅桌面端显示；贯穿子节点区的金色竖直细线）----
                        if (!isMobile) ...[
                          SizedBox(
                            width: 24,
                            child: CustomPaint(
                              painter: _TreeTrunkPainter(),
                              size: const Size(24, double.infinity),
                            ),
                          ),
                        ],
                        // ---- 子节点列表 ----
                        Expanded(
                          child: Column(
                            children: [
                              for (final child in group.children) ...[
                                Row(
                                  children: [
                                    // 横枝 + 圆点（仅桌面端显示；连接主干与子节点）
                                    if (!isMobile) ...[
                                      SizedBox(
                                        width: 32,
                                        height: 40,
                                        child: CustomPaint(
                                          painter: _TreeBranchPainter(),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ] else ...[
                                      // 移动端：紧凑圆点引导
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: AppTheme.gold,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
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
                                        onTap: () =>
                                            onChildTap(child.master),
                                        onLongPress: () =>
                                            onChildLongPress(child.master),
                                        onMenu: (action) =>
                                            onChildMenu(
                                              child.master,
                                              action,
                                            ),
                                        onChildTap: onChildTap,
                                        onChildLongPress: onChildLongPress,
                                        onChildMenu: onChildMenu,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isMobile ? 4 : 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 节点行 ⋮ 操作菜单（进入/预览/编辑/重命名/删除）
  PopupMenuButton<String> _buildNodeMenu(BuildContext context) {
    return _buildContractMenu(
      iconColor: AppTheme.gold,
      iconSize: 18,
      onSelected: onMenu,
      includeEdit: group.master.depth == 0,
      tooltip: AppLocalizations.of(context).contractCardOperations,
      l10n: AppLocalizations.of(context),
    );
  }
}

/// 契约操作菜单（母版/子版共用）。
///
/// 母版菜单含「编辑」（[includeEdit] true），子版菜单不含。
/// 统一菜单结构与样式，消除多处几乎相同的 PopupMenuButton + itemBuilder 重复。
PopupMenuButton<String> _buildContractMenu({
  required Color iconColor,
  required double iconSize,
  required ValueChanged<String> onSelected,
  required bool includeEdit,
  required String tooltip,
  required AppLocalizations l10n,
}) {
  return PopupMenuButton<String>(
    icon: Icon(Icons.more_vert, size: iconSize, color: iconColor),
    tooltip: tooltip,
    onSelected: onSelected,
    // 缩短动画时长，菜单弹出更快更流畅（共享样式见 AppTheme.popupAnimationStyle）
    popUpAnimationStyle: AppTheme.popupAnimationStyle,
    itemBuilder: (context) => [
      ContractMenuItem('enter', Icons.play_arrow_outlined, l10n.contractCardEnter),
      ContractMenuItem('preview', Icons.visibility_outlined, l10n.contractCardPreview),
      if (includeEdit)
        ContractMenuItem('edit', Icons.edit_outlined, l10n.contractCardEdit),
      ContractMenuItem('rename', Icons.drive_file_rename_outline, l10n.contractCardRename),
      ContractMenuItem('delete', Icons.delete_outline, l10n.contractCardDelete),
    ],
  );
}

/// 树状主干画笔：绘制子节点区贯穿到底的金色竖直细线。
///
/// 与每个子节点行前的 [_TreeBranchPainter] 横枝相连，
/// 形成「命运树」的枝干视觉——母版为根，子版为枝。
class _TreeTrunkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 顶部留 6px 空隙，底部贯穿至卡片下边距（视觉上「向下生长」）
    const startY = 6.0;
    final endY = size.height - 6;
    if (endY <= startY) return;

    // 竖直主干：贴近右缘绘制，使横枝（紧随其后的 x=0 起笔）与之无缝相接
    final trunkX = size.width - 2;
    canvas.drawLine(
      Offset(trunkX, startY),
      Offset(trunkX, endY),
      paint,
    );

    // 主干底部收束小圆点（枝干生长端）
    canvas.drawCircle(
      Offset(trunkX, endY),
      2.5,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TreeTrunkPainter oldDelegate) => false;
}

/// 树状横枝画笔：绘制子节点卡片前的一截横枝 + 连接圆点。
///
/// 横枝从左侧主干处向右延伸到子节点卡片，末端以一个金色小圆点
/// 作为「枝桠生长点」——每个子版就是命运之树上的一根枝。
class _TreeBranchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 水平横枝：从左缘向右延伸（到卡片边缘附近）
    final midY = size.height / 2;
    const startX = 0.0;
    final endX = size.width - 2;
    canvas.drawLine(
      Offset(startX, midY),
      Offset(endX, midY),
      paint,
    );

    // 枝桠生长点（卡片侧的圆点）
    canvas.drawCircle(
      Offset(endX, midY),
      2.5,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) => false;
}