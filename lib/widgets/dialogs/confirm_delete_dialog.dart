import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../app/theme.dart';

/// 统一的删除确认对话框
///
/// 用于所有需要确认删除的场景（母版级联删除、子版删除、批量删除）。
/// 统一了标题、红色删除按钮和取消按钮的样式。
class ConfirmDeleteDialog {
  /// 弹出删除确认对话框。
  ///
  /// 参数：
  ///   - title: 对话框标题（如「删除契约」）
  ///   - message: 确认消息（如「确定要删除...」）
  ///
  /// 返回值：用户确认删除返回 true，取消返回 false。
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).confirmDeleteCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).confirmDeleteDelete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}