/// Mephisto .meph 契约解析器
///
/// 移植自 mephisto-cli（Go）的 `internal/core/parser`，适配 Dart 类型化模型。
///
/// 处理流程（与 CLI 一致的两阶段）：
///   1. 词法分析：按 `【区块名】` 将文本切分为区块列表（见 [meph_lexer.dart]）
///   2. 结构化解析：将各区块解析为 [Contract]
///
/// 支持区块（白名单）：角色名、锚点、世界观、角色背景、开局场景、状态、规则、记忆、历史
library;

import '../../domain/models.dart';
import '../engine/values_util.dart';
import 'meph_dsl.dart';
import 'meph_lexer.dart';

export 'meph_lexer.dart' show MephParseError;

// ============================================================
// 结构化解析
// ============================================================

/// 解析 .meph 文本为 [Contract]。
///
/// 入口函数：
/// ```dart
/// final contract = parseMeph(text);
/// ```
Contract parseMeph(String text) {
  final blocks = lexMeph(text);
  return _parseBlocks(blocks);
}

/// 将区块列表解析为 [Contract]。
Contract _parseBlocks(List<Block> blocks) {
  var roleName = '';
  final anchor = <StateItem>[];
  var worldview = '';
  var background = '';
  var opening = '';
  final state = <StateItem>[];
  final rules = <Rule>[];
  final memories = <Memory>[];
  final history = <HistoryEntry>[];
  final seen = <String>{};

  for (final block in blocks) {
    // 检测重复区块
    if (!seen.add(block.title)) {
      throw MephParseError(
        line: block.line,
        blockName: block.title,
        message: '重复的区块「${block.title}」',
      );
    }

    // Dart 的 switch 非空 case 隐式 break（不会 fall-through），无需显式 break；
    // 显式 break 仅用于 `default` 空分支，与 Go/C 语义不同，此处加注释避免误读。
    switch (block.title) {
      case '角色名':
        roleName = _parseRoleName(block);
        break;
      case '锚点':
        anchor.addAll(_parseKeyValue(block));
        break;
      case '世界观':
        worldview = _parseTextBlock(block);
        break;
      case '角色背景':
        background = _parseTextBlock(block);
        break;
      case '开局场景':
        opening = _parseTextBlock(block);
        break;
      case '状态':
        state.addAll(_parseKeyValue(block));
        break;
      case '规则':
        rules.addAll(_parseRules(block));
        break;
      case '记忆':
        memories.addAll(_parsePlainList(block).map((m) => Memory(content: m)));
        break;
      case '历史':
        history.addAll(_parseHistory(block));
        break;
      default:
        // 自定义区块：静默忽略
        break;
    }
  }

  return Contract(
    roleName: roleName,
    anchor: anchor,
    worldview: worldview,
    background: background,
    opening: opening,
    state: state,
    rules: rules,
    memories: memories,
    history: history,
  );
}

