/// 骰子系统：RollStore、骰子表达式评估、叙事信息提取
///
/// 移植自 mephisto-cli 的 `internal/core/engine/dice.go`。
///
/// 只支持单骰子（`1dN`）：
///   - 1d2：二元判定（是/否、成功/失败）
///   - 1d100：高精度命运判定（1-100）
///
/// 多骰子（如 2d6）使用场景极少，已移除以保持逻辑简洁。
/// 如需重新支持多骰子，可通过 `roll(2d6)` 表达式整体扩展。
library;

import 'dart:math';

import '../../domain/config.dart';
import 'values_util.dart';

/// 骰子结果存储：确保条件判定与叙事信息使用同一骰值。
///
/// key 是 roll 表达式原文（如 `roll(1d100)`），value 是骰子点数。
class RollStore {
  final Map<String, int> _values = {};

  /// 获取或掷骰：已有结果直接返回，否则掷骰并缓存。
  int roll(String expr) {
    final cached = _values[expr];
    if (cached != null) return cached;
    final sides = parseRollDice(expr);
    // 防御：非法/不支持的面数（parseRollDice 返回 0）时跳过掷骰，
    // 避免 `Random().nextInt(0)` 抛 RangeError 拖垮整轮规则评估。
    if (sides <= 0) return 0;
    final total = Random().nextInt(sides) + 1;
    _values[expr] = total;
    return total;
  }

  /// 获取指定表达式的骰值（不掷骰），不存在时返回 null。
  int? get(String expr) => _values[expr];
}

/// 从 `roll(1d100)` 中解析骰子面数。
///
/// 只接受 `roll(1d2)` 与 `roll(1d100)`（与解析器的一致硬限制）：
///   - 1d2：二元判定（是/否、成功/失败）
///   - 1d100：高精度命运判定（1-100）
/// 其他面数或非法格式返回 0（调用方做无效判断）。
int parseRollDice(String expr) {
  var inner = expr.startsWith('roll(') ? expr.substring(5) : expr;
  if (inner.endsWith(')')) inner = inner.substring(0, inner.length - 1);
  final parts = inner.split('d');
  if (parts.length != 2) return 0;
  final count = int.tryParse(parts[0].trim());
  final sides = int.tryParse(parts[1].trim()) ?? 0;
  // 硬限制：单骰 + 仅 2（1d2 二元判定）与 100（1d100 高精度判定）合法
  return (count == 1 && (sides == 2 || sides == 100)) ? sides : 0;
}

/// 解析后的骰子表达式。
class RollExpr {
  /// 原始完整条件，如 `roll(1d100) >= 80`
  final String raw;

  /// roll(...) 核心部分，如 `roll(1d100)`
  final String rollCore;

  /// 骰子面数（如 100）
  final int sides;

  /// 用户阈值操作符（空表示使用默认阈值）
  final String op;

  /// 用户阈值（仅在 [op] 非空时有效）
  final int userThreshold;

  const RollExpr({
    required this.raw,
    required this.rollCore,
    required this.sides,
    this.op = '',
    this.userThreshold = 0,
  });

  /// 骰子最大值（即面数）
  int get maxValue => sides;

  /// 是否使用了自定义阈值
  bool get hasCustomThreshold => op.isNotEmpty;
}

/// 解析条件中的 roll 核心信息（roll 表达式 + 面数 + 自定义阈值）。
///
/// 返回 null 表示不是合法的 roll 表达式。
/// 由 [parseRollExpr] 和 [evalRoll] 共用，消除重复解析逻辑。
///
/// **合法性硬限制与 [parseRollDice] / parser 一致**：
/// 仅接受 `roll(1d2)`（二元判定）与 `roll(1d100)`（高精度判定）——
/// 骰子个数必须为 1、面数必须为 2 或 100。`roll(2d6)` 等其余写法返回 null
/// （评估视为不匹配），避免「被当作 1d6 静默掷骰」的语义漂移。
RollExpr? _parseRollCore(String c) {
  if (!c.startsWith('roll(')) return null;

  final endExpr = c.indexOf(')');
  if (endExpr == -1 || endExpr < 5) return null;

  final rollCore = c.substring(0, endExpr + 1);
  final expr = c.substring(5, endExpr).trim();
  final parts = expr.split('d');
  if (parts.length != 2) return null;
  final count = int.tryParse(parts[0].trim());
  final sides = int.tryParse(parts[1].trim());
  // 硬限制：单骰 + 仅 2 / 100 面（与 parser 的 _validRollDicePattern 一致）
  if (count != 1 || sides == null || (sides != 2 && sides != 100)) {
    return null;
  }

  // 解析自定义阈值（可选）
  final rest = c.substring(endExpr + 1).trim();
  var op = '';
  var userThreshold = 0;
  if (rest.isNotEmpty) {
    for (final o in comparisonOperators) {
      if (rest.startsWith(o)) {
        final val = int.tryParse(rest.substring(o.length).trim());
        if (val != null) {
          op = o;
          userThreshold = val;
        }
        break;
      }
    }
  }

  return RollExpr(
    raw: c,
    rollCore: rollCore,
    sides: sides,
    op: op,
    userThreshold: userThreshold,
  );
}

