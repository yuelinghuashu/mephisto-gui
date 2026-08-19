import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../domain/config.dart';
import '../../domain/enums.dart';
import '../../providers/llm_settings_provider.dart';
import '../../services/llm/client.dart';
import 'radio_selection_tile.dart';
import 'section_card.dart';

/// LLM 配置表单区块
///
/// 包含后端类型、API Key、Base URL、Model、Max Tokens 的配置。
/// 内部管理 TextEditingController 生命周期和懒加载逻辑。
///
/// 支持两种后端：
///   - [LlmBackend.openaiCompatible]：OpenAI 兼容协议（DeepSeek 等），需 API Key
///   - [LlmBackend.ollama]：本地 Ollama，自动填充默认 URL，隐藏 API Key
class LlmConfigSection extends ConsumerStatefulWidget {
  const LlmConfigSection({super.key});

  @override
  ConsumerState<LlmConfigSection> createState() => _LlmConfigSectionState();
}

class _LlmConfigSectionState extends ConsumerState<LlmConfigSection> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _maxTokensController = TextEditingController();
  final _timeoutController = TextEditingController();
  final _retriesController = TextEditingController();

  /// 当前后端类型（默认 OpenAI 兼容）
  LlmBackend _backend = LlmBackend.openaiCompatible;

  bool _llmLoaded = false;

  /// 是否正在测试连接（防止重复点击）
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    // 懒加载移到 initState：进入设置页即加载一次持久化配置。
    // 此前懒加载挂在各输入框 onTap 上——用户不点任何输入框直接
    // 「保存配置」会静默用默认值覆盖已有配置（maxTokens 等数值
    // 字段直接落盘为默认值）。
    Future.microtask(_ensureLlmLoaded);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _maxTokensController.dispose();
    _timeoutController.dispose();
    _retriesController.dispose();
    super.dispose();
  }

  /// 懒加载 LLM 配置到表单
  Future<void> _ensureLlmLoaded() async {
    if (_llmLoaded) return;
    final config = await ref.read(llmSettingsProvider.notifier).load();
    if (config != null) {
      _backend = config.backend;
      _apiKeyController.text = config.apiKey;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.model;
      _maxTokensController.text = config.maxTokens.toString();
      _timeoutController.text = config.timeoutSeconds.toString();
      _retriesController.text = config.maxRetries.toString();
    } else {
      const defaults = LlmConfig();
      _backend = defaults.backend;
      _baseUrlController.text = defaults.baseUrl;
      _modelController.text = defaults.model;
      _maxTokensController.text = defaults.maxTokens.toString();
      _timeoutController.text = defaults.timeoutSeconds.toString();
      _retriesController.text = defaults.maxRetries.toString();
    }
    if (mounted) setState(() => _llmLoaded = true);
  }

  /// 切换后端类型：仅在字段为空或仍为另一后端默认值时自动填充对应默认值，
  /// 绝不覆盖用户已输入的自定义内容；API Key 在 Ollama 模式下仅隐藏 UI、保留值。
  ///
  /// 设计原则：
  ///   - 用户首次进入表单时字段为空 → 切到某后端自动填其默认值（减少输入成本）
  ///   - 用户已自定义 Base URL / Model → 切换后端时不覆盖，保留自定义内容
  ///   - API Key 在 Ollama 下隐藏（`if (!isOllama)`），但 controller 值不清空，
  ///     切回 OpenAI 兼容时自动回显，避免用户重复输入
  void _switchBackend(LlmBackend? backend) {
    if (backend == null || backend == _backend) return;
    setState(() => _backend = backend);

    if (backend == LlmBackend.ollama) {
      // Base URL：为空或仍是 OpenAI 默认 URL（未自定义）→ 填 Ollama 默认
      final base = _baseUrlController.text.trim();
      if (base.isEmpty || base == LlmConfig.defaultBaseUrl) {
        _baseUrlController.text = LlmConfig.ollamaBaseUrl;
      }
      // API Key：不清空（隐藏 UI 但保留值，切回时自动回显）
      // Model：为空或仍是默认 deepseek → 清空让用户填本地模型名
      final model = _modelController.text.trim();
      if (model.isEmpty || model == LlmConfig.defaultModel) {
        _modelController.clear();
      }
    } else {
      // OpenAI 兼容：Base URL 为空或仍是 Ollama 默认 URL（未自定义）→ 填 OpenAI 默认
      final base = _baseUrlController.text.trim();
      if (base.isEmpty || base == LlmConfig.ollamaBaseUrl) {
        _baseUrlController.text = LlmConfig.defaultBaseUrl;
      }
      // Model：为空（Ollama 下被清空过）→ 填回默认模型；非空则保留用户自定义
      final model = _modelController.text.trim();
      if (model.isEmpty) {
        _modelController.text = LlmConfig.defaultModel;
      }
    }
  }

  /// 保存 LLM 配置
  Future<void> _saveLlmConfig() async {
    final messenger = ScaffoldMessenger.of(context);
    // async 间隙前先取引用，避免 use_build_context_synchronously
    final l10n = AppLocalizations.of(context);
    final config = LlmConfig(
      backend: _backend,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      maxTokens: int.tryParse(_maxTokensController.text.trim()) ?? 4096,
      timeoutSeconds:
          int.tryParse(_timeoutController.text.trim()) ??
          LlmConfig.defaultTimeoutSeconds,
      maxRetries:
          int.tryParse(_retriesController.text.trim()) ??
          LlmConfig.defaultMaxRetries,
    );

    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsConfigSaveFail)),
      );
      return;
    }

    await ref.read(llmSettingsProvider.notifier).save(config);
    // 强制失效缓存：确保运行时下次请求立即用新 key（双保险，见 llmConfigProvider 的 watch）
    ref.invalidate(llmConfigProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsConfigSaved)));
  }

  /// 从剪贴板导入 API Key（避免手输 Key 时复制到剪贴板长期残留）。
  Future<void> _pasteApiKey() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsApiKeyPasteEmpty)),
      );
      return;
    }
    setState(() => _apiKeyController.text = text);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsApiKeyPasteSuccess)),
    );
  }

  /// 测试 LLM 连接：使用表单当前字段（无需先保存）发一个最小流式请求验证连通性。
  ///
  /// - OpenAI 兼容：需要有效 API Key + Model；失败原因（网络/鉴权/模型不存在）即时反馈
  /// - Ollama：本地服务，无需 API Key；请求快速失败或不响应会提示检查服务启动
  Future<void> _testConnection() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_testing) return;
    setState(() => _testing = true);

    final config = LlmConfig(
      backend: _backend,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      maxTokens: int.tryParse(_maxTokensController.text.trim()) ?? 16,
      timeoutSeconds:
          int.tryParse(_timeoutController.text.trim()) ??
          LlmConfig.defaultTimeoutSeconds,
      maxRetries:
          int.tryParse(_retriesController.text.trim()) ??
          LlmConfig.defaultMaxRetries,
    );

    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      setState(() => _testing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).settingsTestNeedBaseUrlModel,
          ),
        ),
      );
      return;
    }

    String? error;
    try {
      final client = LlmClient(
        apiKey: config.apiKey,
        baseUrl: config.baseUrl,
        model: config.model,
        maxTokens: config.maxTokens,
      );
      await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'ping')],
        onChunk: (_) {},
        // 测试连接用较短超时，快速反馈
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      error = '$e';
    }

    if (!mounted) return;
    setState(() => _testing = false);
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? l10n.settingsTestSuccess
              : l10n.settingsTestFail(error),
        ),
      ),
    );
  }

  /// 重置 LLM 配置（回退到默认）
  Future<void> _resetLlmConfig() async {
    final messenger = ScaffoldMessenger.of(context);
    // async 间隙前先取引用，避免 use_build_context_synchronously
    final l10n = AppLocalizations.of(context);
    await ref.read(llmSettingsProvider.notifier).clear();
    // 强制失效缓存：清除配置后下次请求立即回退默认值
    ref.invalidate(llmConfigProvider);
    const defaults = LlmConfig();
    _backend = defaults.backend;
    _apiKeyController.clear();
    _baseUrlController.text = defaults.baseUrl;
    _modelController.text = defaults.model;
    _maxTokensController.text = defaults.maxTokens.toString();
    _timeoutController.text = defaults.timeoutSeconds.toString();
    _retriesController.text = defaults.maxRetries.toString();
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsConfigReset)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOllama = _backend == LlmBackend.ollama;

    // ---- 羊皮纸卡片容器 ----
    // 使用 Material 包裹 ListTile（RadioSelectionTile），确保水波纹/选中高亮能正常绘制
    return SectionCard(
      child: Column(
        children: [
          // 后端类型选择（复古单选，与设置页其他区块风格一致）
          RadioSelectionTile(
            icon: Icons.auto_stories_outlined,
            label: l10n.settingsBackendOpenai,
            selected: _backend == LlmBackend.openaiCompatible,
            onTap: () => _switchBackend(LlmBackend.openaiCompatible),
          ),
          RadioSelectionTile(
            icon: Icons.local_fire_department_outlined,
            label: l10n.settingsBackendOllama,
            selected: _backend == LlmBackend.ollama,
            onTap: () => _switchBackend(LlmBackend.ollama),
          ),
          const SizedBox(height: 12),

          // API Key（Ollama 不需要，隐藏）
          if (!isOllama)
            TextField(
              controller: _apiKeyController,
              onTap: _ensureLlmLoaded,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsApiKeyLabel,
                hintText: l10n.settingsApiKeyHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_outlined),
                  tooltip: l10n.settingsApiKeyPaste,
                  onPressed: _pasteApiKey,
                ),
              ),
            ),
          if (!isOllama) const SizedBox(height: 12),

          // Base URL
          TextField(
            controller: _baseUrlController,
            onTap: _ensureLlmLoaded,
            decoration: InputDecoration(
              labelText: l10n.settingsBaseUrlLabel,
              hintText: isOllama
                  ? LlmConfig.ollamaBaseUrl
                  : l10n.settingsBaseUrlHint,
            ),
          ),
          const SizedBox(height: 12),

          // Model
          TextField(
            controller: _modelController,
            onTap: _ensureLlmLoaded,
            decoration: InputDecoration(
              labelText: l10n.settingsModelLabel,
              hintText: l10n.settingsModelHint,
            ),
          ),
          const SizedBox(height: 12),

          // Max Tokens
          TextField(
            controller: _maxTokensController,
            onTap: _ensureLlmLoaded,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.settingsMaxTokensLabel,
              hintText: l10n.settingsMaxTokensHint,
            ),
          ),
          const SizedBox(height: 12),

          // 超时秒数（保护响应头到达 + 流式读取）
          TextField(
            controller: _timeoutController,
            onTap: _ensureLlmLoaded,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.settingsTimeoutLabel,
              hintText: l10n.settingsTimeoutHint,
            ),
          ),
          const SizedBox(height: 12),

          // 最大重试次数（网络层瞬时故障时）
          TextField(
            controller: _retriesController,
            onTap: _ensureLlmLoaded,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.settingsRetriesLabel,
              hintText: l10n.settingsRetriesHint,
            ),
          ),
          const SizedBox(height: 16),

          // 操作按钮（右对齐；窄屏自动换行，避免第三个按钮被裁剪）
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt, size: 18),
                label: Text(
                  _testing ? l10n.settingsTesting : l10n.settingsTestConnection,
                ),
                onPressed: _testing ? null : _testConnection,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.settingsSaveConfig),
                onPressed: _saveLlmConfig,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: Text(l10n.settingsResetConfig),
                onPressed: _resetLlmConfig,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
