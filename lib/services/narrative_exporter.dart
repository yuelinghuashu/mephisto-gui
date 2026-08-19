/// 叙事导出纯函数工具
///
/// 将一段叙事旅程（历史消息）渲染为排版优雅的 Markdown / 纯文本阅读版，
/// 供用户导出分享或留档。剥离 `.meph` 契约语法，按「命运 → 角色 → 系统」排版。
///
/// 纯函数无 IO，独立单元可测。
library;

import '../domain/models.dart';

/// 将历史消息导出为 Markdown 文本。
///
/// 参数：
///   - [roleName]: 角色名（用于标题 & 角色消息行前缀）
///   - [branchName]: 分支名（可空；用于副标题，标识版本/支线）
///   - [history]: 历史条目（fate / assistant / system，按时间顺序）
String exportNarrativeMarkdown({
  required String roleName,
  String? branchName,
  required List<HistoryEntry> history,
}) {
  final buffer = StringBuffer();

  // 标题
  buffer.writeln('# $roleName · Chronicle');
  if (branchName != null && branchName.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('> 📜 分支：**$branchName**');
  }
  buffer.writeln();

  // 正文（按时间顺序）
  for (final entry in history) {
    final content = entry.content;
    switch (entry.role) {
      case MessageRole.fate:
        buffer.writeln('---');
        buffer.writeln();
        buffer.writeln('**命运**：$content');
        buffer.writeln();
      case MessageRole.assistant:
        buffer.writeln('**$roleName**：$content');
        buffer.writeln();
      case MessageRole.system:
        buffer.writeln('*⚙ 系统：$content*');
        buffer.writeln();
    }
  }

  // 元信息
  buffer.write('---');
  buffer.writeln();
  buffer.writeln('_由 Mephisto 叙事引擎导出 · 共 ${history.length} 条消息_');

  return buffer.toString();
}

/// 将历史消息导出为纯文本（无 Markdown 标记，适合 .txt）。
String exportNarrativePlainText({
  required String roleName,
  String? branchName,
  required List<HistoryEntry> history,
}) {
  final buffer = StringBuffer();

  buffer.writeln('$roleName · Chronicle');
  if (branchName != null && branchName.isNotEmpty) {
    buffer.writeln('分支：$branchName');
  }
  buffer.writeln();

  for (final entry in history) {
    final content = entry.content;
    switch (entry.role) {
      case MessageRole.fate:
        buffer.writeln('── 命运 ──');
        buffer.writeln(content);
        buffer.writeln();
      case MessageRole.assistant:
        buffer.writeln('$roleName：$content');
        buffer.writeln();
      case MessageRole.system:
        buffer.writeln('⚙ $content');
        buffer.writeln();
    }
  }

  buffer.writeln('──────────────────');
  buffer.writeln('由 Mephisto 叙事引擎导出 · 共 ${history.length} 条消息');

  return buffer.toString();
}
