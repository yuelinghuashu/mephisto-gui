import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 设置页区块标题（金色衬线体 + 项目符号）
///
/// 从 settings_screen.dart 底部提取，供所有设置区块共用。
class SectionHeader extends StatelessWidget {
  final String icon;
  final String title;

  const SectionHeader({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '$icon  $title',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.gold,
      ),
    );
  }
}