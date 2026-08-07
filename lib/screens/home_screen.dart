import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../providers/contract_provider.dart';
import '../providers/providers.dart';
import '../services/session/child_save_store.dart';
import '../services/storage/contract_dir.dart';
import '../services/storage/contract_repo.dart';
import '../widgets/dialogs/confirm_delete_dialog.dart';
import '../widgets/dialogs/rename_contract_dialog.dart';
import '../widgets/home/contract_card.dart';
import '../widgets/home/contract_preview_sheet.dart';
import '../widgets/home/home_brand_header.dart';
import '../widgets/home/home_state_views.dart';
import 'contract_editor_screen.dart';

/// 首页：契约选择
///
/// 展示用户 `contracts/` 目录中的所有 .meph 契约文件（含角色名）。
/// 采用「母版 + 可展开子版」的树状表格层级结构：
///   - 母版卡片默认只显示自身
///   - 有子版时卡片右侧显示展开箭头「▾」，点击展开子版列表（缩进小卡片）
///   - 母版行和子版行右下都有「⋮ 操作菜单」，提供一致的 进入/预览/重命名/删除
///
/// 支持：
///   - 单击母版/子版卡片进入对应叙事
///   - 长按卡片进入多选模式（批量删除）
///   - 导入本地 .meph 文件
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 多选模式下选中的契约文件名
  final Set<String> _selected = {};

  /// 是否为多选模式
  bool _isSelectMode = false;

  /// 已展开子版区的母版文件名（默认收起，点击展开）
  final Set<String> _expandedGroups = {};

  /// 是否正在恢复内置角色（空状态恢复按钮的加载态）
  bool _isRestoring = false;

  /// 进入多选模式，并选中指定卡片（可级联选中其子版）。
  ///
  /// 参数：
  ///   - fileName: 长按的文件名
  ///   - cascadeChildren: 长按母版时，将其下所有子版一并选中
  void _enterSelectMode(
    String fileName, {
    List<String> cascadeChildren = const [],
  }) {
    setState(() {
      _isSelectMode = true;
      _selected.add(fileName);
      _selected.addAll(cascadeChildren);
    });
  }

  /// 切换卡片的选中状态（单个文件，不联动）。
  void _toggleSelect(String fileName) {
    setState(() {
      if (_selected.contains(fileName)) {
        _selected.remove(fileName);
        // 取消最后一个选中时自动退出多选
        if (_selected.isEmpty) _isSelectMode = false;
      } else {
        _selected.add(fileName);
      }
    });
  }

  /// 切换母版卡片的选中状态（级联联动其下所有子版）。
  void _toggleSelectMaster(ContractGroup group) {
    setState(() {
      final masterName = group.master.fileName;
      final childNames = group.children.map((c) => c.fileName).toSet();

      if (_selected.contains(masterName)) {
        // 取消母版 → 同时取消其下所有子版
        _selected.remove(masterName);
        _selected.removeAll(childNames);
        if (_selected.isEmpty) _isSelectMode = false;
      } else {
        // 选中母版 → 同时选中其下所有子版
        _selected.add(masterName);
        _selected.addAll(childNames);
      }
    });
  }

  /// 退出多选模式
  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selected.clear();
    });
  }

  /// 全选所有契约（含子版）
  void _selectAll(List<ContractGroup> groups) {
    setState(() {
      for (final group in groups) {
        _selected.add(group.master.fileName);
        for (final child in group.children) {
          _selected.add(child.fileName);
        }
      }
    });
  }

  /// 切换某母版的子版区展开/收起
  void _toggleChildrenExpanded(String masterFileName) {
    setState(() {
      if (_expandedGroups.contains(masterFileName)) {
        _expandedGroups.remove(masterFileName);
      } else {
        _expandedGroups.add(masterFileName);
      }
    });
  }

  /// 删除选中的契约文件
  Future<void> _deleteSelected() async {
    final messenger = ScaffoldMessenger.of(context);
    final count = _selected.length;

    final l10n = AppLocalizations.of(context);

    // 确认对话框
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: l10n.homeDeleteContractTitle,
      message: l10n.homeDeleteSelectedConfirm(count),
    );

    if (!confirmed) return;

    // 逐个删除
    var failCount = 0;
    for (final name in _selected.toList()) {
      if (!await deleteContract(name)) failCount++;
    }

    // 退出多选 + 刷新列表
    _exitSelectMode();
    _refreshLists();

    // 成功时列表已直观反映（文件消失），无需提示；仅当存在删除失败时告知
    if (failCount > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeDeleteSelectedFail(count))),
      );
    }
  }

  /// 从本地文件系统导入 .meph 契约文件到用户契约目录。
  ///
  /// 支持多选：文件选择器允许同时选择多个 .meph 文件，逐个导入。
  Future<void> _importContract() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    // 打开系统文件选择器（过滤 .meph 文件，支持多选）
    const typeGroup = XTypeGroup(
      label: 'Mephisto 契约',
      extensions: ['meph'],
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);

    if (files.isEmpty) return; // 用户取消选择

    var successCount = 0;
    var failCount = 0;
    var lastError = '';

    // 逐个导入（重名自动加序号）
    for (final file in files) {
      try {
        await importContract(file.path, file.name);
        successCount++;
      } catch (e) {
        failCount++;
        lastError = '$e';
      }
    }

    // 刷新契约列表
    _refreshLists();

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

  /// 刷新契约列表 providers。
  void _refreshLists() {
    ref.invalidate(contractGroupListProvider);
  }

  /// 强制恢复内置角色模板（浮士德/唐泰斯）到当前契约目录。
  ///
  /// 作为空状态兜底：无论目录种子状态如何，重新复制缺失的内置模板
  /// （不覆盖用户已有的同名文件）。
  Future<void> _restoreBuiltin() async {
    setState(() => _isRestoring = true);
    await ensureContracts(force: true);
    if (!mounted) return;
    setState(() => _isRestoring = false);
    _refreshLists();
  }

  /// 切换契约并进入叙事。
  ///
  /// 等待叙事页返回后刷新契约列表，确保叙事过程中新生成的子版文件
  /// 能立即在首页显示（否则 provider 缓存命中，需要重启才能看到）。
  Future<void> _openNarrative(ContractInfo info) async {
    await switchContract(ref, info.fileName);
    if (mounted) {
      await Navigator.pushNamed(context, '/narrative');
      _refreshLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(contractGroupListProvider);

    return Scaffold(
      appBar: _buildAppBar(theme, groupsAsync.value ?? const []),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => HomeErrorState(error: e),
        data: (groups) {
          if (groups.isEmpty) {
            return HomeEmptyState(
              onRestoreBuiltin: _restoreBuiltin,
              isRestoring: _isRestoring,
            );
          }
          return _buildContractList(context, theme, groups);
        },
      ),
    );
  }

  // ============================================================
  // 顶栏
  // ============================================================

  AppBar _buildAppBar(ThemeData theme, List<ContractGroup> groups) {
    // 全部契约文件数（母版 + 子版）
    final allFiles = [
      for (final g in groups) ...[g.master, ...g.children],
    ];
    final l10n = AppLocalizations.of(context);

    // ---- 多选模式顶栏 ----
    if (_isSelectMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
          tooltip: l10n.homeCancel,
        ),
        title: Text(
          l10n.homeSelectedCount(_selected.length),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // ---- 删除选中 ----
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _selected.isEmpty ? null : _deleteSelected,
            tooltip: l10n.homeDeleteSelected,
          ),
          // ---- 全选 ----
          TextButton(
            onPressed: allFiles.isEmpty
                ? null
                : () {
                    // 全部选中时再点全选 = 取消全选
                    if (_selected.length == allFiles.length) {
                      _exitSelectMode();
                    } else {
                      _selectAll(groups);
                    }
                  },
            child: Text(
              _selected.length == allFiles.length
                  ? l10n.homeDeselectAll
                  : l10n.homeSelectAll,
            ),
          ),
        ],
      );
    }

    // ---- 普通模式顶栏 ----
    return AppBar(
      title: const Text('📜 Mephisto'),
      centerTitle: false,
      actions: [
        // ---- 新建契约按钮 ----
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _newContract,
          tooltip: l10n.homeNewContract,
        ),
        // ---- 导入契约按钮 ----
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          onPressed: _importContract,
          tooltip: l10n.homeImportContract,
        ),
        // ---- 设置入口 ----
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          tooltip: l10n.homeSettings,
        ),
      ],
    );
  }

  // ============================================================
  // 契约列表（母版 + 可展开子版的树状结构）
  // ============================================================

  Widget _buildContractList(
    BuildContext context,
    ThemeData theme,
    List<ContractGroup> groups,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        // ---- 品牌展示区（多选模式下隐藏，聚焦操作） ----
        if (!_isSelectMode) const HomeBrandHeader(),

        // ---- 契约分组卡片列表 ----
        for (final group in groups) ...[
          ContractCard(
            info: group.master,
            children: group.children,
            childrenExpanded: _expandedGroups.contains(group.master.fileName),
            onToggleChildren: () =>
                _toggleChildrenExpanded(group.master.fileName),
            isSelectMode: _isSelectMode,
            isMasterSelected: _selected.contains(group.master.fileName),
            childSelection: {
              for (final child in group.children)
                child.fileName: _selected.contains(child.fileName),
            },
            onMasterTap: () {
              if (_isSelectMode) {
                _toggleSelectMaster(group);
              } else {
                _openNarrative(group.master);
              }
            },
            onMasterLongPress: () {
              if (!_isSelectMode) {
                // 长按母版 → 级联选中其下所有子版
                _enterSelectMode(
                  group.master.fileName,
                  cascadeChildren:
                      group.children.map((c) => c.fileName).toList(),
                );
              }
            },
            onMasterMenu: (action) =>
                _handleMasterMenu(context, group.master, action),
            onChildTap: (child) {
              if (_isSelectMode) {
                _toggleSelect(child.fileName);
              } else {
                _openNarrative(child);
              }
            },
            onChildLongPress: (child) {
              if (!_isSelectMode) {
                // 长按子版 → 单独选中该子版（不级联）
                _enterSelectMode(child.fileName);
              }
            },
            onChildMenu: (child, action) =>
                _handleChildMenu(context, child, action),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// 处理母版行「⋮ 菜单」操作。
  Future<void> _handleMasterMenu(
    BuildContext context,
    ContractInfo master,
    String action,
  ) async {
    switch (action) {
      case 'enter':
        await _openNarrative(master);
      case 'preview':
        await ContractPreviewSheet.show(context, master);
      case 'edit':
        await _editContract(master);
      case 'rename':
        await _renameDialog(master);
      case 'delete':
        await _confirmCascadeDelete(master);
    }
  }

  /// 打开契约编辑器（编辑母版 .meph 源文本）。
  Future<void> _editContract(ContractInfo info) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    final content = await readContract(info.fileName);
    if (content == null) return;

    if (!mounted) return;
    final saved = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractEditorScreen(
          fileName: info.fileName,
          initialContent: content,
        ),
      ),
    );

    if (saved != null) {
      _refreshLists();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeContractSaved)),
      );
    }
  }

  /// 打开契约编辑器（新建空白契约）。
  ///
  /// 保存成功后自动切换为新契约并进入叙事，免去手动返回首页再点卡的步骤。
  Future<void> _newContract() async {
    if (!mounted) return;
    final fileName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ContractEditorScreen(),
      ),
    );

    if (fileName == null) return; // 取消/未保存

    // 切换为新契约并直接进入叙事
    await switchContract(ref, fileName);
    _refreshLists();
    if (mounted) {
      await Navigator.pushNamed(context, '/narrative');
      _refreshLists(); // 叙事页返回后刷新，展示新生成的子版
    }
  }

  /// 处理子版行「⋮ 菜单」操作。
  Future<void> _handleChildMenu(
    BuildContext context,
    ContractInfo child,
    String action,
  ) async {
    switch (action) {
      case 'enter':
        await _openNarrative(child);
      case 'preview':
        await ContractPreviewSheet.show(context, child);
      case 'rename':
        await _renameDialog(child);
      case 'delete':
        await _confirmDeleteChild(child);
    }
  }

  /// 弹出重命名对话框并执行重命名（母版级联同步子版前缀）。
  Future<void> _renameDialog(ContractInfo info) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    final newName = await RenameContractDialog.show(
      context,
      currentName: info.fileName,
    );

    if (newName == null || newName == info.fileName) return;

    final ok = await renameContract(info.fileName, newName);
    // 母版重命名时，同步其子版文件名前缀
    if (ok && !info.isChild) {
      final oldPrefix = extractMasterPrefix(info.fileName);
      final newPrefix = extractMasterPrefix(newName);
      for (final child in await ChildSaveStore.listChildFiles(info.fileName)) {
        // faust.child.meph → 歌德.child.meph
        final suffix = child.substring(oldPrefix.length);
        await renameContract(child, '$newPrefix$suffix');
      }
    }

    // 刷新列表
    _refreshLists();

    if (!mounted) return;
    // 成功时列表已显示新文件名，无需提示；仅当重命名失败时告知
    // （对话框已拦截「目标名已存在」，此处是文件系统层面失败的兜底提示）
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeRenameFail)),
      );
    }
  }

  /// 确认并级联删除母版及其下所有子版。
  Future<void> _confirmCascadeDelete(ContractInfo master) => _confirmAndDelete(
    title: AppLocalizations.of(context).homeDeleteContractTitle,
    message: AppLocalizations.of(context).homeDeleteMasterConfirm(
      master.fileName,
    ),
    delete: () async => await deleteContractCascade(master.fileName) > 0,
  );

  /// 确认并删除单个子版。
  Future<void> _confirmDeleteChild(ContractInfo child) => _confirmAndDelete(
    title: AppLocalizations.of(context).homeDeleteChildTitle,
    message: AppLocalizations.of(context).homeDeleteChildConfirm(
      child.fileName,
    ),
    delete: () => deleteContract(child.fileName),
  );

  /// 共享删除流程：确认对话框 → 执行删除 → 刷新列表 → 失败提示。
  ///
  /// 统一 [_confirmCascadeDelete] 与 [_confirmDeleteChild] 的「确认 → 删除 →
  /// 刷新 → 提示」样板；[delete] 返回是否删除成功（false 时提示删除失败）。
  Future<void> _confirmAndDelete({
    required String title,
    required String message,
    required Future<bool> Function() delete,
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
    if (!mounted) return;
    _refreshLists();

    // 成功时列表已直观反映（文件消失），无需提示；仅当删除失败时告知
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeDeleteFail)),
      );
    }
  }
}
