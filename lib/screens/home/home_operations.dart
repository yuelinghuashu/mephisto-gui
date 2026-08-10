/// 首页文件操作（独立顶层函数）
///
/// 从 HomeScreen State 抽离的「不依赖 State 实例字段」的文件操作，
/// 统一接收 [WidgetRef] + [BuildContext] + 必要状态参数。
/// 使逻辑可独立单元测试，State 只负责桥接。
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../providers/contract_provider.dart';
import '../../providers/home_selection_controller.dart';
import '../../services/contract_pack.dart';
import '../../services/storage/contract_dir.dart';
import '../../services/storage/contract_repo.dart';
import '../../widgets/dialogs/confirm_delete_dialog.dart';
import '../contract_editor_screen.dart';

/// 删除选中的契约文件。
///
/// 逐个删除成功后退出多选并刷新列表；有失败时提示数量。
Future<void> deleteSelectedContract(
  WidgetRef ref,
  BuildContext context,
  HomeSelectionController selection, {
  required VoidCallback onExitSelectMode,
  required VoidCallback onRefreshLists,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final count = selection.selectedCount;
  final l10n = AppLocalizations.of(context);

  if (!await ConfirmDeleteDialog.show(
    context,
    title: l10n.homeDeleteContractTitle,
    message: l10n.homeDeleteSelectedConfirm(count),
  )) {
    return;
  }

  // 逐个删除
  var failCount = 0;
  for (final name in selection.selected.toList()) {
    if (!await deleteContract(name)) failCount++;
  }

  if (!context.mounted) return;
  onExitSelectMode();
  onRefreshLists();

  // 成功时列表已直观反映（文件消失），无需提示；仅当存在删除失败时告知
  if (failCount > 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeDeleteSelectedFail(count))),
    );
  }
}

/// 从本地文件系统导入契约文件到用户契约目录。
///
/// 支持两类文件（可混合多选）：
///   - `.meph` 契约文件：直接复制
///   - `.zip` 压缩包：解压后提取其中全部 .meph 文件
Future<void> importContractFiles(
  BuildContext context, {
  required VoidCallback onRefreshLists,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  // 打开系统文件选择器（支持 .meph + .zip，多选）
  const typeGroup = XTypeGroup(
    label: 'Mephisto 契约',
    extensions: ['meph', 'zip'],
  );
  final files = await openFiles(acceptedTypeGroups: [typeGroup]);

  if (files.isEmpty) return; // 用户取消选择

  var successCount = 0;
  var failCount = 0;
  var lastError = '';

  // 逐个导入（.meph 直接复制；.zip 解压还原）
  for (final file in files) {
    try {
      if (file.name.toLowerCase().endsWith('.zip')) {
        final bytes = await file.readAsBytes();
        final imported = await unpackMeph(bytes);
        successCount += imported;
      } else {
        await importContract(file.path, file.name);
        successCount++;
      }
    } catch (e) {
      failCount++;
      lastError = '$e';
    }
  }

  if (!context.mounted) return;
  onRefreshLists();

  // 汇总提示
  if (failCount == 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeImportSuccess(successCount))),
    );
  } else if (successCount == 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeImportFailAll(lastError))),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.homeImportPartial(successCount, failCount)),
      ),
    );
  }
}

/// 导出单棵命运树（母版 + 全部子版）为 .zip 文件。
///
/// 通过系统保存对话框让用户选择保存位置；取消时静默返回。
Future<void> exportContractTree(
  BuildContext context, {
  required String masterFileName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final bytes = await packContractTree(masterFileName);

  final destination = await getSaveLocation(
    suggestedName: '$masterFileName.zip'.replaceAll('.meph', ''),
    acceptedTypeGroups: const [
      XTypeGroup(label: 'ZIP 压缩包', extensions: ['zip']),
    ],
  );
  if (destination == null) return; // 用户取消

  try {
    await File(destination.path).writeAsBytes(bytes);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeExportSuccess(destination.path))),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeExportFail('$e'))),
    );
  }
}

/// 导出整个舞台目录为 .zip 文件。
Future<void> exportStage(
  BuildContext context, {
  required String stageDirPath,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final bytes = await packStage(stageDirPath);

  final stageName = stageDirPath.split(Platform.pathSeparator).last;
  final destination = await getSaveLocation(
    suggestedName: '$stageName.zip',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'ZIP 压缩包', extensions: ['zip']),
    ],
  );
  if (destination == null) return; // 用户取消

  try {
    await File(destination.path).writeAsBytes(bytes);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeExportSuccess(destination.path))),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeExportFail('$e'))),
    );
  }
}

/// 强制恢复内置角色模板（浮士德/唐泰斯）到当前契约目录。
///
/// 作为空状态兜底：无论目录种子状态如何，重新复制缺失的内置模板
/// （不覆盖用户已有的同名文件）。
Future<void> restoreBuiltinContracts(
  BuildContext context, {
  required ValueChanged<bool> onRestoringChanged,
  required VoidCallback onRefreshLists,
}) async {
  onRestoringChanged(true);
  await ensureContracts(force: true);
  if (!context.mounted) return;
  onRestoringChanged(false);
  onRefreshLists();
}

/// 打开契约编辑器（编辑母版 .meph 源文本）。
///
/// 保存成功后刷新列表并提示。
Future<void> editContractFile(
  BuildContext context, {
  required String fileName,
  required VoidCallback onRefreshLists,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final content = await readContract(fileName);
  if (content == null) return;

  if (!context.mounted) return;
  final saved = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => ContractEditorScreen(
        fileName: fileName,
        initialContent: content,
      ),
    ),
  );

  if (saved != null && context.mounted) {
    onRefreshLists();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.homeContractSaved)),
    );
  }
}

/// 打开契约编辑器（新建空白契约）。
///
/// 保存成功后自动切换为新契约并进入叙事，免去手动返回首页再点卡的步骤。
Future<void> newContractFile(
  WidgetRef ref,
  BuildContext context, {
  required VoidCallback onRefreshLists,
}) async {
  if (!context.mounted) return;
  final fileName = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => const ContractEditorScreen(),
    ),
  );

  if (fileName == null) return; // 取消/未保存

  // 切换为新契约并直接进入叙事
  await switchContract(ref, fileName);
  onRefreshLists();
  if (context.mounted) {
    await Navigator.pushNamed(context, '/narrative');
    onRefreshLists(); // 叙事页返回后刷新，展示新生成的子版
  }
}