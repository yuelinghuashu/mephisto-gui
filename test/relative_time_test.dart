import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:mephisto/l10n/app_localizations_zh.dart';
import 'package:mephisto/widgets/home/relative_time.dart';

/// 相对时间格式化测试
///
/// 覆盖分档边界：刚刚 / 分钟前 / 小时前 / 天前 / 旧日期（≥7 天显示 M/D）。
void main() {
  // 使用简体中文本地化（直接实例化生成的子类，跳过 BuildContext；
  // 默认 locale 即 zh，无需显式传入）
  final AppLocalizations l10n = AppLocalizationsZh();

  test('30 秒前 → 刚刚', () {
    final t = DateTime.now().subtract(const Duration(seconds: 30));
    expect(formatRelativeTime(t, l10n), '刚刚');
  });

  test('5 分钟前 → 5 分钟前', () {
    final t = DateTime.now().subtract(const Duration(minutes: 5));
    expect(formatRelativeTime(t, l10n), '5 分钟前');
  });

  test('59 分钟前 → 59 分钟前（未进小时档）', () {
    final t = DateTime.now().subtract(const Duration(minutes: 59));
    expect(formatRelativeTime(t, l10n), '59 分钟前');
  });

  test('3 小时前 → 3 小时前', () {
    final t = DateTime.now().subtract(const Duration(hours: 3));
    expect(formatRelativeTime(t, l10n), '3 小时前');
  });

  test('23 小时前 → 23 小时前（未进天档）', () {
    final t = DateTime.now().subtract(const Duration(hours: 23));
    expect(formatRelativeTime(t, l10n), '23 小时前');
  });

  test('2 天前 → 2 天前', () {
    final t = DateTime.now().subtract(const Duration(days: 2));
    expect(formatRelativeTime(t, l10n), '2 天前');
  });

  test('6 天前 → 6 天前（未进日期档）', () {
    final t = DateTime.now().subtract(const Duration(days: 6));
    expect(formatRelativeTime(t, l10n), '6 天前');
  });

  test('≥7 天前 → 具体日期（M/D）', () {
    final t = DateTime.now().subtract(const Duration(days: 10));
    final result = formatRelativeTime(t, l10n);
    // 应显示为「月/日」格式而非相对时间
    expect(result, '${t.month}/${t.day}');
  });
}