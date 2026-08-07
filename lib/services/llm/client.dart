import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// LLM 错误响应体最大读取字节数。
///
/// 防止异常 API 返回超长错误体导致客户端内存膨胀。
const int maxErrorBodyBytes = 8192;

/// LLM 消息（API 格式）
class LlmMessage {
  /// 角色（user、assistant、system）
  final String role;

  /// 内容
  final String content;

  /// 构造函数
  LlmMessage({required this.role, required this.content});

  /// 转换为 JSON 格式
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

  /// 生成回复（流式输出）
  ///
  /// 使用 `http.Client().send` 逐行读取 SSE（Server-Sent Events）响应，
  /// 每收到一个 content delta 就调用 [onChunk]，实现真正的逐 token 回调。
  ///
  /// 行为说明：
  ///   - 网络超时：默认 60 秒，可通过 [timeout] 覆盖
  ///   - API 错误：状态码非 200 时抛出 [Exception]（含响应体）
  ///   - 解析错误：单行解析失败仅打印日志，不影响后续内容
  ///   - 返回：完整拼接后的回复内容
  Future<String> generateStream({
    required List<LlmMessage> messages,
    required void Function(String chunk) onChunk,
    Duration timeout = const Duration(seconds: 60),
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

    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = jsonEncode({
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': true,
        'max_tokens': maxTokens,
      });

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.send(request).timeout(timeout);

      if (response.statusCode != 200) {
        // 限制错误响应体的读取长度，防止恶意/异常服务返回超长错误体导致内存膨胀
        final errorBody = await response.stream
            .transform(utf8.decoder)
            .take(maxErrorBodyBytes + 1)
            .join();
        final truncated = errorBody.length > maxErrorBodyBytes
            ? '${errorBody.substring(0, maxErrorBodyBytes)}\n…（响应体已截断）'
            : errorBody;
        throw Exception('API 错误: ${response.statusCode}\n$truncated');
      }

      final fullContent = StringBuffer();
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
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
    } finally {
      // 仅关闭自建客户端；注入的客户端由调用方负责生命周期
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
