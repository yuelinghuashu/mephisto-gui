import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../domain/narrative_error.dart';
import '../../services/narrative_error_localizer.dart';
import 'message_list.dart';

/// 叙事页共享骨架
///
/// 封装单角色 [NarrativeScreen] 与多角色 [StageNarrativeScreen] 共用的：
///   - 桌面端快捷键绑定（Ctrl+Home / Ctrl+End → 滚动消息列表）
///   - LLM 错误监听 → SnackBar 提示（错误码本地化翻译）
///
/// 差异部分（AppBar 结构 / body）由 [scaffoldBuilder] 参数提供，
/// 本组件负责包裹 `CallbackShortcuts` 并在 [lastError] 变化时弹出提示。
class NarrativeScaffold extends ConsumerStatefulWidget {
  /// 消息列表控制 Key（供快捷键滚动定位）
  final GlobalKey<MessageListState> messageListKey;

  /// 最近错误信息（由父组件从各自 Provider 中 watch 传入）。
  /// 非空时自动弹出本地化 SnackBar 提示（错误码 → 本地化文本）。
  final String lastError;

  /// Scaffold 构建器（接收已包裹快捷键的上下文）
  final WidgetBuilder scaffoldBuilder;

  const NarrativeScaffold({
    super.key,
    required this.messageListKey,
    required this.lastError,
    required this.scaffoldBuilder,
  });

  @override
  ConsumerState<NarrativeScaffold> createState() => _NarrativeScaffoldState();
}

class _NarrativeScaffoldState extends ConsumerState<NarrativeScaffold> {
  @override
  void didUpdateWidget(NarrativeScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当错误信息变化且非空时弹出提示（初始状态为 '' 时不触发）
    if (widget.lastError.isNotEmpty &&
        widget.lastError != oldWidget.lastError) {
      final error = widget.lastError;
      // 延迟到当前帧结束后再弹出 SnackBar：
      // didUpdateWidget 在 build 期间被调用，直接 showSnackBar 会触发
      // "cannot be called during build" 断言。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        // 错误码 → 本地化文本；自由格式错误文本（如 LLM 异常信息）直接展示
        final displayError = isNarrativeErrorCode(error)
            ? localizeNarrativeError(l10n, error)
            : error;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.narrativeErrorPrefix(displayError))),
          );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 桌面端快捷键（移动端无实体键盘，使用 AppBar 按钮替代）：
    //   Ctrl+Home → 跳至第一条历史
    //   Ctrl+End  → 跳至最后一条历史
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.home, control: true): () =>
            widget.messageListKey.currentState?.scrollToTop(),
        const SingleActivator(LogicalKeyboardKey.end, control: true): () =>
            widget.messageListKey.currentState?.scrollToBottom(),
      },
      child: Builder(builder: widget.scaffoldBuilder),
    );
  }
}
