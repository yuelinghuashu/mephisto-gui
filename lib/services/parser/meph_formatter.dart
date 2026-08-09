/// Mephisto .meph 契约格式化器
///
/// 移植自 vscode-mephisto 插件的 `src/features/formatting.ts`，
/// 提供与编辑器插件一致的格式化规范：
///   - 区块标题顶格（无缩进）
///   - 区块内容缩进 2 个空格
///   - 压缩连续空行为单个空行（区块间统一分隔；文档首尾空行丢弃）
///   - 列表项 `- 内容` 规整、键值冒号后单空格（中英文冒号）
///   - 规则行规范化：保护引号内字符串 → 修复 `]if` → 合并被空格拆开的
///     运算符（`< =` → `<=`、`- =` → `-=`）→ 二元运算符前后补空格 →
///     赋值号 `=` 前后补空格（不误伤 `==` / `>=` / `+=`）→ 空白压缩
///
/// 与 [parseMeph] 的关系：格式化走词法层（[lexMeph]），即使用户输入了
/// 会导致 parseMeph 报错的运算符空格（如 `> =`），也能正常格式化并自动修复。
/// 词法层出错（如游离内容）时返回原文本不动作，避免破坏用户正在编辑的内容。
///
/// 关键字修复逻辑与 [parseMeph] 的校验共享 [dslKeywordFixPatterns]（meph_dsl.dart），
/// 新增 DSL 关键字只需在 meph_dsl.dart 中定义一次。
library;

import 'meph_dsl.dart';
import 'meph_lexer.dart';

/// 格式化 .meph 文本；词法解析出错时返回原文本。
String formatMephText(String text) {
  final List<Block> blocks;
  try {
    blocks = lexMeph(text);
  } on MephParseError {
    // 有解析错误时不格式化，避免破坏用户正在编辑的内容
    return text;
  }

  final lines = text.split('\n');
  // 区块标题行号集合（1-based）
  final titleLines = blocks.map((b) => b.line).toSet();

  final result = <String>[];
  var consecutiveBlankLines = 0;

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final trimmed = rawLine.trim();

    // ---- 空行处理：首尾丢弃，连续空行压缩为单个 ----
    if (trimmed.isEmpty) {
      if (i == 0 || i == lines.length - 1) continue;
      consecutiveBlankLines++;
      if (consecutiveBlankLines == 1) {
        result.add(''); // 保留第一个空行（区块分隔）
      }
      continue;
    }
    consecutiveBlankLines = 0;

    final lineNo = i + 1;

    // ---- 区块标题：顶格 ----
    if (titleLines.contains(lineNo)) {
      result.add(trimmed);
      continue;
    }

    // ---- 区块内容：缩进 2 空格 + 规范化 ----
    final blockTitle = _blockTitleForLine(blocks, lineNo);
    if (blockTitle != null) {
      final normalized = blockTitle == '规则'
          ? _normalizeRuleLine(trimmed)
          : _normalizeContentLine(trimmed);
      result.add('  $normalized');
      continue;
    }

    // ---- 其他行（游离/区块外注释等）：保留原样 ----
    result.add(rawLine);
  }

  final formatted = result.join('\n');
  // 无变化时返回原文本（避免编辑器/调用方不必要刷新）
  return formatted == text ? text : formatted;
}

/// 判断指定行号（1-based）所在区块的标题名；不在任何区块内容中时返回 null。
String? _blockTitleForLine(List<Block> blocks, int lineNo) {
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (lineNo <= block.line) continue; // 标题行或此前
    // 内容至下一块标题前一行为止（最后一块延伸到文档末尾）
    final nextTitleLine = i < blocks.length - 1 ? blocks[i + 1].line : lineNo + 1;
    if (lineNo < nextTitleLine) return block.title;
  }
  return null;
}

/// 规范化普通内容行（非规则区块）。
///
/// - 列表项 `- 内容`：`-` 后固定单个空格
/// - 键值对 `key：value` / `key: value`：冒号后固定单个空格（英文冒号排除 `==` 相邻）
String _normalizeContentLine(String line) {
  // 列表项：`-` 后多余空格压缩为 1 个
  if (line.startsWith('- ')) {
    line = '- ${line.substring(2).replaceFirst(RegExp(r'^ +'), '')}';
  } else if (line.startsWith('-')) {
    // 形如 "-内容" 或 "-  内容" → 固定为 "- 内容"
    line = '- ${line.substring(1).trimLeft()}';
  }

  // 键值对：冒号后多余空格压缩为 1 个
  final cnColonIdx = line.indexOf('：');
  if (cnColonIdx > 0) {
    final after = line.substring(cnColonIdx + 1).replaceFirst(RegExp(r'^ +'), '');
    line = '${line.substring(0, cnColonIdx + 1)} $after';
  } else {
    // 英文冒号（排除 `==` 相邻）
    final enColonIdx = line.indexOf(':');
    if (enColonIdx > 0 &&
        line[enColonIdx - 1] != '=' &&
        line[enColonIdx + 1] != '=') {
      final after = line.substring(enColonIdx + 1).replaceFirst(RegExp(r'^ +'), '');
      line = '${line.substring(0, enColonIdx + 1)} $after';
    }
  }

  return line;
}

