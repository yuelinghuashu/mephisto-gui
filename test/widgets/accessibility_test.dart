import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/app/theme.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/domain/stage_models.dart';
import 'package:mephisto/domain/stage_narrative_state.dart';
import 'package:mephisto/widgets/home/role_chip.dart';
import 'package:mephisto/widgets/narrative/input_bar.dart';
import 'package:mephisto/widgets/narrative/message_bubble.dart';
import 'package:mephisto/widgets/narrative/role_status_bar.dart';
import 'package:mephisto/widgets/narrative/status_bar.dart';

import 'test_helpers.dart';

/// 无障碍（读屏语义 + 点击目标）测试
///
/// 覆盖方向 B 的落地：
///   - 状态条/角色状态芯片：合并语义（读屏一次性朗读，而非逐段朗读 emoji）
///   - 消息气泡操作菜单：可被读屏识别为按钮
///   - 附件移除按钮 / 角色芯片：热区 ≥ 32px（触屏最小点击目标）
void main() {
  Widget wrap(Widget child) {
    return localizedApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  /// 启用语义树并返回 handle（测试结束必须显式 dispose，
  /// 框架在 tearDown 之前校验 handle 已释放，故不能用 addTearDown）。
  SemanticsHandle enableSemantics(WidgetTester tester) =>
      tester.ensureSemantics();

  /// 从语义树中收集所有节点的 label，便于断言「合并语义」。
  List<String> collectSemanticLabels(WidgetTester tester, Finder finder) {
    final node = tester.getSemantics(finder);
    final labels = <String>[];
    node.visitChildren((child) {
      // 本版本 child.label 为非空 String
      if (child.label.isNotEmpty) labels.add(child.label);
      return true;
    });
    // 自身 label 也纳入（若存在）
    if (node.label.isNotEmpty) {
      labels.add(node.label);
    }
    return labels;
  }

  group('状态条合并语义（读屏一次朗读）', () {
    testWidgets('StatusBar：单一合并 label 包含「规则 N」且不逐段朗读 emoji', (tester) async {
      final handle = enableSemantics(tester);
      await tester.pumpWidget(
        wrap(const StatusBar(ruleCount: 12, memoryCount: 5, historyCount: 3)),
      );

      // 整条状态条应存在合并语义标签：包含「规则 12 条」格式
      final labels = collectSemanticLabels(tester, find.byType(StatusBar));
      expect(
        labels.any((l) => l.contains('规则') && l.contains('12')),
        isTrue,
        reason: '读屏应朗读「规则 12 条」类合并标签',
      );
      // emoji 不应作为独立语义被朗读（excludeSemantics 已排除）
      expect(
        labels.any((l) => l.contains('⚡')),
        isFalse,
        reason: 'emoji 图标不应被单独朗读',
      );
      handle.dispose();
    });

    testWidgets('RoleStatusChip：合并 label 包含角色名与计数', (tester) async {
      final handle = enableSemantics(tester);
      await tester.pumpWidget(
        wrap(
          // 非 const：Memory 构造非 const，需运行时创建
          RoleStatusBar(
            stage: const StageLoaded(
              info: StageInfo(path: '/s', name: 'S', characterCount: 1),
              characters: [
                StageCharacter(
                  fileName: 'a.meph',
                  contract: Contract(roleName: '浮士德'),
                ),
              ],
            ),
            roles: {
              '浮士德': RoleRunState(
                currentState: const {'灵魂': IntValue(50)},
                memories: [Memory(content: '契约')],
              ),
            },
          ),
        ),
      );

      final labels = collectSemanticLabels(tester, find.byType(RoleStatusChip));
      expect(
        // 状态计数 = 状态条目数（1），记忆计数 = 记忆条数（1）
        labels.any((l) => l.contains('浮士德') && l.contains('状态 1 项') && l.contains('记忆 1 条')),
        isTrue,
        reason: '读屏应朗读「浮士德 状态 1 项，记忆 1 条」类合并标签',
      );
      handle.dispose();
    });
  });

  group('消息气泡操作菜单语义', () {
    testWidgets('消息气泡长按菜单入口被识别为按钮', (tester) async {
      final handle = enableSemantics(tester);
      await tester.pumpWidget(
        wrap(MessageBubble(message: Message.assistant('浮士德沉默着。'))),
      );

      // 语义树中应存在 button 节点（菜单入口）：用栈手动遍历所有后代
      final node = tester.getSemantics(find.byType(MessageBubble));
      var foundButton = false;
      final stack = <SemanticsNode>[node];
      while (stack.isNotEmpty) {
        final n = stack.removeLast();
        // ignore: deprecated_member_use - hasFlag 仍可用；测试断言用位标志更直观
        if (n.hasFlag(SemanticsFlag.isButton)) {
          foundButton = true;
          break;
        }
        n.visitChildren((child) {
          stack.add(child);
          return true;
        });
      }
      expect(foundButton, isTrue, reason: '气泡应暴露可打开菜单的按钮语义');
      handle.dispose();
    });
  });

  group('点击目标 ≥ 32px（触屏最小热区）', () {
    testWidgets('附件移除按钮热区 ≥ 32×32', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 200,
            child: InputBar(
              isGenerating: false,
              onSend: _noopSend,
              onStop: _noop,
              showAttachment: true,
              attachedFileNames: ['附件.txt'],
            ),
          ),
        ),
      );

      // 找到移除按钮（close 图标）
      final closeIcon = find.byIcon(Icons.close);
      expect(closeIcon, findsOneWidget);
      final removeHitArea = tester.getSize(
        find.ancestor(
          of: closeIcon,
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(removeHitArea.width, greaterThanOrEqualTo(32));
      expect(removeHitArea.height, greaterThanOrEqualTo(32));
    });

    testWidgets('角色芯片热区高度 ≥ 32', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoleChip(
            roleName: '阿周那',
            color: AppTheme.gold,
            onTap: _noop,
            onLongPress: _noop,
          ),
        ),
      );
      // 芯片的 InkWell 命中区域应 ≥ 32px 高（内部 Container 有 minHeight）
      final chip = tester.getSize(
        find.ancestor(
          of: find.text('阿周那'),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(chip.height, greaterThanOrEqualTo(32));
    });
  });
}

void _noop() {}

void _noopSend(String _) {}
