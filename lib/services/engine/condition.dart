/// 条件评估系统：评估规则条件表达式
///
/// 移植自 mephisto-cli 的 `internal/core/engine/condition.go`。
///
/// 支持语法：
///   - 包含/不包含 "关键词"    → 文本匹配
///   - 状态.键 操作符 值       → 状态比较
///   - roll(1d100)            → 骰子判定
///   - 条件1 && 条件2         → 与运算（优先级高于 ||）
///   - 条件1 || 条件2         → 或运算
///
/// 性能优化：条件字符串在首次求值时编译为 [CondNode] AST 并缓存在模块级
/// [Map]，后续评估直接复用已编译结构，避免每轮对话对「规则名 if 条件」反复
/// 做字符串拆分（split || / &&）与子串判断。
library;

import '../../domain/models.dart';
import 'dice.dart';
import 'values_util.dart';

// ============================================================
// 编译缓存：同一条件字符串跨引擎实例共享编译结果
// ============================================================

/// 模块级条件编译缓存（key = 条件字符串原文）。
///
/// 设计取舍：
///   - 同一个 .meph 契约的规则在每轮对话中都会被同一组 Rule 复用，
///     缓存可显著减少重复字符串拆分（split || / &&）的 CPU 开销
///   - 采用 LRU 淘汰策略：记录每条目最近访问时间，超过 [maxConditionCacheEntries]
///     时淘汰最久未用的条目，避免长期运行/多契约切换下积累无用内存
final Map<String, CondNode?> _conditionCache = {};

/// 条件编译缓存最大条目数。
///
/// 契约规则数量级远低于此阈值；LRU 淘汰仅作为内存安全兜底，
/// 防止未来动态生成大量条件（如用户脚本）时的无界增长。
const int maxConditionCacheEntries = 200;

/// 每条目最近访问时间（LRU 辅助数据）。
final Map<String, int> _conditionCacheAccess = {};

// ============================================================
// AST 节点定义
// ============================================================

/// 编译后的条件节点（密封类，穷尽匹配安全）。
sealed class CondNode {
  const CondNode();

  /// 使用当前输入/状态/骰子存储求值。
  bool eval({
    required String input,
    required Map<String, StateValue> state,
    RollStore? rollStore,
  });
}

/// 或运算：任一子条件满足即通过。
class OrNode extends CondNode {
  final List<CondNode> children;

  const OrNode(this.children);

  @override
  bool eval({
    required String input,
    required Map<String, StateValue> state,
    RollStore? rollStore,
  }) => children.any(
    (c) => c.eval(input: input, state: state, rollStore: rollStore),
  );
}

/// 与运算：所有子条件满足才通过。
class AndNode extends CondNode {
  final List<CondNode> children;

  const AndNode(this.children);

  @override
  bool eval({
    required String input,
    required Map<String, StateValue> state,
    RollStore? rollStore,
  }) => children.every(
    (c) => c.eval(input: input, state: state, rollStore: rollStore),
  );
}

/// 文本匹配：`包含 "关键词"`
class ContainsNode extends CondNode {
  final String keyword;

  const ContainsNode(this.keyword);

  @override
  bool eval({
    required String input,
    required Map<String, StateValue> state,
    RollStore? rollStore,
  }) => input.contains(keyword);
}

/// 文本匹配：`不包含 "关键词"`
class NotContainsNode extends CondNode {
  final String keyword;

  const NotContainsNode(this.keyword);

  @override
  bool eval({
    required String input,
    required Map<String, StateValue> state,
    RollStore? rollStore,
  }) => !input.contains(keyword);
}

/// 状态比较：`状态.键 操作符 值`（eval 时即时查状态 Map）
class StateCondNode extends CondNode {
  /// 原始条件（含 `状态.` 前缀），供 [evalStateCondition] 复用
  final String cond;

  const StateCondNode(this.cond);

