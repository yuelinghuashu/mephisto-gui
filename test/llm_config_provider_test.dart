import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/providers/llm_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('llmConfigProvider', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('用户配置未设置时返回默认值', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = await container.read(llmConfigProvider.future);

      expect(config, const LlmConfig());
    });

    test('用户配置优先于默认值', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

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
    });

    test('清除用户配置后回退到默认值', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 先保存再清除
      await container
          .read(llmSettingsProvider.notifier)
          .save(const LlmConfig(apiKey: 'temp-key'));
      await container.read(llmSettingsProvider.notifier).clear();

      final config = await container.read(llmConfigProvider.future);
      expect(config, const LlmConfig());
    });
  });
}