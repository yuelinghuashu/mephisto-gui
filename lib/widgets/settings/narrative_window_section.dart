import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../providers/narrative_window_provider.dart';
import 'radio_selection_tile.dart';
import 'section_card.dart';

/// 历史消息窗口选择区块
///
/// 控制发送给 LLM 的历史对话条数上限，平衡 token 消耗与上下文记忆。
/// 从 settings_screen.dart 拆分而来，风格与其余设置区块一致。
class NarrativeWindowSection extends ConsumerWidget {
  const NarrativeWindowSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentWindow = ref.watch(narrativeWindowProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsHistoryWindowDescription,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),

        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final window in NarrativeWindow.values) ...[
                RadioSelectionTile(
                  icon: switch (window) {
                    NarrativeWindow.narrow => Icons.filter_1,
                    NarrativeWindow.medium => Icons.filter_2,
                    NarrativeWindow.wide => Icons.filter_3,
                    NarrativeWindow.full => Icons.all_inclusive,
                  },
                  // 档位文案走 ARB 国际化（20 条 / 40 条 / 60 条 / 全部发送）
                  label: switch (window) {
                    NarrativeWindow.narrow => l10n.settingsHistoryWindowNarrow,
                    NarrativeWindow.medium => l10n.settingsHistoryWindowMedium,
                    NarrativeWindow.wide => l10n.settingsHistoryWindowWide,
                    NarrativeWindow.full => l10n.settingsHistoryWindowFull,
                  },
                  selected: currentWindow == window,
                  onTap: () =>
                      ref.read(narrativeWindowProvider.notifier).setWindow(window),
                ),
                if (window != NarrativeWindow.values.last)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}