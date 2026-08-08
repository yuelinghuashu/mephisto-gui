/// 契约目录管理：管理用户可访问的 .meph 契约文件夹
///
/// 所有契约文件统一存放在应用文档目录的 `contracts/` 子目录中。
/// 首次启动时从 assets 复制内置模板作为初始契约，之后用户可以自由增删改。
///
/// 契约文件的 CRUD 与文件名校验见 [contract_repo.dart]。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 内置模板资产前缀
const String _assetPrefix = 'assets/contracts/';

/// 内置模板列表（首次启动时复制到用户目录）
///
/// 除母版契约外，还预置「官方示范子版」（命运支流枝叶）：
///   - `dantes.bonapart.meph`：基督山伯爵 × 波拿巴党卧底 if 线
///   - `faust.utopia.meph`：浮士德 × 理想国 / 乌托邦 if 线
/// 首页分组逻辑会自动将它们显示为对应母版下的子版，直观呈现「树根 + 枝叶」。
const List<String> _builtinContracts = [
  'faust.meph',
  'dantes.meph',
  'dantes.bonapart.meph',
  'faust.utopia.meph',
];

/// 首次种子标记前缀（SharedPreferences key 前缀）
///
/// 标记内置模板是否已经复制到用户目录。
/// 只在首次安装/首次启动时执行一次，之后不再自动恢复被删除的模板。
///
/// **按目录绑定**：为避免用户切换契约目录（自定义路径/外部存储）后新目录为空，
/// 种子标记必须绑定目录路径（`<前缀><目录绝对路径>`），
/// 而不是全局单一标记——否则全局标记为 true 后新目录永远不会获得内置模板。
const String _seededPrefix = 'mephisto_contracts_seeded_';

/// 构建指定目录的种子标记 key。
///
/// 目录路径中包含分隔符（`/`、`\`），在 SharedPreferences key 中合法，
/// 直接拼接即可（JSON 键无字符限制）。
String _seededKeyFor(Directory dir) => '$_seededPrefix${dir.path}';

/// 用户自定义契约目录（SharedPreferences key）
///
/// 值含义（按平台）：
///   - 桌面端：任意目录路径（如 `~/Mephisto/contracts`）
///   - Android：外部存储标记 [mobileExternalMarker] 表示应用外部存储
///   - iOS：未配置（系统沙盒限制，仅应用内目录）
const String _contractsDirKey = 'mephisto_contracts_directory';

/// 移动端外部存储标记（SharedPreferences `_contractsDirKey` 的可选值）。
///
/// 仅 Android 使用：外部存储位于应用专属外部目录（`Android/data/<pkg>/files`），
/// dart:io 可直接读写（真实文件路径），卸载应用时清除。
/// 内部沙盒（默认）使用 [getApplicationDocumentsDirectory]，同样随卸载清除。
const String mobileExternalMarker = 'mobile_external';

/// 获取契约目录路径（用户自定义优先）。目录不存在时自动创建。
Future<Directory> getContractsDirectory() async {
  final prefs = await SharedPreferences.getInstance();

  // 用户自定义存储位置
  final custom = prefs.getString(_contractsDirKey);
  if (custom != null && custom.isNotEmpty) {
    // Android：外部存储标记 → 应用外部目录（真实路径，dart:io 直接可用）
    if (custom == mobileExternalMarker && Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/Mephisto/contracts');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir;
      }
      // 获取外部目录失败（罕见）→ 清空标记，回落沙盒默认
      await prefs.remove(_contractsDirKey);
    } else if (custom == mobileExternalMarker) {
      // 其他平台出现该标记（理论不发生的脏数据）→ 回落默认
      await prefs.remove(_contractsDirKey);
    } else {
      // 桌面端任意路径
      final customDir = Directory(custom);
      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }
      return customDir;
    }
  }

  // 默认位置
  final dir = await _defaultContractsDirectory();
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir;
}

/// 当前是否使用移动端外部存储（仅 Android 返回可能为 true；其余平台恒 false）。
///
/// Android 用户可在「内部沙盒 ↔ 应用外部存储」间切换契约存储位置。
Future<bool> isUsingMobileExternalStorage() async {
  if (!Platform.isAndroid) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_contractsDirKey) == mobileExternalMarker;
}

