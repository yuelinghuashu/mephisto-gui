import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../services/storage/secure_key_value_store.dart';
import 'prefs_notifier.dart';

/// 安全键值存储 Provider（可注入 fake 供测试）
///
/// 基于系统级安全存储（Android Keystore / iOS·macOS Keychain /
/// Windows DPAPI / Linux libsecret），用于持久化 API Key 等敏感字段。
final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return const SecureKeyValueStoreImpl(FlutterSecureStorage());
});

/// LLM 配置持久化 Provider
///
/// 管理用户在设置页配置的 LLM 参数。
///   - **API Key**：持久化到系统级安全存储（[secureKeyValueStoreProvider]）
///   - **其余字段**（Base URL / Model / Max Tokens / Backend）：持久化到 SharedPreferences
///   - 旧版本以明文存于 SharedPreferences 的 API Key 在首次读取时自动迁移到安全存储
/// 优先级：用户配置 > LlmConfig 默认值
class LlmSettingsController extends AutoLoadNotifier<LlmConfig?> {
  static const String _apiKeyKey = 'llm_api_key';
  static const String _baseUrlKey = 'llm_base_url';
  static const String _modelKey = 'llm_model';
  static const String _maxTokensKey = 'llm_max_tokens';
  static const String _backendKey = 'llm_backend';

  @override
  LlmConfig? get defaultValue => null;

  /// 安全键值存储（来自 [secureKeyValueStoreProvider]；测试可覆盖）。
  Future<SecureKeyValueStore> _secureStore() async =>
      ref.read(secureKeyValueStoreProvider);

  /// 从安全存储读取 API Key；存储不可用时返回 null（由调用方回退明文）。
  Future<String?> _readApiKeyFromSecureStore() async {
    try {
      final store = await _secureStore();
      return await store.read(_apiKeyKey);
    } catch (_) {
      // 安全存储不可用（测试环境无原生插件 / 系统密钥环不可用）
      // → 返回 null，由调用方回退 SharedPreferences 明文
      return null;
    }
  }

  /// 从持久化存储读取 LLM 配置（不写回 state）。
  ///
  /// 与 [load] 不同，本方法只读取不触发状态更新，避免 `llmConfigProvider`
  /// 每次请求都因 `state = config` 产生多余的 Provider 重建通知。
  ///
  /// API Key 读取逻辑（含优雅降级）：
  ///   1. 优先从安全存储读取（新格式）
  ///   2. 安全存储为空或不可用（无原生实现/密钥环异常）时，
  ///      检查 SharedPreferences 是否残留旧明文（老版本）；
  ///      若有则 `安全存储写入 + 删除明文` 一步迁移完成
  ///   3. 安全存储写入失败（如密钥环不可用）→ 保留明文，下次仍可重试迁移
  Future<LlmConfig?> readConfig() async {
    final prefs = await SharedPreferences.getInstance();

    // API Key：优先安全存储；无则回退旧明文（并触发迁移）
    var apiKey = await _readApiKeyFromSecureStore();
    if (apiKey == null || apiKey.isEmpty) {
      final legacyPlainText = prefs.getString(_apiKeyKey);
      if (legacyPlainText != null && legacyPlainText.isNotEmpty) {
        // 旧明文 → 迁移到安全存储，随后删除明文
        apiKey = legacyPlainText;
        try {
          final store = await _secureStore();
          await store.write(_apiKeyKey, legacyPlainText);
          await prefs.remove(_apiKeyKey);
        } catch (_) {
          // 安全存储写入失败（如密钥环不可用）→ 保留明文，下次仍可重试迁移
        }
      }
    }

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
  ///
  /// API Key 写入安全存储；其余字段写入 SharedPreferences。
  /// 同时清理 SharedPreferences 中可能残留的明文 API Key。
  Future<void> save(LlmConfig config) async {
    final prefs = await SharedPreferences.getInstance();

    // API Key 写入安全存储；安全存储不可用时降级保留明文
    // （测试环境 / 系统密钥环不可用），下次成功写入/保存时再清理明文。
    try {
      final store = await _secureStore();
      if (config.apiKey.isNotEmpty) {
        await store.write(_apiKeyKey, config.apiKey);
      } else {
        await store.delete(_apiKeyKey); // API Key 为空（如 Ollama 模式）→ 清除旧 Key
      }
      await prefs.remove(_apiKeyKey); // 仅安全存储成功时才清理明文
    } catch (_) {
      // 安全存储不可用 → 保留 SharedPreferences 明文（功能不受损）
      if (config.apiKey.isNotEmpty) {
        await prefs.setString(_apiKeyKey, config.apiKey);
      } else {
        await prefs.remove(_apiKeyKey);
      }
    }

    await prefs.setString(_baseUrlKey, config.baseUrl);
    await prefs.setString(_modelKey, config.model);
    await prefs.setInt(_maxTokensKey, config.maxTokens);
    await prefs.setString(_backendKey, config.backend.name);
    state = config;
  }

  /// 清除 LLM 配置（回退到默认值）
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    // 安全存储删除失败时忽略（可能本就不可用，明文删除兜底）
    try {
      final store = await _secureStore();
      await store.delete(_apiKeyKey);
    } catch (_) {
      // 安全存储不可用 → 忽略，靠下方明文删除兜底
    }
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
