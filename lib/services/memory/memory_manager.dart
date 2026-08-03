/// 记忆管理：自动提取、去重、压缩。
///
/// 纯服务层实现，不依赖 Riverpod / UI 框架：
/// LLM 配置由调用方显式传入，与 [NarrativeTurnService] 的设计哲学保持一致，
/// 可脱离框架直接单元测试。
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import '../llm/client.dart';

/// 记忆管理：自动提取、去重、压缩。
class MemoryManager {
  /// 可选的共享 HTTP 客户端（由调用方注入；null 时每次请求新建）
  final http.Client? client;

  const MemoryManager({this.client});

  // ---- 配置 ----
  static const int extractInterval = 3;
  static const int maxLimit = 30;
  static const int compressRetain = 5;
  static const int extractWindow = 10;

  /// 每 N 轮提取记忆；返回更新后的记忆（null 表示未触发）。
  Future<List<Memory>?> maybeExtract({
    required List<HistoryEntry> history,
    required List<Memory> memories,
    LlmConfig? config,
  }) async {
    final round = history.where((h) => h.role == MessageRole.fate).length;
    if (round <= 0 || round % extractInterval != 0) return null;
    return extract(history: history, memories: memories, config: config);
  }

  /// 从最近对话提取记忆；返回新记忆列表（已去重/压缩）。
  ///
  /// [config] 无持久化配置时可由调用方传入默认 [LlmConfig]。
  Future<List<Memory>> extract({
    required List<HistoryEntry> history,
    required List<Memory> memories,
    LlmConfig? config,
  }) async {
    if (history.isEmpty) return memories;

    final effectiveConfig = config ?? const LlmConfig();

    // 最近 N 轮
    const window = extractWindow * 2;
    final recent = history.length > window
        ? history.sublist(history.length - window)
        : history;

    final historyText = recent
        .map((h) => '${h.role == MessageRole.fate ? '命运' : '角色'}: ${h.content}')
        .join('\n');
    final existingText = memories.isEmpty
        ? '（无）'
        : memories.map((m) => '- ${m.content}').join('\n');

    final prompt =
        '''
从以下对话中提取关键事件摘要。

规则：
1. 提取 2-5 条对角色产生重大影响的核心事件，覆盖整段剧情的关键推进
2. 不要只提取最后一句话或结尾内容，要回顾整段对话中的完整事件链
3. 每条摘要 20-60 个字，保留关键人物、地点、动作和信息
4. 忽略日常寒暄和无意义对话
5. 如果事件已经存在于现有记忆中，不要重复提取
6. 禁止修改或重复角色的核心设定（如角色名、锚点内容、状态值等）
7. 输出格式：每行一条，以 "- " 开头

现有记忆：
$existingText

对话历史：
$historyText

请输出新提取的记忆：''';

    try {
      final newLines = await _callLLM(prompt, config: effectiveConfig);
      if (newLines.isEmpty) return memories;

      // 去重
      final existing = memories.map((m) => m.content).toSet();
      final fresh = newLines.where((l) => !existing.contains(l)).toList();
      if (fresh.isEmpty) return memories;

      var updated = [...memories, ...fresh.map((c) => Memory(content: c))];

      // 压缩
      if (updated.length > maxLimit) {
        updated = await compress(updated, config: effectiveConfig);
      }
      return updated;
    } catch (e) {
      debugPrint('记忆提取失败（静默跳过）: $e');
      return memories;
    }
  }

  /// 压缩记忆（旧记忆压缩为摘要 + 保留最近 N 条）。
  Future<List<Memory>> compress(
    List<Memory> allMemories, {
    LlmConfig? config,
  }) async {
    if (allMemories.length <= maxLimit) return allMemories;

    final effectiveConfig = config ?? const LlmConfig();

    final toCompress = allMemories.sublist(
      0,
      allMemories.length - compressRetain,
    );
    final recent = allMemories.sublist(allMemories.length - compressRetain);

    final compressText = toCompress.map((m) => '- ${m.content}').join('\n');
    final prompt =
        '''
以下是一段角色的长期记忆列表。请将这些记忆压缩为不超过 5 条最重要的摘要。

要求：
1. 保留最关键的 3-5 个核心事件
2. 保留最近发生的重要事件
3. 合并相似或重复的记忆
4. 每条摘要不超过 20 个字
5. 禁止篡改角色的核心设定（如角色名、锚点内容、状态值等）
6. 输出格式：每行一条，以 "- " 开头

现有记忆：
$compressText

请输出压缩后的记忆：''';

    try {
      final lines = await _callLLM(prompt, config: effectiveConfig);
      if (lines.isEmpty) return allMemories;
      return [...lines.map((c) => Memory(content: c)), ...recent];
    } catch (e) {
      debugPrint('记忆压缩失败（保留原列表）: $e');
      return allMemories;
    }
  }

  /// 调用 LLM 并解析输出为记忆行列表。
  Future<List<String>> _callLLM(
    String prompt, {
    required LlmConfig config,
  }) async {
    final llmClient = LlmClient(
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      model: config.model,
      maxTokens: config.maxTokens,
      client: client,
    );

    final reply = await llmClient.generateStream(
      messages: [LlmMessage(role: 'user', content: prompt)],
      onChunk: (_) {}, // 记忆管理不需要实时输出
    );

    return reply
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.startsWith('- ') ? l.substring(2).trim() : l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}