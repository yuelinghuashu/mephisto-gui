/// 舞台叙事状态管理器（多角色）
///
/// 管理多角色舞台的会话状态变化：
///   - 舞台加载：从舞台目录加载全部角色契约 + 各角色独立运行时状态
///   - 单轮生成：委托 [StageTurnService]（各角色规则引擎独立运行 + 单次 LLM +
///     分节解析），结果按角色分批写回
///   - 存档：各角色独立子版存档到舞台目录（`舞台/角色.child.meph`），完全复用
///     [SessionSaver] / [ChildSaveStore]（零 DSL 侵入）
///
/// 与 [NarrativeNotifier]（单角色）的关系：
///   - 两者完全独立，互不依赖；舞台 Notifier 不复用单角色状态机
///   - 状态迁移统一走 [stageNarrativeReducer]（纯函数）
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/narrative_error.dart';
import '../domain/stage_models.dart';
import '../domain/stage_narrative_event.dart';
import '../domain/stage_narrative_reducer.dart';
import '../domain/stage_narrative_state.dart';
import '../services/memory/memory_manager.dart';
import '../services/session/child_save_store.dart';
import '../services/stage_turn_service.dart';
import '../services/storage/meph_file_name.dart' as meph_file_name;
import '../services/storage/stage_repo.dart' as stage_repo;
import 'generation_coordinator.dart';
import 'generation_settings_provider.dart';
import 'llm_settings_provider.dart';
import 'narrative_provider.dart';
import 'streaming_coordinator.dart';

