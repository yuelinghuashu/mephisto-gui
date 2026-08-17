import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/stage_models.dart';
import '../../domain/stage_narrative_state.dart';
import '../../l10n/app_localizations.dart';

/// 舞台角色状态条：展示各角色的状态/记忆数量。
///
/// 从 [StageNarrativeScreen] 提取的独立 widget，便于独立测试与复用。
///
/// 内部使用水平 [SingleChildScrollView] 承载角色胶囊；为避免鼠标悬停在此
/// 区域时垂直滚轮事件被「平行兄弟节点」的滚动隔离（导致无法滚动下方消息流），
/// 通过 [onVerticalScroll] 将垂直滚轮增量委托给外部（舞台叙事页转发给消息流）。
/// 水平方向的自我滚动能力不受影响。
///
/// 接收 [stage] / [roles] 字段（而非整个 state），使调用方（舞台叙事页）
/// 可以窄监听：流式输出期间本组件只随 roles 变化重建。
class RoleStatusBar extends StatelessWidget {
  /// 舞台数据（null = 未加载，不渲染）
  final StageLoaded? stage;

  /// 各角色运行时状态（角色名 → 状态/记忆/历史）
  final Map<String, RoleRunState> roles;

  /// 垂直滚轮委托（鼠标在状态条区域滚动时转发给外部滚动目标）。
  final void Function(double deltaY)? onVerticalScroll;

  const RoleStatusBar({
    super.key,
    required this.stage,
    required this.roles,
    this.onVerticalScroll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = this.stage;
    if (stage == null) return const SizedBox.shrink();

    final statusBar = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(theme.brightness),
        border: Border(
          bottom: BorderSide(color: AppTheme.divider(theme.brightness)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final character in stage.characters) ...[
              RoleStatusChip(
                roleName: character.roleName,
                stateCount: roles[character.roleName]?.currentState.length ?? 0,
                memoryCount: roles[character.roleName]?.memories.length ?? 0,
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );

    // 无委托时原样返回（不改变既有行为）
    final onScroll = onVerticalScroll;
    if (onScroll == null) return statusBar;

    // 捕获垂直滚轮事件转发给外部。
    // 不调用 stopPropagation：水平 SingleChildScrollView 本就不消费 dy，
    // 垂直事件在子树外由 AppBar/消息流处理；此处仅在同一棵子树内路由。
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final deltaY = event.scrollDelta.dy;
          if (deltaY != 0) onScroll(deltaY);
        }
      },
      child: statusBar,
    );
  }
}

/// 单个角色状态 chip
///
/// 视觉对齐单角色叙事页的 [StatusBar._StatusChip]：
///   - 计数使用金色加粗（强调数字）
///   - 标签使用次要文本色
///   - 图标 + 每项间留 4px 间隙
class RoleStatusChip extends StatelessWidget {
  final String roleName;
  final int stateCount;
  final int memoryCount;

  const RoleStatusChip({
    super.key,
    required this.roleName,
    required this.stateCount,
    required this.memoryCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      // 合并读屏语义：朗读「角色名 状态 N 项，记忆 M 条」，避免逐段朗读
      //（注意 gen-l10n 按占位符字母序生成参数：memoryCount/roleName/stateCount）
      label: l10n.roleStatusChipSemantics(memoryCount, roleName, stateCount),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            roleName,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          // 状态计数：⚡ + 金色加粗数字（与单角色 StatusBar 风格一致）
          Text('⚡', style: theme.textTheme.bodySmall),
          const SizedBox(width: 2),
          Text(
            '$stateCount ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(width: 6),
          // 记忆计数：🧠 + 金色加粗数字
          Text('🧠', style: theme.textTheme.bodySmall),
          const SizedBox(width: 2),
          Text(
            '$memoryCount',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
            ),
          ),
        ],
      ),
    );
  }
}
