/// Mephisto 叙事引擎 - 命运树构建器
///
/// 从契约信息列表 [ContractInfo] 构建递归的 [ContractGroup] 命运树。
/// 与文件系统 / Riverpod 完全解耦（纯函数），可独立单元测试。
///
/// `ContractInfo` 与 `ContractGroup` 也定义于此——契约树的纯数据模型
/// 与「构建算法」放在一起，`contract_provider.dart` 仅负责 IO 与 Provider
/// 组装（re-export 本文件保持向后兼容）。
library;

/// 契约树最大层级深度（母版根为 1）。
///
/// 用于 [buildContractTree] 构建命运树时的递归深度守卫：
/// 超过此深度的文件名链会被截断为叶子节点，防止用户手动创建的超长
/// 层级链（如 `a.b.c.d.e.f...`）导致递归过深甚至栈溢出。
const int maxContractDepth = 8;

/// 契约信息（文件名 + 角色名 + 是否子版）
class ContractInfo {
  /// 契约文件名（如 `faust.meph`、`faust.dark.meph`、`faust.dark.light.meph`）
  final String fileName;

  /// 契约角色名（从【角色名】区块解析；失败时回退为文件名去扩展名）
  final String roleName;

  /// 是否为子版文件（母版根之外还有路径段）
  ///
  /// 子版 = 母版 + 运行时对话/状态/记忆/历史，是存档快照或分支。
  final bool isChild;

  /// 子版的分支名（取路径最后一段；如 `child`、`dark`、`light`）
  final String? branchName;

  /// 子版「命运一句话」（用户另存为分支时填写，取自子版【角色背景】的 `@命运:` 标记）
  ///
  /// 用于首页展示更可读的支流描述；未填写时为 null，首页回落为显示 [branchName]。
  final String? branchTitle;

  /// 文件最后修改时间（用于首页按「最近编辑」排序最近使用的契约）。
  ///
  /// 取整棵子树的最大 mtime（含子版）：自动保存/编辑子版时，
  /// 母版卡片应反映整棵命运树的最新活动时间。
  /// null 表示未知（文件不存在或读取失败），排序时视为最旧。
  final DateTime? lastModified;

  /// 该文件所属的层级深度（母版根为 0，一级子版为 1，二级为 2 …）
  ///
  /// 首次访问时计算并缓存，避免 UI 渲染期间对同一节点反复执行
  /// `replaceAll + split` 的字符串开销。
  late final int depth = _computeDepth(fileName);

  ContractInfo({
    required this.fileName,
    required this.roleName,
    this.isChild = false,
    this.branchName,
    this.branchTitle,
    this.lastModified,
  });

  /// 从文件名计算层级深度：`faust.meph` → 0，`faust.dark.meph` → 1。
  static int _computeDepth(String fileName) =>
      fileName.replaceAll('.meph', '').split('.').length - 1;
}

/// 契约分组：一个节点（母版或子版）+ 其下所有子节点
///
/// 多级树模型：通过层级文件名（`.` 分段）表达派生链，
/// `children` 是**递归的同构节点列表**（而非平级信息）：
///
/// ```
/// ContractGroup(master: faust)                          // 母版根
/// ├─ ContractGroup(master: faust.dark)                  // 一级分支
/// │   └─ ContractGroup(master: faust.dark.light)        // 二级分支
/// └─ ContractGroup(master: faust.child)                 // 默认存档（一级）
/// ```
class ContractGroup {
  /// 当前节点契约（母版或子版）
  final ContractInfo master;

  /// 该节点下的子节点（递归：每个也是 ContractGroup）
  final List<ContractGroup> children;

  const ContractGroup({required this.master, required this.children});

  /// 直接子节点数量
  int get childCount => children.length;

  /// 是否有直接子节点
  bool get hasChildren => children.isNotEmpty;

  /// 递归统计整棵子树的总节点数（含自身）
  int get totalCount =>
      1 + children.fold<int>(0, (sum, c) => sum + c.totalCount);

  /// 递归收集整棵子树的所有契约信息（含自身，深度优先）
  List<ContractInfo> get allInfos => [
    master,
    ...children.expand((c) => c.allInfos),
  ];

  /// 该节点所处的层级深度（母版根为 0，一级子版为 1 …）
  int get depth => master.depth;

