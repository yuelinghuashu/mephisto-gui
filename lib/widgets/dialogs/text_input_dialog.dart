import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

/// 通用文本输入对话框
///
/// 统一「输入一个文本值」的对话框交互模式：
///   - 回车（Enter/软键盘完成）= 确认提交
///   - 取消按钮 / Esc = 返回 null
///
/// 校验支持两级：
///   - 同步 [TextInputDialog.show] 的 [show] 参数 `validate`（如非空、后缀检查）
///   - 异步 `validateAsync`（如检查文件名是否已存在），返回错误消息时
///     在输入框 errorText 展示并阻止提交；异步校验期间禁用确认按钮防连点。
///
/// 内部使用 [StatefulWidget] 管理 [TextEditingController] 生命周期，
/// 确保 controller 在 TextField 完全从树中卸载后才释放（避免过早 dispose）。
///
/// 目前被两处复用：
///   - 首页「重命名契约」对话框（校验 .meph 后缀 + 文件名已存在）
///   - 叙事页「另存为分支」对话框（校验非空）
class TextInputDialog {
  /// 弹出文本输入对话框。
  ///
  /// 参数：
  ///   - title: 对话框标题
  ///   - labelText: 输入框标签
  ///   - validate: 同步输入校验（返回 false 时不关闭对话框，与确定按钮行为一致）
  ///   - validateAsync: 可选异步校验（如检查文件名是否已存在）：
  ///       返回 null 表示校验通过；返回错误消息字符串时阻止提交，
  ///       并在输入框 errorText 中展示该消息。
  ///   - hintText / helperText: 输入框提示文案
  ///   - confirmText: 确定按钮文案
  ///   - initialValue: 输入框初始值
  ///
  /// 返回值：用户确认后的文本（已 trim）；取消返回 null。
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String labelText,
    required bool Function(String value) validate,
    Future<String?> Function(String value)? validateAsync,
    String? hintText,
    String? helperText,
    String? confirmText,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: title,
        labelText: labelText,
        validate: validate,
        validateAsync: validateAsync,
        hintText: hintText,
        helperText: helperText,
        confirmText: confirmText,
        initialValue: initialValue,
      ),
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final bool Function(String value) validate;
  final Future<String?> Function(String value)? validateAsync;
  final String? hintText;
  final String? helperText;
  final String? confirmText;
  final String initialValue;

  const _TextInputDialog({
    required this.title,
    required this.labelText,
    required this.validate,
    this.validateAsync,
    this.hintText,
    this.helperText,
    this.confirmText,
    this.initialValue = '',
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  /// 异步校验进行中标志（校验期间禁用确认按钮，防止连点重复提交）
  bool _isValidating = false;

  /// 异步校验错误消息（展示在输入框 errorText）
  String? _asyncError;

  @override
  void dispose() {
    // State.dispose 在 widget 完全从树中移除后由框架调用，
    // 此时 TextField 已不再引用 controller，释放是安全的。
    _controller.dispose();
    super.dispose();
  }

  /// 提交逻辑：同步校验 → 异步校验 → 通过则关闭对话框并返回结果。
  /// 按钮与回车共用；异步校验期间禁用提交，避免重复调用。
  Future<void> _submit() async {
    final value = _controller.text.trim();
    // 1. 同步校验（非空/后缀等）
    if (!widget.validate(value)) return;
    // 2. 无异步校验 → 直接提交
    final asyncValidator = widget.validateAsync;
    if (asyncValidator == null) {
      Navigator.pop(context, value);
      return;
    }
    // 3. 异步校验（防连点）
    if (_isValidating) return;
    setState(() {
      _isValidating = true;
      _asyncError = null;
    });
    final error = await asyncValidator(value);
    if (!mounted) return;
    setState(() {
      _isValidating = false;
      _asyncError = error;
    });
    if (error == null) {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          helperText: widget.helperText,
          // 异步校验失败时展示错误消息
          errorText: _asyncError,
        ),
        // 回车快速提交（桌面 Enter + 移动端软键盘「完成」均触发）
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).textInputDialogCancel),
        ),
        FilledButton(
          onPressed: _isValidating ? null : _submit,
          child: Text(
            widget.confirmText ??
                AppLocalizations.of(context).textInputDialogConfirm,
          ),
        ),
      ],
    );
  }
}
