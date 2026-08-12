/// 记忆管理：自动提取、去重、压缩。
///
/// 纯服务层实现，不依赖 Riverpod / UI 框架：
/// LLM 配置由调用方显式传入，与 [NarrativeTurnService] 的设计哲学保持一致，
/// 可脱离框架直接单元测试。
///
/// 极简设计（为「坚守人设」服务）：
///   - **永久保存**：记忆写入 .meph【记忆】区块后永不删除，重启后仍在
///   - **[importance]**：1-5 星标注「这条对角色多重要」，仅用于注入时排序裁剪，
///     保证人设核心/重大事件优先被模型看到
///   - **压缩保护**：高权重记忆（≥ [Memory.highImportanceThreshold]）永不压缩丢弃
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import '../llm/client.dart';

/// 记忆管理：自动提取、去重、压缩、注入排序。
class MemoryManager {
  /// 可选的共享 HTTP 客户端（由调用方注入；null 时每次请求新建）
  final http.Client? client;

  const MemoryManager({this.client});

  // ---- 配置 ----
  static const int extractInterval = 3;
  static const int maxLimit = 30;
  static const int compressRetain = 5;

  /// 高权重记忆最多保留条数。
  ///
  /// 压缩时，超过此数量的高权重记忆（≥ [Memory.highImportanceThreshold]）会
  /// 按权重升序降级参与压缩——防止用户手写大量权重 5 记忆且自动提取
  /// 持续产出高权重时，列表无限膨胀导致 token 消耗失控。
  static const int highImportanceCap = 15;

  /// 提取对话窗口大小（最近 N 轮「命运 + 角色」对）。
  ///
  /// 与 [extractInterval] 的关系：
  ///   - 每 [extractInterval] 轮触发一次提取
  ///   - 提取时取最近「[extractWindow] 轮完整对话」（即 [extractWindow] × 2 条
  ///     历史条目：每条命运 + 对应角色回复）
  static const int extractWindow = 10;

  /// 记忆管理 LLM 调用的超时时间（比主叙事短）。
  ///
  /// 记忆提取/压缩是**后台辅助任务**，不应阻塞主流程：
  /// 服务端挂起/超时时应快速失败静默跳过，而不是无限等待占住调用方。
  static const Duration llmTimeout = Duration(seconds: 30);

  /// LLM 提取记忆时的权重前缀正则（同 meph_parser 中 `_memoryPrefixPattern`）。
  ///
  /// 复用同款格式：`[4] 内容`，使自动提取的记忆与契约手写记忆共享权重解析逻辑。
  static final RegExp _weightPrefixPattern = RegExp(r'^\[(\d)\]\s+(.+)$');

  /// 按重要性权重降序排序记忆（高权重在前，同权重保持原顺序稳定）。
  ///
  /// 供注入提示词时使用：保证人设核心/重大事件优先被模型看到。
  static List<Memory> sortByImportance(List<Memory> memories) {
    if (memories.isEmpty) return memories;
    final sorted = [...memories]
      ..sort((a, b) => b.importance.compareTo(a.importance));
    return sorted;
  }

  /// 按 [maxMemories] 裁剪记忆列表：高权重必带 + 其余按权重降序补足。
  ///
  /// 供系统提示词构建（单角色 / 多角色舞台）复用，消除重复实现：
  ///   - 高权重记忆（≥ [Memory.highImportanceThreshold]）全部保留（人设核心）
  ///   - 其余按权重降序补足剩余名额
  ///   - 返回结果已按权重排序（高权重在前、低权重降序在后），调用方无需再排序
  ///
  /// 记忆数量未超上限时直接返回原列表**不排序**（保持调用方语义，
  /// 由调用方决定是否需要 [sortByImportance]）。
  static List<Memory> clipMemories(List<Memory> memories, int maxMemories) {
    if (memories.length <= maxMemories) return memories;
    final high = sortByImportance(
      memories
          .where((m) => m.importance >= Memory.highImportanceThreshold)
          .toList(),
    );
    final rest = sortByImportance(
      memories
          .where((m) => m.importance < Memory.highImportanceThreshold)
          .toList(),
    );
    final remainingSlots = (maxMemories - high.length).clamp(0, maxMemories);
    return [...high, ...rest.take(remainingSlots)];
  }

