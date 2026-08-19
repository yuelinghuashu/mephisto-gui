import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../providers/providers.dart';
import 'radio_selection_tile.dart';
import 'section_card.dart';

/// 界面语言设置区块：简体中文 / English
///
/// 从原 [AppearanceSection] 拆出，使「界面语言（本地化）」与
/// 「主题（视觉）」成为独立设置分区，语义清晰。
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          RadioSelectionTile(
            icon: Icons.translate,
            label: l10n.languageChinese,
            selected: ref.watch(languageProvider) == 'zh',
            onTap: () => ref.read(languageProvider.notifier).setLanguage('zh'),
          ),
          const Divider(height: 1),
          RadioSelectionTile(
            icon: Icons.language,
            label: l10n.languageEnglish,
            selected: ref.watch(languageProvider) == 'en',
            onTap: () => ref.read(languageProvider.notifier).setLanguage('en'),
          ),
        ],
      ),
    );
  }
}
