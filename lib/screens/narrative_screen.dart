import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../providers/providers.dart';
import '../widgets/contract_menu_item.dart';
import '../widgets/contract_panel.dart';
import '../widgets/dialogs/text_input_dialog.dart';
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
class NarrativeScreen extends ConsumerStatefulWidget {
  const NarrativeScreen({super.key});

  @override
  ConsumerState<NarrativeScreen> createState() => _NarrativeScreenState();
}

class _NarrativeScreenState extends ConsumerState<NarrativeScreen> {
  /// 消息列表控制 Key（用于 AppBar 按钮 / 快捷键控制滚动）
  final GlobalKey<MessageListState> _messageListKey =
      GlobalKey<MessageListState>();

  @override
  void initState() {
    super.initState();
    // 进入叙事页时尝试恢复默认子版（若有存档）
    Future.microtask(() {
      if (mounted) {
        ref.read(narrativeProvider.notifier).restoreSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ---- 读取状态 ----
    final state = ref.watch(narrativeProvider);
    // 契约兜底提示（用户文件缺失/损坏 → 已加载内置模板时非空）
    final fallbackNotice = ref.watch(contractFallbackNoticeProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // ---- 监听 LLM 错误：非空时提示用户，避免静默回退 ----
    ref.listen(narrativeProvider.select((s) => s.lastError), (prev, next) {
      if (next.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('╳ $next，梅菲斯特以凡俗之力回应')));
      }
    });

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
              tooltip: '存档',
              onSelected: _onSaveMenu,
              // 缩短动画时长，菜单弹出更快更流畅（共享样式见 AppTheme.popupAnimationStyle）
              popUpAnimationStyle: AppTheme.popupAnimationStyle,
              itemBuilder: (context) => [
                ContractMenuItem('save', Icons.save_outlined, '保存当前进度'),
                ContractMenuItem(
                  'save_branch',
                  Icons.account_tree_outlined,
                  '另存为分支...',
                ),
                const PopupMenuDivider(),
                ContractMenuItem('delete', Icons.delete_outline, '删除存档'),
              ],
            ),
            // 跳至第一条历史
            IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: '跳至第一条历史（Ctrl+Home）',
              onPressed: () => _messageListKey.currentState?.scrollToTop(),
            ),
            // 跳至最后一条历史
            IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: '跳至最后一条历史（Ctrl+End）',
              onPressed: () => _messageListKey.currentState?.scrollToBottom(),
            ),
            // 仪表盘按钮（查看当前契约数据）
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.dashboard),
                onPressed: () {
                  if (isMobile) {
                    _showDashboardBottomSheet();
                  } else {
                    Scaffold.of(context).openEndDrawer();
                  }
                },
                tooltip: '仪表盘',
              ),
            ),
            // 设置按钮
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              tooltip: '设置',
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

  /// 移动端仪表盘：从底部弹出面板展示契约数据。
  ///
  /// 桌面端使用右侧抽屉（[DashboardDrawer]），
  /// 移动端屏幕较窄，改为底部弹出更符合操作习惯：
  ///   - 高度约占屏幕 75%
  ///   - 顶部显示拖动把手 + 标题 + 关闭按钮
  ///   - 内容复用 [ContractPanel] 契约数据面板
  void _showDashboardBottomSheet() {
    final state = ref.read(narrativeProvider);
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      // 圆角面板（顶角）
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // 背景色跟随主题表面色
      backgroundColor: theme.scaffoldBackgroundColor,
      // 允许向下拖动关闭
      isScrollControlled: true,
      // 高度约占屏幕 75%，给内容留出充足空间
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- 顶部拖动把手 ----
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ---- 标题栏 ----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      '⚜',
                      style: TextStyle(fontSize: 20, color: AppTheme.gold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '仪表盘',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // ---- 契约数据面板（复用共享组件） ----
              Expanded(
                child: ContractPanel(
                  contract: state.contract,
                  currentState: state.currentState,
                  memories: state.memories,
                  history: state.history,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理存档菜单选择。
  Future<void> _onSaveMenu(String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(narrativeProvider.notifier);

    switch (value) {
      case 'save':
        final fileName = await notifier.saveChild();
        if (!mounted) return;
        if (fileName != null) {
          messenger.showSnackBar(SnackBar(content: Text('✦ 契约已镌刻: $fileName')));
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('╳ 存档失败：请检查契约目录权限或磁盘空间')),
          );
        }
      case 'save_branch':
        await _showSaveBranchDialog();
      case 'delete':
        final ok = await notifier.deleteSave();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(ok ? '⚰ 存档已删除' : '╳ 没有可删除的存档')),
        );
    }
  }

  /// 弹出「另存为分支」对话框，输入分支名生成 `faust.branch.meph`。
  Future<void> _showSaveBranchDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(narrativeProvider.notifier);

    final branchName = await TextInputDialog.show(
      context,
      title: '✏️ 另存为分支',
      labelText: '分支名',
      hintText: '如 dark、light、审判线',
      confirmText: '保存',
      validate: (value) => value.isNotEmpty,
    );

    if (branchName == null || branchName.isEmpty) return;
    final fileName = await notifier.saveChild(branchName: branchName);
    if (!mounted) return;
    if (fileName != null) {
      messenger.showSnackBar(SnackBar(content: Text('✦ 分支契约已镌刻: $fileName')));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('╳ 分支存档失败：请检查契约目录权限或磁盘空间')),
      );
    }
  }
}
