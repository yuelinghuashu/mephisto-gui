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

/// 子版存档存储
class ChildSaveStore {
  /// 默认子版后缀（母版名 + `.child`）
  static const String defaultChildSuffix = '.child';

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
  }) async {
    final dir = await getContractsDirectory();
    final baseName = masterFileName.replaceAll('.meph', '');

    // overwriteFileName 提供时直接覆盖（已存在子版时在原文件上修改）；
    // 否则按 .child / 递增 / 分支名 生成新文件。
    // 一次性列出目录中所有 .meph 文件名后在内存中判断，
    // 避免 _resolveFileName 中多次同步磁盘 existsSync() 检查。
    final fileName = overwriteFileName ??
        await _resolveFileName(dir, baseName, branchName);

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

  /// 从子版文件恢复会话。
  ///
  /// 参数：
  ///   - fileName: 子版文件名（如 `faust.child.meph`）
  ///
  /// 返回值：恢复的完整契约（含运行时状态/记忆/历史）；失败返回 null
  static Future<Contract?> restore(String fileName) async {
    final dir = await getContractsDirectory();
    final file = File('${dir.path}/$fileName');
    if (!file.existsSync()) return null;

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
  static Future<List<String>> listChildFiles(String masterFileName) async {
    final dir = await getContractsDirectory();
    final baseName = masterFileName.replaceAll('.meph', '');

    // 匹配 `baseName.*.meph` 且排除母版本身（复用共享的目录扫描工具）
    final allNames = await listMephFileNames(dir);
    return allNames
        .where((name) => name != masterFileName)
        .where((name) => name.startsWith('$baseName.'))
        .toList();
  }

  /// 删除子版文件。
  static Future<bool> delete(String fileName) async {
    final dir = await getContractsDirectory();
    final file = File('${dir.path}/$fileName');
    if (!file.existsSync()) return false;
    try {
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 检查子版文件是否存在。
  static Future<bool> exists(String fileName) async {
    final dir = await getContractsDirectory();
    return File('${dir.path}/$fileName').existsSync();
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