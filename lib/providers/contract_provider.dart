import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/narrative_error.dart';
import '../services/engine/condition.dart';
import '../services/parser/meph_parser.dart';
import '../services/storage/contract_dir.dart';
import '../services/storage/contract_repo.dart';
import '../services/storage/meph_file_name.dart';

/// 当前使用的契约文件名（存储在 shared_preferences）
const String contractPrefKey = 'mephisto_current_contract';

/// 默认契约名（用户目录中不存在任何契约时使用）
const String defaultContractName = 'faust.meph';

/// 契约树最大层级深度（母版根为 1）。
///
/// 用于 [contractGroupListProvider] 构建命运树时的递归深度守卫：
/// 超过此深度的文件名链会被截断为叶子节点，防止用户手动创建的超长
/// 层级链（如 `a.b.c.d.e.f...`）导致递归过深甚至栈溢出。
const int maxContractDepth = 8;

/// 契约兜底提示控制器。
///
/// 当 [contractProvider] 因用户契约文件缺失/损坏而回退到 assets 内置模板时，
/// 置为提示消息（UI 顶部提示条展示，避免用户误以为契约内容正确）；
/// 正常加载时为 null（不显示）。
class ContractFallbackNoticeController extends Notifier<String?> {
  @override
  String? build() => null;

  /// 更新兜底提示（null 表示无提示）。
  void setNotice(String? message) => state = message;
}

/// 契约兜底提示 Provider。
final contractFallbackNoticeProvider =
    NotifierProvider<ContractFallbackNoticeController, String?>(
  ContractFallbackNoticeController.new,
);

/// 当前使用的契约文件名 Provider（如 `faust.meph`）
///
/// 用于子版存档命名（`faust.meph` → `faust.child.meph`）。
final currentContractNameProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(contractPrefKey) ?? defaultContractName;
});

/// 契约 Provider：从用户 `contracts/` 目录加载 .meph 文件并解析为 [Contract]。
///
/// 加载流程：
///   1. 确保用户契约目录存在（首次启动时从 assets 复制内置模板）
///   2. 从 [SharedPreferences] 读取上次使用的契约名
///   3. 读取并解析该契约文件
///   4. 用户文件缺失或解析失败（如用户手动编辑引入语法错误）时，
///      回退到 assets 同名内置模板作为最后防线（[_builtinFallback]），
///      避免叙事页静默崩溃为 [Contract.empty]（「角色」空壳、无开局场景）。
///
/// 契约加载最终兜底：用户自定义契约（非内置模板名）缺失/损坏时，
/// 不抛异常进入 [AsyncError]（异常会引发 Notifier/UI watch 的复杂
/// error 处理时序），而是返回 [Contract.empty] 空契约 + 设置兜底提示。
///
/// 仅当用户文件与内置模板均不可用时才走到这条最终兜底。
final contractProvider = FutureProvider<Contract>((ref) async {
  // 1. 确保契约目录存在
  await ensureContracts();

  // 2. 读取当前契约名（默认为 faust.meph）
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString(contractPrefKey) ?? defaultContractName;

  // 3. 从用户目录读取并解析（解析失败 → 尝试内置模板兜底）
  final source = await readContract(name);
  if (source != null) {
    try {
      final contract = parseMeph(source);
      // 正常加载：清除兜底提示
      ref.read(contractFallbackNoticeProvider.notifier).setNotice(null);
      return contract;
    } catch (_) {
      // 用户文件存在但解析失败（语法错误）→ 落到内置模板兜底
    }
  }

  // 4. 回退到 assets 内置模板；仍不可用时返回空契约 + 兜底提示
  final fallback = await _builtinFallback(name);
  if (fallback != null) {
    // 已回退内置模板：置错误码提示，UI 顶部展示并翻译，
    // 避免用户误以为契约内容正确
    ref.read(contractFallbackNoticeProvider.notifier)
        .setNotice(narrativeErrorContractFallback);
    return fallback;
  }

  // 用户自定义契约（非内置模板名）缺失/损坏：
  //   - 不能静默替换成内置的浮士德契约（误导），因此不尝试内置兜底
  //   - 返回空契约（roleName: '角色'）保证叙事页不崩溃
  //   - 同步设置 fallback notice → 叙事页顶部警告条可见
  ref.read(contractFallbackNoticeProvider.notifier)
      .setNotice(narrativeErrorContractFallback);
  return Contract.empty();
});

