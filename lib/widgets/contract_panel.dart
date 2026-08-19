import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/models.dart';
import '../l10n/app_localizations.dart';

/// 契约数据面板：结构化展示 .meph 契约的所有区块。
///
/// 供两处复用：
///   - 首页：契约预览（底部 Sheet）
///   - 叙事页：仪表盘（右侧抽屉）
///
/// 展示内容：
///   - 角色、状态、锚点、世界观、开局场景、规则
///   - 可选：记忆、历史（运行时数据，由调用方传入）
class ContractPanel extends StatelessWidget {
  /// 契约数据（必需）
  final Contract contract;

  /// 运行时状态（可选；不传时使用契约初始状态）
  final Map<String, StateValue>? currentState;

  /// 运行时记忆（可选；不传时不显示【记忆】区块）
  final List<Memory>? memories;

  /// 运行时历史（可选；不传时不显示【历史】区块）
  final List<HistoryEntry>? history;

  const ContractPanel({
    super.key,
    required this.contract,
    this.currentState,
    this.memories,
    this.history,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = currentState ?? contract.stateMap;
    final memList = memories;
    final histList = history;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---- 角色 ----
          _sectionHeader(theme, l10n.contractPanelRoleName),
          _sectionBody(
            Text(contract.roleName, style: theme.textTheme.bodyLarge),
          ),

          // ---- 状态（运行时值） ----
          _sectionHeader(theme, l10n.contractPanelState),
          _sectionBody(
            state.isEmpty
                ? Text(
                    l10n.contractPanelNoState,
                    style: theme.textTheme.labelMedium,
                  )
                : _buildKeyValueList(
                    state.entries.map((e) => (e.key, e.value.value)).toList(),
                    theme,
                  ),
          ),

          // ---- 锚点 ----
          if (contract.anchor.isNotEmpty) ...[
            _sectionHeader(theme, l10n.contractPanelAnchor),
            _sectionBody(
              _buildKeyValueList(
                contract.anchor.map((a) => (a.key, a.value.value)).toList(),
                theme,
              ),
            ),
          ],

          // ---- 世界观 ----
          if (contract.worldview.isNotEmpty) ...[
            _sectionHeader(theme, l10n.contractPanelWorldview),
            _sectionBody(
              Text(contract.worldview, style: theme.textTheme.bodyMedium),
            ),
          ],

          // ---- 角色背景 ----
          if (contract.background.isNotEmpty) ...[
            _sectionHeader(theme, l10n.contractPanelBackground),
            _sectionBody(
              Text(
                contract.background.replaceAll('{角色名}', contract.roleName),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],

          // ---- 开局场景 ----
          if (contract.opening.isNotEmpty) ...[
            _sectionHeader(theme, l10n.contractPanelOpening),
            _sectionBody(
              Text(
                contract.opening.replaceAll('{角色名}', contract.roleName),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],

          // ---- 规则 ----
          _sectionHeader(theme, l10n.contractPanelRules(contract.rules.length)),
          _sectionBody(
            contract.rules.isEmpty
                ? Text(
                    l10n.contractPanelNoRules,
                    style: theme.textTheme.labelMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < contract.rules.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${i + 1}. [${contract.rules[i].name}] '
                            '${contract.rules[i].condition} '
                            '-> ${contract.rules[i].action}',
                            // labelLarge 已含 13px + textSecondary 默认值
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                    ],
                  ),
          ),

          // ---- 记忆（可选） ----
          if (memList != null) ...[
            _sectionHeader(theme, l10n.contractPanelMemories(memList.length)),
            _sectionBody(
              memList.isEmpty
                  ? Text(
                      l10n.contractPanelNoMemories,
                      style: theme.textTheme.labelMedium,
                    )
                  : _buildStringList(
                      memList.map((m) => m.content).toList(),
                      theme,
                    ),
            ),
          ],

          // ---- 历史（可选） ----
          if (histList != null) ...[
            _sectionHeader(theme, l10n.contractPanelHistory(histList.length)),
            _sectionBody(
              histList.isEmpty
                  ? Text(
                      l10n.contractPanelNoHistory,
                      style: theme.textTheme.labelMedium,
                    )
                  : _buildStringList(
                      histList
                          .map(
                            (h) =>
                                '${h.role == MessageRole.fate ? l10n.contractPanelRoleFate : l10n.contractPanelRoleAssistant}: '
                                '${h.content}',
                          )
                          .toList(),
                      theme,
                    ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 区块标题
  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: AppTheme.gold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 区块内容（左缩进）
  Widget _sectionBody(Widget child) {
    return Padding(padding: const EdgeInsets.only(left: 4), child: child);
  }

  /// 渲染键值对列表（状态/锚点）
  Widget _buildKeyValueList(List<(String, Object)> entries, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (key, value) in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('- $key: $value', style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }

  /// 渲染字符串列表（记忆/历史/规则动作等辅助条目）
  Widget _buildStringList(List<String> items, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '- $item',
              // labelLarge 已含 13px + textSecondary 默认值
              style: theme.textTheme.labelLarge,
            ),
          ),
      ],
    );
  }
}
