import 'package:mephisto/l10n/app_localizations.dart';

/// 将时间格式化为可读的「相对时间」文本（如「刚刚 / 5 分钟前 / 3 小时前 / 2 天前」）。
///
/// 分档规则（均为向下取整）：
///   - < 1 分钟：刚刚
///   - < 1 小时：N 分钟前
///   - < 1 天：N 小时前
///   - < 7 天：N 天前
///   - ≥ 7 天：具体日期（M/D）
///
/// 供首页「最近编辑」快捷入口显示「浮士德 · 2 小时前」。
String formatRelativeTime(DateTime time, AppLocalizations l10n) {
  final diff = DateTime.now().difference(time);

  // < 1 分钟
  if (diff.inMinutes < 1) return l10n.relativeTimeJustNow;
  // < 1 小时
  if (diff.inHours < 1) return l10n.relativeTimeMinutesAgo(diff.inMinutes);
  // < 1 天
  if (diff.inDays < 1) return l10n.relativeTimeHoursAgo(diff.inHours);
  // < 7 天
  if (diff.inDays < 7) return l10n.relativeTimeDaysAgo(diff.inDays);
  // ≥ 7 天：显示具体日期（跨月/跨年场景也足够清晰）
  return '${time.month}/${time.day}';
}