  /// 每 N 轮提取记忆；返回更新后的记忆（null 表示未触发）。
  ///
  /// [config] 为主配置；[auxConfig] 为辅助任务独立模型配置（可空）。
  Future<List<Memory>?> maybeExtract({
    required List<HistoryEntry> history,
    required List<Memory> memories,
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    final round = history.where((h) => h.role == MessageRole.fate).length;
    if (round <= 0 || round % extractInterval != 0) return null;
    return extract(
      history: history,
      memories: memories,
      config: config,
      auxConfig: auxConfig,
    );
  }

  /// 多角色批量记忆提取。
  ///
  /// 输入：角色名 → 该角色的历史与现有记忆。
  /// 输出：`角色名 → 该角色新提取的记忆列表`（已去重）。
  ///
  /// 设计要点：
  ///   - **单次 LLM 调用**：将所有角色的对话与记忆合并到一个 prompt，
  ///     让模型一次性为所有角色提取记忆。相较于每个角色独立调用
  ///     LLM（N 次调用），5 角色舞台可减少 4 次 LLM 往返。
  ///   - **输出格式**：每行以 `【角色名】` 开头标记归属，后续行为该角色的
  ///     提取结果（`- [权重] 内容`）。
  ///   - **去重**：与单角色 [extract] 相同的「按内容精确去重 + 权重升级」逻辑。
  ///   - **失败回退**：LLM 异常时返回空 map（调用方跳过，静默）。
  ///
  /// 参数：
  ///   - roleHistory: 角色名 → 待提取的历史（提取触发条件由调用方判断）
  ///   - roleMemories: 角色名 → 该角色现有记忆（去重基底）
  ///   - config: LLM 配置
  Future<Map<String, List<Memory>>> extractForRoles({
    required Map<String, List<HistoryEntry>> roleHistory,
    required Map<String, List<Memory>> roleMemories,
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    if (roleHistory.isEmpty) return const {};

    final effectiveConfig = config ?? const LlmConfig();

    // 组装跨角色 prompt：每位角色的历史与现有记忆并排展示
    final buffer = StringBuffer();
    final orderedRoles = roleHistory.keys.toList();
    for (final roleName in orderedRoles) {
      final history = roleHistory[roleName]!;
      final memories = roleMemories[roleName] ?? const <Memory>[];

      final recent = history.length > extractWindow * 2
          ? history.sublist(history.length - extractWindow * 2)
          : history;
      final historyText = recent
          .map((h) => '${h.role == MessageRole.fate ? '命运' : '角色'}: ${h.content}')
          .join('\n');
      final existingText = memories.isEmpty
          ? '（无）'
          : memories.map((m) => '- ${m.content}').join('\n');

      buffer.writeln('【$roleName】');
      buffer.writeln('现有记忆:');
      buffer.writeln(existingText);
      buffer.writeln('对话历史 ($roleName):');
      buffer.writeln(historyText);
      buffer.writeln();
    }

    final prompt =
        '''
从以下各角色的对话中，为每位角色提取关键事件摘要。

角色列表：${orderedRoles.join('、')}

要求：
1. 每个角色提取 1-3 条对角色产生重大影响的核心事件
2. 如果角色的对话历史中没有值得记录的内容，该角色可以输出空（不输出该角色区块）
3. 每条摘要 20-60 个字
4. 忽略日常寒暄和无意义对话
5. 如果事件已经存在于现有记忆中，不要重复提取
6. 禁止修改角色的核心设定（角色名、锚点内容、状态值等）
7. 输出格式：每行以「【角色名】」开头标记段落，其下每行一条，以 "- [权重] 内容" 开头
   - 权重为 1-5 的整数，表示这条记忆对角色塑造的重要性
   - 如果无法判断权重，使用默认 3

$buffer

请输出新提取的记忆：''';

    try {
      final lines = await _callLLM(
        prompt,
        config: effectiveConfig,
        auxConfig: auxConfig,
      );
      if (lines.isEmpty) return const {};

      // 解析跨角色输出：按「【角色名】」段落切分，每行 `- [权重] 内容`
      final result = <String, List<Memory>>{};
      String? currentRole;
      for (final line in lines) {
        // 角色段落标题
        if (line.startsWith('【') && line.endsWith('】')) {
          final roleName = line.substring(1, line.length - 1).trim();
          // 只接受已知角色名
          if (roleHistory.containsKey(roleName)) {
            currentRole = roleName;
            result.putIfAbsent(roleName, () => []);
          } else {
            currentRole = null; // 未知角色段落 → 忽略
          }
          continue;
        }
        if (currentRole == null) continue;

        // 解析权重前缀 [N]
        final match = _weightPrefixPattern.firstMatch(line);
        if (match == null) {
          result[currentRole]!.add(Memory(content: line));
          continue;
        }
        final importance =
            int.tryParse(match[1]!)?.clamp(1, Memory.maxImportance) ??
            Memory.defaultImportance;
        result[currentRole]!.add(
          Memory(content: match[2]!.trim(), importance: importance),
        );
      }

      // 去重 + 权重升级（每个角色基于其现有记忆去重）
      final cleaned = <String, List<Memory>>{};
      for (final roleName in result.keys) {
        final parsed = result[roleName]!;
        if (parsed.isEmpty) continue;

        final existingByContent = <String, int>{
          for (final m in roleMemories[roleName] ?? const <Memory>[])
            m.content: m.importance,
        };
        final fresh = <Memory>[];
        for (final m in parsed) {
          final existingImportance = existingByContent[m.content];
          if (existingImportance == null) {
            existingByContent[m.content] = m.importance;
            fresh.add(m);
          } else if (m.importance > existingImportance) {
            existingByContent[m.content] = m.importance;
            fresh.add(m);
          }
        }
        if (fresh.isNotEmpty) {
          cleaned[roleName] = fresh;
        }
      }
      return cleaned;
    } catch (e) {
      debugPrint('多角色记忆提取失败（静默跳过）: $e');
      return const {};
    }
  }

  /// 从最近对话提取记忆；返回新记忆列表（已去重/压缩）。
  ///
  /// [config] 无持久化配置时可由调用方传入默认 [LlmConfig]。
  Future<List<Memory>> extract({
    required List<HistoryEntry> history,
    required List<Memory> memories,
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    if (history.isEmpty) return memories;

    final effectiveConfig = config ?? const LlmConfig();

    // 最近 N 轮完整对话（每轮 = 1 条命运 + 1 条角色回复，共 2 条历史条目）
    const maxEntryCount = extractWindow * 2;
    final recent = history.length > maxEntryCount
        ? history.sublist(history.length - maxEntryCount)
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
5. 如果事件已经存在于现有记忆中，不要重复提取——即使措辞不同但语义相同（如同一事件的另一种说法），也不应再提取
6. 禁止修改或重复角色的核心设定（如角色名、锚点内容、状态值等）
7. 输出格式：每行一条，以 "- [权重] 内容" 开头
   - 权重为 1-5 的整数，表示这条记忆对角色塑造的重要性：
     5 = 角色核心誓言/根本动机，4 = 重大剧情事件，3 = 一般进展，2 = 次要信息，1 = 边缘细节
   - 如果无法判断权重，使用默认 3

现有记忆：
$existingText

对话历史：
$historyText

请输出新提取的记忆：''';

    try {
      final lines = await _callLLM(
        prompt,
        config: effectiveConfig,
        auxConfig: auxConfig,
      );
      if (lines.isEmpty) return memories;

      // 解析 LLM 返回的权重前缀（[N] 内容），无前缀时兜底默认权重
      final parsed = <Memory>[];
      for (final line in lines) {
        final match = _weightPrefixPattern.firstMatch(line);
        if (match == null) {
          parsed.add(Memory(content: line));
          continue;
        }
        final importance =
            int.tryParse(match[1]!)?.clamp(1, Memory.maxImportance) ??
            Memory.defaultImportance;
        parsed.add(
          Memory(content: match[2]!.trim(), importance: importance),
        );
      }
      if (parsed.isEmpty) return memories;

      // ---- 去重 + 权重升级（按内容精确去重） ----
      // 已有记忆内容与新提取相同时：
      //   - 新权重 ≤ 旧权重 → 丢弃新条目（不重复）
      //   - 新权重 > 旧权重 → 替换旧条目（权重升级）
      final existingByContent = <String, int>{
        for (final m in memories) m.content: m.importance,
      };
      final fresh = <Memory>[];
      for (final m in parsed) {
        final existingImportance = existingByContent[m.content];
        if (existingImportance == null) {
          existingByContent[m.content] = m.importance;
          fresh.add(m);
        } else if (m.importance > existingImportance) {
          existingByContent[m.content] = m.importance;
          fresh.add(m);
        }
      }
      if (fresh.isEmpty) return memories;

      // 合并：权重升级的条目替换旧条目，全新条目追加
      final upgradedContents = fresh
          .where((f) => memories.any((m) => m.content == f.content))
          .map((f) => f.content)
          .toSet();
      final merged = memories.map((m) {
        for (final f in fresh) {
          if (f.content == m.content && f.importance > m.importance) {
            return f;
          }
        }
        return m;
      }).toList();
      final brandNew = fresh
          .where((m) => !upgradedContents.contains(m.content))
          .toList();

      var updated = [...merged, ...brandNew];

      // 压缩
      if (updated.length > maxLimit) {
        updated = await compress(
          updated,
          config: effectiveConfig,
          auxConfig: auxConfig,
        );
      }
      return updated;
    } catch (e) {
      debugPrint('记忆提取失败（静默跳过）: $e');
      return memories;
    }
  }

  /// 压缩记忆（旧记忆压缩为摘要 + 保留最近 N 条）。
  ///
  /// 高权重记忆（importance ≥ [Memory.highImportanceThreshold]）永不参与压缩。
  Future<List<Memory>> compress(
    List<Memory> allMemories, {
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    if (allMemories.length <= maxLimit) return allMemories;

    final effectiveConfig = config ?? const LlmConfig();

    // 高权重记忆默认永不压缩，但超过 [highImportanceCap] 上限时，
    // 把「最低权重的高权重记忆」降级为可压缩（保护数量合理性）
    final high = allMemories
        .where((m) => m.importance >= Memory.highImportanceThreshold)
        .toList()
      ..sort((a, b) => a.importance.compareTo(b.importance)); // 权重升序：最低优先降级
    var protectedHigh = high;
    var downgraded = <Memory>[];
    if (high.length > highImportanceCap) {
      // 保留权重最高的 highImportanceCap 条，其余降级参与压缩
      protectedHigh = high.sublist(high.length - highImportanceCap);
      downgraded = high.sublist(0, high.length - highImportanceCap);
    }
    final compressible = <Memory>[
      ...downgraded,
      ...allMemories.where(
        (m) => m.importance < Memory.highImportanceThreshold,
      ),
    ];
    if (compressible.isEmpty) return protectedHigh;

    final toCompress = compressible.sublist(
      0,
      compressible.length > compressRetain
          ? compressible.length - compressRetain
          : 0,
    );
    final recentCompressible = compressible.sublist(
      compressible.length > compressRetain
          ? compressible.length - compressRetain
          : 0,
    );
    // 待压缩的条目为空 → 无需调用 LLM，直接合并保护高权重 + 最近
    if (toCompress.isEmpty) {
      return [...protectedHigh, ...recentCompressible];
    }

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
      final lines = await _callLLM(
        prompt,
        config: effectiveConfig,
        auxConfig: auxConfig,
      );
      if (lines.isEmpty) return allMemories;
      return [...lines.map((c) => Memory(content: c)), ...protectedHigh, ...recentCompressible];
    } catch (e) {
      debugPrint('记忆压缩失败（保留原列表）: $e');
      return allMemories;
    }
  }

  /// 调用 LLM 并解析输出为记忆行列表。
  ///
  /// [config] 为主配置；[auxConfig] 非空且启用时使用独立辅助模型
  ///（通过 [LlmAuxConfig.resolve] 继承主配置缺省字段）。
  Future<List<String>> _callLLM(
    String prompt, {
    required LlmConfig config,
    LlmAuxConfig? auxConfig,
  }) async {
    // 多模型路由：启用独立辅助模型时，用其配置覆盖主配置
    final effective = (auxConfig != null && auxConfig.enabled)
        ? auxConfig.resolve(config)
        : config;
    final llmClient = LlmClient(
      apiKey: effective.apiKey,
      baseUrl: effective.baseUrl,
      model: effective.model,
      maxTokens: effective.maxTokens,
      client: client,
    );

    final reply = await llmClient.generateStream(
      messages: [LlmMessage(role: 'user', content: prompt)],
      onChunk: (_) {}, // 记忆管理不需要实时输出
      // 后台任务超时保护：取「用户配置超时」与「后台任务上限」中较小者，
      // 确保记忆提取/压缩在服务端挂起时快速失败，不阻塞主叙事流程。
      // 重试次数沿用用户配置（默认 1 次）。
      timeout: Duration(
        seconds:
            config.timeoutSeconds > llmTimeout.inSeconds
            ? llmTimeout.inSeconds
            : config.timeoutSeconds,
      ),
      maxRetries: config.maxRetries,
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