/// 合法契约文件名的正则（字母、数字、中文、`.`、`_`、`-`）。
///
/// 用于 [_builtinFallback] 加载 assets 前校验，避免 SharedPreferences
/// 中的脏数据（如路径穿越 `..` 或非法字符）被拼接进 assets 加载路径。
final RegExp _contractNamePattern = RegExp(r'^[\u4e00-\u9fa5\w.-]+$');

/// 从 assets 加载同名内置模板作为兜底契约。
///
/// 仅当用户目录文件缺失/损坏时使用，保证顶级内置契约（faust / dantes）
/// 始终可进入叙事，避免回退为 [Contract.empty]（「角色」空壳、无开局场景）。
///
/// 仅在 [name] 恰好是内置模板名时兜底成功；用户自定义契约（非内置名）
/// 缺失时返回 null，由调用方（[contractProvider]）回落为 [Contract.empty]
/// 空契约 + 兜底提示——避免将用户的自定义契约引用静默替换成内置的
/// 浮士德契约（误导）。
Future<Contract?> _builtinFallback(String name) async {
  // 基础校验：非空 + 仅含合法文件名字符，避免脏数据进入 assets 路径
  if (name.isEmpty || !_contractNamePattern.hasMatch(name)) return null;

  String? content;
  try {
    content = await rootBundle.loadString('assets/contracts/$name');
  } catch (_) {
    // 无同名内置模板
  }
  if (content == null) return null;
  try {
    return parseMeph(content);
  } catch (_) {
    return null;
  }
}

/// 契约信息（文件名 + 角色名 + 是否子版）
class ContractInfo {
  /// 契约文件名（如 `faust.meph`、`faust.dark.meph`、`faust.dark.light.meph`）
  final String fileName;

  /// 契约角色名（从【角色名】区块解析；失败时回退为文件名去扩展名）
  final String roleName;

  /// 是否为子版文件（母版根之外还有路径段）
  ///
  /// 子版 = 母版 + 运行时对话/状态/记忆/历史，是存档快照或分支。
  final bool isChild;

  /// 子版的分支名（取路径最后一段；如 `child`、`dark`、`light`）
  final String? branchName;

  /// 子版「命运一句话」（用户另存为分支时填写，取自子版【角色背景】的 `@命运:` 标记）
  ///
  /// 用于首页展示更可读的支流描述；未填写时为 null，首页回落为显示 [branchName]。
  final String? branchTitle;

  /// 文件最后修改时间（用于首页按「最近编辑」排序最近使用的契约）。
  ///
  /// 取整棵子树的最大 mtime（含子版）：自动保存/编辑子版时，
  /// 母版卡片应反映整棵命运树的最新活动时间。
  /// null 表示未知（文件不存在或读取失败），排序时视为最旧。
  final DateTime? lastModified;

  /// 该文件所属的层级深度（母版根为 0，一级子版为 1，二级为 2 …）
  ///
  /// 首次访问时计算并缓存，避免 UI 渲染期间对同一节点反复执行
  /// `replaceAll + split` 的字符串开销。
  late final int depth = _computeDepth(fileName);

  ContractInfo({
    required this.fileName,
    required this.roleName,
    this.isChild = false,
    this.branchName,
    this.branchTitle,
    this.lastModified,
  });

  /// 从文件名计算层级深度：`faust.meph` → 0，`faust.dark.meph` → 1。
  static int _computeDepth(String fileName) =>
      fileName.replaceAll('.meph', '').split('.').length - 1;
}

