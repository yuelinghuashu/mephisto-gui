import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/app/theme.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:mephisto/providers/home_section_visibility_provider.dart';
import 'package:mephisto/providers/stage_provider.dart';
import 'package:mephisto/services/storage/stage_repo.dart';

import 'section_header.dart';

/// 舞台列表区标题（首页聚合入口）
///
/// 只负责「标题 + 折叠按钮」，舞台卡列表由外层 [ContractTreeSection] 的
/// `ListView.builder` 按索引惰性构建（每张卡独立懒实例化，视口外不构建）。
///
/// 数据来源：本组件 watch [stageListProvider] 获取舞台列表（用于计数与
/// 空列表时隐藏整区），卡片渲染委托给外层（避免整块 Column 一次性构建
/// 全部舞台卡——每张卡还各自 watch 两个 family provider）。
class StageSection extends ConsumerWidget {
  /// 是否处于多选模式（多选时标题隐藏折叠按钮语义不变，舞台卡由外层强制展开）
  final bool isSelectMode;

  const StageSection({super.key, this.isSelectMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final stagesAsync = ref.watch(stageListProvider);
    final stages = stagesAsync.value ?? const <StageInfo>[];
    if (stages.isEmpty) return const SizedBox.shrink();

    final visibility = ref.watch(homeSectionVisibilityProvider);
    // 多选模式或折叠状态：只显示标题（折叠时不渲染卡片列表）。
    // 多选模式下强制展开（折叠状态下看不到卡片就无法勾选）
    final collapsed = !isSelectMode && visibility.stageCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          leadingIcon: Icons.theater_comedy,
          title: l10n.homeStageSectionTitle,
          count: stages.length,
          trailing: IconButton(
            icon: Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: AppTheme.gold,
            ),
            tooltip: collapsed
                ? l10n.homeSectionExpand
                : l10n.homeSectionCollapse,
            onPressed: () => ref
                .read(homeSectionVisibilityProvider.notifier)
                .toggleStageCollapsed(),
          ),
        ),
        if (collapsed) const SizedBox(height: 12),
      ],
    );
  }
}
