import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/app/theme.dart';

/// AppTheme 主题测试
///
/// 覆盖 v1.4.1 的 TextTheme 缺口回归：
///   - 此前 `_buildTheme` 用整体替换的 `TextTheme(7 角色)` 定义文字主题，
///     `titleLarge` / `titleMedium` 未定义 → 为 null，
///     所有 `theme.textTheme.titleLarge?.copyWith(...)` 链因 `?.` 短路
///     而静默失效（品牌标题/设置页标题/抽屉标题样式丢失）。
///   - 本测试断言亮/暗主题下这些角色均非 null 且基本属性生效。
void main() {
  group('AppTheme.textTheme 完整性', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('$brightness：titleLarge / titleMedium 非 null（样式不丢失）', () {
        final theme = AppTheme.of(brightness);

        final titleLarge = theme.textTheme.titleLarge;
        expect(titleLarge, isNotNull, reason: 'titleLarge 此前为 null，样式被 ?. 短路');
        expect(titleLarge!.fontSize, 20);
        expect(titleLarge.fontWeight, FontWeight.bold);

        final titleMedium = theme.textTheme.titleMedium;
        expect(
          titleMedium,
          isNotNull,
          reason: 'titleMedium 此前为 null，样式被 ?. 短路',
        );
        expect(titleMedium!.fontSize, 16);

        // 既有 7 角色保持定义（回归保护）
        expect(theme.textTheme.bodyLarge, isNotNull);
        expect(theme.textTheme.bodyMedium, isNotNull);
        expect(theme.textTheme.bodySmall, isNotNull);
        expect(theme.textTheme.titleSmall, isNotNull);
        expect(theme.textTheme.labelLarge, isNotNull);
        expect(theme.textTheme.labelMedium, isNotNull);
        expect(theme.textTheme.labelSmall, isNotNull);
      });

      test('$brightness：textTheme 颜色随明暗联动（textPrimary 正确）', () {
        final theme = AppTheme.of(brightness);
        final expected = brightness == Brightness.dark
            ? AppTheme.darkTextPrimary
            : AppTheme.lightTextPrimary;
        expect(theme.textTheme.titleLarge!.color, expected);
        expect(theme.textTheme.bodyMedium!.color, expected);
      });
    }

    test('亮/暗主题实例缓存（AppTheme.of 返回同一实例）', () {
      // ThemeData 构造是重量级操作；实例应被缓存避免每次 build 重建
      final light1 = AppTheme.of(Brightness.light);
      final light2 = AppTheme.of(Brightness.light);
      final dark1 = AppTheme.of(Brightness.dark);
      final dark2 = AppTheme.of(Brightness.dark);
      expect(identical(light1, light2), isTrue, reason: '亮主题应缓存为单例');
      expect(identical(dark1, dark2), isTrue, reason: '暗主题应缓存为单例');
      expect(identical(light1, dark1), isFalse);
    });
  });
}