/// 契约分组：一个节点（母版或子版）+ 其下所有子节点
///
/// 多级树模型：通过层级文件名（`.` 分段）表达派生链，
/// `children` 是**递归的同构节点列表**（而非平级信息）：
///
/// ```
/// ContractGroup(master: faust)                          // 母版根
/// ├─ ContractGroup(master: faust.dark)                  // 一级分支
/// │   └─ ContractGroup(master: faust.dark.light)        // 二级分支
/// └─ ContractGroup(master: faust.child)                 // 默认存档（一级）
/// ```
class ContractGroup {
  /// 当前节点契约（母版或子版）
  final ContractInfo master;

  /// 该节点下的子节点（递归：每个也是 ContractGroup）
  final List<ContractGroup> children;

  const ContractGroup({required this.master, required this.children});

  /// 直接子节点数量
  int get childCount => children.length;

  /// 是否有直接子节点
  bool get hasChildren => children.isNotEmpty;

  /// 递归统计整棵子树的总节点数（含自身）
  int get totalCount =>
      1 + children.fold<int>(0, (sum, c) => sum + c.totalCount);

  /// 递归收集整棵子树的所有契约信息（含自身，深度优先）
  List<ContractInfo> get allInfos =>
      [master, ...children.expand((c) => c.allInfos)];

  /// 该节点所处的层级深度（母版根为 0，一级子版为 1 …）
  int get depth => master.depth;

