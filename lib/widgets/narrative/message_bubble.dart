import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import 'dice_verdict_card.dart';
import 'paragraph_text.dart';

/// 单条消息气泡
///
/// 根据消息角色（命运/角色/系统）渲染不同的气泡样式：
///   - 系统消息：居中金色标签样式
///   - 命运消息（用户）：右对齐金色气泡
///   - 角色消息（AI）：左对齐卡片色气泡（支持流式输出光标）
///
/// 长按（桌面端右键）角色/命运消息弹出操作菜单：
///   - 复制：复制消息内容
///   - 重新生成：删除该回复 + 其前一条命运指引，再以同一条指引重新发送
class MessageBubble extends StatelessWidget {
  /// 消息数据
  final Message message;

  /// 是否为流式输出中的消息
  final bool isStreaming;

  /// 重新生成回调（仅角色消息且非流式输出时可用）
  final VoidCallback? onRegenerate;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFate = message.role == MessageRole.fate;
    final isSystem = message.role == MessageRole.system;

    // ---- 系统消息：特殊样式（不支持长按菜单） ----
    if (isSystem) {
      // 骰子判定结果：渲染「命运结算」卡片
      final diceResults = message.diceResults;
      if (diceResults != null && diceResults.isNotEmpty) {
        return DiceVerdictCard(results: diceResults);
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📜 ', style: theme.textTheme.labelMedium),
              Expanded(
                child: Text(
                  message.content,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary(theme.brightness),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---- 命运消息（用户）：右对齐金色气泡 ----
    if (isFate) {
      return _withMessageMenu(
        context,
        _MessageContainer(
          alignment: Alignment.centerRight,
          color: AppTheme.gold.withValues(alpha: 0.15),
          child: ParagraphText(
            message.content,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    // ---- 角色消息（AI）：左对齐卡片色气泡 ----
    final assistantBubble = _MessageContainer(
      alignment: Alignment.centerLeft,
      color: theme.cardColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 流式输出与完成后的文本使用相同正体样式，
          // 生成中状态由末尾金色光标标识，避免斜体影响实时阅读。
          ParagraphText(
            message.content,
            style: theme.textTheme.bodyMedium,
          ),
          // 流式打字机光标：静态竖线 + 独立 StatefulWidget 实现
          // 周期性闪烁（仅流式输出中显示；完成时随 [MessageBubble] 重建消失）
          if (isStreaming) const _BlinkingCursor(),
        ],
      ),
    );

    // 流式输出中不弹出操作菜单（内容仍在变化）
    if (isStreaming) return assistantBubble;
    return _withMessageMenu(context, assistantBubble);
  }

  /// 包裹消息气泡并附加长按/右键操作菜单。
  ///
  /// 菜单项**按需构造**（在回调内构建而非每次 build）：
  /// 流式期间气泡每 chunk 重建，若在 build 中构造 PopupMenuItem 列表
  /// （含 ListTile、AppLocalizations 查找），即使菜单从未打开也白白消耗。
  Widget _withMessageMenu(BuildContext context, Widget child) {
    return Semantics(
      // 读屏可感知「此处是按钮，可打开消息操作菜单」；
      // 不排除子语义（消息文本仍需朗读）
      button: true,
      label: AppLocalizations.of(context).messageMenuOpenSemantics,
      child: GestureDetector(
        // HitTestBehavior.opaque：确保整块区域可命中（含透明区域），
        // 满足桌面右键/触屏长按的最小命中范围
        behavior: HitTestBehavior.opaque,
        // 桌面端右键亦触发菜单
        onSecondaryTapDown: (details) =>
            _showMenu(context, details.globalPosition),
        onLongPress: () => _showMenu(context),
        child: child,
      ),
    );
  }

  /// 构建菜单项列表（按需调用）。
  ///
  /// 在 [showMenu] 之前构建——菜单被触发时才会执行
  /// `AppLocalizations.of(context)` 查找与 ListTile 构造。
  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: 'copy',
        child: ListTile(
          leading: const Icon(Icons.copy, size: 20),
          title: Text(l10n.messageMenuCopy),
          dense: true,
          visualDensity: VisualDensity.compact,
        ),
      ),
      // 重新生成：仅角色消息（assistant）可用
      if (message.role == MessageRole.assistant && onRegenerate != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'regenerate',
          child: ListTile(
            leading: const Icon(Icons.refresh, size: 20),
            title: Text(l10n.messageMenuRegenerate),
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    ];
  }

  /// 弹出操作菜单（优先使用触发位置，否则居中显示）。
  void _showMenu(
    BuildContext context, [
    Offset? position,
  ]) async {
    // 按需构建菜单项（避免每次 build 都构造）
    final items = _buildMenuItems(context);
    if (items.isEmpty) return;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position?.dx ?? 0,
        position?.dy ?? 0,
        position?.dx ?? 0,
        position?.dy ?? 0,
      ),
      items: items,
    );

    if (result == null) return;

    switch (result) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.content));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).messageMenuCopied)),
            );
        }
        break;
      case 'regenerate':
        onRegenerate?.call();
        break;
    }
  }
}

