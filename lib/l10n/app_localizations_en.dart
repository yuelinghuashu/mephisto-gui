// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mephisto';

  @override
  String get homeTitle => '📜 Mephisto';

  @override
  String get homeNewContract => 'New Contract';

  @override
  String get homeImportContract => 'Import Contract';

  @override
  String get homeSettings => 'Settings';

  @override
  String homeSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get homeCancel => 'Cancel';

  @override
  String get homeDeleteSelected => 'Delete Selected';

  @override
  String get homeSelectAll => 'Select All';

  @override
  String get homeDeselectAll => 'Deselect All';

  @override
  String get homeDeleteContractTitle => 'Delete Contract';

  @override
  String homeDeleteSelectedConfirm(Object count) {
    return 'Delete the $count selected contract files? This cannot be undone.';
  }

  @override
  String homeDeleteMasterConfirm(Object fileName) {
    return 'Delete master $fileName and all its child versions? This cannot be undone.';
  }

  @override
  String get homeDeleteChildTitle => 'Delete Child Version';

  @override
  String homeDeleteChildConfirm(Object fileName) {
    return 'Delete child version file $fileName? This cannot be undone.';
  }

  @override
  String get homeDeleteFail => '╳ Delete failed';

  @override
  String homeDeleteSelectedFail(Object count) {
    return '╳ $count contracts failed to delete';
  }

  @override
  String homeImportSuccess(Object count) {
    return '✦ Imported $count contracts';
  }

  @override
  String homeImportFailAll(Object error) {
    return '╳ Import failed: $error';
  }

  @override
  String homeImportPartial(Object fail, Object success) {
    return '⚚ $success succeeded, $fail failed';
  }

  @override
  String get homeRenameFail =>
      '╳ Rename failed: target name already exists or old file is missing';

  @override
  String get homeContractSaved => '✦ Contract saved';

  @override
  String get homeNoBranches => 'This master has no child branches yet';

  @override
  String get emptyStateNoContract => 'The Void of Contracts';

  @override
  String get emptyStateDescription =>
      'No contracts found yet\nClick the import button at the top right to add a .meph file,\nor configure a contract directory on the settings page';

  @override
  String get emptyStateRestoring => 'Restoring...';

  @override
  String get emptyStateRestoreBuiltin => 'Restore Built-in Characters';

  @override
  String get emptyStateGoSettings => 'Go to Settings';

  @override
  String get emptyStateLoadFail => 'Failed to load contracts';

  @override
  String get homeBrandTitle => 'Mephisto Narrative Engine';

  @override
  String get homeBrandSubtitle =>
      'Choose a contract of fate, and the story unfolds from here';

  @override
  String get contractCardEnter => 'Enter';

  @override
  String get contractCardPreview => 'Preview';

  @override
  String get contractCardEdit => 'Edit';

  @override
  String get contractCardRename => 'Rename';

  @override
  String get contractCardDelete => 'Delete';

  @override
  String get contractCardOperations => 'Actions';

  @override
  String get contractCardExpandChildren => 'Expand child versions';

  @override
  String get contractCardCollapseChildren => 'Collapse child versions';

  @override
  String get narrativeSaveMenu => 'Save';

  @override
  String get narrativeSaveCurrent => 'Save Current Progress';

  @override
  String get narrativeSaveBranch => 'Save as Branch...';

  @override
  String get narrativeDeleteSave => 'Delete Save';

  @override
  String get narrativeScrollTop => 'Scroll to first message (Ctrl+Home)';

  @override
  String get narrativeScrollBottom => 'Scroll to last message (Ctrl+End)';

  @override
  String get narrativeEditContract =>
      'Edit Current Contract (rules hot-reload on save)';

  @override
  String get narrativeDashboard => 'Dashboard';

  @override
  String get narrativeClose => 'Close';

  @override
  String get narrativeSettings => 'Settings';

  @override
  String narrativeSaveSuccess(Object fileName) {
    return '✦ Contract engraved: $fileName';
  }

  @override
  String get narrativeSaveFail =>
      '╳ Save failed: check contract directory permissions or disk space';

  @override
  String narrativeBranchSaved(Object fileName) {
    return '✦ Branch contract engraved: $fileName';
  }

  @override
  String get narrativeBranchFail =>
      '╳ Branch save failed: check contract directory permissions or disk space';

  @override
  String get narrativeDeleteSaveSuccess => '⚰ Save deleted';

  @override
  String get narrativeDeleteSaveNone => '╳ No save to delete';

  @override
  String get narrativeHotReloadNotice =>
      '✦ Rules hot-updated and now in effect (non-rule sections such as character name require a new narrative to take effect)';

  @override
  String get narrativeFileWatchUnavailable =>
      '⚠ File watching unavailable; rule hot-reload is disabled (narrative unaffected)';

  @override
  String get narrativeRestoreFailed =>
      '╳ Save restore failed: the save file may exist but is corrupted; starting a new narrative from the master contract';

  @override
  String narrativeErrorPrefix(Object error) {
    return '╳ $error. Mephisto responds with mortal strength';
  }

  @override
  String get narrativeBranchDialogTitle => '✏️ Save as Branch';

  @override
  String get narrativeBranchLabel => 'Branch name';

  @override
  String get narrativeBranchHint => 'e.g. dark, light, judgment';

  @override
  String get narrativeBranchTitleLabel => 'Fate description';

  @override
  String get narrativeBranchTitleHint =>
      'Describe where this branch will lead (optional). Shown as the branch name on the home page';

  @override
  String get narrativeStopGenerating => 'Stop Generating';

  @override
  String get narrativeConfirm => 'Save';

  @override
  String get narrativeEmptyHint =>
      'Write the guidance of fate, and the narrative will grow within the contract...';

  @override
  String get messageBubbleThinking => 'Mephisto is writing...';

  @override
  String get inputBarAttachTooltip => 'Attach context (text, multi-select)';

  @override
  String get inputBarHintGenerating => 'Mephisto is weaving a story...';

  @override
  String get inputBarHintIdle =>
      'Write the guidance of fate, the contract will drive the narrative...';

  @override
  String get inputBarSendTooltip => 'Send';

  @override
  String inputBarInvalidAttachment(Object fileName) {
    return '╳ $fileName is not valid text, skipped';
  }

  @override
  String get statusBarRuleChip => 'Rules';

  @override
  String get statusBarMemoryChip => 'Memory';

  @override
  String get statusBarHistoryChip => 'History';

  @override
  String diceVerdictTitle(Object count) {
    return 'Fate Verdict · $count roll(s)';
  }

  @override
  String diceVerdictThreshold(Object threshold) {
    return 'Threshold ≥ $threshold';
  }

  @override
  String diceVerdictTriggered(Object action) {
    return 'Triggered: $action';
  }

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get previewSheetClose => 'Close';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeDescription => 'Light/dark theme mode.';

  @override
  String get settingsThemeSystem => 'Follow System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageDescription => 'Simplified Chinese / English.';

  @override
  String get settingsNarrativeWidth => 'Narrative Content Width';

  @override
  String get settingsWidthDescription =>
      'The maximum width of the narrative message flow. Mobile fills the screen automatically; this mainly affects desktop.';

  @override
  String get settingsWidthNarrow => 'Narrow';

  @override
  String get settingsWidthMedium => 'Medium';

  @override
  String get settingsWidthWide => 'Wide';

  @override
  String get settingsWidthFull => 'Full Screen';

  @override
  String get settingsHistoryWindow => 'History Message Window';

  @override
  String get settingsHistoryWindowDescription =>
      'Upper limit of historical dialogue messages sent to the LLM. A smaller window reduces token consumption; a larger window gives the model more complete memory of earlier context.';

  @override
  String get settingsHistoryWindowNarrow => '20 messages';

  @override
  String get settingsHistoryWindowMedium => '40 messages';

  @override
  String get settingsHistoryWindowWide => '60 messages';

  @override
  String get settingsHistoryWindowFull => 'Send all';

  @override
  String get settingsMemoryLimit => 'Memory Injection Limit';

  @override
  String get settingsMemoryLimitDescription =>
      'Upper limit of memory items sent to the LLM per turn. A smaller window reduces token consumption; when the limit is exceeded, high-importance memories (≥4 stars) are all kept, and the rest fill in by descending weight.';

  @override
  String get settingsMemoryLimitCompact => '10 items';

  @override
  String get settingsMemoryLimitStandard => '20 items';

  @override
  String get settingsMemoryLimitExtended => '30 items';

  @override
  String get settingsMemoryLimitFull => 'Inject all';

  @override
  String get settingsNarrativeRules => 'Narrative Rules';

  @override
  String get settingsRulesDescription =>
      'Customize the narrative style, fully replacing the default constraints. The more precise the style description, the closer the output matches expectations (explicitly state the style/poetic form/dialogue approach).';

  @override
  String get settingsRulesHint => 'Enter narrative rules...';

  @override
  String get settingsResetRules => 'Reset to Default';

  @override
  String get settingsSaveRules => 'Save Rules';

  @override
  String get settingsRulesSaved => '✦ Narrative rules saved';

  @override
  String get settingsRulesReset => '⇄ Restored default narrative rules';

  @override
  String get settingsContractsDir => 'Contract Directory';

  @override
  String get settingsAndroidDirDescription =>
      'Contracts are stored in the app\'s private space, unaffected by Android storage permissions. “Internal storage” uses the app-specific partition; “external storage” uses the device mass storage partition—both are within the app\'s private directory and are cleared on uninstall. Android restricts apps from directly reading/writing user public directories (Downloads, Documents, SD card), so contracts cannot be freely assigned to folders like on desktop. To use contracts from elsewhere on your phone, use the import feature on the home page.';

  @override
  String get settingsIosDirDescription =>
      'Contracts are stored in the app\'s internal directory (iOS sandbox restriction). Import and default loading both use this directory.';

  @override
  String get settingsDesktopDirDescription =>
      'The folder containing .meph contract files. Import and default loading both use this directory.';

  @override
  String get settingsDirLoading => 'Loading...';

  @override
  String get settingsAndroidExternalLocation =>
      'Location: app external storage (Android/data app-private directory)';

  @override
  String get settingsAndroidInternalLocation =>
      'Location: app internal storage (app-private directory)';

  @override
  String get settingsIosLocation =>
      'Location: app internal directory (iOS sandbox)';

  @override
  String get settingsAndroidExternalStorage => 'Storage: app external space';

  @override
  String get settingsAndroidInternalStorage => 'Storage: app internal space';

  @override
  String get settingsSwitchToInternal => 'Switch to Internal Storage';

  @override
  String get settingsSwitchToExternal => 'Switch to External Storage';

  @override
  String get settingsChangeDir => 'Change Directory';

  @override
  String get settingsOpenFolder => 'Open Folder';

  @override
  String settingsDirChanged(Object path) {
    return '✦ Contract directory updated: $path';
  }

  @override
  String get settingsDirChangeFail => '╳ Failed to set contract directory';

  @override
  String get settingsIosSandboxNotice =>
      '╳ iOS sandbox restriction: contracts are only stored in the app\'s internal directory and cannot be relocated';

  @override
  String get settingsStorageSwitchFail => '╳ Failed to switch storage location';

  @override
  String get settingsStorageExternalSwitched =>
      '✦ Contract location: app external storage (cleared on uninstall)';

  @override
  String get settingsStorageInternalSwitched =>
      '✦ Contract location: app internal storage';

  @override
  String get settingsDirNotExist => '╳ Directory does not exist';

  @override
  String settingsOpenFolderFail(Object error) {
    return '╳ Failed to open folder: $error';
  }

  @override
  String get settingsPlatformNotSupported =>
      'Opening folders is not supported on this platform';

  @override
  String get settingsLlmConfig => 'LLM Configuration';

  @override
  String get settingsLlmDescription =>
      'AI service parameters used for narrative generation. Saving with empty fields uses default configuration.';

  @override
  String get settingsBackendOpenai => 'OpenAI Compatible';

  @override
  String get settingsBackendOllama => 'Local Ollama';

  @override
  String get settingsApiKeyLabel => 'API Key';

  @override
  String get settingsApiKeyHint => 'sk-... (can be empty for Ollama)';

  @override
  String get settingsApiKeyPaste => 'Paste from Clipboard';

  @override
  String get settingsApiKeyPasteSuccess => '✦ API Key imported from clipboard';

  @override
  String get settingsApiKeyPasteEmpty =>
      '╳ Nothing importable found in clipboard';

  @override
  String get settingsBaseUrlLabel => 'Base URL';

  @override
  String get settingsBaseUrlHint => 'https://api.deepseek.com/v1';

  @override
  String get settingsModelLabel => 'Model';

  @override
  String get settingsModelHint => 'deepseek-v4-flash / qwen2.5:7b';

  @override
  String get settingsMaxTokensLabel => 'Max Tokens';

  @override
  String get settingsTimeoutLabel => 'Timeout (seconds)';

  @override
  String get settingsTimeoutHint => '60';

  @override
  String get settingsRetriesLabel => 'Max Retries';

  @override
  String get settingsRetriesHint => '1';

  @override
  String get settingsMaxTokensHint => '4096';

  @override
  String get settingsTestConnection => 'Test Connection';

  @override
  String get settingsTesting => 'Testing...';

  @override
  String get settingsSaveConfig => 'Save Configuration';

  @override
  String get settingsResetConfig => 'Reset to Default';

  @override
  String get settingsConfigSaved => '✦ LLM configuration saved';

  @override
  String get settingsConfigSaveFail => '╳ Base URL and Model cannot be empty';

  @override
  String get settingsConfigReset => '⇄ Restored default configuration';

  @override
  String get settingsTestNeedBaseUrlModel =>
      '╳ Please fill in Base URL and Model first';

  @override
  String get settingsTestSuccess =>
      '✦ Connection successful, model is available';

  @override
  String settingsTestFail(Object error) {
    return '╳ Connection failed: $error';
  }

  @override
  String get contractEditorNewTitle => '✏️ New Contract';

  @override
  String get contractEditorEditTitle => '✏️ Edit Contract';

  @override
  String get contractEditorFormatTooltip =>
      'Format text (adjust indentation, blank lines, and fix operator spacing)';

  @override
  String get contractEditorSave => 'Save';

  @override
  String get contractEditorCancel => 'Cancel';

  @override
  String get contractEditorFileName => 'File name (auto-appends .meph)';

  @override
  String get contractEditorFileNameHint => 'e.g. my_story';

  @override
  String get contractEditorLoadingTemplate => 'Loading faust.meph template...';

  @override
  String get contractEditorContentHint => 'Enter .meph contract content...';

  @override
  String get contractEditorNameEmpty => '╳ Please enter a file name';

  @override
  String contractEditorNameExists(Object fileName) {
    return '╳ File name already exists: $fileName';
  }

  @override
  String contractEditorFormatError(
    Object blockName,
    Object line,
    Object message,
  ) {
    return '╳ Format error: $message (${blockName}line $line)';
  }

  @override
  String contractEditorParseFail(Object error) {
    return '╳ Parse failed: $error';
  }

  @override
  String contractEditorSaveFail(Object error) {
    return '╳ Save failed: $error';
  }

  @override
  String get contractEditorUnparseable => 'Unparseable contract content';

  @override
  String get contractEditorInfoLine1 =>
      '• Contracts are organized by 【section name】: role name / anchors / worldview / background / opening scene / state / rules / memory / history';

  @override
  String get contractEditorInfoLine2 =>
      '• Rule format: [rule name] if condition -> action; any 【custom section】 can be used as draft/notes without errors';

  @override
  String get contractEditorInfoLine3 =>
      '• Format is auto-validated on save with error location';

  @override
  String get contractEditorInfoLine4 =>
      '• For a more professional editing experience (line numbers, syntax highlighting, auto-completion), install the Mephisto plugin in VSCode to edit .meph files';

  @override
  String contractEditorErrorLine(
    Object blockName,
    Object line,
    Object message,
  ) {
    return 'Line $line$blockName: $message';
  }

  @override
  String contractEditorErrorBlock(Object blockName) {
    return ', section「$blockName」';
  }

  @override
  String get contractEditorConflictTitle => '⚠ File changed externally';

  @override
  String get contractEditorConflictContent =>
      'This file was modified by another process while editing (e.g. narrative auto-save or VSCode save).\n\n\"Overwrite\" replaces the on-disk version with your current edit;\n\"Reload\" discards your edit and pulls the latest on-disk version.';

  @override
  String get contractEditorConflictCancel => 'Cancel';

  @override
  String get contractEditorConflictReload => 'Reload';

  @override
  String get contractEditorConflictOverwrite => 'Overwrite';

  @override
  String get contractEditorReloaded => 'Reloaded the latest on-disk version';

  @override
  String get textInputDialogConfirm => 'OK';

  @override
  String get textInputDialogCancel => 'Cancel';

  @override
  String get renameDialogTitle => '✏️ Rename Contract';

  @override
  String get renameDialogLabel => 'New file name';

  @override
  String get renameDialogHelper => 'Must end with .meph';

  @override
  String get renameDialogConfirm => 'Rename';

  @override
  String get renameDialogNameExists =>
      'This file name already exists, please choose another';

  @override
  String get renameDialogBranchTitleLabel => 'Fate description';

  @override
  String get renameDialogBranchTitleHint =>
      'Describe where this branch leads (optional)';

  @override
  String get confirmDeleteCancel => 'Cancel';

  @override
  String get confirmDeleteDelete => 'Delete';

  @override
  String get narrativeProviderGenFailed =>
      'An error occurred while generating the reply, please retry';

  @override
  String get narrativeProviderAutoSaveFail =>
      'Auto-save failed, progress was not written to disk';

  @override
  String get narrativeProviderSaveFail =>
      'Save failed: check contract directory permissions or disk space';

  @override
  String get narrativeProviderHotReloadFail =>
      'Contract hot-reload failed, original settings preserved';

  @override
  String get contractFallbackNotice =>
      'The current contract file is missing or corrupted; built-in template loaded';

  @override
  String get relativeTimeJustNow => 'Just now';

  @override
  String relativeTimeMinutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String relativeTimeHoursAgo(Object hours) {
    return '$hours hr ago';
  }

  @override
  String relativeTimeDaysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String get languageLabel => 'Language';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';
}
