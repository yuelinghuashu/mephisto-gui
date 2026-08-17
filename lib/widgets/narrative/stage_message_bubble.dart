import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/stage_color_palette.dart';
import 'message_bubble.dart';
import 'paragraph_text.dart';

/// 舞台消息气泡（按角色着色）
///
/// 在多角色舞台中使用：当消息携带 [Message.roleTag] 且色板中有该角色时，
/// 渲染为「左侧角色名标签 + 左边框着色」气泡，让用户一瞥即知发言者。
///
/// 兼容性：
///   - `roleTag == null`（单角色叙事 / 命运 / 系统消息）→ 完全退化为
///     标准 [MessageBubble]，零行为改变。
///   - 色板中无该角色（理论上不发生，防御）→ 同样退化为标准气泡。
class StageMessageBubble extends StatelessWidget {
  /// 消息数据
  final Message message;

  /// 角色名 → 主题色的映射（来自 [assignRoleColors]）
  final Map<String, Color> roleColors;

  /// 是否为流式输出中的消息
  final bool isStreaming;

  const StageMessageBubble({
    super.key,
    required this.message,
    required this.roleColors,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    // 仅角色消息（assistant）且携带 roleTag 且色板可查时才应用角色着色
    final roleTag = message.roleTag;
    final roleColor = roleTag == null ? null : roleColors[roleTag];
    if (roleTag == null || roleColor == null) {
      return MessageBubble(message: message, isStreaming: isStreaming);
    }

    // ---- 命运 / 系统消息：仍用标准气泡（着色只针对角色消息） ----
    if (message.role != MessageRole.assistant) {
      return MessageBubble(message: message, isStreaming: isStreaming);
    }

    // ---- 角色消息：按角色名着色 ----
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      // MergeSemantics：竖排角色名标签与正文合并为单一读屏单元，
      // 避免读屏按「竖排标签 → 正文」割裂顺序朗读（见 B3）
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧角色名标签（竖排小圆点 + 角色名）
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: roleColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      roleTag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 角色消息气泡（左边框用角色色）
            Expanded(
              child: Container(
                // 复用标准气泡的视觉常量（padding/圆角），避免两处漂移
                padding: assistantBubblePadding,
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(assistantBubbleRadius),
                  border: Border(
                    left: BorderSide(color: roleColor, width: 3),
                  ),
                ),
                child: ParagraphText(
                  // 剥离 content 开头的 `【角色名】` 前缀：
                  // reducer 写入 history 时保留该头（存档可读），
                  // 但 UI 已有左侧竖排角色名标签，正文不再重复显示角色名。
                  stripRoleHeader(message.content),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 剥离消息内容开头的 `【角色名】` 前缀（仅当它确实以 `【` 开头时）。
///
/// 舞台 reducer 构造 assistant 消息时以 `【角色名】\n正文` 格式写入，
/// 供存档历史可读性。UI 气泡左侧已有独立角色名标签，正文若保留该头
/// 会导致角色名重复显示。此函数在渲染时剥离前缀，同时保留正文的换行。
String stripRoleHeader(String content) {
  return content.startsWith('【')
      ? content.substring(content.indexOf('】') + 1).trimLeft()
      : content;
}
