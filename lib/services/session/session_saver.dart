/// 会话存档服务：将叙事会话快照保存为子版 .meph 文件。
///
/// [NarrativeNotifier] 中的存档执行逻辑抽为纯函数类，参数化完整的会话快照，
/// 不依赖 Riverpod / UI 框架 —— 未来多角色舞台可对任意角色的快照复用本服务，
/// 且可脱离框架直接单元测试。
library;

import '../../domain/models.dart';
import '../storage/contract_repo.dart';
import 'child_save_store.dart';

/// 会话存档服务
class SessionSaver {
  /// 保存当前会话快照为子版文件。
  ///
  /// - [masterFileName]：母版文件名（决定子版基础名；`faust.meph` → `faust.*.meph`）
  /// - [contract]：母版契约
  /// - [currentState]：运行时状态
  /// - [memories]：运行时记忆
  /// - [history]：运行时历史
  /// - [branchName]：可选自定义分支名（如 'dark'）；null 时使用默认 `.child`
  /// - [overwriteFileName]：直接覆盖的文件名（已存在子版时传入）
  ///
  /// 返回值：保存的子版文件名；保存失败时抛异常（由调用方决定错误处理）。
  static Future<String> save({
    required String masterFileName,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<HistoryEntry> history,
    String? branchName,
    String? overwriteFileName,
  }) {
    return ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: currentState,
      memories: memories,
      history: history,
      branchName: branchName,
      overwriteFileName: overwriteFileName,
    );
  }

  /// 保存当前会话：已打开子版则直接覆盖原文件；母版则生成/递增 `.child` 子版。
  ///
  /// 将 [NarrativeNotifier] 中「子版覆盖 / 母版 .child 递增」的编排逻辑下沉到此，
  /// 统一「当前打开文件决定覆盖或新建」的决策。
  ///
  /// 参数：
  ///   - [sourceFileName]：当前打开的会话源文件（子版 → 覆盖；母版 → 新建 .child）
  ///   - 其余为会话快照参数（与 [save] 一致）
  ///
  /// 返回值：保存的子版文件名。
  static Future<String> saveCurrent({
    required String sourceFileName,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<HistoryEntry> history,
  }) {
    // 已打开的是子版 → 直接覆盖；否则按默认 .child 生成/递增
    final overwrite = isChildFileName(sourceFileName) ? sourceFileName : null;
    return save(
      masterFileName: sourceFileName,
      contract: contract,
      currentState: currentState,
      memories: memories,
      history: history,
      overwriteFileName: overwrite,
    );
  }

  /// 另存为分支：以母版基础名为 master + [branchName] 生成新分支文件。
  ///
  /// 与 [saveCurrent] 不同，本方法始终以「母版基础名」为命名根，
  /// 避免从子版（如 `faust.child.meph`）另存时错误地得到 `child.dark.meph`。
  ///
  /// 参数：
  ///   - [sourceFileName]：当前打开的会话源文件（仅用于提取母版前缀）
  ///   - [branchName]：自定义分支名（如 'dark'、'light'）
  ///   - 其余为会话快照参数（与 [save] 一致）
  ///
  /// 返回值：保存的分支文件名（如 `faust.dark.meph`）。
  static Future<String> saveAsBranch({
    required String sourceFileName,
    required String branchName,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<HistoryEntry> history,
  }) {
    return save(
      masterFileName: extractMasterPrefix(sourceFileName),
      contract: contract,
      currentState: currentState,
      memories: memories,
      history: history,
      branchName: branchName,
    );
  }
}