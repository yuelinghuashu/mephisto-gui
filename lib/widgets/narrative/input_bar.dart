import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../providers/providers.dart';

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

/// 命运输入栏：输入框 + 附件按钮 + 发送按钮
///
/// 作为 [StatefulWidget] 管理 [TextEditingController] 和 [FocusNode] 的生命周期，
/// 避免每次 build 创建新实例导致的内存泄漏。
///
/// 附件功能说明：
///   - 📎 按钮打开系统文件选择器（仅限 .txt / .md 等文本格式）
///   - 附件是**会话级**附加上下文，作为「补充上下文」注入 LLM
///   - 附件按钮不抢输入框焦点，选择完成后焦点回归，回车发送不受影响
class InputBar extends ConsumerStatefulWidget {
  /// 是否正在生成 AI 回复（此时禁用输入与发送）
  final bool isGenerating;

  const InputBar({super.key, required this.isGenerating});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
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
    ref.read(narrativeProvider.notifier).sendMessage(text);
  }

  /// 选择并附加多个文本文件（限定文本格式，支持多选）
  Future<void> _attachFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(narrativeProvider.notifier);

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
        notifier.attachContext(file.name, limited);
      } catch (e) {
        // 单个文件非文本则跳过，不影响其他
        messenger.showSnackBar(
          SnackBar(content: Text('╳ ${file.name} 不是有效文本，已跳过')),
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
    // 监听当前附件列表（用于显示附加提示，支持多选）
    final attachedNames = ref.watch(
      narrativeProvider.select((s) => s.attachedFileNames),
    );
    final hasAttachments = attachedNames.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- 附加上下文提示（多附件，每个可单独移除）----
        if (hasAttachments) ...[
          Container(
            color: AppTheme.gold.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < attachedNames.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _AttachmentChip(
                    name: attachedNames[i],
                    onRemove: () => ref
                        .read(narrativeProvider.notifier)
                        .removeAttachedContext(i),
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
              // ---- 附件按钮（不抢输入框焦点） ----
              IconButton(
                icon: const Icon(Icons.attach_file, color: AppTheme.gold),
                onPressed: isGenerating ? null : _attachFiles,
                tooltip: '附加上下文（文本，可多选）',
                // 不设置 autofocus，点击后焦点回归 _focusNode
              ),
              const SizedBox(width: 4),

              // ---- 输入框 ----
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !isGenerating,
                  decoration: InputDecoration(
                    hintText: isGenerating
                        ? '梅菲斯特正在编织故事...'
                        : '写下命运的指引，契约将推动叙事...',
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

              // ---- 发送按钮 ----
              IconButton(
                icon: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.gold,
                        ),
                      )
                    : const Icon(Icons.send, color: AppTheme.gold),
                onPressed: isGenerating ? null : _sendMessage,
                tooltip: '发送',
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
