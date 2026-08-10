/// 单轮叙事生成服务
///
/// 责任：输入一次命运指引 + 角色的契约/状态/记忆/历史 + LLM 配置，
/// 依次执行「规则引擎 → 组装提示词 → 调用 LLM → 兜底回复」，返回结构化结果。
///
/// 设计要点（为多角色铺路）：
///   - 不依赖 Riverpod / UI / 会话状态：输入输出全部参数化，可脱离框架直接单元测试
///   - 每个调用实例天然隔离上下文：未来多角色场景下，
///     调度器可对每个角色各自调用一次 [generate]，并通过 `Future.wait` 并发执行，
///     每个角色独享自己的契约/记忆/历史 —— 这正是「严守人设」的架构前提
///   - [LlmClient] 为纯函数式网络层、无共享可变状态，天然支持多实例并发
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'engine/local_reply.dart';
import 'engine/rule_engine.dart';
import 'llm/client.dart';
import 'prompt/system_prompt.dart';

/// 单轮叙事生成的结构化结果
class NarrativeTurnResult {
  /// 最终回复文本（LLM 空响应或异常时已回退本地回复）
  final String reply;

  /// 规则引擎运行后的新状态（供调用方写回会话）
  final Map<String, StateValue> newState;

  /// 规则引擎注入的新记忆（供调用方追加到会话记忆）
  final List<Memory> injectedMemories;

  /// 骰子判定信息（非空时调用方以系统消息插入叙事流）
  final String rollInfo;

  /// 骰子判定结构化结果（供 UI 渲染「命运结算」卡片）
  final List<DiceResult> diceResults;

  /// 最近一次 LLM 错误信息（无错误时为空字符串）
  final String lastError;

  const NarrativeTurnResult({
    required this.reply,
    required this.newState,
    required this.injectedMemories,
    required this.rollInfo,
    required this.diceResults,
    required this.lastError,
  });
}

/// 单轮叙事生成服务
///
/// [clientFactory] 允许注入自定义 LLM 客户端构造器（测试用）；
/// 为空时按 [LlmConfig] 直接创建真实客户端。
class NarrativeTurnService {
  final LlmClient Function(LlmConfig config)? _clientFactory;

  /// 可选的共享 HTTP 客户端（由调用方注入；null 时每次请求新建）
  final http.Client? client;

  const NarrativeTurnService({this._clientFactory, this.client});

