import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/providers/llm_settings_provider.dart';
import 'package:mephisto/services/storage/secure_key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试用：内存版安全存储（替代 FlutterSecureStorage）。
///
/// `FlutterSecureStorage` 是 final class 且依赖系统密钥链，
/// 无法在纯 Dart 测试中实例化。通过 [SecureKeyValueStore] 接口注入
/// 此内存实现，验证 Provider 的读写/迁移逻辑。
class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  /// 断言 Key 存在且值为指定内容。
  Map<String, String> get all => Map.unmodifiable(_data);
}

void main() {
  group('llmConfigProvider', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late FakeSecureKeyValueStore secureStore;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      secureStore = FakeSecureKeyValueStore();
    });

    /// 构造一个注入了 fake 安全存储的 ProviderContainer。
    ///
    /// 为 `llmConfigProvider`（autoDispose）添加活跃监听，避免 Riverpod 3.x
    /// 在测试中「无 listener 直接 read future」时因 dispose 时序导致
    /// "disposed during loading state" 的伪失败。
    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(secureStore),
        ],
      );
      final sub = container.listen(llmConfigProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });
      return container;
    }

    test('用户配置未设置时返回默认值', () async {
      final container = makeContainer();

      final config = await container.read(llmConfigProvider.future);

      expect(config, const LlmConfig());
    });

    test('用户配置优先于默认值（API Key 写入安全存储）', () async {
      final container = makeContainer();

      // 保存用户配置
      const userConfig = LlmConfig(
        apiKey: 'user-key',
        baseUrl: 'https://custom.example.com/v1',
        model: 'custom-model',
        maxTokens: 2048,
      );
      await container
          .read(llmSettingsProvider.notifier)
          .save(userConfig);

      final config = await container.read(llmConfigProvider.future);

      expect(config.apiKey, 'user-key');
      expect(config.baseUrl, 'https://custom.example.com/v1');
      expect(config.model, 'custom-model');
      expect(config.maxTokens, 2048);

      // API Key 应存在于安全存储而非 SharedPreferences
      expect(secureStore.all, containsPair('llm_api_key', 'user-key'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('llm_api_key'), isNull);
    });

    test('清除用户配置后回退到默认值，且安全存储中的 Key 被清除', () async {
      final container = makeContainer();

      // 先保存再清除
      await container
          .read(llmSettingsProvider.notifier)
          .save(const LlmConfig(apiKey: 'temp-key'));
      await container.read(llmSettingsProvider.notifier).clear();

      final config = await container.read(llmConfigProvider.future);
      expect(config, const LlmConfig());
      expect(secureStore.all, isEmpty);
    });

    test('旧明文 API Key 首次读取时自动迁移到安全存储并删除明文', () async {
      // 模拟旧版本：API Key 明文存于 SharedPreferences
      SharedPreferences.setMockInitialValues({
        'llm_api_key': 'legacy-plain-key',
        'llm_base_url': 'https://legacy.example.com/v1',
        'llm_model': 'legacy-model',
        'llm_max_tokens': 4096,
        'llm_backend': 'openaiCompatible',
      });
      final container = makeContainer();

      final config = await container.read(llmConfigProvider.future);

      // 迁移：API Key 读到了旧明文值
      expect(config.apiKey, 'legacy-plain-key');
      expect(config.baseUrl, 'https://legacy.example.com/v1');

      // 迁移完成：明文已删除，安全存储已写入
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('llm_api_key'), isNull);
      expect(secureStore.all, containsPair('llm_api_key', 'legacy-plain-key'));
    });

    test('安全存储写入失败（密钥环不可用）时保留明文，不抛异常', () async {
      // 注入一个 write 总是失败的 fake
      final failingStore = _FailingWriteStore();
      final container = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(failingStore),
        ],
      );
      // 保持 autoDispose provider 活跃（同上）
      final sub = container.listen(llmConfigProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      SharedPreferences.setMockInitialValues({
        'llm_api_key': 'kept-as-plain',
        'llm_base_url': 'https://legacy.example.com/v1',
      });

      // 迁移写入失败不应导致读取崩溃
      final config = await container.read(llmConfigProvider.future);
      expect(config.apiKey, 'kept-as-plain');

      // 明文未被删除（写入失败 → 保留，下次重试）
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('llm_api_key'), 'kept-as-plain');
    });

    test('安全存储完全不可用（无原生插件）时优雅降级到明文，功能不受损', () async {
      // 不 override secureKeyValueStoreProvider：真实实现会在纯 Dart 测试中
      // 抛 MissingPluginException。验证 Provider 能捕获并降级，不影响读/写。
      final container = ProviderContainer();
      final sub = container.listen(llmConfigProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      // 保存：安全存储不可用 → 明文写入 SharedPreferences（功能不受损）
      await container
          .read(llmSettingsProvider.notifier)
          .save(const LlmConfig(apiKey: 'degraded-key', baseUrl: 'https://x/v1'));

      // 读取：安全存储不可用 → 读到明文中保存的 Key
      final config = await container.read(llmConfigProvider.future);
      expect(config.apiKey, 'degraded-key');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('llm_api_key'), 'degraded-key');

      // 清除：安全存储删除失败被忽略，明文被删除
      await container.read(llmSettingsProvider.notifier).clear();
      final cleared = await container.read(llmConfigProvider.future);
      expect(cleared, const LlmConfig());
      expect(prefs.getString('llm_api_key'), isNull);
    });
  });
}

class _FailingWriteStore implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {
    throw Exception('simulated keyring unavailable');
  }

  @override
  Future<void> delete(String key) async {}
}
