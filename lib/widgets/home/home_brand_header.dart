import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';

/// 首页品牌展示区
///
/// 展示「Mephisto 叙事引擎」标题和副标题。
/// 仅用于首页契约列表顶部，多选模式下由调用方决定是否隐藏。
class HomeBrandHeader extends StatelessWidget {
  const HomeBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).homeBrandTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.gold,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).homeBrandSubtitle,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}