  @override
  bool eval({
    required String input,
    required Map<String, StateValue> state,
    RollStore? rollStore,
  }) => evalStateCondition(cond, state);
}

/// 骰子判定：`roll(1d100)` / `roll(1d100) >= 80`（eval 时即时掷骰）
class RollCondNode extends CondNode {
  /// 原始条件，供 [evalRoll] 复用
  final String cond;

  const RollCondNode(this.cond);

  @override
  bool eval({
    required String input,
    required Map<String, StateValue> state,
    RollStore? rollStore,
  }) {
    final (matched, _) = evalRoll(cond, rollStore);
    return matched;
  }
}

// ============================================================
// 编译入口
// ============================================================

/// 编译条件表达式为 AST；无法编译时返回 null。
///
/// 编译失败的原子条件在评估时视为不匹配（与旧逻辑 `return false` 一致）。
CondNode? _compileAtom(String c) {
  if (c.startsWith('包含 ')) {
    return ContainsNode(unquote(c.substring(3).trim()));
  }
  if (c.startsWith('不包含 ')) {
    return NotContainsNode(unquote(c.substring(4).trim()));
  }
  if (c.startsWith('状态.')) {
    return StateCondNode(c);
  }
  if (c.startsWith('roll(')) {
    return RollCondNode(c);
  }
  return null;
}

/// 编译条件表达式（递归处理逻辑运算符与括号分组；结果写入模块级缓存）。
///
/// 带 LRU 淘汰：访问时更新最近时间戳，缓存超限时淘汰最久未用条目，
/// 防止长期运行下无界增长。
CondNode? compileCondition(String cond) {
  final now = _clock();

  // 使用 containsKey 而非 `!= null` 判断：编译失败的条目（值为 null）
  // 也应命中缓存，避免每次评估时都重新走一遍完整编译流程。
  if (_conditionCache.containsKey(cond)) {
    // 命中：更新最近访问时间
    _conditionCacheAccess[cond] = now;
    return _conditionCache[cond];
  }

  // 未命中：编译并插入，随后按容量上限淘汰最久未用的条目
  final compiled = _compileConditionUncached(cond);
  _conditionCache[cond] = compiled;
  _conditionCacheAccess[cond] = now;
  _evictIfNeeded();
  return compiled;
}

/// LRU 时钟：单调递增计数器（避免依赖系统时间导致的时间回拨/同毫秒冲突）。
int _clock() => _clockCounter++;

int _clockCounter = 0;

/// 缓存超限时淘汰最久未使用的条目。
void _evictIfNeeded() {
  if (_conditionCache.length <= maxConditionCacheEntries) return;

  // 按最近访问时间升序排序，取最久未用的条目逐个淘汰
  final entries = _conditionCacheAccess.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final evictCount = _conditionCache.length - maxConditionCacheEntries;
  for (final entry in entries.take(evictCount)) {
    _conditionCache.remove(entry.key);
    _conditionCacheAccess.remove(entry.key);
  }
}

/// 清除条件编译缓存（含 LRU 辅助数据与时钟计数器）。
///
/// 由契约切换（[switchContract]）时调用：旧契约的条件规则不再需要，
/// 释放内存防止长期运行/多契约切换下缓存积累无用编译结果。
void clearConditionCache() {
  _conditionCache.clear();
  _conditionCacheAccess.clear();
  _clockCounter = 0;
}

