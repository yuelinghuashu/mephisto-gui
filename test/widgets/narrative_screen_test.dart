import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/providers/providers.dart';
import 'package:mephisto/screens/narrative_screen.dart';
import 'package:mephisto/screens/settings_screen.dart';
import 'package:mephisto/services/storage/secure_key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

/// 叙事页 Widget 测试
///
/// 通过注入抛异常的 mock HTTP 客户端，触发 LLM 调用失败 → 本地兜底回复，
/// 从而在零网络依赖下覆盖「发送 → 规则 → 兜底回复 → 消息渲染」完整闭环。
///
/// 通过 override contractProvider 直接注入内存中的契约，
/// 避免测试环境中真实文件 IO 的 Future 无法在 FakeAsync 中完成的问题。
///
/// 测试专用：预填兜底提示的 Notifier（override 用）。
///
/// [ContractFallbackNoticeController.build] 返回 null，无法在构建后
/// 再 setNotice（build 会在首次读取 state 时覆盖已设值），因此子类
/// 直接在 build() 中返回预设消息。
class _PrefilledFallbackNoticeController
    extends ContractFallbackNoticeController {
  final String message;

  _PrefilledFallbackNoticeController(this.message);

  @override
  String? build() => message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 提供自定义契约目录（restoreSession 找不到 faust.child.meph 时安全
    // no-op，且不触发 path_provider）
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': '/tmp/mephisto_test_contracts',
      'mephisto_current_contract': 'faust.meph',
    });
  });

  /// 测试契约（含开局场景 + 1 条规则，验证空状态与状态条）
  const testContract = Contract(
    roleName: '浮士德',
    worldview: '16 世纪的德意志，一个充满神秘学与契约的世界。',
    opening: '烛火摇曳的书斋中，浮士德坐在成堆的典籍之间。',
    state: [StateItem(key: '灵魂完整度', value: IntValue(100))],
    rules: [
      Rule(
        name: '灵魂危机',
        condition: '状态.灵魂完整度 < 30',
        action: '注入 "浮士德的灵魂接近枯竭"',
        line: 1,
      ),
    ],
  );

  /// 内存版安全存储（替代真实 FlutterSecureStorage）。
  ///
  /// 在 testWidgets 的 FakeAsync 环境中，真实 FlutterSecureStorage 的
  /// platform channel 没有 handler，调用会永远挂起（而非抛异常），
  /// 导致 llmConfigProvider.future 永不 resolve、生成流程卡死。
  /// override 为内存实现即可聚焦 UI 行为的测试。
  final secureStore = _MemorySecureStore();

  /// 构建叙事页：注入 mock HTTP 客户端（LLM 调用失败 → 本地兜底回复）
  /// 并 override 契约 Provider（避免真实文件 IO）。
  ///
  /// [httpClient] 可自定义（默认抛异常，触发本地兜底）；挂起场景可传入
  /// 返回永未完成 Future 的 client 以观察「生成中」状态。
  Widget buildNarrativeScreen({http.Client? httpClient}) {
    return ProviderScope(
      overrides: [
        httpClientProvider.overrideWithValue(
          httpClient ??
              MockClient((request) async => throw Exception('mock 网络错误')),
        ),
        contractProvider.overrideWith((ref) async => testContract),
        currentContractNameProvider.overrideWith((ref) async => 'faust.meph'),
        secureKeyValueStoreProvider.overrideWithValue(secureStore),
      ],
      child: localizedAppWithRoutes(
        routes: {'/settings': (_) => const SettingsScreen()},
        home: const NarrativeScreen(),
      ),
    );
  }

  testWidgets('空状态显示开局场景与引导文案', (tester) async {
    await tester.pumpWidget(buildNarrativeScreen());
    await tester.pumpAndSettle();

    expect(find.text('📜 契约已立'), findsOneWidget);
    expect(find.text('写下命运的指引，叙事将在契约中生长...'), findsOneWidget);
    // 开局场景来自契约文件
    expect(find.textContaining('烛火摇曳的书斋中'), findsOneWidget);
    // 状态条展示规则数（契约含 1 条规则 → 独立文本节点 "1 "）
    expect(find.text('1 '), findsOneWidget);
    expect(find.text('规则'), findsOneWidget);
  });

  testWidgets('契约兜底提示条：非空时渲染', (tester) async {
    // 注入兜底提示消息 → 顶部提示条渲染（4 个 override：httpClient/contract/currentName/notice）
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(
            MockClient((request) async => throw Exception('mock 网络错误')),
          ),
          contractProvider.overrideWith((ref) async => testContract),
          currentContractNameProvider.overrideWith((ref) async => 'faust.meph'),
          contractFallbackNoticeProvider.overrideWith(
            () => _PrefilledFallbackNoticeController('当前契约文件缺失或损坏，已加载内置模板'),
          ),
        ],
        child: localizedAppWithRoutes(
          routes: {'/settings': (_) => const SettingsScreen()},
          home: const NarrativeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 提示条文案 + 警示图标出现
    expect(find.text('当前契约文件缺失或损坏，已加载内置模板'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('契约兜底提示条：正常时不显示', (tester) async {
    // 未注入提示（默认 null）→ 不渲染提示条
    await tester.pumpWidget(buildNarrativeScreen());
    await tester.pumpAndSettle();

    expect(find.text('当前契约文件缺失或损坏，已加载内置模板'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('发送消息 → 命运气泡 + 本地兜底回复气泡出现', (tester) async {
    await tester.pumpWidget(buildNarrativeScreen());
    await tester.pumpAndSettle();

    // 输入命运的指引并发送（"我仰望星空"不匹配 localReply 关键词分支 → 走默认回复）
    await tester.enterText(find.byType(TextField), '我仰望星空');
    await tester.tap(find.byIcon(Icons.send));
    // 等待异步生成流程（规则 → LLM 失败 → 本地回复 → 自动存档）
    await tester.pumpAndSettle();

    // 命运消息（用户）出现
    expect(find.text('我仰望星空'), findsOneWidget);
    // 本地兜底回复出现：localReply 默认分支的固定尾句
    expect(find.textContaining('值得被追问'), findsOneWidget);
    // 输入框已清空
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('生成中：禁用输入框与发送按钮', (tester) async {
    // 用 Completer 挂起 LLM 请求，确保「生成中」状态持续可被观察到
    // （若 mock 立即完成/抛错，生成流程太快结束，无法验证禁用态）
    final llmCompleter = Completer<http.Response>();
    final hangingClient = MockClient((request) => llmCompleter.future);

    await tester.pumpWidget(buildNarrativeScreen(httpClient: hangingClient));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '继续');
    await tester.tap(find.byIcon(Icons.send));
    // 推进异步流程（llmConfig 加载等），此刻 LLM 请求挂起 → isGenerating 为 true
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
    // 发送按钮被替换为加载指示器
    expect(find.byIcon(Icons.send), findsNothing);

    // 完成挂起的请求（非 200 → generateStream 抛异常 → 本地兜底），
    // 避免遗留未完成异步；输入框恢复可用
    llmCompleter.complete(http.Response('', 500));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('设置按钮可跳转设置页', (tester) async {
    await tester.pumpWidget(buildNarrativeScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    // 设置页标题出现（路由跳转成功）
    expect(find.text('📜 设置'), findsOneWidget);
  });
}

/// 测试用：内存版安全存储（替代 FlutterSecureStorage，见 [buildNarrativeScreen]）。
class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
