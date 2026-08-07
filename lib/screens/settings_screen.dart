import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../app/theme.dart';
import '../providers/narrative_rule_provider.dart';
import '../providers/narrative_width_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage/contract_dir.dart';
import '../widgets/settings/llm_config_section.dart';
import '../widgets/settings/radio_selection_tile.dart';
import '../widgets/settings/section_card.dart';

/// 设置页：契约目录管理、LLM 配置、外观
///
/// 遵循《浮士德》主题设计语言：
///   - 金色衬线体区块标题（◉ / ⚜ / ⚚）
///   - 暖色羊皮纸卡片容器（surfaceVariant）
///   - 金色选中态的复古 ListTile
///   - 桌面端限制内容宽度（maxWidth 600），避免内容无限拉伸
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _contractsDirPath;

  /// 叙事规则编辑控制器
  late final TextEditingController _narrativeRulesController;

  /// 当前是否使用 Android 外部存储（仅 Android 可能为 true）
  bool _useExternalStorage = false;

  @override
  void initState() {
    super.initState();
    _loadContractsDir();
    // 加载当前叙事规则到编辑框
    _narrativeRulesController = TextEditingController(
      text: ref.read(narrativeRuleProvider),
    );
  }

  @override
  void dispose() {
    _narrativeRulesController.dispose();
    super.dispose();
  }

  /// 保存叙事规则
  Future<void> _saveNarrativeRules() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await ref
        .read(narrativeRuleProvider.notifier)
        .save(_narrativeRulesController.text);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsRulesSaved)),
    );
  }

  /// 恢复默认叙事规则
  Future<void> _resetNarrativeRules() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await ref.read(narrativeRuleProvider.notifier).reset();
    _narrativeRulesController.text = ref.read(narrativeRuleProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsRulesReset)),
    );
  }

  /// 加载当前契约目录路径 + 外部存储状态
  Future<void> _loadContractsDir() async {
    final dir = await getContractsDirectory();
    final useExternal = await isUsingMobileExternalStorage();
    if (mounted) {
      setState(() {
        _contractsDirPath = dir.path;
        _useExternalStorage = useExternal;
      });
    }
  }

  /// 构建叙事内容宽度选择器
  Widget _buildWidthSelector(ThemeData theme) {
    final currentWidth = ref.watch(narrativeWidthProvider);

    return Column(
      children: [
        for (final width in NarrativeWidth.values) ...[
          RadioSelectionTile(
            icon: switch (width) {
              NarrativeWidth.narrow => Icons.smartphone,
              NarrativeWidth.medium => Icons.book,
              NarrativeWidth.wide => Icons.menu_book,
              NarrativeWidth.full => Icons.photo_size_select_large,
            },
            label: width.label,
            selected: currentWidth == width,
            onTap: () =>
                ref.read(narrativeWidthProvider.notifier).setWidth(width),
          ),
          if (width != NarrativeWidth.values.last) const Divider(height: 1),
        ],
      ],
    );
  }

  /// 选择新的契约目录（桌面端：系统目录选择器）。
  Future<void> _changeContractsDir() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    // 打开系统目录选择器
    final selected = await getDirectoryPath(
      initialDirectory: _contractsDirPath,
    );

    if (selected == null || selected.isEmpty) return; // 用户取消

    // 保存新目录
    final ok = await setContractsDirectory(selected);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsDirChangeFail)));
      return;
    }

    // 刷新显示 + 提示
    await _loadContractsDir();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsDirChanged(selected))),
    );
  }

  /// iOS：「更改目录」提示（iOS 系统沙盒限制，仅应用内目录）。
  Future<void> _iosChangeContractsDir() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).settingsIosSandboxNotice)),
    );
  }

  /// Android：切换「内部沙盒 ↔ 应用外部存储」。
  Future<void> _toggleMobileStorage() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final enabled = await setMobileExternalStorage(!_useExternalStorage);
    if (!enabled) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsStorageSwitchFail)));
      return;
    }
    await _loadContractsDir();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _useExternalStorage
              ? l10n.settingsStorageExternalSwitched
              : l10n.settingsStorageInternalSwitched,
        ),
      ),
    );
  }

  /// 用系统文件管理器打开契约文件夹（仅桌面端可用）。
  Future<void> _openContractsDir() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final dir = await getContractsDirectory();

    if (!dir.existsSync()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsDirNotExist)));
      return;
    }

    // Linux 用 xdg-open，macOS 用 open，Windows 用 explorer
    // 移动端沙盒目录不可由用户直接浏览，此操作仅桌面端提供
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [dir.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [dir.path]);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.settingsPlatformNotSupported)),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsOpenFolderFail('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('📜 ${l10n.homeSettings}'), centerTitle: false),
      // 滚动区域占满全屏宽（鼠标在屏幕任意位置滚动都生效，桌面端友好）；
      // 内容宽度约束下移到内部列，保持内容居中固定 600px。
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // ============================================================
              // 外观设置
              // ============================================================
              _SectionHeader(icon: '◉', title: l10n.settingsAppearance),
              const SizedBox(height: 12),

              // ---- 主题模式选择（ListTile 需要 Material 祖先以绘制水波纹）----
              SectionCard(
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
              ),
              const SizedBox(height: 28),

              // ============================================================
              // 界面语言
              // ============================================================
              _SectionHeader(icon: '🌐', title: l10n.languageLabel),
              const SizedBox(height: 12),

              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    RadioSelectionTile(
                      icon: Icons.translate,
                      label: l10n.languageChinese,
                      selected: ref.watch(languageProvider) == 'zh',
                      onTap: () =>
                          ref.read(languageProvider.notifier).setLanguage('zh'),
                    ),
                    const Divider(height: 1),
                    RadioSelectionTile(
                      icon: Icons.language,
                      label: l10n.languageEnglish,
                      selected: ref.watch(languageProvider) == 'en',
                      onTap: () =>
                          ref.read(languageProvider.notifier).setLanguage('en'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ============================================================
              // 叙事内容宽度（桌面端阅读偏好）
              // ============================================================
              _SectionHeader(icon: '📐', title: l10n.settingsNarrativeWidth),
              const SizedBox(height: 8),
              Text(
                l10n.settingsWidthDescription,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),

              // ---- 宽度选择（羊皮纸卡片容器） ----
              SectionCard(
                padding: EdgeInsets.zero,
                child: _buildWidthSelector(theme),
              ),
              const SizedBox(height: 28),

              // ============================================================
              // 叙事规则（输出约束，可自定义编辑）
              // ============================================================
              _SectionHeader(icon: '📜', title: l10n.settingsNarrativeRules),
              const SizedBox(height: 8),
              Text(
                l10n.settingsRulesDescription,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),

              // ---- 规则编辑卡片 ----
              SectionCard(
                child: Column(
                  children: [
                    // 多行规则编辑框
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: TextField(
                        controller: _narrativeRulesController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                        decoration: InputDecoration(
                          hintText: l10n.settingsRulesHint,
                        ),
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
              const SizedBox(height: 28),

              // ============================================================
              // 契约目录设置（平台自适应）
              // ============================================================
              _SectionHeader(icon: '⚜', title: l10n.settingsContractsDir),
              const SizedBox(height: 8),
              Text(
                switch (defaultTargetPlatform) {
                  TargetPlatform.android => l10n.settingsAndroidDirDescription,
                  TargetPlatform.iOS => l10n.settingsIosDirDescription,
                  _ => l10n.settingsDesktopDirDescription,
                },
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),

              // ---- 羊皮纸卡片容器 ----
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 当前路径显示（始终显示真实完整路径，不隐藏）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _contractsDirPath ?? l10n.settingsDirLoading,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                        // 移动端附加上下文说明（不替代路径，仅补充解释）
                        if (defaultTargetPlatform == TargetPlatform.android) ...[
                          const SizedBox(height: 4),
                          Text(
                            _useExternalStorage
                                ? l10n.settingsAndroidExternalLocation
                                : l10n.settingsAndroidInternalLocation,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                        ],
                        if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.settingsIosLocation,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    switch (defaultTargetPlatform) {
                      // ---- Android：内部沙盒 ↔ 外部存储切换 ----
                      TargetPlatform.android => Row(
                        children: [
                          Expanded(
                            child: Text(
                              _useExternalStorage
                                  ? l10n.settingsAndroidExternalStorage
                                  : l10n.settingsAndroidInternalStorage,
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: Icon(
                              _useExternalStorage
                                  ? Icons.storage_outlined
                                  : Icons.sd_card_outlined,
                            ),
                            label: Text(
                              _useExternalStorage
                                  ? l10n.settingsSwitchToInternal
                                  : l10n.settingsSwitchToExternal,
                            ),
                            onPressed: _toggleMobileStorage,
                          ),
                        ],
                      ),
                      // ---- iOS：点击如实提示（沙盒限制，不隐藏） ----
                      TargetPlatform.iOS => Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.folder_open),
                            label: Text(l10n.settingsChangeDir),
                            onPressed: _iosChangeContractsDir,
                          ),
                        ],
                      ),
                      // ---- 桌面端：系统目录选择器 + 打开文件夹 ----
                      _ => Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.folder_open),
                            label: Text(l10n.settingsChangeDir),
                            onPressed: _changeContractsDir,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new),
                            label: Text(l10n.settingsOpenFolder),
                            onPressed: _openContractsDir,
                          ),
                        ],
                      ),
                    },
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ============================================================
              // LLM 配置
              // ============================================================
              _SectionHeader(icon: '⚚', title: l10n.settingsLlmConfig),
              const SizedBox(height: 8),
              Text(
                l10n.settingsLlmDescription,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),

              const LlmConfigSection(),
              const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 区块标题（金色衬线体 + 项目符号）
class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '$icon  $title',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.gold,
      ),
    );
  }
}
