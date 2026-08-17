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
    final l10n = AppLocalizations.of(context);

    return Semantics(
      // 合并读屏语义：读屏朗读「规则 12 条」而非逐个朗读 emoji/数字/标签
      //（注意 gen-l10n 按占位符字母序生成参数：count 在前、label 在后）
      label: l10n.statusBarChipSemantics(count, label),
      excludeSemantics: true,
      child: Row(
        children: [
          // bodySmall 为 12px 基准，emoji 图标字号沿用同一档位
          Text(icon, style: theme.textTheme.bodySmall),
          const SizedBox(width: 4),
          Text(
            '$count ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary(theme.brightness),
            ),
          ),
        ],
      ),
    );
  }
}