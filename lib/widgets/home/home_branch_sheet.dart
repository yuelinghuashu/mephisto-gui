import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../providers/contract_provider.dart';

/// 移动端母版分支选择器（BottomSheet）
///
/// 移动端点击母版卡片时弹出，列出「母版本体」+ 全部子版分支：
///   - 顶级显示「进入母版」入口（角色名 + 文件名）
///   - 下方列出该母版下所有子版（含命运说明/分支名）
///   - 用户点击任一分支名直接进入对应叙事
///
/// 替代移动端「点箭头展开 → 再找子版点」的两步操作，一步直达。
class HomeBranchSheet extends StatelessWidget {
  /// 当前母版节点
  final ContractGroup group;

  /// 点击分支/母版进入叙事的回调
  final ValueChanged<ContractInfo> onEnter;

  const HomeBranchSheet({
    super.key,
    required this.group,
    required this.onEnter,
  });

  /// 弹出分支选择器的便捷入口。
  static Future<void> show(
    BuildContext context, {
    required ContractGroup group,
    required ValueChanged<ContractInfo> onEnter,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: HomeBranchSheet(group: group, onEnter: onEnter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final master = group.master;
    final branches = group.allInfos
        .where((i) => i.fileName != master.fileName)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dragHandle(theme),
        _header(context, theme, l10n, master),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _BranchTile(
                title: master.roleName,
                subtitle: master.fileName,
                isMaster: true,
                onTap: () {
                  Navigator.pop(context);
                  onEnter(master);
                },
              ),
              if (branches.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.homeNoBranches,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final info in branches)
                  _BranchTile(
                    title: info.branchTitle ?? info.branchName ?? info.fileName,
                    subtitle: info.fileName,
                    onTap: () {
                      Navigator.pop(context);
                      onEnter(info);
                    },
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 顶部拖动把手
  Widget _dragHandle(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: theme.dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// 标题栏
  Widget _header(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ContractInfo master,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          const Text(
            '📜',
            style: TextStyle(fontSize: 18, color: AppTheme.gold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              master.roleName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.homeCancel,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// 分支列表项（母版/子版共用，紧凑单行）
class _BranchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isMaster;
  final VoidCallback onTap;

  const _BranchTile({
    required this.title,
    required this.subtitle,
    this.isMaster = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        isMaster ? Icons.graphic_eq : Icons.circle,
        size: isMaster ? 16 : 8,
        color: AppTheme.gold,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isMaster ? FontWeight.bold : FontWeight.normal,
          color: isMaster ? AppTheme.gold : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppTheme.textSecondary(theme.brightness),
          fontSize: 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}