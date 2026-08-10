/// 舞台系统提示词构建器（多角色舞台）
///
/// 与 [buildSystemPrompt]（单角色）互补：
/// 单角色提示词是「你是[角色名]」，从角色个人视角展开叙事；
/// 舞台提示词是「你是这 N 位角色的共同命运剧场」，由模型按内容自行分配戏份。
///
/// 输出设计（v2：全景叙事流）：
///   不再要求「按【角色名】分节输出」（角色一多分段机械冗长、LLM 偶发不分节
///   导致角色丢失），改为**一篇流畅的第三人称小说**：
///     - 自然在叙述/对话中提及各角色名（不用方括号标记分节）
///     - 有戏份的角色必须出现，无戏份的角色不必强行出场
///   后端通过「提及归属」将全景文本映射到被提到的角色（见 stage_mention_parser）。
///
/// 分层结构：
///   1. 格式要求：叙事约束（小说的第三人称全知视角）
///   2. 世界设定：舞台公共世界观（第一个角色卡的【世界观】）
///   3. 角色定义：每位角色的身份 + 背景 + 运行时状态 + 记忆
///   4. 附加上下文 + 契约/追加规则（各角色独立注入）
///   5. 此刻：命运指引 + 行动引导
///   6. 输出格式硬性要求（末尾收束）
///
/// 设计要点：
///   - 不依赖 Riverpod / UI，纯函数；参数化为可脱离框架直接单元测试
///   - 角色记忆/状态各自独立注入，互不混淆（每个角色只看到自己的过往）
///   - v1 的【分节要求】已移除，「无戏份角色不输出」由「自然提及」隐式表达
library;

import '../../domain/models.dart';
import '../../domain/stage_models.dart';
import '../memory/memory_manager.dart';

