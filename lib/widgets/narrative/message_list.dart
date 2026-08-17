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

  /// 自定义气泡构建器（null 时使用标准 [MessageBubble]）
  ///
  /// 多角色舞台传入 [StageMessageBubble] 实现按角色着色；
  /// 单角色叙事不传 → 保持默认行为。
  final Widget Function(Message message, bool isStreaming)? messageBuilder;

  /// 重新生成回调（单角色叙事；index 为消息索引）
  final void Function(int index)? onRegenerate;

  const MessageList({
    super.key,
    required this.messages,
    required this.streamingContent,
    required this.isGenerating,
    this.contentMaxWidth,
    this.messageBuilder,
    this.onRegenerate,
  });

  @override
  MessageListState createState() => MessageListState();
}

/// [MessageList] 的状态，暴露滚动控制方法。
///
/// 通过 `GlobalKey<MessageListState>` 从外部（如 AppBar 按钮、快捷键）控制
/// 消息列表跳转至第一条 / 最后一条历史。
class MessageListState extends State<MessageList> {
  /// 滚动到底部判定容差（px）。
  ///
  /// 用户滚动位置距离真正底部在此范围内视为「在底部」，
  /// 恢复自动跟随；超出此范围视为离开底部，暂停自动跟随。
  static const double bottomTolerancePx = 8;

  /// 离开底部判定阈值偏移（px）。
  ///
  /// 从底部向上滚动超过此偏移才判定为「离开底部」——
  /// 避免用户在底部附近的微小滚动误触发暂停自动跟随。
  static const double leaveBottomThresholdPx = 24;

  /// 顶部附近判定阈值（px）。
  ///
  /// 滚动位置在此范围内视为「在顶部」——用于智能跳转按钮
  /// 决定点击时应跳到顶部还是底部。
  static const double nearTopThresholdPx = 100;

  /// 当前是否在消息列表顶部附近（智能跳转按钮的图标/方向依据）。
  ///
  /// 由 [_onScroll] 在滚动事件中维护，外部通过 [ValueListenable]
  /// 监听变化即可实时切换图标方向。
  final ValueNotifier<bool> isNearTop = ValueNotifier<bool>(true);

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
    isNearTop.dispose();
    super.dispose();
  }

  /// 监听滚动位置：顶部以下视为"离开底部"暂停跟随；滚回底部恢复跟随。
  ///
  /// 同时维护 [isNearTop]（顶部附近判定，驱动智能跳转按钮的图标方向）。
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom =
        position.pixels >= position.maxScrollExtent - bottomTolerancePx;
    if (atBottom) {
      _autoFollowBottom = true;
    } else if (position.pixels <
        position.maxScrollExtent - leaveBottomThresholdPx) {
      // 明显离开底部才暂停（避免微小偏移误触发）
      _autoFollowBottom = false;
    }

    // 顶部附近判定（智能跳转按钮图标切换依据）
    final nearTop = position.pixels <= nearTopThresholdPx;
    if (isNearTop.value != nearTop) {
      isNearTop.value = nearTop;
    }
  }

  /// 新消息/流式内容到来时：若正在跟随底部则滚动到底部。
  ///
  /// 滚动策略区分两种场景：
  ///   - 消息**条数**变化（新消息入列）→ 平滑滚动（250ms，视觉自然）
  ///   - 流式**内容增长**（streamingContent 每 50ms 变化）→ 直接 `jumpTo`
  ///     直落底部：逐 chunk 重启 250ms 动画会造成「追尾抖动」并每 50ms
  ///     入队一次动画回调，故流式增长不走动画。
  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_autoFollowBottom) return;
    final countChanged =
        widget.messages.length != oldWidget.messages.length;
    final contentChanged =
        widget.streamingContent != oldWidget.streamingContent ||
        widget.isGenerating != oldWidget.isGenerating;
    if (countChanged) {
      // 新消息入列：平滑滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    } else if (contentChanged && widget.isGenerating) {
      // 流式内容增长：jumpTo 直落底部（不触发动画，避免追尾抖动）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
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

  /// 按滚轮增量滚动，位置 clamped 在 `[0, maxScrollExtent]` 内。
  ///
  /// 供外部区域（如 [RoleStatusBar] 的垂直滚轮委托）将滚轮事件路由到
  /// 消息流，实现「鼠标在状态条上滚动也能带动消息流」的桌面端体验。
  void scrollBy(double deltaY) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + deltaY)
        .clamp(0.0, position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  /// 智能跳转：在顶部附近 → 跳到最底部；否则 → 跳到最顶部。
  ///
  /// 替代原来的「跳顶 + 跳底」双按钮，合并为单一按钮按位置智能决定方向，
  /// 移动端仍保留一键滚动能力（不依赖键盘快捷键）。
  void scrollTopOrBottom() {
    if (!_scrollController.hasClients) return;
    if (isNearTop.value) {
      scrollToBottom();
    } else {
      scrollToTop();
    }
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
            // 独立 StatefulWidget：流式 chunk 高频到达时，仅在内容实际
            // 变化时重建 Message 对象——避免每次 chunk 都执行
            // `Message.assistant()` 的 `_generateUniqueId()` + `DateTime.now()`
            // 与 `AppLocalizations.of(context)` 查找
            return _wrapBubble(
              _StreamingBubble(
                content: widget.streamingContent,
                showPlaceholder: widget.streamingContent.isEmpty,
                // 透传 messageBuilder：使舞台页流式输出也能走
                // [StageMessageBubble]（角色着色），而非绕回标准气泡
                messageBuilder: widget.messageBuilder,
              ),
            );
          }

          // ---- 普通消息 ----
          // 用 _CachedBubble 包裹：流式 chunk 高频重建列表时，历史消息的
          // Message 对象内容未变（Equatable 按内容比较相等），缓存的气泡
          // 子树直接复用，不再对每条可见历史消息重跑 Markdown 解析
          // （ParagraphText.build），显著降低长叙事下的流式开销。
          return _CachedBubble(
            message: widget.messages[index],
            builder: (message) {
              final bubble =
                  widget.messageBuilder?.call(message, false) ??
                  MessageBubble(
                    message: message,
                    onRegenerate: widget.onRegenerate == null
                        ? null
                        : () => widget.onRegenerate!(index),
                  );
              return _wrapBubble(bubble);
            },
          );
        },
      ),
    );
  }

  /// 包裹消息气泡：在存在内容宽度限制时居中约束（null 时原样返回 = 满屏）。
  ///
  /// 每个气泡外层包 [RepaintBoundary]：流式输出时 [streamingContent] 频繁
  /// 变化触发列表重建，但**未变化的气泡**被隔离在独立图层中无需重绘，
  /// 显著降低流式输出时的 UI 开销。
  Widget _wrapBubble(Widget bubble) {
    final maxWidth = widget.contentMaxWidth;
    if (maxWidth == null) {
      return RepaintBoundary(child: bubble);
    }
    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: bubble,
        ),
      ),
    );
  }
}

