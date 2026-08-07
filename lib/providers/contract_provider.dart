import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/narrative_error.dart';
import '../services/parser/meph_parser.dart';
import '../services/storage/contract_dir.dart';
import '../services/storage/contract_repo.dart';

/// 当前使用的契约文件名（存储在 shared_preferences）
const String contractPrefKey = 'mephisto_current_contract';

/// 默认契约名（用户目录中不存在任何契约时使用）
const String defaultContractName = 'faust.meph';

/// 契约兜底提示控制器。
///
/// 当 [contractProvider] 因用户契约文件缺失/损坏而回退到 assets 内置模板时，
/// 置为提示消息（UI 顶部提示条展示，避免用户误以为契约内容正确）；
/// 正常加载时为 null（不显示）。
class ContractFallbackNoticeController extends Notifier<String?> {
  @override
  String? build() => null;

  /// 更新兜底提示（null 表示无提示）。
  void setNotice(String? message) => state = message;
}

/// 契约兜底提示 Provider。
final contractFallbackNoticeProvider =
    NotifierProvider<ContractFallbackNoticeController, String?>(
  ContractFallbackNoticeController.new,
);

/// 当前使用的契约文件名 Provider（如 `faust.meph`）
///
/// 用于子版存档命名（`faust.meph` → `faust.child.meph`）。
final currentContractNameProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(contractPrefKey) ?? defaultContractName;
});

/// 契约 Provider：从用户 `contracts/` 目录加载 .meph 文件并解析为 [Contract]。
///
/// 加载流程：
///   1. 确保用户契约目录存在（首次启动时从 assets 复制内置模板）
///   2. 从 [SharedPreferences] 读取上次使用的契约名
///   3. 读取并解析该契约文件
///   4. 用户文件缺失或解析失败（如用户手动编辑引入语法错误）时，
///      回退到 assets 同名内置模板作为最后防线（[_builtinFallback]），
///      避免叙事页静默崩溃为 [Contract.empty]（「角色」空壳、无开局场景）。
///
/// 仅当用户文件与内置模板均不可用时才进入 [AsyncError]。
final contractProvider = FutureProvider<Contract>((ref) async {
  // 1. 确保契约目录存在
  await ensureContracts();

  // 2. 读取当前契约名（默认为 faust.meph）
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString(contractPrefKey) ?? defaultContractName;

  // 3. 从用户目录读取并解析（解析失败 → 尝试内置模板兜底）
  final source = await readContract(name);
  if (source != null) {
    try {
      final contract = parseMeph(source);
      // 正常加载：清除兜底提示
      ref.read(contractFallbackNoticeProvider.notifier).setNotice(null);
      return contract;
    } catch (_) {
      // 用户文件存在但解析失败（语法错误）→ 落到内置模板兜底
    }
  }

  // 4. 回退到 assets 内置模板；仍不可用时抛异常
  final fallback = await _builtinFallback(name);
  if (fallback != null) {
    // 已回退内置模板：置错误码提示，UI 顶部展示并翻译，
    // 避免用户误以为契约内容正确
    ref.read(contractFallbackNoticeProvider.notifier)
        .setNotice(narrativeErrorContractFallback);
    return fallback;
  }
  throw Exception('契约文件不存在: $name');
});

/// 从 assets 加载同名内置模板作为兜底契约。
///
/// 仅当用户目录文件缺失/损坏时使用，保证顶级内置契约（faust / dantes）
/// 始终可进入叙事，避免回退为 [Contract.empty]（「角色」空壳、无开局场景）。
///
/// 仅在 [name] 恰好是内置模板名时兜底成功；用户自定义契约（非内置名）
/// 缺失时返回 null 交给调用方抛「契约文件不存在」——避免将用户的自定义
/// 契约引用静默替换成内置的浮士德契约（误导）。
Future<Contract?> _builtinFallback(String name) async {
  String? content;
  try {
    content = await rootBundle.loadString('assets/contracts/$name');
  } catch (_) {
    // 无同名内置模板
  }
  if (content == null) return null;
  try {
    return parseMeph(content);
  } catch (_) {
    return null;
  }
}

