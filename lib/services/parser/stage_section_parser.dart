/// 舞台分节解析器：将 LLM 多角色回复按 `【角色名】` 切分为各角色段。
///
/// 多角色舞台的生成管线中，LLM 单次调用的输出按角色分节（每节以 `【角色名】`
/// 开头）。本解析器负责把完整回复切分为 `角色名 → 段落文本` 的映射。
///
/// 容错设计：
///   - 已声明的角色未出现在输出中 → 映射中不存在该键（前端判定「无戏份」）
///   - 输出中出现未知角色名（LLM 幻觉/改名）→ 归入 `overflow` 额外段落
///   - 分节标题若同行带换行（如 `【浮士德】xxx`），角色名取标题行首行
///   - 标题大小写/空白容忍：trim 后匹配；全角/半角括号容错
library;

/// 分节解析结果
class StageSectionResult {
  /// 各角色段落（角色名 → 该角色的完整段落文本，已 trim）
  final Map<String, String> sections;

  /// 未被任何已声明角色标题匹配的剩余文本（LLM 额外输出/前言/总结）
  final String overflow;

  const StageSectionResult({
    required this.sections,
    required this.overflow,
  });

  /// 是否存在任何有效角色分段
  bool get isEmpty => sections.isEmpty;

  /// 指定角色是否有戏份
  bool hasRole(String roleName) => sections.containsKey(roleName);

  /// 取指定角色段落文本（无戏份返回 null）
  String? sectionOf(String roleName) => sections[roleName];
}

/// 解析 LLM 多角色回复为分节映射。
///
/// 参数：
///   - reply: LLM 完整回复文本
///   - roleNames: 已声明的角色名列表（来自舞台角色契约）
///
/// 返回 [StageSectionResult]：已声明角色段 + 溢出文本。
StageSectionResult parseStageSections({
  required String reply,
  required List<String> roleNames,
}) {
  if (reply.trim().isEmpty) {
    return const StageSectionResult(sections: {}, overflow: '');
  }

  // ---- 逐行扫描，识别分节标题行（`【角色名】`）----
  final lines = reply.split('\n');
  final sections = <String, String>{};
  final overflow = StringBuffer();

  // 当前正在收集的角色名（null = 不在任何分节内）
  String? currentRole;
  final currentLines = <String>[];

  /// 结束当前分节：把已累积行写入映射 / 溢出。
  void flush() {
    if (currentRole != null) {
      final text = currentLines.join('\n').trim();
      if (text.isNotEmpty) {
        // 已声明角色 → 分段；未知角色名 → 归入 overflow（连同标题一起）
        if (roleNames.contains(currentRole)) {
          // 同一角色出现重复分节（LLM 分段输出并不罕见）时**追加合并**
          // 而非后者覆盖前者——避免前段内容静默丢失。
          final existing = sections[currentRole!];
          sections[currentRole!] = existing == null
              ? text
              : '$existing\n\n$text';
        } else {
          overflow.writeln('【$currentRole】');
          overflow.writeln(text);
          overflow.writeln();
        }
      }
      currentLines.clear();
    } else if (currentLines.isNotEmpty) {
      // 分节前的引言/前言 → 溢出
      final text = currentLines.join('\n').trim();
      if (text.isNotEmpty) {
        overflow.writeln(text);
        overflow.writeln();
      }
      currentLines.clear();
    }
    currentRole = null;
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    // 检测分节标题：`【角色名】`（可同行带内容）
    final headerMatch = _sectionHeaderPattern.firstMatch(line);
    if (headerMatch != null) {
      flush();
      currentRole = headerMatch.group(1)!.trim();
      // 标题同行可能跟内容（如 `【浮士德】站在窗前…`）
      final rest = line.substring(headerMatch.end).trim();
      if (rest.isNotEmpty) currentLines.add(rest);
      continue;
    }

    // 普通行 → 累积到当前角色段（或溢出）
    currentLines.add(line);
  }

  // 收尾：flush 最后一个分节
  flush();

  return StageSectionResult(
    sections: sections,
    overflow: overflow.toString().trim(),
  );
}

/// 分节标题正则：`【角色名】` 或 `【 角色名 】`（容忍空白）。
///
/// 兼容性：
///   - 全角括号 `【】` 为主要格式；
///   - 半角 `[ ]` 偶发输出也做容错（`【|\[` 开头）
///   - 标题同行可跟内容（`【浮士德】正文…`），角色名取括号内内容
final RegExp _sectionHeaderPattern = RegExp(
  r'^\s*[【\[]\s*(.+?)\s*[】\]]\s*',
);

/// 判断某行是否为「角色分节标题」（纯标题行，无正文内容）。
///
/// 供 UI 流式渲染时实时检测分节边界（v2 可自定义）。
bool isSectionHeaderLine(String line) {
  final trimmed = line.trim();
  final match = _sectionHeaderPattern.firstMatch(trimmed);
  if (match == null) return false;
  // 纯标题 = 标题后无正文内容
  return trimmed.substring(match.end).trim().isEmpty;
}

/// 全景叙事「提及归属」：把一篇多角色小说文本映射到被提及的各角色。
///
/// 多角色 v2 输出不再按 `【角色名】` 分节，而是由 LLM 写一篇行文流畅的
/// 第三人称小说，直接在叙述中自然提及出场角色。本函数：
///   - 逐角色检查文本中是否出现其名字（`contains` 语义）
///   - 被提及的角色 → `sections[角色名] = 全文`（每位被提及者共享同一段文本，
///     由调用方 / reducer 识别为「全景消息」做去重渲染）
///   - 未被提及的角色 → 不映射（本回无戏份）
///   - 极端情况下无任何角色被提及 → 归入 overflow，由调用方决定兜底
///
/// 与 [parseStageSections] 的关系：
///   - [parseStageSections]：v1 分节格式（LLM 仍输出 `【角色名】` 时兼容）
///   - 本函数：v2 全景叙事流（新提示词引导下的主要格式）
StageSectionResult parseStageMentions({
  required String reply,
  required List<String> roleNames,
}) {
  final trimmed = reply.trim();
  if (trimmed.isEmpty) {
    return const StageSectionResult(sections: {}, overflow: '');
  }

  final sections = <String, String>{};
  for (final roleName in roleNames) {
    // 角色名出现在文本中 → 该角色本回有戏份，共享全文
    if (trimmed.contains(roleName)) {
      sections[roleName] = trimmed;
    }
  }

  // 有任一角色被提及 → overflow 清空：文本已全部归位给角色，
  // 无需再作为「额外叙事」由 reducer 重复追加（否则会出现相同文本两遍）。
  // 仅当无任何角色被提及时才把全文留给 overflow 兜底。
  return StageSectionResult(
    sections: sections,
    overflow: sections.isEmpty ? trimmed : '',
  );
}
