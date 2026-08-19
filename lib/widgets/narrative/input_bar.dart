import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/input_history_provider.dart';

/// 附件内容最大字数（避免撑爆 LLM 上下文窗口）
const int _maxAttachmentChars = 2000;

/// 允许的附件扩展名（仅纯文本格式，图片/Excel/PPT 等二进制不支持）
const List<String> _allowedExtensions = [
  'txt',
  'md',
  'meph',
  'json',
  'log',
  'csv',
  'yaml',
  'yml',
];

/// 叙事输入栏：输入框 + 可选附件按钮 + 发送按钮
///
/// 业务操作通过回调注入（使单角色叙事页与多角色舞台页可完全复用），
/// 但命运指引输入历史（↑ / ↓ 回溯）是全局持久化偏好，直接使用
/// [inputHistoryProvider] 管理——跨会话/跨契约保留，退出重进不丢失。
///
/// 附件功能说明（[showAttachment] = true 时启用）：
///   - 📎 按钮打开系统文件选择器（仅限 .txt / .md 等文本格式）
///   - 附件是**会话级**附加上下文，作为「补充上下文」注入 LLM
///   - 附件按钮不抢输入框焦点，选择完成后焦点回归，回车发送不受影响
class InputBar extends ConsumerStatefulWidget {
  /// 是否正在生成 AI 回复（此时禁用输入与发送）
  final bool isGenerating;

  /// 发送消息回调（输入非空且非生成中时触发）
  final ValueChanged<String> onSend;

  /// 停止当前生成回调（生成中时点击发送按钮变为「停止」按钮）
  final VoidCallback onStop;

  /// 「立即显示全文」回调（生成中显示 ⏩ 按钮，点击跳过剩余打字机动画）；
  /// 为 null 时不显示该按钮。
  final VoidCallback? onReveal;

  /// 是否启用附件功能（单角色叙事与多角色舞台均已启用）
  final bool showAttachment;

  /// 当前附件文件名列表（用于在输入框上方展示附件 chip，可单独移除）
  final List<String> attachedFileNames;

  /// 附加文件回调：输入框选择并读取文本文件后触发，
  /// 由调用方写入各自的会话状态。
  final void Function(String fileName, String content)? onAttach;

  /// 移除指定索引附件回调（由调用方更新各自会话状态）。
  final ValueChanged<int>? onRemoveAttach;

  const InputBar({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    this.onReveal,
    this.showAttachment = false,
    this.attachedFileNames = const [],
    this.onAttach,
    this.onRemoveAttach,
  });

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  final _controller = TextEditingController();

  /// 输入框焦点节点。
  ///
  /// 键盘事件处理直接绑定在焦点节点上（而非外层 Focus 包裹），
  /// 确保 Enter 在 TextField 内部 EditableText 处理之前被拦截：
  ///   - Enter（无 Shift）→ 发送（_sendMessage）
  ///   - Shift+Enter → 放行（EditableText 插入换行）
  /// 旧实现用外层 `Focus(onKeyEvent:)` 包裹 TextField，但键盘事件
  /// 先到达焦点节点本身，EditableText 在 multiline 模式下消费 Enter
  /// 插入换行并返回 handled，外层 Focus 收不到事件，产生
  /// 「第一次回车换行、第二次才提交」的问题。
  late FocusNode _focusNode;

  /// 历史回溯游标：-1 = 当前编辑态；≥0 = 正在浏览历史
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;

