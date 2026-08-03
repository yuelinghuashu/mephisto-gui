import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';

/// 命运结算卡片
///
/// 以《浮士德》风格的命运意象（天平 ⚖）展示一次骰子判定结果。
/// 支持折叠/展开：
///   - 判定 ≥ 3 条：默认折叠为单行摘要
///   - 判定 ≤ 2 条：自动展开显示详情
class DiceVerdictCard extends StatefulWidget {
  final List<DiceResult> results;

  const DiceVerdictCard({super.key, required this.results});

  @override
  State<DiceVerdictCard> createState() => _DiceVerdictCardState();
}

class _DiceVerdictCardState extends State<DiceVerdictCard> {
  late bool _expanded = widget.results.length < 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successCount = widget.results.where((d) => d.success).length;
    final failCount = widget.results.length - successCount;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, successCount, failCount),
            if (_expanded) ...[
              const Divider(height: 1, indent: 14, endIndent: 14),
              _buildDetails(theme),
              _buildFooter(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    int successCount,
    int failCount,
  ) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Text('⚖ ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                '命运结算 · ${widget.results.length} 回判定',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
              '$successCount✦  $failCount╳',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary(theme.brightness),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: AppTheme.textSecondary(theme.brightness),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in widget.results) ...[
            _VerdictRow(result: d),
            if (d != widget.results.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: AppTheme.gold.withValues(alpha: 0.04),
      child: Text(
        '≋ 诸神的注视落于棋盘之上 ≋',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppTheme.textSecondary(theme.brightness),
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// 单条判定行（两行撑满布局）
///
/// 第一行：成败标志 + 规则名（左撑满）+ 骰子数值（右对齐加粗）
/// 第二行：触发动作（仅成功时）+ 命运反馈文案（斜体）
class _VerdictRow extends StatelessWidget {
  final DiceResult result;

  const _VerdictRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.success ? AppTheme.gold : AppTheme.crimson;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- 第一行：标志 + 规则名（撑满） + 数值（右对齐） ----
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.success ? '✦ ' : '╳ ',
              style: TextStyle(color: color, fontSize: 16),
            ),
            Expanded(
              child: Text(
                result.ruleName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${result.value}/${result.maxValue}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // ---- 阈值（仅在自定义阈值时显示） ----
        if (result.threshold != null)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              '阈值 ≥ ${result.threshold}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary(theme.brightness),
                fontSize: 12,
              ),
            ),
          ),
        // ---- 触发动作（仅在规则真正匹配并执行时显示） ----
        if (result.triggered && result.action.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              '触发: ${result.action}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        // ---- 命运反馈文案（成功金色 / 失败暗红） ----
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            result.verdict,
            style: theme.textTheme.bodySmall?.copyWith(
              color: result.success ? AppTheme.gold : AppTheme.crimson,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
