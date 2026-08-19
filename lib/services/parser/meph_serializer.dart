/// Mephisto .meph 契约序列化器
///
/// 将 [Contract]（含运行时状态/记忆/历史）序列化为 .meph 文本。
/// 与 [parseMeph] 互补：parseMeph 负责 文本 → Contract，这里负责 Contract → 文本。
///
/// 主要用于生成子版存档文件（母版加上运行时变化）。
/// 序列化结果可被 parseMeph 完整解析回来，保证可逆性。
library;

import '../../domain/models.dart';

/// 序列化区块输出顺序说明：
///   - `@命运`（系统门面区块，如存在）位于文件**最顶部**——作为子版的
///     「命运门面」，打开文件第一眼即见
///   - 其后为用户叙事区块
String serializeMeph(
  Contract contract, {
  Map<String, StateValue>? runtimeState,
  List<Memory>? memories,
  List<HistoryEntry>? history,
}) {
  final buffer = StringBuffer();

  // ---- @命运 系统门面区块（若有，置于文件最顶部）----
  if (contract.branchTitle.isNotEmpty) {
    buffer.writeln('@命运');
    buffer.writeln(contract.branchTitle);
    buffer.writeln();
  }

  // ---- 角色名 ----
  buffer.writeln('【角色名】');
  buffer.writeln(contract.roleName);
  buffer.writeln();

  // ---- 锚点 ----
  if (contract.anchor.isNotEmpty) {
    buffer.writeln('【锚点】');
    for (final item in contract.anchor) {
      // 与【状态】区块统一使用 _formatStateValue：
      // 字符串值带引号输出（避免 `"10"` 被往返解析成数字、值内含 `：`/`:` 时
      // 在第一个冒号处被截断成错误键值），保证 parseMeph 可完整还原类型。
      buffer.writeln('- ${item.key}: ${_formatStateValue(item.value)}');
    }
    buffer.writeln();
  }

  // ---- 世界观 ----
  if (contract.worldview.isNotEmpty) {
    buffer.writeln('【世界观】');
    buffer.writeln(_compactBlankLines(contract.worldview));
    buffer.writeln();
  }

  // ---- 角色背景 ----
  if (contract.background.isNotEmpty) {
    buffer.writeln('【角色背景】');
    buffer.writeln(_compactBlankLines(contract.background));
    buffer.writeln();
  }

  // ---- 开局场景 ----
  if (contract.opening.isNotEmpty) {
    buffer.writeln('【开局场景】');
    buffer.writeln(_compactBlankLines(contract.opening));
    buffer.writeln();
  }

  // ---- 状态（运行时覆盖）----
  final effectiveState = runtimeState ?? contract.stateMap;
  if (effectiveState.isNotEmpty) {
    buffer.writeln('【状态】');
    for (final entry in effectiveState.entries) {
      buffer.writeln('- ${entry.key}: ${_formatStateValue(entry.value)}');
    }
    buffer.writeln();
  }

  // ---- 规则 ----
  if (contract.rules.isNotEmpty) {
    buffer.writeln('【规则】');
    for (final rule in contract.rules) {
      final groupPart = rule.group.isNotEmpty ? '[group:${rule.group}] ' : '';
      buffer.writeln(
        '[${rule.name}] if ${rule.condition} -> $groupPart${rule.action}',
      );
    }
    buffer.writeln();
  }

  // ---- 记忆 ----
  final effectiveMemories = memories ?? contract.memories;
  if (effectiveMemories.isNotEmpty) {
    buffer.writeln('【记忆】');
    for (final memory in effectiveMemories) {
      final content = memory.content.replaceAll('\n', ' ');
      // 始终输出结构化前缀 `[权重] `，包括默认权重 3：
      //   - 用户在编辑器/仪表盘中显式设置权重后，该值必须持久化显式可见
      //   - 旧格式无前缀记忆在保存时会自动补齐 `[3]`，语义完全等价
      buffer.writeln('- [${memory.importance}] $content');
    }
    buffer.writeln();
  }

  // ---- 历史 ----
  final effectiveHistory = history ?? contract.history;
  if (effectiveHistory.isNotEmpty) {
    buffer.writeln('【历史】');
    for (final entry in effectiveHistory) {
      // 三态角色前缀：fate / assistant / system。
      // system 条目（舞台「额外叙事」等）此前被错误写成 assistant:，
      // 读档后会被解析成伪造的角色对白——必须独立前缀才能完整还原。
      final role = switch (entry.role) {
        MessageRole.fate => 'fate',
        MessageRole.system => 'system',
        MessageRole.assistant => 'assistant',
      };
      buffer.writeln('- $role: ${entry.content.replaceAll('\n', r'\n')}');
    }
    buffer.writeln();
  }

  return buffer.toString();
}

/// 压缩多行文本中的连续空行（保留单个空行分隔段落）。
///
/// 原始 .meph 文件可能包含大量连续空行（用户/外部编辑器复制粘贴带格式文本时
/// 常见）；序列化快照（编辑区预填 / 子版存档）时将其规范化，避免编辑区出现
/// 大量空白行影响阅读。语义不受影响——parser 本就跳过空行。
String _compactBlankLines(String text) {
  final lines = text.split('\n');
  final result = <String>[];
  var prevBlank = false;
  for (final line in lines) {
    final isBlank = line.trim().isEmpty;
    // 连续空行只保留第一个（前一行非空时输出空行，后续空行跳过）
    if (isBlank && prevBlank) continue;
    result.add(line);
    prevBlank = isBlank;
  }
  // 去除尾部多余空行（保持区块结尾整洁）
  while (result.isNotEmpty && result.last.trim().isEmpty) {
    result.removeLast();
  }
  return result.join('\n');
}

/// 状态值格式化为 .meph 文本：
///   - 字符串带引号（避免被解析为数字/布尔）
///   - 数字/布尔直接输出
String _formatStateValue(StateValue value) {
  return value.map(
    integer: (i) => i.toString(),
    double: (d) => d.toString(),
    boolean: (b) => b.toString(),
    string: (s) => '"${s.replaceAll('"', r'\"')}"',
  );
}