    _controller.clear();
    // 发送后记录到全局持久化历史（跨会话/跨契约保留）
    ref.read(inputHistoryProvider.notifier).push(text);
    widget.onSend(text);
    _focusNode.requestFocus();
  }

  /// 桌面端判断（用于多行输入 / 键盘快捷键；移动端保持单行回车发送）。
  bool get _isDesktop {
    final platform = Theme.of(context).platform;
    return switch (platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  /// 当前全局持久化输入历史（跨会话保留，最多 5 条）。
  ///
  /// 注意：本 getter 只在键盘事件回调（↑/↓）中读取，**不在 build 阶段**。
  /// 因此必须用 [WidgetRef.read] 而非 [WidgetRef.watch]——watch 在事件
  /// 路径上注册订阅违反 Riverpod 契约（只允许在 build 中使用），
  /// 且 widget 卸载后调用会触发 StateError。
  List<String> get _history => ref.read(inputHistoryProvider);

  /// ↑ 回溯上一条历史输入。
  void _historyBack() {
    if (_history.isEmpty) return;
    if (_historyIndex == -1) {
      _historyIndex = _history.length - 1;
    } else if (_historyIndex > 0) {
      _historyIndex--;
    }
    _setHistoryText(_history[_historyIndex]);
  }

  /// ↓ 前进到下一条历史输入；到达末尾后回到空白编辑态。
  void _historyForward() {
    if (_history.isEmpty || _historyIndex == -1) return;
    _historyIndex++;
    if (_historyIndex >= _history.length) {
      _historyIndex = -1;
      _setHistoryText('');
    } else {
      _setHistoryText(_history[_historyIndex]);
    }
  }

  /// 设置输入框文本并把光标移到末尾。
  void _setHistoryText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 处理桌面端键盘事件：
  ///   - Enter（无 Shift）→ 发送
  ///   - Shift+Enter → 换行
  ///   - ↑ / ↓ → 回溯输入历史
  /// 移动端软键盘回车发送保持不变（走 [TextField.onSubmitted]）。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 仅桌面端启用多行 + 快捷键；移动端保持单行回车发送
    if (!_isDesktop) return KeyEventResult.ignored;

    // 同时匹配主键盘区 Enter 与方向键区域/小键盘的 NumpadEnter
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        // Shift+Enter → 交给 TextField 插入换行
        return KeyEventResult.ignored;
      }
      // Enter → 发送并阻止插入换行
      _sendMessage();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _historyBack();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _historyForward();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 选择并附加多个文本文件（限定文本格式，支持多选）
  Future<void> _attachFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final onAttach = widget.onAttach;
    final l10n = AppLocalizations.of(context);
    if (onAttach == null) return;

    const typeGroup = XTypeGroup(label: '文本文件', extensions: _allowedExtensions);
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return; // 用户取消

    for (final file in files) {
      try {
        // 读取 UTF-8 文本（二次校验：二进制/非文本会读取失败）
        final content = await file.readAsString();
        if (content.trim().isEmpty) continue;
        final trimmed = content.trim();
        final limited = trimmed.length > _maxAttachmentChars
            ? trimmed.substring(0, _maxAttachmentChars)
            : trimmed;
        onAttach(file.name, limited);
      } catch (e) {
        // 单个文件非文本则跳过，不影响其他
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.inputBarInvalidAttachment(file.name))),
        );
      }
    }
    // 成功不弹 SnackBar：输入框上方的附件 chip 列表已是清晰反馈。
    // 通过 addPostFrameCallback 延后到下一帧请求焦点：
    // 确保原生文件对话框已完全关闭、附件 chip 已渲染，输入框能可靠拿回焦点。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGenerating = widget.isGenerating;
    final l10n = AppLocalizations.of(context);
    final hasAttachments = widget.attachedFileNames.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- 附加上下文提示（多附件，每个可单独移除）----
        if (widget.showAttachment && hasAttachments) ...[
          Container(
            color: AppTheme.gold.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.attachedFileNames.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _AttachmentChip(
                    name: widget.attachedFileNames[i],
                    onRemove: () => widget.onRemoveAttach?.call(i),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ---- 输入栏 ----
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(theme.brightness),
            border: Border(
              top: BorderSide(color: AppTheme.divider(theme.brightness)),
            ),
          ),
          child: Row(
            children: [
              // ---- 附件按钮（不抢输入框焦点）----
              if (widget.showAttachment) ...[
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppTheme.gold),
                  onPressed: isGenerating ? null : _attachFiles,
                  tooltip: l10n.inputBarAttachTooltip,
                  // 不设置 autofocus，点击后焦点回归 _focusNode
                ),
                const SizedBox(width: 4),
              ],

              // ---- 输入框 ----
              Expanded(
                // 键盘事件由 _focusNode 的 onKeyEvent 拦截（桌面端 Enter 发送 /
                // Shift+Enter 换行；移动端不受影响，保持单行回车发送）
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !isGenerating,
                  // 桌面端：多行输入（Shift+Enter 换行，Enter 发送）
                  // 移动端：保持单行（软键盘回车发送，语义不变）
                  maxLines: _isDesktop ? null : 1,
                  minLines: 1,
                  keyboardType: _isDesktop
                      ? TextInputType.multiline
                      : TextInputType.text,
                  textInputAction: _isDesktop
                      ? TextInputAction.newline
                      : TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: isGenerating
                        ? l10n.inputBarHintGenerating
                        : l10n.inputBarHintIdle,
                    hintStyle: TextStyle(
                      color: isGenerating
                          ? AppTheme.textSecondary(
                              theme.brightness,
                            ).withValues(alpha: 0.5)
                          : AppTheme.textSecondary(theme.brightness),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: _isDesktop ? null : (_) => _sendMessage(),
                ),
              ),

              // ---- 显示全文 / 发送 / 停止按钮 ----
              // 生成中：提供「⏩ 显示全文」（跳过打字机动画）与「停止」两个动作；
              // 空闲时：仅「发送」。
              if (isGenerating && widget.onReveal != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.fast_forward_outlined,
                    color: AppTheme.gold,
                  ),
                  onPressed: widget.onReveal,
                  tooltip: l10n.inputBarRevealFull,
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: isGenerating
                    ? const Icon(
                        Icons.stop_circle_outlined,
                        color: AppTheme.crimson,
                      )
                    : const Icon(Icons.send, color: AppTheme.gold),
                onPressed: isGenerating ? widget.onStop : _sendMessage,
                tooltip: isGenerating
                    ? l10n.narrativeStopGenerating
                    : l10n.inputBarSendTooltip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单个附件提示条（文件名 + 移除按钮）
class _AttachmentChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _AttachmentChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        const Icon(Icons.attach_file, size: 14, color: AppTheme.gold),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            // labelSmall 已含 11px + textSecondary 默认值
            style: theme.textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 移除按钮：外层 ConstrainedBox 保证 ≥32px 热区（满足触屏最小
        // 点击目标）；视觉仅 14px 图标 + 4px padding，热区扩大不改变外观
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          child: InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: AppTheme.crimson),
            ),
          ),
        ),
      ],
    );
  }
}
