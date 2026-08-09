/// Mephisto .meph DSL 语法定义
///
/// 集中定义 DSL 中的关键字、运算符等语法元素。
/// 供 [meph_parser.dart]（校验报错）和 [meph_formatter.dart]（自动修复）共用，
/// 消除多处重复的关键字正则定义 —— 新增 DSL 关键字只需在此处改一处。
library;

// ============================================================
// DSL 关键字
// ============================================================

/// DSL 关键字 → 标准写法映射。
///
/// key：标准关键字（如 `不包含`）
/// value：匹配「关键字被空格拆开」的正则模式（如 `不\s+包含`）
///
/// 用途：
///   - Parser：逐一检测 `RegExp(value).hasMatch(...)`，命中即报「关键字中间不能有空格」
///   - Formatter：逐一 `replaceAllMapped` 将拆开的写法合并为标准写法
const Map<String, String> dslKeywordFixPatterns = {
  '不包含': r'不\s+包含',
  '包含': r'包\s+含',
  '注入': r'注\s+入',
  '状态': r'状\s+态',
  // 校验 pattern：要求「状态」与「.」之间至少一个空格才报错（合法 `状态.键` 不误报）
  // formatter 额外用 `状态\s*\.\s*` 做更强修复（对齐 VSCode，见 meph_formatter.dart）
  '状态.': r'状态\s+\.',
};

/// DSL 关键字 → 预编译正则映射。
///
/// 与 [dslKeywordFixPatterns] 同构，但 value 已编译为 [RegExp] 实例。
/// Parser / Formatter 每次校验/格式化时都曾对相同模式反复 `RegExp(...)` 构造；
/// 预编译后消除重复编译开销（尤其是契约编辑器 400ms 防抖实时校验场景）。
final Map<String, RegExp> dslKeywordFixRegExps = {
  for (final entry in dslKeywordFixPatterns.entries)
    entry.key: RegExp(entry.value),
};

/// 括号内双引号内容正则（用于屏蔽引号内容，避免误报）。
///
/// 被 parser 的 `_validateKeywordSpacing` / `_validateCompoundSeparator` 与
/// formatter 的 `_normalizeRuleLine` 共用。
final RegExp quotedStringPattern = RegExp(r'"([^"]*)"');

// ============================================================
// 运算符间距校验
// ============================================================

/// 匹配「两个比较字符间含空白」的正则（如 `> =`、`= =`、`! =`）。
///
/// 合法写法 `>=` / `<=` / `==` / `!=` / `>` / `<` 均为紧连字符，不会被误报。
/// 被 parser 的 `_validateOperatorSpacing` 与 `_validateComparisonOperatorSpacing`
/// 共用，消除两处重复的 `RegExp` 构造。
final RegExp spacedComparisonPattern = RegExp(r'[<>=!]\s+[<>=!]');

/// 匹配「复合赋值符号与等号间含空白」的正则（如 `+ =`、`- =`）。
///
/// 排除 `==`（复合赋值符号后不允许直接跟 `=`，天然排除）。
/// 被 parser 的 `_validateOperatorSpacing` 与 executor 的运行时兜底共用。
final RegExp spacedCompoundOperatorPattern = RegExp(r'[+\-*/]\s+=(?!=)');
