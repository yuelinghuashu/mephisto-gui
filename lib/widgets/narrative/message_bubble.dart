import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import 'dice_verdict_card.dart';
import 'paragraph_text.dart';

/// 单条消息气泡
///
/// 根据消息角色（命运/角色/系统）渲染不同的气泡样式：
///   - 系统消息：居中金色标签样式
///   - 命运消息（用户）：右对齐金色气泡
///   - 角色消息（AI）：左对齐卡片色气泡（支持流式输出光标）
class MessageBubble extends StatelessWidget {
  /// 消息数据
  final Message message;

  /// 是否为流式输出中的消息
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFate = message.role == MessageRole.fate;
    final isSystem = message.role == MessageRole.system;

    // ---- 系统消息：特殊样式 ----
    if (isSystem) {
      // 骰子判定结果：渲染「命运结算」卡片
      final diceResults = message.diceResults;
      if (diceResults != null && diceResults.isNotEmpty) {
        return DiceVerdictCard(results: diceResults);
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📜 ', style: theme.textTheme.labelMedium),
              Expanded(
                child: Text(
                  message.content,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary(theme.brightness),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---- 命运消息（用户）：右对齐 ----
    // 使用 Align（宽松约束）而非 Row，让文本能根据可用宽度自动 softWrap 换行
    if (isFate) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            // 宽度继承外层用户选择的叙事内容宽度档位，自动换行
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ParagraphText(
              message.content,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    // ---- 角色消息（AI）：左对齐 ----
    // 使用 Align（宽松约束）而非 Row，让文本能根据可用宽度自动 softWrap 换行
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          // 宽度继承外层用户选择的叙事内容宽度档位，自动换行
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 流式输出与完成后的文本使用相同正体样式，
              // 生成中状态由末尾金色光标标识，避免斜体影响实时阅读。
              ParagraphText(
                message.content,
                style: theme.textTheme.bodyMedium,
              ),
              if (isStreaming) _buildCursor(),
            ],
          ),
        ),
      ),
    );
  }

  /// 流式输出光标（闪烁效果）
  Widget _buildCursor() {
    return const SizedBox(
      width: 2,
      height: 16,
      child: ColoredBox(color: AppTheme.gold),
    );
  }
}
