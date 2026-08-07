// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Mephisto';

  @override
  String get homeTitle => '📜 Mephisto';

  @override
  String get homeNewContract => '新建契约';

  @override
  String get homeImportContract => '导入契约';

  @override
  String get homeSettings => '设置';

  @override
  String homeSelectedCount(Object count) {
    return '已选 $count 项';
  }

  @override
  String get homeCancel => '取消';

  @override
  String get homeDeleteSelected => '删除所选';

  @override
  String get homeSelectAll => '全选';

  @override
  String get homeDeselectAll => '取消全选';

  @override
  String get homeDeleteContractTitle => '删除契约';

  @override
  String homeDeleteSelectedConfirm(Object count) {
    return '确定要删除选中的 $count 个契约文件吗？此操作不可恢复。';
  }

  @override
  String homeDeleteMasterConfirm(Object fileName) {
    return '确定要删除母版 $fileName 及其下所有子版吗？此操作不可恢复。';
  }

  @override
  String get homeDeleteChildTitle => '删除子版';

  @override
  String homeDeleteChildConfirm(Object fileName) {
    return '确定要删除子版文件 $fileName 吗？此操作不可恢复。';
  }

  @override
  String get homeDeleteFail => '╳ 删除失败';

  @override
  String homeDeleteSelectedFail(Object count) {
    return '╳ $count 个契约删除失败';
  }

  @override
  String homeImportSuccess(Object count) {
    return '✦ 已导入 $count 个契约';
  }

  @override
  String homeImportFailAll(Object error) {
    return '╳ 导入失败: $error';
  }

  @override
  String homeImportPartial(Object fail, Object success) {
    return '⚚ 成功 $success 个，失败 $fail 个';
  }

  @override
  String get homeRenameFail => '╳ 重命名失败：目标文件名已存在或旧文件不存在';

  @override
  String get homeContractSaved => '✦ 契约已保存';

  @override
  String get emptyStateNoContract => '契约虚空';

  @override
  String get emptyStateDescription =>
      '尚未找到任何契约\n点击右上角导入 .meph 文件，\n或在设置页中配置契约目录';

  @override
  String get emptyStateRestoring => '正在恢复...';

  @override
  String get emptyStateRestoreBuiltin => '恢复内置角色';

  @override
  String get emptyStateGoSettings => '前往设置';

  @override
  String get emptyStateLoadFail => '加载契约失败';

  @override
  String get homeBrandTitle => 'Mephisto 叙事引擎';

  @override
  String get homeBrandSubtitle => '选择一份命运契约，故事由此展开';

  @override
  String get contractCardEnter => '进入';

  @override
  String get contractCardPreview => '预览';

  @override
  String get contractCardEdit => '编辑';

  @override
  String get contractCardRename => '重命名';

  @override
  String get contractCardDelete => '删除';

  @override
  String get contractCardOperations => '操作';

  @override
  String get contractCardExpandChildren => '展开子版';

  @override
  String get contractCardCollapseChildren => '收起子版';

  @override
  String get narrativeSaveMenu => '存档';

  @override
  String get narrativeSaveCurrent => '保存当前进度';

  @override
  String get narrativeSaveBranch => '另存为分支...';

  @override
  String get narrativeDeleteSave => '删除存档';

  @override
  String get narrativeScrollTop => '跳至第一条历史（Ctrl+Home）';

  @override
  String get narrativeScrollBottom => '跳至最后一条历史（Ctrl+End）';

  @override
  String get narrativeEditContract => '编辑当前契约（保存后规则自动热更新）';

  @override
  String get narrativeDashboard => '仪表盘';

  @override
  String get narrativeClose => '关闭';

  @override
  String get narrativeSettings => '设置';

  @override
  String narrativeSaveSuccess(Object fileName) {
    return '✦ 契约已镌刻: $fileName';
  }

  @override
  String get narrativeSaveFail => '╳ 存档失败：请检查契约目录权限或磁盘空间';

  @override
  String narrativeBranchSaved(Object fileName) {
    return '✦ 分支契约已镌刻: $fileName';
  }

  @override
  String get narrativeBranchFail => '╳ 分支存档失败：请检查契约目录权限或磁盘空间';

  @override
  String get narrativeDeleteSaveSuccess => '⚰ 存档已删除';

  @override
  String get narrativeDeleteSaveNone => '╳ 没有可删除的存档';

  @override
  String get narrativeHotReloadNotice => '✦ 规则已热更新并即时生效（角色名等非规则区块需重启新叙事才生效）';

  @override
  String get narrativeFileWatchUnavailable => '⚠ 文件监听不可用，规则热重载将失效（叙事不受影响）';

  @override
  String narrativeErrorPrefix(Object error) {
    return '╳ $error，梅菲斯特以凡俗之力回应';
  }

  @override
  String get narrativeBranchDialogTitle => '✏️ 另存为分支';

  @override
  String get narrativeBranchLabel => '分支名';

  @override
  String get narrativeBranchHint => '如 dark、light、审判线';

  @override
  String get narrativeConfirm => '保存';

  @override
  String get narrativeEmptyHint => '写下命运的指引，叙事将在契约中生长...';

  @override
  String get messageBubbleThinking => '梅菲斯特正在执笔...';

  @override
  String get inputBarAttachTooltip => '附加上下文（文本，可多选）';

  @override
  String get inputBarHintGenerating => '梅菲斯特正在编织故事...';

  @override
  String get inputBarHintIdle => '写下命运的指引，契约将推动叙事...';

  @override
  String get inputBarSendTooltip => '发送';

  @override
  String inputBarInvalidAttachment(Object fileName) {
    return '╳ $fileName 不是有效文本，已跳过';
  }

  @override
  String get statusBarRuleChip => '规则';

  @override
  String get statusBarMemoryChip => '记忆';

  @override
  String get statusBarHistoryChip => '历史';

  @override
  String diceVerdictTitle(Object count) {
    return '命运结算 · $count 回判定';
  }

  @override
  String diceVerdictThreshold(Object threshold) {
    return '阈值 ≥ $threshold';
  }

  @override
  String diceVerdictTriggered(Object action) {
    return '触发: $action';
  }

  @override
  String get dashboardTitle => '仪表盘';

  @override
  String get previewSheetClose => '关闭';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '亮色';

  @override
  String get settingsThemeDark => '暗色';

  @override
  String get settingsNarrativeWidth => '叙事内容宽度';

  @override
  String get settingsWidthDescription => '叙事界面信息流的最大宽度。移动端自动占满屏幕，此选项主要影响桌面端。';

  @override
  String get settingsNarrativeRules => '叙事规则';

  @override
  String get settingsRulesDescription =>
      '自定义叙事风格，整体替换默认约束。风格描述越精确，输出越贴合预期（明确写出\"以什么风格/诗体/对白方式\"）。';

  @override
  String get settingsRulesHint => '输入叙事规则...';

  @override
  String get settingsResetRules => '恢复默认';

  @override
  String get settingsSaveRules => '保存规则';

  @override
  String get settingsRulesSaved => '✦ 叙事规则已保存';

  @override
  String get settingsRulesReset => '⇄ 已恢复默认叙事规则';

  @override
  String get settingsContractsDir => '契约目录';

  @override
  String get settingsAndroidDirDescription =>
      '契约保存在应用的私有空间，不受 Android 存储权限限制。“内部存储”使用应用专用分区；“外部存储”使用设备大容量分区——两者都在应用私有目录内，卸载应用时都会被清除。Android 系统限制应用直接读写用户公共目录（如下载、文档、SD 卡），因此无法像桌面端那样自由指定契约文件夹。如需从手机其他位置使用契约，请用首页的“导入”功能。';

  @override
  String get settingsIosDirDescription =>
      '契约保存在应用内目录（iOS 系统沙盒限制）。导入和默认加载都使用此目录。';

  @override
  String get settingsDesktopDirDescription =>
      '存放 .meph 契约文件的文件夹。导入和默认加载都使用此目录。';

  @override
  String get settingsDirLoading => '加载中...';

  @override
  String get settingsAndroidExternalLocation =>
      '位置说明：应用外部存储（Android/data 应用私有目录）';

  @override
  String get settingsAndroidInternalLocation => '位置说明：应用内部存储（应用私有目录）';

  @override
  String get settingsIosLocation => '位置说明：应用内目录（iOS 沙盒）';

  @override
  String get settingsAndroidExternalStorage => '存储位置：应用外部空间';

  @override
  String get settingsAndroidInternalStorage => '存储位置：应用内部空间';

  @override
  String get settingsSwitchToInternal => '切换为内部存储';

  @override
  String get settingsSwitchToExternal => '切换为外部存储';

  @override
  String get settingsChangeDir => '更改目录';

  @override
  String get settingsOpenFolder => '打开文件夹';

  @override
  String settingsDirChanged(Object path) {
    return '✦ 契约目录已更新: $path';
  }

  @override
  String get settingsDirChangeFail => '╳ 设置契约目录失败';

  @override
  String get settingsIosSandboxNotice => '╳ iOS 系统沙盒限制：契约仅保存在应用内目录，无法更改位置';

  @override
  String get settingsStorageSwitchFail => '╳ 切换存储位置失败';

  @override
  String get settingsStorageExternalSwitched => '✦ 契约占用地：应用外部存储（卸载应用时清除）';

  @override
  String get settingsStorageInternalSwitched => '✦ 契约占用地：应用内部存储';

  @override
  String get settingsDirNotExist => '╳ 目录不存在';

  @override
  String settingsOpenFolderFail(Object error) {
    return '╳ 打开文件夹失败: $error';
  }

  @override
  String get settingsPlatformNotSupported => '当前平台暂不支持打开文件夹';

  @override
  String get settingsLlmConfig => 'LLM 配置';

  @override
  String get settingsLlmDescription => '叙事生成使用的 AI 服务参数。留空保存将使用默认配置。';

  @override
  String get settingsBackendOllama => '本地 Ollama';

  @override
  String get settingsTestConnection => '测试连接';

  @override
  String get settingsTesting => '测试中...';

  @override
  String get settingsSaveConfig => '保存配置';

  @override
  String get settingsResetConfig => '恢复默认';

  @override
  String get contractEditorNewTitle => '✏️ 新建契约';

  @override
  String get contractEditorEditTitle => '✏️ 编辑契约';

  @override
  String get contractEditorFormatTooltip => '格式化文本（调整缩进、空行并修复运算符空格）';

  @override
  String get contractEditorSave => '保存';

  @override
  String get contractEditorCancel => '取消';

  @override
  String get contractEditorFileName => '文件名（自动补 .meph 后缀）';

  @override
  String get contractEditorFileNameHint => '如 my_story';

  @override
  String get contractEditorLoadingTemplate => '正在加载 faust.meph 模板...';

  @override
  String get contractEditorContentHint => '输入 .meph 契约内容...';

  @override
  String get contractEditorNameEmpty => '╳ 请填写文件名';

  @override
  String contractEditorNameExists(Object fileName) {
    return '╳ 文件名已存在: $fileName';
  }

  @override
  String contractEditorFormatError(
    Object blockName,
    Object line,
    Object message,
  ) {
    return '╳ 格式错误: $message（$blockName第 $line 行）';
  }

  @override
  String contractEditorParseFail(Object error) {
    return '╳ 解析失败: $error';
  }

  @override
  String contractEditorSaveFail(Object error) {
    return '╳ 保存失败: $error';
  }

  @override
  String get contractEditorUnparseable => '无法解析的契约内容';

  @override
  String get contractEditorInfoLine1 =>
      '• 契约以【区块名】组织：角色名 / 锚点 / 世界观 / 角色背景 / 开局场景 / 状态 / 规则 / 记忆 / 历史';

  @override
  String get contractEditorInfoLine2 =>
      '• 规则格式：[规则名] if 条件 -> 动作；任意【自定义区块】可作为草稿/备忘，不会报错';

  @override
  String get contractEditorInfoLine3 => '• 保存时自动校验格式并定位错误';

  @override
  String get contractEditorInfoLine4 =>
      '• 需要更专业的编辑体验（行号、语法高亮、自动补全）等等可在 VSCode 安装 Mephisto 插件编辑 .meph 文件';

  @override
  String contractEditorErrorLine(
    Object blockName,
    Object line,
    Object message,
  ) {
    return '第 $line 行$blockName：$message';
  }

  @override
  String contractEditorErrorBlock(Object blockName) {
    return '，区块「$blockName」';
  }

  @override
  String get textInputDialogConfirm => '确定';

  @override
  String get textInputDialogCancel => '取消';

  @override
  String get renameDialogTitle => '✏️ 重命名契约';

  @override
  String get renameDialogLabel => '新文件名';

  @override
  String get renameDialogHelper => '需以 .meph 结尾';

  @override
  String get renameDialogConfirm => '重命名';

  @override
  String get renameDialogNameExists => '该文件名已存在，请更换';

  @override
  String get confirmDeleteCancel => '取消';

  @override
  String get confirmDeleteDelete => '删除';

  @override
  String get narrativeProviderGenFailed => '生成回复时发生异常，请重试';

  @override
  String get narrativeProviderAutoSaveFail => '自动存档失败，进度未写入磁盘';

  @override
  String get narrativeProviderSaveFail => '存档失败，请检查契约目录权限或磁盘空间';

  @override
  String get narrativeProviderHotReloadFail => '契约热重载失败，已保留原设定';

  @override
  String get contractFallbackNotice => '当前契约文件缺失或损坏，已加载内置模板';

  @override
  String get languageLabel => '语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';
}
