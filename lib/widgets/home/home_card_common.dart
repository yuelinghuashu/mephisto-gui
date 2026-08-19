import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 卡片多选模式下的单选框（契约卡 / 舞台卡共用）。
///
/// 选中时显示金色实心勾选圆，未选中显示描边圆框。仅多选模式显示，
/// 由父级通过 `isSelectMode` 控制是否渲染。
class SelectCheckbox extends StatelessWidget {
  final bool isSelected;
  final Brightness brightness;

  const SelectCheckbox({
    super.key,
    required this.isSelected,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
      color: isSelected ? AppTheme.gold : AppTheme.textSecondary(brightness),
    );
  }
}

/// 卡片展开/收起箭头按钮（契约卡子节点区 / 舞台角色列表共用）。
///
/// 展开时显示 `expand_less`（收起），收起时显示 `expand_more`（展开）。
/// 统一的压缩尺寸（无默认 48px 最小点击区），避免撑大卡片行高。
class ExpandArrow extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onPressed;
  final String tooltip;

  const ExpandArrow({
    super.key,
    required this.isExpanded,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isExpanded ? Icons.expand_less : Icons.expand_more,
        color: AppTheme.gold,
        size: 20,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }
}

/// 首页卡片统一外壳：统一 ContractCard（单角色契约树）与 StageCard
/// （多角色舞台聚合）之间的共同骨架。
///
/// 两种卡片在视觉上共享同一套「卡片容器 + 主行 + 展开区」结构：
///   - 统一圆角（[AppTheme.radiusLarge]）、边框、内边距
///   - 主行 = 前导内容（[leading]）+ 标题列（[titleColumn]）+ 尾部（[trailing]）
///   - 展开区 = 顶部金色分割线 + 自定义内容
///
/// 点击/长按逻辑自动处理多选模式：
///   - 普通模式 → [onTap] / [onLongPress]
///   - 多选模式 → [onToggleSelect]（前导内容自动切换为 SelectCheckbox）
///
/// 调用方只需提供内容组件，外壳统一处理视觉容器与交互分发。
class HomeCardShell extends StatelessWidget {
  /// 是否处于多选模式（多选时自动切换点击行为 + 前导显示 Checkbox）
  final bool isSelectMode;

  /// 多选模式下是否被选中
  final bool isSelected;

  /// 普通模式点击回调（进入叙事）
  final VoidCallback onTap;

  /// 长按回调（普通模式进入多选）
  final VoidCallback? onLongPress;

  /// 多选模式下点击回调（切换选中）
  final VoidCallback? onToggleSelect;

  /// 是否显示展开区
  final bool isExpanded;

  /// 展开区内容（卡片下方，顶部带分割线；null 时不渲染）
  final Widget? expandedContent;

  /// 非展开时显示在主行下方的内容（如 StageCard 的角色名预览行）。
  ///
  /// 仅当 [isExpanded] 为 false 时渲染；不传则不显示。
  final Widget? collapsedContent;

  /// 主行内边距（移动端紧凑时可传小值）
  final EdgeInsetsGeometry padding;

  /// 非选中状态下的边框（ContractCard 树内节点无边框，StageCard 有金色描边）
  final BorderSide? normalBorderSide;

  /// 普通模式下的前导内容（多选模式由 SelectCheckbox 替换）。
  ///
  /// 传 null 时普通模式也不渲染前导区域。
  final Widget? leading;

  /// 主行中间的标题信息（Expanded 自动填充剩余宽度）
  final Widget titleColumn;

  /// 主行最右侧的可选内容（展开箭头 / ⋮ 菜单等）
  final Widget? trailing;

  /// 前导内容与标题列之间的间距（默认与展开箭头一致）
  final double leadingSpacing;

  const HomeCardShell({
    super.key,
    required this.isSelectMode,
    required this.isSelected,
    this.isExpanded = false,
    this.onTap = _noopOrIgnore,
    this.onLongPress,
    this.onToggleSelect,
    this.expandedContent,
    this.collapsedContent,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.normalBorderSide,
    this.leading,
    required this.titleColumn,
    this.trailing,
    this.leadingSpacing = 12,
  });

  static void _noopOrIgnore() {}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: isSelected
            ? const BorderSide(color: AppTheme.gold, width: 2)
            : (normalBorderSide ?? BorderSide.none),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- 主行 ----
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            onTap: isSelectMode ? onToggleSelect : onTap,
            onLongPress: isSelectMode ? null : onLongPress,
            child: Padding(
              padding: padding,
              child: Row(
                children: [
                  // 多选模式：自动显示 SelectCheckbox
                  if (isSelectMode) ...[
                    SelectCheckbox(
                      isSelected: isSelected,
                      brightness: theme.brightness,
                    ),
                    SizedBox(width: leadingSpacing),
                  ] else if (leading != null) ...[
                    // 普通模式：调用方自定义前导内容
                    leading!,
                    SizedBox(width: leadingSpacing),
                  ],
                  // 标题列（自动填充剩余宽度）
                  Expanded(child: titleColumn),
                  // 尾部（展开箭头 / ⋮ 菜单等）
                  ?trailing,
                ],
              ),
            ),
          ),

          // ---- 非展开态附加内容（如角色预览）----
          if (!isExpanded && collapsedContent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: collapsedContent,
              ),
            ),

          // ---- 展开区：顶部分割线 + 自定义内容 ----
          if (isExpanded && expandedContent != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.divider(
                        theme.brightness,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: expandedContent,
              ),
            ),
        ],
      ),
    );
  }
}
