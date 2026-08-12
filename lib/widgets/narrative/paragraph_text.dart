import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 轻量 Markdown 段落渲染器
///
/// 支持语法（自研，保持轻量不引入外部依赖）：
///   - 标题：`# ` ~ `###### `（1~6 级，按级别放大字号）
///   - `> 引用`：引用块（行首 `> ` 前缀，支持连续引用行）
///   - `- 列表` / `* 列表`：无序列表（行首 `- `/`* ` 前缀）
///   - `**粗体**`：行内粗体
///   - `*斜体*`：行内斜体
///   - `` `行内代码` ``：行内代码
///   - `***粗斜体***`：行内粗斜体
///
/// 按 `\n\n` 段落拆分，段落间加垂直间距；段落内部的换行保留。
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
      return _renderBlock(context, content, style);
    }

    // 多段落：每段一个块，段间加间距
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _renderBlock(context, paragraphs[i], style),
        ],
      ],
    );
  }

  /// 渲染单个文本块（识别标题/引用/列表/代码块等块级语法）。
  Widget _renderBlock(BuildContext context, String text, TextStyle? baseStyle) {
    final lines = text.split('\n');
    final nonEmptyLines = lines.where((l) => l.trim().isNotEmpty).toList();
    if (nonEmptyLines.isEmpty) return const SizedBox.shrink();

    final firstLine = nonEmptyLines.first.trim();

    // ---- 标题：`# ` ~ `###### `（1~6 级） ----
    // 标题行的字体大小按级别放大，不随正文换行。
    // 三级标题（×1.3）与旧版行为完全一致，保持向后兼容。
    final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(firstLine);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      final titleText = headingMatch.group(2)!.trim();
      // 级别越大字号越小：一级 ×1.5 → 六级 ×1.2
      final scale = switch (level) {
        1 => 1.5,
        2 => 1.4,
        3 => 1.3,
        _ => 1.2,
      };
      final titleStyle = (baseStyle ?? const TextStyle()).copyWith(
        fontSize: (baseStyle?.fontSize ?? 14) * scale,
        fontWeight: FontWeight.bold,
        height: 1.3,
      );
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          titleText,
          style: titleStyle,
          textAlign: textAlign,
        ),
      );
    }

    // ---- 引用块：`> 引用`（多行连续引用合并） ----
    final quoteLines = nonEmptyLines
        .where((l) => l.startsWith('> '))
        .map((l) => l.substring(2).trim())
        .toList();
    if (quoteLines.isNotEmpty && quoteLines.length == nonEmptyLines.length) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.06),
          border: Border(
            left: BorderSide(color: AppTheme.gold.withValues(alpha: 0.4)),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: RichText(
          text: _buildInlineRichText(
            quoteLines.join('\n'),
            baseStyle?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary(
                Theme.of(context).brightness,
              ),
            ),
          ),
          textAlign: textAlign,
        ),
      );
    }

    // ---- 无序列表：`- 列表` / `* 列表` ----
    final listItems = <String>[];
    var inList = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        listItems.add(trimmed.substring(2).trim());
        inList = true;
      } else if (inList && trimmed.isEmpty) {
        break; // 列表结束
      } else if (inList) {
        // 列表中的续行（换行文本）追加到前一项
        if (listItems.isNotEmpty) {
          listItems[listItems.length - 1] =
              '${listItems.last}\n$trimmed';
        }
      }
    }
    if (listItems.isNotEmpty && listItems.length == nonEmptyLines.length) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in listItems) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppTheme.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      text: _buildInlineRichText(item, baseStyle),
                      textAlign: textAlign,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // ---- 默认：普通文本（行内样式渲染） ----
    // 无 Markdown 标记时直接渲染纯文本（保持原有 Text widget 行为，
    // 兼容 `find.text()` 测试断言与无障碍文本选择）
    if (!_hasInlineMarkup(text)) {
      return Text(
        text,
        style: baseStyle,
        textAlign: textAlign,
      );
    }
    return RichText(
      text: _buildInlineRichText(text, baseStyle),
      textAlign: textAlign,
    );
  }

  /// 检查文本是否包含任何行内 Markdown 标记。
  bool _hasInlineMarkup(String text) {
    return RegExp(r'\*\*\*.+?\*\*\*|\*\*.+?\*\*|`[^`]+`|(?<!\*)\*[^*\n]+\*(?!\*)')
        .hasMatch(text);
  }

  /// 构建行内富文本（支持 `**粗体**`、`*斜体*`、`` `代码` ``、`***粗斜体***`）。
  TextSpan _buildInlineRichText(String text, TextStyle? baseStyle) {
    final spans = <TextSpan>[];
    _parseInline(text, baseStyle ?? const TextStyle(), spans);
    return TextSpan(children: spans);
  }

  /// 递归解析行内 Markdown 标记。
  ///
  /// 支持语法（按优先级从高到低匹配）：
  ///   - `***粗斜体***` → 粗体 + 斜体
  ///   - `**粗体**` → 加粗
  ///   - `` `代码` `` → 等宽字体 + 背景色
  ///   - `*斜体*` → 斜体（单星号，需前后都有文本避免误匹配）
  void _parseInline(String text, TextStyle style, List<TextSpan> spans) {
    if (text.isEmpty) return;

    // 滚动文本，找到第一个标记
    var remaining = text;
    var buffer = StringBuffer();

    while (remaining.isNotEmpty) {
      // 查找各种标记
      final boldItalicMatch = RegExp(r'\*\*\*(.+?)\*\*\*').firstMatch(remaining);
      final boldMatch = RegExp(r'\*\*(.+?)\*\*').firstMatch(remaining);
      final codeMatch = RegExp(r'`([^`]+)`').firstMatch(remaining);
      final italicMatch = RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)').firstMatch(remaining);

      // 找到最早出现的匹配
      final matches = <(int, Match, TextSpan Function(Match, TextStyle))>[
        if (boldItalicMatch != null)
          (boldItalicMatch.start, boldItalicMatch, (m, s) => _parseInlineWithStyle(m, s, bold: true, italic: true)),
        if (boldMatch != null)
          (boldMatch.start, boldMatch, (m, s) => _parseInlineWithStyle(m, s, bold: true)),
        if (codeMatch != null)
          (codeMatch.start, codeMatch, (m, s) => _parseInlineCode(m, s, baseStyle: style)),
        if (italicMatch != null)
          (italicMatch.start, italicMatch, (m, s) => _parseInlineWithStyle(m, s, italic: true)),
      ];

      if (matches.isEmpty) {
        // 没有更多标记：剩余全部作为纯文本
        buffer.write(remaining);
        break;
      }

      // 取最早出现的匹配
      matches.sort((a, b) => a.$1.compareTo(b.$1));
      final (_, match, builder) = matches.first;

      // 匹配前的文本 → 纯文本
      if (match.start > 0) {
        buffer.write(remaining.substring(0, match.start));
      }

      // 匹配的标记 → 带样式的 span
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString(), style: style));
        buffer.clear();
      }
      spans.add(builder(match, style));

      // 继续处理剩余部分
      remaining = remaining.substring(match.end);
    }

    // 末尾剩余文本
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString(), style: style));
    }
  }

  /// 从匹配构建带样式的 span（粗体/斜体组合）。
  TextSpan _parseInlineWithStyle(
    Match match,
    TextStyle style, {
    bool bold = false,
    bool italic = false,
  }) {
    final content = match.group(1)!;
    final nestedStyle = style.copyWith(
      fontWeight: bold ? FontWeight.bold : style.fontWeight,
      fontStyle: italic ? FontStyle.italic : style.fontStyle,
    );
    // 内容中可能还有嵌套标记（如 **粗*斜***），递归解析
    final nestedSpans = <TextSpan>[];
    _parseInline(content, nestedStyle, nestedSpans);
    return TextSpan(children: nestedSpans);
  }

  /// 从匹配构建行内代码 span（等宽字体 + 背景色）。
  TextSpan _parseInlineCode(
    Match match,
    TextStyle style, {
    required TextStyle baseStyle,
  }) {
    final code = match.group(1)!;
    return TextSpan(
      text: code,
      style: style.copyWith(
        fontFamily: 'monospace',
        backgroundColor: AppTheme.gold.withValues(alpha: 0.08),
        fontSize: style.fontSize != null ? style.fontSize! - 1 : 13,
      ),
    );
  }
}