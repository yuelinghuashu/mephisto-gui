import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../app/theme.dart';
import '../widgets/settings/contracts_dir_section.dart';
import '../widgets/settings/language_section.dart';
import '../widgets/settings/llm_config_section.dart';
import '../widgets/settings/narrative_memory_section.dart';
import '../widgets/settings/narrative_rules_section.dart';
import '../widgets/settings/narrative_width_section.dart';
import '../widgets/settings/narrative_window_section.dart';
import '../widgets/settings/section_card.dart';
import '../widgets/settings/section_header.dart';
import '../widgets/settings/theme_mode_section.dart';
import 'settings_section_page.dart';

/// 设置页：契约目录管理、LLM 配置、外观
///
/// 遵循《浮士德》主题设计语言：
///   - 金色衬线体区块标题（◉ / ⚜ / ⚚）
///   - 暖色羊皮纸卡片容器（surfaceVariant）
///   - 金色选中态的复古 ListTile
///
/// 响应式布局：
///   - **宽屏（≥600）**：单页垂直堆叠全部 7 个区块（桌面端优先，内容居中 600px）
///   - **窄屏（<600，移动端）**：切换为「分区入口列表 + 点击进入独立子页」——
///     7 个分区以紧凑 ListTile 展示（图标 + 标题 + 副标题），无需滚动 2-3 屏
///     定位目标；各区块组件通过 [SettingsSectionPage] 延迟实例化，进入对应
///     子页才构建。
///
/// 各区块实现已拆分至 [lib/widgets/settings/] 下的独立组件，
/// 本页只负责「响应式组装 + 导航」。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// 设置分区配置（icon + 标题 + 区块 builder）
  ///
  /// 宽屏模式直接内联渲染全部区块；窄屏模式作为入口列表渲染。
  static List<_SettingsSection> _sections(AppLocalizations l10n) => [
    _SettingsSection(
      icon: '🌗',
      title: l10n.settingsTheme,
      subtitle: l10n.settingsThemeDescription,
      builder: (_) => const ThemeModeSection(),
    ),
    _SettingsSection(
      icon: '🌐',
      title: l10n.settingsLanguage,
      subtitle: l10n.settingsLanguageDescription,
      builder: (_) => const LanguageSection(),
    ),
    _SettingsSection(
      icon: '📐',
      title: l10n.settingsNarrativeWidth,
      subtitle: l10n.settingsWidthDescription,
      builder: (_) => const NarrativeWidthSection(),
    ),
    _SettingsSection(
      icon: '🪟',
      title: l10n.settingsHistoryWindow,
      subtitle: l10n.settingsHistoryWindowDescription,
      builder: (_) => const NarrativeWindowSection(),
    ),
    _SettingsSection(
      icon: '🧠',
      title: l10n.settingsMemoryLimit,
      subtitle: l10n.settingsMemoryLimitDescription,
      builder: (_) => const NarrativeMemorySection(),
    ),
    _SettingsSection(
      icon: '📜',
      title: l10n.settingsNarrativeRules,
      subtitle: l10n.settingsRulesDescription,
      builder: (_) => const NarrativeRulesSection(),
    ),
    _SettingsSection(
      icon: '⚜',
      title: l10n.settingsContractsDir,
      subtitle: l10n.settingsDesktopDirDescription,
      builder: (_) => const ContractsDirSection(),
    ),
    _SettingsSection(
      icon: '⚚',
      title: l10n.settingsLlmConfig,
      subtitle: l10n.settingsLlmDescription,
      builder: (_) => const LlmConfigSection(),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < AppTheme.mobileBreakpoint;

    return Scaffold(
      appBar: AppBar(title: Text('📜 ${l10n.homeSettings}'), centerTitle: false),
      body: isNarrow
          ? _buildNarrowList(context, l10n)
          : _buildWideList(context, l10n),
    );
  }

  /// 宽屏：单页垂直堆叠全部区块（与旧版一致，内容居中 600px）。
  Widget _buildWideList(BuildContext context, AppLocalizations l10n) {
    final sections = _sections(l10n);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 28),
                  _labeledSection(
                    icon: sections[i].icon,
                    title: sections[i].title,
                    child: sections[i].builder(context),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 窄屏（移动端）：分区入口列表，点击进入独立子页。
  ///
  /// 入口页只渲染 ListTile（图标 + 标题 + 副标题摘要），不实例化区块，
  /// 避免进入设置页就触发 `ContractsDirSection` 等组件的 IO 初始化；
  /// 区块内容通过 [SettingsSectionPage] 在子页中延迟构建。
  Widget _buildNarrowList(BuildContext context, AppLocalizations l10n) {
    final sections = _sections(l10n);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final section = sections[index];
        return SectionCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Text(
              section.icon,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            title: Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Text(
              section.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsSectionPage(
                    title: '${section.icon}  ${section.title}',
                    builder: section.builder,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 带 [SectionHeader] 标题的区块包装（宽屏单页模式使用）。
  Widget _labeledSection({
    required String icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(icon: icon, title: title),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// 设置分区配置（宽屏内联渲染 / 窄屏入口列表共用）
class _SettingsSection {
  final String icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}