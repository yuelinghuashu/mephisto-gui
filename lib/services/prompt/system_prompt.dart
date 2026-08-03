import '../../domain/models.dart';

/// 构建系统提示词（角色扮演叙事设定）。
///
/// Mephisto 的核心机制：
///   - 你是[角色名]（模型完全代入角色身份，以角色的视角和气质展开叙事）
///   - 用户扮演「命运」，输入的是场景描述或情节推进（命运的指引）
///   - 你根据命运的指引，以第三人称文学叙事展开场景
///
/// 分层结构（由高到低，对齐 CLI 版）：
///   1. 格式要求：叙事约束（前置定调）
///   2. 世界设定：世界观 + 开局场景
///   3. 角色定义：你是谁 + 你的背景 + 锚点
///   4. 当前状态：运行时状态值
///   5. 你记得的过往：长期记忆
///   6. 附加上下文 + 契约规则（动态注入）
///   7. 此刻：命运指引 + 行动引导
///   8. 要求：叙事约束（末尾收束）
///
/// 参数：
///   - contract: 契约数据（静态部分：角色名、锚点、世界观等）
///   - currentState: 当前运行时状态值（非契约初始状态）
///   - memories: 当前运行时记忆列表（由注入动作和记忆提取累积）
///   - narrativeRules: 用户自定义的叙事约束（来自设置页，可编辑）；
///     非空时整体替换默认约束 [defaultNarrativeRules]
///   - attachedContexts: 会话级附加上下文列表（如场景设定等文本文件内容），
///     支持多选；非空时注入【补充上下文】区块
String buildSystemPrompt({
  required Contract contract,
  required Map<String, StateValue> currentState,
  List<Memory> memories = const [],
  String? narrativeRules,
  List<String> attachedContexts = const [],
}) {
  final buffer = StringBuffer();

  // ============================================================
  // 第一层：格式硬性要求（放在最前，强化记忆）
  // ============================================================
  final constraints =
      (narrativeRules != null && narrativeRules.trim().isNotEmpty)
      ? narrativeRules.trim()
      : defaultNarrativeRules;
  buffer.writeln('【格式要求】');
  buffer.writeln(constraints);
  buffer.writeln();

  // ============================================================
  // 第二层：世界设定
  // ============================================================
  if (contract.worldview.isNotEmpty) {
    buffer.writeln('【世界设定】');
    buffer.writeln(_interpolate(contract.worldview, contract.roleName));
    buffer.writeln();
  }

  // ============================================================
  // 第三层：角色定义
  // ============================================================
  buffer.writeln('【角色】');
  buffer.writeln('你是${contract.roleName}');
  if (contract.anchor.isNotEmpty) {
    final style = _extractStyle(contract.anchor);
    if (style != null) {
      buffer.writeln('，一个$style的存在');
    }
  }
  buffer.writeln('。');
  if (contract.background.isNotEmpty) {
    buffer.writeln(
      '你的背景：${_interpolate(contract.background, contract.roleName)}',
    );
  }
  buffer.writeln();

  // ============================================================
  // 第四层：当前状态（运行时值，非契约初始值）
  // ============================================================
  buffer.writeln('【当前状态】');
  if (currentState.isEmpty) {
    buffer.writeln('（无特殊状态）');
  } else {
    for (final entry in currentState.entries) {
      buffer.writeln('- ${entry.key}：${entry.value.value}');
    }
  }
  buffer.writeln();

  // ============================================================
  // 第五层：你记得的过往（长期记忆）
  // ============================================================
  if (memories.isNotEmpty) {
    buffer.writeln('【你记得的过往】');
    for (final memory in memories) {
      buffer.writeln('- ${memory.content}');
    }
    buffer.writeln();
  }

  // ============================================================
  // 附加上下文（会话级，用户导入的补充设定，支持多选）
  // ============================================================
  if (attachedContexts.isNotEmpty) {
    buffer.writeln('【补充上下文】');
    for (final context in attachedContexts) {
      if (context.trim().isNotEmpty) {
        buffer.writeln(context.trim());
        buffer.writeln();
      }
    }
  }

  // 契约规则（来自 .meph 文件，动态追加，属于契约设定的一部分）
  if (contract.rules.isNotEmpty) {
    buffer.writeln('【追加规则】');
    buffer.writeln(
      '当${contract.rules.map((r) => '${r.condition}时：${_interpolate(r.action, contract.roleName)}').join('；')}',
    );
    buffer.writeln();
  }

  // ============================================================
  // 第七层：此刻（命运指引 + 行动引导）
  // ============================================================
  buffer.writeln('【此刻】');
  buffer.writeln('命运指引：');
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln('作为${contract.roleName}，你在这个场景中如何行动和回应？');
  buffer.writeln('用第三人称文学叙事描述你的动作、对手的反应、环境的变化。');
  buffer.writeln();

  // ============================================================
  // 第八层：要求（末尾再强调一次约束）
  // ============================================================
  buffer.writeln('【要求】');
  buffer.writeln(constraints);
  buffer.writeln();

  return buffer.toString();
}

/// 默认叙事约束（用户未自定义时使用）。
///
/// 哲学对齐 CLI 版：极简、正向引导、正反示例示范。
/// 用户可以在设置页自定义并整体替换此约束。
const String defaultNarrativeRules = '''
【绝对格式要求】你必须以小说叙事风格输出。严禁使用括号、方括号、【】、冒号加引号等任何剧本标记。对话必须使用引号，并明确说话者（如“某某说”、“某某喊道”）。动作描写必须自然融入段落。

【互动要求】每段回复必须包含至少一名其他角色（非玩家）的对话和动作反应。如果场景中没有其他角色，请引入或创造至少一个互动对象。禁止只有玩家独角戏。

正确示例：
浮士德站在书斋窗前，望着窗外的月光，喃喃道：“我穷尽一生所学，却仍未触及世界的本质。”梅菲斯特从阴影中走出，笑道：“那么，与我作一场交易如何？”浮士德转过身，目光深沉：“交易？你开得出我付不起的价码吗？”
''';

/// 从锚点中提取风格描述。
///
/// 依次查找"风格"、"说话风格"、"人格标签"、"核心信念"键，
/// 返回第一个非空的值。
String? _extractStyle(List<StateItem> anchor) {
  const styleKeys = ['风格', '说话风格', '人格标签', '核心信念'];
  for (final item in anchor) {
    if (styleKeys.contains(item.key)) {
      final value = item.value.value.toString();
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

/// 占位符插值：替换契约文本中的 `{角色名}` 为实际角色名。
String _interpolate(String text, String roleName) {
  return text.replaceAll('{角色名}', roleName);
}