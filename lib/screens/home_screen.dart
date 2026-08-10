import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../app/theme.dart';
import '../providers/contract_provider.dart';
import '../providers/home_selection_controller.dart';
import '../providers/stage_provider.dart';
import '../services/storage/stage_repo.dart';
import '../widgets/dialogs/confirm_delete_dialog.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/home/contract_card.dart';
import '../widgets/home/contract_preview_sheet.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_branch_sheet.dart';
import '../widgets/home/home_brand_header.dart';
import '../widgets/home/home_state_views.dart';
import '../widgets/home/section_header.dart';
import '../widgets/home/stage_card.dart';
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
      for (final stage in ref.read(stageListProvider).value ?? const <StageInfo>[])
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

  /// 删除选中的契约文件 + 选中的舞台目录。
  Future<void> _deleteSelected() async {
    // 1. 删除选中的契约文件（沿用现有逻辑）
    if (_selection.selected.isNotEmpty) {
      await deleteSelectedContract(
        ref,
        context,
        _selection,
        onExitSelectMode: _selection.exitSelectMode,
        onRefreshLists: _refreshLists,
      );
      if (!mounted) return;
    }
    // 2. 删除选中的舞台目录（若无契约选中，也要退出多选 + 刷新）
    if (_selection.selectedStages.isNotEmpty) {
      await _deleteStages(_selection.selectedStages.toList());
      if (!mounted) return;
      _selection.exitSelectMode();
      _refreshLists();
    }
    // 3. 删除选中的舞台内角色卡 / 存档（批量）
    if (_selection.selectedStageRoles.isNotEmpty) {
      await _deleteSelectedStageRoles();
      if (!mounted) return;
    }
  }

  /// 批量删除多选模式下勾选的舞台内角色（母版角色卡 / .child.meph 存档）。
  ///
  /// 选中 key 格式为 `"舞台路径|角色名|角色卡文件名|isChild"`（由
  /// [HomeSelectionController] 生成，携带实际文件名）。逐个解析后
  /// 直接使用文件名调用 [deleteStageRoleCard] / [deleteStageRoleChild]，
  /// 不再用中文角色名反查文件名（角色名与文件名不一定一致）。
  Future<void> _deleteSelectedStageRoles() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = _selection.selectedStageRoles.length;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: l10n.homeDeleteContractTitle,
      message: l10n.homeDeleteSelectedConfirm(count),
    );
    if (!confirmed) return;

    var failCount = 0;
    for (final key in _selection.selectedStageRoles.toList()) {
      final parts = key.split('|');
      if (parts.length != 4) continue;
      final stagePath = parts[0];
      final fileName = parts[2];
      final isChild = parts[3] == 'true';
      final ok = isChild
          ? await deleteStageRoleChild(stagePath, fileName)
          : await deleteStageRoleCard(stagePath, fileName);
      if (!ok) failCount++;
    }

    if (!mounted) return;
    _selection.exitSelectMode();
    _refreshLists();
    if (failCount > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeDeleteSelectedFail(count))),
      );
    }
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
    final stageName = stagePath.split(Platform.pathSeparator).last;

    switch (action) {
      case 'enter':
        // 进入：从母版干净开局（对齐单角色「点母版 = 进母版」）。
        // 想续玩存档请用展开区角色「子版行」或直接点开舞台内的子版入口。
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

  /// 删除指定舞台目录（确认 → 删除 → 刷新）。
  Future<void> _deleteStages(List<String> paths) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: l10n.stageDeleteTitle,
      message: paths.length == 1
          ? l10n.stageDeleteConfirm(
              paths.first.split(Platform.pathSeparator).last,
            )
          : l10n.stageDeleteMultipleConfirm(paths.length),
    );
    if (!confirmed) return;

    var failCount = 0;
    for (final path in paths) {
      if (!await deleteStage(path)) failCount++;
    }
    if (!mounted) return;
    _selection.exitSelectMode();
    _refreshLists();
    if (failCount > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeDeleteSelectedFail(failCount))),
      );
    }
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
        // 母版卡 key：舞台路径|角色名|角色卡文件名|isChild=false
        '$stagePath|${c.roleName}|${c.fileName}|false',
        // 子版卡 key（仅有存档时）：isChild=true
        if (c.hasSave) '$stagePath|${c.roleName}|${c.fileName}|true',
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
  void _toggleStageRoleSelect(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild = false,
  }) {
    _selection.toggleStageRoleSelect(
      stagePath,
      roleName,
      fileName,
      isChild: isChild,
    );
  }

  /// 普通模式长按舞台内角色卡 → 进入多选并选中该角色。
  ///
  /// [fileName] 为角色卡文件名（如 `Arjuna.meph`），由 StageCard 传入；
  /// 多选 key 中携带文件名，使批量删除可直接定位目标文件。
  void _enterStageRoleSelectMode(
    String stagePath,
    String roleName,
    String fileName, {
    bool isChild = false,
  }) {
    _selection.enterStageRoleSelectMode(
      stagePath,
      roleName,
      fileName,
      isChild: isChild,
    );
  }

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
  ///     （空消息流，所有角色从各自母版文件；对齐单角色「点母版 = 进母版」）
  ///   - 点角色**子版行**（restoreSave=true）→ 恢复所有角色存档
  ///     （被点角色从 `.child.meph` 存档续玩，其余角色也续玩各自存档）
  ///
  /// [restoreSave]：true = 恢复全部角色存档（子版续玩）；
  /// false = 全部角色从母版干净开局（母版开局，空消息流）。
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
  /// `StageCharacter.fileName` 传递，**不使用中文角色名反查文件名**——
  /// 角色名与文件名可能不一致（如内置 Kurukshetra 舞台的 `阿周那 → Arjuna.meph`）。
  Future<void> _handleStageRoleMenu(
    String stagePath,
    String roleName,
    String fileName,
    String action,
  ) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'enter':
        // 进入舞台叙事（从母版开局对齐角色行点击行为）
        await _openStageRole(stagePath, roleName, restoreSave: false);
        return;
      case 'preview':
        // 预览角色卡内容（结构化展示契约数据）
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
        // 删除母版角色卡 .meph（直接用 fileName 定位，级联删存档）
        final confirmed = await ConfirmDeleteDialog.show(
          context,
          title: l10n.stageDeleteTitle,
          message: l10n.stageCardDeleteRoleConfirm(roleName),
        );
        if (!confirmed) return;
        await deleteStageRoleCard(stagePath, fileName);
        if (!mounted) return;
        _refreshLists();
        break;
      case 'delete_child':
        // 删除该角色的 .child.meph 存档（基于 fileName 推导存档名）
        final confirmed = await ConfirmDeleteDialog.show(
          context,
          title: l10n.stageDeleteTitle,
          message: l10n.stageCardDeleteChildConfirm(roleName),
        );
        if (!confirmed) return;
        await deleteStageRoleChild(stagePath, fileName);
        if (!mounted) return;
        _refreshLists();
        break;
    }
  }

  /// 处理母版卡片点击。
  ///
  /// 移动端：弹出分支选择器（列出母版本体 + 全部子版，一步直达）。
  /// 桌面端：保持原有行为——有子节点时展开/收起，无子节点时直接进入。
  Future<void> _onMasterTap(BuildContext context, ContractGroup group) async {
    if (!_selection.isSelectMode &&
        MediaQuery.sizeOf(context).width < AppTheme.mobileBreakpoint &&
        group.hasChildren) {
      // 移动端：弹出分支选择器 BottomSheet
      await HomeBranchSheet.show(
        context,
        group: group,
        onEnter: _openNarrative,
      );
      return;
    }

    // 桌面端：保持原有行为
    if (_selection.isSelectMode) {
      _selection.toggleSelectSubtree(group);
    } else {
      _openNarrative(group.master);
    }
  }

  // ============================================================
  // 视图构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(contractGroupListProvider);

    // 通过 ListenableBuilder 监听 _selection 的变化自动重绘，
    // 替代原先手动 `setState(() => _selection.xxx())` 的样板。
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        // 全部契约文件数（递归收集所有节点，含所有层级）
        final allFiles =
            groupsAsync.value?.expand((g) => g.allInfos).toList() ?? [];

        return Scaffold(
          appBar: _selection.isSelectMode
              ? HomeSelectModeAppBar(
                  selectedCount: _selection.totalSelectedCount,
                  totalCount: allFiles.length,
                  onDelete: _selection.totalSelectedCount == 0
                      ? null
                      : _deleteSelected,
                  onCancel: _selection.exitSelectMode,
                  onToggleSelectAll: () {
                    // 全部选中时再点全选 = 取消全选
                    if (_selection.selectedCount == allFiles.length) {
                      _selection.exitSelectMode();
                    } else {
                      _selection.selectAll(groupsAsync.value ?? const []);
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
              return _buildContractList(context, theme, groups);
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // 最近编辑（合并契约 + 舞台）
  // ============================================================

  /// 合并「单角色契约 + 多角色舞台」两侧最近编辑，返回全局最新入口。
  ///
  /// - **契约侧**：所有 [ContractInfo] 中 `lastModified` 最新者 → 进入对应叙事页
  /// - **舞台侧**：所有舞台目录中 `stageLastModified` 最新者 → 进入舞台叙事页
  /// - 比较两侧 mtime，取最新者作为首页右上角「最近编辑」胶囊入口
  ///
  /// 修复：旧实现仅考虑契约树（.meph 文件的 mtime），完全遗漏了多角色舞台
  /// （舞台目录内的角色卡 + `.child.meph` 存档同样代表「最近在玩哪个」）。
  RecentEditEntry? _computeRecentEntry(List<ContractInfo> allContractInfos) {
    // ---- 契约侧候选 ----
    ContractInfo? bestContract;
    for (final info in allContractInfos) {
      final t = info.lastModified;
      if (t == null) continue;
      if (bestContract == null || t.isAfter(bestContract.lastModified!)) {
        bestContract = info;
      }
    }

    // ---- 舞台侧候选（Riverpod 缓存 mtime，避免磁盘 IO 重复） ----
    final stages = ref.watch(stageListProvider).value ?? const <StageInfo>[];
    StageInfo? bestStage;
    DateTime? bestStageTime;
    for (final stage in stages) {
      final t = ref.watch(stageLastModifiedProvider(stage.path)).value;
      if (t == null) continue;
      if (bestStage == null || t.isAfter(bestStageTime!)) {
        bestStage = stage;
        bestStageTime = t;
      }
    }

    final contractTime = bestContract?.lastModified;

    // 舞台更新比契约更新更晚（或契约无 mtime）→ 优先展示舞台入口
    if (bestStage != null &&
        bestStageTime != null &&
        (contractTime == null || bestStageTime.isAfter(contractTime))) {
      final stage = bestStage;
      return RecentEditEntry(
        label: stage.name,
        lastModified: bestStageTime,
        onTap: () => _openStageNarrative(stage.path),
      );
    }

    // 契约侧赢（或两侧均无 mtime）→ 展示契约入口
    final contract = bestContract;
    if (contract == null) return null;
    return RecentEditEntry(
      label: contract.roleName,
      lastModified: contract.lastModified,
      onTap: () => _openNarrative(contract),
    );
  }

  // ============================================================
  // 契约列表（多级命运树）
  // ============================================================

  Widget _buildContractList(
    BuildContext context,
    ThemeData theme,
    List<ContractGroup> groups,
  ) {
    final l10n = AppLocalizations.of(context);
    // 预先计算每棵契约树的全部节点信息（一次性递归收集），
    // 避免在 childSelection 构建与 onLongPress 回调中对同一棵树反复递归遍历
    // （大型层级树场景下减少重复 O(N) 遍历）。
    final groupInfosCache = <String, List<ContractInfo>>{
      for (final group in groups) group.master.fileName: group.allInfos,
    };

    // 「最近编辑」：合并单角色契约 + 多角色舞台两侧候选，取全局最新入口。
    // 直接从已构建的 groupInfosCache 展开全部 ContractInfo（避免再次调用
    // `group.allInfos` getter 对同一棵子树重复递归遍历）。
    final recentEntry = _computeRecentEntry([
      for (final infos in groupInfosCache.values) ...infos,
    ]);

    // 垂直列表。深层分支的横向滚动由 [ContractCard] 子节点区按需内嵌
    // （仅展开的子节点区有深层后代时出现），不在此全局加宽/滚动。
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        // ---- 品牌展示区（多选模式下隐藏，聚焦操作） ----
        // 「最近编辑」快捷入口：显示最近修改的契约或舞台，点击直接进入
        if (!_selection.isSelectMode) HomeBrandHeader(recentEntry: recentEntry),

        // ---- 多角色舞台聚合入口（独立于单角色契约树） ----
        // 支持：⋮ 菜单（进入/重命名/删除）+ 长按多选 + 批量删除
        // （舞台分区标题由 StageSection 内部渲染，带计数徽标）
        StageSection(
          onStageTap: _openStageNarrative,
          onStageLongPress: _selection.isSelectMode
              ? null
              : _enterStageSelectMode,
          onStageToggleSelect: _selection.isSelectMode
              ? _toggleStageSelect
              : null,
          onStageMenu: _selection.isSelectMode ? null : _handleStageMenu,
          isSelectMode: _selection.isSelectMode,
          isStageSelected: _selection.isStageSelected,
          expandedStages: _selection.expandedStages,
          onToggleStageExpanded: _selection.toggleStageExpanded,
          onRoleTap: _selection.isSelectMode
              ? null
              : (stagePath, roleName, {restoreSave = false}) => _openStageRole(
                  stagePath,
                  roleName,
                  restoreSave: restoreSave,
                ),
          onRoleMenu: _selection.isSelectMode ? null : _handleStageRoleMenu,
          onRoleToggleSelect: _selection.isSelectMode
              ? _toggleStageRoleSelect
              : null,
          onRoleLongPress: _selection.isSelectMode
              ? null
              : _enterStageRoleSelectMode,
          isRoleSelected: _selection.isStageRoleSelected,
        ),

        // ---- 单角色契约分区标题（仅普通模式显示，多选时聚焦操作） ----
        if (!_selection.isSelectMode)
          SectionHeader(
            leadingIcon: Icons.menu_book_outlined,
            title: l10n.homeContractSectionTitle,
            count: groups.length,
          ),
        const SizedBox(height: 4),

        // ---- 每棵命运树（母版为根，递归渲染子节点） ----
        for (final group in groups) ...[
          ContractCard(
            group: group,
            childrenExpanded: _selection.expandedGroups.contains(
              group.master.fileName,
            ),
            expandedChildren: _selection.expandedGroups,
            onToggleNode: _selection.toggleChildrenExpanded,
            isSelectMode: _selection.isSelectMode,
            isSelected: _selection.isSelected(group.master.fileName),
            childSelection: {
              for (final info
                  in groupInfosCache[group.master.fileName] ??
                      const <ContractInfo>[])
                info.fileName: _selection.isSelected(info.fileName),
            },
            onTap: () => _onMasterTap(context, group),
            onLongPress: () {
              if (!_selection.isSelectMode) {
                // 长按节点 → 级联选中其整棵子树
                // 同时自动展开该子树路径，使被级联选中的节点立即可见
                final subtreeNames =
                    (groupInfosCache[group.master.fileName] ??
                            const <ContractInfo>[])
                        .map((i) => i.fileName)
                        .toList();
                _selection.enterSelectMode(
                  group.master.fileName,
                  cascadeNames: subtreeNames,
                  expandNodes: subtreeNames,
                );
              }
            },
            onMenu: (action) =>
                _handleMasterMenu(context, group.master, action),
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
            onChildMenu: (child, action) =>
                _handleChildMenu(context, child, action),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
