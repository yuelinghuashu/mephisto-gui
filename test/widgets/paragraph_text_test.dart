import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/widgets/narrative/paragraph_text.dart';

import 'test_helpers.dart';

/// 自研轻量 Markdown 渲染器 [ParagraphText] 的 Widget 测试
///
/// 覆盖：
///   - 纯文本（无标记）→ 直接渲染 [Text]（无 RichText，兼容无障碍/文本选择）
///   - 行内样式：粗体 / 斜体 / 行内代码 / 粗斜体
///   - 块级样式：多级标题（`#` ~ `######`）/ 引用块 / 无序列表
///   - 多段落拆分（`\n\n` 分隔段间距）
///   - 纯文本混合行内标记 → RichText 渲染
void main() {
  Widget buildParagraph(String content, {TextStyle? style}) {
    return localizedApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ParagraphText(content, style: style),
        ),
      ),
    );
  }

  /// 从所有 RichText 的 TextSpan 树中深度收集文本+样式信息。
  ///
  /// 返回按顺序的 span 列表（含嵌套递归展开）。
  /// 注意：Flutter 的 [Text] widget 底层也使用 [RichText] 渲染，
  /// 因此即使纯文本路径（[ParagraphText] 返回 [Text]）也会产生 RichText。
  /// 此函数只收集「显式提供的 TextStyle」的 span 片段。
  List<Map<String, Object?>> collectAllSpans(WidgetTester tester) {
    final allSpans = <Map<String, Object?>>[];

    void walk(TextSpan span) {
      if (span.text != null && span.text!.isNotEmpty) {
        allSpans.add({
          'text': span.text,
          'fontWeight': span.style?.fontWeight,
          'fontStyle': span.style?.fontStyle,
          'fontFamily': span.style?.fontFamily,
          'backgroundColor': span.style?.backgroundColor,
        });
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) walk(child);
      }
    }

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    for (final rt in richTexts) {
      final span = rt.text;
      if (span is TextSpan) walk(span);
    }
    return allSpans;
  }

  /// 查找指定文本的 span（精确匹配文本内容）。
  Map<String, Object?>? findSpan(
    List<Map<String, Object?>> spans,
    String text,
  ) {
    for (final span in spans) {
      if (span['text'] == text) return span;
    }
    return null;
  }

  // ============================================================
  // 纯文本（无 Markdown 标记）
  // ============================================================

  testWidgets('纯文本无标记 → 直接渲染（文本可见）', (tester) async {
    await tester.pumpWidget(buildParagraph('浮士德站在书斋窗前。'));

    // 文本可见（Text 底层可能用 RichText，但文本不变）
    expect(find.text('浮士德站在书斋窗前。'), findsOneWidget);
    // 收集所有 span 并断言：整体作为单个无样式 span 存在
    final spans = collectAllSpans(tester);
    expect(
      findSpan(spans, '浮士德站在书斋窗前。'),
      isNotNull,
    );
    // 无任何 Markdown 样式标记：
    //   - fontWeight 不是 bold（Text 默认可能是 w400，但不会是 bold）
    //   - fontStyle 不是 italic
    //   - fontFamily 不是 monospace
    final pure = findSpan(spans, '浮士德站在书斋窗前。')!;
    expect(pure['fontWeight'], isNot(FontWeight.bold));
    expect(pure['fontStyle'], isNot(FontStyle.italic));
    expect(pure['fontFamily'], isNot('monospace'));
  });

  testWidgets('含换行的纯文本 → 保留换行渲染', (tester) async {
    await tester.pumpWidget(buildParagraph('第一行\n第二行'));

    expect(find.text('第一行\n第二行'), findsOneWidget);
  });

  // ============================================================
  // 行内标记
  // ============================================================

  testWidgets('粗体：**粗体** → 加粗 span', (tester) async {
    await tester.pumpWidget(buildParagraph('这是**重要的**内容。'));

    final spans = collectAllSpans(tester);
    // 匹配「重要的」span 且在加粗
    final boldSpan = findSpan(spans, '重要的')!;
    expect(boldSpan['fontWeight'], FontWeight.bold);
  });

  testWidgets('斜体：*斜体* → 斜体 span', (tester) async {
    await tester.pumpWidget(buildParagraph('他*低语*着。'));

    final spans = collectAllSpans(tester);
    final italicSpan = findSpan(spans, '低语')!;
    expect(italicSpan['fontStyle'], FontStyle.italic);
    // 其余文本无斜体
    final beforeSpan = findSpan(spans, '他')!;
    expect(beforeSpan['fontStyle'], isNull);
    final afterSpan = findSpan(spans, '着。')!;
    expect(afterSpan['fontStyle'], isNull);
  });

  testWidgets('行内代码：`代码` → 等宽字体 + 高亮背景', (tester) async {
    await tester.pumpWidget(buildParagraph('使用`状态.灵魂完整度`检查。'));

    final spans = collectAllSpans(tester);
    final codeSpan = findSpan(spans, '状态.灵魂完整度')!;
    expect(codeSpan['fontFamily'], 'monospace');
    expect(codeSpan['backgroundColor'], isNotNull);
  });

  testWidgets('粗斜体：***粗斜体*** → 粗体 + 斜体 span', (tester) async {
    await tester.pumpWidget(buildParagraph('结果***无法预料***。'));

    final spans = collectAllSpans(tester);
    final boldItalicSpan = findSpan(spans, '无法预料')!;
    expect(boldItalicSpan['fontWeight'], FontWeight.bold);
    expect(boldItalicSpan['fontStyle'], FontStyle.italic);
  });

  // ============================================================
  // 块级标记
  // ============================================================

  testWidgets('一级标题：# 标题 → 最大字号标题', (tester) async {
    await tester.pumpWidget(buildParagraph('# 第一幕'));

    // 标题文本存在且唯一（不含 # 前缀）
    expect(find.text('第一幕'), findsOneWidget);
    // 一级标题字号放大约 1.5 倍且加粗
    final textWidget = tester.widget<Text>(find.text('第一幕'));
    expect(textWidget.style?.fontWeight, FontWeight.bold);
    expect(textWidget.style?.fontSize, 14 * 1.5); // 默认 14 → × 1.5
  });

  testWidgets('二级标题：## 标题 → 居中字号标题', (tester) async {
    await tester.pumpWidget(buildParagraph('## 第一幕 · 书斋'));

    // 标题文本存在且唯一，## 前缀被剥离
    expect(find.text('第一幕 · 书斋'), findsOneWidget);
    // 二级标题字号放大约 1.4 倍且加粗
    final textWidget = tester.widget<Text>(find.text('第一幕 · 书斋'));
    expect(textWidget.style?.fontWeight, FontWeight.bold);
    expect(textWidget.style?.fontSize, 14 * 1.4); // 默认 14 → × 1.4
  });

  testWidgets('三级标题：### 标题 → 加粗放大标题', (tester) async {
    await tester.pumpWidget(buildParagraph('### 命运的转折'));

    // 标题文本存在且唯一
    expect(find.text('命运的转折'), findsOneWidget);
    // 标题字号放大约 1.3 倍且加粗
    final textWidget = tester.widget<Text>(find.text('命运的转折'));
    expect(textWidget.style?.fontWeight, FontWeight.bold);
    expect(textWidget.style?.fontSize, 14 * 1.3); // 默认 14 → × 1.3
  });

  testWidgets('四级标题：#### 标题 → 较小字号标题', (tester) async {
    await tester.pumpWidget(buildParagraph('#### 细节设定'));

    // 标题文本存在且唯一
    expect(find.text('细节设定'), findsOneWidget);
    // 四级及以下标题字号统一放大约 1.2 倍且加粗
    final textWidget = tester.widget<Text>(find.text('细节设定'));
    expect(textWidget.style?.fontWeight, FontWeight.bold);
    expect(textWidget.style?.fontSize, 14 * 1.2); // 默认 14 → × 1.2
  });

  testWidgets('引用块：> 引用 → 引用文本可被渲染', (tester) async {
    await tester.pumpWidget(
      buildParagraph('> 知识就像火焰——越靠近，越能感受它的灼热。'),
    );

    // 引用块使用 RichText 渲染，文本以 span 形式存在
    final spans = collectAllSpans(tester);
    expect(
      findSpan(spans, '知识就像火焰——越靠近，越能感受它的灼热。'),
      isNotNull,
    );
  });

  testWidgets('无序列表：- 项1 / - 项2 → 两个列表项渲染', (tester) async {
    await tester.pumpWidget(buildParagraph('- 第一项\n- 第二项'));

    final spans = collectAllSpans(tester);
    expect(findSpan(spans, '第一项'), isNotNull);
    expect(findSpan(spans, '第二项'), isNotNull);
  });

  // ============================================================
  // 多段落
  // ============================================================

  testWidgets('多段落：\\n\\n 分隔渲染为多个块', (tester) async {
    await tester.pumpWidget(buildParagraph('第一段\n\n第二段'));

    // 两段文本均在 span 中可找到（两部分被拆分分块）
    final spans = collectAllSpans(tester);
    expect(findSpan(spans, '第一段'), isNotNull);
    expect(findSpan(spans, '第二段'), isNotNull);
  });

  testWidgets('空内容 → 不渲染任何文本（不抛异常）', (tester) async {
    await tester.pumpWidget(buildParagraph(''));

    // 不抛异常，无文本节点（SizedBox.shrink 或空渲染）
    final spans = collectAllSpans(tester);
    expect(spans, isEmpty);
  });

  // ============================================================
  // 边界用例：嵌套标记 / 列表续行 / 连续引用 / 首尾空白
  // ============================================================

  testWidgets('嵌套标记：**粗*斜*体** → 粗体 span 内含斜体 span', (tester) async {
    await tester.pumpWidget(buildParagraph('**粗*斜*体**'));

    final spans = collectAllSpans(tester);
    // 外层粗体：粗体样式片段
    final boldSpan = spans.where((s) => s['fontWeight'] == FontWeight.bold);
    expect(boldSpan, isNotEmpty, reason: '外层应有粗体 span');
    // 内层斜体：斜体样式片段（嵌套递归解析）
    final italicSpan = spans
        .where((s) => s['fontStyle'] == FontStyle.italic)
        .toList();
    expect(italicSpan, isNotEmpty, reason: '粗体内部嵌套的 *斜* 应被解析为斜体 span');
    // 斜体内容「斜」存在于斜体 span 中
    expect(
      italicSpan.any((s) => s['text'] == '斜'),
      isTrue,
      reason: '斜体 span 文本应为「斜」',
    );
  });

  testWidgets('列表续行：- 第一行\n续行文本 → 合并为同一列表项', (tester) async {
    // 列表中的非列表行（缩进续行）追加到前一项：
    // 合并后作为单个列表项渲染（续行文本与列表项同在一个 span 中）
    await tester.pumpWidget(buildParagraph('- 第一行\n续行内容'));

    final spans = collectAllSpans(tester);
    // 续行内容应被渲染（作为合并项的一部分，不单独成项）
    expect(
      spans.any((s) => s['text'] == '第一行\n续行内容'),
      isTrue,
      reason: '续行应并入前一项文本',
    );
    // 列表项「第一行」不应作为独立 span 单独出现（已合并）
    expect(
      spans.any((s) => s['text'] == '第一行'),
      isFalse,
      reason: '合并后不再存在孤立的「第一行」span',
    );
  });

  testWidgets('连续引用行合并为同一引用块', (tester) async {
    await tester.pumpWidget(buildParagraph('> 第一行引用\n> 第二行引用'));

    // 引用行被合并为单个引用块：文本以 \n 连接成一个 span
    final spans = collectAllSpans(tester);
    expect(
      spans.any((s) => s['text'] == '第一行引用\n第二行引用'),
      isTrue,
      reason: '连续引用行应合并为同一引用块文本',
    );
  });

  testWidgets('单段落保留原始首尾空白（原样渲染）', (tester) async {
    // 单段落路径（paragraphs.length <= 1）直接渲染原始 content
    await tester.pumpWidget(buildParagraph('  两端有空格  '));

    final spans = collectAllSpans(tester);
    expect(spans, isNotEmpty);
  });

  testWidgets('多段落各自 trim：首尾空白被裁剪', (tester) async {
    await tester.pumpWidget(buildParagraph('  第一段  \n\n  第二段  '));

    final spans = collectAllSpans(tester);
    // 多段落路径对每段做 trim，段落内容仍可找到
    expect(findSpan(spans, '第一段'), isNotNull);
    expect(findSpan(spans, '第二段'), isNotNull);
  });

  testWidgets('行内标记跨行（**未闭合）→ 不崩溃并按原样渲染', (tester) async {
    await tester.pumpWidget(buildParagraph('**未闭合的粗体'));

    final spans = collectAllSpans(tester);
    expect(spans, isNotEmpty, reason: '未闭合标记不抛异常，文本仍渲染');
  });
}