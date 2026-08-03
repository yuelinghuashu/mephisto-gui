/// 状态值工具函数
///
/// 将针对 [StateValue] 的行为内聚为 Dart 3 extension 方法，
/// 调用点更贴近类型语义（`stateVal.asDouble` 替代 `stateValueToDouble(stateVal)`）。
///
/// 从 domain/values.dart 中拆分出的引擎相关工具函数。
/// 这些函数属于规则引擎的辅助逻辑，不应被当作纯领域模型的一部分。
library;

import '../../domain/models.dart';

/// 比较运算符（含数值与布尔比较；按优先级从长到短排列）。
///
/// 被 [evalStateCondition]（condition.dart）和骰子阈值解析（dice.dart）
/// 共用，消除两处重复定义。
const List<String> comparisonOperators = ['>=', '<=', '!=', '==', '>', '<'];

/// 解析值字符串并推断类型（移植自 CLI 的 ParseValue）。
///
///   - 被引号包裹 → 字符串（去除引号）
///   - `true` / `false` → 布尔
///   - 整数字面量 → [IntValue]
///   - 浮点字面量 → [DoubleValue]
///   - 其他 → [StringValue]
StateValue parseStateValue(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return const StringValue('');

  final unquoted = unquote(v);
  if (unquoted != v) return StringValue(unquoted);

  final lower = v.toLowerCase();
  if (lower == 'true') return const BoolValue(true);
  if (lower == 'false') return const BoolValue(false);

  final integer = int.tryParse(v);
  if (integer != null) return IntValue(integer);

  final doubleValue = double.tryParse(v);
  if (doubleValue != null) return DoubleValue(doubleValue);

  return StringValue(v);
}

/// 去除字符串两端的引号（如果存在）。
String unquote(String s) {
  if (s.length >= 2 &&
      ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'")))) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

/// [StateValue] 的数值/比较行为扩展。
///
/// 将原本散落的 [stateValueToDouble] / [stateValueEquals] /
/// [compareNumericState] 内聚为类型扩展，调用点语义更清晰。
extension StateValueExt on StateValue {
  /// 转为 double（非数值类型返回 null）。
  double? get asDouble => map<double?>(
    integer: (i) => i.toDouble(),
    double: (d) => d,
    boolean: (_) => null,
    string: (_) => null,
  );

  /// 跨类型相等比较（本值 vs 条件中的字符串值）。
  ///
  ///   - 数字状态：统一转为 double 比较
  ///   - 字符串状态：去引号后精确比较
  ///   - 布尔状态：识别 true/false（大小写不敏感）
  bool equalsString(String b) {
    final target = unquote(b);
    return map(
      integer: (v) => v == double.tryParse(target),
      double: (v) => v == double.tryParse(target),
      boolean: (v) {
        final lower = target.toLowerCase();
        if (lower == 'true') return v;
        if (lower == 'false') return !v;
        return false;
      },
      string: (v) => v == target,
    );
  }

  /// 数值比较（本值 vs 条件字符串），返回是否满足操作符。
  ///
  /// 支持操作符：>、>=、<、<=
  bool compareNumeric(String b, String op) {
    final left = asDouble;
    if (left == null) return false;
    final right = double.tryParse(unquote(b));
    if (right == null) return false;
    return switch (op) {
      '>' => left > right,
      '>=' => left >= right,
      '<' => left < right,
      '<=' => left <= right,
      _ => false,
    };
  }
}