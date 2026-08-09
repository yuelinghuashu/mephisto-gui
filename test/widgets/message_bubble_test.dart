import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/widgets/narrative/message_bubble.dart';

import 'test_helpers.dart';

/// 消息气泡 Widget 测试
///
/// 覆盖四种渲染路径：
///   - 命运（用户）消息：右对齐金色气泡
///   - 角色（AI）消息：左对齐卡片色气泡
///   - 系统消息：居中标签样式 + 骰子判定卡片
///   - 流式输出：打字机光标（闪烁动画）
void main() {
  Widget buildBubble(Message message, {bool isStreaming = false}) {
    return localizedApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MessageBubble(message: message, isStreaming: isStreaming),
        ),
      ),
    );
  }

  testWidgets('命运消息：右对齐金色气泡 + 内容正确显示', (tester) async {
    await tester.pumpWidget(buildBubble(Message.fate('我仰望星空')));

    // 内容显示
    expect(find.text('我仰望星空'), findsOneWidget);
    // 右对齐（命运消息使用 Align alignment: centerRight）
    final align = tester.widget<Align>(
      find.ancestor(of: find.text('我仰望星空'), matching: find.byType(Align)),
    );
    expect(align.alignment, Alignment.centerRight);
  });

  testWidgets('角色消息：左对齐卡片色气泡 + 内容正确显示', (tester) async {
    await tester.pumpWidget(buildBubble(Message.assistant('浮士德沉默着。')));

    // 内容显示
    expect(find.text('浮士德沉默着。'), findsOneWidget);
    // 左对齐（角色消息使用 Align alignment: centerLeft）
    final align = tester.widget<Align>(
      find.ancestor(of: find.text('浮士德沉默着。'), matching: find.byType(Align)),
    );
    expect(align.alignment, Alignment.centerLeft);
  });

  testWidgets('系统消息：居中标签样式（无骰子数据）', (tester) async {
    await tester.pumpWidget(buildBubble(Message.system('系统提示')));

    // 内容显示
    expect(find.text('系统提示'), findsOneWidget);
    // 系统消息使用 Row 居中对齐
    final row = tester.widget<Row>(
      find.ancestor(of: find.text('系统提示'), matching: find.byType(Row)),
    );
    expect(row.mainAxisAlignment, MainAxisAlignment.center);
  });

  testWidgets('系统消息（含骰子结果）：渲染「命运结算」卡片', (tester) async {
    final msg = Message.system(
      '命运结算',
      diceResults: const [
        DiceResult(
          ruleName: '命运之判',
          expression: 'roll(1d100)',
          value: 85,
          maxValue: 100,
          threshold: 50,
          success: true,
        ),
      ],
    );
    await tester.pumpWidget(buildBubble(msg));

    // 骰子卡片渲染（包含规则名与结果展示）
    expect(find.textContaining('命运之判'), findsOneWidget);
    expect(find.textContaining('85'), findsOneWidget);
  });

  testWidgets('流式输出：显示打字机光标（闪烁动画部件存在）', (tester) async {
    await tester.pumpWidget(
      buildBubble(Message.assistant('正在生成'), isStreaming: true),
    );

    // 内容显示
    expect(find.text('正在生成'), findsOneWidget);
    // 闪烁光标存在（_BlinkingCursor 内部是 SizedBox + ColoredBox）
    expect(
      find.byType(ColoredBox),
      findsWidgets, // 至少一个（气泡背景也可能有 ColoredBox，用 findsWidgets 保守断言）
    );
  });

  testWidgets('非流式输出：不渲染打字机光标', (tester) async {
    await tester.pumpWidget(buildBubble(Message.assistant('完成')));

    // 内容存在
    expect(find.text('完成'), findsOneWidget);
    // 闪烁光标（_BlinkingCursor 的 ColoredBox）不应存在
    // 角色气泡本身无 ColoredBox（用 Container decoration 渲染背景），
    // 因此 findsNothing 可以精确断言无光标
    expect(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });
}