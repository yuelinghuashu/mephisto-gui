/// 记忆提取编排服务
///
/// 封装「记忆提取 → 安全合并」的通用管线，供单角色 [NarrativeNotifier]
/// 与多角色 [StageNarrativeNotifier] 复用，消除两处约 60 行的重复实现。
///
/// 核心设计（「提取期间新对话不丢失」）：
///   - 提取是异步后台任务，期间用户可能继续发消息（新对话产生新记忆）
///   - 写回时必须**安全合并**而非直接覆盖：
///     - 提取期间 history 长度未变 → 直接采用提取结果
///     - 长度变化（有新对话）→ 以「当前 memories」为基底，仅将新提取结果
///       中**当前不存在**的新条目追加到末尾
///   - 合并后若超过 [MemoryManager.maxLimit]，触发压缩
///     （低权重优先压缩/舍弃，高权重保护不丢）
library;

import '../../domain/models.dart';
import 'memory_manager.dart';

/// 单角色记忆提取输入
class MemoryExtractionInput {
  /// 该角色的历史条目（提取依据）
  final List<HistoryEntry> history;

  /// 该角色的当前记忆列表（提取后合并基底）
  final List<Memory> memories;

  /// 提取启动时的 history 长度（用于检测提取期间是否发生新对话）
  final int historyLengthAtStart;

  const MemoryExtractionInput({
    required this.history,
    required this.memories,
    required this.historyLengthAtStart,
  });
}

/// 记忆提取编排服务（轻量无状态，可全局复用单例）
///
/// 与 [MemoryManager] 的关系：
///   - [MemoryManager] 负责「单次提取/压缩」的纯逻辑（LLM 调用、权重解析、去重）
///   - 本服务负责「提取后的安全合并」编排逻辑（冲突检测、并发合并、压缩触发）
class MemoryExtractionService {
  const MemoryExtractionService();

  /// 单角色：执行记忆提取并安全合并且返回更新后的记忆。
  ///
  /// 参数：
  ///   - manager: [MemoryManager] 实例（提取/压缩的实际执行者）
  ///   - input: 提取输入（历史 + 当前记忆 + 起始行长度快照）
  ///   - config: LLM 配置（null 时使用默认值）
  ///
  /// 返回值：
  ///   - `null`：提取未触发 / 提取结果无变化 / 提取期间新对话导致无新增
  ///   - `List<Memory>`：安全合并后的新记忆列表
  Future<List<Memory>?> extractWithSafeMerge({
    required MemoryManager manager,
    required MemoryExtractionInput input,
    required LlmConfig? config,
  }) async {
    final updated = await manager.maybeExtract(
      history: input.history,
      memories: input.memories,
      config: config,
    );
    if (updated == null) return null;

    // 提取期间没有新对话 → 直接采用提取结果（无覆盖风险）
    if (input.history.length == input.historyLengthAtStart) {
      return updated;
    }

    // 提取期间有新对话 → 安全合并：
    // 以当前 memories 为基底，仅追加「新提取结果中当前不存在」的条目。
    // 利用 Memory 的 Equatable props（按 content 比较）判断是否已存在。
    final currentContents = input.memories.map((m) => m.content).toSet();
    final fresh = updated
        .where((m) => !currentContents.contains(m.content))
        .toList();
    if (fresh.isEmpty) return null; // 无新增条目，保持现状

    var combined = [...input.memories, ...fresh];
    // 遵循权重制取舍：合并后超限触发 compress（低权重优先压缩/舍弃，
    // 高权重保护不丢）——而非无脑追加导致列表膨胀失控
    if (combined.length > MemoryManager.maxLimit) {
      combined = await manager.compress(combined, config: config);
    }
    return combined;
  }
}