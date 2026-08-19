/// 舞台单轮叙事生成服务（多角色）
///
/// 责任：输入一次命运指引 + 舞台全部角色的契约/状态/记忆/历史 + LLM 配置，
/// 依次执行「每位角色各自的规则引擎 → 组装多角色系统提示词 → 单次调用 LLM →
/// 分节解析 → 本地兜底」，返回结构化结果。
///
/// 设计要点（对齐 [NarrativeTurnService] 的哲学）：
///   - 不依赖 Riverpod / UI / 会话状态：输入输出全部参数化，可脱离框架直接单元测试
///   - 每个角色的规则引擎独立运行、状态独立更新、记忆独立注入——互不混淆
///   - [LlmClient] 纯函数式网络层，支持并发调用与取消
///
/// 与 [NarrativeTurnService] 的差异：
///   - 单角色：一次 LLM 调用 = 全量回复（不分节）
///   - 多角色：一次 LLM 调用 = 按 `【角色名】` 分节的回复，[parseStageSections] 切分
///   - 本服务**不修改**任何角色存档/记忆文件；持久化由调用方（Notifier）负责
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'engine/local_reply.dart';
import 'engine/rule_engine.dart';
import 'llm/client.dart';
import 'llm/llm_invoker.dart';
import 'llm/llm_message_builder.dart';
import 'parser/stage_section_parser.dart';
import 'prompt/stage_system_prompt.dart';
import 'storage/stage_repo.dart';

/// 舞台单轮叙事生成的结构化结果
class StageTurnResult {
  /// 各角色段落（角色名 → 该角色的叙事文本；**无戏份角色不含键**）
  final Map<String, String> replies;

  /// 各角色规则引擎运行后的新状态（供调用方写回各自角色）
  final Map<String, Map<String, StateValue>> newStates;

  /// 各角色规则引擎注入的新记忆（供调用方追加到各自角色）
  final Map<String, List<Memory>> injectedMemories;

  /// 未被任何已声明角色匹配的 LLM 输出（前言/总结/未知角色段）
  final String overflow;

  /// 骰子判定信息（非空时调用方以系统消息插入叙事流）
  final String rollInfo;

  /// 骰子判定结构化结果（供 UI 渲染「命运结算」卡片）
  final List<DiceResult> diceResults;

  /// 最近一次 LLM 错误信息（无错误时为空字符串）
  final String lastError;

  const StageTurnResult({
    required this.replies,
    required this.newStates,
    required this.injectedMemories,
    required this.overflow,
    required this.rollInfo,
    required this.diceResults,
    required this.lastError,
  });

  /// 是否存在任何有效角色回复
  bool get hasReplies => replies.isNotEmpty;
}

/// 舞台单轮叙事生成服务
///
/// [clientFactory] 允许注入自定义 LLM 客户端构造器（测试用）；
/// 为空时按 [LlmConfig] 直接创建真实客户端。
class StageTurnService {
  final LlmClient Function(LlmConfig config)? _clientFactory;

  /// 可选的共享 HTTP 客户端（由调用方注入；null 时每次请求新建）
  final http.Client? client;

  const StageTurnService({this._clientFactory, this.client});

