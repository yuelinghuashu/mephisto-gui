/// 子版存档存储：基于 .meph 文件的母版/子版机制
///
/// 母版文件（如 faust.meph）永不改动。
/// 运行时产生对话后，生成子版文件（如 faust.child.meph）保存完整快照：
///   子版 = 母版全部数据 + 运行时状态变化 + 记忆 + 历史
///
/// 命名规则：
///   默认保存：`faust.child.meph`
///   已有同名：`faust.child2.meph`（自动递增序号）
///   自定义分支：`faust.dark.meph` / `faust.light.meph`（用户在 UI 输入分支名）
///
/// 子版与母版存放在同一目录（用户默认或自定义的契约目录），便于查找。
library;

import 'dart:io';

import '../../domain/models.dart';
import '../parser/meph_parser.dart';
import '../parser/meph_serializer.dart';
import '../storage/contract_dir.dart';
import '../storage/meph_file_name.dart';

/// 子版存档文件名（`faust.meph` → `faust.child.meph`）的快捷别名。
///
/// 与旧 [SessionSaver] 语义一致——默认存档属于「当前分支路径 + `.child`」。
String childSaveFileName(String sourceFileName) =>
    defaultChildFileName(stripChildSuffix(sourceFileName));

/// 子版存档存储
class ChildSaveStore {
  /// 保存当前会话为子版文件。
  ///
  /// 参数：
  ///   - masterFileName: 母版文件名（如 `faust.meph`，决定子版基础名）
  ///   - contract: 母版契约
  ///   - currentState: 运行时状态
  ///   - memories: 运行时记忆
  ///   - history: 运行时历史
  ///   - branchName: 可选自定义分支名（如 'dark'）；null 时使用默认 `.child`
  ///   - branchTitle: 可选「命运一句话」（用户另存为分支时填写），
  ///     以 `@命运:` 标记注入【角色背景】区块；null 时不注入
  ///   - targetDir: 目标目录（舞台场景下为舞台目录）；
  ///     null 时使用全局契约目录（向后兼容）
  ///
  /// 返回值：保存的子版文件名（如 `faust.child.meph` 或 `faust.dark.meph`）
  static Future<String> save(
    String masterFileName,
    Contract contract, {
    required Map<String, StateValue> currentState,
    required List<Memory> memories,
    required List<HistoryEntry> history,
    String? branchName,
    String? branchTitle,
    String? overwriteFileName,
    Directory? targetDir,
  }) async {
    final dir = targetDir ?? await getContractsDirectory();
    final baseName = masterFileName.replaceAll('.meph', '');

    // overwriteFileName 提供时直接覆盖（已存在子版时在原文件上修改）；
    // 否则按 .child / 递增 / 分支名 生成新文件。
    // 一次性列出目录中所有 .meph 文件名后在内存中判断，
    // 避免 _resolveFileName 中多次同步磁盘 existsSync() 检查。
    final fileName =
        overwriteFileName ?? await _resolveFileName(dir, baseName, branchName);

    // branchTitle 非空时 serializer 输出 @命运 区块
    final effectiveContract =
        (branchTitle != null && branchTitle.trim().isNotEmpty)
        ? contract.copyWith(branchTitle: branchTitle.trim())
        : contract;

    final content = serializeMeph(
      effectiveContract,
      runtimeState: currentState,
      memories: memories,
      history: history,
    );

    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    return fileName;
  }

  /// 保存当前会话的**默认存档**（`.child`），每个分支有自己的存档。
  ///
  /// 多级树模型下，存档命名规则为「当前分支路径 + `.child`」：
  ///   - 母版 `faust.meph`          → `faust.child.meph`（递增：child2 / child3 …）
  ///   - 分支 `faust.dark.meph`     → `faust.dark.child.meph`（递增：child2 / child3 …）
  ///   - 二级分支 `faust.dark.light.meph` → `faust.dark.light.child.meph`（递增）
  ///   - 若已打开存档自身（`faust.dark.child.meph`）→ 覆盖它自己（同一轮会话不膨胀）
  ///
  /// 区分两种语义：
  ///   - **从母版/分支重新开始**（每次首页打开）→ 递增序号生成新存档，
  ///     避免 `faust.child.meph` 被新一轮游玩直接覆盖导致旧进度丢失。
  ///   - **已在存档内继续对话**（存档自身是 `.child` 结尾）→ 覆盖自己，
  ///     同一轮会话内连续自动保存不产生多余文件。
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
    final branchPath = stripChildSuffix(sourceFileName);

    // 当前打开的是存档自身（`.child` 或 `.childN` 结尾）→ 覆盖它自己，
    // 保持同一轮会话内数量不膨胀。
    if (_isSaveFileName(sourceFileName)) {
      return save(
        branchPath,
        contract,
        currentState: currentState,
        memories: memories,
        history: history,
        overwriteFileName: sourceFileName,
      );
    }

