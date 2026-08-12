import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import 'client.dart';

/// 共享 LLM 调用封装
///
/// 统一「构造客户端 + 调用 + 本地回退」的三段样板，被单角色
/// [NarrativeTurnService] 与多角色 [StageTurnService] 共享。
class LlmInvoker {
  /// 自定义 LLM 客户端构造器（测试注入用）
  final LlmClient Function(LlmConfig config)? clientFactory;

  /// 可选的共享 HTTP 客户端
  final http.Client? client;

  const LlmInvoker({this.clientFactory, this.client});

  /// 执行一次「LLM 调用 → 回退」的生成流程。
  ///
  /// 返回 `(reply, lastError)`：
  ///   - reply: 最终回复文本（LLM 成功 / 本地兜底）
  ///   - lastError: LLM 调用异常描述（无异常时为空字符串）
  Future<(String reply, String lastError)> generate({
    required List<LlmMessage> messages,
    required LlmConfig config,
    required void Function(String chunk) onChunk,
    required Future<String> Function() fallback,
    Future<void>? cancelSignal,
  }) async {
    final llmClient =
        clientFactory?.call(config) ??
        LlmClient(
          apiKey: config.apiKey,
          baseUrl: config.baseUrl,
          model: config.model,
          maxTokens: config.maxTokens,
          client: client,
        );

    try {
      final streamed = await llmClient.generateStream(
        messages: messages,
        onChunk: onChunk,
        cancelSignal: cancelSignal,
        timeout: Duration(seconds: config.timeoutSeconds),
        maxRetries: config.maxRetries,
      );
      final trimmed = streamed.trim();
      if (trimmed.isEmpty) {
        return (await fallback(), '');
      }
      return (streamed, '');
    } catch (e) {
      debugPrint('LLM 调用失败，回退到本地回复: $e');
      return (await fallback(), 'LLM 调用失败: $e');
    }
  }
}