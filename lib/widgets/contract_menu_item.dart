import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 轻量菜单项组件（替代 ListTile，降低弹出首帧构建开销）
///
/// 统一契约卡片和叙事页的 PopupMenu 菜单项样式：
///   - 金色图标 + 文字
///   - 直接基于 [PopupMenuItem] 构建，避免 ListTile 的额外开销
class ContractMenuItem extends PopupMenuItem<String> {
  ContractMenuItem(String value, IconData icon, String label, {super.key})
    : super(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.gold),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      );
}