  /// 整棵子树的最近编辑时间（含自身与所有后代的最大 [ContractInfo.lastModified]）。
  ///
  /// 用于首页按「最近编辑」对顶级母版树排序：自动保存/编辑子版时，
  /// 母版卡片应反映整棵命运树的最新活动时间。
  /// null 表示整棵子树均无可用 mtime（此时按签名顺序兜底）。
  DateTime? get latestModified {
    final candidates = <DateTime>[
      if (master.lastModified != null) master.lastModified!,
      for (final child in children)
        if (child.latestModified != null) child.latestModified!,
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

/// 从契约信息列表构建「命运树」纯函数。
///
/// 与文件系统 / Riverpod 解耦，输入 `infos` 输出递归的
/// [ContractGroup] 列表（按「最近编辑」降序），便于独立单元测试。
///
/// 算法步骤：
///   1. 按「完整路径」索引（路径 = 文件名去 .meph，如 faust.dark.light）
///   2. 预分组「直接父路径 → 直接子路径」，避免递归中每层全量遍历
///      （将整树构建从 O(N²) 降为 O(N)）
///   3. 递归构建子树，处理深度守卫与孤儿子版
///   4. 顶层根按「最近编辑」降序排序
List<ContractGroup> buildContractTree(List<ContractInfo> infos) {
  // 按「完整路径」索引：路径 = 文件名去 .meph（如 faust.dark.light）
  final infoMap = <String, ContractInfo>{
    for (final info in infos) info.fileName.replaceAll('.meph', ''): info,
  };

  // 预分组：将「直接父路径 → 直接子路径」映射一次性构建完成，
  // 避免递归中每层都全量遍历 infoMap（将整树构建从 O(N²) 降为 O(N)）。
  //
  // 通过「路径段数 = 父段数 + 1」精确识别直接子节点：
  //   - `faust`     → 子节点必须是恰好 2 段且以 `faust.` 开头
  //   - `faust.dark` → 子节点必须是恰好 3 段且以 `faust.dark.` 开头
  //
  // 使用 Set 去重：同一「父 → 子」关系可能由多个后代路径推导得出
  // （如 faust.dark.light 与 faust.dark.light.mem 都会推导 faust.dark
  // 是 faust 的下级，但只需记录一次）。
  //
  // 不仅为「文件实际存在」的完整路径建立父子关系，还为所有**中间前缀**
  // 建立「前缀 → 下一段」关系。这样孤儿链（如只有 faust.dark.light.meph
  // 而无 faust.meph / faust.dark.meph）的占位节点也能递归找到子路径，
  // 不会在占位根下丢失深层子版。
  final childrenOf = <String, List<String>>{};
  for (final info in infos) {
    final segments = info.fileName.replaceAll('.meph', '').split('.');
    if (segments.length < 2) continue; // 母版根无父

    // 完整路径的父子关系
    void addChild(String parent, String child) {
      final list = childrenOf.putIfAbsent(parent, () => <String>[]);
      if (!list.contains(child)) list.add(child);
    }

    final fullPath = segments.join('.');
    final parentPath = segments.take(segments.length - 1).join('.');
    addChild(parentPath, fullPath);

    // 中间前缀的父子关系（处理孤儿链缺失中间层）
    for (var i = 1; i < segments.length - 1; i++) {
      final prefix = segments.take(i).join('.');
      final nextPath = segments.take(i + 1).join('.');
      addChild(prefix, nextPath);
    }
  }
  // 每组内保持字典序（与旧实现 sorted 行为一致）
  for (final paths in childrenOf.values) {
    paths.sort();
  }

  // 递归构建子树（childrenOf 已提供 O(1) 查找直接子节点）
  //
  // 深度守卫：文件名的 `.` 分段数表示层级深度，正常情况下不会很深
  // （母版.分支.分支…）。但用户可能手动创建超长链（如 a.b.c.d...），
  // 递归过深会导致栈溢出，因此超过 [maxContractDepth] 时截断为叶子节点。
  //
  // 子节点不额外过滤 infoMap：childrenOf 通过「路径段数 = 父段数 + 1」
  // 精确构建，已保证只有直接子路径；若某子路径在 infoMap 中不存在
  // （孤儿链中间层占位），buildGroup 会递归生成占位节点继续展开，
  // 确保深层真实子版不会丢失。
  ContractGroup buildGroup(String path) {
    // 当前路径段数作为深度（母版根为 1）
    final segments = path.split('.');
    if (segments.length > maxContractDepth) {
      // 超过最大深度：截断为叶子节点，**不再递归展开**。
      //
      // 不能「截断后继续 buildGroup(truncPath)」——若 truncPath 在
      // infoMap 中不存在（超深孤儿链），占位节点会递归展开子路径，
      // 子路径又截断回同一 truncPath，造成无限递归（栈溢出）。
      final truncPath = segments.take(maxContractDepth).join('.');
      final truncInfo = infoMap[truncPath];
      if (truncInfo != null) {
        return ContractGroup(master: truncInfo, children: const []);
      }
      return ContractGroup(
        master: ContractInfo(
          fileName: '$truncPath.meph',
          roleName: truncPath.split('.').last,
          isChild: truncPath.split('.').length >= 2,
        ),
        children: const [],
      );
    }

    final info = infoMap[path];
    if (info == null) {
      // 孤儿节点（父占位缺失）：用文件名兜底生成占位节点，
      // 递归展开子路径（占位节点继续作为占位递归处理）。
      final segmentCount = path.split('.').length;
      return ContractGroup(
        master: ContractInfo(
          fileName: '$path.meph',
          roleName: path.split('.').last,
          isChild: segmentCount >= 2,
        ),
        children: [
          for (final childPath in childrenOf[path] ?? const <String>[])
            buildGroup(childPath),
        ],
      );
    }

    final directChildren = [
      for (final childPath in childrenOf[path] ?? const <String>[])
        buildGroup(childPath),
    ];
    return ContractGroup(master: info, children: directChildren);
  }

  // 顶层根 = 段数为 1 的母版（或仅有 1 段的文件）
  final groups = <ContractGroup>[];
  final roots =
      infoMap.keys.where((path) => path.split('.').length == 1).toList()
        ..sort();
  for (final root in roots) {
    groups.add(buildGroup(root));
  }

  // 孤儿子版（其父链不存在母版根，如只有 faust.dark 而无 faust.meph）：
  // 用占位节点补为顶层根，确保不无处展示
  final rootFirstSegments = roots.map((p) => p.split('.').first).toSet();
  final allFirstSegments = infoMap.keys.map((p) => p.split('.').first).toSet();
  for (final first in allFirstSegments.difference(rootFirstSegments)) {
    groups.add(buildGroup(first));
  }

  // 按「最近编辑」降序排序顶层母版树：
  //   - 子树最新 mtime 越大 → 排越前（最近使用的契约优先展示）
  //   - 无可用 mtime（mtime 全为 null）→ 保持原有字典序
  groups.sort((a, b) {
    final at = a.latestModified;
    final bt = b.latestModified;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });

  return groups;
}
