import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'contract_menu_item.dart';

/// 卡片「⋮ 菜单」项定义：菜单值 + 图标 + 标签。
///
/// 供首页契约卡 / 舞台卡 / 叙事页共用，统一菜单项结构。
class CardMenuItem {
  final String value;
  final IconData icon;
  final String label;

  const CardMenuItem(this.value, this.icon, this.label);
}

/// 构建轻量卡片「⋮ 菜单」的共享工具。
///
/// 首页 [ContractCard]（单角色契约树）与 [StageCard]（多角色舞台）
/// 的菜单结构高度重复（PopupMenuButton + ContractMenuItem + 金色图标 +
/// 共享动画样式）。本函数统一构建，调用方只需传入菜单项列表。
///
/// 参数：
///   - [menuItems]：菜单项列表（值 / 图标 / 标签）
///   - [onSelected]：菜单项选中回调（参数为菜单值）
///   - [tooltip]：菜单按钮的悬浮提示（通常为「操作」）
///   - [iconColor] / [iconSize]：菜单图标颜色/大小（默认真金 + 18）
PopupMenuButton<String> buildCardMenu({
  required List<CardMenuItem> menuItems,
  required ValueChanged<String> onSelected,
  required String tooltip,
  Color? iconColor,
  double iconSize = 18,
}) {
  return PopupMenuButton<String>(
    icon: Icon(Icons.more_vert, size: iconSize, color: iconColor ?? AppTheme.gold),
    tooltip: tooltip,
    onSelected: onSelected,
    // 缩短动画时长，菜单弹出更快更流畅（共享样式见 AppTheme.popupAnimationStyle）
    popUpAnimationStyle: AppTheme.popupAnimationStyle,
    itemBuilder: (context) => [
      for (final item in menuItems)
        ContractMenuItem(item.value, item.icon, item.label),
    ],
  );
}
