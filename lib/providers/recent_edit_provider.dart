/// 首页「最近编辑」数据计算 Provider（memoized）
///
/// 合并「单角色契约 + 多角色舞台」两侧最近活动，返回最新入口的数据部分
/// （label + lastModified + 类型标志）。onTap 回调由 UI 层根据类型构建，
/// 保持 Provider 纯数据、可测试。
///
/// 设计要点：
///   - 依赖 [contractGroupListProvider]（契约侧 mtime 已缓存）与
///     [stageListProvider] / [stageLastModifiedProvider]（舞台侧已缓存），
///     本身不做任何磁盘 IO，仅做内存中的比较与选择
///   - 不持有 onTap 回调（依赖 UI 上下文），由调用方在构建 [RecentEditEntry]
///     时根据 [isStage] 决定回调行为
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stage_models.dart';
import 'contract_provider.dart';
import 'stage_provider.dart';

/// 最近编辑数据（`label` + `lastModified` + 类型 + 识别标识）
class RecentEditData {
  /// 展示标签：契约 → 角色名；舞台 → 舞台名。
  final String label;

  /// 最近活动时间。
  final DateTime lastModified;

  /// 是否为舞台（true = 舞台；false = 单角色契约）
  final bool isStage;

  /// 进入叙事所需的标识：
  ///   - 契约：文件名（如 `faust.meph`，供 [ContractInfo] 构造/查找）
  ///   - 舞台：目录绝对路径（供 [StageInfo] 进入）
  final String targetPath;

  const RecentEditData({
    required this.label,
    required this.lastModified,
    required this.isStage,
    required this.targetPath,
  });
}

/// 最近编辑数据 Provider（获取契约组列表后基于缓存 mtime 计算）。
///
/// 与旧 [ContractTreeSection._computeRecentEntry] 的区别：
///   - 旧实现每次 build 都递归遍历契约树 + watch 所有舞台 mtime
///   - 新实现依赖 Riverpod 缓存：contractGroupListProvider 与
///     stageLastModifiedProvider 均已有缓存，仅在真正变化时重算
///   - 返回 null 表示两侧均无可用 mtime（不显示「最近编辑」入口）
final recentEditProvider = FutureProvider<RecentEditData?>((ref) async {
  final groups = await ref.watch(contractGroupListProvider.future);

  // ---- 契约侧候选：递归收集所有节点，取 mtime 最新者 ----
  ContractInfo? bestContract;
  void collect(ContractGroup group) {
    final t = group.master.lastModified;
    final best = bestContract;
    if (t != null && (best == null || t.isAfter(best.lastModified!))) {
      bestContract = group.master;
    }
    for (final child in group.children) {
      collect(child);
    }
  }

  for (final group in groups) {
    collect(group);
  }

  // ---- 舞台侧候选：读取缓存 mtime，取最新者 ----
  final stages = ref.watch(stageListProvider).value ?? const <StageInfo>[];
  StageInfo? bestStage;
  DateTime? bestStageTime;
  for (final stage in stages) {
    final t = ref.watch(stageLastModifiedProvider(stage.path)).value;
    if (t == null) continue;
    if (bestStage == null || t.isAfter(bestStageTime!)) {
      bestStage = stage;
      bestStageTime = t;
    }
  }

  final contractTime = bestContract?.lastModified;

  // 舞台更新比契约更新更晚（或契约无 mtime）→ 优先展示舞台入口
  if (bestStage != null &&
      bestStageTime != null &&
      (contractTime == null || bestStageTime.isAfter(contractTime))) {
    return RecentEditData(
      label: bestStage.name,
      lastModified: bestStageTime,
      isStage: true,
      targetPath: bestStage.path,
    );
  }

  // 契约侧赢（或两侧均无 mtime）→ 展示契约入口
  final contract = bestContract;
  if (contract == null) return null;
  return RecentEditData(
    label: contract.roleName,
    lastModified: contract.lastModified!,
    isStage: false,
    targetPath: contract.fileName,
  );
});
