import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';

/// 叙事空状态
///
/// 当消息列表为空且未在生成时显示，展示开局场景引导用户开始叙事。
class EmptyState extends StatelessWidget {
  /// 开局场景文本（已替换 {角色名} 占位符）
  final String opening;

  const EmptyState({super.key, required this.opening});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.emptyStateTitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 24,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.narrativeEmptyHint, style: theme.textTheme.labelLarge),
            if (opening.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.emptyStateOpening,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(opening, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
