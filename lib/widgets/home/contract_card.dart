import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../providers/contract_provider.dart';
import '../contract_menu_item.dart';

/// 契约卡片（母版卡片，内嵌可展开子版区）
///
/// 展示单个母版契约的角色名和文件名。
/// 母版行和子版行拥有**完全一致的 UI 和交互**（唯一区别是层级缩进和分支标签）：
///   - 普通模式：点击行进入叙事，右下 ⋮ 操作菜单
///   - 多选模式：左侧显示单选框（☑/○），点击行切换选中
///
/// 若该母版存在子版（存档分支），母版行显示展开箭头「▾ N」，
/// 点击展开后以缩进列表形式展示子版（层级区分母版/子版）。
class ContractCard extends StatelessWidget {
  /// 母版契约信息
  final ContractInfo info;

  /// 该母版下的子版列表
  final List<ContractInfo> children;

  /// 子版区是否展开
  final bool childrenExpanded;

  /// 点击展开/收起子版区
  final VoidCallback onToggleChildren;

  /// 是否处于多选模式
  final bool isSelectMode;

  /// 母版是否被选中（多选模式下）
  final bool isMasterSelected;

  /// 子版选中状态映射（fileName → 是否选中）
  final Map<String, bool> childSelection;

  /// 单击母版回调（多选模式切换选中 / 普通模式进入叙事）
  final VoidCallback onMasterTap;

  /// 长按母版回调（普通模式级联进入多选并选中母版+子版）
  final VoidCallback onMasterLongPress;

  /// 母版行「⋮ 菜单」操作回调（参数为操作名）
  final ValueChanged<String> onMasterMenu;

  /// 点击子版回调（多选模式切换选中 / 普通模式进入对应分支）
  final ValueChanged<ContractInfo> onChildTap;

  /// 长按子版回调（普通模式单独进入多选并选中该子版）
  final ValueChanged<ContractInfo> onChildLongPress;

  /// 子版行「⋮ 菜单」操作回调（参数为 子版信息 + 操作名）
  final void Function(ContractInfo child, String action) onChildMenu;

