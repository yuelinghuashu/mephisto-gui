/// Mephisto .meph 契约序列化器
///
/// 将 [Contract]（含运行时状态/记忆/历史）序列化为 .meph 文本。
/// 与 [parseMeph] 互补：parseMeph 负责 文本 → Contract，这里负责 Contract → 文本。
///
/// 主要用于生成子版存档文件（母版加上运行时变化）。
/// 序列化结果可被 parseMeph 完整解析回来，保证可逆性。
library;

import '../../domain/models.dart';

/// 将契约及其运行时快照序列化为 .meph 文本。
///
/// 参数：
///   - contract: 母版契约（提供角色名/锚点/世界观/背景/开局/规则等静态区块）
///   - runtimeState: 运行时状态（覆盖合同初始状态；null 时使用合同状态）
///   - memories: 运行时记忆列表
///   - history: 运行时历史列表
///
/// 区块输出顺序（与 parseMeph 白名单一致）：
///   角色名 → 锚点 → 世界观 → 角色背景 → 开局场景 → 状态 → 规则 → 记忆 → 历史
String serializeMeph(
  Contract contract, {
  Map<String, StateValue>? runtimeState,
  List<Memory>? memories,
  List<HistoryEntry>? history,
}) {
  final buffer = StringBuffer();

  // ---- 角色名 ----
  buffer.writeln('【角色名】');
  buffer.writeln(contract.roleName);
  buffer.writeln();

  // ---- 锚点 ----
  if (contract.anchor.isNotEmpty) {
    buffer.writeln('【锚点】');
    for (final item in contract.anchor) {
      buffer.writeln('- ${item.key}: ${item.value.value}');
    }
    buffer.writeln();
  }

  // ---- 世界观 ----
  if (contract.worldview.isNotEmpty) {
    buffer.writeln('【世界观】');
    buffer.writeln(contract.worldview);
    buffer.writeln();
  }

  // ---- 角色背景 ----
  if (contract.background.isNotEmpty) {
    buffer.writeln('【角色背景】');
    buffer.writeln(contract.background);
    buffer.writeln();
  }

  // ---- 开局场景 ----
  if (contract.opening.isNotEmpty) {
    buffer.writeln('【开局场景】');
    buffer.writeln(contract.opening);
    buffer.writeln();
  }

  // ---- 状态（运行时覆盖）----
  final effectiveState = runtimeState ?? contract.stateMap;
  if (effectiveState.isNotEmpty) {
    buffer.writeln('【状态】');
    for (final entry in effectiveState.entries) {
      buffer.writeln('- ${entry.key}: ${_formatStateValue(entry.value)}');
    }
    buffer.writeln();
  }

  // ---- 规则 ----
  if (contract.rules.isNotEmpty) {
    buffer.writeln('【规则】');
    for (final rule in contract.rules) {
      final groupPart = rule.group.isNotEmpty ? '[group:${rule.group}] ' : '';
      buffer.writeln('[${rule.name}] if ${rule.condition} -> $groupPart${rule.action}');
    }
    buffer.writeln();
  }

  // ---- 记忆 ----
  final effectiveMemories = memories ?? contract.memories;
  if (effectiveMemories.isNotEmpty) {
    buffer.writeln('【记忆】');
    for (final memory in effectiveMemories) {
      buffer.writeln('- ${memory.content.replaceAll('\n', ' ')}');
    }
    buffer.writeln();
  }

  // ---- 历史 ----
  final effectiveHistory = history ?? contract.history;
  if (effectiveHistory.isNotEmpty) {
    buffer.writeln('【历史】');
    for (final entry in effectiveHistory) {
      final role = entry.role == MessageRole.fate ? 'fate' : 'assistant';
      buffer.writeln('- $role: ${entry.content.replaceAll('\n', r'\n')}');
    }
    buffer.writeln();
  }

  return buffer.toString();
}

/// 状态值格式化为 .meph 文本：
///   - 字符串带引号（避免被解析为数字/布尔）
///   - 数字/布尔直接输出
String _formatStateValue(StateValue value) {
  return value.map(
    integer: (i) => i.toString(),
    double: (d) => d.toString(),
    boolean: (b) => b.toString(),
    string: (s) => '"${s.replaceAll('"', r'\"')}"',
  );
}