import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../providers/narrative_memory_provider.dart';
import 'radio_selection_tile.dart';
import 'section_card.dart';

/// 记忆注入上限选择区块
///
/// 控制每轮发送给 LLM 的记忆条数上限，平衡 token 消耗与叙事连续性。
/// 从 settings_screen.dart 拆分而来，风格与其余设置区块一致。
class NarrativeMemorySection extends ConsumerWidget {
  const NarrativeMemorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentLimit = ref.watch(narrativeMemoryLimitProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsMemoryLimitDescription,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),

        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final limit in NarrativeMemoryLimit.values) ...[
                RadioSelectionTile(
                  icon: switch (limit) {
                    // 书卷渐进：档位越高，书卷/魔力感越盛（契合浮士德契约风格）
                    NarrativeMemoryLimit.compact => Icons.bookmark_border,
                    NarrativeMemoryLimit.standard => Icons.menu_book_outlined,
                    NarrativeMemoryLimit.extended => Icons.auto_stories_outlined,
                    NarrativeMemoryLimit.full => Icons.auto_awesome,
                  },
                  // 档位文案走 ARB 国际化（10 条 / 20 条 / 30 条 / 全部注入）
                  label: switch (limit) {
                    NarrativeMemoryLimit.compact =>
                      l10n.settingsMemoryLimitCompact,
                    NarrativeMemoryLimit.standard =>
                      l10n.settingsMemoryLimitStandard,
                    NarrativeMemoryLimit.extended =>
                      l10n.settingsMemoryLimitExtended,
                    NarrativeMemoryLimit.full => l10n.settingsMemoryLimitFull,
                  },
                  selected: currentLimit == limit,
                  onTap: () =>
                      ref.read(narrativeMemoryLimitProvider.notifier).setLimit(limit),
                ),
                if (limit != NarrativeMemoryLimit.values.last)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}