import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../domain/stage_color_palette.dart';
import '../providers/providers.dart';
import '../services/storage/stage_repo.dart';
import '../widgets/narrative/input_bar.dart';
import '../widgets/narrative/message_list.dart';
import '../widgets/narrative/narrative_scaffold.dart';
import '../widgets/narrative/role_status_bar.dart';
import '../widgets/narrative/smart_jump_button.dart';
import '../widgets/narrative/stage_empty_state.dart';
import '../widgets/narrative/stage_message_bubble.dart';
import '../widgets/narrative/width_constrained_center.dart';

/// 舞台叙事主界面（多角色）
///
/// 展示多角色舞台的共享消息流 + 单输入框（命运指引）。
/// 消息流按 `【角色名】` 分节展示；输入发送后由 [StageTurnService]
/// 单次 LLM 调用 → 分节解析 → 各角色独立回写。
///
/// 角色消息气泡（[StageMessageBubble]）按角色着色：
///   - 左侧竖排角色名标签 + 左边框使用该角色的主题色
///   - roleTag 为空 / 色板不可查时退化为标准 [MessageBubble]
class StageNarrativeScreen extends ConsumerStatefulWidget {
  /// 舞台目录绝对路径
  final String stagePath;

  /// 是否恢复各角色存档（续玩）。false = 跳过存档、直接进入母版开局
  /// （「重新开始」语义，由首页舞台卡片「重新开始」菜单传入）。
  final bool restoreSaves;

  /// 跳过存档恢复的角色名集合（从母版干净开局），其余角色恢复各自存档。
  ///
  /// 用于首页舞台卡展开区「按角色选择母版/子版」：
  ///   - 点击某角色母版行 → 传 `{该角色}`（该角色从母版整合，其余续玩）
  ///   - 点击某角色子版行 → 不传该角色（自动恢复其存档 = 子版续玩）
  /// null 表示所有角色按 [restoreSaves] 统一处理（默认行为）。
  final Set<String>? skipRestoreRoles;

  const StageNarrativeScreen({
    super.key,
    required this.stagePath,
    this.restoreSaves = true,
    this.skipRestoreRoles,
  });

  @override
  ConsumerState<StageNarrativeScreen> createState() =>
      _StageNarrativeScreenState();
}

class _StageNarrativeScreenState extends ConsumerState<StageNarrativeScreen> {
  final GlobalKey<MessageListState> _messageListKey =
      GlobalKey<MessageListState>();

