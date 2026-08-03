import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    await ref
        .read(narrativeRuleProvider.notifier)
        .save(_narrativeRulesController.text);
    messenger.showSnackBar(const SnackBar(content: Text('✦ 叙事规则已保存')));
  }

  /// 恢复默认叙事规则
  Future<void> _resetNarrativeRules() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(narrativeRuleProvider.notifier).reset();
    _narrativeRulesController.text = ref.read(narrativeRuleProvider);
    messenger.showSnackBar(const SnackBar(content: Text('⇄ 已恢复默认叙事规则')));
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

    // 打开系统目录选择器
    final selected = await getDirectoryPath(
      initialDirectory: _contractsDirPath,
    );

    if (selected == null || selected.isEmpty) return; // 用户取消

    // 保存新目录
    final ok = await setContractsDirectory(selected);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('╳ 设置契约目录失败')));
      return;
    }

    // 刷新显示 + 提示
    await _loadContractsDir();
    messenger.showSnackBar(SnackBar(content: Text('✦ 契约目录已更新: $selected')));
  }

  /// iOS：「更改目录」提示（iOS 系统沙盒限制，仅应用内目录）。
  Future<void> _iosChangeContractsDir() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('╳ iOS 系统沙盒限制：契约仅保存在应用内目录，无法更改位置'),
      ),
    );
  }

  /// Android：切换「内部沙盒 ↔ 应用外部存储」。
  Future<void> _toggleMobileStorage() async {
    final messenger = ScaffoldMessenger.of(context);
    final enabled = await setMobileExternalStorage(!_useExternalStorage);
    if (!enabled) {
      messenger.showSnackBar(const SnackBar(content: Text('╳ 切换存储位置失败')));
      return;
    }
    await _loadContractsDir();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _useExternalStorage
              ? '✦ 契约占用地：应用外部存储（卸载应用时清除）'
              : '✦ 契约占用地：应用内部存储',
        ),
      ),
    );
  }

  /// 用系统文件管理器打开契约文件夹（仅桌面端可用）。
  Future<void> _openContractsDir() async {
    final messenger = ScaffoldMessenger.of(context);
    final dir = await getContractsDirectory();

    if (!dir.existsSync()) {
      messenger.showSnackBar(const SnackBar(content: Text('╳ 目录不存在')));
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
        messenger.showSnackBar(const SnackBar(content: Text('当前平台暂不支持打开文件夹')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('╳ 打开文件夹失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('📜 设置'), centerTitle: false),
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
              const _SectionHeader(icon: '◉', title: '外观'),
              const SizedBox(height: 12),

              // ---- 主题模式选择（ListTile 需要 Material 祖先以绘制水波纹）----
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    RadioSelectionTile(
                      icon: Icons.brightness_auto_outlined,
                      label: '跟随系统',
                      selected: themeMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                    const Divider(height: 1),
                    RadioSelectionTile(
                      icon: Icons.light_mode_outlined,
                      label: '亮色',
                      selected: themeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    const Divider(height: 1),
                    RadioSelectionTile(
                      icon: Icons.dark_mode_outlined,
                      label: '暗色',
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
              // 叙事内容宽度（桌面端阅读偏好）
              // ============================================================
              const _SectionHeader(icon: '📐', title: '叙事内容宽度'),
              const SizedBox(height: 8),
              Text(
                '叙事界面信息流的最大宽度。移动端自动占满屏幕，此选项主要影响桌面端。',
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
              const _SectionHeader(icon: '📜', title: '叙事规则'),
              const SizedBox(height: 8),
              Text(
                '自定义叙事风格，整体替换默认约束。'
                '风格描述越精确，输出越贴合预期（明确写出"以什么风格/诗体/对白方式"）。',
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
                        decoration: const InputDecoration(
                          hintText: '输入叙事规则...',
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
                          label: const Text('恢复默认'),
                          onPressed: _resetNarrativeRules,
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('保存规则'),
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
              const _SectionHeader(icon: '⚜', title: '契约目录'),
              const SizedBox(height: 8),
              Text(
                switch (defaultTargetPlatform) {
                  TargetPlatform.android =>
                    '契约可保存在应用内部存储或应用外部存储（卸载应用时清除）。'
                        '导入和默认加载都使用当前存储位置。',
                  TargetPlatform.iOS =>
                    '契约保存在应用内目录（iOS 系统沙盒限制）。'
                        '导入和默认加载都使用此目录。',
                  _ =>
                    '存放 .meph 契约文件的文件夹。导入和默认加载都使用此目录。',
                },
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),

              // ---- 羊皮纸卡片容器 ----
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 当前路径显示
                    Text(
                      _contractsDirPath ?? '加载中...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    switch (defaultTargetPlatform) {
                      // ---- Android：内部沙盒 ↔ 外部存储切换 ----
                      TargetPlatform.android => Row(
                        children: [
                          Expanded(
                            child: Text(
                              _useExternalStorage
                                  ? '当前：应用外部存储'
                                  : '当前：应用内部存储',
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
                              _useExternalStorage ? '切换为内部存储' : '切换为外部存储',
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
                            label: const Text('更改目录'),
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
                            label: const Text('更改目录'),
                            onPressed: _changeContractsDir,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('打开文件夹'),
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
              const _SectionHeader(icon: '⚚', title: 'LLM 配置'),
              const SizedBox(height: 8),
              Text(
                '叙事生成使用的 AI 服务参数。留空保存将使用默认配置。',
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
