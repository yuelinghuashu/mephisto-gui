import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mephisto/services/llm/client.dart';

void main() {
  group('LlmClient.generateStream', () {
    test('逐行解析 SSE 并逐块回调 onChunk', () async {
      final mock = MockClient((request) async {
        // 验证请求构造：URL 拼接（baseUrl 带尾斜杠应被修正）、认证头、请求体
        expect(
          request.url.toString(),
          'https://api.deepseek.com/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer test-key');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'deepseek-v4-flash');
        expect(body['stream'], isTrue);

        return http.Response(
          'data: {"choices":[{"delta":{"content":"你好"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"，世界"}}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      });

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1/',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      final chunks = <String>[];
      final result = await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: chunks.add,
      );

      expect(chunks, ['你好', '，世界']);
      expect(result, '你好，世界');
    });

    test('apiKey 为空时不发送 Authorization 头（Ollama 场景）', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('data: [DONE]\n\n', 200);
      });

      final client = LlmClient(
        apiKey: '',
        baseUrl: 'http://localhost:11434',
        model: 'qwen2.5',
        client: mock,
      );
      await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: (_) {},
      );

      expect(captured, isNotNull);
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test('API 返回非 200 时抛出异常（含响应体）', () async {
      final mock = MockClient((request) async {
        return http.Response('{"error":"invalid api key"}', 401);
      });

      final client = LlmClient(
        apiKey: 'bad-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      await expectLater(
        client.generateStream(
          messages: [LlmMessage(role: 'user', content: 'hi')],
          onChunk: (_) {},
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('401'),
          ),
        ),
      );
    });

    test('服务端正常结束但没有任何 content delta 时返回空字符串', () async {
      final mock = MockClient((request) async {
        return http.Response(
          'data: {"choices":[{"delta":{"role":"assistant"}}]}\n\n'
          'data: [DONE]\n\n',
          200,
        );
      });

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      final result = await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: (_) {},
      );

      expect(result, isEmpty);
    });

    test('SocketException 在响应头到达前触发指数退避重试', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          // 第一次：模拟网络层连接拒绝（瞬时故障）
          throw const SocketException('Connection refused');
        }
        // 第二次：成功返回 SSE
        return http.Response('data: [DONE]\n\n', 200);
      });

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      final result = await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: (_) {},
      );

      expect(callCount, 2);
      expect(result, isEmpty);
    });

    test('http.ClientException 在响应头到达前触发指数退避重试', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          throw http.ClientException('Connection closed before full header');
        }
        return http.Response('data: [DONE]\n\n', 200);
      });

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      final result = await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: (_) {},
      );

      expect(callCount, 2);
      expect(result, isEmpty);
    });

    test('重试耗尽后仍抛 SocketException（不吞异常）', () async {
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        throw const SocketException('Connection refused');
      });

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      await expectLater(
        client.generateStream(
          messages: [LlmMessage(role: 'user', content: 'hi')],
          onChunk: (_) {},
        ),
        throwsA(isA<SocketException>()),
      );
      expect(callCount, 2); // 1 次尝试 + 1 次重试
    });

    test('非流式 JSON 响应（不支持 SSE 的代理）→ 从 message.content 提取内容', () async {
      // 某些 OpenAI 兼容代理忽略 stream:true，返回标准 Chat Completion JSON
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': '这是模拟的非流式响应内容。'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      final chunks = <String>[];
      final result = await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: chunks.add,
      );

      // 非流式 JSON 兜底提取内容；onChunk 无增量回调（一次性内容）
      expect(result, '这是模拟的非流式响应内容。');
      expect(chunks, isEmpty);
    });

    test('非流式 JSON 格式错误 → 返回空字符串且不抛异常（容忍解析失败）', () async {
      // 服务端返回无法解析的非 SSE/非 JSON 内容
      final mock = MockClient((request) async {
        return http.Response(
          'not-json-or-sse',
          200,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      });

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: mock,
      );

      final result = await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: (_) {},
      );

      // 无可用内容：返回空字符串，不抛异常（调用方按空响应回退本地回复）
      expect(result, isEmpty);
    });

    test('SSE data 行被 chunk 拆成两半时仍正确重组解析', () async {
      // 模拟 TCP 分片：一条完整的 data 行被拆到两个 chunk 中发送。
      // LineSplitter 流式解析应跨 chunk 累积并重组完整行，避免丢内容。
      const full =
          'data: {"choices":[{"delta":{"content":"你好，"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"世界"}}]}\n\n'
          'data: [DONE]\n\n';
      final bytes = utf8.encode(full);
      // 在第 20 字节处拆成两段（恰好切断第一行）
      const splitPoint = 20;
      final chunk1 = Uint8List.fromList(bytes.sublist(0, splitPoint));
      final chunk2 = Uint8List.fromList(bytes.sublist(splitPoint));

      final chunkedClient = _ChunkedMockClient([chunk1, chunk2]);

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: chunkedClient,
      );

      final chunks = <String>[];
      final result = await client.generateStream(
        messages: [LlmMessage(role: 'user', content: 'hi')],
        onChunk: chunks.add,
      );

      // 跨 chunk 拆分的 data 行仍被完整解析
      expect(chunks, ['你好，', '世界']);
      expect(result, '你好，世界');
    });

    test('流式读取中途超时不重试（已输出 chunk 不重复），抛流式超时异常', () async {
      // 模拟服务端在流式输出中途挂起：已发送部分内容后不再发数据。
      // 若被误判为「连接超时」整体重试，已送达 UI 的 chunk 会重复。
      var callCount = 0;
      final controller = StreamController<List<int>>();
      final hangingClient = _StreamHangMockClient(
        onSend: () => callCount++,
        stream: controller.stream,
      );
      // 发送第一个 chunk 后保持流打开（不再 close）→ 下一行 await 超时
      controller.add(
        utf8.encode('data: {"choices":[{"delta":{"content":"你好"}}]}\n\n'),
      );

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: hangingClient,
      );

      final chunks = <String>[];
      await expectLater(
        client.generateStream(
          messages: [LlmMessage(role: 'user', content: 'hi')],
          onChunk: chunks.add,
          timeout: const Duration(milliseconds: 50),
        ),
        // 流式阶段超时 = 已消费部分响应，重试会导致内容重复，
        // 因此包装为专用异常类型抛出（LlmInvoker 捕获后回退本地回复）
        throwsA(isA<LlmStreamTimeoutException>()),
      );

      // 关键断言：绝不重发整个请求
      expect(callCount, 1);
      // 已输出的 chunk 保持原样（未因重试重复）
      expect(chunks, ['你好']);
      await controller.close();
    });

    test('非 200 错误体读取超时不重试（业务错误重试无意义）', () async {
      var callCount = 0;
      final controller = StreamController<List<int>>();
      final hangingClient = _StreamHangMockClient(
        onSend: () => callCount++,
        stream: controller.stream,
        statusCode: 500,
      );
      // 不发送任何错误体数据 → 读取错误体超时

      final client = LlmClient(
        apiKey: 'test-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-v4-flash',
        client: hangingClient,
      );

      await expectLater(
        client.generateStream(
          messages: [LlmMessage(role: 'user', content: 'hi')],
          onChunk: (_) {},
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<LlmStreamTimeoutException>()),
      );

      // 非 200 是业务错误，重试不会成功 → 不重试
      expect(callCount, 1);
      await controller.close();
    });
  });
}

/// 模拟服务端挂起（发送部分数据后不再继续）的 mock 客户端。
///
/// 用于验证「流式读取阶段超时」与「响应头到达前连接超时」的区分：
/// 前者不应触发整体重试（已输出的 chunk 会重复）。
class _StreamHangMockClient extends http.BaseClient {
  final void Function() onSend;
  final Stream<List<int>> stream;
  final int statusCode;

  _StreamHangMockClient({
    required this.onSend,
    required this.stream,
    this.statusCode = 200,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend();
    return http.StreamedResponse(
      stream,
      statusCode,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );
  }
}

/// 模拟真实 TCP 分片的 mock 客户端。
///
/// `MockClient` 的 `send()` 会把 Response.body 作为单一完整流，无法表现
/// 网络层将一个 SSE 行拆成多个 chunk 到达的场景；此类直接重写 `send()`，
/// 返回真正的分片 [http.StreamedResponse]，供 `LineSplitter` 跨 chunk 重组验证。
class _ChunkedMockClient extends http.BaseClient {
  final List<Uint8List> chunks;

  _ChunkedMockClient(this.chunks);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      200,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );
  }
}
