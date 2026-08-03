import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 复古风格选中项（金色圆形勾选 + 高亮文字）
///
/// 设置页统一的单选组件：
///   - 选中：金色实心圆点 + 金色加粗文字
///   - 未选中：灰色空心圆点 + 普通文字
///
/// 用于外观主题、叙事内容宽度、LLM 后端类型等单选场景，
/// 保持设置页整体风格一致。
class RadioSelectionTile extends StatelessWidget {
  /// 左侧图标
  final IconData icon;

  /// 选项文字
  final String label;

  /// 是否选中
  final bool selected;

  /// 点击回调
  final VoidCallback onTap;

  const RadioSelectionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(
        selected ? Icons.brightness_1 : Icons.circle_outlined,
        size: 18,
        color: selected
            ? AppTheme.gold
            : AppTheme.textSecondary(theme.brightness),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: selected ? AppTheme.gold : theme.textTheme.bodyMedium?.color,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
