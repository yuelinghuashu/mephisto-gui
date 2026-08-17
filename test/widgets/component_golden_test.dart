import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/app/theme.dart';
import 'package:mephisto/domain/contract_tree_builder.dart';
import 'package:mephisto/domain/models.dart';
import 'package:mephisto/domain/stage_models.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:mephisto/widgets/home/contract_card.dart';
import 'package:mephisto/widgets/home/stage_card.dart';
import 'package:mephisto/widgets/narrative/message_bubble.dart';

/// 核心组件 UI 黄金基准（Golden Tests）
///
/// 用途：对主题化组件建立视觉基线，任何布局/配色/间距回归都会使
/// 像素 diff 失败——弥补纯逻辑测试看不到的视觉退化（尤其配合本次
/// 窄监听/气泡缓存等 UI 重构，防止流式布局漂移类隐性回归）。
///
/// 环境说明：测试环境使用 Flutter 默认字体（Ahem，确定性渲染），
/// 与真机字体无关，因此 golden 在 CI 与本地一致、可稳定复现。
/// 更新基准：`flutter test --update-goldens test/widgets/component_golden_test.dart`
///
/// 平台：golden 与 platform 无关（不涉及平台字体/图标差异），
/// 但建议在 ubuntu CI 上生成/校验（与本地一致）。
void main() {
  /// 固定尺寸画布：保证 golden 稳定（不依赖窗口大小）。
  /// 必须配置本地化委托（与生产 app.dart 一致），否则
  /// `AppLocalizations.of(context)` 在组件内为 null 会抛错。
  Widget canvas(Widget child, {double width = 400, double height = 200}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('MessageBubble golden', () {
    testWidgets('命运消息：右对齐金色气泡', (tester) async {
      await tester.pumpWidget(
        canvas(MessageBubble(message: Message.fate('我仰望星空'))),
      );
      await expectLater(
        find.byType(MessageBubble),
        matchesGoldenFile('goldens/message_bubble_fate.png'),
      );
    });

    testWidgets('角色消息：左对齐卡片色气泡', (tester) async {
      await tester.pumpWidget(
        canvas(MessageBubble(message: Message.assistant('浮士德沉默着。'))),
      );
      await expectLater(
        find.byType(MessageBubble),
        matchesGoldenFile('goldens/message_bubble_assistant.png'),
      );
    });

    testWidgets('系统消息：居中标签样式', (tester) async {
      await tester.pumpWidget(
        canvas(MessageBubble(message: Message.system('⚖ 命运裁决'))),
      );
      await expectLater(
        find.byType(MessageBubble),
        matchesGoldenFile('goldens/message_bubble_system.png'),
      );
    });
  });

  group('ContractCard golden', () {
    testWidgets('契约卡：单行紧凑（母版 + 分支徽标）', (tester) async {
      final group = ContractGroup(
        master: ContractInfo(
          fileName: 'faust.meph',
          roleName: '浮士德',
        ),
        children: [
          ContractGroup(
            master: ContractInfo(
              fileName: 'faust.dark.meph',
              roleName: '浮士德',
              isChild: true,
              branchName: 'dark',
            ),
            children: const [],
          ),
        ],
      );
      await tester.pumpWidget(
        canvas(
          ContractCard(
            group: group,
            isSelectMode: false,
            isSelected: false,
            onTap: () {},
            onLongPress: () {},
            onMenu: (_) {},
            onBranchTap: (_) {},
          ),
        ),
      );
      await expectLater(
        find.byType(ContractCard),
        matchesGoldenFile('goldens/contract_card.png'),
      );
    });
  });

  group('StageCard golden', () {
    testWidgets('舞台卡：单行 + 角色芯片（含存档徽标）', (tester) async {
      await tester.pumpWidget(
        canvas(
          StageCard(
            info: const StageInfo(
              path: '/contracts/Kurukshetra',
              name: 'Kurukshetra',
              characterCount: 2,
            ),
            roleNames: const ['阿周那', '迦尔纳'],
            savedRoleNames: const {'阿周那'},
            onTap: () {},
          ),
          height: 120,
        ),
      );
      await expectLater(
        find.byType(StageCard),
        matchesGoldenFile('goldens/stage_card.png'),
      );
    });
  });
}
