import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/domain/reducer_utils.dart';
import 'package:mephisto/providers/providers.dart';
import 'package:mephisto/services/session/child_save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// NarrativeNotifier 单元测试
///
/// 覆盖状态编排、生成闭环、会话操作、存档/恢复以及初始化构建等
/// 不依赖 UI 层的纯 Notifier 逻辑。网络层通过 mock HTTP 客户端隔离。
///
/// 时序注意：contractProvider 为 FutureProvider，操作 notifier 前必须先
/// `await contractProvider.future`，确保 Notifier 首次 build 即拿到已 resolve
/// 的契约，避免后续契约完成触发 Notifier 重建、重置运行时状态。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  /// 测试契约（含开局场景 + 带状态变更的规则）
  const testContract = Contract(
    roleName: '浮士德',
    worldview: '16 世纪的德意志，一个充满神秘学与契约的世界。',
    opening: '烛火摇曳的书斋中，浮士德坐在成堆的典籍之间。',
    state: [StateItem(key: '灵魂完整度', value: IntValue(100))],
    rules: [
      Rule(
        name: '堕落加深',
        condition: '包含 "堕落"',
        action: '状态.灵魂完整度 -= 10',
        line: 1,
      ),
    ],
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mephisto_provider_test_');
    SharedPreferences.setMockInitialValues({
      'mephisto_contracts_directory': tempDir.path,
      'mephisto_current_contract': 'faust.meph',
    });
    await File('${tempDir.path}/faust.meph').writeAsString(
      '【角色名】\n浮士德\n\n【世界观】\n充满契约的世界\n',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 构建 ProviderContainer：先 await 契约 resolve，确保 Notifier 稳定。
  ///
  /// narrativeProvider.build() watch 了 contractProvider 与
  /// currentContractNameProvider 两个 FutureProvider；若其首次 build 时
  /// 二者仍处于 loading，resolve 后会触发 Notifier 重建、重置运行时状态。
  /// 因此这里在首次访问 notifier 前同时预触发两个 future，保证已 resolve。
  Future<ProviderContainer> buildContainer({
    http.Client? httpClient,
    Future<LlmConfig> Function(Ref ref)? llmConfigOverride,
  }) async {
    final container = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(
          httpClient ??
              MockClient((request) async => throw Exception('mock 网络错误')),
        ),
        if (llmConfigOverride != null)
          llmConfigProvider.overrideWith(llmConfigOverride),
        contractProvider.overrideWith((ref) async => testContract),
        currentContractNameProvider.overrideWith((ref) async => 'faust.meph'),
      ],
    );
    // 修复间歇性 30s 超时：dispose 前先让事件循环 flush 掉 pending 微任务
    //（如 _autoSaveChild 的 SharedPreferences 读、记忆提取的异步尾巴），
    // 避免异步链在 container 已销毁后继续读 provider 抛
    // "Bad state: Tried to read a provider from a ProviderContainer that
    // was already disposed" 导致测试超时。
    addTearDown(() async {
      // 让出多个事件循环轮次：让所有 pending Future 的 .then 回调完成
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      container.dispose();
    });
    // 预触发两个被 Notifier watch 的 FutureProvider，避免重建竞态
    await container.read(contractProvider.future);
    await container.read(currentContractNameProvider.future);
    // 预触发 llmConfig future（可能为 error，catch 掉），避免 dispose 竞态
    if (llmConfigOverride != null) {
      try {
        await container.read(llmConfigProvider.future);
      } catch (_) {
        // 预期：GenerationFailed 测试用抛错的 llmConfig
      }
    }
    return container;
  }

  /// 轮询等待生成流程结束（sendMessage 为 fire-and-forget，需等待 isGenerating 复位）
  Future<void> waitForGeneration(
    ProviderContainer container, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (container.read(narrativeProvider).isGenerating) {
      if (DateTime.now().isAfter(deadline)) {
        fail('生成流程超时未结束');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    // 额外让出事件循环：等 _flushStreamBuffer + 记忆提取 + 自动保存的微任务完成
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  /// 构造 SSE 格式的 LLM 成功响应（符合 LlmClient.generateStream 解析要求）。
  ///
  /// 使用 [http.Response.bytes] 并以 utf8 编码 body，
  /// 避免默认 latin1 编码无法承载中文内容的 "Contains invalid characters" 错误。
  http.Response sseResponse(String content) {
    final chunks = content.isNotEmpty ? [content] : <String>[];
    final lines = [
      for (final c in chunks)
        'data: ${jsonEncode({
          'choices': [
            {'delta': {'content': c}},
          ],
        })}',
      'data: [DONE]',
    ];
    return http.Response.bytes(
      utf8.encode(lines.join('\n')),
      200,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );
  }

  group('初始化与构建', () {
    test('母版契约加载 → 状态/当前状态/messages 正确初始化', () async {
      final container = await buildContainer();
      final state = container.read(narrativeProvider);

      expect(state.sourceFileName, 'faust.meph');
      expect(state.roleName, '浮士德');
      expect(state.currentState['灵魂完整度'], const IntValue(100));
      // 母版无历史 → messages 空（正常显示开局场景）
      expect(state.messages, isEmpty);
      expect(state.isGenerating, isFalse);
    });

    test('含历史子版恢复 → 消息列表从历史完整重建', () async {
      // 写入含历史区块的子版文件
      await File('${tempDir.path}/faust.child.meph').writeAsString(
        '【角色名】\n浮士德\n\n'
        '【状态】\n- 灵魂完整度：70\n\n'
        '【历史】\n'
        '- fate: 继续前行\n'
        '- assistant：浮士德沉默着。\n',
      );

      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      final restored = await notifier.restoreChild('faust.child.meph');
      expect(restored, isTrue);
      final state = container.read(narrativeProvider);
      expect(state.sourceFileName, 'faust.child.meph');
      expect(state.currentState['灵魂完整度'], const IntValue(70));
      // 消息从历史重建：fate + assistant
      expect(state.messages, hasLength(2));
      expect(state.messages.first.content, '继续前行');
      expect(state.messages.last.content, '浮士德沉默着。');
    });

    test('契约最终兜底（Contract.empty）→ 叙事页正常初始化不崩溃', () async {
      // contractProvider 已保证自身始终成功返回（自定义契约缺失时
      // 返回空契约 + 设置 fallback notice，见 contract_provider_test）。
      // 此处验证 NarrativeNotifier 在拿到空契约时正常初始化。
      final container = ProviderContainer(
        overrides: [
          httpClientProvider.overrideWithValue(
            MockClient((request) async => throw Exception('mock 网络错误')),
          ),
          contractProvider.overrideWith((ref) async => Contract.empty()),
          currentContractNameProvider.overrideWith(
            (ref) async => 'my_story.meph',
          ),
        ],
      );
      // 与 buildContainer 一致的 dispose 时序保护：先 flush 微任务再销毁
      addTearDown(() async {
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        container.dispose();
      });
      await container.read(contractProvider.future);
      await container.read(currentContractNameProvider.future);

      final state = container.read(narrativeProvider);
      // 空契约兜底：角色名为「角色」，叙事页不崩溃
      expect(state.roleName, '角色');
      expect(state.messages, isEmpty);
      expect(state.currentState, isEmpty);
      expect(state.isGenerating, isFalse);
    });
  });

  group('sendMessage 守卫', () {
    test('空白输入不发送（不进入生成状态、不追加消息）', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);
      final before = container.read(narrativeProvider);

      notifier.sendMessage('   ');
      notifier.sendMessage('');

      final after = container.read(narrativeProvider);
      expect(after.messages, before.messages);
      expect(after.isGenerating, isFalse);
    });

    test('生成中二次发送被拒绝', () async {
      // 用 Completer 挂起 LLM 请求，确保生成状态持续
      final llmCompleter = Completer<http.Response>();
      final hangingClient = MockClient((request) => llmCompleter.future);
      final container = await buildContainer(httpClient: hangingClient);
      final notifier = container.read(narrativeProvider.notifier);

      notifier.sendMessage('第一句');
      // 推进异步流程（llmConfig 加载等），此刻 LLM 请求挂起 → isGenerating 为 true
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(narrativeProvider).isGenerating, isTrue);

      // 二次发送被拒绝：不追加消息
      final before = container.read(narrativeProvider).messages.length;
      notifier.sendMessage('第二句');
      expect(container.read(narrativeProvider).messages.length, before);

      // 完成挂起请求（非 200 → LLM 抛异常 → 本地兜底），避免遗留未完成异步
      llmCompleter.complete(http.Response('', 500));
      await waitForGeneration(container);
      expect(container.read(narrativeProvider).isGenerating, isFalse);
    });
  });

  group('生成闭环', () {
    test('LLM 失败 → 本地兜底回复 + 状态复位 + 自动生成子版', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      notifier.sendMessage('我仰望星空');
      await waitForGeneration(container);

      final state = container.read(narrativeProvider);
      // 命运消息 + 本地兜底回复
      expect(state.messages, hasLength(2));
      expect(state.messages.first.content, '我仰望星空');
      expect(state.messages.last.content, contains('值得被追问'));
      expect(state.isGenerating, isFalse);
      // 自动保存生成了子版文件
      expect(state.sourceFileName, 'faust.child.meph');
      expect(File('${tempDir.path}/faust.child.meph').existsSync(), isTrue);
    });

    test('LLM 成功 → SSE 回复写回历史 + 契约规则状态变更生效', () async {
      // 成功响应："我堕落了" 触发规则 灵魂完整度 -= 10
      final successClient = MockClient(
        (request) async => sseResponse('浮士德感到灵魂的裂痕。'),
      );
      final container = await buildContainer(httpClient: successClient);
      final notifier = container.read(narrativeProvider.notifier);

      notifier.sendMessage('我堕落了');
      await waitForGeneration(container);

      final state = container.read(narrativeProvider);
      expect(state.isGenerating, isFalse);
      // 规则状态变更：100 - 10 = 90
      expect(state.currentState['灵魂完整度'], const IntValue(90));
      // 回复写回历史
      expect(state.messages, hasLength(2));
      expect(state.messages.last.content, '浮士德感到灵魂的裂痕。');
      expect(
        state.history.last,
        const HistoryEntry(
          role: MessageRole.assistant,
          content: '浮士德感到灵魂的裂痕。',
        ),
      );
    });
    // 注：GenerationFailed 的全局兜底路径未在此处单测——
    //   - `_generateReply` 的 catch 兜底已由 narrative_screen_test（HTTP 500 → 本地兜底）覆盖
    //   - `GenerationFailed` 状态迁移已由 narrative_reducer_test 独立覆盖
    // 在 Notifier 层模拟 llmConfigProvider 抛错会触发 Riverpod dispose 时序问题，不稳定故不保留。
  });

  group('会话操作', () {
    test('setState 更新单个状态值', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      notifier.setState('灵魂完整度', const IntValue(50));
      expect(
        container.read(narrativeProvider).currentState['灵魂完整度'],
        const IntValue(50),
      );
    });

    test('resetSession 保留契约、清空动态数据', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      // 先产生动态数据
      notifier.setState('灵魂完整度', const IntValue(30));
      notifier.attachContext('scene.txt', '书斋的镜子里有影子');
      notifier.sendMessage('重置前的对话');
      await waitForGeneration(container);

      notifier.resetSession();

      final state = container.read(narrativeProvider);
      // 契约保留，动态数据清空
      expect(state.roleName, '浮士德');
      expect(state.messages, isEmpty);
      expect(state.history, isEmpty);
      expect(state.memories, isEmpty);
      expect(state.currentState['灵魂完整度'], const IntValue(100)); // 回契约初始值
      expect(state.attachedContexts, isEmpty);
      expect(state.isGenerating, isFalse);
    });

    test('附加上下文 CRUD', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      notifier.attachContext('scene.txt', '书斋的镜子里有影子');
      notifier.attachContext('town.txt', '市集人声鼎沸');
      expect(
        container.read(narrativeProvider).attachedFileNames,
        ['scene.txt', 'town.txt'],
      );
      expect(
        container.read(narrativeProvider).attachedContexts,
        ['书斋的镜子里有影子', '市集人声鼎沸'],
      );

      notifier.removeAttachedContext(0);
      expect(
        container.read(narrativeProvider).attachedFileNames,
        ['town.txt'],
      );
      // 越界移除忽略
      notifier.removeAttachedContext(99);
      expect(
        container.read(narrativeProvider).attachedFileNames,
        ['town.txt'],
      );

      notifier.clearAttachedContexts();
      expect(container.read(narrativeProvider).attachedFileNames, isEmpty);
      expect(container.read(narrativeProvider).attachedContexts, isEmpty);
    });
  });

  group('存档与恢复', () {
    test('restoreChild 文件不存在 → 返回 false 且状态不变', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);
      final before = container.read(narrativeProvider);

      final restored = await notifier.restoreChild('不存在.meph');
      expect(restored, isFalse);
      expect(container.read(narrativeProvider), before);
    });

    test('deleteChild 删除文件', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      // 创建存档文件
      await ChildSaveStore.save(
        'faust.meph',
        container.read(narrativeProvider).contract,
        currentState: const {},
        memories: const [],
        history: const [],
      );
      expect(File('${tempDir.path}/faust.child.meph').existsSync(), isTrue);

      final deleted = await notifier.deleteChild('faust.child.meph');
      expect(deleted, isTrue);
      expect(File('${tempDir.path}/faust.child.meph').existsSync(), isFalse);
      // 再次删除返回 false
      expect(await notifier.deleteChild('faust.child.meph'), isFalse);
    });

    test('listChildFiles 列出当前母版的所有子版', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      // 创建多个分支文件
      await File('${tempDir.path}/faust.child.meph').writeAsString('【角色名】\n浮士德\n');
      await File('${tempDir.path}/faust.dark.meph').writeAsString('【角色名】\n浮士德\n');

      final files = await notifier.listChildFiles();
      expect(files, containsAll(['faust.child.meph', 'faust.dark.meph']));
    });

    test('defaultChildFileName 静态方法', () {
      expect(
        NarrativeNotifier.defaultChildFileName('faust.meph'),
        'faust.child.meph',
      );
      // 多级分支（如 faust.dark.meph）拥有独立于母版根的默认存档：
      // 与 SessionSaver.saveCurrent 的存档命名规则一致（faust.dark.child.meph），
      // 旧实现仅取母版根（faust.child.meph）会导致分支存档无法恢复/删除。
      expect(
        NarrativeNotifier.defaultChildFileName('faust.dark.meph'),
        'faust.dark.child.meph',
      );
      // 存档自身作为来源时：直接返回自己的文件名（faust.dark.child.meph）
      expect(
        NarrativeNotifier.defaultChildFileName('faust.dark.child.meph'),
        'faust.dark.child.meph',
      );
    });

    test('historyToMessages 将历史转换为消息列表', () {
      const history = [
        HistoryEntry(role: MessageRole.fate, content: '命运'),
        HistoryEntry(role: MessageRole.assistant, content: '回复'),
        HistoryEntry(role: MessageRole.system, content: '骰子结算'),
      ];
      final messages = historyToMessages(history);
      expect(messages, hasLength(3));
      expect(messages[0].role, MessageRole.fate);
      expect(messages[1].role, MessageRole.assistant);
      expect(messages[2].role, MessageRole.system);
      expect(messages.map((m) => m.content), ['命运', '回复', '骰子结算']);
    });

    test('hotReloadContract 同时应用规则与记忆中区块', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      // 准备带记忆和规则的完整契约文本
      const content = '''
【角色名】
浮士德

【规则】
[新规则] if 包含 "试验" -> 状态.灵魂完整度 -= 5

【记忆】
- [5] 核心誓言：与梅菲斯特立下终极赌约
- [4] 重大事件：在黑森林中遭遇狼人
- 无前缀记忆（默认权重 3）
''';

      notifier.hotReloadContract(content);

      final state = container.read(narrativeProvider);
      // 规则已热更新
      expect(state.contract.rules, hasLength(1));
      expect(state.contract.rules.first.name, '新规则');
      // 记忆已热更新（含权重解析）
      expect(state.memories, hasLength(3));
      expect(state.memories[0].content, '核心誓言：与梅菲斯特立下终极赌约');
      expect(state.memories[0].importance, 5);
      expect(state.memories[1].content, '重大事件：在黑森林中遭遇狼人');
      expect(state.memories[1].importance, 4);
      expect(state.memories[2].content, '无前缀记忆（默认权重 3）');
      expect(state.memories[2].importance, Memory.defaultImportance);
      // 角色等静态字段保留原运行版本
      expect(state.contract.roleName, '浮士德');
    });

    test('hotReloadContract 解析失败时保留原状态', () async {
      final container = await buildContainer();
      final notifier = container.read(narrativeProvider.notifier);

      notifier.hotReloadContract('【角色名】\n浮士德\n\n【记忆】\n- 没有权重');

      // 记忆应成功应用（因为这段内容是合法契约）
      final state = container.read(narrativeProvider);
      expect(state.memories, hasLength(1));

      // 再传入非法内容，应保留当前状态并设定错误提示
      notifier.hotReloadContract('【规则】\n[不完整规则');
      final state2 = container.read(narrativeProvider);
      expect(state2.memories, hasLength(1)); // 记忆未被破坏
      expect(state2.lastError, isNotEmpty); // 错误提示已设置
    });
  });
}