    // 当前打开的是母版根/分支（faust.meph / faust.dark.meph）→
    // 不传 overwriteFileName，由 _resolveFileName 自动递增：
    //   faust.child.meph → faust.child2.meph → faust.child3.meph …
    return save(
      branchPath,
      contract,
      currentState: currentState,
      memories: memories,
      history: history,
    );
  }

  /// 判断文件名是否为「存档文件」（`.child` 或递增存档 `.childN`）。
  ///
  ///   - `faust.child.meph`    → true（默认存档）
  ///   - `faust.child2.meph`   → true（递增存档）
  ///   - `faust.dark.child.meph` → true（dark 分支的存档）
  ///   - `faust.meph`          → false（母版根）
  ///   - `faust.dark.meph`     → false（自定义分支）
  static bool _isSaveFileName(String fileName) {
    final lastSegment = splitBaseName(fileName).last;
    if (lastSegment == 'child') return true;
    // child2 / child3 / child10 …（递增存档变体）
    if (lastSegment.startsWith('child') &&
        int.tryParse(lastSegment.substring('child'.length)) != null) {
      return true;
    }
    return false;
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
    final branchPath = stripChildSuffix(sourceFileName);
    return save(
      branchPath,
      contract,
      currentState: currentState,
      memories: memories,
      history: history,
      branchName: branchName,
      branchTitle: branchTitle,
    );
  }

  /// 从子版文件恢复会话。
  ///
  /// 参数：
  ///   - fileName: 子版文件名（如 `faust.child.meph`）
  ///
  /// 返回值：恢复的完整契约（含运行时状态/记忆/历史）；失败返回 null
  static Future<Contract?> restore(String fileName, {String? dirPath}) async {
    final dir = dirPath != null
        ? Directory(dirPath)
        : await getContractsDirectory();
    final file = File('${dir.path}/$fileName');
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      return parseMeph(content);
    } catch (e) {
      // 子版解析失败视为不可恢复（可能是用户手动编辑错误）
      return null;
    }
  }

  /// 列出指定母版的所有子版文件。
  ///
  /// 参数：
  ///   - masterFileName: 母版文件名（如 `faust.meph`）
  ///
  /// 返回值：子版文件名列表（如 `['faust.child.meph', 'faust.dark.meph']`）
  static Future<List<String>> listChildFiles(
    String masterFileName, {
    String? dirPath,
  }) async {
    final dir = dirPath != null
        ? Directory(dirPath)
        : await getContractsDirectory();
    final baseName = masterFileName.replaceAll('.meph', '');

    // 匹配 `baseName.*.meph` 且排除母版本身（复用共享的目录扫描工具）
    final allNames = await listMephFileNames(dir);
    return allNames
        .where((name) => name != masterFileName)
        .where((name) => name.startsWith('$baseName.'))
        .toList();
  }

  /// 删除子版文件。
  ///
  /// [dirPath] 指定所在目录（舞台场景下为舞台目录）；null 时使用全局契约目录。
  static Future<bool> delete(String fileName, {String? dirPath}) async {
    final dir = dirPath != null
        ? Directory(dirPath)
        : await getContractsDirectory();
    final file = File('${dir.path}/$fileName');
    if (!await file.exists()) return false;
    try {
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 检查子版文件是否存在。
  ///
  /// [dirPath] 指定所在目录（舞台场景下为舞台目录）；null 时使用全局契约目录。
  static Future<bool> exists(String fileName, {String? dirPath}) async {
    final dir = dirPath != null
        ? Directory(dirPath)
        : await getContractsDirectory();
    return File('${dir.path}/$fileName').exists();
  }

  /// 解析目标文件名：
  ///   - branchName 为空：使用 `baseName.child.meph`，若已存在则 `baseName.child2.meph` 递增
  ///   - branchName 非空：使用 `baseName.branchName.meph`，若已存在则追加序号 `baseName.branchName2.meph`
  ///
  /// 优化：一次性列出目录中所有 .meph 文件名后在内存中判断，
  /// 避免多次同步磁盘 `existsSync()` 检查（文件多时显著减少 I/O）。
  static Future<String> _resolveFileName(
    Directory dir,
    String baseName,
    String? branchName,
  ) async {
    // 引用共享顶层常量 `defaultChildSuffix`（meph_file_name.dart）
    final suffix = branchName == null || branchName.isEmpty
        ? defaultChildSuffix
        : '.${branchName.trim()}';

    // 批量列出所有 .meph 文件名，内存 Set 中去重判断（比循环磁盘检查快）
    final existingNames = (await listMephFileNames(dir)).toSet();

    var fileName = '$baseName$suffix.meph';
    var counter = 2;
    while (existingNames.contains(fileName)) {
      fileName = '$baseName$suffix$counter.meph';
      counter++;
    }
    return fileName;
  }
}
