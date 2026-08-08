import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../app/theme.dart';
import '../domain/narrative_error.dart';
import '../providers/providers.dart';
import '../screens/contract_editor_screen.dart';
import '../services/contract_file_watcher.dart';
import '../services/narrative_error_localizer.dart';
import '../services/parser/meph_serializer.dart';
import '../services/session/child_save_store.dart';
import '../services/storage/contract_repo.dart';
import '../widgets/contract_menu_item.dart';
import '../widgets/dialogs/save_branch_dialog.dart';
import '../widgets/narrative/dashboard_bottom_sheet.dart';
import '../widgets/narrative/dashboard_drawer.dart';
import '../widgets/narrative/empty_state.dart';
import '../widgets/narrative/input_bar.dart';
import '../widgets/narrative/message_list.dart';
import '../widgets/narrative/status_bar.dart';
import '../widgets/narrative/width_constrained_center.dart';

/// 叙事主界面
///
/// 展示叙事对话流，包含：
///   - 天幕栏：角色名 + 存档/仪表盘/设置按钮
///   - 叙事流：消息列表（命运/角色/系统）
///   - 输入区：命运输入框 + 发送按钮
///   - 状态条：规则/记忆/历史数量
///
/// 存档机制（母版/子版）：
///   - 进入页面时自动恢复最近存档；每轮对话自动覆盖保存子版文件（`faust.child.meph`）
///   - AppBar 存档菜单支持：保存、另存为分支、删除
///
/// 规则热重载：
///   - 通过 [FileSystemEntity.watch] 监听当前打开的 .meph 文件，
///     外部编辑器（VSCode）保存后自动热更新规则（对齐 CLI 版 fsnotify 体验）
///   - 编辑按钮打开应用内编辑器，保存同样由文件监听统一触发热重载
class NarrativeScreen extends ConsumerStatefulWidget {
  const NarrativeScreen({super.key});

  @override
  ConsumerState<NarrativeScreen> createState() => _NarrativeScreenState();
}

class _NarrativeScreenState extends ConsumerState<NarrativeScreen> {
  /// 消息列表控制 Key（用于 AppBar 按钮 / 快捷键控制滚动）
  final GlobalKey<MessageListState> _messageListKey =
      GlobalKey<MessageListState>();

  /// 契约文件变更监听器（外部编辑器保存 → 规则热重载）
  ContractFileWatcher? _fileWatcher;