/// 解析条件中的 roll 表达式。
RollExpr? parseRollExpr(String cond) {
  return _parseRollCore(cond.trim());
}

/// 评估骰子表达式，返回 (是否满足条件, 实际骰值)。
///
/// 支持的格式：
///   - `roll(1d2)`            → 安科二元判定：掷出 1 = 成功（是），掷出 2 = 失败（否）
///   - `roll(1d100)`          → 结果 >= 默认阈值（50%）
///   - `roll(1d100) >= 80`    → 自定义阈值判定
///
/// 默认判定：
///   - 1d2（安科传统）：掷出 1 = 成功；掷出 2 = 失败，各 50%
///   - 1d100：阈值 = `sides / 2`，奇数时向上取整
(bool, int) evalRoll(String cond, RollStore? rs) {
  final c = cond.trim();
  final result = _parseRollCore(c);
  if (result == null) return (false, 0);

  final sides = result.sides;
  // 从 RollStore 获取或掷骰
  final total = rs != null
      ? rs.roll(result.rollCore)
      : Random().nextInt(sides) + 1;

  if (result.hasCustomThreshold) {
    return switch (result.op) {
      '>=' => (total >= result.userThreshold, total),
      '>' => (total > result.userThreshold, total),
      '<=' => (total <= result.userThreshold, total),
      '<' => (total < result.userThreshold, total),
      '==' => (total == result.userThreshold, total),
      '!=' => (total != result.userThreshold, total),
      _ => (false, total),
    };
  }

  // 默认判定：
  //   - 1d2 二元判定（安科传统）：掷出 1 = 成功（是），掷出 2 = 失败（否），各 50%
  //   - 1d100 高精度判定：50-100 算成功（50%）
  if (sides == 2) {
    return (total == 1, total);
  }
  var threshold = sides ~/ 2;
  if (sides % 2 != 0) threshold++; // 奇数时向上取整
  return (total >= threshold, total);
}

/// 从条件字符串中提取所有 roll(...) 表达式的结构化计算结果。
///
/// 返回 [DiceResult] 列表，每个元素包含：
///   - ruleName：规则名称
///   - expression：roll 表达式原文（如 `roll(1d100)`）
///   - value：实际骰值
///   - maxValue：骰子面数
///   - threshold：自定义阈值（无自定义时按默认 50% 计算）
///   - success：骰子点数是否达标
///   - triggered：整个规则条件是否匹配（动作是否实际执行）
///   - action：所属规则的执行动作（[triggered] 为 true 时用于 UI 展示「触发: xxx」）
List<DiceResult> extractDiceResults(
  String ruleName,
  String cond,
  RollStore? rs, {
  bool triggered = true,
  String action = '',
}) {
  var remaining = cond;
  final results = <DiceResult>[];

  while (true) {
    final idx = remaining.indexOf('roll(');
    if (idx == -1) break;
    final substr = remaining.substring(idx);
    final re = parseRollExpr(substr);
    if (re == null) {
      remaining = remaining.substring(idx + 5);
      continue;
    }

    // 从 RollStore 获取骰值（不重新掷骰）
    var total = rs?.get(re.rollCore) ?? 0;
    // 若 RollStore 没有缓存该表达式的值（如 || 短路导致未评估），
    // 或根本没有 RollStore，则独立掷骰确保有效（1~sides）
    if (total == 0) {
      total = Random().nextInt(re.sides) + 1;
    }

    // 用同一 RollStore 判定该 roll 表达式是否成功
    final (matched, _) = evalRoll(re.raw, rs);

    results.add(
      DiceResult(
        ruleName: ruleName,
        expression: re.rollCore,
        value: total,
        maxValue: re.maxValue,
        // 有自定义阈值时用用户阈值；否则用默认 50% 阈值
        threshold: re.hasCustomThreshold ? re.userThreshold : null,
        success: matched,
        triggered: triggered,
        action: action,
      ),
    );

    // 跳过已解析部分（含自定义阈值）：`re.raw` 已包含完整的
    // `roll(...) [op 阈值]`，整体跳过后从后续部分继续扫描。
    remaining = remaining.substring(idx + re.raw.length);
    remaining = remaining.trim();
    if (remaining.startsWith('&&')) {
      remaining = remaining.substring(2).trim();
    }
  }

  return results;
}
