import 'package:flutter/material.dart';

/// 按段落渲染文本（支持 `\n\n` 段落分隔，段落间加垂直间距）
///
/// 用于展示 LLM 生成的多段落叙事文本，让每个自然段落之间有明显间隔。
class ParagraphText extends StatelessWidget {
  /// 文本内容
  final String content;

  /// 文本样式
  final TextStyle? style;

  /// 对齐方式
  final TextAlign textAlign;

  const ParagraphText(
    this.content, {
    super.key,
    this.style,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    // 按段落拆分（空行分隔）
    final paragraphs = content
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // 单段落：直接渲染（保留内部换行）
    if (paragraphs.length <= 1) {
      return Text(
        content,
        style: style,
        textAlign: textAlign,
      );
    }

    // 多段落：每段一个 Text，段间加间距
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(
            paragraphs[i],
            style: style,
            textAlign: textAlign,
          ),
        ],
      ],
    );
  }
}