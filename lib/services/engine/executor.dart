/// 动作执行系统：执行规则动作（注入、状态修改、复合动作）
///
/// 移植自 mephisto-cli 的 `internal/core/engine/executor.go`。
///
/// 支持的动作类型（通过前缀识别）：
///   - `注入 "..."` → 追加到记忆，无直接输出
///   - `状态.键 = 值` / `状态.键 += 值` → 更新状态，返回 📊 确认消息
///   - 普通文本 → 作为 LLM 指令返回
///   - 复合动作：多个子动作用 ` && ` 串联，依次执行
library;

import '../../domain/models.dart';
import 'values_util.dart';

/// 规则动作前缀常量。
///
/// 动作类型通过前缀识别（对应 DSL 语法）：
///   - [injectPrefix]：`注入 "..."` → 追加到记忆
///   - [statePrefix]：`状态.键 = 值` → 更新状态
///
/// 被 [executeAction]（executor.dart）与 [RuleEngine]（rule_engine.dart）
/// 共用，消除散落的魔法字符串。
abstract final class RuleAction {
  /// 注入动作前缀（`注入 "..."`）
  static const String injectPrefix = '注入 ';

  /// 状态修改动作前缀（`状态.键 ...`）
  static const String statePrefix = '状态.';
}

/// 执行规则动作。
///
/// 参数：
///   - action: 动作字符串
///   - state: 运行时状态（原地修改）
///   - memories: 记忆列表（注入动作原地追加）
///   - roleName: 角色名（用于 {角色名} 占位符替换）
///
/// 返回值：直接输出的文本（注入动作返回空字符串）。
String executeAction(
  String action, {
  required String input,
  required Map<String, StateValue> state,
  required List<String> memories,
  required String roleName,
}) {
  final a = action.trim();

  // 复合动作：用 " && " 串联多个子动作
  if (a.contains(' && ')) {
    final outputs = <String>[];
    for (final part in a.split(' && ')) {
      final r = executeAction(
        part.trim(),
        input: input,
        state: state,
        memories: memories,
        roleName: roleName,
      );
      if (r.isNotEmpty) outputs.add(r);
    }
    return outputs.join('\n');
  }

  if (a.startsWith(RuleAction.injectPrefix)) {
    var msg = unquote(a.substring(RuleAction.injectPrefix.length).trim());
    msg = msg.replaceAll('{角色名}', roleName);
    memories.add(msg);
    return '';
  }

  if (a.startsWith(RuleAction.statePrefix)) {
    return setState(a, state);
  }

  // 普通动作文本（作为 LLM 指令）
  return a;
}

/// 状态变更：`状态.键 = 值` 或 `状态.键 += 值`（支持 -=、*=、/=）。
///
/// 复合赋值的类型规则：
///   - 当前值是 [IntValue] 时，结果保持 int（向零截断，与 Go int() 一致）
///   - 当前值是 [DoubleValue] 时，结果保持 double
String setState(String action, Map<String, StateValue> state) {
  final rest = action.substring(3).trim(); // 去掉 "状态."

  // 兜底校验：`+ =`、`- =` 等「复合运算符符号与等号间有空格」的写法
  // 会导致 `+=` 无法识别、简单赋值分支把 `+` 并进键名（静默创建错误状态键）。
  // 解析阶段已拦截（parseMeph），此处防手动编辑/绕过解析的规则。
  if (RegExp(r'[+\-*/]\s+=(?!=)').hasMatch(rest)) {
    return '📊 复合运算符（如 \'+=\'、\'-=\'）中间不能有空格';
  }

  // 复合赋值运算符（优先级高于简单赋值）
  const compoundOps = ['+=', '-=', '*=', '/='];
  String? compoundOp;
  var compoundIdx = -1;
  for (final op in compoundOps) {
    final i = rest.indexOf(op);
    if (i != -1) {
      compoundOp = op;
      compoundIdx = i;
      break;
    }
  }

  String key;
  String valStr;
  if (compoundOp != null) {
    key = rest.substring(0, compoundIdx).trim();
    valStr = rest.substring(compoundIdx + compoundOp.length).trim();
  } else {
    final eq = rest.indexOf('=');
    if (eq == -1) return '格式错误';
    key = rest.substring(0, eq).trim();
    valStr = rest.substring(eq + 1).trim();
  }
  valStr = unquote(valStr);

  if (compoundOp == null) {
    // ---- 简单赋值 ----
    final val = parseStateValue(valStr);
    state[key] = val;
    return '📊 $key = ${val.value}';
  }

  // ---- 复合赋值：数值运算 ----
  final current = state[key];
  if (current == null) return '📊 状态「$key」不存在';
  final currentNum = current.asDouble;
  if (currentNum == null) return '📊 $key：当前值类型不支持算术运算';
  final valNum = parseStateValue(valStr).asDouble;
  if (valNum == null) return '📊 $key：赋值类型不支持算术运算';

  // 除数为 0 时返回提示（保持原语义：返回提示文本而非抛异常）
  if (compoundOp == '/=' && valNum == 0) {
    return '📊 除数不能为0';
  }

  // 保持类型：int 状态保持 int（向零截断）
  // 使用 Dart 3 switch 表达式统一风格；`_` 分支理论上不可达
  // （[compoundOp] 已在上方 `compoundOps` 列表中验证），仅作穷尽性兜底。
  final double result = switch (compoundOp) {
    '+=' => currentNum + valNum,
    '-=' => currentNum - valNum,
    '*=' => currentNum * valNum,
    '/=' => currentNum / valNum,
    _ => throw ArgumentError('未知的复合运算符: $compoundOp'),
  };
  state[key] = current is IntValue
      ? IntValue(result.toInt())
      : DoubleValue(result);
  return '📊 $key $compoundOp $valStr';
}
