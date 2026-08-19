import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import 'message_list.dart';

/// 智能跳转按钮：合并「跳顶 + 跳底」为单按钮。
///
/// 行为：
///   - 滚动位置在顶部附近 → 点击跳到最底部（图标显示「向下双箭头」）
///   - 滚动位置离开顶部 → 点击跳到最顶部（图标显示「向上双箭头」）
///
/// 图标方向由消息列表的 [MessageListState.isNearTop] 实时驱动，
/// 不依赖键盘快捷键，移动端依然一键可达。
///
/// 被单角色叙事页与多角色舞台页共用，消除两处重复实现。
class SmartJumpButton extends StatelessWidget {
  /// 消息列表控制 Key（用于访问 [MessageListState] 的滚动/位置状态）
  final GlobalKey<MessageListState> messageListKey;

  const SmartJumpButton({super.key, required this.messageListKey});

  /// 默认 Listenable（消息列表尚未挂载时使用）。
  ///
  /// 消息列表挂载后 [ValueListenableBuilder] 自动切换到
  /// `messageListKey.currentState.isNearTop` 进行实时监听。
  static final ValueNotifier<bool> _emptyNearTop = ValueNotifier(true);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messageListState = messageListKey.currentState;
    return ValueListenableBuilder<bool>(
      valueListenable: messageListState?.isNearTop ?? _emptyNearTop,
      builder: (context, isNearTop, _) {
        return IconButton(
          icon: Icon(
            isNearTop
                ? Icons.keyboard_double_arrow_down
                : Icons.keyboard_double_arrow_up,
          ),
          tooltip: isNearTop
              ? l10n.narrativeScrollBottom
              : l10n.narrativeScrollTop,
          onPressed: () => messageListState?.scrollTopOrBottom(),
        );
      },
    );
  }
}
