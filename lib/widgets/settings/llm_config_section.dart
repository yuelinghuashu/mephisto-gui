import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// 当前后端类型（默认 OpenAI 兼容）
  LlmBackend _backend = LlmBackend.openaiCompatible;

  bool _llmLoaded = false;

  /// 是否正在测试连接（防止重复点击）
  bool _testing = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _maxTokensController.dispose();
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
    } else {
      const defaults = LlmConfig();
      _backend = defaults.backend;
      _baseUrlController.text = defaults.baseUrl;
      _modelController.text = defaults.model;
      _maxTokensController.text = defaults.maxTokens.toString();
    }
    if (mounted) setState(() => _llmLoaded = true);
  }

  /// 切换后端类型：Ollama 自动填充本地地址、清空 API Key 和默认模型
  void _switchBackend(LlmBackend? backend) {
    if (backend == null || backend == _backend) return;
    setState(() => _backend = backend);

    if (backend == LlmBackend.ollama) {
      _baseUrlController.text = LlmConfig.ollamaBaseUrl;
      _apiKeyController.clear();
      // Model 若仍是默认的 deepseek，则清空让用户填本地模型名
      if (_modelController.text == LlmConfig.defaultModel) {
        _modelController.clear();
      }
    } else {
      _baseUrlController.text = LlmConfig.defaultBaseUrl;
    }
  }

  /// 保存 LLM 配置
  Future<void> _saveLlmConfig() async {
    final messenger = ScaffoldMessenger.of(context);
    final config = LlmConfig(
      backend: _backend,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      maxTokens: int.tryParse(_maxTokensController.text.trim()) ?? 4096,
    );

    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('╳ Base URL 和 Model 不能为空')),
      );
      return;
    }

    await ref.read(llmSettingsProvider.notifier).save(config);
    messenger.showSnackBar(const SnackBar(content: Text('✦ LLM 配置已保存')));
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
    );

    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      setState(() => _testing = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('╳ 请先填写 Base URL 和 Model')),
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
        messages: [
          LlmMessage(role: 'user', content: 'ping'),
        ],
        onChunk: (_) {},
        // 测试连接用较短超时，快速反馈
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      error = '$e';
    }

    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == null ? '✦ 连接成功，模型可用' : '╳ 连接失败: $error',
        ),
      ),
    );
  }

  /// 重置 LLM 配置（回退到默认）
  Future<void> _resetLlmConfig() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(llmSettingsProvider.notifier).clear();
    const defaults = LlmConfig();
    _backend = defaults.backend;
    _apiKeyController.clear();
    _baseUrlController.text = defaults.baseUrl;
    _modelController.text = defaults.model;
    _maxTokensController.text = defaults.maxTokens.toString();
    messenger.showSnackBar(const SnackBar(content: Text('⇄ 已恢复默认配置')));
  }

  @override
  Widget build(BuildContext context) {
    final isOllama = _backend == LlmBackend.ollama;

    // ---- 羊皮纸卡片容器 ----
    // 使用 Material 包裹 ListTile（RadioSelectionTile），确保水波纹/选中高亮能正常绘制
    return SectionCard(
      child: Column(
          children: [
            // 后端类型选择（复古单选，与设置页其他区块风格一致）
            RadioSelectionTile(
              icon: Icons.auto_stories_outlined,
              label: 'OpenAI 兼容',
              selected: _backend == LlmBackend.openaiCompatible,
              onTap: () => _switchBackend(LlmBackend.openaiCompatible),
            ),
            RadioSelectionTile(
              icon: Icons.local_fire_department_outlined,
              label: '本地 Ollama',
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
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...（Ollama 可留空）',
                ),
              ),
            if (!isOllama) const SizedBox(height: 12),

            // Base URL
            TextField(
              controller: _baseUrlController,
              onTap: _ensureLlmLoaded,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: isOllama
                    ? 'http://localhost:11434/v1'
                    : 'https://api.deepseek.com/v1',
              ),
            ),
            const SizedBox(height: 12),

            // Model
            TextField(
              controller: _modelController,
              onTap: _ensureLlmLoaded,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'deepseek-v4-flash / qwen2.5:7b',
              ),
            ),
            const SizedBox(height: 12),

            // Max Tokens
            TextField(
              controller: _maxTokensController,
              onTap: _ensureLlmLoaded,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Tokens',
                hintText: '4096',
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
                      : const Icon(Icons.wifi_tethering_outlined, size: 18),
                  label: Text(_testing ? '测试中...' : '测试连接'),
                  onPressed: _testing ? null : _testConnection,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存配置'),
                  onPressed: _saveLlmConfig,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('恢复默认'),
                  onPressed: _resetLlmConfig,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
