import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../services/storage/contract_repo.dart';

/// 重命名契约对话框
///
/// 支持双输入：
///   - 新文件名（必填，复用通用校验：非空 + .meph 后缀 + 重名校验）
///   - 命运说明（可选，仅子版/已有 @命运 区块时显示）——重命名时可同时
///     编辑展示在首页的「命运一句话」
///
/// 内部使用 [_RenameDialogBody] 管理双 [TextEditingController] 生命周期。
class RenameContractDialog {
  /// 弹出重命名对话框。
  ///
  /// 参数：
  ///   - currentName: 当前文件名（作为输入框初始值）
  ///   - initialBranchTitle: 当前命运说明（预填；null = 无）
  ///   - showBranchTitleField: 是否显示命运说明输入框
  ///     （子版/已有 @命运 区块时为 true，母版为 false）
  ///
  /// 返回值：`(新文件名, 命运说明?)`；命运说明为 null 表示未填写/未修改，
  ///   取消/Esc 返回 null。
  static Future<(String, String?)?> show(
    BuildContext context, {
    required String currentName,
    String? initialBranchTitle,
    bool showBranchTitleField = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return showDialog<(String, String?)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RenameDialog(
        currentName: currentName,
        initialBranchTitle: initialBranchTitle,
        showBranchTitleField: showBranchTitleField,
        l10n: l10n,
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String currentName;
  final String? initialBranchTitle;
  final bool showBranchTitleField;
  final AppLocalizations l10n;

  const _RenameDialog({
    required this.currentName,
    required this.initialBranchTitle,
    required this.showBranchTitleField,
    required this.l10n,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.currentName,
  );
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialBranchTitle ?? '',
  );

  /// 异步校验进行中标志（校验期间禁用确认按钮，防止连点重复提交）
  bool _isValidating = false;

  /// 异步校验错误消息（展示在输入框 errorText）
  String? _asyncError;

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// 提交逻辑：同步校验 → 异步校验 → 通过则关闭对话框并返回结果。
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    // 1. 同步校验（非空 + .meph 后缀）
    if (name.isEmpty || !name.endsWith('.meph')) return;

    // 2. 异步重名校验：目标名存在且不是当前文件名时拦截
    if (name != widget.currentName) {
      if (_isValidating) return;
      setState(() {
        _isValidating = true;
        _asyncError = null;
      });
      final available = await isContractNameAvailable(name);
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _asyncError = available ? null : widget.l10n.renameDialogNameExists;
      });
      if (!available) return;
    }

    // 3. 通过 → 返回 (新文件名, 命运说明)
    final title = _titleController.text.trim();
    Navigator.pop(context, (name, title.isEmpty ? null : title));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.renameDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.l10n.renameDialogLabel,
              helperText: widget.l10n.renameDialogHelper,
              errorText: _asyncError,
            ),
            onSubmitted: (_) => _submit(),
          ),
          // 命运说明输入框（仅子版/已有 @命运 区块时显示）
          if (widget.showBranchTitleField) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: widget.l10n.renameDialogBranchTitleLabel,
                hintText: widget.l10n.renameDialogBranchTitleHint,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.textInputDialogCancel),
        ),
        FilledButton(
          onPressed: _isValidating ? null : _submit,
          child: Text(widget.l10n.renameDialogConfirm),
        ),
      ],
    );
  }
}
