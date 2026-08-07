import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../domain/models.dart';
import 'message_bubble.dart';

/// 叙事消息列表
///
/// 展示消息流，支持流式输出（最后一条显示"思考中..."或流式内容）。
/// 支持文本选择（[SelectionArea]）。
///
/// 作为 [MessageListState] 暴露滚动控制能力：
///   - [MessageListState.scrollToTop]：跳至第一条历史
///   - [MessageListState.scrollToBottom]：跳至最后一条历史
class MessageList extends StatefulWidget {
  /// 消息列表
  final List<Message> messages;

  /// 当前流式输出内容
  final String streamingContent;

  /// 是否正在生成
  final bool isGenerating;

  /// 消息内容最大宽度（null 表示满屏）
  ///
  /// 用于在不限制整个滚动视口宽度的前提下，约束每条消息气泡的宽度。
  /// 这样鼠标在屏幕任意位置滚动消息流都生效（桌面端友好），
  /// 同时消息仍保持用户选择的叙事内容宽度档位居中显示。
  final double? contentMaxWidth;

  const MessageList({
    super.key,
    required this.messages,
    required this.streamingContent,
    required this.isGenerating,
    this.contentMaxWidth,
  });

  @override
  MessageListState createState() => MessageListState();
}

/// [MessageList] 的状态，暴露滚动控制方法。
///
/// 通过 `GlobalKey<MessageListState>` 从外部（如 AppBar 按钮、快捷键）控制
/// 消息列表跳转至第一条 / 最后一条历史。
class MessageListState extends State<MessageList> {
  /// 滚动控制器（管理消息流的滚动位置）
  final ScrollController _scrollController = ScrollController();

  /// 是否应自动跟随到底部
  ///
  /// 初始为 true（打开即跟随最新消息）。
  /// 用户向上滚动（查看历史）时置 false 暂停跟随；
  /// 用户滚回底部时恢复 true。
  bool _autoFollowBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 首次挂载后定位到最新消息：打开子版（已含完整历史）或切换契约时
    // 应直接看到结尾而非开头。jumpTo 瞬时完成，历史长时也无需滚动动画；
    // 母版无历史时 maxScrollExtent 为 0，jumpTo(0) 无副作用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 监听滚动位置：顶部以下视为"离开底部"暂停跟随；滚回底部恢复跟随。
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom =
        position.pixels >= position.maxScrollExtent - 8; // 8px 容差
    if (atBottom) {
      _autoFollowBottom = true;
    } else if (position.pixels < position.maxScrollExtent - 24) {
      // 明显离开底部才暂停（避免微小偏移误触发）
      _autoFollowBottom = false;
    }
  }

  /// 新消息/流式内容到来时：若正在跟随底部则平滑滚动到底部。
  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 消息数量变化或流式内容增长（排除纯滚动造成的 update）
    final contentChanged =
        widget.messages.length != oldWidget.messages.length ||
        widget.streamingContent != oldWidget.streamingContent ||
        widget.isGenerating != oldWidget.isGenerating;
    if (contentChanged && _autoFollowBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// 平滑滚动至消息列表顶部（第一条历史）。
  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// 平滑滚动至消息列表底部（最后一条历史）。
  ///
  /// 使用 `position.maxScrollExtent` 动态获取最大滚动距离，
  /// 兼容不同屏幕高度与消息数量。
  void scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: widget.messages.length + (widget.isGenerating ? 1 : 0),
        itemBuilder: (context, index) {
          // ---- 如果正在生成，最后一条显示流式内容 ----
          if (widget.isGenerating && index == widget.messages.length) {
            final content = widget.streamingContent.isEmpty
                ? AppLocalizations.of(context).messageBubbleThinking
                : widget.streamingContent;
            return _wrapBubble(
              MessageBubble(
                message: Message.assistant(content),
                isStreaming: true,
              ),
            );
          }

          // ---- 普通消息 ----
          return _wrapBubble(MessageBubble(message: widget.messages[index]));
        },
      ),
    );
  }

  /// 包裹消息气泡：在存在内容宽度限制时居中约束（null 时原样返回 = 满屏）。
  Widget _wrapBubble(Widget bubble) {
    final maxWidth = widget.contentMaxWidth;
    if (maxWidth == null) return bubble;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: bubble,
      ),
    );
  }
}