  /// 执行一轮生成。
  ///
  /// 参数：
  ///   - userInput: 本次命运指引（用户输入）
  ///   - contract: 角色契约（含 roleName / rules / anchor / worldview 等）
  ///   - currentState: 当前运行时状态（规则引擎会在其上求新状态）
  ///   - memories: 当前记忆列表（规则引擎注入会追加）
  ///   - priorMessages: 历史消息（不含本次指引；系统消息会被过滤不发送给 LLM）
  ///   - attachedContexts: 会话级附加上下文
  ///   - narrativeRules: 用户自定义叙事约束（设置页）
  ///   - config: LLM 配置
  ///   - onChunk: 流式输出回调（逐 token）
  ///   - cancelSignal: 协作式取消信号；该 Future 完成后停止 LLM 流式读取
  ///   - maxHistoryMessages: 上下文窗口上限（保留最近 N 条历史消息；
  ///     null 表示不限制 = 全部发送）
  ///   - maxMemories: 记忆注入条数上限（null = 不限制，全部注入）；
  ///     超过上限时高权重记忆全部保留 + 其余按权重降序补足上限，
  ///     放不下的记忆仍在存档中，仅本轮不带（不崩人设）
  Future<NarrativeTurnResult> generate({
    required String userInput,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<Message> priorMessages,
    required List<String> attachedContexts,
    required String narrativeRules,
    required LlmConfig config,
    required void Function(String chunk) onChunk,
    Future<void>? cancelSignal,
    int? maxHistoryMessages,
    int? maxMemories,
  }) async {
    // 0. 上下文窗口管理：保留最近 N 条历史消息（防止超长对话无限膨胀 token）
    //    系统消息会被 _buildLlmMessages 过滤，为节省内存也在截断时一并丢弃。
    final effectivePrior = maxHistoryMessages == null
        ? priorMessages
        : priorMessages.length > maxHistoryMessages
        ? priorMessages.sublist(priorMessages.length - maxHistoryMessages)
        : priorMessages;
    // 1. 规则引擎（主动/被动规则、骰子判定、状态变更、记忆注入）
    final ruleResult = RuleEngine(
      rules: contract.rules,
      roleName: contract.roleName,
    ).run(input: userInput, state: currentState);

    // 2. 组装 LLM 输入（用户输入 + 规则指令 + 骰子结果）
    final llmInput = _buildInstruction(userInput, ruleResult);

    // 3. 组装 LLM 消息（系统提示词 + 历史 + 当前输入）
    //    注意 system prompt 使用规则引擎运行后的状态与记忆（含注入）
    final injectedMemories = ruleResult.injectedMemories
        .map((m) => Memory(content: m))
        .toList();
    final messages = _buildLlmMessages(
      llmInput: llmInput,
      contract: contract,
      currentState: ruleResult.newState,
      memories: [...memories, ...injectedMemories],
      priorMessages: effectivePrior,
      attachedContexts: attachedContexts,
      narrativeRules: narrativeRules,
      maxMemories: maxMemories,
    );

    // 4. 调用 LLM（流式）；空响应或异常时回退本地回复
    final llmClient =
        _clientFactory?.call(config) ??
        LlmClient(
          apiKey: config.apiKey,
          baseUrl: config.baseUrl,
          model: config.model,
          maxTokens: config.maxTokens,
          client: client,
        );

    var reply = '';
    var lastError = '';
    try {
      final streamed = await llmClient.generateStream(
        messages: messages,
        onChunk: onChunk,
        cancelSignal: cancelSignal,
        // 超时/重试来自用户配置（LlmConfig），默认 60s / 1 次重试
        timeout: Duration(seconds: config.timeoutSeconds),
        maxRetries: config.maxRetries,
      );
      reply = streamed.trim().isEmpty
          ? localReply(userInput, contract: contract)
          : streamed;
    } catch (e) {
      debugPrint('LLM 调用失败，回退到本地回复: $e');
      reply = localReply(userInput, contract: contract);
      lastError = 'LLM 调用失败: $e';
    }

    return NarrativeTurnResult(
      reply: reply,
      newState: ruleResult.newState,
      injectedMemories: injectedMemories,
      rollInfo: ruleResult.rollInfo,
      diceResults: ruleResult.diceResults,
      lastError: lastError,
    );
  }

  /// 组装 LLM 输入：用户输入 + 规则指令 + 骰子结果。
  String _buildInstruction(String userInput, RuleRunResult result) {
    final parts = <String>[userInput];
    final activeRule = result.activeRule;
    if (activeRule != null) {
      parts.add('（指令：${activeRule.action}）');
    }
    if (result.rollInfo.isNotEmpty) {
      parts.add('（骰子结果：\n${result.rollInfo}）');
    }
    return parts.join('\n');
  }

  /// 构建 LLM 消息列表（系统提示词 + 历史 + 当前输入）。
  List<LlmMessage> _buildLlmMessages({
    required String llmInput,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<Message> priorMessages,
    required List<String> attachedContexts,
    required String narrativeRules,
    int? maxMemories,
  }) {
    final history = priorMessages
        .where((m) => m.role != MessageRole.system)
        .map(
          (m) => LlmMessage(
            role: m.role == MessageRole.fate ? 'user' : 'assistant',
            content: m.content,
          ),
        );
    return [
      LlmMessage(
        role: 'system',
        content: buildSystemPrompt(
          contract: contract,
          currentState: currentState,
          memories: memories,
          narrativeRules: narrativeRules,
          attachedContexts: attachedContexts,
          maxMemories: maxMemories,
        ),
      ),
      ...history,
      LlmMessage(role: 'user', content: llmInput),
    ];
  }
}
