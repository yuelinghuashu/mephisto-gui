import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// LLM 错误响应体最大读取字节数。
///
/// 防止异常 API 返回超长错误体导致客户端内存膨胀。
const int maxErrorBodyBytes = 8192;

/// 默认最大重试次数。
///
/// 仅对**网络层瞬时故障**重试（连接超时/响应头未到达超时/流读取超时），
/// 业务错误（HTTP 4xx/5xx 状态码、解析错误）不重试——它们不会因重试而成功。
const int defaultMaxRetries = 1;

/// 重试基础延迟（毫秒）。
///
/// 使用指数退避：第 N 次重试延迟 = baseDelayMs * 2^(N-1)，
/// 避免重试风暴同时打向 API 服务。
const int retryBaseDelayMs = 500;

/// LLM 消息（API 格式）
class LlmMessage {
  /// user、assistant、system
  final String role;

  final String content;

  LlmMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// LLM 客户端
///
/// 纯网络请求层，不包含任何默认值。
/// 所有参数（baseUrl、model、apiKey）由调用方传入。
class LlmClient {
  final String apiKey;
  final String baseUrl;
  final String model;
  final int maxTokens;

  /// 可选的 http 客户端（主要用于测试注入）
  final http.Client? client;

  const LlmClient({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.maxTokens = 4096,
    this.client,
  });

  /// 生成回复（SSE 流式输出）。
  ///
  /// 关键行为：
  ///   - 超时：默认 60 秒，同时保护「响应头到达」与「流式数据读取」
  ///   - 重试：仅「响应头到达前」的网络层瞬时故障（超时/连接/客户端异常）
  ///     按指数退避重试；流式中途超时、API 4xx/5xx 均不重试
  ///   - 取消：传入 [cancelSignal] 后提前终止 SSE 读取，返回已累积内容
  ///   - 返回：完整拼接后的回复内容
  Future<String> generateStream({
    required List<LlmMessage> messages,
    required void Function(String chunk) onChunk,
    Duration timeout = const Duration(seconds: 60),
    Future<void>? cancelSignal,
    int maxRetries = defaultMaxRetries,
  }) async {
    // 去掉 baseUrl 末尾多余斜杠，避免出现 `//chat/completions`
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$base/chat/completions');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      // 本地服务（如 Ollama）不需要 API Key，为空时不发送认证头
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };

