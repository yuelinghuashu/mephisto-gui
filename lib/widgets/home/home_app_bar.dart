import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

/// 首页顶栏（普通模式）
///
/// 展示品牌标题 + 新建/导入/设置操作按钮。
/// 从 home_screen.dart 拆分而来，使页面聚焦列表构建。
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 新建契约回调
  final VoidCallback onNewContract;

  /// 导入契约回调
  final VoidCallback onImportContract;

  const HomeAppBar({
    super.key,
    required this.onNewContract,
    required this.onImportContract,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppBar(
      title: const Text('📜 Mephisto'),
      centerTitle: false,
      actions: [
        // ---- 新建契约按钮 ----
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onNewContract,
          tooltip: l10n.homeNewContract,
        ),
        // ---- 导入契约按钮 ----
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          onPressed: onImportContract,
          tooltip: l10n.homeImportContract,
        ),
        // ---- 设置入口 ----
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          tooltip: l10n.homeSettings,
        ),
      ],
    );
  }
}

/// 首页顶栏（多选模式）
///
/// 展示选中数量 + 删除选中 + 全选/取消全选操作。
/// 从 home_screen.dart 拆分而来。
class HomeSelectModeAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// 选中数量
  final int selectedCount;

  /// 全部文件数量（用于判断是否全选）
  final int totalCount;

  /// 删除选中回调
  final VoidCallback? onDelete;

  /// 取消/退出多选回调
  final VoidCallback onCancel;

  /// 全选/取消全选回调
  final VoidCallback onToggleSelectAll;

  const HomeSelectModeAppBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onDelete,
    required this.onCancel,
    required this.onToggleSelectAll,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isAllSelected = selectedCount == totalCount;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onCancel,
        tooltip: l10n.homeCancel,
      ),
      title: Text(
        l10n.homeSelectedCount(selectedCount),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        // ---- 删除选中 ----
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: selectedCount == 0 ? null : onDelete,
          tooltip: l10n.homeDeleteSelected,
        ),
        // ---- 全选/取消全选 ----
        TextButton(
          onPressed: totalCount == 0 ? null : onToggleSelectAll,
          child: Text(
            isAllSelected ? l10n.homeDeselectAll : l10n.homeSelectAll,
          ),
        ),
      ],
    );
  }
}