/// 编译（无缓存版本，供 [compileCondition] 调用）。
CondNode? _compileConditionUncached(String cond) {
  final c = cond.trim();
  if (c.isEmpty) return null;

  // ---- 括号分组：整个条件被一对括号完整包裹时，剥掉后递归编译 ----
  // 例如 `(包含 "a" || 包含 "b")` → 编译内部 `包含 "a" || 包含 "b"`
  final unwrapped = _unwrapOuterParens(c);
  if (unwrapped != null) {
    return _compileConditionUncached(unwrapped);
  }

  // ---- 逻辑运算符（优先级：&& > ||，均只在括号外分割）----
  if (_hasTopLevelOperator(c, '||')) {
    final children = <CondNode>[];
    for (final p in _splitTopLevel(c, '||')) {
      if (p.isEmpty) continue;
      final compiled = _compileConditionUncached(p);
      if (compiled != null) children.add(compiled);
    }
    if (children.isEmpty) return null;
    return OrNode(children);
  }
  if (_hasTopLevelOperator(c, '&&')) {
    final children = <CondNode>[];
    for (final p in _splitTopLevel(c, '&&')) {
      if (p.isEmpty) continue;
      final compiled = _compileConditionUncached(p);
      if (compiled != null) children.add(compiled);
    }
    if (children.isEmpty) return null;
    return AndNode(children);
  }

  // ---- 原子条件 ----
  return _compileAtom(c);
}

/// 如果整个条件被一对括号完整包裹（如 `(a || b)`），剥掉并返回内部内容；
/// 否则返回 null。
String? _unwrapOuterParens(String c) {
  if (!c.startsWith('(')) return null;
  final end = _findMatchingParen(c, 0);
  if (end == -1 || end != c.length - 1) return null;
  final inner = c.substring(1, end).trim();
  return inner.isEmpty ? null : inner;
}

/// 查找 [start] 处左括号对应的右括号下标；找不到返回 -1。
int _findMatchingParen(String c, int start) {
  var depth = 0;
  for (var i = start; i < c.length; i++) {
    if (c[i] == '(') {
      depth++;
    } else if (c[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// 判断指定运算符是否出现在顶层（括号外）。
bool _hasTopLevelOperator(String c, String op) {
  var depth = 0;
  for (var i = 0; i < c.length; i++) {
    final ch = c[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
    } else if (depth == 0 && i + op.length <= c.length && c.startsWith(op, i)) {
      return true;
    }
  }
  return false;
}

/// 在顶层（括号外）按运算符切分条件字符串，返回切分片段（已 trim）。
List<String> _splitTopLevel(String c, String op) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < c.length; i++) {
    final ch = c[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
    } else if (depth == 0 && i + op.length <= c.length && c.startsWith(op, i)) {
      parts.add(c.substring(start, i).trim());
      i += op.length - 1;
      start = i + 1;
    }
  }
  parts.add(c.substring(start).trim());
  return parts;
}

/// 评估条件表达式。
///
/// 参数：
///   - cond: 条件字符串（如 `包含 "攻击"`）
///   - input: 当前用户输入
///   - state: 当前状态 map
///   - rollStore: 骰子结果存储（可为 null，为 null 时独立掷骰）
bool evalCondition(
  String cond, {
  required String input,
  required Map<String, StateValue> state,
  RollStore? rollStore,
}) {
  // 优先走编译缓存（首次编译后复用 AST）
  final node = compileCondition(cond);
  if (node == null) return false;
  return node.eval(input: input, state: state, rollStore: rollStore);
}

/// 评估状态条件：`状态.键 操作符 值`。
///
/// 支持操作符：>=、<=、!=、==、>、<
bool evalStateCondition(String cond, Map<String, StateValue> state) {
  final rest = cond.substring(3).trim(); // 去掉 "状态."

  // 查找操作符（优先匹配多字符；复用公共常量避免重复定义）
  String? op;
  var idx = -1;
  for (final o in comparisonOperators) {
    final i = rest.indexOf(o);
    if (i != -1) {
      op = o;
      idx = i;
      break;
    }
  }
  if (op == null) return false;

  final key = rest.substring(0, idx).trim();
  final valStr = rest.substring(idx + op.length).trim();
  final stateVal = state[key];
  if (stateVal == null) return false; // 状态不存在时返回 false

  return switch (op) {
    '==' => stateVal.equalsString(valStr),
    '!=' => !stateVal.equalsString(valStr),
    '>' || '>=' || '<' || '<=' => stateVal.compareNumeric(valStr, op),
    _ => false,
  };
}
