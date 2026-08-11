/// 首页菜单/重命名/删除确认（独立顶层函数）
///
/// 从 HomeScreen State 抽离的「⋮ 菜单分发 + 重命名/重删除确认」逻辑，
/// 统一接收 [BuildContext] + 必要状态参数。使逻辑可独立维护。
library;

import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../constants/menu_actions.dart';
import '../../providers/contract_provider.dart';
import '../../services/storage/contract_repo.dart';
import '../../widgets/dialogs/confirm_delete_dialog.dart';
import '../../widgets/dialogs/rename_contract_dialog.dart';
import '../../widgets/home/contract_preview_sheet.dart';

/// 处理契约节点「⋮ 菜单」操作（母版/子版共用分发）。
///
/// 母版与子版菜单几乎完全一致，仅差「编辑」操作与删除行为不同：
///   - 母版：可编辑源文本 + 级联删除整棵子树
///   - 子版：不可编辑 + 仅删除自身
/// 通过参数化差异合并，消除两份几乎相同的 switch 样板。
Future<void> handleNodeMenu(
  BuildContext context,
  ContractInfo node,
  String action, {
  required bool includeEdit,
  required Future<void> Function() onEdit,
  required Future<void> Function(ContractInfo) onOpenNarrative,
  required Future<void> Function(ContractInfo) onRename,
  required Future<void> Function() onDelete,
}) async {
  switch (action) {
    case menuActionEnter:
      await onOpenNarrative(node);
      return;
    case menuActionPreview:
      await ContractPreviewSheet.show(context, node);
      return;
    case menuActionEdit:
      if (includeEdit) await onEdit();
      return;
    case menuActionRename:
      await onRename(node);
      return;
    case menuActionDelete:
      await onDelete();
      return;
  }
}

/// 弹出重命名对话框并执行重命名（母版级联同步子树前缀）。
///
/// 子版重命名时还可同时编辑「命运说明」（`@命运` 区块）：
/// 先更新原文件内容（文本级操作，不动其他内容），再执行文件重命名。
/// 母版重命名时，其下所有子版前缀通过 [renameContractCascade] 一并同步。
Future<void> renameContractDialog(
  BuildContext context,
  ContractInfo info, {
  required VoidCallback onRefreshLists,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final result = await RenameContractDialog.show(
    context,
    currentName: info.fileName,
    initialBranchTitle: info.branchTitle,
    showBranchTitleField: info.isChild || info.branchTitle != null,
  );

  if (result == null) return;
  final (newName, newBranchTitle) = result;
  // 文件名与命运说明均未变化 → 无需操作
  if (newName == info.fileName && newBranchTitle == info.branchTitle) {
    return;
  }

  // 命运说明有变化 → 先更新原文件内容（旧文件名），再执行重命名
  if (newBranchTitle != info.branchTitle) {
    await updateContractBranchTitle(info.fileName, newBranchTitle ?? '');
  }

  // 文件名未变化（可能仅修改了命运说明）→ 刷新列表后返回
  if (newName == info.fileName) {
    onRefreshLists();
    return;
  }

  // 母版：级联重命名整棵子树；子版：仅重命名自身
  final ok = info.isChild
      ? await renameContract(info.fileName, newName)
      : await renameContractCascade(info.fileName, newName);
  if (!context.mounted) return;

  // 刷新列表
  onRefreshLists();

  // 成功时列表已显示新文件名，无需提示；仅当重命名失败时告知
  // （对话框已拦截「目标名已存在」，此处是文件系统层面失败的兜底提示）
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeRenameFail)),
    );
  }
}

/// 共享删除流程：确认对话框 → 执行删除 → 刷新列表 → 失败提示。
///
/// 统一「确认 → 删除 → 刷新 → 提示」样板；[delete] 返回是否删除成功
/// （false 时提示删除失败）。
Future<void> confirmAndDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<bool> Function() delete,
  required VoidCallback onRefreshLists,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final confirmed = await ConfirmDeleteDialog.show(
    context,
    title: title,
    message: message,
  );
  if (!confirmed) return;

  final ok = await delete();
  // 刷新列表（await 后 widget 可能已销毁，先检查 mounted）
  if (!context.mounted) return;
  onRefreshLists();

  // 成功时列表已直观反映（文件消失），无需提示；仅当删除失败时告知
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeDeleteFail)),
    );
  }
}

/// 确认并级联删除母版及其下所有子版。
Future<void> confirmCascadeDelete(
  BuildContext context,
  ContractInfo master, {
  required VoidCallback onRefreshLists,
}) {
  return confirmAndDelete(
    context,
    title: AppLocalizations.of(context).homeDeleteContractTitle,
    message: AppLocalizations.of(context).homeDeleteMasterConfirm(
      master.fileName,
    ),
    delete: () async => await deleteContractCascade(master.fileName) > 0,
    onRefreshLists: onRefreshLists,
  );
}

/// 确认并删除单个子版。
Future<void> confirmDeleteChild(
  BuildContext context,
  ContractInfo child, {
  required VoidCallback onRefreshLists,
}) {
  return confirmAndDelete(
    context,
    title: AppLocalizations.of(context).homeDeleteChildTitle,
    message: AppLocalizations.of(context).homeDeleteChildConfirm(
      child.fileName,
    ),
    delete: () => deleteContract(child.fileName),
    onRefreshLists: onRefreshLists,
  );
}