/// 舞台叙事状态管理器
class StageNarrativeNotifier extends Notifier<StageNarrativeState>
    with GenerationCoordinator<StageNarrativeState>, StreamingCoordinator {
  /// 流式内容写回状态（StreamingCoordinator 钩子）。
  @override
  void applyStreamingContent(String fullContent) {
    // 已 dispose（Notifier 重建/销毁）后不再写状态（同单角色版守卫）
    if (isGenerationDisposed) return;
    state = state.copyWith(streamingContent: fullContent);
  }

  /// 舞台加载请求版本号（用于竞态保护）
  ///
  /// `loadStage` 是异步的：用户快速切换舞台时，旧请求的 Future 完成较慢，
  /// 若其 dispatch 晚于新请求，会覆盖新舞台的状态。每发起一次加载
  /// 递增此版本号，dispatch 前校验仍是当前版本，否则丢弃过期结果。
  int _loadRequestId = 0;

  /// 状态迁移统一走 [stageNarrativeReducer]
  void _dispatch(StageNarrativeEvent event) {
    state = stageNarrativeReducer(state, event);
  }

  @override
  StageNarrativeState build() {
    ref.onDispose(() {
      disposeStreaming();
      disposeGeneration();
    });
    return const StageNarrativeState();
  }

  /// 加载舞台：从舞台目录加载全部角色；默认恢复各角色存档（若有）。
  ///
  /// 成功后返回 true；舞台目录不存在/无角色时返回 false 并设置错误。
  ///
  /// [restoreSaves] 为 false 时跳过存档恢复，直接进入母版角色卡的开局
  /// （「重新开始」语义：用户不想续玩已有存档，而是干净地从母版开场）。
  /// 首页舞台卡片主体点击（续玩）默认 true；「重新开始」菜单传 false。
  ///
  /// [skipRestoreRoles] 用于「按角色选择母版/子版」的能力：传入角色名
  /// 集合时，集合内的角色**跳过存档恢复**（从母版干净开局），其余角色
  /// 仍恢复各自存档（续玩）。传 null 视为全部角色按 [restoreSaves] 统一处理。
  /// 首页舞台卡展开区点击某角色「母版行」时传 `{roleName}`，实现：
  /// 被点角色从母版整合、其余角色继续用各自存档——即「把相应文件整合在一起」。
  ///
  /// **竞态保护**：本方法内部带「请求版本号」校验——若在本次加载完成前
  /// 又发起了新一次 [loadStage]，旧结果会被丢弃（返回 false 但不污染状态）。
  Future<bool> loadStage(
    String dirPath, {
    bool restoreSaves = true,
    Set<String>? skipRestoreRoles,
  }) async {
    // 记录本次请求的版本号；后续若检测到更高版本说明已有新加载在途
    final requestId = ++_loadRequestId;

    final loaded = await stage_repo.loadStage(dirPath);
    if (loaded == null) {
      if (requestId == _loadRequestId) {
        state = state.copyWith(lastError: narrativeErrorGenFailed);
      }
      return false;
    }

    final stage = loaded;
    final stagePath = dirPath;

    // 构建各角色初始状态（从契约 stateMap 起步）
    final initialStates = <String, Map<String, StateValue>>{};
    for (final character in stage.characters) {
      initialStates[character.roleName] = character.contract.stateMap;
    }

    // 尝试恢复各角色独立存档（舞台/角色.child.meph）。
    // restoreSaves=false（重新开始）时跳过恢复 → restoredByRole 为空 → 自然进入母版开局。
    // skipRestoreRoles 非空时：集合内角色跳过恢复（从母版开局），其余角色恢复存档。
    // 并发执行：各角色存档恢复互不依赖，串行 IO 会随角色数线性增加等待
    //（5 角色舞台最多可减少约 4 次磁盘读取往返）。结果按角色名归位。
    final restoredByRole = restoreSaves
        ? await _restoreRoleSaves(
            stage,
            dirPath: stagePath,
            skipRestoreRoles: skipRestoreRoles,
          )
        : const <String, Contract>{};

    // 竞态保护：加载期间已有新请求 → 丢弃本次过期结果
    if (requestId != _loadRequestId) return false;

    // 若任何角色有存档 → 使用恢复的会话（各角色动态数据从子版加载）
    // 否则直接使用角色契约初始状态进入空会话
    if (restoredByRole.isNotEmpty) {
      // 用恢复的契约替换角色卡（保留文件名映射）
      final recoveredCharacters = stage.characters.map((c) {
        final restored = restoredByRole[c.roleName];
        return StageCharacter(
          fileName: c.fileName,
          contract: restored ?? c.contract,
        );
      }).toList();
      final recoveredStage = StageLoaded(
        info: stage.info,
        characters: recoveredCharacters,
      );
      _dispatch(
        StageLoadedEvent(
          stage: recoveredStage,
          stagePath: stagePath,
          initialStates: {
            for (final c in recoveredCharacters)
              c.roleName: c.contract.stateMap,
          },
        ),
      );
    } else {
      _dispatch(
        StageLoadedEvent(
          stage: stage,
          stagePath: stagePath,
          initialStates: initialStates,
        ),
      );
    }
    return true;
  }

  /// 发送消息（用户输入 → 舞台叙事推进）。
  ///
  /// 全局兜底：任何未预期异常都必须复位同步标志位，避免 UI 永久卡在「生成中」
  /// （复用 [GenerationCoordinator] 的防重入与取消编排 + [runGeneration] 收尾）。
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    if (!canSend(isGenerating: state.isGenerating)) return;

    beginGeneration();

    // 新一轮生成：清空流式累积器 + 复位「显示全文」标志，
    // 避免旧一轮的跳过打字机状态泄漏到新一轮（StreamingCoordinator）
    resetStreamingForNewRound();

    _dispatch(StageMessageSent(content.trim()));

    await runGeneration(
      userInput: content.trim(),
      core: _generateCore,
      // 生成失败：flush 流式缓冲 + 重置生成状态（走 reducer）
      onFailure: () {
        flushStreamBuffer();
        _dispatch(const StageGenerationFailed(narrativeErrorGenFailed));
      },
      onError: (e, st) => debugPrint('舞台生成回复异常: $e\n$st'),
    );
  }

  /// 停止生成时 flush 流式缓冲（GenerationCoordinator 钩子）。
  @override
  void onGenerationStop() {
    flushStreamBuffer();
  }

  /// 生成舞台回复（委托 [StageTurnService]，结果按角色写回状态）。
  Future<void> _generateCore(String userInput) async {
    final service = ref.read(stageTurnServiceProvider);
    // 统一读取生成所需配置（配置变更后 force refresh 确保拿到最新值）
    final settings = await ref.refresh(generationSettingsProvider.future);

    final stage = state.stage;
    if (stage == null) {
      _dispatch(const StageGenerationFailed(narrativeErrorGenFailed));
      return;
    }

    // 组装各角色当前运行时状态/记忆
    final roleStates = <String, Map<String, StateValue>>{
      for (final entry in state.roles.entries)
        entry.key: entry.value.currentState,
    };
    final roleMemories = <String, List<Memory>>{
      for (final entry in state.roles.entries) entry.key: entry.value.memories,
    };

    final result = await service.generate(
      userInput: userInput,
      stage: stage,
      roleStates: roleStates,
      roleMemories: roleMemories,
      // 历史消息 = 除去最后一条（本次命运指引）的所有消息。
      // 与单角色版一致：正常流程中 [_dispatch(StageMessageSent)] 已先追加
      // 用户消息，若此处传全量会与下方 `userInput` 重复出现两次。
      historyMessages: state.messages.length > 1
          ? state.messages.take(state.messages.length - 1).toList()
          : const [],
      attachedContexts: state.attachedContexts,
      narrativeRules: settings.narrativeRules,
      config: settings.llmConfig,
      onChunk: appendStreamChunk,
      cancelSignal: generationCancelSignal,
      maxHistoryMessages: settings.maxHistoryMessages,
      maxMemories: settings.maxMemories,
    );

    flushStreamBuffer();

    _dispatch(
      StageReplySucceeded(
        replies: result.replies,
        newStates: result.newStates,
        injectedMemories: result.injectedMemories,
        overflow: result.overflow,
        rollInfo: result.rollInfo,
        diceResults: result.diceResults,
        lastError: result.lastError,
      ),
    );

    // 自动保存：各角色独立存档到舞台目录
    await _autoSaveStage();
    // 异步记忆提取：各角色历史中命运+其段落均可自动摘记；
    // 用 unawaited 不阻塞下一轮发送（对齐单角色版 `_maybeExtractMemories` 语义）
    unawaited(
      _maybeExtractStageMemories(
        config: settings.llmConfig,
        auxConfig: settings.auxLlmConfig,
      ),
    );
  }

  /// 为每个角色执行记忆提取（对齐单角色版的 [_maybeExtractMemories] 语义）。
  ///
  /// **批量提取优化**：所有候选角色合并为**单次 LLM 调用**提取记忆
  /// （通过 [MemoryManager.extractForRoles]），而非每个角色独立调用
  /// LLM（N 次调用）——5 角色舞台最多减少 4 次 LLM 往返的等待时间。
  ///
  /// **安全合并**：提取是异步后台任务，期间用户可能继续发消息（新对话产生
  /// 新记忆/规则注入新记忆）。与单角色版相同的取舍：
  ///   - 提取期间该角色 history 长度未变 → 直接追加提取结果
  ///   - 长度变化（有新对话）→ 以「当前 memories」为基底，仅将新提取结果
  ///     中**当前不存在**的新条目追加到末尾——保证新记忆不被旧结果覆盖
  ///   - 合并后若超过上限，触发压缩（高权重记忆保护不丢）
  Future<void> _maybeExtractStageMemories({
    LlmConfig? config,
    LlmAuxConfig? auxConfig,
  }) async {
    final stage = state.stage;
    if (stage == null) return;
    final manager = ref.read(memoryManagerProvider);
    final effectiveConfig = config ?? const LlmConfig();

    // 只对「有历史且到达提取间隔」的角色发起记忆提取
    final candidates = stage.characters.where((c) {
      final role = state.roles[c.roleName];
      if (role == null) return false;
      final round = role.history
          .where((h) => h.role == MessageRole.fate)
          .length;
      return round > 0 && round % MemoryManager.extractInterval == 0;
    }).toList();
    if (candidates.isEmpty) return;

    // 并发前快照每个候选角色的 history 长度（用于检测提取期间是否发生新对话）
    final historyLengthsAtStart = <String, int>{
      for (final c in candidates)
        c.roleName: state.roles[c.roleName]!.history.length,
    };
    final roleHistory = <String, List<HistoryEntry>>{
      for (final c in candidates) c.roleName: state.roles[c.roleName]!.history,
    };
    final roleMemories = <String, List<Memory>>{
      for (final c in candidates) c.roleName: state.roles[c.roleName]!.memories,
    };

    // 批量提取：单次 LLM 调用为所有候选角色提取记忆
    //（N 次独立调用 → 1 次批量调用，5 角色舞台最多减少 4 次 LLM 往返）
    final extracted = await manager.extractForRoles(
      roleHistory: roleHistory,
      roleMemories: roleMemories,
      config: effectiveConfig,
      auxConfig: auxConfig,
    );
    if (extracted.isEmpty) return;

    // 安全合并写回：提取期间若新对话产生（history 长度变化），
    // 以「当前 memories」为基底仅追加新提取结果中不存在的条目；
    // 无新对话时直接采用提取结果。合并后超限触发压缩。
    var roles = Map<String, RoleRunState>.from(state.roles);
    var hasChanges = false;
    for (final entry in extracted.entries) {
      final roleName = entry.key;
      final role = roles[roleName];
      if (role == null) continue;
      final newMemories = entry.value;
      if (newMemories.isEmpty) continue;

      final currentMemories = role.memories;
      List<Memory> updated;
      // 提取期间无新对话 → 直接追加新记忆
      if (role.history.length == (historyLengthsAtStart[roleName] ?? 0)) {
        updated = [...currentMemories, ...newMemories];
      } else {
        // 有新对话 → 以当前 memories 为基底，追加不存在的新条目
        final existingContents = currentMemories.map((m) => m.content).toSet();
        final fresh = newMemories
            .where((m) => !existingContents.contains(m.content))
            .toList();
        if (fresh.isEmpty) continue;
        updated = [...currentMemories, ...fresh];
      }
      // 超过上限触发压缩（与单角色版一致）
      if (updated.length > MemoryManager.maxLimit) {
        updated = await manager.compress(
          updated,
          config: effectiveConfig,
          auxConfig: auxConfig,
        );
      }
      if (updated.length == currentMemories.length) continue;
      roles[roleName] = role.copyWith(memories: updated);
      hasChanges = true;
    }
    if (!hasChanges) return;

    state = state.copyWith(roles: roles);
    await _autoSaveStage();
  }

  /// 自动保存各角色子版到舞台目录（`舞台/角色.child.meph`）。
  ///
  /// 完全复用 [SessionSaver.save]：为每个角色序列化其独立快照。
  ///
  /// **并发优化**：各角色保存互不依赖（各自独立快照/文件路径），
  /// 因此使用 [Future.wait] 并发执行——5 角色舞台最多可减少约 4 次
  /// 磁盘写入的串行等待。每个角色的保存独立 try-catch，
  /// 单个角色失败不影响其余角色完成。
  Future<void> _autoSaveStage() async {
    final stage = state.stage;
    if (stage == null) return;

    final stageDir = stage.info.path;
    await Future.wait(
      stage.characters.map((character) async {
        final roleName = character.roleName;
        final role = state.roles[roleName];
        if (role == null) return;

        try {
          await ChildSaveStore.save(
            character.fileName,
            character.contract,
            currentState: role.currentState,
            memories: role.memories,
            history: role.history,
            // 舞台目录直接覆盖（不递增）
            overwriteFileName: defaultChildFileName(character.fileName),
            targetDir: Directory(stageDir),
          );
        } catch (e) {
          debugPrint('舞台角色存档失败: $stageDir/${character.fileName} ($e)');
          state = state.copyWith(lastError: narrativeErrorAutoSaveFail);
        }
      }),
    );
  }

  /// 并发恢复各角色存档（`舞台/角色.child.meph`），返回「角色名 → 恢复的契约」。
  ///
  /// 被 [loadStage]（自动恢复）与 [restoreStage]（显式恢复）共用，
  /// 收敛两处的并发恢复逻辑。
  ///
  /// **并发优化**：各角色存档恢复互不依赖（各自独立文件路径），
  /// 因此使用 [Future.wait] 并发执行——5 角色舞台最多可减少约 4 次
  /// 磁盘读取的串行等待。结果按角色名归位。
  ///
  /// [skipRestoreRoles] 非空时：集合内角色跳过恢复（从母版开局），
  /// 其余角色恢复各自存档。传 null 视为全部角色统一恢复。
  Future<Map<String, Contract>> _restoreRoleSaves(
    StageLoaded stage, {
    String? dirPath,
    Set<String>? skipRestoreRoles,
  }) async {
    final restoredByRole = <String, Contract>{};
    final restoredList = await Future.wait(
      stage.characters.map((character) async {
        // 该角色被指定从母版开局 → 不恢复存档
        if (skipRestoreRoles != null &&
            skipRestoreRoles.contains(character.roleName)) {
          return (roleName: character.roleName, restored: null);
        }
        final restored = await ChildSaveStore.restore(
          defaultChildFileName(character.fileName),
          dirPath: dirPath ?? stage.info.path,
        );
        return (roleName: character.roleName, restored: restored);
      }),
    );
    for (final r in restoredList) {
      if (r.restored != null) restoredByRole[r.roleName] = r.restored!;
    }
    return restoredByRole;
  }

  /// 恢复各角色存档（显式调用；loadStage 已自动恢复，通常无需手动）。
  ///
  /// 存档恢复逻辑复用 [_restoreRoleSaves]（并发 + skipRestoreRoles 语义一致）。
  Future<bool> restoreStage() async {
    final stage = state.stage;
    if (stage == null) return false;

    final restoredByRole = await _restoreRoleSaves(stage);
    if (restoredByRole.isEmpty) return false;

    // 重建共享消息流：取各角色中最长的历史重建（history 最长的角色通常
    // 拥有最完整的戏份历史——与 [_onStageLoaded] 语义对齐，避免旧存档
    // 历史残缺时只取第一个角色导致丢记录）
    final longestHistory = restoredByRole.values
        .map((c) => c.history)
        .reduce((a, b) => a.length >= b.length ? a : b);
    _dispatch(
      StageSessionRestored(
        restoredByRole: restoredByRole,
        messages: stageHistoryToMessages(longestHistory),
      ),
    );
    return true;
  }

  /// 附加上下文（会话级，支持多选追加）。
  void attachContext(String fileName, String content) {
    _dispatch(StageContextAttached(fileName: fileName, content: content));
  }

  /// 移除指定索引的附加上下文。
  void removeAttachedContext(int index) {
    _dispatch(StageContextRemoved(index));
  }

  /// 重置会话（保留舞台，清空动态数据）。
  void resetSession() {
    _dispatch(const StageSessionReset());
  }

  /// 构造默认子版文件名（`浮士德.meph` → `浮士德.child.meph`；
  /// `faust.dark.meph` → `faust.dark.child.meph`）。
  ///
  /// 委托共享工具 [meph_file_name.defaultChildFileName]（与
  /// [NarrativeNotifier] 完全一致，为唯一实现）。
  static String defaultChildFileName(String masterFileName) =>
      meph_file_name.defaultChildFileName(masterFileName);
}

// ============================================================
// Provider 定义
// ============================================================

/// 舞台单轮叙事生成服务 Provider（复用单角色版的 HTTP 连接池）
final stageTurnServiceProvider = Provider<StageTurnService>((ref) {
  return StageTurnService(client: ref.watch(httpClientProvider));
});

/// 舞台叙事状态 Provider
final stageNarrativeProvider =
    NotifierProvider<StageNarrativeNotifier, StageNarrativeState>(
      StageNarrativeNotifier.new,
    );
