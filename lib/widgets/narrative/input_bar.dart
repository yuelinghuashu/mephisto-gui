import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

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
/// 纯 UI 组件（不依赖任何 Provider），业务操作全部通过回调注入，
/// 使单角色叙事页与多角色舞台页可完全复用同一组件。
///
/// 附件功能说明（[showAttachment] = true 时启用）：
///   - 📎 按钮打开系统文件选择器（仅限 .txt / .md 等文本格式）
///   - 附件是**会话级**附加上下文，作为「补充上下文」注入 LLM
///   - 附件按钮不抢输入框焦点，选择完成后焦点回归，回车发送不受影响
class InputBar extends StatefulWidget {
  /// 是否正在生成 AI 回复（此时禁用输入与发送）
  final bool isGenerating;

  /// 发送消息回调（输入非空且非生成中时触发）
  final ValueChanged<String> onSend;

  /// 停止当前生成回调（生成中时点击发送按钮变为「停止」按钮）
  final VoidCallback onStop;

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
    this.showAttachment = false,
    this.attachedFileNames = const [],
    this.onAttach,
    this.onRemoveAttach,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

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
    widget.onSend(text);
    _focusNode.requestFocus();
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
          SnackBar(
            content: Text(l10n.inputBarInvalidAttachment(file.name)),
          ),
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
                    onRemove: () =>
                        widget.onRemoveAttach?.call(i),
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
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !isGenerating,
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
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              // ---- 发送 / 停止按钮 ----
              // 生成中时按钮变为「停止生成」：点击即中断 LLM 流式读取
              IconButton(
                icon: isGenerating
                    ? const Icon(Icons.stop_circle_outlined, color: AppTheme.crimson)
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
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary(theme.brightness),
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close, size: 14, color: AppTheme.crimson),
          ),
        ),
      ],
    );
  }
}