/// 契约信息（文件名 + 角色名 + 是否子版）
class ContractInfo {
  /// 契约文件名（如 `faust.meph` 或 `faust.child.meph`）
  final String fileName;

  /// 契约角色名（从【角色名】区块解析；失败时回退为文件名去扩展名）
  final String roleName;

  /// 是否为子版文件（如 `faust.child.meph`、`faust.dark.meph`）
  ///
  /// 子版 = 母版 + 运行时对话/状态/记忆/历史，是存档快照。
  final bool isChild;

  /// 子版的分支名（仅子版有；如 `child`、`dark`、`light`）
  final String? branchName;

  /// 子版「命运一句话」（用户另存为分支时填写，取自子版【角色背景】的 `@命运:` 标记）
  ///
  /// 用于首页展示更可读的支流描述；未填写时为 null，首页回落为显示 [branchName]。
  final String? branchTitle;

  const ContractInfo({
    required this.fileName,
    required this.roleName,
    this.isChild = false,
    this.branchName,
    this.branchTitle,
  });
}

/// 契约分组：一个母版 + 其下所有子版
///
/// 用于首页层级展示：
///   - [master]: 母版文件（如 `faust.meph`）
///   - [children]: 子版列表（如 `[faust.child.meph, faust.dark.meph]`）
class ContractGroup {
  /// 母版契约
  final ContractInfo master;

  /// 该母版下的子版列表
  final List<ContractInfo> children;

  const ContractGroup({required this.master, required this.children});

  /// 子版数量
  int get childCount => children.length;

  /// 是否有子版
  bool get hasChildren => children.isNotEmpty;
}

/// 契约分组列表 Provider：按母版分组展示
///
/// 返回 [[ContractGroup]]，每个组包含一个母版及其所有子版。
/// 例如：
///   - faust.meph → { master: faust.meph, children: [faust.child.meph, faust.dark.meph] }
///   - dantes.meph → { master: dantes.meph, children: [] }
final contractGroupListProvider =
    FutureProvider<List<ContractGroup>>((ref) async {
  await ensureContracts();

  final files = await listContracts();

  // 先解析所有文件信息（并行读取，文件多时避免串行 IO 拖慢首页加载）
  final infos = await Future.wait(
    files.map((name) async {
      final content = await readContract(name);
      final roleName = content == null ? null : extractRoleName(content);
      return ContractInfo(
        fileName: name,
        roleName: roleName ?? name.replaceAll('.meph', ''),
        isChild: isChildFileName(name),
        branchName: extractBranchName(name),
        // 命运一句话（仅子版可能含 @命运: 标记；母版/旧分支为 null）
        branchTitle:
            content == null ? null : extractBranchTitle(content),
      );
    }),
  );

  // 按母版前缀分组：母版按文件名；子版挂到对应母版下
  final groupMap = <String, ContractGroup>{};
  final pendingChildren = <String, List<ContractInfo>>{};

  for (final info in infos) {
    if (info.isChild) {
      final masterKey = extractMasterPrefix(info.fileName);
      pendingChildren.putIfAbsent(masterKey, () => []).add(info);
    } else {
      groupMap[extractMasterPrefix(info.fileName)] =
          ContractGroup(master: info, children: []);
    }
  }

  // 将子版挂到母版组上（孤儿子版则自动推断母版）
  for (final entry in pendingChildren.entries) {
    final masterKey = entry.key;
    final existing = groupMap[masterKey];
    final master = existing?.master ??
        ContractInfo(
          fileName: '$masterKey.meph',
          roleName: entry.value.first.roleName,
        );
    groupMap[masterKey] = ContractGroup(
      master: master,
      children: [...entry.value]..sort((a, b) => a.fileName.compareTo(b.fileName)),
    );
  }

  // 返回排序后的分组列表
  final groups = groupMap.values.toList()
    ..sort((a, b) => a.master.fileName.compareTo(b.master.fileName));
  return groups;
});

/// 切换当前使用的契约。
///
/// 保存契约名到 [SharedPreferences] 并刷新 [contractProvider]。
Future<void> switchContract(WidgetRef ref, String contractName) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(contractPrefKey, contractName);
  ref.invalidate(contractProvider);
  ref.invalidate(currentContractNameProvider);
}