/// 构建舞台系统提示词（多角色）。
///
/// 参数：
///   - stage: 舞台数据（角色契约列表 + 公共世界观）
///   - roleStates: 角色名 → 当前运行时状态（规则引擎运行后；空表 = 无状态）
///   - roleMemories: 角色名 → 当前记忆列表（含规则引擎注入的新记忆）
///   - narrativeRules: 用户自定义叙事约束（非空时整体替换 [defaultStageNarrativeRules]）
///   - attachedContexts: 会话级附加上下文（如场景设定文本）
///   - maxMemories: 每个角色记忆注入条数上限（null = 不限制）；
///     与 [MemoryManager.sortByImportance] 复用裁剪逻辑（高权重必带 + 低权重降序补足）
String buildStageSystemPrompt({
  required StageLoaded stage,
  required Map<String, Map<String, StateValue>> roleStates,
  required Map<String, List<Memory>> roleMemories,
  String? narrativeRules,
  List<String> attachedContexts = const [],
  int? maxMemories,
}) {
  final buffer = StringBuffer();

  // ============================================================
  // 第一层：格式硬性要求（放在最前，强化记忆）
  // ============================================================
  final constraints = (narrativeRules != null && narrativeRules.trim().isNotEmpty)
      ? narrativeRules.trim()
      : defaultStageNarrativeRules;
  buffer.writeln('【格式要求】');
  buffer.writeln(constraints);
  buffer.writeln();

  // ============================================================
  // 第二层：世界设定（公共世界观 = 第一个角色的【世界观】）
  // ============================================================
  final worldview = stage.commonWorldview;
  if (worldview.isNotEmpty) {
    buffer.writeln('【世界设定】');
    buffer.writeln(worldview);
    buffer.writeln();
  }

  // ============================================================
  // 第三层：角色定义（每个角色独立区块）
  // ============================================================
  buffer.writeln('【角色】');
  buffer.writeln('你同时扮演以下 ${stage.characters.length} 位角色，');
  buffer.writeln('命运的输入由你按内容自行分配戏份，没有戏份的角色不输出。');
  buffer.writeln();
  for (final character in stage.characters) {
    final roleName = character.roleName;
    buffer.writeln('### $roleName');
    final contract = character.contract;

    // 身份 + 锚点风格
    buffer.writeln('你是$roleName。');
    final style = _extractStyle(contract.anchor);
    if (style != null) buffer.writeln('你的风格：$style');
    if (contract.background.isNotEmpty) {
      buffer.writeln('你的背景：${_interpolate(contract.background, roleName)}');
    }
    buffer.writeln();

    // 当前状态（运行时值）
    final state = roleStates[roleName] ?? const <String, StateValue>{};
    if (state.isNotEmpty) {
      buffer.writeln('你的当前状态：');
      for (final entry in state.entries) {
        buffer.writeln('- ${entry.key}：${entry.value.value}');
      }
      buffer.writeln();
    }

    // 回忆（自己角色的长期记忆，按重要性降序 + maxMemories 灌窗裁剪）
    final memories = roleMemories[roleName] ?? const <Memory>[];
    final effective = maxMemories == null || memories.length <= maxMemories
        ? MemoryManager.sortByImportance(memories)
        : MemoryManager.clipMemories(memories, maxMemories);
    if (effective.isNotEmpty) {
      buffer.writeln('你记得的过往：');
      for (final m in effective) {
        buffer.writeln('- ${m.content}');
      }
      buffer.writeln();
    }
    buffer.writeln();
  }

  // ============================================================
  // 附加上下文（会话级，用户导入的补充设定）
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

  // 各角色契约规则（动态追加，属于契约设定的一部分）
  for (final character in stage.characters) {
    final contract = character.contract;
    if (contract.rules.isNotEmpty) {
      buffer.writeln('【${character.roleName} 的追加规则】');
      buffer.writeln(
        '当${contract.rules.map((r) => '${r.condition}时：${_interpolate(r.action, contract.roleName)}').join('；')}',
      );
      buffer.writeln();
    }
  }

  // ============================================================
  // 第四层：此刻（命运指引 + 行动引导）
  // ============================================================
  buffer.writeln('【此刻】');
  buffer.writeln('命运指引：');
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln('请根据命运指引，决定哪些角色有戏份、如何行动和回应。');
  buffer.writeln('用第三人称文学叙事描述动作、对话、环境变化。');
  buffer.writeln();

  // ============================================================
  // 第五层：输出格式硬性要求（末尾收束）
  // ============================================================
  buffer.writeln('【输出格式】');
  buffer.writeln(
    '回复必须为一段（或多段）行文流畅的第三人称小说，直接在叙述中自然提及出场角色，'
    '严禁使用 `【角色名】` 等方括号标记分节。',
  );
  buffer.writeln(
    '若有戏份的角色不止一人，让他们在同文中互动（对话/动作/交锋），'
    '无需为每位角色单独起节。',
  );
  buffer.writeln('本次舞台包含以下角色，请在叙述中自然调用：');
  buffer.writeln(stage.characters.map((c) => c.roleName).join('、'));
  buffer.writeln('未在文中被提及的角色视为本回无戏份（不必强行安排出场）。');
  buffer.writeln();
  buffer.writeln('【要求】');
  buffer.writeln(constraints);
  buffer.writeln();

  return buffer.toString();
}

/// 默认舞台叙事约束（用户未自定义时使用）。
///
/// 多角色下采用「全景叙事流」设计：
///   - 不分节、像写小说一样把出场的角色自然写入同一篇叙述
///   - 有戏份的角色通过在文中提及其名体现；未被提及 = 本回无戏份
///   - 同文互动（对话/动作/交锋），而非逐人分段
const String defaultStageNarrativeRules = '''
【绝对格式要求】你必须以小说叙事风格输出。严禁使用括号、方括号、【】、冒号加引号等任何剧本标记。对话必须使用引号，并明确说话者（如“某某说”、“某某喊道”）。动作描写必须自然融入段落。

【全景叙事要求】回复必须是一段行文流畅的第三人称小说，直接在叙述与对话中自然提及出场角色，严禁使用 `【角色名】` 分节。有戏份的角色自然进入同一篇文段互动（对话/动作/交锋），无需按人分段。

【戏份分配要求】未在文中提及的角色视为本回无戏份，不必强行安排出场；涉及多名角色的场景，让每位到场角色都有相应的言行，避免只有主角开口。

正确示例：
浮士德站在书斋窗前，望着窗外的月光，喃喃道：“我穷尽一生所学，却仍未触及世界的本质。”

梅菲斯特从阴影中走出，笑道：“那么，与我作一场交易如何？”浮士德转过身，目光深沉：“交易？你开得出我付不起的价码吗？”
''';

/// 从锚点中提取风格描述（与单角色版的 `_extractStyle` 保持一致）。
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