import 'package:mephisto/l10n/app_localizations.dart';

import '../domain/narrative_error.dart';

/// 将 Provider 层错误码映射为本地化文本。
///
/// 仅处理 [isNarrativeErrorCode] 返回 true 的静态错误码；
/// 自由格式错误文本（如 LLM 异常信息）直接原样返回。
String localizeNarrativeError(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    narrativeErrorGenFailed => l10n.narrativeProviderGenFailed,
    narrativeErrorAutoSaveFail => l10n.narrativeProviderAutoSaveFail,
    narrativeErrorSaveFail => l10n.narrativeProviderSaveFail,
    narrativeErrorHotReloadFail => l10n.narrativeProviderHotReloadFail,
    narrativeErrorContractFallback => l10n.contractFallbackNotice,
    _ => errorCode,
  };
}
