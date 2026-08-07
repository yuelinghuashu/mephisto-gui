import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

/// 首页空状态：没有找到任何契约
class HomeEmptyState extends StatelessWidget {
  /// 恢复内置角色按钮的回调（为 null 时不显示恢复按钮）
  final Future<void> Function()? onRestoreBuiltin;

  /// 是否正在恢复内置角色（恢复期间按钮禁用，避免重复触发）
  final bool isRestoring;

  const HomeEmptyState({
    super.key,
    this.onRestoreBuiltin,
    this.isRestoring = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚜', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              l10n.emptyStateNoContract,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyStateDescription,
              style: theme.textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 恢复内置角色按钮（兜底：无论目录种子状态如何，强制复制缺失的内置模板）
            if (onRestoreBuiltin != null) ...[
              FilledButton.icon(
                onPressed: isRestoring ? null : onRestoreBuiltin,
                icon: isRestoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore),
                label: Text(
                  isRestoring ? l10n.emptyStateRestoring : l10n.emptyStateRestoreBuiltin,
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 前往设置按钮（引导用户配置契约目录）
            OutlinedButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: Text(l10n.emptyStateGoSettings),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 首页错误状态：加载契约失败
class HomeErrorState extends StatelessWidget {
  /// 错误信息
  final Object error;

  const HomeErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚚', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).emptyStateLoadFail,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}