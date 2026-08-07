import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

/// 「另存为分支」对话框：输入分支名 + 可选「命运说明」。
///
/// 命运说明是这条支流的一句话描述，以 `@命运:` 标记写入子版【角色背景】，
/// 首页据此以「命运一句话」展示该分支（分支名仍保留显示）。
///
/// 与通用 [TextInputDialog] 不同，本对话框需要**双输入**（分支名必填、
/// 命运说明可选），因此独立封装，避免侵入通用单输入对话框。
class SaveBranchDialog {
  /// 弹出「另存为分支」对话框。
  ///
  /// 返回值：
  ///   - 用户确认：`(branchName, branchTitle?)`（branchTitle 可空 = 未填写）
  ///   - 取消/Esc：null
  static Future<(String, String?)?> show(
    BuildContext context, {
    String initialBranchName = '',
  }) {
    return showDialog<(String, String?)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaveBranchDialog(initialBranchName: initialBranchName),
    );
  }
}

class _SaveBranchDialog extends StatefulWidget {
  final String initialBranchName;

  const _SaveBranchDialog({this.initialBranchName = ''});

  @override
  State<_SaveBranchDialog> createState() => _SaveBranchDialogState();
}

class _SaveBranchDialogState extends State<_SaveBranchDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialBranchName,
  );
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    // State.dispose 在 widget 完全移除后由框架调用，此时 TextField 已不再引用
    _nameController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final branchName = _nameController.text.trim();
    if (branchName.isEmpty) return; // 分支名必填
    final branchTitle = _titleController.text.trim();
    Navigator.pop(
      context,
      (branchName, branchTitle.isEmpty ? null : branchTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.narrativeBranchDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.narrativeBranchLabel,
              hintText: l10n.narrativeBranchHint,
            ),
            // 回车：若分支名已填则提交；否则聚焦命运说明（或保持）
            onSubmitted: (_) {
              if (_nameController.text.trim().isNotEmpty) _submit();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.narrativeBranchTitleLabel,
              hintText: l10n.narrativeBranchTitleHint,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.textInputDialogCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.narrativeConfirm),
        ),
      ],
    );
  }
}