/// 规范化规则行中的空格。
///
/// - 双引号内内容保持原样（含内部空格，通过占位符保护）
/// - 双引号外的连续空白压缩为单个空格
/// - 修复 `]if` → `] if` 缺失空格
/// - 合并被空格拆开的运算符：`X < = 10` → `X <= 10`，`X - = 10` → `X -= 10`
/// - 二元运算符（`||` `&&` `->` `==` `!=` `>=` `<=` `+=` `-=` `*=` `/=` `%=`）前后补空格
/// - 赋值号 `=` 前后补空格（不误伤已处理的比较/复合赋值运算符）
String _normalizeRuleLine(String line) {
  // 1. 提取双引号字符串为占位符（保护内容）
  final strings = <String>[];
  String placeholder = line.replaceAllMapped(quotedStringPattern, (m) {
    strings.add(m[1]!);
    return '\x00${strings.length - 1}\x00';
  });

  // 2. 在占位符空间上做结构修复（不影响字符串内部）
  // 修复 `]if` → `] if`
  placeholder = placeholder.replaceFirst(RegExp(r'\]\s*if\b'), '] if');
  // 修复 `if包含` → `if 包含`
  placeholder = placeholder.replaceAllMapped(
    RegExp(r'if(?=[^\s])'),
    (_) => 'if ',
  );

  // 合并被空格拆开的运算符：`< =` → `<=`，`- =` → `-=`（删除 = 前空白，保留等号）
  placeholder = placeholder.replaceAllMapped(
    RegExp(r'([<>=!+\-*/%&|^])\s*=\s*'),
    (m) => '${m[1]}=' ,
  );

  // 合并被空格拆开的 DSL 关键词：
  //   `不 包含` → `不包含`、`包 含` → `包含`、`注 入` → `注入`、
  //   `状 态` → `状态`、`roll (` → `roll(`
  // （此时引号内容已被占位符保护，不会误伤字符串内部文字；
  //   关键词 → 正则模式统一定义在 dslKeywordFixPatterns，与 parser 共享）
  for (final entry in dslKeywordFixRegExps.entries) {
    placeholder = placeholder.replaceAllMapped(
      entry.value,
      (_) => entry.key,
    );
  }
  // 增强修复「状态 . 堕落指数」两侧空格 → `状态.堕落指数`（与 VSCode 对齐）
  // parser 校验只要求「状态」与「.」之间至少一个空格才报错（已含在 dslKeywordFixPatterns），
  // 此处用 `\s*\.\s*` 额外清理「.」与键名之间的空格（如 `状态. 堕落指数` → `状态.堕落指数`）
  placeholder = placeholder.replaceAllMapped(
    RegExp(r'状态\.\s*'),
    (m) => '状态.',
  );
  // roll 表达式内部规范化：`roll (1d100)` → `roll(1d100)`；
  // 括号内及 d 两侧空格也清除（`roll( 1d100)` / `roll(1 d100)` / `roll(1d 100)` → `roll(1d100)`）
  // 保留原骰子个数与面数（m[1]=个数、m[2]=面数），只做空格清理不改语义
  placeholder = placeholder.replaceAllMapped(
    RegExp(r'roll\s*\(\s*(\d+)\s*d\s*(\d+)\s*\)'),
    (m) => 'roll(${m[1]}d${m[2]})',
  );

  // 二元运算符前后插入空格
  const operators = [
    r'\|\|', '&&', '->', '==', '!=', '>=', '<=',
    r'\+=', '-=', r'\*=', '/=', '%=',
  ];
  for (final op in operators) {
    final opClean = op.replaceAll('\\', '');
    // 运算符前加空格（若前面不是空格或行首）
    placeholder = placeholder.replaceAllMapped(
      RegExp('([^\\s])$op'),
      (m) => '${m[1]} $opClean',
    );
    // 运算符后加空格（若后面不是空格或行尾）
    placeholder = placeholder.replaceAllMapped(
      RegExp('$op([^\\s])'),
      (m) => '$opClean ${m[1]}',
    );
  }

  // 赋值号 `=` 前后补空格（排除比较运算符及复合赋值运算符字符）
  placeholder = placeholder.replaceAllMapped(
    RegExp(r'([^=!<>\s+\-*/%&|^])\s*=\s*([^=])'),
    (m) => '${m[1]} = ${m[2]}',
  );

  // 3. 连续空白压缩为单个空格
  final collapsed = placeholder.replaceAll(RegExp(r'[\s]+'), ' ').trim();

  // 4. 恢复字符串（保留原始内部空格）
  return collapsed.replaceAllMapped(
    RegExp(r'\x00(\d+)\x00'),
    (m) => '"${strings[int.parse(m[1]!)]}"',
  );
}