  /// 整棵子树的最近编辑时间（含自身与所有后代的最大 [ContractInfo.lastModified]）。
  ///
  /// 用于首页按「最近编辑」对顶级母版树排序：自动保存/编辑子版时，
  /// 母版卡片应反映整棵命运树的最新活动时间。
  /// null 表示整棵子树均无可用 mtime（此时按签名顺序兜底）。
  DateTime? get latestModified {
    final candidates = <DateTime>[
      if (master.lastModified != null) master.lastModified!,
      for (final child in children)
        if (child.latestModified != null) child.latestModified!,
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

/// 契约分组列表 Provider：按「层级路径」构建多级递归树
///
/// 返回 [[ContractGroup]] 列表，每个根节点是一份母版契约及其「命运树」：
/// ```
/// faust.meph → ContractGroup(faust)
///   ├─ faust.dark.meph → ContractGroup(faust.dark)
///   │   └─ faust.dark.light.meph → ContractGroup(faust.dark.light)
///   └─ faust.child.meph → ContractGroup(faust.child)
/// ```
final contractGroupListProvider =
    FutureProvider<List<ContractGroup>>((ref) async {
  await ensureContracts();

  final files = await listContracts();

  // 先解析所有文件信息（并行读取，文件多时避免串行 IO 拖慢首页加载）
  final dir = await getContractsDirectory();
  final infos = await Future.wait(
    files.map((name) async {
      final content = await readContract(name);
      final roleName = content == null ? null : extractRoleName(content);
      // 读取文件 mtime（用于首页「最近编辑」排序）；文件不存在时 null
      // 使用异步 API 避免阻塞 UI 事件循环（同步 existsSync/lastModifiedSync
      // 在文件较多或网络文件系统上可能卡顿）
      final file = File('${dir.path}/$name');
      DateTime? lastModified;
      try {
        lastModified = await file.exists()
            ? await file.lastModified()
            : null;
      } catch (_) {
        lastModified = null; // 读取失败（权限/IO 异常）时降级为 null
      }
      return ContractInfo(
        fileName: name,
        roleName: roleName ?? name.replaceAll('.meph', ''),
        isChild: isChildFileName(name),
        branchName: extractBranchName(name),
        // 命运一句话（仅子版可能含 @命运: 标记；母版/旧分支为 null）
        branchTitle:
            content == null ? null : extractBranchTitle(content),
        lastModified: lastModified,
      );
    }),
  );

  // 按「完整路径」索引：路径 = 文件名去 .meph（如 faust.dark.light）
  final infoMap = <String, ContractInfo>{
    for (final info in infos) info.fileName.replaceAll('.meph', ''): info,
  };

  // 预分组：将「直接父路径 → 直接子路径」映射一次性构建完成，
  // 避免递归中每层都全量遍历 infoMap（将整树构建从 O(N²) 降为 O(N)）。
  //
  // 通过「路径段数 = 父段数 + 1」精确识别直接子节点：
  //   - `faust`     → 子节点必须是恰好 2 段且以 `faust.` 开头
  //   - `faust.dark` → 子节点必须是恰好 3 段且以 `faust.dark.` 开头
  final childrenOf = <String, List<String>>{};
  for (final info in infos) {
    final path = info.fileName.replaceAll('.meph', '');
    final segments = path.split('.');
    if (segments.length < 2) continue; // 母版根无父
    final parentPath = segments.take(segments.length - 1).join('.');
    childrenOf.putIfAbsent(parentPath, () => []).add(path);
  }
  // 每组内保持字典序（与旧实现 sorted 行为一致）
  for (final paths in childrenOf.values) {
    paths.sort();
  }

  // 递归构建子树（childrenOf 已提供 O(1) 查找直接子节点）
  //
  // 深度守卫：文件名的 `.` 分段数表示层级深度，正常情况下不会很深
  // （母版.分支.分支…）。但用户可能手动创建超长链（如 a.b.c.d...），
  // 递归过深会导致栈溢出，因此超过 [maxContractDepth] 时截断为叶子节点。
  ContractGroup buildGroup(String path) {
    // 当前路径段数作为深度（母版根为 1）
    final segments = path.split('.');
    if (segments.length > maxContractDepth) {
      final truncPath = segments.take(maxContractDepth).join('.');
      return buildGroup(truncPath);
    }

    final info = infoMap[path];
    if (info == null) {
      // 孤儿节点（父占位缺失）：用文件名兜底生成占位节点
      final segmentCount = path.split('.').length;
      return ContractGroup(
        master: ContractInfo(
          fileName: '$path.meph',
          roleName: path.split('.').last,
          isChild: segmentCount >= 2,
        ),
        children: [],
      );
    }

    final directChildren = [
      for (final childPath in childrenOf[path] ?? const <String>[])
        if (infoMap[childPath] != null) buildGroup(childPath),
    ];
    return ContractGroup(master: info, children: directChildren);
  }

  // 顶层根 = 段数为 1 的母版（或仅有 1 段的文件）
  final groups = <ContractGroup>[];
  final roots = infoMap.keys
      .where((path) => path.split('.').length == 1)
      .toList()
    ..sort();
  for (final root in roots) {
    groups.add(buildGroup(root));
  }

  // 孤儿子版（其父链不存在母版根，如只有 faust.dark 而无 faust.meph）：
  // 用占位节点补为顶层根，确保不无处展示
  final rootFirstSegments = roots.map((p) => p.split('.').first).toSet();
  final allFirstSegments = infoMap.keys.map((p) => p.split('.').first).toSet();
  for (final first in allFirstSegments.difference(rootFirstSegments)) {
    groups.add(buildGroup(first));
  }

  // 按「最近编辑」降序排序顶层母版树：
  //   - 子树最新 mtime 越大 → 排越前（最近使用的契约优先展示）
  //   - 无可用 mtime（mtime 全为 null）→ 保持原有字典序
  groups.sort((a, b) {
    final at = a.latestModified;
    final bt = b.latestModified;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });

  return groups;
});

/// 切换当前使用的契约。
///
/// 保存契约名到 [SharedPreferences] 并刷新 [contractProvider]。
Future<void> switchContract(WidgetRef ref, String contractName) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(contractPrefKey, contractName);
  // 清空旧契约的条件编译缓存：切换契约后旧条件的 AST 不再需要，
  // 释放内存防止长期多契约切换下缓存积累无用编译结果
  clearConditionCache();
  ref.invalidate(contractProvider);
  ref.invalidate(currentContractNameProvider);
}