    final httpClient = client ?? http.Client();
    try {
      // ---- 发送请求 + 读取响应体（带连接层重试） ----
      // 仅在此阶段发生「网络层瞬时故障」时重试整个请求：
      //   - TimeoutException：响应头未在超时时间内到达（连接超时）
      //   - SocketException：连接被拒绝 / DNS 解析失败等
      //   - ClientException：http 包封装的网络层异常
      // 一旦进入流式读取，不再重试（避免重复内容）。
      // 业务错误（HTTP 4xx/5xx 状态码、解析错误）不重试——它们不会因重试而成功。
      Object? lastNetworkError;
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        // 每次尝试创建新的 request：http.Request.finalize() 只能调用一次，
        // 复用同一对象会导致第二次发送时抛出 StateError（重试场景）。
        final request = http.Request('POST', url)
          ..headers.addAll(headers)
          ..body = jsonEncode({
            'model': model,
            'messages': messages.map((m) => m.toJson()).toList(),
            'stream': true,
            'max_tokens': maxTokens,
          });
        try {
          return await _sendAndReadStream(
            httpClient: httpClient,
            request: request,
            timeout: timeout,
            cancelSignal: cancelSignal,
            onChunk: onChunk,
          );
        } on TimeoutException catch (e) {
          lastNetworkError = e;
          if (attempt == maxRetries) rethrow;
          // 指数退避：500ms → 1000ms → 2000ms …
          final delayMs = retryBaseDelayMs * (1 << attempt);
          debugPrint(
            'LLM 请求超时，${maxRetries - attempt} 次后重试 '
            '(延迟 ${delayMs}ms): $e',
          );
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        } on SocketException catch (e) {
          lastNetworkError = e;
          if (attempt == maxRetries) rethrow;
          final delayMs = retryBaseDelayMs * (1 << attempt);
          debugPrint(
            'LLM 网络连接异常，${maxRetries - attempt} 次后重试 '
            '(延迟 ${delayMs}ms): $e',
          );
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        } on http.ClientException catch (e) {
          lastNetworkError = e;
          if (attempt == maxRetries) rethrow;
          final delayMs = retryBaseDelayMs * (1 << attempt);
          debugPrint(
            'LLM HTTP 客户端异常，${maxRetries - attempt} 次后重试 '
            '(延迟 ${delayMs}ms): $e',
          );
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
      }
      // 理论不可达（循环内 rethrow 或 return），但需要满足编译器
      throw lastNetworkError!;
    } finally {
      // 仅关闭自建客户端；注入的客户端由调用方负责生命周期
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// 发送单个请求并读取完整流式响应。
  ///
  /// 拆分自 [generateStream]，使「带重试的循环」与「单次请求处理」职责分离。
  Future<String> _sendAndReadStream({
    required http.Client httpClient,
    required http.Request request,
    required Duration timeout,
    required Future<void>? cancelSignal,
    required void Function(String chunk) onChunk,
  }) async {
    final response = await httpClient.send(request).timeout(timeout);

    if (response.statusCode != 200) {
      // 限制错误响应体的读取长度，防止恶意/异常服务返回超长错误体导致内存膨胀
      final errorBody = await response.stream
          .transform(utf8.decoder)
          .take(maxErrorBodyBytes + 1)
          .join()
          .timeout(timeout);
      final truncated = errorBody.length > maxErrorBodyBytes
          ? '${errorBody.substring(0, maxErrorBodyBytes)}\n…（响应体已截断）'
          : errorBody;
      throw Exception('API 错误: ${response.statusCode}\n$truncated');
    }

    final fullContent = StringBuffer();
    // 取消信号：完成时置位标记，SSE 循环内检查后提前 break
    final cancelCompleter = Completer<void>();
    if (cancelSignal != null) {
      cancelSignal.whenComplete(cancelCompleter.complete);
    }
    // 取消信号是否已触发（用于 SSE 循环内提前 break）
    bool isCancelled() => cancelCompleter.isCompleted;

    // 流式读取：每行数据也应用 [timeout]，防止服务端建立连接后长时间
    // 不发数据（心跳间隔过长/挂起）导致 UI 永久卡在「生成中」
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(timeout)) {
      if (isCancelled()) break;
      if (!line.startsWith('data:')) continue;

      final data = line.substring(5).trim();
      if (data == '[DONE]') break;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        final first = choices == null || choices.isEmpty ? null : choices[0];
        final firstMap = first is Map<String, dynamic> ? first : null;
        final deltaMap = firstMap?['delta'];
        final deltaMapTyped =
            deltaMap is Map<String, dynamic> ? deltaMap : null;
        final delta = deltaMapTyped?['content'] as String?;
        if (delta != null && delta.isNotEmpty) {
          fullContent.write(delta);
          onChunk(delta);
        }
      } catch (e) {
        debugPrint('SSE 解析失败: $data\n$e');
      }
    }

    // 诊断：如果流解析后没有内容，打印原始响应信息用于排查
    if (fullContent.isEmpty) {
      debugPrint(
        '⚠️ LLM 返回空内容。'
        'Base URL: $baseUrl, Model: $model, '
        '状态码: ${response.statusCode}',
      );
      // 无法在流结束后重新读取，但至少输出已知信息供排查
      debugPrint('提示：如果 API 正常但未返回内容，请检查响应格式是否符合 OpenAI SSE 规范。');
    }

    return fullContent.toString();
  }
}