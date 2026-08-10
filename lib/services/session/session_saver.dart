/// 会话存档服务：将叙事会话快照保存为子版 .meph 文件。
///
/// [NarrativeNotifier] 中的存档执行逻辑抽为纯函数类，参数化完整的会话快照，
/// 不依赖 Riverpod / UI 框架 —— 未来多角色舞台可对任意角色的快照复用本服务，
/// 且可脱离框架直接单元测试。
library;

import 'dart:io';

import '../../domain/models.dart';
import '../storage/meph_file_name.dart';
import 'child_save_store.dart';

/// 会话存档服务
class SessionSaver {
  /// 保存会话快照为子版文件（失败时抛异常，由调用方决定错误处理）。
  ///
  /// - [branchName]：null 时使用默认 `.child`
  /// - [branchTitle]：以 `@命运:` 标记注入子版【角色背景】
  /// - [overwriteFileName]：直接覆盖的文件名（已存在子版时传入）
  /// - [targetDir]：目标目录（舞台场景下为舞台目录 `舞台/`）；
  ///   null 时使用全局契约目录（向后兼容）
  static Future<String> save({
    required String masterFileName,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<HistoryEntry> history,
    String? branchName,
    String? branchTitle,
    String? overwriteFileName,
    Directory? targetDir,
  }) {
    return ChildSaveStore.save(
      masterFileName,
      contract,
      currentState: currentState,
      memories: memories,
      history: history,
      branchName: branchName,
      branchTitle: branchTitle,
      overwriteFileName: overwriteFileName,
      targetDir: targetDir,
    );
  }

  /// 保存当前会话的**默认存档**（`.child`），决策 B：每个分支有自己的存档。
  ///
  /// 多级树模型下，存档命名规则为「当前分支路径 + `.child`」：
  ///   - 母版 `faust.meph`          → 覆盖 `faust.child.meph`
  ///   - 分支 `faust.dark.meph`     → 覆盖 `faust.dark.child.meph`
  ///   - 二级分支 `faust.dark.light.meph` → 覆盖 `faust.dark.light.child.meph`
  ///   - 若已打开存档自身（`faust.dark.child.meph`）→ 覆盖它自己
  ///
  /// 从不递增序号：每次保存都覆盖当前分支的默认存档，保证数量不膨胀。
  ///
  /// 参数：
  ///   - [sourceFileName]：当前打开的会话源文件（分支或存档）
  ///   - 其余为会话快照参数（与 [save] 一致）
  ///
  /// 返回值：保存的存档文件名。
  static Future<String> saveCurrent({
    required String sourceFileName,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<HistoryEntry> history,
  }) {
    // 计算「当前分支路径」（去掉 .child 存档尾段 / 文件名的层级前缀）：
    //   faust.meph            → faust
    //   faust.dark.meph       → faust.dark
    //   faust.dark.child.meph → faust.dark（存档属于 dark 分支）
    final branchPath = _stripChildSuffix(sourceFileName);
    // 默认存档名 = 分支路径 + .child.meph
    final defaultSaveName = '$branchPath.child.meph';
    return save(
      masterFileName: branchPath,
      contract: contract,
      currentState: currentState,
      memories: memories,
      history: history,
      // 总是覆盖当前分支的默认存档（不递增序号，保证数量不膨胀）
      overwriteFileName: defaultSaveName,
    );
  }

  /// 另存为分支：以**当前分支路径**为命名根 + [branchName] 生成新分支文件。
  ///
  /// 多级树模型下，从分支再另存会**继承派生路径**：
  ///   - 母版 `faust.meph`                  → 另存 `dark`   → `faust.dark.meph`
  ///   - 分支 `faust.dark.meph`             → 另存 `light`  → `faust.dark.light.meph`
  ///   - 二级分支 `faust.dark.light.meph`   → 另存 `utopia` → `faust.dark.light.utopia.meph`
  ///   - 存档 `faust.dark.child.meph`       → 另存 `light`  → `faust.dark.light.meph`（继承 dark）
  static Future<String> saveAsBranch({
    required String sourceFileName,
    required String branchName,
    String? branchTitle,
    required Contract contract,
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<HistoryEntry> history,
  }) {
    // 从「当前分支路径」派生（而非母版根），实现多级继承
    final branchPath = _stripChildSuffix(sourceFileName);
    return save(
      masterFileName: branchPath,
      contract: contract,
      currentState: currentState,
      memories: memories,
      history: history,
      branchName: branchName,
      branchTitle: branchTitle,
    );
  }

  /// 计算「当前分支路径」：去掉 `.child` 存档尾段后，提取层级前缀。
  ///
  /// 委托共享工具 [stripChildSuffix]，消除同名重复实现
  /// （此前两处逻辑完全一致但各自维护）。
  static String _stripChildSuffix(String sourceFileName) =>
      stripChildSuffix(sourceFileName);
}
