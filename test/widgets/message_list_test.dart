import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/widgets/narrative/message_list.dart';

import 'test_helpers.dart';

/// 叙事消息列表 Widget 测试
///
/// 重点验证滚动定位行为：
///   - 打开已有历史的列表（如加载子版）时，应直接看到最新消息（滚动到底部）
///   - 空列表（母版开局）时不应异常
void main() {
  /// 构造 [count] 条角色消息（用于撑起可滚动的高度）。
  List<Message> buildMessages(int count) => [
    for (var i = 1; i <= count; i++) Message.assistant('消息 $i'),
  ];

  /// 读取 [MessageList] 内 ListView 的滚动位置。
  ScrollPosition positionOf(WidgetTester tester) {
    final listView = tester.widget<ListView>(find.byType(ListView));
    return listView.controller!.position;
  }

  Widget buildList({
    required List<Message> messages,
    double height = 200,
    bool isGenerating = false,
  }) {
    return localizedApp(
      home: Scaffold(
        body: SizedBox(
          height: height,
          child: MessageList(
            messages: messages,
            streamingContent: '',
            isGenerating: isGenerating,
          ),
        ),
      ),
    );
  }

  testWidgets('挂载含完整历史的列表后：滚动到底部（直接看到最新消息）', (tester) async {
    await tester.pumpWidget(buildList(messages: buildMessages(60)));
    // 触发 initState 中的 postFrameCallback（jumpTo 到底部）
    await tester.pump();

    final position = positionOf(tester);
    // 已滚动到底部（允许 1px 浮点误差）
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    // 且确实离开了顶部（验证不是停留在开头）
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('挂载空列表（母版开局）：不崩溃且停留在顶部', (tester) async {
    await tester.pumpWidget(buildList(messages: const []));
    // 触发 initState 中的 postFrameCallback
    await tester.pump();

    final position = positionOf(tester);
    expect(position.maxScrollExtent, 0);
    expect(position.pixels, 0);
  });

  testWidgets('挂载少量消息（不超过视口）：停在顶部且无滚动', (tester) async {
    await tester.pumpWidget(buildList(messages: buildMessages(2)));
    await tester.pump();

    final position = positionOf(tester);
    // 内容不足一屏时 maxScrollExtent 为 0，jumpTo 无副作用
    expect(position.maxScrollExtent, 0);
    expect(position.pixels, 0);
  });

  testWidgets('发送新消息触发的 didUpdateWidget 平滑滚动仍可用', (tester) async {
    final messages = buildMessages(60);
    await tester.pumpWidget(buildList(messages: messages));
    await tester.pump();

    // 注意：必须使用「新 List 引用」而非在原列表上 append——
    // 若复用同一 List，oldWidget.messages 与 widget.messages 指向同一对象，
    // length 比较永远相等，didUpdateWidget 无法感知变化。
    final updated = [...messages, Message.assistant('新消息')];
    await tester.pumpWidget(buildList(messages: updated));
    // 等待平滑滚动动画（250ms）完成
    await tester.pumpAndSettle();

    final position = positionOf(tester);
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
  });
}
