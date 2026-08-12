/// 存储键统一常量
///
/// 集中管理所有 SharedPreferences / SecureStorage 的键名，
/// 避免散落在各服务文件中难以追踪。
library;

// ============================================================
// SharedPreferences 键
// ============================================================

/// 契约目录设置键（`contract_dir.dart`）
const String contractsDirKey = 'mephisto_contracts_directory';

/// 移动端外部存储标记（仅 Android 使用）
const String mobileExternalMarker = 'mobile_external';

/// 契约种子标记前缀（`contract_dir.dart`）
///
/// 完整 key = 前缀 + 目录绝对路径（如 `mephisto_contracts_seeded_/home/...`）
const String contractsSeededPrefix = 'mephisto_contracts_seeded_';

/// 当前契约文件名键（`contract_provider.dart`）
const String currentContractKey = 'mephisto_current_contract';

/// 主题模式键（`settings_provider.dart`）
const String themeModeKey = 'mephisto_theme_mode';

/// 界面语言键（`settings_provider.dart`）
const String languageKey = 'mephisto_language';

/// 首页舞台区折叠状态键（`home_section_visibility_provider.dart`）
const String homeStageSectionCollapsedKey = 'mephisto_home_stage_collapsed';

/// 首页契约区折叠状态键（`home_section_visibility_provider.dart`）
const String homeContractSectionCollapsedKey =
    'mephisto_home_contract_collapsed';

// ============================================================
// 安全存储（SecureStorage）键
// ============================================================

/// LLM API Key 存储键（`llm_settings_provider.dart`）
const String llmApiKeyKey = 'llm_api_key';

// ============================================================
// LLM 配置键（`llm_settings_provider.dart`）
// ============================================================

const String llmBaseUrlKey = 'llm_base_url';
const String llmModelKey = 'llm_model';
const String llmMaxTokensKey = 'llm_max_tokens';
const String llmBackendKey = 'llm_backend';
const String llmTimeoutSecondsKey = 'llm_timeout_seconds';
const String llmMaxRetriesKey = 'llm_max_retries';

// ============================================================
// 辅助任务模型配置键（`llm_settings_provider.dart`）
// ============================================================

const String llmAuxEnabledKey = 'llm_aux_enabled';
const String llmAuxModelKey = 'llm_aux_model';
const String llmAuxBaseUrlKey = 'llm_aux_base_url';
const String llmAuxMaxTokensKey = 'llm_aux_max_tokens';
const String llmAuxTimeoutSecondsKey = 'llm_aux_timeout_seconds';
const String llmAuxApiKeyKey = 'llm_aux_api_key';
