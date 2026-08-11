import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

/// 角色快捷操作底部弹层（长按角色芯片触发）
///
/// 提供「进入 / 预览 / 编辑 / 删除角色」四个操作入口，替代旧版
/// 「展开区每个角色的 ⋮ 菜单」，让长按角色 chip 即可弹出上下文菜单。
///
/// 静态方法 [RoleQuickActionsSheet.show] 封装 `showModalBottomSheet`，
/// 返回所选操作的 action 字符串（`enter` / `preview` / `edit` / `delete_role`），
/// 取消或点击空白处返回 `null`。
class RoleQuickActionsSheet {
  const RoleQuickActionsSheet._();

  /// 弹出角色快捷操作弹层。
  ///
  /// [roleName] 显示为弹层标题（不可操作，仅标识角色）。
  /// 返回用户选择的 action 字符串，关闭弹层返回 `null`。
  static Future<String?> show(BuildContext context, {required String roleName}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                roleName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            _ActionItem(
              icon: Icons.play_arrow_outlined,
              label: l10n.contractCardEnter,
              action: 'enter',
            ),
            _ActionItem(
              icon: Icons.visibility_outlined,
              label: l10n.contractCardPreview,
              action: 'preview',
            ),
            _ActionItem(
              icon: Icons.edit_outlined,
              label: l10n.contractCardEdit,
              action: 'edit',
            ),
            _ActionItem(
              icon: Icons.delete_outline,
              label: l10n.stageCardDeleteRole,
              action: 'delete_role',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 弹层内的单个操作项
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String action;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(context, action),
    );
  }
}