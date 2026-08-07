import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';

/// 叙事状态条：规则/记忆/历史数量统计
class StatusBar extends StatelessWidget {
  /// 规则数量
  final int ruleCount;

  /// 记忆数量
  final int memoryCount;

  /// 历史数量
  final int historyCount;

  const StatusBar({
    super.key,
    required this.ruleCount,
    required this.memoryCount,
    required this.historyCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(theme.brightness),
        border: Border(
          top: BorderSide(color: AppTheme.divider(theme.brightness)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusChip('⚡', ruleCount, l10n.statusBarRuleChip),
          const SizedBox(width: 16),
          _StatusChip('🧠', memoryCount, l10n.statusBarMemoryChip),
          const SizedBox(width: 16),
          _StatusChip('📜', historyCount, l10n.statusBarHistoryChip),
        ],
      ),
    );
  }
}

/// 单个状态计数项
class _StatusChip extends StatelessWidget {
  final String icon;
  final int count;
  final String label;

  const _StatusChip(this.icon, this.count, this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          '$count ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.gold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary(theme.brightness),
          ),
        ),
      ],
    );
  }
}