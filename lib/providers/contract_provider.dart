import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../domain/contract_tree_builder.dart';
import '../domain/models.dart';
import '../domain/narrative_error.dart';
import '../services/engine/condition.dart';
import '../services/parser/meph_parser.dart';
import '../services/storage/contract_dir.dart';
import '../services/storage/contract_repo.dart';
import '../services/storage/meph_file_name.dart';

// ============================================================
// 契约树模型与构建器 re-export
//
// `ContractInfo` / `ContractGroup` / `maxContractDepth` / `buildContractTree`
// 已移入 `contract_tree_builder.dart`（纯函数，无 Riverpod 依赖）。
// 本文件 re-export 保持向后兼容：外部只需
//   import 'package:mephisto/providers/contract_provider.dart';
// 即可继续使用这些符号。
// ============================================================
export 'package:mephisto/domain/contract_tree_builder.dart';

/// 当前使用的契约文件名（存储在 shared_preferences）
const String contractPrefKey = currentContractKey;

/// 默认契约名（用户目录中不存在任何契约时使用）
const String defaultContractName = 'faust.meph';

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
    ref
        .read(contractFallbackNoticeProvider.notifier)
        .setNotice(narrativeErrorContractFallback);
    return fallback;
  }

  // 用户自定义契约（非内置模板名）缺失/损坏：
  //   - 不能静默替换成内置的浮士德契约（误导），因此不尝试内置兜底
  //   - 返回空契约（roleName: '角色'）保证叙事页不崩溃
  //   - 同步设置 fallback notice → 叙事页顶部警告条可见
  ref
      .read(contractFallbackNoticeProvider.notifier)
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
  } catch (e) {
    // 无同名内置模板（debug 模式打印便于排查 assets 缺失）
    debugPrint('_builtinFallback: assets/contracts/$name 加载失败: $e');
  }
  if (content == null) return null;
  try {
    return parseMeph(content);
  } catch (_) {
    return null;
  }
}

// ============================================================
// 契约信息 mtime 缓存（Riverpod Provider 管理生命周期）
//
// 从文件级全局 `Map` 迁移为 Provider 持有的实例，避免跨测试库
// 并行加载时共享全局可变状态导致的污染/非确定性。
// ============================================================

/// 基于 mtime 的契约解析缓存条目。
class _ContractInfoCacheEntry {
  final DateTime lastModified;
  final ContractInfo info;

  const _ContractInfoCacheEntry({
    required this.lastModified,
    required this.info,
  });
}

/// 契约信息解析缓存（key = 文件名）。
///
/// 设计要点：
///   - 仅在 mtime 变化时重新读取文件内容（轻量 stat 命中缓存）
///   - Riverpod 的 `ref.invalidate` 仍会触发重建（增删文件/切换目录），
///     但已解析的内容在文件未变化时被复用，避免重复 IO
///   - 契约切换（[switchContract]）时清空，确保新契约全量刷新
class ContractInfoCache {
  /// 缓存最大条目数（内存安全兜底）。
  static const int maxEntries = 200;

  /// 内部存储（按插入顺序迭代，淘汰时取最早条目）。
  final Map<String, _ContractInfoCacheEntry> _entries = {};

  /// 读取缓存条目；mtime 命中时返回 [ContractInfo]，否则返回 null。
  ContractInfo? get(String name, DateTime? lastModified) {
    if (lastModified == null) return null;
    final cached = _entries[name];
    if (cached == null || cached.lastModified != lastModified) return null;
    return cached.info;
  }

  /// 写入缓存条目（超限时淘汰最早条目）。
  void put(String name, DateTime lastModified, ContractInfo info) {
    _entries[name] = _ContractInfoCacheEntry(
      lastModified: lastModified,
      info: info,
    );
    _evictIfNeeded();
  }

  /// 清空缓存（契约切换时调用，确保全量重新解析）。
  void clear() {
    _entries.clear();
  }

  /// 缓存超限时淘汰最旧（按插入顺序移除最早条目）。
  void _evictIfNeeded() {
    if (_entries.length <= maxEntries) return;
    // 找到最早的条目（遍历取第一个），移除之
    final justAddedKey = _entries.keys.last;
    final firstKey = _entries.keys.firstWhere(
      (k) => k != justAddedKey,
      orElse: () => justAddedKey,
    );
    _entries.remove(firstKey);
  }
}

/// 契约信息缓存 Provider。
///
/// 供 [contractGroupListProvider] 复用解析结果，抑制重复 IO。
/// 生命周期由 Provider 容器管理，而非文件级全局变量。
final contractInfoCacheProvider = Provider<ContractInfoCache>((ref) {
  return ContractInfoCache();
});

/// 契约分组列表 Provider：按「层级路径」构建多级递归树
///
/// 返回 [[ContractGroup]] 列表，每个根节点是一份母版契约及其「命运树」：
/// ```
/// faust.meph → ContractGroup(faust)
///   ├─ faust.dark.meph → ContractGroup(faust.dark)
///   │   └─ faust.dark.light.meph → ContractGroup(faust.dark.light)
///   └─ faust.child.meph → ContractGroup(faust.child)
/// ```
///
/// 性能优化（mtime 缓存）：
///   - 每次执行先读取各文件 mtime（轻量 stat）
///   - 文件 mtime 未变化且已存在缓存 → 直接复用解析结果，跳过文件读取
///   - 仅在 mtime 变化或首次访问时读取内容解析角色名/命运说明
final contractGroupListProvider = FutureProvider<List<ContractGroup>>((
  ref,
) async {
  await ensureContracts();

  final files = await listContracts();
  // 获取共享缓存实例（生命周期由 Provider 管理）
  final cache = ref.watch(contractInfoCacheProvider);

  // 先解析所有文件信息（并行读取，文件多时避免串行 IO 拖慢首页加载）
  final dir = await getContractsDirectory();
  final infos = await Future.wait(
    files.map((name) async {
      // 读取文件 mtime（用于首页「最近编辑」排序）；文件不存在时 null
      // 使用异步 API 避免阻塞 UI 事件循环（同步 existsSync/lastModifiedSync
      // 在文件较多或网络文件系统上可能卡顿）
      final file = File('${dir.path}/$name');
      DateTime? lastModified;
      try {
        lastModified = await file.exists() ? await file.lastModified() : null;
      } catch (_) {
        lastModified = null; // 读取失败（权限/IO 异常）时降级为 null
      }

      // mtime 缓存命中：文件未变化 → 直接复用已解析的 ContractInfo
      final cached = cache.get(name, lastModified);
      if (cached != null) return cached;

      // 缓存未命中 / mtime 变化：读取内容重新解析
      final content = await readContract(name);
      final roleName = content == null ? null : extractRoleName(content);
      final info = ContractInfo(
        fileName: name,
        roleName: roleName ?? name.replaceAll('.meph', ''),
        isChild: isChildFileName(name),
        branchName: extractBranchName(name),
        // 命运一句话（仅子版可能含 @命运: 标记；母版/旧分支为 null）
        branchTitle: content == null ? null : extractBranchTitle(content),
        lastModified: lastModified,
      );
      if (lastModified != null) {
        cache.put(name, lastModified, info);
      }
      return info;
    }),
  );

  return buildContractTree(infos);
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
  // 清空契约信息 mtime 缓存：切换契约后旧文件名可能被复用为新内容，
  // 必须强制全量重新解析避免脏数据
  ref.read(contractInfoCacheProvider).clear();
  ref.invalidate(contractProvider);
  ref.invalidate(currentContractNameProvider);
}