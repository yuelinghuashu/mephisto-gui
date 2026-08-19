import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/stage_provider.dart';
import '../../services/storage/stage_repo.dart';
import 'stage_card.dart';

/// 带元数据加载的舞台卡片
///
/// 通过 `stageProvider(stage.path)` 异步加载角色列表 + `stageLastModifiedProvider`
/// 缓存读取最近活动时间。加载完成前显示基础卡片（无预览），不阻塞列表渲染。
///
/// 使用 Riverpod 缓存替代原先的 `FutureBuilder`（每次 build 重新发起磁盘
/// mtime 读取）：多选切换等父级重建不再触发无效 IO；舞台列表刷新时
/// 通过 `invalidate(stageListProvider)` 一并失效缓存。
class StageCardWithMeta extends ConsumerWidget {
  final StageInfo stage;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final ValueChanged<String>? onMenu;
  final void Function(String roleName, {bool restoreSave})? onRoleTap;
  final void Function(String roleName)? onRoleLongPress;

  const StageCardWithMeta({
    super.key,
    required this.stage,
    required this.onTap,
    this.onLongPress,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.onMenu,
    this.onRoleTap,
    this.onRoleLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageAsync = ref.watch(stageProvider(stage.path));
    final characters = stageAsync.value?.characters ?? const <StageCharacter>[];
    final roleNames = characters.map((c) => c.roleName).toList();
    // 有存档的角色名集合（来自 loadStage 探测的 hasSave）
    final savedRoleNames = {
      for (final c in characters)
        if (c.hasSave) c.roleName,
    };

    // 最近活动时间：由 Riverpod 缓存（无监听时释放，刷新舞台列表时一并失效）
    final lastModifiedAsync = ref.watch(stageLastModifiedProvider(stage.path));

    return StageCard(
      info: stage,
      roleNames: roleNames,
      savedRoleNames: savedRoleNames,
      lastModified: lastModifiedAsync.value,
      onTap: onTap,
      onLongPress: onLongPress,
      isSelectMode: isSelectMode,
      isSelected: isSelected,
      onToggleSelect: onToggleSelect,
      onMenu: onMenu,
      onRoleTap: onRoleTap,
      onRoleLongPress: onRoleLongPress,
    );
  }
}
