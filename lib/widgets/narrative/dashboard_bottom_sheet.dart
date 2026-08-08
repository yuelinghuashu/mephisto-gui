import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../domain/narrative_state.dart';
import '../contract_panel.dart';

/// 移动端仪表盘：从底部弹出面板展示契约数据。
///
/// 桌面端使用右侧抽屉（[DashboardDrawer]），
/// 移动端屏幕较窄，改为底部弹出更符合操作习惯：
///   - 高度约占屏幕 75%
///   - 顶部显示拖动把手 + 标题 + 关闭按钮
///   - 内容复用 [ContractPanel] 契约数据面板
class DashboardBottomSheet extends StatelessWidget {
  /// 叙事状态（包含契约、运行时状态、记忆、历史）
  final NarrativeState state;

  const DashboardBottomSheet({super.key, required this.state});

  /// 弹出底部面板的便捷入口。
  static Future<void> show(BuildContext context, NarrativeState state) {
    return showModalBottomSheet<void>(
      context: context,
      // 圆角面板（顶角）
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // 背景色跟随主题表面色
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // 允许向下拖动关闭
      isScrollControlled: true,
      // 高度约占屏幕 75%，给内容留出充足空间
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75,
        child: SafeArea(
          child: DashboardBottomSheet(state: state),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- 顶部拖动把手 ----
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // ---- 标题栏 ----
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            children: [
              const Text(
                '⚜',
                style: TextStyle(fontSize: 20, color: AppTheme.gold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).narrativeDashboard,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: AppLocalizations.of(context).narrativeClose,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ---- 契约数据面板（复用共享组件） ----
        Expanded(
          child: ContractPanel(
            contract: state.contract,
            currentState: state.currentState,
            memories: state.memories,
            history: state.history,
          ),
        ),
      ],
    );
  }
}