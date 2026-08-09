import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../providers/contract_provider.dart';
import 'relative_time.dart';

/// 首页品牌展示区
///
/// 展示「Mephisto 叙事引擎」标题 + 副标题 + 右下角「最近编辑」快捷入口。
/// 仅用于首页契约列表顶部，多选模式下由调用方决定是否隐藏。
///
/// 「最近编辑」胶囊：显示最近修改过的契约（角色名 + 相对时间），
/// 点击直接进入该契约的叙事页——无论列表折叠得多深/滚动到哪里，
/// 进入首页就能一眼看到「最近在玩哪个」并一步直达。
class HomeBrandHeader extends StatelessWidget {
  /// 最近编辑的契约信息（具体文件，可能是子版）；null 时不显示快捷入口。
  final ContractInfo? recentInfo;

  /// 点击最近编辑入口的回调（进入叙事页）。
  final VoidCallback? onRecentTap;

  const HomeBrandHeader({
    super.key,
    this.recentInfo,
    this.onRecentTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final recent = recentInfo;
    final lastModified = recent?.lastModified;
    // 相对时间文本（null 表示无 mtime，不显示入口）
    final timeText = lastModified == null
        ? null
        : formatRelativeTime(lastModified, l10n);
    // 同时满足「有最近编辑 + 有 mtime + 有回调」时才显示胶囊
    final showChip =
        recent != null && timeText != null && onRecentTap != null;

    // 标题 + 最近编辑入口（同一行，右对齐）
    final header = Row(
      children: [
        Expanded(
          child: Text(
            l10n.homeBrandTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
              fontSize: 26,
            ),
          ),
        ),
        // 最近编辑快捷入口（金色胶囊按钮）
        if (showChip)
          _buildRecentChip(
            context,
            roleName: recent.roleName,
            timeText: timeText,
            onTap: onRecentTap,
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 4),
        Text(
          l10n.homeBrandSubtitle,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 金色胶囊：「🕐 角色名 · 相对时间」
  Widget _buildRecentChip(
    BuildContext context, {
    required String roleName,
    required String timeText,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 14, color: AppTheme.gold),
            const SizedBox(width: 4),
            Text(
              '$roleName · $timeText',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.gold,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}