/// 解析【角色名】：取第一个非空行。
String _parseRoleName(Block block) {
  for (final line in block.content) {
    final trimmed = line.text.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  throw MephParseError(
    line: block.line,
    blockName: block.title,
    message: '角色名不能为空',
  );
}

/// 解析纯文本区块（世界观/角色背景/开局场景）：按原样拼接各行。
String _parseTextBlock(Block block) {
  return block.content.map((l) => l.text).join('\n');
}

/// 解析【记忆】：`- 条目` 纯文本列表。
List<String> _parsePlainList(Block block) {
  return _scanEntries(block).map((e) => e.raw).toList();
}

/// 解析【规则】：
///
/// ```
/// [规则名] if 条件 -> 动作
/// [规则名] if 条件 -> [group:组名] 动作
/// ```
List<Rule> _parseRules(Block block) {
  final result = <Rule>[];
  for (final line in block.content) {
    final trimmed = line.text.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (trimmed.contains('#')) {
      throw MephParseError(
        line: line.number,
        blockName: block.title,
        message: "规则行中不允许包含 '#' 符号（注释必须位于行首）",
      );
    }
    result.add(_parseRuleLine(trimmed, line.number, block.title));
  }
  return result;
}

/// 规则名闭合正则：`] + 空白 + if`，定位规则名结束位置。
///
/// 兼容 `]if`、`] if`、`]  if` 等写法；条件中即使包含 `]` 也不会误匹配。
final RegExp _ruleNamePattern = RegExp(r'\]\s*if\b');

/// 屏蔽字符串中的双引号内容为 `""`（避免引号内文字被校验正则误报）。
String _maskQuotedStrings(String s) => s.replaceAll(quotedStringPattern, '""');

/// 解析单行规则。
Rule _parseRuleLine(String trimmed, int lineNumber, String blockName) {
  if (!trimmed.startsWith('[')) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "规则必须以 '[' 开头",
    );
  }

  final match = _ruleNamePattern.firstMatch(trimmed);
  if (match == null || match.start == 0) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "规则格式错误，需要 '[规则名] if 条件 -> 动作'",
    );
  }

  // 规则名
  final name = trimmed.substring(1, match.start).trim();
  if (name.isEmpty) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: '规则名不能为空',
    );
  }

  // 条件与动作：取第一个 -> 分割（动作中可能含 ->，条件中极少出现，设计取舍）
  final rest = trimmed.substring(match.end).trim();
  final arrow = rest.indexOf('->');
  if (arrow == -1) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "规则缺少 '->'",
    );
  }
  final condition = rest.substring(0, arrow).trim();
  var action = rest.substring(arrow + 2).trim();
  if (condition.isEmpty || action.isEmpty) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: '规则的条件或动作不能为空',
    );
  }

  // 互斥组（可选）：动作以 [group:组名] 开头时剥离
  // 缺少闭合的 "]" 时剥离异常，静默导致组名解析错误，必须尽早报错
  var group = '';
  if (action.contains('[group:') && !action.contains(']')) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: '互斥组应写为 [group:组名]（缺少闭合的 "]"）',
    );
  }
  if (action.startsWith('[group:')) {
    final end = action.indexOf(']');
    if (end != -1) {
      group = action.substring(7, end);
      action = action.substring(end + 1).trim();
    }
  }

  // 校验动作中的运算符空格：`状态.键 + = 值` 这类「复合运算符符号与等号间有空格」
  // 会导致 `+=` 无法识别、静默创建错误的状态键（如 `键 +`），必须尽早报错。
  _validateOperatorSpacing(action, lineNumber, blockName);

  // 校验条件中的比较运算符空格：`状态.键 > = 值`、`状态.键 = = 值`、`roll(1d100) > = 80`
  // 会导致 `>=` / `==` / `!=` 无法识别、条件静默失效（规则永不触发），必须尽早报错。
  _validateComparisonOperatorSpacing(condition, lineNumber, blockName);

  // 校验关键词空格：`不 包含 "x"`、`包 含 "x"` 会被拆开无法识别，
  // 条件静默失效（规则永不触发），必须尽早报错。
  _validateKeywordSpacing(condition, action, lineNumber, blockName);

  // 校验条件括号匹配：`( ... || ...` 缺右括号时条件静默编译失败
  _validateParenBalance(condition, lineNumber, blockName);

  // 校验复合动作分隔符：`&&` 前后缺空格时整段被当作 LLM 指令，
  // 注入/状态变更静默丢失，必须尽早报错。
  _validateCompoundSeparator(action, lineNumber, blockName);

  return Rule(
    name: name,
    condition: condition,
    action: action,
    group: group,
    line: lineNumber,
  );
}

/// 检测复合动作（含 ` && ` 串联与单个动作）中 `状态.` 动作的运算符空格。
///
/// 覆盖两类：
///   - 复合赋值 `+ =`、`- =`、`* =`、`/ =`（符号与等号间含空白，且非 `==`）
///   - 动作中的比较 `= =`、`! =`、`> =` 等（两个比较字符间含空白）
/// 合法的 `+=` / `-=` / `*=` / `/=`、`=`、`==`、`!=` 均不受影响。
void _validateOperatorSpacing(String action, int lineNumber, String blockName) {
  final parts = action.split(' && ');
  for (final part in parts) {
    final trimmed = part.trim();
    // 仅校验状态赋值动作
    if (!trimmed.startsWith('状态.')) continue;
    // 复用共享正则（定义见 meph_dsl.dart）
    if (spacedCompoundOperatorPattern.hasMatch(trimmed)) {
      throw MephParseError(
        line: lineNumber,
        blockName: blockName,
        message: "复合运算符（如 '+='、'-='）中间不能有空格",
      );
    }
    if (spacedComparisonPattern.hasMatch(trimmed)) {
      throw MephParseError(
        line: lineNumber,
        blockName: blockName,
        message: "比较运算符（如 '>='、'=='）中间不能有空格",
      );
    }
  }
}

