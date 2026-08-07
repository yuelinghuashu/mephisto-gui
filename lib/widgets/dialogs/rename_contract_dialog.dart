import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../services/storage/contract_repo.dart';
import 'text_input_dialog.dart';

/// 重命名契约对话框
///
/// 复用通用文本输入对话框 [TextInputDialog]，
/// 统一了输入框校验（非空 + .meph 后缀）和回车快速提交。
///
/// 新增异步重名校验：目标文件名已存在（非自身）时，在输入框错误提示
/// 并阻止提交，避免提交后才由 [renameContract] 静默失败。
class RenameContractDialog {
  /// 弹出重命名对话框。
  ///
  /// 参数：
  ///   - currentName: 当前文件名（作为输入框初始值）
  ///
  /// 返回值：用户确认的新文件名；取消返回 null。
  static Future<String?> show(
    BuildContext context, {
    required String currentName,
  }) {
    final l10n = AppLocalizations.of(context);
    return TextInputDialog.show(
      context,
      title: l10n.renameDialogTitle,
      labelText: l10n.renameDialogLabel,
      helperText: l10n.renameDialogHelper,
      confirmText: l10n.renameDialogConfirm,
      initialValue: currentName,
      validate: (value) => value.isNotEmpty && value.endsWith('.meph'),
      // 异步重名校验：目标名存在且不是当前文件名时拦截并展示错误
      validateAsync: (newName) async {
        if (newName == currentName) return null; // 重命名为自身合法
        final available = await isContractNameAvailable(newName);
        return available ? null : l10n.renameDialogNameExists;
      },
    );
  }
}