/// 消息气泡缓存（按内容短路）
///
/// 流式输出期间 [MessageList.build] 每 50ms 重建一次，itemBuilder 会对
/// 全部可见项重新执行。历史消息的 [Message] 内容未变（Equatable 按内容
/// 比较相等），但每次 rebuild 都会重新走一遍
/// `MessageBubble → ParagraphText → Markdown 正则解析`——长叙事下成本
/// 随可见消息数线性增长。
///
/// 本组件在 [didUpdateWidget] 中按「message 内容是否变化」短路：
/// 内容未变时复用已构建的气泡子树（Flutter 对相同 child 实例跳过重建），
/// 仅当消息内容真正变化（新回复入列/重新生成）时才重建气泡。
class _CachedBubble extends StatefulWidget {
  /// 当前消息（Equatable 按内容比较）
  final Message message;

  /// 气泡构建器（惰性调用：仅首次构建或内容变化时执行）
  final Widget Function(Message message) builder;

  const _CachedBubble({required this.message, required this.builder});

  @override
  State<_CachedBubble> createState() => _CachedBubbleState();
}

class _CachedBubbleState extends State<_CachedBubble> {
  /// 上次构建时的消息（用于内容变化检测）
  late Message _lastMessage = widget.message;

  /// 已构建的气泡子树（内容未变时复用）
  late Widget _cachedChild = _build();

  /// 构建气泡子树（仅在首次/内容变化时执行）。
  Widget _build() {
    return widget.builder(widget.message);
  }

  @override
  void didUpdateWidget(_CachedBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 内容未变 → 复用缓存子树，不重建（避免每 chunk 重跑 Markdown 解析）
    if (widget.message != _lastMessage) {
      _lastMessage = widget.message;
      _cachedChild = _build();
    }
  }

  @override
  Widget build(BuildContext context) => _cachedChild;
}

/// 流式输出气泡（独立 StatefulWidget）
///
/// 优化核心：LLM 流式 chunk 以 50ms 节流窗口高频到达，[MessageList.build]
/// 每次重建都会调用 itemBuilder。若在此处直接 `Message.assistant(content)`，
/// 每次都会触发 `_generateUniqueId()`（全局计数器 + DateTime.now()）与
/// `AppLocalizations.of(context)` 查找——大量无意义对象分配。
///
/// 本组件将 Message 对象的构造交给 [didUpdateWidget]：仅当内容**实际变化**
/// 时才更新内部缓存的 [Message]；内容相同时（发生 rebuild 但 content 未变）
/// 直接复用缓存对象，避免每轮 builder 都构造新 Message。
class _StreamingBubble extends StatefulWidget {
  /// 当前流式内容（空时由 showPlaceholder 决定是否显示占位文案）
  final String content;

  /// 内容为空时是否显示「思考中...」占位
  final bool showPlaceholder;

  /// 自定义气泡构建器（与 [MessageList.messageBuilder] 一致；
  /// null 时使用标准 [MessageBubble]）
  final Widget Function(Message message, bool isStreaming)? messageBuilder;

  const _StreamingBubble({
    required this.content,
    required this.showPlaceholder,
    this.messageBuilder,
  });

  @override
  State<_StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<_StreamingBubble> {
  /// 缓存的 Message 对象（仅在内容变化时重建）
  late Message _message = _buildMessage(widget.content);

  /// 构造流式 Message（仅承载内容，Message.assistant 无 isStreaming 参数；
  /// 流式状态由外部 MessageBubble 的 isStreaming 决定）
  static Message _buildMessage(String content) {
    return Message.assistant(content);
  }

  @override
  void didUpdateWidget(_StreamingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅在内容实际变化时重建 Message 对象
    if (oldWidget.content != widget.content) {
      _message = _buildMessage(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 内容为空且需占位时显示「思考中...」本地化文案
    // （仅有此状态才做 l10n 查找；流式内容非空时直接使用缓存 Message）
    final displayMessage = widget.content.isEmpty && widget.showPlaceholder
        ? Message.assistant(AppLocalizations.of(context).messageBubbleThinking)
        : _message;
    // 优先走 messageBuilder（舞台页角色着色）；null 时退回标准气泡
    final bubble =
        widget.messageBuilder?.call(displayMessage, true) ??
        MessageBubble(message: displayMessage, isStreaming: true);
    return bubble;
  }
}
