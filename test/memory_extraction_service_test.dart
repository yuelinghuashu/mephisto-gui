import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/services/memory/memory_extraction_service.dart';
import 'package:mephisto/services/memory/memory_manager.dart';

/// MemoryExtractionService 安全合并测试
///
/// 覆盖「提取期间新对话不丢失」的合并语义：
///   - 无新对话 → 直接采用提取结果
///   - 有新对话 → 以「当前记忆」为基底，仅追加新提取结果中不存在的新条目
///   - 合并后超限 → 触发压缩
///
/// 通过可注入的 FakeMemoryManager 控制 maybeExtract/compress 的返回值，
/// 不依赖真实 LLM。
void main() {
  const manager = _FakeMemoryManager();

  group('extractWithSafeMerge 安全合并', () {
    test('提取期间无新对话 → 直接采用提取结果', () async {
      const service = MemoryExtractionService();
      final input = MemoryExtractionInput(
        history: [
          const HistoryEntry(role: MessageRole.fate, content: '出发'),
          const HistoryEntry(role: MessageRole.assistant, content: '回应'),
        ],
        memories: [Memory(content: '旧记忆')],
        historyLengthAtStart: 2,
      );
      // 当前长度 == 启动时长度（2）→ 无新对话
      final result = await service.extractWithSafeMerge(
        manager: manager,
        input: input,
        currentHistoryLength: 2,
        currentMemories: [Memory(content: '旧记忆')],
        config: null,
      );
      expect(result, isNotNull);
      expect(result!.map((m) => m.content), ['新提取记忆']);
    });

    test('提取期间有新对话 → 以当前记忆为基底，仅追加不存在的新条目', () async {
      const service = MemoryExtractionService();
      final input = MemoryExtractionInput(
        history: [const HistoryEntry(role: MessageRole.fate, content: '出发')],
        memories: [Memory(content: '旧记忆')],
        historyLengthAtStart: 1,
      );
      // 当前长度 3 > 启动时 1 → 有新对话；当前记忆已含「提取期间注入的记忆」
      final result = await service.extractWithSafeMerge(
        manager: manager,
        input: input,
        currentHistoryLength: 3,
        currentMemories: [
          Memory(content: '旧记忆'),
          Memory(content: '提取期间注入的记忆'),
        ],
        config: null,
      );
      expect(result, isNotNull);
      // 合并结果 = 当前记忆 + 新提取中不存在的条目
      expect(result!.map((m) => m.content), ['旧记忆', '提取期间注入的记忆', '新提取记忆']);
    });

    test('有新对话但提取结果均为已有内容 → 返回 null（无变化）', () async {
      const service = MemoryExtractionService();
      final input = MemoryExtractionInput(
        history: [const HistoryEntry(role: MessageRole.fate, content: '出发')],
        memories: [Memory(content: '新提取记忆')],
        historyLengthAtStart: 1,
      );
      final result = await service.extractWithSafeMerge(
        manager: manager,
        input: input,
        currentHistoryLength: 5,
        // 当前记忆已包含提取结果中的全部内容
        currentMemories: [Memory(content: '新提取记忆')],
        config: null,
      );
      expect(result, isNull);
    });

    test('提取未触发（maybeExtract 返回 null）→ 返回 null', () async {
      const service = MemoryExtractionService();
      const input = MemoryExtractionInput(
        history: [],
        memories: [],
        historyLengthAtStart: 0,
      );
      final result = await service.extractWithSafeMerge(
        manager: manager,
        input: input,
        currentHistoryLength: 0,
        currentMemories: [],
        config: null,
      );
      expect(result, isNull);
    });
  });
}

/// 可控的 MemoryManager 测试替身。
///
/// [maybeExtract] 固定返回一条「新提取记忆」；
/// 历史为空时返回 null（模拟未触发）。
class _FakeMemoryManager extends MemoryManager {
  const _FakeMemoryManager();

  @override
  Future<List<Memory>?> maybeExtract({
    required List<HistoryEntry> history,
    required List<Memory> memories,
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    if (history.isEmpty) return null;
    return [Memory(content: '新提取记忆')];
  }

  @override
  Future<List<Memory>> compress(
    List<Memory> allMemories, {
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    // 不真正调用 LLM：原样返回（测试仅关心「超限时 compress 被调用」语义）
    return allMemories;
  }
}
