import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../providers/providers.dart';
import 'radio_selection_tile.dart';
import 'section_card.dart';

/// 主题模式设置区块：跟随系统 / 亮色 / 暗色
///
/// 从原 [AppearanceSection] 拆出，使「主题（视觉）」与「界面语言（本地化）」
/// 成为独立设置分区，语义清晰。
class ThemeModeSection extends ConsumerWidget {
  const ThemeModeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          RadioSelectionTile(
            icon: Icons.brightness_auto_outlined,
            label: l10n.settingsThemeSystem,
            selected: themeMode == ThemeMode.system,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.system),
          ),
          const Divider(height: 1),
          RadioSelectionTile(
            icon: Icons.light_mode_outlined,
            label: l10n.settingsThemeLight,
            selected: themeMode == ThemeMode.light,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.light),
          ),
          const Divider(height: 1),
          RadioSelectionTile(
            icon: Icons.dark_mode_outlined,
            label: l10n.settingsThemeDark,
            selected: themeMode == ThemeMode.dark,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}