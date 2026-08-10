import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 首页分区标题（多角色舞台 / 单角色契约）。
///
/// 用于在首页明确区分两类不同内容：
///   - 前导图标（[leadingIcon]）
///   - 金色加粗标题文本（[title]）
///   - 可选的项目计数徽标（[count]，null 时不显示）
///
/// 标题后绘制一条淡金色水平延伸线，强化分区边界。
class SectionHeader extends StatelessWidget {
  /// 前导图标
  final IconData leadingIcon;

  /// 分区标题文本
  final String title;

  /// 项目计数（null 时不显示计数徽标）
  final int? count;

  const SectionHeader({
    super.key,
    required this.leadingIcon,
    required this.title,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          Icon(leadingIcon, color: AppTheme.gold, size: 18),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          // 淡金色延伸线
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.gold.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}