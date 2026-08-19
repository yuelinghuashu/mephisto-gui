import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../providers/narrative_rule_provider.dart';
import 'section_card.dart';

/// 叙事规则设置区块：用户自定义输出约束（可编辑并持久化）
///
/// 从 settings_screen.dart 拆分而来。
class NarrativeRulesSection extends ConsumerStatefulWidget {
  const NarrativeRulesSection({super.key});

  @override
  ConsumerState<NarrativeRulesSection> createState() =>
      _NarrativeRulesSectionState();
}

class _NarrativeRulesSectionState extends ConsumerState<NarrativeRulesSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // 加载当前叙事规则到编辑框
    _controller = TextEditingController(text: ref.read(narrativeRuleProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 保存叙事规则
  Future<void> _saveNarrativeRules() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await ref.read(narrativeRuleProvider.notifier).save(_controller.text);
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsRulesSaved)));
  }

  /// 恢复默认叙事规则
  Future<void> _resetNarrativeRules() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await ref.read(narrativeRuleProvider.notifier).reset();
    _controller.text = ref.read(narrativeRuleProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsRulesReset)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.settingsRulesDescription, style: theme.textTheme.labelLarge),
        const SizedBox(height: 12),

        SectionCard(
          child: Column(
            children: [
              // 多行规则编辑框
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                  decoration: InputDecoration(hintText: l10n.settingsRulesHint),
                ),
              ),
              const SizedBox(height: 12),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n.settingsResetRules),
                    onPressed: _resetNarrativeRules,
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.settingsSaveRules),
                    onPressed: _saveNarrativeRules,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
