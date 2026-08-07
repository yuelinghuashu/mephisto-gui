import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../domain/narrative_state.dart';
import '../contract_panel.dart';

/// 仪表盘抽屉：展示当前契约的所有数据
///
/// 复用共享 [ContractPanel] 组件，与首页预览使用同一套展示逻辑。
class DashboardDrawer extends StatelessWidget {
  /// 叙事状态（包含契约、运行时状态、记忆、历史）
  final NarrativeState state;

  const DashboardDrawer({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      // 从右侧滑出的抽屉宽度约 320
      width: 320,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 标题栏 ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
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
                ],
              ),
            ),
            const Divider(height: 1),
            // ---- 契约数据面板（复用共享组件，传运行时状态/记忆/历史） ----
            Expanded(
              child: ContractPanel(
                contract: state.contract,
                currentState: state.currentState,
                memories: state.memories,
                history: state.history,
              ),
            ),
          ],
        ),
      ),
    );
  }
}