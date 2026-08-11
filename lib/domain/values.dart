/// Mephisto 叙事引擎 - 状态值类型
///
/// 定义了类型安全的联合类型 [StateValue]，用于表示运行时状态中的值。
/// 避免使用 `dynamic` 类型导致的序列化歧义。
library;

// ============================================================
// 状态值类型（sealed class）
// ============================================================

/// 状态值类型安全表示
sealed class StateValue {
  const StateValue();

  /// 状态值（子类 override 为具体类型）
  Object get value;

  /// 同一个子类 + 相同 value 视为相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType && (other as StateValue).value == value;

  @override
  int get hashCode => value.hashCode;

  /// 类型安全的模式匹配
  ///
  /// 利用 sealed class 的 exhaustiveness 在基类中完成所有分支匹配，
  /// 子类不需要也不应该重写此方法。
  T map<T>({
    required T Function(int value) integer,
    required T Function(double value) double,
    required T Function(bool value) boolean,
    required T Function(String value) string,
  }) {
    return switch (this) {
      IntValue v => integer(v.value),
      DoubleValue v => double(v.value),
      BoolValue v => boolean(v.value),
      StringValue v => string(v.value),
    };
  }
}

/// 整数状态值
class IntValue extends StateValue {
  @override
  final int value;
  const IntValue(this.value);

  @override
  String toString() => value.toString();
}

/// 浮点数状态值
class DoubleValue extends StateValue {
  @override
  final double value;
  const DoubleValue(this.value);

  @override
  String toString() => value.toString();
}

/// 布尔状态值
class BoolValue extends StateValue {
  @override
  final bool value;
  const BoolValue(this.value);

  @override
  String toString() => value.toString();
}

/// 字符串状态值
class StringValue extends StateValue {
  @override
  final String value;
  const StringValue(this.value);

  @override
  String toString() => value.toString();
}