/// 角色消息气泡的内容内边距（水平 16 / 垂直 10）。
///
/// 与 [assistantBubbleRadius] 一起构成角色气泡的标准视觉，被标准气泡
/// `_MessageContainer` 与舞台角色气泡 `StageMessageBubble` 共用，
/// 避免两处视觉常量漂移（改圆角/内边距需同步两处）。
const EdgeInsets assistantBubblePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 10,
);

/// 角色消息气泡的圆角。
const double assistantBubbleRadius = 12;

/// 消息气泡容器（命运/角色共用）。
///
/// 统一「Padding + Align + Container」三段结构：
///   - [alignment]：右对齐（命运）或左对齐（角色）
///   - [color]：气泡背景色（金色半透明 / 卡片色半透明）
///   - [child]：气泡内容（纯文本 / 文本 + 流式光标）
class _MessageContainer extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final Widget child;

  const _MessageContainer({
    required this.alignment,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        // 使用 Align（宽松约束）而非 Row，让文本能根据可用宽度自动 softWrap 换行
        alignment: alignment,
        child: Container(
          // 宽度继承外层用户选择的叙事内容宽度档位，自动换行
          padding: assistantBubblePadding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(assistantBubbleRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 流式打字机光标（闪烁动画）。
///
/// 独立 [StatefulWidget]：
///   - `MessageBubble` 是 StatelessWidget，无法持有周期性的 [AnimationController]
///   - 光标只在流式输出中显示，完成时随 [MessageBubble] 重建自动消失
///   - 闪烁：约 1.2 秒周期内保持可见 0.7s / 隐藏 0.5s，
///     符合中文阅读习惯的"纸带打字机"节奏（太快会干扰阅读）
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  /// 光标可见持续时间
  static const Duration _visibleDuration = Duration(milliseconds: 700);

  /// 光标隐藏持续时间
  static const Duration _hiddenDuration = Duration(milliseconds: 500);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _visibleDuration + _hiddenDuration,
  );

  @override
  void initState() {
    super.initState();
    // 周期性重复闪烁（循环播放）
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 前半周期（可见持续期内）opacity = 1，后半周期 = 0，
    // 形成「亮起 → 熄灭」的方波闪烁（而非平滑淡入淡出，更接近打字机）
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isVisible =
            _controller.value <
            (_visibleDuration.inMilliseconds /
                (_visibleDuration + _hiddenDuration).inMilliseconds);
        return Opacity(opacity: isVisible ? 1.0 : 0.0, child: child);
      },
      child: const SizedBox(
        width: 2,
        height: 16,
        child: ColoredBox(color: AppTheme.gold),
      ),
    );
  }
}