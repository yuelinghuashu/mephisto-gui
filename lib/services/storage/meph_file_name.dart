/// .meph 文件名解析共享工具
///
/// 集中处理 .meph 文件名（多级命运树命名规则）的解析与校验。
///
/// 多级树模型：文件名中的 `.` 分段即层级。
///   - `faust.meph`               → [faust]（母版根）
///   - `faust.dark.meph`          → [faust, dark]（一级分支）
///   - `faust.dark.light.meph`    → [faust, dark, light]（二级分支）
///   - `faust.child.meph`         → [faust, child]（默认存档）
///
/// 各调用方（contract_repo / child_save_store / session_saver / narrative_state /
/// contract_provider / narrative_provider / stage_narrative_provider）此前存在
/// 分散的 `replaceAll + split + indexOf` 字符串样板，统一收敛至此消除重复。
library;

/// 默认子版后缀（母版名 + `.child`）。
///
/// 被 [defaultChildFileName] / [stripChildSuffix] 与 [ChildSaveStore]
/// 共同引用，是存档命名规则的核心常量。
const String defaultChildSuffix = '.child';

/// 解析文件名为「基础名（去 `.meph` 后缀）的路径段列表」。
List<String> splitBaseName(String fileName) {
  return fileName.replaceAll('.meph', '').split('.');
}

/// 判断文件名是否为子版文件（母版根 后还有路径段）。
bool isChildFileName(String fileName) => splitBaseName(fileName).length >= 2;

/// 提取母版基础名。
String extractMasterPrefix(String fileName) => splitBaseName(fileName).first;

/// 提取子版分支名（取路径最后一段）。
String? extractBranchName(String fileName) {
  final segments = splitBaseName(fileName);
  return segments.length >= 2 ? segments.last : null;
}

/// 提取子版「分支路径」（去掉最后一段分支名后的完整前缀）。
String? extractBranchPath(String fileName) {
  final segments = splitBaseName(fileName);
  if (segments.length < 2) return null;
  return segments.take(segments.length - 1).join('.');
}

/// 计算「当前分支路径」：去掉 `.child` 存档尾段后，提取层级前缀。
///
/// - `faust.meph`            → `faust`
/// - `faust.dark.meph`       → `faust.dark`
/// - `faust.dark.child.meph` → `faust.dark`（.child 是存档后缀，非分支）
/// - `faust.dark.light.meph` → `faust.dark.light`
String stripChildSuffix(String fileName) {
  final base = fileName.replaceAll('.meph', '');
  final trimmed = base.endsWith(defaultChildSuffix)
      ? base.substring(0, base.length - defaultChildSuffix.length)
      : base;
  return trimmed;
}

/// 构造默认子版文件名（`faust.meph` → `faust.child.meph`；
/// `faust.dark.meph` → `faust.dark.child.meph`）。
///
/// 与 [SessionSaver.saveCurrent] 的存档命名规则保持一致：
/// 默认存档属于「当前分支路径 + `.child`」，而非仅母版根。
/// 被 [NarrativeNotifier] / [StageNarrativeNotifier] 共享调用，
/// 统一此前两个 Notifier 间不一致的实现（旧单角色版仅取母版根，
/// 导致多级分支下无法正确定位/恢复存档）。
String defaultChildFileName(String masterFileName) =>
    '${stripChildSuffix(masterFileName)}$defaultChildSuffix.meph';

/// 计算文件名对应的层级深度（母版根为 0，一级子版为 1，二级为 2 …）。
int fileNameDepth(String fileName) => splitBaseName(fileName).length - 1;
