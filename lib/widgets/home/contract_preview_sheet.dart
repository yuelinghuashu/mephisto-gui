import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../providers/contract_provider.dart';
import '../../services/parser/meph_parser.dart';
import '../../services/storage/contract_repo.dart';
import '../contract_panel.dart';

/// 契约预览底部 Sheet
///
/// 读取 .meph 文件内容并解析为结构化 [Contract]，
/// 使用共享 [ContractPanel] 结构化展示全部区块数据。
class ContractPreviewSheet {
  /// 显示预览
  ///
  /// 参数：
  ///   - context: 用于显示 SnackBar 和 BottomSheet 的 BuildContext
  ///   - info: 契约信息（文件名）
  ///
  /// 返回值：Future 完成表示 Sheet 已关闭
  static Future<void> show(BuildContext context, ContractInfo info) async {
    // 读取 .meph 文件并解析为结构化契约
    final content = await readContract(info.fileName);
    if (content == null) return;

    final Contract contract;
    try {
      contract = parseMeph(content);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('╳ 解析失败: $e')),
      );
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceVariant(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        // 预览面板高度占屏幕 85%，使用共享 ContractPanel 结构化展示
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
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
                        info.fileName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 正文内容（结构化契约数据面板）
              Expanded(
                child: ContractPanel(contract: contract),
              ),
            ],
          ),
        );
      },
    );
  }
}