  const ContractCard({
    super.key,
    required this.info,
    required this.children,
    required this.childrenExpanded,
    required this.onToggleChildren,
    required this.isSelectMode,
    required this.isMasterSelected,
    required this.childSelection,
    required this.onMasterTap,
    required this.onMasterLongPress,
    required this.onMasterMenu,
    required this.onChildTap,
    required this.onChildLongPress,
    required this.onChildMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: isMasterSelected
            ? const BorderSide(color: AppTheme.gold, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          // ---- 母版行（与子版行交互一致） ----
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            onTap: onMasterTap,
            onLongPress: onMasterLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  // 多选模式：显示单选框（与子版行一致）
                  if (isSelectMode) ...[
                    Icon(
                      isMasterSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isMasterSelected
                          ? AppTheme.gold
                          : AppTheme.textSecondary(theme.brightness),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // 非多选模式：树根图标（命中「命运树」隐喻）
                  if (!isSelectMode) ...[
                    const Icon(
                      Icons.graphic_eq,
                      size: 16,
                      color: AppTheme.gold,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.roleName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          info.fileName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary(theme.brightness),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 子版展开/收起按钮（仅在存在子版时显示）
                  // 普通模式和多选模式都保留，方便多选时查看其他列表的子版
                  if (children.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        childrenExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: isSelectMode && !isMasterSelected
                            ? AppTheme.textSecondary(theme.brightness)
                            : AppTheme.gold,
                        size: 20,
                      ),
                      onPressed: onToggleChildren,
                      tooltip: childrenExpanded
                          ? AppLocalizations.of(context).contractCardCollapseChildren
                          : AppLocalizations.of(context).contractCardExpandChildren,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  // ⋮ 操作菜单（仅普通模式显示）
                  if (!isSelectMode) ...[
                    _buildMasterMenu(context),
                  ],
                ],
              ),
            ),
          ),

          // ---- 子版区（可展开，树状「枝桠」视觉 + 平滑生长动画）----
          if (childrenExpanded && children.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- 树状主干（贯穿子版区的金色竖直细线）----
                      // 竖线画在容器右缘，紧随其后的横枝从左缘起笔，
                      // 二者无缝衔接成「主干 → 横枝 → 叶」的连续折线
                      SizedBox(
                        width: 12,
                        child: CustomPaint(
                          painter: _TreeTrunkPainter(),
                          size: const Size(12, double.infinity),
                        ),
                      ),
                      // ---- 子版列表（每行前端是「横枝 + 圆点」） ----
                      Expanded(
                        child: Column(
                          children: [
                            for (final child in children) ...[
                              Row(
                                children: [
                                  // 横枝 + 圆点（连接主干与子版卡片）
                                  SizedBox(
                                    width: 14,
                                    height: 40,
                                    child: CustomPaint(
                                      painter: _TreeBranchPainter(),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: _ChildTile(
                                      child: child,
                                      isSelectMode: isSelectMode,
                                      isSelected:
                                          childSelection[child.fileName] ??
                                          false,
                                      onTap: () => onChildTap(child),
                                      onLongPress: () =>
                                          onChildLongPress(child),
                                      onMenuSelected: (action) =>
                                          onChildMenu(child, action),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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
    );
  }

  /// 母版行 ⋮ 操作菜单（进入/预览/编辑/重命名/删除）
  PopupMenuButton<String> _buildMasterMenu(BuildContext context) {
    return _buildContractMenu(
      iconColor: AppTheme.gold,
      iconSize: 18,
      onSelected: onMasterMenu,
      includeEdit: true,
      tooltip: AppLocalizations.of(context).contractCardOperations,
      l10n: AppLocalizations.of(context),
    );
  }
}

/// 子版条目（与母版行交互完全一致 + 缩进层级 + 分支标签）
///
/// 多选模式下显示与母版相同的单选框（☑/○），点击行切换选中。
/// 普通模式下显示分支箭头「→」，点击进入该子版叙事。
class _ChildTile extends StatelessWidget {
  final ContractInfo child;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<String> onMenuSelected;

  const _ChildTile({
    required this.child,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppTheme.gold.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // 多选模式：单选框（与母版行完全一致）
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
              // 普通模式：分支进入箭头
              if (!isSelectMode) ...[
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: AppTheme.gold,
                ),
                const SizedBox(width: 6),
              ],
              // 分支标签：命运一句话为主 + 分支名为副（并存显示）
              // 与文件名共享「有限弹性宽度」（3 : 2），
              // 两者各自 maxLines/ellipsis 真正生效、互不挤爆——
              // 命运描述过长在 3/5 宽度内省略号截断，文件名过长在 2/5 宽度内截断
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.branchTitle ?? child.branchName ?? 'child',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 命运一句话与分支名不同（如「命运：xxx」带分支名后缀）时，
                      // 以小字展示分支名，保留文件本身的命名信息
                      if (child.branchTitle != null &&
                          child.branchName != null &&
                          child.branchName!.isNotEmpty)
                        Text(
                          child.branchName!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary(theme.brightness),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              // 文件名：同样包在 Expanded 内（flex: 2），
              // 过长时在有限宽度内省略号截断，不再撑满整行或溢出卡片右缘
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        child.fileName,
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
              ),
              // ⋮ 操作菜单（进入/重命名/删除）—— 多选模式下也保留
              _buildChildMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 子版行 ⋮ 菜单（进入/预览/重命名/删除）
  PopupMenuButton<String> _buildChildMenu(BuildContext context) {
    return _buildContractMenu(
      iconColor: AppTheme.textSecondary(Theme.of(context).brightness),
      iconSize: 16,
      onSelected: onMenuSelected,
      includeEdit: false,
      tooltip: AppLocalizations.of(context).contractCardOperations,
      l10n: AppLocalizations.of(context),
    );
  }
}

/// 契约操作菜单（母版/子版共用）。
///
/// 母版菜单含「编辑」（[includeEdit] true），子版菜单不含。
/// 统一菜单结构与样式，消除两处几乎相同的 PopupMenuButton + itemBuilder 重复。
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

/// 树状主干画笔：绘制子版区贯穿到底的金色竖直细线。
///
/// 与每个子版行前的 [_TreeBranchPainter] 横枝相连，
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

/// 树状横枝画笔：绘制子版卡片前方的一截横枝 + 连接圆点。
///
/// 横枝从左侧主干处向右延伸到子版卡片，末端以一个金色小圆点
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