  /// 执行一轮舞台生成。
  ///
  /// 参数：
  ///   - userInput: 本次命运指引（用户输入）
  ///   - stage: 舞台数据（全部角色 Contract）
  ///   - roleStates: 角色名 → 当前运行时状态（规则引擎在其上求新状态）
  ///   - roleMemories: 角色名 → 当前记忆列表（规则引擎注入会追加）
  ///   - historyMessages: 历史消息（含系统消息会被过滤；不含本次指引）
  ///   - attachedContexts: 会话级附加上下文
  ///   - narrativeRules: 用户自定义叙事约束（设置页）
  ///   - config: LLM 配置
  ///   - onChunk: 流式输出回调（逐 token）
  ///   - cancelSignal: 协作式取消信号
  ///   - maxHistoryMessages: 上下文窗口上限（null = 不限制）
  ///   - maxMemories: 每个角色记忆注入条数上限（null = 不限制）
  ///
  /// 返回 [StageTurnResult]。
  Future<StageTurnResult> generate({
    required String userInput,
    required StageLoaded stage,
    required Map<String, Map<String, StateValue>> roleStates,
    required Map<String, List<Memory>> roleMemories,
    required List<Message> historyMessages,
    List<String> attachedContexts = const [],
    required String narrativeRules,
    required LlmConfig config,
    required void Function(String chunk) onChunk,
    Future<void>? cancelSignal,
    int? maxHistoryMessages,
    int? maxMemories,
  }) async {
    // 0. 上下文窗口管理：保留最近 N 条历史消息（与单角色版一致）
    final effectiveHistory = maxHistoryMessages == null
        ? historyMessages
        : historyMessages.length > maxHistoryMessages
        ? historyMessages.sublist(historyMessages.length - maxHistoryMessages)
        : historyMessages;

    // 空舞台防御：无角色时无内容可生成。上游 [loadStage] 已保证舞台
    // 至少一个角色，但本服务的兜底路径（[stage.characters.first]）在
    // 空列表下会抛 RangeError——此处显式守卫使防御与上游保持一致。
    if (stage.characters.isEmpty) {
      return const StageTurnResult(
        replies: {},
        newStates: {},
        injectedMemories: {},
        overflow: '',
        rollInfo: '',
        diceResults: [],
        lastError: '',
      );
    }

    // 1. 每位角色各自运行规则引擎（状态/记忆/骰子独立隔离）
    final newStates = <String, Map<String, StateValue>>{};
    final injectedMemories = <String, List<Memory>>{};
    final allDiceResults = <DiceResult>[];
    for (final character in stage.characters) {
      final roleName = character.roleName;
      final currentState = roleStates[roleName] ?? const <String, StateValue>{};
      final ruleResult = RuleEngine(
        rules: character.contract.rules,
        roleName: roleName,
      ).run(input: userInput, state: currentState);

      newStates[roleName] = ruleResult.newState;
      injectedMemories[roleName] = ruleResult.injectedMemories
          .map((m) => Memory(content: m))
          .toList();
      allDiceResults.addAll(ruleResult.diceResults);
    }

    // 2. 组装 LLM 消息（多角色系统提示词 + 历史 + 当前输入）
    //    系统提示词使用规则引擎运行后的状态与记忆（含注入）
    final messages = _buildLlmMessages(
      userInput: userInput,
      stage: stage,
      roleStates: newStates,
      roleMemories: {
        for (final character in stage.characters)
          character.roleName: [
            ...(roleMemories[character.roleName] ?? const <Memory>[]),
            ...(injectedMemories[character.roleName] ?? const <Memory>[]),
          ],
      },
      historyMessages: effectiveHistory,
      attachedContexts: attachedContexts,
      narrativeRules: narrativeRules,
      maxMemories: maxMemories,
    );

    // 3. 单次调用 LLM（流式）；空响应或异常时回退本地多角色回复
    final invoker = LlmInvoker(clientFactory: _clientFactory, client: client);
    final (reply, lastError) = await invoker.generate(
      messages: messages,
      config: config,
      onChunk: onChunk,
      cancelSignal: cancelSignal,
      fallback: () async => _buildLocalStageReply(userInput, stage),
    );

    // 4. 解析：优先旧分节格式（`【角色名】`，每位角色各归其段）；
    //    仅当 LLM 输出不分节（v2 全景叙事小说）时，回退「提及归属」——
    //    把整篇文本映射到被提及的各角色。
    //    注意顺序不可颠倒：若先走提及归属，本地兜底/分节输出中
    //    「不同角色各一段不同文本」会被错误合并为共享全文。
    final roleNames = stage.characters.map((c) => c.roleName).toList();
    final sectionResult = parseStageSections(
      reply: reply,
      roleNames: roleNames,
    );
    // 分节成功（至少一段归位）→ 采用；否则回退全景提及归属
    final sections = sectionResult.sections.isNotEmpty
        ? sectionResult
        : parseStageMentions(reply: reply, roleNames: roleNames);

    // 注意：parseStageSections 返回的 map 可能为 const 空 map，不能原地修改，
    // 因此始终构建新 map。
    final replies = Map<String, String>.from(sections.sections);
    // 极端情况（既无提及也无分节，overflow 非空）→ 降级处理
    if (replies.isEmpty && sections.overflow.isNotEmpty) {
      // 最小长度阈值（30 字符）：过短的 overflow（如"好的"、"……"）大概率是
      // LLM 前言/停顿，触发逐角色调用不划算；直接归入首角色即可。
      const minFallbackLength = 30;
      if (sections.overflow.length > minFallbackLength) {
        // 长文本降级路径：LLM 输出既无法分节也无法按提及归属时，
        // 为每个角色分别调用一次单角色生成管线（角色上下文隔离），
        // 将 N 次结果拼接为分节格式——保证每位角色都有独立回应。
        // 仅在罕见情况下触发（LLM 输出完全无格式/无角色名），
        // 不增加正常路径的 LLM 调用成本。
        debugPrint(
          '⚠️ 舞台 LLM 输出无法分节/提及归属，降级为逐角色独立生成。'
          'overflow 长度: ${sections.overflow.length}',
        );
        final perRoleReplies = await _generatePerRoleFallback(
          userInput: userInput,
          stage: stage,
          roleStates: newStates,
          roleMemories: roleMemories,
          historyMessages: effectiveHistory,
          attachedContexts: attachedContexts,
          narrativeRules: narrativeRules,
          config: config,
          maxMemories: maxMemories,
        );
        if (perRoleReplies.isNotEmpty) {
          return StageTurnResult(
            replies: perRoleReplies,
            newStates: newStates,
            injectedMemories: injectedMemories,
            overflow: '',
            rollInfo: allDiceResults.isEmpty
                ? ''
                : allDiceResults.map((d) => d.displayString).join('\n'),
            diceResults: allDiceResults,
            lastError: lastError.isEmpty
                ? '已降级为逐角色独立生成'
                : '$lastError；已降级为逐角色独立生成',
          );
        }
      }
      // 短文本或逐角色降级也失败（如 LLM 又异常）→ 兜底归入首个角色
      replies[stage.characters.first.roleName] = sections.overflow;
    }

    return StageTurnResult(
      replies: replies,
      newStates: newStates,
      injectedMemories: injectedMemories,
      overflow: sections.overflow,
      rollInfo: allDiceResults.isEmpty
          ? ''
          : allDiceResults.map((d) => d.displayString).join('\n'),
      diceResults: allDiceResults,
      lastError: lastError,
    );
  }

