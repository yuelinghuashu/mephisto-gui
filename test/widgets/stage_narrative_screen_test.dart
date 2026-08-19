import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/domain/stage_models.dart';
import 'package:mephisto/domain/stage_narrative_state.dart';
import 'package:mephisto/providers/stage_narrative_provider.dart';
import 'package:mephisto/screens/stage_narrative_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// 舞台叙事页 Widget 测试
///
/// 通过 override [stageNarrativeProvider] 注入预加载的舞台状态，
/// 避免真实文件 IO 与 LLM 网络调用，聚焦 UI 渲染行为。
///
/// 覆盖：
///   - 加载中显示进度指示器
///   - 加载完成后显示舞台名与角色状态条
///   - 空状态显示各角色开局场景卡片
///   - 消息流渲染（命运消息 + 角色着色气泡）
///   - 全景叙事去重（无 roleTag 的标准气泡，不渲染角色标签）
///   - 发送消息回调传递
///   - 重置会话按钮存在且可点击
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 为 PrefsNotifier（narrativeWidthProvider 等）提供 mock 存储
    SharedPreferences.setMockInitialValues({});
  });

  // ============================================================
  // 测试夹具
  // ============================================================

  const faustContract = Contract(
    roleName: '浮士德',
    opening: '烛火摇曳的书斋中，浮士德坐在成堆的典籍之间。',
    state: [StateItem(key: '灵魂完整度', value: IntValue(100))],
  );

  const mephistoContract = Contract(
    roleName: '梅菲斯特',
    opening: '阴影在角落中蠕动，梅菲斯特静待契约者上钩。',
  );

  const stage = StageLoaded(
    info: StageInfo(
      path: '/tmp/test_stage',
      name: '浮士德与梅菲斯特',
      characterCount: 2,
    ),
    characters: [
      StageCharacter(fileName: '浮士德.meph', contract: faustContract),
      StageCharacter(fileName: '梅菲斯特.meph', contract: mephistoContract),
    ],
  );

  /// 构造已加载的舞台状态（角色 2 名）
  StageNarrativeState loadedState({
    List<Message> messages = const [],
    bool isGenerating = false,
    String streamingContent = '',
  }) {
    return StageNarrativeState(
      stage: stage,
      stagePath: '/tmp/test_stage',
      roles: const {
        '浮士德': RoleRunState(currentState: {'灵魂完整度': IntValue(100)}),
        '梅菲斯特': RoleRunState(),
      },
      messages: messages,
      isGenerating: isGenerating,
      streamingContent: streamingContent,
    );
  }

  /// 构建舞台叙事页（注入 fake notifier）
  Widget buildScreen({required StageNarrativeState initialState}) {
    return ProviderScope(
      overrides: [
        stageNarrativeProvider.overrideWith(
          () => _FakeStageNotifier(initialState),
        ),
      ],
      child: localizedAppWithRoutes(
        routes: {'/settings': (_) => const Scaffold(body: Text('设置页'))},
        home: const StageNarrativeScreen(stagePath: '/tmp/test_stage'),
      ),
    );
  }

  // ============================================================
  // 加载中
  // ============================================================

  testWidgets('加载中：舞台为 null 时显示进度指示器', (tester) async {
    await tester.pumpWidget(
      buildScreen(initialState: const StageNarrativeState()),
    );
    // CircularProgressIndicator 是持续动画，不能用 pumpAndSettle（永不稳定）
    await tester.pump();

    // 未加载完成 → 显示 CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // 舞台名为空（AppBar 不显示）
    expect(find.text('浮士德与梅菲斯特'), findsNothing);
  });

  // ============================================================
  // 加载完成 + 空状态
  // ============================================================

  testWidgets('加载完成：AppBar 显示舞台名 + 角色状态条', (tester) async {
    await tester.pumpWidget(buildScreen(initialState: loadedState()));
    await tester.pumpAndSettle();

    // AppBar 标题 = 舞台名
    expect(find.text('浮士德与梅菲斯特'), findsOneWidget);

    // 角色状态条：两个角色名 + 状态/记忆计数
    expect(find.text('浮士德'), findsWidgets);
    expect(find.text('梅菲斯特'), findsWidgets);
    // 浮士德有 1 个状态值 → ⚡ + "1 " 文本节点
    expect(find.text('1 '), findsWidgets);
    // 两个角色均有 0 条记忆 → 🧠 + "0" 文本节点（可能出现多次）
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('空状态：显示各角色开局场景卡片', (tester) async {
    await tester.pumpWidget(buildScreen(initialState: loadedState()));
    await tester.pumpAndSettle();

    // 空状态引导文案
    expect(find.text('📜 契约已立'), findsOneWidget);
    expect(find.text('写下命运的指引，叙事将在契约中生长...'), findsOneWidget);

    // 每位角色的开局场景卡片（标题按角色名着色区分）
    expect(find.text('【浮士德 · 开局场景】'), findsOneWidget);
    expect(find.text('【梅菲斯特 · 开局场景】'), findsOneWidget);

    // 开局场景内容（已替换 {角色名} 占位符）
    expect(find.textContaining('烛火摇曳的书斋中'), findsOneWidget);
    expect(find.textContaining('阴影在角落中蠕动'), findsOneWidget);
  });

  // ============================================================
  // 消息流渲染
  // ============================================================

  testWidgets('消息流：命运消息 + 角色着色气泡渲染', (tester) async {
    final messages = [
      Message.fate('命运降临'),
      Message.assistant('浮士德站在书斋窗前。', roleTag: '浮士德'),
      Message.assistant('梅菲斯特从阴影中走出。', roleTag: '梅菲斯特'),
    ];
    await tester.pumpWidget(
      buildScreen(initialState: loadedState(messages: messages)),
    );
    await tester.pumpAndSettle();

    // 命运消息（用户）
    expect(find.text('命运降临'), findsOneWidget);

    // 角色消息（AI，带 roleTag → 渲染角色名标签）
    expect(find.text('浮士德站在书斋窗前。'), findsOneWidget);
    expect(find.text('梅菲斯特从阴影中走出。'), findsOneWidget);

    // 角色着色气泡：RotatedBox 竖排角色名标签出现
    // （两位角色各有 1 个角色名标签 → findsNWidgets(2)）
    expect(find.byType(RotatedBox), findsNWidgets(2));
  });

  testWidgets('消息流：全景叙事去重——无 roleTag 的消息不渲染角色标签', (tester) async {
    final messages = [
      Message.fate('命运降临'),
      // 全景消息：多位角色共享同一文本 → roleTag 为 null → 标准气泡
      Message.assistant('两人同时注视着深渊。'),
    ];
    await tester.pumpWidget(
      buildScreen(initialState: loadedState(messages: messages)),
    );
    await tester.pumpAndSettle();

    // 文本只渲染一次（不因角色数量重复）
    expect(find.text('两人同时注视着深渊。'), findsOneWidget);
    // 无角色名标签（无 RotatedBox）
    expect(find.byType(RotatedBox), findsNothing);
  });

  testWidgets('消息流：骰子系统消息渲染「命运结算」卡片', (tester) async {
    final messages = [
      Message.fate('赌一把'),
      Message.system(
        '命运结算',
        diceResults: const [
          DiceResult(
            ruleName: '命运之判',
            expression: 'roll(1d100)',
            value: 85,
            maxValue: 100,
            threshold: 70,
            success: true,
          ),
        ],
      ),
      Message.assistant('浮士德掷出了骰子。', roleTag: '浮士德'),
    ];
    await tester.pumpWidget(
      buildScreen(initialState: loadedState(messages: messages)),
    );
    await tester.pumpAndSettle();

    // 骰子卡片渲染（包含规则名与结果展示）
    expect(find.textContaining('命运之判'), findsOneWidget);
    expect(find.textContaining('85'), findsOneWidget);
  });

  // ============================================================
  // 输入交互
  // ============================================================

  testWidgets('输入命运指引并发送 → onSend 回调触发', (tester) async {
    final notifier = _FakeStageNotifier(loadedState());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stageNarrativeProvider.overrideWith(() => notifier)],
        child: localizedAppWithRoutes(
          routes: {'/settings': (_) => const Scaffold(body: Text('设置页'))},
          home: const StageNarrativeScreen(stagePath: '/tmp/test_stage'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 输入文本并点击发送
    await tester.enterText(find.byType(TextField), '命运降临');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // fake notifier 的 sendMessage 被调用，且内容正确
    expect(notifier.lastSentMessage, '命运降临');
  });

  testWidgets('空白输入不发送', (tester) async {
    final notifier = _FakeStageNotifier(loadedState());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stageNarrativeProvider.overrideWith(() => notifier)],
        child: localizedAppWithRoutes(
          routes: {'/settings': (_) => const Scaffold(body: Text('设置页'))},
          home: const StageNarrativeScreen(stagePath: '/tmp/test_stage'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(notifier.lastSentMessage, isNull);
  });

  // ============================================================
  // 操作按钮
  // ============================================================

  testWidgets('重置会话按钮存在且可点击', (tester) async {
    final notifier = _FakeStageNotifier(loadedState());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stageNarrativeProvider.overrideWith(() => notifier)],
        child: localizedAppWithRoutes(
          routes: {'/settings': (_) => const Scaffold(body: Text('设置页'))},
          home: const StageNarrativeScreen(stagePath: '/tmp/test_stage'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final resetButton = find.byIcon(Icons.restart_alt);
    expect(resetButton, findsOneWidget);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(notifier.resetSessionCalled, isTrue);
  });

  testWidgets('设置按钮存在且可跳转设置页', (tester) async {
    await tester.pumpWidget(buildScreen(initialState: loadedState()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // 路由跳转成功（占位设置页）
    expect(find.text('设置页'), findsOneWidget);
  });
}

/// 测试用 fake 舞台 Notifier：注入预设状态，记录调用而不执行真实 IO。
class _FakeStageNotifier extends StageNarrativeNotifier {
  final StageNarrativeState _initialState;

  String? lastSentMessage;
  bool loadStageCalled = false;
  bool resetSessionCalled = false;

  _FakeStageNotifier(this._initialState);

  @override
  StageNarrativeState build() => _initialState;

  @override
  Future<bool> loadStage(
    String dirPath, {
    bool restoreSaves = true,
    Set<String>? skipRestoreRoles,
  }) async {
    loadStageCalled = true;
    return true;
  }

  @override
  Future<void> sendMessage(String content) async {
    lastSentMessage = content;
  }

  @override
  void resetSession() {
    resetSessionCalled = true;
  }
}
