import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import 'relative_time.dart';

/// 首页「最近编辑」快捷入口的统一数据模型。
///
/// 既可以是单角色契约（[label] = 角色名，点击进入叙事页），
/// 也可以是多角色舞台（[label] = 舞台名，点击进入舞台叙事页）。
/// 由 [HomeScreen] 在合并「契约 + 舞台」两侧最近活动后构造并传入。
class RecentEditEntry {
  /// 展示标签：契约 → 角色名；舞台 → 舞台名。
  final String label;

  /// 最近活动时间（契约文件的 mtime 或舞台目录内最大 mtime）。
  final DateTime? lastModified;

  /// 点击进入对应叙事页的回调。
  final VoidCallback? onTap;

  const RecentEditEntry({
    required this.label,
    required this.lastModified,
    required this.onTap,
  });
}

/// 首页品牌展示区
///
/// 展示「Mephisto 叙事引擎」标题 + 副标题 + 右下角「最近编辑」快捷入口。
/// 仅用于首页契约列表顶部，多选模式下由调用方决定是否隐藏。
///
/// 「最近编辑」胶囊：显示最近修改过的条目（单角色契约的角色名，
/// 或多角色舞台的舞台名 + 相对时间），点击直接进入对应叙事页——
/// 无论列表折叠得多深/滚动到哪里，进入首页就能一眼看到
/// 「最近在玩哪个」并一步直达。
class HomeBrandHeader extends StatelessWidget {
  /// 最近编辑入口（契约或舞台）；null 时不显示快捷入口。
  final RecentEditEntry? recentEntry;

  const HomeBrandHeader({
    super.key,
    this.recentEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final recent = recentEntry;
    final lastModified = recent?.lastModified;
    // 相对时间文本（null 表示无 mtime，不显示入口）
    final timeText = lastModified == null
        ? null
        : formatRelativeTime(lastModified, l10n);
    // 同时满足「有最近编辑 + 有 mtime + 有回调」时才显示胶囊
    final showChip = recent != null && timeText != null && recent.onTap != null;

    // 标题 + 最近编辑入口（同一行，右对齐）
    // 收敛：26pt 大标题 → 20pt，副标题缩为更紧凑的小字，整体高度降低。
    final header = Row(
      children: [
        Expanded(
          child: Text(
            l10n.homeBrandTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
              fontSize: 20,
            ),
          ),
        ),
        // 最近编辑快捷入口（金色胶囊按钮）
        if (showChip)
          _buildRecentChip(
            context,
            label: recent.label,
            timeText: timeText,
            onTap: recent.onTap,
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 2),
        Text(
          l10n.homeBrandSubtitle,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 金色胶囊：「🕐 标签 · 相对时间」
  Widget _buildRecentChip(
    BuildContext context, {
    required String label,
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
              '$label · $timeText',
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