  @override
  void initState() {
    super.initState();
    // 加载舞台；续玩（restoreSaves=true）自动恢复各角色存档，
    // 重新开始（false）跳过存档、干净地从母版角色卡开局。
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(stageNarrativeProvider.notifier)
          .loadStage(
            widget.stagePath,
            restoreSaves: widget.restoreSaves,
            skipRestoreRoles: widget.skipRestoreRoles,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    // ---- 窄监听：仅依赖所需字段，避免流式 chunk 触发整页重建 ----
    // 与单角色叙事页同一策略：streamingContent 每 50ms 变化只重建
    // 消息流区域（_StageNarrativeMessageFlow），AppBar/输入栏/状态条不随
    // 打字机效果刷新。
    final l10n = AppLocalizations.of(context);
    final isGenerating = ref.watch(
      stageNarrativeProvider.select((s) => s.isGenerating),
    );
    final stageName = ref.watch(
      stageNarrativeProvider.select((s) => s.stageName),
    );
    final lastError = ref.watch(
      stageNarrativeProvider.select((s) => s.lastError),
    );
    final attachedFileNames = ref.watch(
      stageNarrativeProvider.select((s) => s.attachedFileNames),
    );
    // 舞台角色（加载完成后不变；null = 加载中）——消息流空态与色板所需
    final stage = ref.watch(stageNarrativeProvider.select((s) => s.stage));
    // 各角色运行时状态/记忆（RoleStatusBar 所需）
    final roles = ref.watch(stageNarrativeProvider.select((s) => s.roles));

    // 叙事内容宽度偏好（与单角色叙事页共用，保证输入框宽度一致）
    final contentMaxWidth = ref.watch(narrativeWidthProvider).maxWidth;
    // 角色色板：舞台所有角色 → 主题色（仅依赖 stage，加载后不变）
    final roleColors = stage == null
        ? const <String, Color>{}
        : assignRoleColors(
            stage.characters.map((c) => c.roleName).toList(),
          );

    // ---- 错误监听（LLM 错误 → SnackBar）已由 [NarrativeScaffold] 统一处理 ----

    // ---- 构建界面：共享骨架（快捷键 + 错误监听）----
    return NarrativeScaffold(
      messageListKey: _messageListKey,
      lastError: lastError,
      scaffoldBuilder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            stageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // 智能跳转：顶部附近 → 跳到底部；其余 → 跳到顶部
            // （与单角色叙事页共用，消除重复实现）
            SmartJumpButton(messageListKey: _messageListKey),
            // 重置会话（回到母版开局）：清除所有动态数据/存档会话，
            // 对齐单角色叙事页「重置」语义——有存档时也能回母版重新开始。
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: l10n.stageNarrativeReset,
              onPressed: () {
                ref.read(stageNarrativeProvider.notifier).resetSession();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(l10n.stageNarrativeResetDone)),
                  );
              },
            ),
            // 设置入口（与单角色叙事页一致）
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              tooltip: l10n.narrativeSettings,
            ),
          ],
        ),
      body: Column(
        children: [
          // ---- 角色状态条（轻量）----
          // 垂直滚轮委托：鼠标在状态条区域滚动时转发给消息流，
          // 对齐单角色「屏幕任意位置滚动都生效」的桌面端体验。
          RoleStatusBar(
            stage: stage,
            roles: roles,
            onVerticalScroll: (deltaY) =>
                _messageListKey.currentState?.scrollBy(deltaY),
          ),
          // ---- 消息流（独立 ConsumerWidget：窄监听，流式只重建本区域）----
          Expanded(
            child: _StageNarrativeMessageFlow(
              messageListKey: _messageListKey,
              contentMaxWidth: contentMaxWidth,
              stage: stage,
              roleColors: roleColors,
              isGenerating: isGenerating,
            ),
          ),
          // ---- 输入栏（复用 [InputBar]，与单角色叙事页一致）----
          // 宽度约束与单角色叙事页共用 `WidthConstrainedCenter`，
          // 保证两个页面输入框宽度/居中方式完全一致。
          WidthConstrainedCenter(
            contentMaxWidth: contentMaxWidth,
            child: InputBar(
              isGenerating: isGenerating,
              onSend: (text) {
                if (text.trim().isEmpty) return;
                ref.read(stageNarrativeProvider.notifier).sendMessage(text);
              },
              onStop: () {
                ref.read(stageNarrativeProvider.notifier).stopGenerating();
              },
              onReveal: () {
                ref.read(stageNarrativeProvider.notifier).revealStreaming();
              },
              showAttachment: true,
              attachedFileNames: attachedFileNames,
              onAttach: (fileName, content) {
                ref
                    .read(stageNarrativeProvider.notifier)
                    .attachContext(fileName, content);
              },
              onRemoveAttach: (index) {
                ref
                    .read(stageNarrativeProvider.notifier)
                    .removeAttachedContext(index);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// 舞台叙事消息流（窄监听消费者）
///
/// 独立 [ConsumerWidget]：只 watch `messages` / `streamingContent` /
/// `isGenerating`，使 LLM 流式输出期间只有本区域重建，AppBar / 输入栏 /
/// 角色状态条不随打字机效果刷新（与单角色 `_NarrativeMessageFlow` 同一策略）。
class _StageNarrativeMessageFlow extends ConsumerWidget {
  /// 消息列表控制 Key（滚动跳转）
  final GlobalKey<MessageListState> messageListKey;

  /// 消息内容最大宽度（null 表示满屏）
  final double? contentMaxWidth;

  /// 舞台数据（null = 加载中，显示进度圈）
  final StageLoaded? stage;

  /// 角色色板（按角色着色气泡）
  final Map<String, Color> roleColors;

  /// 是否正在生成
  final bool isGenerating;

  const _StageNarrativeMessageFlow({
    required this.messageListKey,
    required this.contentMaxWidth,
    required this.stage,
    required this.roleColors,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(
      stageNarrativeProvider.select((s) => s.messages),
    );
    final streamingContent = ref.watch(
      stageNarrativeProvider.select((s) => s.streamingContent),
    );

    if (stage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // 舞台已加载、无消息且未在生成 → 展示各角色开局场景卡片
    // （对齐单角色叙事页的 EmptyState 空态体验）
    if (messages.isEmpty && !isGenerating) {
      return StageEmptyState(
        openings: [
          for (final c in stage!.characters)
            (
              c.roleName,
              c.contract.opening.replaceAll('{角色名}', c.roleName),
            ),
        ],
        roleColors: roleColors,
      );
    }
    return MessageList(
      key: messageListKey,
      messages: messages,
      streamingContent: streamingContent,
      isGenerating: isGenerating,
      // 遵循用户选择的叙事内容宽度档位（与单角色叙事页一致）
      contentMaxWidth: contentMaxWidth,
      messageBuilder: (message, isStreaming) => StageMessageBubble(
        message: message,
        roleColors: roleColors,
        isStreaming: isStreaming,
      ),
    );
  }
}