/// 设置移动端外部存储开关（仅 Android 生效；其余平台返回 false）。
///
/// 参数：
///   - enabled: true 切换为应用外部存储；false 切回内部沙盒（删除标记走默认）
///
/// 返回值：是否设置成功。
Future<bool> setMobileExternalStorage(bool enabled) async {
  if (!Platform.isAndroid) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      return await prefs.setString(_contractsDirKey, mobileExternalMarker);
    }
    return await prefs.remove(_contractsDirKey);
  } catch (_) {
    return false;
  }
}

/// 默认契约目录（平台自适应）。
///
/// - 桌面端（Linux/macOS/Windows）：`~/Mephisto/contracts`，
///   基于环境变量动态解析（Linux/macOS 用 `HOME`，Windows 用 `USERPROFILE`）。
///   优先使用环境变量而非 `path_provider`，保证桌面端路径与旧版本一致
///   （用户已存在的契约文件不受升级影响）。
/// - 移动端（Android/iOS）：应用文档目录下的 `Mephisto/contracts`，
///   使用 [getApplicationDocumentsDirectory]（异步 API），
///   存储在应用沙盒内，无需额外存储权限。
Future<Directory> _defaultContractsDirectory() async {
  // 移动端：path_provider 的应用文档目录（sandbox 内）
  if (Platform.isAndroid || Platform.isIOS) {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/Mephisto/contracts');
  }

  // 桌面端：环境变量主目录（与旧版本路径一致）
  return Directory('${_homeDirectory().path}/Mephisto/contracts');
}

/// 获取用户主目录（桌面端专用）。
///
/// - Linux/macOS：`$HOME` 环境变量
/// - Windows：`%USERPROFILE%` 环境变量
/// - 无法获取时抛出 [StateError]（由调用方处理）
///
/// 仅在桌面端调用；移动端走 [getApplicationDocumentsDirectory]（见上方）。
Directory _homeDirectory() {
  // Linux / macOS
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return Directory(home);
  }

  // Windows
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.isNotEmpty) {
    return Directory(userProfile);
  }

  throw StateError('无法确定用户主目录（缺少 HOME / USERPROFILE 环境变量）');
}

/// 设置自定义契约目录路径。
///
/// 参数：
///   - path: 用户选择的目录路径
///
/// 返回值：是否设置成功（目录创建失败时返回 false）。
Future<bool> setContractsDirectory(String path) async {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_contractsDirKey, path);
  } catch (_) {
    return false;
  }
}

/// 确保契约目录存在且包含内置模板。
///
/// 按**当前契约目录**执行种子逻辑（种子标记绑定目录路径）：
///   - 目录尚未种子：创建 `contracts/` 目录，将 assets 中的内置模板复制进去，
///     然后写入该目录的种子标记。
///   - 目录已种子：只确保目录存在，**不再自动恢复**被用户删除的内置模板。
///     用户对契约文件夹拥有完全控制权——删除即删除。
///
/// 参数：
///   - [force]：为 true 时无视种子标记，强制复制缺失的内置模板（不覆盖已有文件）。
///     用于用户手动「恢复内置角色」的场景（如空状态兜底）。
Future<void> ensureContracts({bool force = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final dir = await getContractsDirectory();

  // 当前目录已种过种子且非强制 → 不自动恢复模板（尊重用户删除）
  final seededKey = _seededKeyFor(dir);
  if (!force && (prefs.getBool(seededKey) ?? false)) {
    return;
  }

  // 种子/强制恢复：复制内置模板（仅当文件不存在时，不覆盖用户已有文件）
  for (final name in _builtinContracts) {
    final file = File('${dir.path}/$name');
    if (file.existsSync()) continue;

    try {
      final content = await rootBundle.loadString('$_assetPrefix$name');
      await file.writeAsString(content);
    } catch (e) {
      // 内置模板加载失败不影响主流程
      debugPrint('复制内置契约失败: $name ($e)');
    }
  }

  // 标记当前目录已种过种子
  await prefs.setBool(seededKey, true);
}

/// 列出目录下所有 `.meph` 文件的文件名（字典序排序）。
///
/// 统一了 [contract_repo.dart]（listContracts / deleteContractCascade）与
/// [child_save_store.dart]（listChildFiles）中重复的「扫目录 → 过滤 .meph →
/// 取文件名 → 排序」样板，消除各处 `listSync + whereType<File> + split` 重复。
///
/// 异步实现（`dir.list()`）避免 UI 线程上同步 IO 阻塞。
Future<List<String>> listMephFileNames(Directory dir) async {
  final names = <String>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.endsWith('.meph')) names.add(name);
  }
  names.sort();
  return names;
}