/// 检测条件中的比较运算符空格：两个比较字符间含空白（如 `> =`、`= =`、`! =`）。
///
/// 合法的 `>=` / `<=` / `==` / `!=` / `>` / `<` 均为单个或紧连字符，被误报。
/// 引号字符串值中的 `>` / `<` 后跟普通字符也不受影响（正则要求两边都是比较字符）。
void _validateComparisonOperatorSpacing(
  String condition,
  int lineNumber,
  String blockName,
) {
  if (spacedComparisonPattern.hasMatch(condition)) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "比较运算符（如 '>='、'=='）中间不能有空格",
    );
  }
}

/// 检测 DSL 关键词被空格拆开：`不 包含 "x"`、`包 含 "x"`。
///
/// 引擎用 `startsWith('包含 ')` / `startsWith('不包含 ')` 精确匹配，
/// 关键词间出现空格会导致条件静默失效（规则永不触发）。
/// 检测前先屏蔽 `"..."` 引号内容，避免引号内文字被误报。
///
/// 关键词 → 正则模式统一定义在 [dslKeywordFixPatterns]（meph_dsl.dart），
/// 与 formatter 的修复逻辑共享，新增关键字只需改一处。
void _validateKeywordSpacing(
  String condition,
  String action,
  int lineNumber,
  String blockName,
) {
  // 屏蔽引号内容后的字符串（引号内的"不 包含"等文字不误报）
  final masked = _maskQuotedStrings('$condition $action');

  for (final entry in dslKeywordFixPatterns.entries) {
    if (RegExp(entry.value).hasMatch(masked)) {
      throw MephParseError(
        line: lineNumber,
        blockName: blockName,
        message: "关键词「${entry.key}」中间不能有空格",
      );
    }
  }

  // roll 后紧跟空白（如 `roll (1d100)`）导致 `roll(` 无法识别
  if (RegExp(r'roll\s+\(').hasMatch(masked)) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "roll 与 '(' 之间不能有空格",
    );
  }
  // roll 后缺少左括号（如 `roll 1d100`、`roll1d100`）导致 roll 表达式
  // 无法识别、条件静默失效（规则永不触发），必须尽早报错。
  // 仅检查条件部分（roll 是条件概念，动作中的普通文本 "roll" 不应误报）；
  // lookahead 限定 roll 后跟骰子特征（数字或 d），避免「状态.roll值」等
  // 含 roll 子串的普通状态键被误报为缺左括号。
  final maskedCond = _maskQuotedStrings(condition);
  if (RegExp(r'\broll(?=[\s]*\d|[\s]*d)(?!\s*\()').hasMatch(maskedCond)) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "roll 表达式缺少 '('，应写作 roll(1dN)（如 roll(1d100)）",
    );
  }
  // roll 左括号未闭合（如 `roll(1d100`、`roll(1d100 > 50`，直到条件末尾
  // 都没有 `)`）导致 roll 表达式无法识别、条件静默失效，必须尽早报错。
  if (RegExp(r'roll\([^)]*$').hasMatch(maskedCond)) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "roll 表达式缺少 ')'，应写作 roll(1dN)（如 roll(1d100)）",
    );
  }
  // roll 表达式必须为 `roll(1d2)` 或 `roll(1d100)`：
  //   - `roll( 1d100)` / `roll(1 d100)` / `roll(1d 100)`：括号内/d 两侧空格
  //   - `roll(2d100)`：多骰个数（不支持，静默按 1 骰处理是妥协）
  //   - `roll(1d6)` / `roll(1d20)`：非受支持的面数（仅 1d2 二元判定 / 1d100 高精度判定）
  //   - `roll(d100)` / `roll(1dx)` / `roll(1d)`：非法格式
  // 以上任一情况都导致引擎静默妥协或条件从不匹配，必须尽早报错。
  for (final m in RegExp(r'roll\(([^)]*)\)').allMatches(masked)) {
    final inner = m[1]!;
    if (!RegExp(r'^(1d2|1d100)$').hasMatch(inner)) {
      throw MephParseError(
        line: lineNumber,
        blockName: blockName,
        message: "骰子表达式格式无效，仅支持 roll(1d2)（二元判定）与 roll(1d100)（高精度判定）",
      );
    }
  }
}

/// 检测条件中的括号匹配（缺右括号或多余右括号都会导致条件静默失效）。
void _validateParenBalance(
  String condition,
  int lineNumber,
  String blockName,
) {
  var depth = 0;
  for (var i = 0; i < condition.length; i++) {
    final ch = condition[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth < 0) {
        throw MephParseError(
          line: lineNumber,
          blockName: blockName,
          message: '条件的括号不匹配（出现多余的 ")"）',
        );
      }
    }
  }
  if (depth != 0) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: '条件的括号不匹配（可能有未闭合的 "("）',
    );
  }
}

