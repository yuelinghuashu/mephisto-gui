import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/providers/narrative_window_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('narrativeWindowProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('未设置时使用默认值 medium（40 条）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final window = container.read(narrativeWindowProvider);
      expect(window, NarrativeWindow.medium);
      expect(window.maxHistoryMessages, 40);
    });

    test('保存后从持久化恢复（narrow = 20 条）', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(narrativeWindowProvider.notifier)
          .setWindow(NarrativeWindow.narrow);
      expect(container.read(narrativeWindowProvider), NarrativeWindow.narrow);
      expect(container.read(narrativeWindowProvider).maxHistoryMessages, 20);
    });

    test('wide = 60 条，full = 不限制（null）', () {
      expect(NarrativeWindow.wide.maxHistoryMessages, 60);
      expect(NarrativeWindow.full.maxHistoryMessages, isNull);
    });
  });
}