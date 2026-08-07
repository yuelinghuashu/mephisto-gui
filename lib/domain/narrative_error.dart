/// 叙事 Provider 层错误码
///
/// 纯逻辑层（Notifier）无法访问 BuildContext / AppLocalizations，
/// 因此错误消息以「错误码」形式暴露，由 UI 层负责本地化翻译。
///
/// 取值约定：
///   - `provider.*` 前缀为 Provider 层产生的静态错误码（对应 ARB 中的
///     `narrativeProvider*` 密钥，UI 层映射为本地化文本）
///   - 非 `provider.` 前缀的字符串视为自由格式错误文本（如 LLM 异常信息），
///     UI 层直接展示原文
library;

/// 生成回复失败的静态错误码。
const String narrativeErrorGenFailed = 'provider.generation_failed';

/// 自动存档失败的静态错误码。
const String narrativeErrorAutoSaveFail = 'provider.auto_save_failed';

/// 默认保存失败的静态错误码。
const String narrativeErrorSaveFail = 'provider.save_failed';

/// 契约热重载失败的静态错误码。
const String narrativeErrorHotReloadFail = 'provider.hot_reload_failed';

/// 契约兜底提示的静态错误码。
const String narrativeErrorContractFallback = 'provider.contract_fallback';

/// 判断错误文本是否为 Provider 层错误码。
///
/// 返回 true 表示 [text] 是静态错误码，UI 层应映射为本地化文本；
/// 返回 false 表示是自由格式错误文本（如 LLM 异常信息），直接展示。
bool isNarrativeErrorCode(String text) => text.startsWith('provider.');