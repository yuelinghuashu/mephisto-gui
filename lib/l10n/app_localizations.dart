import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Mephisto'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In zh, this message translates to:
  /// **'📜 Mephisto'**
  String get homeTitle;

  /// No description provided for @homeNewContract.
  ///
  /// In zh, this message translates to:
  /// **'新建契约'**
  String get homeNewContract;

  /// No description provided for @homeImportContract.
  ///
  /// In zh, this message translates to:
  /// **'导入契约'**
  String get homeImportContract;

  /// No description provided for @homeSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get homeSettings;

  /// No description provided for @homeSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String homeSelectedCount(Object count);

  /// No description provided for @homeCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get homeCancel;

  /// No description provided for @homeDeleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除所选'**
  String get homeDeleteSelected;

  /// No description provided for @homeSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get homeSelectAll;

  /// No description provided for @homeDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get homeDeselectAll;

  /// No description provided for @homeDeleteContractTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除契约'**
  String get homeDeleteContractTitle;

  /// No description provided for @homeDeleteSelectedConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个契约文件吗？此操作不可恢复。'**
  String homeDeleteSelectedConfirm(Object count);

  /// No description provided for @homeDeleteMasterConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除母版 {fileName} 及其下所有子版吗？此操作不可恢复。'**
  String homeDeleteMasterConfirm(Object fileName);

  /// No description provided for @homeDeleteChildTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除子版'**
  String get homeDeleteChildTitle;

  /// No description provided for @homeDeleteChildConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除子版文件 {fileName} 吗？此操作不可恢复。'**
  String homeDeleteChildConfirm(Object fileName);

  /// No description provided for @homeDeleteFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 删除失败'**
  String get homeDeleteFail;

  /// No description provided for @homeDeleteSelectedFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ {count} 个契约删除失败'**
  String homeDeleteSelectedFail(Object count);

  /// No description provided for @homeImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'✦ 已导入 {count} 个契约'**
  String homeImportSuccess(Object count);

  /// No description provided for @homeImportFailAll.
  ///
  /// In zh, this message translates to:
  /// **'╳ 导入失败: {error}'**
  String homeImportFailAll(Object error);

  /// No description provided for @homeImportPartial.
  ///
  /// In zh, this message translates to:
  /// **'⚚ 成功 {success} 个，失败 {fail} 个'**
  String homeImportPartial(Object fail, Object success);

  /// No description provided for @homeExportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'✦ 已导出: {path}'**
  String homeExportSuccess(Object path);

  /// No description provided for @homeExportFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 导出失败: {error}'**
  String homeExportFail(Object error);

  /// No description provided for @homeRenameFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 重命名失败：目标文件名已存在或旧文件不存在'**
  String get homeRenameFail;

  /// No description provided for @homeContractSaved.
  ///
  /// In zh, this message translates to:
  /// **'✦ 契约已保存'**
  String get homeContractSaved;

  /// No description provided for @homeNoBranches.
  ///
  /// In zh, this message translates to:
  /// **'此母版暂未创建子版分支'**
  String get homeNoBranches;

  /// No description provided for @emptyStateNoContract.
  ///
  /// In zh, this message translates to:
  /// **'契约虚空'**
  String get emptyStateNoContract;

  /// No description provided for @emptyStateDescription.
  ///
  /// In zh, this message translates to:
  /// **'尚未找到任何契约\n点击右上角导入 .meph 文件，\n或在设置页中配置契约目录'**
  String get emptyStateDescription;

  /// No description provided for @emptyStateRestoring.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复...'**
  String get emptyStateRestoring;

  /// No description provided for @emptyStateRestoreBuiltin.
  ///
  /// In zh, this message translates to:
  /// **'恢复内置角色'**
  String get emptyStateRestoreBuiltin;

  /// No description provided for @emptyStateGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往设置'**
  String get emptyStateGoSettings;

  /// No description provided for @emptyStateLoadFail.
  ///
  /// In zh, this message translates to:
  /// **'加载契约失败'**
  String get emptyStateLoadFail;

  /// No description provided for @homeBrandTitle.
  ///
  /// In zh, this message translates to:
  /// **'Mephisto 叙事引擎'**
  String get homeBrandTitle;

  /// No description provided for @homeBrandSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'签下契约，书写命运'**
  String get homeBrandSubtitle;

  /// No description provided for @homeStageSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'多角色舞台'**
  String get homeStageSectionTitle;

  /// No description provided for @homeContractSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'单角色契约'**
  String get homeContractSectionTitle;

  /// No description provided for @homeSectionExpand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get homeSectionExpand;

  /// No description provided for @homeSectionCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get homeSectionCollapse;

  /// No description provided for @stageCardCharacterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 位角色'**
  String stageCardCharacterCount(Object count);

  /// No description provided for @stageCardLastModified.
  ///
  /// In zh, this message translates to:
  /// **'最近活动：{time}'**
  String stageCardLastModified(Object time);

  /// No description provided for @stageCardHasSave.
  ///
  /// In zh, this message translates to:
  /// **'有存档'**
  String get stageCardHasSave;

  /// No description provided for @stageCardRestart.
  ///
  /// In zh, this message translates to:
  /// **'重新开始（回母版）'**
  String get stageCardRestart;

  /// No description provided for @stageCardRoleMaster.
  ///
  /// In zh, this message translates to:
  /// **'母版'**
  String get stageCardRoleMaster;

  /// No description provided for @stageCardRoleChild.
  ///
  /// In zh, this message translates to:
  /// **'{role} · 子版'**
  String stageCardRoleChild(Object role);

  /// No description provided for @stageCardRoleChildSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'续玩存档'**
  String get stageCardRoleChildSubtitle;

  /// No description provided for @stageCardExport.
  ///
  /// In zh, this message translates to:
  /// **'导出（舞台 ZIP）'**
  String get stageCardExport;

  /// No description provided for @stageCardDeleteRole.
  ///
  /// In zh, this message translates to:
  /// **'删除母版角色卡'**
  String get stageCardDeleteRole;

  /// No description provided for @stageCardDeleteChild.
  ///
  /// In zh, this message translates to:
  /// **'删除存档'**
  String get stageCardDeleteChild;

  /// No description provided for @stageCardDeleteRoleConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除角色「{roleName}」的母版文件及其存档吗？此操作不可恢复。'**
  String stageCardDeleteRoleConfirm(Object roleName);

  /// No description provided for @stageCardDeleteChildConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除角色「{roleName}」的存档吗？此操作不可恢复。'**
  String stageCardDeleteChildConfirm(Object roleName);

  /// No description provided for @stageNarrativeReset.
  ///
  /// In zh, this message translates to:
  /// **'重置会话（回到母版开局）'**
  String get stageNarrativeReset;

  /// No description provided for @stageNarrativeResetDone.
  ///
  /// In zh, this message translates to:
  /// **'⇄ 已重置会话，舞台回到母版开局'**
  String get stageNarrativeResetDone;

  /// No description provided for @stageRenameDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'✏️ 重命名舞台'**
  String get stageRenameDialogTitle;

  /// No description provided for @stageRenameDialogLabel.
  ///
  /// In zh, this message translates to:
  /// **'新舞台名'**
  String get stageRenameDialogLabel;

  /// No description provided for @stageRenameDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get stageRenameDialogConfirm;

  /// No description provided for @stageRenameNameExists.
  ///
  /// In zh, this message translates to:
  /// **'该舞台名已存在，请更换'**
  String get stageRenameNameExists;

  /// No description provided for @stageDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除舞台'**
  String get stageDeleteTitle;

  /// No description provided for @stageDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除舞台 {name} 及其所有角色吗？此操作不可恢复。'**
  String stageDeleteConfirm(Object name);

  /// No description provided for @stageDeleteMultipleConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个舞台吗？此操作不可恢复。'**
  String stageDeleteMultipleConfirm(Object count);

  /// No description provided for @contractCardEnter.
  ///
  /// In zh, this message translates to:
  /// **'进入'**
  String get contractCardEnter;

  /// No description provided for @contractCardPreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get contractCardPreview;

  /// No description provided for @contractCardEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get contractCardEdit;

  /// No description provided for @contractCardExport.
  ///
  /// In zh, this message translates to:
  /// **'导出（命运树 ZIP）'**
  String get contractCardExport;

  /// No description provided for @contractCardRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get contractCardRename;

  /// No description provided for @contractCardDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get contractCardDelete;

  /// No description provided for @contractCardOperations.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get contractCardOperations;

  /// No description provided for @contractCardExpandChildren.
  ///
  /// In zh, this message translates to:
  /// **'展开子版'**
  String get contractCardExpandChildren;

  /// No description provided for @contractCardCollapseChildren.
  ///
  /// In zh, this message translates to:
  /// **'收起子版'**
  String get contractCardCollapseChildren;

  /// No description provided for @contractBranchCount.
  ///
  /// In zh, this message translates to:
  /// **'分支 · {count}'**
  String contractBranchCount(Object count);

  /// No description provided for @narrativeSaveMenu.
  ///
  /// In zh, this message translates to:
  /// **'存档'**
  String get narrativeSaveMenu;

  /// No description provided for @narrativeSaveBranch.
  ///
  /// In zh, this message translates to:
  /// **'另存为分支...'**
  String get narrativeSaveBranch;

  /// No description provided for @narrativeDeleteSave.
  ///
  /// In zh, this message translates to:
  /// **'删除存档'**
  String get narrativeDeleteSave;

  /// No description provided for @narrativeScrollTop.
  ///
  /// In zh, this message translates to:
  /// **'跳至第一条历史（Ctrl+Home）'**
  String get narrativeScrollTop;

  /// No description provided for @narrativeScrollBottom.
  ///
  /// In zh, this message translates to:
  /// **'跳至最后一条历史（Ctrl+End）'**
  String get narrativeScrollBottom;

  /// No description provided for @narrativeEditContract.
  ///
  /// In zh, this message translates to:
  /// **'编辑当前契约（保存后规则自动热更新）'**
  String get narrativeEditContract;

  /// No description provided for @narrativeDashboard.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘'**
  String get narrativeDashboard;

  /// No description provided for @narrativeClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get narrativeClose;

  /// No description provided for @narrativeSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get narrativeSettings;

  /// No description provided for @narrativeBranchSaved.
  ///
  /// In zh, this message translates to:
  /// **'✦ 分支契约已镌刻: {fileName}'**
  String narrativeBranchSaved(Object fileName);

  /// No description provided for @narrativeBranchFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 分支存档失败：请检查契约目录权限或磁盘空间'**
  String get narrativeBranchFail;

  /// No description provided for @narrativeDeleteSaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'⚰ 存档已删除'**
  String get narrativeDeleteSaveSuccess;

  /// No description provided for @narrativeDeleteSaveNone.
  ///
  /// In zh, this message translates to:
  /// **'╳ 没有可删除的存档'**
  String get narrativeDeleteSaveNone;

  /// No description provided for @narrativeHotReloadNotice.
  ///
  /// In zh, this message translates to:
  /// **'✦ 规则已热更新并即时生效（角色名等非规则区块需重启新叙事才生效）'**
  String get narrativeHotReloadNotice;

  /// No description provided for @narrativeFileWatchUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'⚠ 文件监听不可用，规则热重载将失效（叙事不受影响）'**
  String get narrativeFileWatchUnavailable;

  /// No description provided for @narrativeRestoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'╳ 存档恢复失败：存档文件可能存在但内容已损坏，已从母版开始新叙事'**
  String get narrativeRestoreFailed;

  /// No description provided for @narrativeErrorPrefix.
  ///
  /// In zh, this message translates to:
  /// **'╳ {error}，梅菲斯特以凡俗之力回应'**
  String narrativeErrorPrefix(Object error);

  /// No description provided for @narrativeBranchDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'✏️ 另存为分支'**
  String get narrativeBranchDialogTitle;

  /// No description provided for @narrativeBranchLabel.
  ///
  /// In zh, this message translates to:
  /// **'分支名'**
  String get narrativeBranchLabel;

  /// No description provided for @narrativeBranchHint.
  ///
  /// In zh, this message translates to:
  /// **'如 dark、light、审判线'**
  String get narrativeBranchHint;

  /// No description provided for @narrativeBranchTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'命运说明'**
  String get narrativeBranchTitleLabel;

  /// No description provided for @narrativeBranchTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'描述这条支流将走向何方（可留空），首页将以此命名枝桠'**
  String get narrativeBranchTitleHint;

  /// No description provided for @narrativeStopGenerating.
  ///
  /// In zh, this message translates to:
  /// **'停止生成'**
  String get narrativeStopGenerating;

  /// No description provided for @narrativeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get narrativeConfirm;

  /// No description provided for @narrativeEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'写下命运的指引，叙事将在契约中生长...'**
  String get narrativeEmptyHint;

  /// No description provided for @messageBubbleThinking.
  ///
  /// In zh, this message translates to:
  /// **'梅菲斯特正在执笔...'**
  String get messageBubbleThinking;

  /// No description provided for @messageMenuCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get messageMenuCopy;

  /// No description provided for @messageMenuRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get messageMenuRegenerate;

  /// No description provided for @messageMenuCopied.
  ///
  /// In zh, this message translates to:
  /// **'✦ 已复制到剪贴板'**
  String get messageMenuCopied;

  /// No description provided for @inputBarAttachTooltip.
  ///
  /// In zh, this message translates to:
  /// **'附加上下文（文本，可多选）'**
  String get inputBarAttachTooltip;

  /// No description provided for @inputBarHintGenerating.
  ///
  /// In zh, this message translates to:
  /// **'梅菲斯特正在编织故事...'**
  String get inputBarHintGenerating;

  /// No description provided for @inputBarHintIdle.
  ///
  /// In zh, this message translates to:
  /// **'写下命运的指引，契约将推动叙事...'**
  String get inputBarHintIdle;

  /// No description provided for @inputBarSendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get inputBarSendTooltip;

  /// No description provided for @inputBarInvalidAttachment.
  ///
  /// In zh, this message translates to:
  /// **'╳ {fileName} 不是有效文本，已跳过'**
  String inputBarInvalidAttachment(Object fileName);

  /// No description provided for @statusBarRuleChip.
  ///
  /// In zh, this message translates to:
  /// **'规则'**
  String get statusBarRuleChip;

  /// No description provided for @statusBarMemoryChip.
  ///
  /// In zh, this message translates to:
  /// **'记忆'**
  String get statusBarMemoryChip;

  /// No description provided for @statusBarHistoryChip.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get statusBarHistoryChip;

  /// No description provided for @diceVerdictTitle.
  ///
  /// In zh, this message translates to:
  /// **'命运结算 · {count} 回判定'**
  String diceVerdictTitle(Object count);

  /// No description provided for @diceVerdictThreshold.
  ///
  /// In zh, this message translates to:
  /// **'阈值 ≥ {threshold}'**
  String diceVerdictThreshold(Object threshold);

  /// No description provided for @diceVerdictTriggered.
  ///
  /// In zh, this message translates to:
  /// **'触发: {action}'**
  String diceVerdictTriggered(Object action);

  /// No description provided for @dashboardTitle.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘'**
  String get dashboardTitle;

  /// No description provided for @previewSheetClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get previewSheetClose;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsThemeDescription.
  ///
  /// In zh, this message translates to:
  /// **'明暗主题模式。'**
  String get settingsThemeDescription;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'亮色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'暗色'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In zh, this message translates to:
  /// **'简体中文 / English。'**
  String get settingsLanguageDescription;

  /// No description provided for @settingsNarrativeWidth.
  ///
  /// In zh, this message translates to:
  /// **'叙事内容宽度'**
  String get settingsNarrativeWidth;

  /// No description provided for @settingsWidthDescription.
  ///
  /// In zh, this message translates to:
  /// **'叙事界面信息流的最大宽度。移动端自动占满屏幕，此选项主要影响桌面端。'**
  String get settingsWidthDescription;

  /// No description provided for @settingsWidthNarrow.
  ///
  /// In zh, this message translates to:
  /// **'窄'**
  String get settingsWidthNarrow;

  /// No description provided for @settingsWidthMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get settingsWidthMedium;

  /// No description provided for @settingsWidthWide.
  ///
  /// In zh, this message translates to:
  /// **'宽'**
  String get settingsWidthWide;

  /// No description provided for @settingsWidthFull.
  ///
  /// In zh, this message translates to:
  /// **'满屏'**
  String get settingsWidthFull;

  /// No description provided for @settingsHistoryWindow.
  ///
  /// In zh, this message translates to:
  /// **'历史消息窗口'**
  String get settingsHistoryWindow;

  /// No description provided for @settingsHistoryWindowDescription.
  ///
  /// In zh, this message translates to:
  /// **'发送给 LLM 的历史对话条数上限。窗口越小，token 消耗越低；窗口越大，模型对前文的记忆越完整。'**
  String get settingsHistoryWindowDescription;

  /// No description provided for @settingsHistoryWindowNarrow.
  ///
  /// In zh, this message translates to:
  /// **'20 条'**
  String get settingsHistoryWindowNarrow;

  /// No description provided for @settingsHistoryWindowMedium.
  ///
  /// In zh, this message translates to:
  /// **'40 条'**
  String get settingsHistoryWindowMedium;

  /// No description provided for @settingsHistoryWindowWide.
  ///
  /// In zh, this message translates to:
  /// **'60 条'**
  String get settingsHistoryWindowWide;

  /// No description provided for @settingsHistoryWindowFull.
  ///
  /// In zh, this message translates to:
  /// **'全部发送'**
  String get settingsHistoryWindowFull;

  /// No description provided for @settingsMemoryLimit.
  ///
  /// In zh, this message translates to:
  /// **'记忆注入上限'**
  String get settingsMemoryLimit;

  /// No description provided for @settingsMemoryLimitDescription.
  ///
  /// In zh, this message translates to:
  /// **'每轮发送给 LLM 的记忆条数上限。窗口越小，token 消耗越低；超过上限时高权重记忆（≥4 星）全部保留，其余按权重降序补足。'**
  String get settingsMemoryLimitDescription;

  /// No description provided for @settingsMemoryLimitCompact.
  ///
  /// In zh, this message translates to:
  /// **'10 条'**
  String get settingsMemoryLimitCompact;

  /// No description provided for @settingsMemoryLimitStandard.
  ///
  /// In zh, this message translates to:
  /// **'20 条'**
  String get settingsMemoryLimitStandard;

  /// No description provided for @settingsMemoryLimitExtended.
  ///
  /// In zh, this message translates to:
  /// **'30 条'**
  String get settingsMemoryLimitExtended;

  /// No description provided for @settingsMemoryLimitFull.
  ///
  /// In zh, this message translates to:
  /// **'全部注入'**
  String get settingsMemoryLimitFull;

  /// No description provided for @settingsNarrativeRules.
  ///
  /// In zh, this message translates to:
  /// **'叙事规则'**
  String get settingsNarrativeRules;

  /// No description provided for @settingsRulesDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义叙事风格，整体替换默认约束。风格描述越精确，输出越贴合预期（明确写出\"以什么风格/诗体/对白方式\"）。\n\n💡 最佳实践：在规则末尾附上一段你期望格式的「正确示例」——LLM 有了可逐字参照的完整范本，格式就不会跑偏（仅描述风格而不给示例，容易让模型自由发挥而偏离格式）。'**
  String get settingsRulesDescription;

  /// No description provided for @settingsRulesHint.
  ///
  /// In zh, this message translates to:
  /// **'输入叙事规则...'**
  String get settingsRulesHint;

  /// No description provided for @settingsResetRules.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get settingsResetRules;

  /// No description provided for @settingsSaveRules.
  ///
  /// In zh, this message translates to:
  /// **'保存规则'**
  String get settingsSaveRules;

  /// No description provided for @settingsRulesSaved.
  ///
  /// In zh, this message translates to:
  /// **'✦ 叙事规则已保存'**
  String get settingsRulesSaved;

  /// No description provided for @settingsRulesReset.
  ///
  /// In zh, this message translates to:
  /// **'⇄ 已恢复默认叙事规则'**
  String get settingsRulesReset;

  /// No description provided for @settingsContractsDir.
  ///
  /// In zh, this message translates to:
  /// **'契约目录'**
  String get settingsContractsDir;

  /// No description provided for @settingsAndroidDirDescription.
  ///
  /// In zh, this message translates to:
  /// **'契约保存在应用的私有空间，不受 Android 存储权限限制。“内部存储”使用应用专用分区；“外部存储”使用设备大容量分区——两者都在应用私有目录内，卸载应用时都会被清除。Android 系统限制应用直接读写用户公共目录（如下载、文档、SD 卡），因此无法像桌面端那样自由指定契约文件夹。如需从手机其他位置使用契约，请用首页的“导入”功能。'**
  String get settingsAndroidDirDescription;

  /// No description provided for @settingsIosDirDescription.
  ///
  /// In zh, this message translates to:
  /// **'契约保存在应用内目录（iOS 系统沙盒限制）。导入和默认加载都使用此目录。'**
  String get settingsIosDirDescription;

  /// No description provided for @settingsDesktopDirDescription.
  ///
  /// In zh, this message translates to:
  /// **'存放 .meph 契约文件的文件夹。导入和默认加载都使用此目录。'**
  String get settingsDesktopDirDescription;

  /// No description provided for @settingsDirLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get settingsDirLoading;

  /// No description provided for @settingsAndroidExternalLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置说明：应用外部存储（Android/data 应用私有目录）'**
  String get settingsAndroidExternalLocation;

  /// No description provided for @settingsAndroidInternalLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置说明：应用内部存储（应用私有目录）'**
  String get settingsAndroidInternalLocation;

  /// No description provided for @settingsIosLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置说明：应用内目录（iOS 沙盒）'**
  String get settingsIosLocation;

  /// No description provided for @settingsAndroidExternalStorage.
  ///
  /// In zh, this message translates to:
  /// **'存储位置：应用外部空间'**
  String get settingsAndroidExternalStorage;

  /// No description provided for @settingsAndroidInternalStorage.
  ///
  /// In zh, this message translates to:
  /// **'存储位置：应用内部空间'**
  String get settingsAndroidInternalStorage;

  /// No description provided for @settingsSwitchToInternal.
  ///
  /// In zh, this message translates to:
  /// **'切换为内部存储'**
  String get settingsSwitchToInternal;

  /// No description provided for @settingsSwitchToExternal.
  ///
  /// In zh, this message translates to:
  /// **'切换为外部存储'**
  String get settingsSwitchToExternal;

  /// No description provided for @settingsChangeDir.
  ///
  /// In zh, this message translates to:
  /// **'更改目录'**
  String get settingsChangeDir;

  /// No description provided for @settingsOpenFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹'**
  String get settingsOpenFolder;

  /// No description provided for @settingsDirChanged.
  ///
  /// In zh, this message translates to:
  /// **'✦ 契约目录已更新: {path}'**
  String settingsDirChanged(Object path);

  /// No description provided for @settingsDirChangeFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 设置契约目录失败'**
  String get settingsDirChangeFail;

  /// No description provided for @settingsIosSandboxNotice.
  ///
  /// In zh, this message translates to:
  /// **'╳ iOS 系统沙盒限制：契约仅保存在应用内目录，无法更改位置'**
  String get settingsIosSandboxNotice;

  /// No description provided for @settingsStorageSwitchFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 切换存储位置失败'**
  String get settingsStorageSwitchFail;

  /// No description provided for @settingsStorageExternalSwitched.
  ///
  /// In zh, this message translates to:
  /// **'✦ 契约占用地：应用外部存储（卸载应用时清除）'**
  String get settingsStorageExternalSwitched;

  /// No description provided for @settingsStorageInternalSwitched.
  ///
  /// In zh, this message translates to:
  /// **'✦ 契约占用地：应用内部存储'**
  String get settingsStorageInternalSwitched;

  /// No description provided for @settingsDirNotExist.
  ///
  /// In zh, this message translates to:
  /// **'╳ 目录不存在'**
  String get settingsDirNotExist;

  /// No description provided for @settingsOpenFolderFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 打开文件夹失败: {error}'**
  String settingsOpenFolderFail(Object error);

  /// No description provided for @settingsPlatformNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台暂不支持打开文件夹'**
  String get settingsPlatformNotSupported;

  /// No description provided for @settingsLlmConfig.
  ///
  /// In zh, this message translates to:
  /// **'LLM 配置'**
  String get settingsLlmConfig;

  /// No description provided for @settingsLlmDescription.
  ///
  /// In zh, this message translates to:
  /// **'叙事生成使用的 AI 服务参数。留空保存将使用默认配置。'**
  String get settingsLlmDescription;

  /// No description provided for @settingsBackendOpenai.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容'**
  String get settingsBackendOpenai;

  /// No description provided for @settingsBackendOllama.
  ///
  /// In zh, this message translates to:
  /// **'本地 Ollama'**
  String get settingsBackendOllama;

  /// No description provided for @settingsApiKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get settingsApiKeyLabel;

  /// No description provided for @settingsApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'sk-...（Ollama 可留空）'**
  String get settingsApiKeyHint;

  /// No description provided for @settingsApiKeyPaste.
  ///
  /// In zh, this message translates to:
  /// **'从剪贴板导入'**
  String get settingsApiKeyPaste;

  /// No description provided for @settingsApiKeyPasteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'✦ 已从剪贴板导入 API Key'**
  String get settingsApiKeyPasteSuccess;

  /// No description provided for @settingsApiKeyPasteEmpty.
  ///
  /// In zh, this message translates to:
  /// **'╳ 剪贴板中没有可导入的内容'**
  String get settingsApiKeyPasteEmpty;

  /// No description provided for @settingsBaseUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'Base URL'**
  String get settingsBaseUrlLabel;

  /// No description provided for @settingsBaseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://api.deepseek.com/v1'**
  String get settingsBaseUrlHint;

  /// No description provided for @settingsModelLabel.
  ///
  /// In zh, this message translates to:
  /// **'Model'**
  String get settingsModelLabel;

  /// No description provided for @settingsModelHint.
  ///
  /// In zh, this message translates to:
  /// **'deepseek-v4-flash / qwen2.5:7b'**
  String get settingsModelHint;

  /// No description provided for @settingsMaxTokensLabel.
  ///
  /// In zh, this message translates to:
  /// **'Max Tokens'**
  String get settingsMaxTokensLabel;

  /// No description provided for @settingsTimeoutLabel.
  ///
  /// In zh, this message translates to:
  /// **'超时（秒）'**
  String get settingsTimeoutLabel;

  /// No description provided for @settingsTimeoutHint.
  ///
  /// In zh, this message translates to:
  /// **'60'**
  String get settingsTimeoutHint;

  /// No description provided for @settingsRetriesLabel.
  ///
  /// In zh, this message translates to:
  /// **'最大重试'**
  String get settingsRetriesLabel;

  /// No description provided for @settingsRetriesHint.
  ///
  /// In zh, this message translates to:
  /// **'1'**
  String get settingsRetriesHint;

  /// No description provided for @settingsMaxTokensHint.
  ///
  /// In zh, this message translates to:
  /// **'4096'**
  String get settingsMaxTokensHint;

  /// No description provided for @settingsTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get settingsTestConnection;

  /// No description provided for @settingsTesting.
  ///
  /// In zh, this message translates to:
  /// **'测试中...'**
  String get settingsTesting;

  /// No description provided for @settingsSaveConfig.
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get settingsSaveConfig;

  /// No description provided for @settingsResetConfig.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get settingsResetConfig;

  /// No description provided for @settingsConfigSaved.
  ///
  /// In zh, this message translates to:
  /// **'✦ LLM 配置已保存'**
  String get settingsConfigSaved;

  /// No description provided for @settingsConfigSaveFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ Base URL 和 Model 不能为空'**
  String get settingsConfigSaveFail;

  /// No description provided for @settingsConfigReset.
  ///
  /// In zh, this message translates to:
  /// **'⇄ 已恢复默认配置'**
  String get settingsConfigReset;

  /// No description provided for @settingsTestNeedBaseUrlModel.
  ///
  /// In zh, this message translates to:
  /// **'╳ 请先填写 Base URL 和 Model'**
  String get settingsTestNeedBaseUrlModel;

  /// No description provided for @settingsTestSuccess.
  ///
  /// In zh, this message translates to:
  /// **'✦ 连接成功，模型可用'**
  String get settingsTestSuccess;

  /// No description provided for @settingsTestFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 连接失败: {error}'**
  String settingsTestFail(Object error);

  /// No description provided for @settingsAuxLlmEnabled.
  ///
  /// In zh, this message translates to:
  /// **'使用独立辅助模型'**
  String get settingsAuxLlmEnabled;

  /// No description provided for @settingsAuxLlmDescription.
  ///
  /// In zh, this message translates to:
  /// **'记忆提取/压缩等后台任务使用独立模型，主叙事不受影响。适合用轻量模型降低长对话使用成本。开启后需填写辅助模型参数（可复用主配置的 API Key / Base URL）。'**
  String get settingsAuxLlmDescription;

  /// No description provided for @settingsAuxModelLabel.
  ///
  /// In zh, this message translates to:
  /// **'辅助模型名称'**
  String get settingsAuxModelLabel;

  /// No description provided for @settingsAuxModelHint.
  ///
  /// In zh, this message translates to:
  /// **'如 deepseek-chat / qwen2.5:7b（留空继承主模型）'**
  String get settingsAuxModelHint;

  /// No description provided for @settingsAuxBaseUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'辅助模型 Base URL（留空继承主配置）'**
  String get settingsAuxBaseUrlLabel;

  /// No description provided for @settingsAuxApiKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'辅助模型 API Key（留空继承主配置）'**
  String get settingsAuxApiKeyLabel;

  /// No description provided for @settingsAuxMaxTokensLabel.
  ///
  /// In zh, this message translates to:
  /// **'辅助模型 Max Tokens'**
  String get settingsAuxMaxTokensLabel;

  /// No description provided for @settingsAuxTimeoutLabel.
  ///
  /// In zh, this message translates to:
  /// **'辅助模型超时（秒）'**
  String get settingsAuxTimeoutLabel;

  /// No description provided for @settingsAuxSaveConfig.
  ///
  /// In zh, this message translates to:
  /// **'保存辅助配置'**
  String get settingsAuxSaveConfig;

  /// No description provided for @settingsAuxSaved.
  ///
  /// In zh, this message translates to:
  /// **'✦ 辅助模型配置已保存'**
  String get settingsAuxSaved;

  /// No description provided for @settingsAuxReset.
  ///
  /// In zh, this message translates to:
  /// **'⇄ 已清除辅助模型配置（回退共用主配置）'**
  String get settingsAuxReset;

  /// No description provided for @settingsAuxDivide.
  ///
  /// In zh, this message translates to:
  /// **'辅助任务模型'**
  String get settingsAuxDivide;

  /// No description provided for @contractEditorNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'✏️ 新建契约'**
  String get contractEditorNewTitle;

  /// No description provided for @contractEditorEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'✏️ 编辑契约'**
  String get contractEditorEditTitle;

  /// No description provided for @contractEditorFormatTooltip.
  ///
  /// In zh, this message translates to:
  /// **'格式化文本（调整缩进、空行并修复运算符空格）'**
  String get contractEditorFormatTooltip;

  /// No description provided for @contractEditorSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get contractEditorSave;

  /// No description provided for @contractEditorCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get contractEditorCancel;

  /// No description provided for @contractEditorFileName.
  ///
  /// In zh, this message translates to:
  /// **'文件名（自动补 .meph 后缀）'**
  String get contractEditorFileName;

  /// No description provided for @contractEditorFileNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如 my_story'**
  String get contractEditorFileNameHint;

  /// No description provided for @contractEditorLoadingTemplate.
  ///
  /// In zh, this message translates to:
  /// **'正在加载 faust.meph 模板...'**
  String get contractEditorLoadingTemplate;

  /// No description provided for @contractEditorContentHint.
  ///
  /// In zh, this message translates to:
  /// **'输入 .meph 契约内容...'**
  String get contractEditorContentHint;

  /// No description provided for @contractEditorNameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'╳ 请填写文件名'**
  String get contractEditorNameEmpty;

  /// No description provided for @contractEditorNameExists.
  ///
  /// In zh, this message translates to:
  /// **'╳ 文件名已存在: {fileName}'**
  String contractEditorNameExists(Object fileName);

  /// No description provided for @contractEditorFormatError.
  ///
  /// In zh, this message translates to:
  /// **'╳ 格式错误: {message}（{blockName}第 {line} 行）'**
  String contractEditorFormatError(
    Object blockName,
    Object line,
    Object message,
  );

  /// No description provided for @contractEditorParseFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 解析失败: {error}'**
  String contractEditorParseFail(Object error);

  /// No description provided for @contractEditorSaveFail.
  ///
  /// In zh, this message translates to:
  /// **'╳ 保存失败: {error}'**
  String contractEditorSaveFail(Object error);

  /// No description provided for @contractEditorUnparseable.
  ///
  /// In zh, this message translates to:
  /// **'无法解析的契约内容'**
  String get contractEditorUnparseable;

  /// No description provided for @contractEditorInfoLine1.
  ///
  /// In zh, this message translates to:
  /// **'• 契约以【区块名】组织：角色名 / 锚点 / 世界观 / 角色背景 / 开局场景 / 状态 / 规则 / 记忆 / 历史'**
  String get contractEditorInfoLine1;

  /// No description provided for @contractEditorInfoLine2.
  ///
  /// In zh, this message translates to:
  /// **'• 规则格式：[规则名] if 条件 -> 动作；任意【自定义区块】可作为草稿/备忘，不会报错'**
  String get contractEditorInfoLine2;

  /// No description provided for @contractEditorInfoLine3.
  ///
  /// In zh, this message translates to:
  /// **'• 保存时自动校验格式并定位错误'**
  String get contractEditorInfoLine3;

  /// No description provided for @contractEditorInfoLine4.
  ///
  /// In zh, this message translates to:
  /// **'• 需要更专业的编辑体验（行号、语法高亮、自动补全）等等可在 VSCode 安装 Mephisto 插件编辑 .meph 文件'**
  String get contractEditorInfoLine4;

  /// No description provided for @contractEditorErrorLine.
  ///
  /// In zh, this message translates to:
  /// **'第 {line} 行{blockName}：{message}'**
  String contractEditorErrorLine(Object blockName, Object line, Object message);

  /// No description provided for @contractEditorErrorBlock.
  ///
  /// In zh, this message translates to:
  /// **'，区块「{blockName}」'**
  String contractEditorErrorBlock(Object blockName);

  /// No description provided for @contractEditorConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'⚠ 文件已被外部修改'**
  String get contractEditorConflictTitle;

  /// No description provided for @contractEditorConflictContent.
  ///
  /// In zh, this message translates to:
  /// **'该文件在编辑期间被其他进程修改（如叙事自动存档或 VSCode 保存）。\n\n选择「覆盖」将用当前编辑内容替换磁盘版本；\n选择「重新加载」将丢弃当前编辑内容并拉取磁盘最新版本。'**
  String get contractEditorConflictContent;

  /// No description provided for @contractEditorConflictCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get contractEditorConflictCancel;

  /// No description provided for @contractEditorConflictReload.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get contractEditorConflictReload;

  /// No description provided for @contractEditorConflictOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get contractEditorConflictOverwrite;

  /// No description provided for @contractEditorReloaded.
  ///
  /// In zh, this message translates to:
  /// **'已重新加载磁盘最新版本'**
  String get contractEditorReloaded;

  /// No description provided for @textInputDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get textInputDialogConfirm;

  /// No description provided for @textInputDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get textInputDialogCancel;

  /// No description provided for @renameDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'✏️ 重命名契约'**
  String get renameDialogTitle;

  /// No description provided for @renameDialogLabel.
  ///
  /// In zh, this message translates to:
  /// **'新文件名'**
  String get renameDialogLabel;

  /// No description provided for @renameDialogHelper.
  ///
  /// In zh, this message translates to:
  /// **'需以 .meph 结尾'**
  String get renameDialogHelper;

  /// No description provided for @renameDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get renameDialogConfirm;

  /// No description provided for @renameDialogNameExists.
  ///
  /// In zh, this message translates to:
  /// **'该文件名已存在，请更换'**
  String get renameDialogNameExists;

  /// No description provided for @renameDialogBranchTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'命运说明'**
  String get renameDialogBranchTitleLabel;

  /// No description provided for @renameDialogBranchTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'描述这条支流将走向何方（可留空），首页将以此命名枝桠'**
  String get renameDialogBranchTitleHint;

  /// No description provided for @confirmDeleteCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get confirmDeleteCancel;

  /// No description provided for @confirmDeleteDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get confirmDeleteDelete;

  /// No description provided for @narrativeProviderGenFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成回复时发生异常，请重试'**
  String get narrativeProviderGenFailed;

  /// No description provided for @narrativeProviderAutoSaveFail.
  ///
  /// In zh, this message translates to:
  /// **'自动存档失败，进度未写入磁盘'**
  String get narrativeProviderAutoSaveFail;

  /// No description provided for @narrativeProviderSaveFail.
  ///
  /// In zh, this message translates to:
  /// **'存档失败，请检查契约目录权限或磁盘空间'**
  String get narrativeProviderSaveFail;

  /// No description provided for @narrativeProviderHotReloadFail.
  ///
  /// In zh, this message translates to:
  /// **'契约热重载失败，已保留原设定'**
  String get narrativeProviderHotReloadFail;

  /// No description provided for @contractFallbackNotice.
  ///
  /// In zh, this message translates to:
  /// **'当前契约文件缺失或损坏，已加载内置模板'**
  String get contractFallbackNotice;

  /// No description provided for @relativeTimeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get relativeTimeJustNow;

  /// No description provided for @relativeTimeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟前'**
  String relativeTimeMinutesAgo(Object minutes);

  /// No description provided for @relativeTimeHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时前'**
  String relativeTimeHoursAgo(Object hours);

  /// No description provided for @relativeTimeDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前'**
  String relativeTimeDaysAgo(Object days);

  /// No description provided for @languageLabel.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get languageLabel;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
