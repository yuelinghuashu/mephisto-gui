import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

import '../providers/contract_provider.dart';
import '../providers/home_selection_controller.dart';
import '../providers/stage_provider.dart';
import '../services/storage/stage_repo.dart';
import '../widgets/dialogs/confirm_delete_dialog.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/home/contract_preview_sheet.dart';
import '../widgets/home/contract_tree_section.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_branch_sheet.dart';
import '../widgets/home/home_state_views.dart';
import '../widgets/home/role_quick_actions_sheet.dart';
import 'contract_editor_screen.dart';
import 'home/home_menu_actions.dart';
import 'home/home_operations.dart';
import 'stage_narrative_screen.dart';

/// 首页：契约选择
///
/// 展示用户 `contracts/` 目录中的所有 .meph 契约文件（含角色名）。
/// 采用「多级命运树」递归层级结构（文件名 `.` 分段表达派生链）：
///   - 母版卡片默认只显示自身
///   - 有子节点时卡片右侧显示展开箭头「▾」，点击展开子节点（逐级缩进的嵌套卡片）
///   - 每个节点右下都有「⋮ 操作菜单」，提供一致的 进入/预览/编辑/重命名/删除
///
/// 支持：
///   - 单击任意节点进入对应叙事
///   - 长按节点进入多选模式（级联选中其整棵子树）
///   - 导入本地 .meph 文件
///
/// 职责拆分（本类只做「组装 + 导航 + 委托」）：
///   - 多选/展开状态：[_selection]（独立 Controller）
///   - 文件操作：`home_operations.dart`（导入/删除/编辑/新建/恢复内置）
///   - 菜单/重命名/删除确认：`home_menu_actions.dart`
///   - 契约树 + 舞台渲染：[ContractTreeSection]（只读 ConsumerWidget）
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 多选/展开状态控制器（状态逻辑已抽离，可独立单元测试）
  final HomeSelectionController _selection = HomeSelectionController();

  /// 是否正在恢复内置角色（空状态恢复按钮的加载态）
  bool _isRestoring = false;

  // ============================================================
  // 状态委托（桥接 Controller）
  //
  // `HomeSelectionController` 是 `ChangeNotifier`，`build()` 中通过
  // `ListenableBuilder` 监听其变化自动重绘，无需手动 `setState`。
  // 仅 `_isRestoring`（空状态恢复按钮的加载态）使用 `setState`。
  // 多选/展开状态的读写全部直接访问 [_selection]，不再逐方法委托。
  // ============================================================

  /// 刷新契约列表 + 舞台列表 + 舞台详情 providers（带 mounted 保护）。
  ///
  /// `stageListProvider` 只刷新舞台目录列表本身；舞台的**缓存详情**
  /// （`stageLastModifiedProvider(path)` 的 mtime + `stageProvider(path)`
  /// 的角色卡/hasSave 探测）是独立缓存的 family provider，必须逐个失效，
  /// 否则从舞台叙事页返回后「最近编辑」日期和新生成的 `.child.meph`
  /// 存档不会及时出现（需重启才刷新）。
  void _refreshLists() {
    if (!mounted) return;
    ref.invalidate(contractGroupListProvider);

    // 先读取当前缓存的舞台列表（invalidate 之前），获取所有舞台路径
    final stagePaths = [
      for (final stage
          in ref.read(stageListProvider).value ?? const <StageInfo>[])
        stage.path,
    ];

    // 逐个失效舞台详情缓存：mtime（最近编辑）+ 角色加载（hasSave 探测）
    for (final path in stagePaths) {
      ref.invalidate(stageLastModifiedProvider(path));
      ref.invalidate(stageProvider(path));
    }
    ref.invalidate(stageListProvider);
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  // ============================================================
  // 文件操作委托（实现在 home_operations.dart）
  // ============================================================

  /// 删除选中的契约文件 + 选中的舞台目录 + 舞台内角色。
  ///
  /// **顺序执行契约 → 舞台 → 舞台内角色**，全部删除完成后**统一退出多选
  /// + 刷新列表**。各分类内部不宜提前退出多选——`exitSelectMode` 会清空
  /// `_selectedStages` / `_selectedStageRoles`，导致后续分类的
  /// `isNotEmpty` 判断落空、删除被静默跳过。
  Future<void> _deleteSelected() async {
    // 1. 删除选中的契约文件；用户取消 → 中止整个流程（保持多选）
    if (_selection.selected.isNotEmpty) {
      final confirmed = await deleteSelectedContract(
        ref,
        context,
        _selection,
      );
      if (!mounted || !confirmed) return;
    }
    // 2. 删除选中的舞台目录（manageSelection: false = 由外层统一收尾）
    if (_selection.selectedStages.isNotEmpty) {
      final confirmed = await _deleteStages(
        _selection.selectedStages.toList(),
        manageSelection: false,
      );
      if (!mounted || !confirmed) return;
    }
    // 3. 删除选中的舞台内角色卡 / 存档（批量）
    if (_selection.selectedStageRoles.isNotEmpty) {
      final confirmed = await _deleteSelectedStageRoles();
      if (!mounted || !confirmed) return;
    }

    // 全部删除完成 → 统一退出多选 + 刷新列表
    _selection.exitSelectMode();
    _refreshLists();
  }

  /// 批量删除多选模式下勾选的舞台内角色（母版角色卡 / .child.meph 存档）。
  ///
  /// 选中 key 由 [HomeSelectionController] 生成（携带路径/角色名/文件名/
  /// isChild 四个字段），通过 [HomeSelectionController.parseStageRoleKey]
  /// 安全解析后直接使用文件名调用 [deleteStageRoleCard] /
  /// [deleteStageRoleChild]，不再用中文角色名反查文件名。
  /// 返回 `false` = 用户取消（调用方中止整个批量删除流程）。
  Future<bool> _deleteSelectedStageRoles() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = _selection.selectedStageRoles.length;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: l10n.homeDeleteContractTitle,
      message: l10n.homeDeleteSelectedConfirm(count),
    );
    if (!confirmed) return false;

    var failCount = 0;
    for (final key in _selection.selectedStageRoles.toList()) {
      final parsed = HomeSelectionController.parseStageRoleKey(key);
      if (parsed == null) continue;
      final (stagePath, _, fileName, isChild) = parsed;
      final ok = isChild
          ? await deleteStageRoleChild(stagePath, fileName)
          : await deleteStageRoleCard(stagePath, fileName);
      if (!ok) failCount++;
    }

    // 不在此处退出多选/刷新——由 _deleteSelected 在全部删除完成后统一收尾
    if (!mounted) return false;
    if (failCount > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeDeleteSelectedFail(count))),
      );
    }
    return true;
  }

  /// 导入本地 .meph 文件。
  Future<void> _importContract() {
    return importContractFiles(context, onRefreshLists: _refreshLists);
  }

  /// 恢复内置角色模板。
  Future<void> _restoreBuiltin() {
    return restoreBuiltinContracts(
      context,
      onRestoringChanged: (value) => setState(() => _isRestoring = value),
      onRefreshLists: _refreshLists,
    );
  }

  /// 编辑契约（母版源文本）。
  Future<void> _editContract(ContractInfo info) {
    return editContractFile(
      context,
      fileName: info.fileName,
      onRefreshLists: _refreshLists,
    );
  }

  /// 新建空白契约。
  Future<void> _newContract() {
    return newContractFile(ref, context, onRefreshLists: _refreshLists);
  }

  // ============================================================
  // 菜单/重命名/删除委托（实现在 home_menu_actions.dart）
  // ============================================================

  /// 处理母版行「⋮ 菜单」操作。
  Future<void> _handleMasterMenu(
    BuildContext context,
    ContractInfo master,
    String action,
  ) {
    if (action == 'export') {
      return exportContractTree(context, masterFileName: master.fileName);
    }
    return handleNodeMenu(
      context,
      master,
      action,
      includeEdit: true,
      onEdit: () => _editContract(master),
      onOpenNarrative: _openNarrative,
      onRename: _renameDialog,
      onDelete: () => _confirmCascadeDelete(master),
    );
  }

  /// 处理子版行「⋮ 菜单」操作。
  Future<void> _handleChildMenu(
    BuildContext context,
    ContractInfo child,
    String action,
  ) {
    return handleNodeMenu(
      context,
      child,
      action,
      includeEdit: false,
      onEdit: () async {}, // 子版不可编辑
      onOpenNarrative: _openNarrative,
      onRename: _renameDialog,
      onDelete: () => _confirmDeleteChild(child),
    );
  }

  /// 重命名对话框 + 级联重命名。
  Future<void> _renameDialog(ContractInfo info) {
    return renameContractDialog(context, info, onRefreshLists: _refreshLists);
  }

  /// 确认并级联删除母版及其下所有子版。
  Future<void> _confirmCascadeDelete(ContractInfo master) {
    return confirmCascadeDelete(context, master, onRefreshLists: _refreshLists);
  }

  /// 确认并删除单个子版。
  Future<void> _confirmDeleteChild(ContractInfo child) {
    return confirmDeleteChild(context, child, onRefreshLists: _refreshLists);
  }

  // ============================================================
  // 舞台操作（多角色舞台卡）
  // ============================================================

  /// 处理舞台卡「⋮ 菜单」操作（进入 / 导出 / 重命名 / 删除）。
  Future<void> _handleStageMenu(String stagePath, String action) async {
    final l10n = AppLocalizations.of(context);
    // 使用 p.basename 跨平台兼容（Windows 路径可能使用 / 或 \ 混合分隔符）
    final stageName = p.basename(stagePath);

    switch (action) {
      case 'enter':
        // 进入：从母版干净开局（对齐单角色「点母版 = 进母版」）。
        await _openStageNarrative(stagePath);
        return;
      case 'restart':
        // 重新开始 = 从母版干净开局（与「进入」行为一致，保留菜单语义）
        await _openStageNarrative(stagePath);
        return;
      case 'export':
        await exportStage(context, stageDirPath: stagePath);
        return;
      case 'rename':
        final newName = await TextInputDialog.show(
          context,
          title: l10n.stageRenameDialogTitle,
          labelText: l10n.stageRenameDialogLabel,
          initialValue: stageName,
          validate: (value) => value.trim().isNotEmpty,
          validateAsync: (value) async {
            final target = Directory(
              '${Directory(stagePath).parent.path}/${value.trim()}',
            );
            return await target.exists() ? l10n.stageRenameNameExists : null;
          },
          confirmText: l10n.stageRenameDialogConfirm,
        );
        if (newName == null || newName == stageName) return;
        final ok = await renameStage(stagePath, newName.trim());
        if (!mounted) return;
        _refreshLists();
        if (!ok) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.homeRenameFail)));
        }
        return;
      case 'delete':
        await _deleteStages([stagePath]);
        return;
    }
  }

  /// 删除指定舞台目录（确认 → 删除 → 收尾）。
  ///
  /// [manageSelection]：
  ///   - true（默认，单舞台菜单删除）：删除后自行退出多选 + 刷新列表
  ///   - false（多选批量删除 `_deleteSelected`）：由外层统一收尾，避免
  ///     提前清空 `_selectedStages` / `_selectedStageRoles` 导致后续分类
  ///     删除被跳过
  ///
  /// 返回 `false` = 用户取消（调用方中止整个批量删除流程）。
  Future<bool> _deleteStages(
    List<String> paths, {
    bool manageSelection = true,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: l10n.stageDeleteTitle,
      message: paths.length == 1
          ? l10n.stageDeleteConfirm(p.basename(paths.first))
          : l10n.stageDeleteMultipleConfirm(paths.length),
    );
    if (!confirmed) return false;

    var failCount = 0;
    for (final path in paths) {
      if (!await deleteStage(path)) failCount++;
    }
    if (!mounted) return false;
    if (manageSelection) {
      _selection.exitSelectMode();
      _refreshLists();
    }
    if (failCount > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeDeleteSelectedFail(failCount))),
      );
    }
    return true;
  }

  /// 长按舞台卡 → 进入多选并**级联选中该舞台内所有角色** + 自动展开舞台。
  ///
  /// 对齐单角色契约树「长按母版 → 级联选中整棵子树 + 自动展开」语义。
  /// 从 `stageProvider(stagePath)` 缓存加载角色列表，构建全部角色 key
  /// （母版卡 + 有存档的子版卡），一并传给 controller。
  void _enterStageSelectMode(String stagePath) {
    final characters =
        ref.read(stageProvider(stagePath)).value?.characters ??
        const <StageCharacter>[];
    final roleKeys = <String>[
      for (final c in characters) ...[
        // 母版卡 key（isChild=false）：统一通过 stageRoleKey 构建
        HomeSelectionController.stageRoleKey(stagePath, c.roleName, c.fileName),
        // 子版卡 key（仅有存档时）：isChild=true
        if (c.hasSave)
          HomeSelectionController.stageRoleKey(
            stagePath,
            c.roleName,
            c.fileName,
            isChild: true,
          ),
      ],
    ];
    _selection.enterStageSelectMode(stagePath, roleKeys);
  }

  /// 多选模式下点击舞台卡 → 切换选中状态。
  void _toggleStageSelect(String stagePath) {
    _selection.toggleStageSelect(stagePath);
  }

  /// 多选模式下点击舞台内角色卡 → 切换选中状态。
  ///
  /// [fileName] 为角色卡文件名（如 `Arjuna.meph`），由 StageCard 传入；
  /// 多选 key 中携带文件名，使批量删除可直接定位目标文件。

  // ============================================================
  // 导航
  // ============================================================

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

  /// 进入多角色舞台叙事页。
  ///
  /// 舞台叙事使用独立的 [StageNarrativeProvider]（与单角色完全隔离），
  /// 因此无需 switchContract 干扰当前契约选择。
  ///
  /// [restoreSaves]：续玩（true）自动恢复各角色存档（有历史 → 子版续玩）；
  /// 母版开局（false，默认）跳过存档、从母版角色卡干净开局（空消息流）。
  ///
  /// **对齐单角色契约树语义**：单角色点「母版」= 进母版空开局；因此舞台卡
  /// 主体 / 「进入」菜单 / 展开区角色母版行都默认从母版开局，只有显式点
  /// 「子版行」或「重新开始」菜单才走对应路径。
  ///
  /// [skipRestoreRoles]：按角色选择母版/子版时，被点角色从母版干净开局
  /// （不恢复存档），其余角色继续各自存档。
  Future<void> _openStageNarrative(
    String stagePath, {
    bool restoreSaves = false,
    Set<String>? skipRestoreRoles,
  }) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StageNarrativeScreen(
          stagePath: stagePath,
          restoreSaves: restoreSaves,
          skipRestoreRoles: skipRestoreRoles,
        ),
      ),
    );
    _refreshLists();
  }

  /// 打开舞台内某角色（母版/子版入口）的共享舞台叙事。
  ///
  /// 与单角色契约树「点母版玩母版、点子版玩子版」对应的多角色语义：
  ///   - 点角色**母版行**（restoreSave=false）→ 整个舞台从母版干净开局
  ///   - 点角色**子版行**（restoreSave=true）→ 恢复所有角色存档
  Future<void> _openStageRole(
    String stagePath,
    String roleName, {
    required bool restoreSave,
  }) async {
    await _openStageNarrative(stagePath, restoreSaves: restoreSave);
  }

  /// 处理角色行 ⋮ 菜单操作（进入 / 预览 / 编辑 / 删除角色卡 / 删除存档）。
  ///
  /// [fileName] 为角色卡文件名（如 `Arjuna.meph`），由 StageCard 直接从
  /// `StageCharacter.fileName` 传递，**不使用中文角色名反查文件名**。
  Future<void> _handleStageRoleMenu(
    String stagePath,
    String roleName,
    String fileName,
    String action,
  ) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'enter':
        await _openStageRole(stagePath, roleName, restoreSave: false);
        return;
      case 'preview':
        await ContractPreviewSheet.showFromFile(
          context,
          dirPath: stagePath,
          fileName: fileName,
        );
        return;
      case 'edit':
        // 编辑母版角色卡 .meph（targetDir = 舞台目录，保存写入该目录）
        final file = File('$stagePath/$fileName');
        if (!await file.exists()) return;
        final content = await file.readAsString();
        if (!mounted) return;
        final saved = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => ContractEditorScreen(
              fileName: fileName,
              initialContent: content,
              targetDir: stagePath,
            ),
          ),
        );
        if (saved != null && mounted) {
          _refreshLists();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.homeContractSaved)));
        }
        return;
      case 'delete_role':
        final confirmed = await ConfirmDeleteDialog.show(
          context,
          title: l10n.stageDeleteTitle,
          message: l10n.stageCardDeleteRoleConfirm(roleName),
        );
        if (!confirmed) return;
        await deleteStageRoleCard(stagePath, fileName);
        if (!mounted) return;
        _refreshLists();
        return;
      case 'delete_child':
        final confirmed = await ConfirmDeleteDialog.show(
          context,
          title: l10n.stageDeleteTitle,
          message: l10n.stageCardDeleteChildConfirm(roleName),
        );
        if (!confirmed) return;
        await deleteStageRoleChild(stagePath, fileName);
        if (!mounted) return;
        _refreshLists();
        return;
    }
  }

  /// 长按角色芯片 → 弹出快捷菜单（进入 / 预览 / 编辑 / 删除）。
  ///
  /// 替代旧版「展开区每个角色的 ⋮ 菜单」，长按角色 chip 弹出上下文菜单，
  /// 保留所有角色级操作的入口。
  Future<void> _handleRoleLongPress(String stagePath, String roleName) async {
    // 查找角色卡文件名
    final characters =
        ref.read(stageProvider(stagePath)).value?.characters ??
        const <StageCharacter>[];
    final match = characters.where((c) => c.roleName == roleName).firstOrNull;
    final fileName = match?.fileName ?? roleName;

    // 弹出角色快捷菜单
    final action = await RoleQuickActionsSheet.show(
      context,
      roleName: roleName,
    );

    if (action == null || !mounted) return;
    await _handleStageRoleMenu(stagePath, roleName, fileName, action);
  }

  /// 处理母版卡片点击：直接进入母版叙事。
  ///
  /// 分支入口已由 [ContractCard] 的分支徽标（↳ N）承载——
  /// 点击徽标弹出 [HomeBranchSheet] 选择分支，母版点击保持直接进入。
  void _onMasterTap(ContractInfo info) {
    if (_selection.isSelectMode) {
      // 多选模式：切换母版选中（含其子树）
      final match = ref
          .read(contractGroupListProvider)
          .value
          ?.where((g) => g.master.fileName == info.fileName)
          .firstOrNull;
      if (match != null) {
        _selection.toggleSelectSubtree(match);
      } else {
        _selection.toggleSelect(info.fileName);
      }
    } else {
      _openNarrative(info);
    }
  }

  // ============================================================
  // 视图构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(contractGroupListProvider);

    // 通过 ListenableBuilder 监听 _selection 的变化自动重绘，
    // 替代原先手动 `setState(() => _selection.xxx())` 的样板。
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        // 全部契约文件数（递归收集所有节点，含所有层级）
        final allFiles =
            groupsAsync.value?.expand((g) => g.allInfos).toList() ?? [];
        // 全部舞台目录（用于全选合并计数 + 全选传递）。
        // 舞台内角色不参与全选/计数——全选只勾选「契约文件 + 舞台目录」两类实体，
        // 与 HomeSelectionController.selectAll 选中范围保持一致。
        final stages = ref
            .read(stageListProvider)
            .value ?? const <StageInfo>[];
        // 全选总数 = 契约文件 + 舞台目录
        final totalSelectable = allFiles.length + stages.length;

        return Scaffold(
          appBar: _selection.isSelectMode
              ? HomeSelectModeAppBar(
                  selectedCount: _selection.totalSelectedCount,
                  totalCount: totalSelectable,
                  onDelete: _selection.totalSelectedCount == 0
                      ? null
                      : _deleteSelected,
                  onCancel: _selection.exitSelectMode,
                  onToggleSelectAll: () {
                    // 全部选中时再点全选 = 取消全选
                    if (_selection.totalSelectedCount == totalSelectable) {
                      _selection.exitSelectMode();
                    } else {
                      _selection.selectAll(
                        groupsAsync.value ?? const [],
                        stages,
                      );
                    }
                  },
                )
              : HomeAppBar(
                  onNewContract: _newContract,
                  onImportContract: _importContract,
                ),
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
              // 已加载契约树：委托 ContractTreeSection 渲染
              // （契约树 + 舞台聚合 + 最近编辑，交互经回调上抛）
              return ContractTreeSection(
                groups: groups,
                selection: _selection,
                onMasterTap: _onMasterTap,
                onMasterMenu: _handleMasterMenu,
                onChildMenu: (child, action) =>
                    _handleChildMenu(context, child, action),
                onChildTap: (child) {
                  if (_selection.isSelectMode) {
                    _selection.toggleSelect(child.fileName);
                  } else {
                    _openNarrative(child);
                  }
                },
                onChildLongPress: (child) {
                  if (!_selection.isSelectMode) {
                    // 长按子节点 → 单独选中（不级联）
                    _selection.enterSelectMode(child.fileName);
                  }
                },
                onEnterNarrative: _openNarrative,
                // ---- 舞台回调 ----
                onStageTap: _openStageNarrative,
                onStageLongPress: _enterStageSelectMode,
                onStageToggleSelect: _toggleStageSelect,
                onStageMenu: _handleStageMenu,
                onRoleTap: (stagePath, roleName, {restoreSave = false}) =>
                    _openStageRole(
                      stagePath,
                      roleName,
                      restoreSave: restoreSave,
                    ),
                onRoleLongPress: _handleRoleLongPress,
              );
            },
          ),
        );
      },
    );
  }
}
