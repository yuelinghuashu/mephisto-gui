import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../domain/config.dart';
import '../../providers/llm_settings_provider.dart';
import 'section_card.dart';

/// 辅助任务模型配置区块（多模型路由）
///
/// 管理「记忆提取 / 压缩」等后台辅助任务使用的独立模型配置。
/// 设计要点：
///   - 默认关闭（[LlmAuxConfig.enabled] = false）→ 所有任务共用主配置，老用户零感知
///   - 开启后可配置：Model / Base URL / API Key / Max Tokens / 超时
///   - API Key 与 Base URL 允许留空——运行时自动继承主配置
class AuxLlmConfigSection extends ConsumerStatefulWidget {
  const AuxLlmConfigSection({super.key});

  @override
  ConsumerState<AuxLlmConfigSection> createState() =>
      _AuxLlmConfigSectionState();
}

class _AuxLlmConfigSectionState extends ConsumerState<AuxLlmConfigSection> {
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _maxTokensController = TextEditingController();
  final _timeoutController = TextEditingController();

  bool _enabled = false;
  bool _loaded = false;

  /// 用户是否已手动操作过开关（防止懒加载覆盖用户交互）。
  ///
  /// 此前懒加载挂在 `onChanged` / `onTap` 上且未 await：异步加载完成的
  /// `_enabled = config.enabled` 会覆盖用户刚拨动的开关值（竞态）。
  /// 现在加载移到 [initState] 调度，但加载完成前用户仍可能点开关，
  /// 因此记录「是否已手动操作」——已操作则加载不再覆盖开关状态。
  bool _userTouchedToggle = false;

  @override
  void initState() {
    super.initState();
    // 懒加载移到 initState：进入设置页即加载一次持久化配置，
    // 不再依赖 onTap/onChanged 触发（此前不点输入框直接保存会静默
    // 用默认值覆盖用户配置；且 onChanged 未 await 存在覆盖竞态）。
    Future.microtask(_ensureLoaded);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _maxTokensController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  /// 懒加载辅助配置到表单。
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final config = await ref.read(llmSettingsProvider.notifier).readAuxConfig();
    if (!mounted) return;
    if (config != null) {
      // 用户已手动操作开关 → 保留用户选择，仅填充其余字段
      if (!_userTouchedToggle) {
        _enabled = config.enabled;
      }
      _modelController.text = config.model;
      _baseUrlController.text = config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _maxTokensController.text = config.maxTokens.toString();
      _timeoutController.text = config.timeoutSeconds.toString();
    } else {
      // 无持久化数据 → 默认关闭
      if (!_userTouchedToggle) {
        _enabled = false;
      }
      _maxTokensController.text = '4096';
      _timeoutController.text = '${LlmConfig.defaultTimeoutSeconds}';
    }
    setState(() => _loaded = true);
  }

  /// 保存辅助配置。
  Future<void> _saveAuxConfig() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    final config = LlmAuxConfig(
      enabled: _enabled,
      model: _modelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      maxTokens: int.tryParse(_maxTokensController.text.trim()) ?? 4096,
      timeoutSeconds:
          int.tryParse(_timeoutController.text.trim()) ??
          LlmConfig.defaultTimeoutSeconds,
    );

    // 启用时若模型名为空且主配置未设置 → 提示先填模型
    if (_enabled) {
      final main = await ref.read(llmSettingsProvider.notifier).readConfig();
      if ((config.model.isEmpty && (main?.model.isEmpty ?? true))) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.settingsConfigSaveFail)),
        );
        return;
      }
    }

    await ref.read(llmSettingsProvider.notifier).saveAux(config);
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsAuxSaved)));
  }

  /// 清除辅助配置（回退共用主配置）。
  Future<void> _clearAuxConfig() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    await ref.read(llmSettingsProvider.notifier).clearAux();
    // 重置表单到默认状态
    setState(() {
      _enabled = false;
      _modelController.clear();
      _baseUrlController.clear();
      _apiKeyController.clear();
      _maxTokensController.text = '4096';
      _timeoutController.text = '${LlmConfig.defaultTimeoutSeconds}';
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsAuxReset)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 启用开关
          SwitchListTile(
            title: Text(l10n.settingsAuxLlmEnabled),
            subtitle: Text(
              l10n.settingsAuxLlmDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _enabled,
            onChanged: (value) {
              // 记录用户手动操作（懒加载已完成时无影响；若加载尚未
              // 完成，则加载不再覆盖此开关值，消除覆盖竞态）
              _userTouchedToggle = true;
              setState(() => _enabled = value);
            },
          ),
          const SizedBox(height: 8),

          // 开启时显示详细配置
          if (_enabled) ...[
            TextField(
              controller: _modelController,
              onTap: _ensureLoaded,
              decoration: InputDecoration(
                labelText: l10n.settingsAuxModelLabel,
                hintText: l10n.settingsAuxModelHint,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _baseUrlController,
              onTap: _ensureLoaded,
              decoration: InputDecoration(
                labelText: l10n.settingsAuxBaseUrlLabel,
                hintText: LlmConfig.defaultBaseUrl,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _apiKeyController,
              onTap: _ensureLoaded,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsAuxApiKeyLabel,
                hintText: 'sk-...',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _maxTokensController,
              onTap: _ensureLoaded,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.settingsAuxMaxTokensLabel,
                hintText: '4096',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _timeoutController,
              onTap: _ensureLoaded,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.settingsAuxTimeoutLabel,
                hintText: '${LlmConfig.defaultTimeoutSeconds}',
              ),
            ),
            const SizedBox(height: 16),

            // 操作按钮
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.settingsAuxSaveConfig),
                  onPressed: _saveAuxConfig,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.settingsResetConfig),
                  onPressed: _clearAuxConfig,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