/// 检测复合动作分隔符：`&&` 前后必须各有一个空格（`' && '`）。
///
/// `注入 "x" &&状态+=1`（左无空格）或 `注入 "x"&& 状态+=1` 时，
/// 执行层 `split(' && ')` 失败，整段被当作 LLM 指令文本处理，
/// 注入/状态变更静默丢失，必须尽早报错。引号内文字不受影响。
void _validateCompoundSeparator(
  String action,
  int lineNumber,
  String blockName,
) {
  final masked = _maskQuotedStrings(action);
  // `&&` 前后至少一边紧贴非空白字符（即缺少标准 ` && ` 分隔）
  if (RegExp(r'&&\S').hasMatch(masked) || RegExp(r'\S&&').hasMatch(masked)) {
    throw MephParseError(
      line: lineNumber,
      blockName: blockName,
      message: "复合动作应用 ' && ' 分隔（&& 前后各一个空格）",
    );
  }
}

/// 解析【历史】：`- fate: 内容` / `- assistant: 内容`，支持 `\n` 转义还原。
List<HistoryEntry> _parseHistory(Block block) {
  final result = <HistoryEntry>[];
  for (final entry in _scanEntries(block)) {
    MessageRole role;
    String content;
    if (entry.raw.startsWith('fate:') || entry.raw.startsWith('fate：')) {
      role = MessageRole.fate;
      content = _trimOnePrefix(_trimOnePrefix(entry.raw, 'fate:'), 'fate：');
    } else if (entry.raw.startsWith('assistant:') ||
        entry.raw.startsWith('assistant：')) {
      role = MessageRole.assistant;
      content = _trimOnePrefix(
        _trimOnePrefix(entry.raw, 'assistant:'),
        'assistant：',
      );
    } else {
      throw MephParseError(
        line: entry.line,
        blockName: block.title,
        message: "历史条目必须以 'fate:' 或 'assistant:' 开头",
      );
    }
    result.add(
      HistoryEntry(role: role, content: content.trim().replaceAll('\\n', '\n')),
    );
  }
  return result;
}

/// 去除单个前缀（若存在）。
String _trimOnePrefix(String s, String prefix) =>
    s.startsWith(prefix) ? s.substring(prefix.length) : s;

/// 解析【锚点】/【状态】：`- key: value` 键值对列表。
List<StateItem> _parseKeyValue(Block block) {
  final result = <StateItem>[];
  for (final entry in _scanEntries(block)) {
    if (entry.raw.contains('#')) {
      throw MephParseError(
        line: entry.line,
        blockName: block.title,
        message: "键值对中不允许包含 '#' 符号（注释必须位于行首）",
      );
    }
    final kv = _splitKeyValue(entry.raw);
    if (kv == null) {
      throw MephParseError(
        line: entry.line,
        blockName: block.title,
        message: "键值对格式错误，缺少 ':' 或 '：'",
      );
    }
    if (kv.$1.isEmpty) {
      throw MephParseError(
        line: entry.line,
        blockName: block.title,
        message: '键值对格式错误，键不能为空',
      );
    }
    result.add(StateItem(key: kv.$1, value: parseStateValue(kv.$2)));
  }
  return result;
}

/// 解析键值对：优先按中文冒号「：」分割，其次按英文冒号「:」。
(String, String)? _splitKeyValue(String s) {
  final cn = s.indexOf('：');
  if (cn != -1) return (s.substring(0, cn).trim(), s.substring(cn + 1).trim());
  final en = s.indexOf(':');
  if (en != -1) return (s.substring(0, en).trim(), s.substring(en + 1).trim());
  return null;
}

// ============================================================
// 通用列表条目扫描
// ============================================================

/// 列表条目（去掉 `- ` 前缀后的内容 + 行号）。
class _Entry {
  final String raw;
  final int line;

  const _Entry(this.raw, this.line);
}

/// 扫描列表条目：去空行、去注释、校验 `-` 前缀。
List<_Entry> _scanEntries(Block block) {
  final entries = <_Entry>[];
  for (final line in block.content) {
    final trimmed = line.text.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!trimmed.startsWith('-')) {
      throw MephParseError(
        line: line.number,
        blockName: block.title,
        message: "列表项必须以 '-' 开头",
      );
    }
    final rest = trimmed.substring(1).trim();
    if (rest.isEmpty) {
      throw MephParseError(
        line: line.number,
        blockName: block.title,
        message: '列表项内容为空',
      );
    }
    entries.add(_Entry(rest, line.number));
  }
  return entries;
}