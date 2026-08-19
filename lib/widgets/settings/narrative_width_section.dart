import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../providers/narrative_width_provider.dart';
import 'radio_selection_tile.dart';
import 'section_card.dart';

/// 叙事内容宽度选择区块
///
/// 桌面端阅读偏好：窄/中/宽/满屏四个档位。
/// 从 settings_screen.dart 拆分而来。
class NarrativeWidthSection extends ConsumerWidget {
  const NarrativeWidthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentWidth = ref.watch(narrativeWidthProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.settingsWidthDescription, style: theme.textTheme.labelLarge),
        const SizedBox(height: 12),

        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final width in NarrativeWidth.values) ...[
                RadioSelectionTile(
                  icon: switch (width) {
                    NarrativeWidth.narrow => Icons.smartphone,
                    NarrativeWidth.medium => Icons.book,
                    NarrativeWidth.wide => Icons.menu_book,
                    NarrativeWidth.full => Icons.photo_size_select_large,
                  },
                  // 档位文案走 ARB 国际化（Narrow / Medium / Wide / Full Screen）
                  label: switch (width) {
                    NarrativeWidth.narrow => l10n.settingsWidthNarrow,
                    NarrativeWidth.medium => l10n.settingsWidthMedium,
                    NarrativeWidth.wide => l10n.settingsWidthWide,
                    NarrativeWidth.full => l10n.settingsWidthFull,
                  },
                  selected: currentWidth == width,
                  onTap: () =>
                      ref.read(narrativeWidthProvider.notifier).setWidth(width),
                ),
                if (width != NarrativeWidth.values.last)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
