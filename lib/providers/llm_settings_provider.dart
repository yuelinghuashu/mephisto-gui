import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'prefs_notifier.dart';

/// LLM 配置持久化 Provider
///
/// 管理用户在设置页配置的 LLM 参数，持久化到 SharedPreferences。
/// 优先级：用户配置 > LlmConfig 默认值
class LlmSettingsController extends AutoLoadNotifier<LlmConfig?> {
  static const String _apiKeyKey = 'llm_api_key';
  static const String _baseUrlKey = 'llm_base_url';
  static const String _modelKey = 'llm_model';
  static const String _maxTokensKey = 'llm_max_tokens';
  static const String _backendKey = 'llm_backend';

  @override
  LlmConfig? get defaultValue => null;

  /// 从持久化存储读取 LLM 配置（不写回 state）。
  ///
  /// 与 [load] 不同，本方法只读取不触发状态更新，避免 `llmConfigProvider`
  /// 每次请求都因 `state = config` 产生多余的 Provider 重建通知。
  Future<LlmConfig?> readConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    final baseUrl = prefs.getString(_baseUrlKey);
    final model = prefs.getString(_modelKey);
    final maxTokens = prefs.getInt(_maxTokensKey);
    final backendName = prefs.getString(_backendKey);

    if (apiKey == null &&
        baseUrl == null &&
        model == null &&
        maxTokens == null &&
        backendName == null) {
      return null;
    }

    // 解析后端类型（默认 OpenAI 兼容；Ollama 时忽略 API Key/保留默认 URL）
    final backend =
        LlmBackend.values.asNameMap()[backendName] ??
        LlmBackend.openaiCompatible;

    return LlmConfig(
      backend: backend,
      apiKey: apiKey ?? '',
      baseUrl: baseUrl ?? '',
      model: model ?? '',
      maxTokens: maxTokens ?? 4096,
    );
  }

  /// 读取持久化的 LLM 配置；返回恢复的配置（无持久化数据时返回 null）
  @override
  Future<LlmConfig?> load() async {
    final config = await readConfig();
    if (config != null) {
      state = config;
    }
    return config;
  }

  /// 保存 LLM 配置
  Future<void> save(LlmConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, config.apiKey);
    await prefs.setString(_baseUrlKey, config.baseUrl);
    await prefs.setString(_modelKey, config.model);
    await prefs.setInt(_maxTokensKey, config.maxTokens);
    await prefs.setString(_backendKey, config.backend.name);
    state = config;
  }

  /// 清除 LLM 配置（回退到默认值）
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_modelKey);
    await prefs.remove(_maxTokensKey);
    await prefs.remove(_backendKey);
    state = defaultValue;
  }
}

/// LLM 用户配置 Provider
final llmSettingsProvider = NotifierProvider<LlmSettingsController, LlmConfig?>(
  LlmSettingsController.new,
);

/// LLM 配置 Provider（最终生效配置，autoDispose）
///
/// - `autoDispose`：无监听时自动清缓存，彻底摆脱「改 key 须重启」的问题
/// - `watch(llmSettingsProvider)`：配置保存（state 更新）时主动失效重建
/// - 使用方（如叙事发送消息）建议用 `ref.refresh` 强制刷新，确保每次读最新 key
final llmConfigProvider = FutureProvider.autoDispose<LlmConfig>((ref) async {
  ref.watch(llmSettingsProvider);
  // 用户配置优先（readConfig 只读不写 state，避免重复触发重建；
  // await 异步持久化加载完成，避免首次请求拿到空 apiKey → 401）
  final userConfig = await ref.read(llmSettingsProvider.notifier).readConfig();
  if (userConfig != null) return userConfig;
  // 默认值兜底
  return const LlmConfig();
});

/// 共享 HTTP 客户端 Provider
///
/// 全局复用同一个 [http.Client]（连接复用，避免每次 LLM 请求新建 TCP 连接），
/// 应用生命周期结束时由 Riverpod 自动关闭。
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
