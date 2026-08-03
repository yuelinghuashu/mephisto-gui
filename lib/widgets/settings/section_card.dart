import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 设置页共享的「羊皮纸卡片」容器
///
/// 统一设置页各区块的卡片外观（surfaceVariant 背景 + 大圆角 + 裁剪），
/// 消除 settings_screen / llm_config_section 中多处重复的容器样式。
class SectionCard extends StatelessWidget {
  /// 卡片内容
  final Widget child;

  /// 内边距（默认 16）
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppTheme.surfaceVariant(theme.brightness),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}