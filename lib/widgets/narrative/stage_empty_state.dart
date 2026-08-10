import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';

/// 舞台叙事空状态（多角色）
///
/// 当舞台加载完成、消息列表为空且未在生成时显示，展示**每个角色**的
/// 【开局场景】卡片，引导用户开始多角色叙事。
///
/// 与单角色 [EmptyState] 的区别：
///   - 单角色只展示一份【开局场景】
///   - 舞台版为每个角色各渲染一张卡片（按角色色板着色标题），
///     让用户在输入第一条命运指引前，先看到舞台上每位角色所处的开场局面。
class StageEmptyState extends StatelessWidget {
  /// 各角色的开局场景（已替换 `{角色名}` 占位符）。
  ///
  /// 元组：(角色名, 开局场景文本)
  final List<(String roleName, String opening)> openings;

  /// 角色色板：角色名 → 主题色（用于卡片标题着色，与舞台气泡一致）。
  final Map<String, Color> roleColors;

  const StageEmptyState({
    super.key,
    required this.openings,
    this.roleColors = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '📜 契约已立',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 24,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.narrativeEmptyHint,
              style: theme.textTheme.labelLarge,
            ),
            if (openings.isNotEmpty) ...[
              const SizedBox(height: 20),
              for (final (roleName, opening) in openings)
                if (opening.isNotEmpty) ...[
                  _buildOpeningCard(
                    theme,
                    roleName: roleName,
                    opening: opening,
                    accentColor: roleColors[roleName] ?? AppTheme.gold,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ],
        ),
      ),
    );
  }

  /// 单个角色的【开局场景】卡片（标题按角色色板着色）。
  Widget _buildOpeningCard(
    ThemeData theme, {
    required String roleName,
    required String opening,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '【$roleName · 开局场景】',
            style: theme.textTheme.labelLarge?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            opening,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}