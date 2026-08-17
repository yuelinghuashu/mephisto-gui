import 'package:flutter/material.dart';

/// 舞台角色芯片（紧凑单行入口）
///
/// 每个角色渲染为一个芯片：色点 + 角色名 + （有存档时 💾 徽标）。
/// 替换旧版「展开区双层迷你卡片」，大幅提升首页信息密度。
///
/// 交互：
///   - 点击 → 进入舞台叙事（按存档续玩）
///   - 长按 → 弹出快捷菜单（由调用方处理）
class RoleChip extends StatelessWidget {
  /// 角色名
  final String roleName;

  /// 角色主题色（来自 [assignRoleColors] 色板）
  final Color color;

  /// 是否存在 `.child.meph` 存档（显示 💾 徽标）
  final bool hasSave;

  /// 点击回调（进入舞台叙事）
  final VoidCallback? onTap;

  /// 长按回调（弹出快捷菜单）
  final VoidCallback? onLongPress;

  const RoleChip({
    super.key,
    required this.roleName,
    required this.color,
    this.hasSave = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        // minHeight 32：满足触屏最小点击目标（带长按手势的小芯片）
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              roleName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // 有存档徽标（💾 emoji 在小字号下清晰可辨）
            if (hasSave) ...[
              const SizedBox(width: 3),
              const Text('💾', style: TextStyle(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}