  @override
  void initState() {
    super.initState();
    // 进入叙事页时尝试恢复默认子版（若有存档）。
    // 若存在存档但恢复失败（如文件被外部损坏），静默进入空会话会让用户
    // 误以为存档丢失，因此通过 SnackBar 给出明确提示。
    Future.microtask(() async {
      if (!mounted) return;
      // 首次监听：提前到 initState 中的 microtask 执行，
      // 避免每次 build() 重复注册 addPostFrameCallback
      _startFileWatch(ref.read(narrativeProvider).sourceFileName);

      final notifier = ref.read(narrativeProvider.notifier);
      final restored = await notifier.restoreSession();
      if (restored || !mounted) return;

      // 恢复失败：区分「无存档（正常情况）」与「存档存在但恢复失败（异常）」
      final state = ref.read(narrativeProvider);
      final hasSave = await ChildSaveStore.exists(
        NarrativeNotifier.defaultChildFileName(state.sourceFileName),
      );
      if (hasSave && mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.narrativeRestoreFailed)),
          );
      }
    });
  }

  @override
  void dispose() {
    _fileWatcher?.dispose();
    _fileWatcher = null;
    super.dispose();
  }

  /// 启动对指定 .meph 文件的监听（仅在文件名变化时重新绑定）。
  ///
  /// 监听目标 = 当前源文件 + 其母版：[ContractFileWatcher] 会自动推导母版名，
  /// 使外部（VSCode）修改母版 .meph 也能被感知——创作者通常编辑母版契约。
  ///
  /// 外部编辑器保存 → 防抖 500ms → 读取实际变化文件 → 规则/记忆热重载（保留运行态）。
  /// 具体监听/防抖/mtime 抑制逻辑已抽至 [ContractFileWatcher]。
  Future<void> _startFileWatch(String fileName) async {
    // 文件名未变化时不重复绑定
    if (fileName.isEmpty ||
        (_fileWatcher?.watchedFileName == fileName)) {
      return;
    }

    final watcher = (_fileWatcher ??= ContractFileWatcher(
      // 文件变更 → 读取最新内容 → 规则/记忆热重载 → 补存子版
      onFileChanged: _handleFileChanged,
      onUnavailable: _showFileWatchUnavailable,
    ));
    await watcher.start(fileName);
  }

  /// 文件监听不可用提示（一次性 SnackBar，避免重复打扰）。
  ///
  /// 文件系统不支持监听（如某些网络文件系统）或监听流报错时，
  /// 规则热重载将失效——但叙事主流程不受影响，通过提示让用户知晓。
  void _showFileWatchUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).narrativeFileWatchUnavailable),
        ),
      );
  }

  /// 文件变更后的热重载处理：读取实际变化文件的最新内容 → 规则/记忆热更新 →
  /// 补存子版。
  ///
  /// [fileName] 为**实际变化**的文件名（当前源文件名或其母版名）：
  ///   - 修改子版（当前源）→ 按子版内容热重载
  ///   - 修改母版 → 按母版内容热重载（创作者通常编辑母版）
  ///
  /// 注意：此回调由 [ContractFileWatcher] 在防抖 + mtime 抑制后调用，
  /// 且处理期间监听已由 watcher 暂停，完成后恢复（避免死循环）。
  Future<void> _handleFileChanged(String fileName) async {
    if (!mounted) return;
    final notifier = ref.read(narrativeProvider.notifier);

    // 读取实际变化文件的最新内容（若文件已被删除则跳过）
    final content = await readContract(fileName);
    if (content == null || !mounted) return;

    notifier.hotReloadContract(content);
    await notifier.saveChild();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).narrativeHotReloadNotice),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // ---- 读取状态 ----
    final state = ref.watch(narrativeProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    // 契约兜底提示（用户文件缺失/损坏 → 已加载内置模板时非空）
    // 注意：契约兜底提示来自 Provider 层，可能为错误码，需要本地化翻译
    final rawFallbackNotice = ref.watch(contractFallbackNoticeProvider);
    final fallbackNotice = rawFallbackNotice == null
        ? null
        : isNarrativeErrorCode(rawFallbackNotice)
            ? localizeNarrativeError(l10n, rawFallbackNotice)
            : rawFallbackNotice;

    // ---- 监听 LLM 错误：非空时提示用户，避免静默回退 ----
    ref.listen(narrativeProvider.select((s) => s.lastError), (prev, next) {
      if (next.isNotEmpty) {
        final l10n = AppLocalizations.of(context);
        // 错误码 → 本地化文本；自由格式错误文本（如 LLM 异常信息）直接展示
        final displayError = isNarrativeErrorCode(next)
            ? localizeNarrativeError(l10n, next)
            : next;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.narrativeErrorPrefix(displayError)),
            ),
          );
      }
    });

    // ---- 文件监听：sourceFileName 变化（重开子版/切换契约）时重绑 ----
    // 首次绑定已在 initState 的 microtask 中完成，此处仅监听后续变化
    ref.listen(
      narrativeProvider.select((s) => s.sourceFileName),
      (prev, next) => _startFileWatch(next),
    );

    // ---- 获取数据 ----
    final roleName = state.roleName;
    final isGenerating = state.isGenerating;
    final opening = state.contract.opening.replaceAll('{角色名}', roleName);
    // 叙事内容宽度偏好（桌面端可选，移动端自动占满）
    final narrativeWidth = ref.watch(narrativeWidthProvider);
    final contentMaxWidth = narrativeWidth.maxWidth;
    // 移动端检测（宽度 < 600 时仪表盘改为底部弹出，而非右侧抽屉）
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // ---- 构建界面 ----
    return CallbackShortcuts(
      // 桌面端快捷键（移动端无实体键盘，使用 AppBar 按钮替代）：
      //   Ctrl+Home → 跳至第一条历史
      //   Ctrl+End  → 跳至最后一条历史
      bindings: {
        const SingleActivator(LogicalKeyboardKey.home, control: true): () =>
            _messageListKey.currentState?.scrollToTop(),
        const SingleActivator(LogicalKeyboardKey.end, control: true): () =>
            _messageListKey.currentState?.scrollToBottom(),
      },
      child: Scaffold(
        // 仪表盘：桌面端右侧抽屉；移动端改用底部弹出面板
        endDrawer: isMobile ? null : DashboardDrawer(state: state),

        // 天幕栏
        appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              // 可用宽度不足以容纳「▸ 分支名」时整体隐藏箭头，
              // 避免出现文本已消失但箭头孤立的窄屏问题。
              // 120 为「 ▸ 」+ 两侧间距 + 最小分支名宽度的估算值。
              final showBranch =
                  state.branchName.isNotEmpty && constraints.maxWidth > 120;

              return Row(
                children: [
                  // 角色名（始终优先保留）
                  Flexible(
                    child: Text(
                      roleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 分支名（空间充足时显示，长文件名省略号截断）
                  if (showBranch) ...[
                    const SizedBox(width: 6),
                    const Text('▸', style: TextStyle(color: AppTheme.gold)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        state.branchName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: AppTheme.crimson,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            // 存档菜单（保存/另存为/删除）
            PopupMenuButton<String>(
              icon: const Icon(Icons.save_outlined),
              tooltip: AppLocalizations.of(context).narrativeSaveMenu,
              onSelected: _onSaveMenu,
              // 缩短动画时长，菜单弹出更快更流畅（共享样式见 AppTheme.popupAnimationStyle）
              popUpAnimationStyle: AppTheme.popupAnimationStyle,
              itemBuilder: (context) => [
                ContractMenuItem('save', Icons.save_outlined, l10n.narrativeSaveCurrent),
                ContractMenuItem(
                  'save_branch',
                  Icons.account_tree_outlined,
                  l10n.narrativeSaveBranch,
                ),
                const PopupMenuDivider(),
                ContractMenuItem('delete', Icons.delete_outline, l10n.narrativeDeleteSave),
              ],
            ),
            // 跳至第一条历史（消息流垂直滚动 → 用垂直双箭头表达「跳到顶」）
            IconButton(
              icon: const Icon(Icons.keyboard_double_arrow_up),
              tooltip: l10n.narrativeScrollTop,
              onPressed: () => _messageListKey.currentState?.scrollToTop(),
            ),
            // 跳至最后一条历史（消息流垂直滚动 → 用垂直双箭头表达「跳到底」）
            IconButton(
              icon: const Icon(Icons.keyboard_double_arrow_down),
              tooltip: l10n.narrativeScrollBottom,
              onPressed: () => _messageListKey.currentState?.scrollToBottom(),
            ),
            // 编辑当前契约（打开应用内编辑器；保存由文件监听自动热更新）
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.narrativeEditContract,
              onPressed: _openContractEditor,
            ),
            // 仪表盘按钮（查看当前契约数据）
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.dashboard),
                onPressed: () {
                  if (isMobile) {
                    DashboardBottomSheet.show(context, state);
                  } else {
                    Scaffold.of(context).openEndDrawer();
                  }
                },
                tooltip: l10n.narrativeDashboard,
              ),
            ),
            // 设置按钮
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              tooltip: l10n.narrativeSettings,
            ),
          ],
        ),

        // 主体：滚动区域（消息流）占满全屏宽，鼠标在屏幕任意位置滚动都生效；
        // 内容宽度档位下移到「每条消息 / 底部栏」层逐项约束，保持居中阅读体验。
        body: Column(
          children: [
            // ---- 契约兜底提示条（用户文件缺失/损坏时置顶提醒） ----
            if (fallbackNotice != null)
              Material(
                color: const Color(0xFFFFF3E0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFB26A00),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fallbackNotice,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8C5A00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 叙事流（消息列表或空状态）—— 滚动视口全宽，条目内部受限居中
            Expanded(
              child: state.messages.isEmpty && !isGenerating
                  ? EmptyState(opening: opening)
                  : MessageList(
                      key: _messageListKey,
                      messages: state.messages,
                      streamingContent: state.streamingContent,
                      isGenerating: isGenerating,
                      contentMaxWidth: contentMaxWidth,
                    ),
            ),

            // 输入区（StatefulWidget 管理 Controller 生命周期）—— 居中受限
            WidthConstrainedCenter(
              contentMaxWidth: contentMaxWidth,
              child: InputBar(isGenerating: isGenerating),
            ),

            // 状态条 —— 居中受限
            WidthConstrainedCenter(
              contentMaxWidth: contentMaxWidth,
              child: StatusBar(
                ruleCount: state.ruleCount,
                memoryCount: state.memoryCount,
                historyCount: state.historyCount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理存档菜单选择。
  Future<void> _onSaveMenu(String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(narrativeProvider.notifier);
    final l10n = AppLocalizations.of(context);

    switch (value) {
      case 'save':
        final fileName = await notifier.saveChild();
        if (!mounted) return;
        if (fileName != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.narrativeSaveSuccess(fileName))),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.narrativeSaveFail)),
          );
        }
        break;
      case 'save_branch':
        await _showSaveBranchDialog();
        break;
      case 'delete':
        final ok = await notifier.deleteSave();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok ? l10n.narrativeDeleteSaveSuccess : l10n.narrativeDeleteSaveNone,
            ),
          ),
        );
        break;
    }
  }

  /// 打开契约编辑器编辑当前正在游玩的 .meph 文件。
  ///
  /// 职责瘦身：本方法只负责「打开编辑器」——保存动作产生的文件写入，
  /// 由 [_startFileWatch] 的文件监听统一感知并触发热重载（避免双重触发）。
  ///
  /// 编辑器内容预填当前契约的完整快照（静态区块 + 运行时状态/记忆/历史）。
  Future<void> _openContractEditor() async {
    final state = ref.read(narrativeProvider);

    // 预填完整快照：静态区块 + 运行时状态/记忆/历史
    final fullContent = serializeMeph(
      state.contract,
      runtimeState: state.currentState,
      memories: state.memories,
      history: state.history,
    );

    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractEditorScreen(
          fileName: state.sourceFileName,
          initialContent: fullContent,
        ),
      ),
    );
    // 编辑器保存后不在此手动热重载：
    // 文件监听已检测到写入并触发 [NarrativeNotifier.hotReloadContract]
  }

  /// 弹出「另存为分支」对话框，输入分支名 + 可选「命运说明」，
  /// 生成 `faust.branch.meph`（命运说明以 `@命运:` 标记写入子版）。
  Future<void> _showSaveBranchDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(narrativeProvider.notifier);
    final l10n = AppLocalizations.of(context);

    final result = await SaveBranchDialog.show(context);
    if (result == null) return;

    final (branchName, branchTitle) = result;
    if (branchName.isEmpty) return;

    final fileName = await notifier.saveChild(
      branchName: branchName,
      branchTitle: branchTitle,
    );
    if (!mounted) return;
    if (fileName != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.narrativeBranchSaved(fileName))),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.narrativeBranchFail)),
      );
    }
  }
}