/// 规则引擎：两阶段规则匹配 + 执行
///
/// 移植自 mephisto-cli 的 `internal/core/engine`。
///
/// 两阶段设计：
///   - 被动规则（状态修改/注入记忆）：批量执行，多条同时匹配时全部执行
///   - 主动规则（LLM 指令/静态文本）：互斥匹配，只执行第一个匹配的
library;

import '../../domain/models.dart';
import 'condition.dart';
import 'dice.dart';
import 'executor.dart';

/// 规则执行结果
class RuleRunResult {
  /// 应用被动规则后的状态
  final Map<String, StateValue> newState;

  /// 注入的记忆
  final List<String> injectedMemories;

  /// 匹配的主动规则（第一个匹配；null 表示无）
  final Rule? activeRule;

  /// 骰子结构化结果（可分别取数值/阈值/状态）
  final List<DiceResult> diceResults;

  /// 各动作执行的直接输出文本（状态确认/错误提示，如 `📊 除数不能为0`）。
  ///
  /// 由 [executeAction] 返回（executor.dart 文档承诺「状态.键 = 值 → 返回
  /// 📊 确认消息」），透出供调用方决定展示策略（Notifier 可追加为系统消息
  /// 或记录日志），避免用户改动反馈被静默丢弃。
  final List<String> actionOutputs;

  const RuleRunResult({
    required this.newState,
    required this.injectedMemories,
    required this.activeRule,
    required this.diceResults,
    this.actionOutputs = const [],
  });

  /// 骰子结果描述（所有相关 roll() 结果，每行一个）
  ///
  /// 从 [diceResults] 自动生成，保持与旧 `rollInfo` 相同的文本格式。
  String get rollInfo => diceResults.isEmpty
      ? ''
      : diceResults.map((d) => d.displayString).join('\n');
}

/// 规则引擎
class RuleEngine {
  final List<Rule> rules;
  final String roleName;

  RuleEngine({required this.rules, required this.roleName});

  /// 是否为被动动作（状态修改/注入记忆）
  bool _isPassive(String action) =>
      action.startsWith(RuleAction.statePrefix) ||
      action.startsWith(RuleAction.injectPrefix);

  /// 执行一轮规则匹配与执行。
  ///
  /// 参数：
  ///   - input: 当前用户输入（命运的指引）
  ///   - state: 当前运行时状态
  ///
  /// 副作用（状态变更/记忆注入）已应用到 [RuleRunResult.newState] 和
  /// [RuleRunResult.injectedMemories]，调用方负责写回。
  RuleRunResult run({
    required String input,
    required Map<String, StateValue> state,
  }) {
    final currentState = Map<String, StateValue>.from(state);
    final memories = <String>[];
    final rollParts = <DiceResult>[];
    final actionOutputs = <String>[];

    // 阶段一：被动规则批量执行
    final passiveGroups = <String>{};
    for (final rule in rules) {
      if (!_isPassive(rule.action)) continue;
      // 被同组已命中规则锁定：本条不再求值，也不会执行
      if (rule.group.isNotEmpty && passiveGroups.contains(rule.group)) {
        continue;
      }

      final rs = RollStore();
      final matched = evalCondition(
        rule.condition,
        input: input,
        state: currentState,
        rollStore: rs,
      );
      // 无论是否匹配，只要包含 roll(...) 就提取骰子信息
      if (rule.condition.contains('roll(')) {
        rollParts.addAll(
          extractDiceResults(
            rule.name,
            rule.condition,
            rs,
            triggered: matched,
            action: rule.action,
          ),
        );
      }
      if (matched) {
        if (rule.group.isNotEmpty) passiveGroups.add(rule.group);
        final output = executeAction(
          rule.action,
          input: input,
          state: currentState,
          memories: memories,
          roleName: roleName,
        );
        // 收集动作直接输出（状态确认 / 错误提示），不再静默丢弃
        if (output.isNotEmpty) actionOutputs.add(output);
      }
    }

    // 阶段二：主动规则互斥匹配
    Rule? activeRule;
    final activeGroups = <String>{};
    final pendingRolls = <DiceResult>[];
    for (final rule in rules) {
      if (_isPassive(rule.action)) continue;

      // 互斥组检查：同一组内只触发第一个匹配的规则（仅锁定，不求值）
      if (rule.group.isNotEmpty && activeGroups.contains(rule.group)) {
        continue;
      }

      final rs = RollStore();
      final matched = evalCondition(
        rule.condition,
        input: input,
        state: currentState,
        rollStore: rs,
      );
      if (matched) {
        activeRule = rule;
        // 锁定互斥组，跳过同组后续规则
        if (rule.group.isNotEmpty) activeGroups.add(rule.group);
        pendingRolls.addAll(
          extractDiceResults(
            rule.name,
            rule.condition,
            rs,
            action: rule.action,
          ),
        );
        break; // 只执行第一个匹配的主动规则
      }
      // 未匹配也收集骰子信息（triggered: false，动作未执行）
      if (rule.condition.contains('roll(')) {
        pendingRolls.addAll(
          extractDiceResults(
            rule.name,
            rule.condition,
            rs,
            triggered: false,
            action: rule.action,
          ),
        );
      }
    }

    // 只保留规则真正匹配并执行的骰子结果（未匹配的规则不显示在结算界面）
    final allDiceResults = [
      ...rollParts,
      ...pendingRolls,
    ].where((d) => d.triggered).toList();

    return RuleRunResult(
      newState: currentState,
      injectedMemories: memories,
      activeRule: activeRule,
      diceResults: allDiceResults,
      actionOutputs: actionOutputs,
    );
  }
}