  /// 降级路径：为舞台中每位角色逐次调用单角色生成管线。
  ///
  /// 当 LLM 输出完全无法分节/提及归属时（罕见），逐个角色独立调用
  /// 一次 LLM（角色上下文隔离），把结果拼接为 `【角色名】\n正文` 分节
  /// 格式，保证每一位角色都有独立回应而非全部丢失。
  ///
  /// 注意：每次调用都会消耗一次 LLM 往返，仅作为极端情况兜底。
  Future<Map<String, String>> _generatePerRoleFallback({
    required String userInput,
    required StageLoaded stage,
    required Map<String, Map<String, StateValue>> roleStates,
    required Map<String, List<Memory>> roleMemories,
    required List<Message> historyMessages,
    required List<String> attachedContexts,
    required String narrativeRules,
    required LlmConfig config,
    int? maxMemories,
  }) async {
    final invoker = LlmInvoker(clientFactory: _clientFactory, client: client);

    // 逐角色独立生成（可并发执行缩短总等待）
    final replies = await Future.wait(
      stage.characters.map((character) async {
        final roleName = character.roleName;
        final currentState =
            roleStates[roleName] ?? const <String, StateValue>{};
        // 使用单角色提示词构建（复用 NarrativeTurnService 的管线）
        final messages = _buildLlmMessages(
          userInput: userInput,
          stage: StageLoaded(info: stage.info, characters: [character]),
          roleStates: {roleName: currentState},
          roleMemories: {roleName: roleMemories[roleName] ?? const <Memory>[]},
          historyMessages: historyMessages,
          attachedContexts: attachedContexts,
          narrativeRules: narrativeRules,
          maxMemories: maxMemories,
        );
        final (reply, _) = await invoker.generate(
          messages: messages,
          config: config,
          onChunk: (_) {}, // 降级路径不流式输出（避免 UI 混乱）
          fallback: () async =>
              '【$roleName】\n${localReply(userInput, contract: character.contract)}',
        );
        return (roleName, reply.trim());
      }),
    );

    final result = <String, String>{};
    for (final (roleName, reply) in replies) {
      if (reply.isNotEmpty) {
        // 以分节格式写入，使前端按标准流程渲染
        result[roleName] = reply.startsWith('【$roleName】')
            ? reply
            : '【$roleName】\n$reply';
      }
    }
    return result;
  }

  /// 构建 LLM 消息列表（多角色系统提示词 + 历史 + 当前输入）。
  List<LlmMessage> _buildLlmMessages({
    required String userInput,
    required StageLoaded stage,
    required Map<String, Map<String, StateValue>> roleStates,
    required Map<String, List<Memory>> roleMemories,
    required List<Message> historyMessages,
    required List<String> attachedContexts,
    required String narrativeRules,
    int? maxMemories,
  }) {
    return buildLlmMessageList(
      systemPrompt: buildStageSystemPrompt(
        stage: stage,
        roleStates: roleStates,
        roleMemories: roleMemories,
        narrativeRules: narrativeRules,
        attachedContexts: attachedContexts,
        maxMemories: maxMemories,
      ),
      historyMessages: historyMessages,
      userInput: userInput,
    );
  }

  /// 构建本地多角色兜底回复：每个角色各自生成一段本地叙事。
  String _buildLocalStageReply(String userInput, StageLoaded stage) {
    final buffer = StringBuffer();
    for (final character in stage.characters) {
      buffer.writeln('【${character.roleName}】');
      buffer.writeln(localReply(userInput, contract: character.contract));
      buffer.writeln();
    }
    return buffer.toString();
  }
}
