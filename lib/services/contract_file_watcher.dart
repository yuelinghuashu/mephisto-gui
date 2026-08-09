/// 契约文件变更监听器
///
/// 负责监听契约目录中的 .meph 文件变更，实现「外部编辑器（VSCode）保存
/// → 规则热重载」的体验。从 [NarrativeScreen] 中抽离，使 UI 层聚焦渲染。
///
/// 设计要点（与旧内嵌逻辑保持一致）：
///   - 在契约目录上监听整个事件流（write/create/rename/modify 均覆盖）。
///     现代编辑器原子保存 = 临时文件 rename 覆盖，event.path 不固定，
///     因此不做路径精确匹配；契约目录文件极少，统一防抖重读当前文件即可。
///   - 防抖 500ms：短时间内多次写入只触发一次（与 CLI 版 fsnotify 对齐）
///   - mtime 抑制：saveChild 自己写文件也会触发事件，但 mtime 与上次处理
///     后记录的一致则忽略，避免死循环
///   - 监听不可用（如网络文件系统）时通过 [onUnavailable] 回调提醒用户，
///     叙事主流程不受影响
///
/// v1.2.0 增强：
///   - 监听目标从「单一当前源文件」扩展为「当前源文件 + 其母版」，
///     使外部修改母版 .meph 也能被感知（创作者通常编辑母版）
///   - mtime 抑制改为「按文件名记录」，母版/子版各自独立抑制，
///     外部修改母版不会被子版 mtime 误拦截
///   - [onFileChanged] 回调传入**实际变化**的文件名，而非固定的当前源文件名
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'storage/contract_dir.dart';
import 'storage/contract_repo.dart';
import 'storage/meph_file_name.dart';

/// 契约文件变更监听器
///
/// 使用示例：
/// ```dart
/// final watcher = ContractFileWatcher(
///   onFileChanged: (fileName) async { ... },
///   onUnavailable: () { ... },
/// );
/// watcher.start('faust.meph');
/// watcher.dispose();
/// ```
class ContractFileWatcher {
  /// 文件变更回调（传入实际变化的文件名：当前源文件或其母版）
  final Future<void> Function(String fileName) onFileChanged;

  /// 监听不可用回调（文件系统不支持监听/监听流报错时触发）
  final VoidCallback? onUnavailable;

  /// 当前监听的文件变更订阅
  StreamSubscription<FileSystemEvent>? _sub;

  /// 文件变更防抖定时器
  Timer? _debounce;

  /// 当前监听的文件名（用于 sourceFileName 变化时重新绑定）
  String _watchedFileName = '';

  /// 母版文件名（当前源文件为子版时 = 母版名；母版自身时 = null）
  String? _masterFileName;

  /// 契约目录（start 时解析并缓存）
  Directory? _contractsDir;

  /// 上次处理完的各文件 mtime（按文件名记录；抑制 saveChild 自我触发监听）
  final Map<String, DateTime> _lastProcessedMtimes = {};

  /// 各监听目标上次处理时的内容快照（按文件名记录）。
  ///
  /// 用于 macOS fsevents 目录级事件误报的过滤：
  /// fsevents 可能把「目录内其他文件的写入」报告为监听目标的 modify 事件，
  /// 但监听目标文件的内容实际上**没有变化** —— 通过内容比较即可识别并忽略。
  ///
  /// 与 [_lastProcessedMtimes] 的区别：
  ///   - [_lastProcessedMtimes]：处理后记录（mtime），用于抑制「saveChild
  ///     自身写文件」的循环触发（防死循环）
  ///   - [_lastProcessedContents]：处理前读取并缓存（内容），用于过滤
  ///     macOS 目录级误报——误报时目标文件内容未变，读取结果与缓存相同
  /// 使用内容而非 mtime 做误报过滤：mtime 在快速连续写入下可能因文件系统
  /// 精度限制而相同（真实修改可能被误判为未变），内容比较则精确无误。
  final Map<String, String> _lastProcessedContents = {};

  /// 测试用：暴露 start 时的内容基线（供单元测试验证初始化行为）。
  @visibleForTesting
  Map<String, String> get debugStartBaselineContents => _lastProcessedContents;

  ContractFileWatcher({
    required this.onFileChanged,
    this.onUnavailable,
  });

  /// 当前监听的文件名（当前源文件；含子版情形）
  String get watchedFileName => _watchedFileName;

  /// 当前监听的目标文件列表（当前源文件 + 母版；去重）
  List<String> get watchedTargets {
    final names = <String>[_watchedFileName];
    final master = _masterFileName;
    if (master != null && master != _watchedFileName) {
      names.add(master);
    }
    return names;
  }

  /// 开始或重新绑定对指定 .meph 文件的监听。
  ///
  /// 文件名未变化时不重复绑定；文件名变化时先取消旧订阅再绑定新文件。
  ///
  /// 监听目标 = 当前源文件 + 其母版：创作者通常在 VSCode 编辑母版，
  /// 若只监听当前源文件（进入叙事后自动存档切到子版），外部改母版将无法感知。
  ///
  /// 注意：完整路径 = 契约目录（[getContractsDirectory]）+ 文件名，
  /// 与 [readContract] / [saveContract] 的路径解析保持一致。
  Future<void> start(String fileName) async {
    // 文件名未变化时不重复绑定
    if (fileName.isEmpty || fileName == _watchedFileName) return;

    cancel();
    _watchedFileName = fileName;
    // 计算母版文件名：当前源文件为子版时 = 母版根 + .meph
    _masterFileName = isChildFileName(fileName)
        ? '${extractMasterPrefix(fileName)}.meph'
        : null;

    try {
      final dir = await getContractsDirectory();
      _contractsDir = dir;
      if (!await dir.exists()) return;

      // 初始化监听目标的内容基线（用于 macOS fsevents 目录级事件过滤）。
      //
      // 背景：macOS fsevents 是目录级事件流，可能把「目录内其他文件的写入」
      // 报告为监听目标文件的 modify 事件（路径精度不如 Linux inotify）。
      // 建立内容基线后，_processChangedFile 中可通过「内容未变化」识别误报并忽略。
      // 使用内容而非 mtime 作为基线依据：mtime 在快速连续写入下精度不足，
      // 内容比较则精确无误（真实修改必然导致内容变化）。
      for (final name in watchedTargets) {
        final file = _targetFile(name);
        if (file != null && await file.exists()) {
          try {
            _lastProcessedContents[name] = await file.readAsString();
          } catch (e) {
            // 读取失败（文件被占用/权限）时跳过缓存，首次事件正常触发
            debugPrint('初始化契约内容基线失败: $name ($e)');
          }
        }
      }

      final sub = dir.watch().listen(
        _onDirEvent,
        onError: (Object e) {
          debugPrint('文件监听错误: $e');
          onUnavailable?.call();
        },
      );
      _sub = sub;
    } catch (e) {
      // 文件系统不支持监听/路径异常时静默降级（不影响叙事主流程）
      debugPrint('启动文件监听失败: $e');
      onUnavailable?.call();
    }
  }

  /// 从目录事件中提取实际变化的文件名。
  ///
  ///   - [FileSystemModifyEvent] / [FileSystemCreateEvent]：取 [FileSystemEvent.path]
  ///   - [FileSystemMoveEvent]：取 destination（原子保存 = rename 覆盖，
  ///     事件流中目标文件名才是最终落盘的文件）
  ///
  /// 返回 null 表示该事件不含文件路径信息。
  String? _eventFileName(FileSystemEvent event) {
    final path = switch (event) {
      FileSystemModifyEvent(:final path) => path,
      FileSystemCreateEvent(:final path) => path,
      FileSystemDeleteEvent(:final path) => path,
      FileSystemMoveEvent(:final destination) => destination,
    };
    if (path == null || path.isEmpty) return null;
    // 目录事件（path 为目录自身）与不属于契约目录的文件均不在监听范围。
    // 注意：这里必须比较**完整路径**（path == _contractsDir.path），
    // 而非文件名（name == _contractsDir.path）——文件名只是路径最后一段，
    // 与目录完整路径永远不会相等，导致目录事件无法被正确过滤。
    final name = path.split(Platform.pathSeparator).last;
    if (name.isEmpty || path == _contractsDir?.path) return null;
    if (!name.endsWith('.meph')) return null;
    return name;
  }

  /// 判断变化的文件是否为当前监听目标（当前源文件或其母版）。
  bool _isWatchedTarget(String fileName) {
    return watchedTargets.contains(fileName);
  }

  /// 处理目录事件：防抖后触发文件变更回调。
  ///
  /// 仅当实际变化的文件名命中监听目标时才进入防抖处理，
  /// 避免目录中其他 .meph 文件的写入（如别的契约/子版）误触发。
  ///
  /// macOS fsevents 目录级事件过滤：
  ///   - fsevents 可能把「目录内其他文件（如 dantes.meph）的写入」报告为
  ///     监听目标文件（如 faust.meph）的 modify 事件
  ///   - 此时监听目标文件的内容**未发生变化** → 与 [start] 时记录的内容
  ///     比对即可识别并忽略（真实修改必然导致内容变化）
  ///   - 内容比较推迟到 [_processChangedFile] 中**异步**执行：
  ///     避免在 UI 事件循环上做同步文件 IO（[readAsStringSync] 可能因文件
  ///     大/IO 慢而卡顿界面）
  void _onDirEvent(FileSystemEvent event) {
    final changedName = _eventFileName(event);
    if (changedName == null || !_isWatchedTarget(changedName)) return;

    // 防抖：短时间内多次写入只触发一次（500ms）；
    // 记录实际变化的文件名，防抖结束后在 _processChangedFile 中异步
    // 读取内容并与基线比较（过滤 fsevents 误报），随后回调
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await _processChangedFile(changedName);
    });
  }

  /// 处理实际变化的文件：内容基线过滤 → mtime 抑制 → 回调 → 更新记录。
  Future<void> _processChangedFile(String fileName) async {
    final file = _targetFile(fileName);
    if (file == null) return;
    if (!_isWatchedTarget(fileName)) return;
    // 异步检查文件是否存在（避免 existsSync 阻塞事件循环）
    bool fileExists;
    try {
      fileExists = await file.exists();
    } catch (_) {
      fileExists = false; // 读取失败（权限/IO 异常）视为不存在
    }
    if (!fileExists) return;

    // ---- 异步内容基线过滤（防 macOS fsevents 目录级误报）----
    // 若事件报告的目标文件内容与缓存基线相同 → 其他文件写入的误报。
    // 用异步 readAsString 替代原事件回调中的 readAsStringSync，
    // 不阻塞 UI 事件循环。
    final String currentContent;
    try {
      currentContent = await file.readAsString();
    } catch (e) {
      // 读取失败（文件被占用/权限）时跳过内容检查，继续走 mtime 抑制
      debugPrint('读取契约内容失败: $fileName ($e)');
      return;
    }
    final baselineContent = _lastProcessedContents[fileName];
    if (baselineContent != null && currentContent == baselineContent) {
      return;
    }

    final DateTime mtime;
    try {
      mtime = await file.lastModified();
    } catch (_) {
      return; // 读取 mtime 失败（权限/IO 异常）时跳过
    }
    // mtime 抑制（按文件名独立记录）：saveChild 自己写文件也会触发事件，
    // 但 mtime 与上次处理后记录的一致 → 忽略，避免死循环
    if (mtime == _lastProcessedMtimes[fileName]) return;

    // 处理期间暂停监听，避免「写 → 监听 → 再写」死循环；完成后恢复
    _sub?.pause();
    try {
      await onFileChanged(fileName);
    } catch (e) {
      // 回调异常不应导致监听死循环：打印日志后继续执行 mtime 更新
      debugPrint('文件变更回调异常: $e');
    } finally {
      // 无论回调成功/失败，都更新 mtime 并恢复监听，
      // 防止异常导致的死循环（失败后不再重复触发同一文件）
      // 注意：这里不调用同步 existsSync/lastModifiedSync/readAsStringSync，
      // 而是在恢复监听后通过异步 API 更新缓存，避免阻塞 UI 事件循环。
      _sub?.resume();
      // 异步更新 mtime 与内容基线（不阻塞事件循环）
      unawaited(_refreshBaselines(fileName));
    }
  }

  /// 异步刷新指定文件的 mtime 与内容基线。
  ///
  /// 在 [_processChangedFile] 的 finally 块中调用，替代原先的同步
  /// `existsSync/lastModifiedSync/readAsStringSync`，避免在大文件或
  /// 网络文件系统上阻塞 UI 事件循环。
  Future<void> _refreshBaselines(String fileName) async {
    try {
      final updated = _targetFile(fileName);
      if (updated == null) {
        _lastProcessedMtimes[fileName] = DateTime.fromMillisecondsSinceEpoch(0);
        return;
      }
      final exists = await updated.exists();
      if (!exists) {
        _lastProcessedMtimes[fileName] = DateTime.fromMillisecondsSinceEpoch(0);
        _lastProcessedContents.remove(fileName);
        return;
      }
      _lastProcessedMtimes[fileName] = await updated.lastModified();
      _lastProcessedContents[fileName] = await updated.readAsString();
    } catch (e) {
      // 更新失败（文件被占用/权限）时保留旧基线，下次事件继续尝试
      debugPrint('更新契约内容缓存失败: $fileName ($e)');
    }
  }

  /// 指定文件的 [File] 对象（契约目录未解析时返回 null）。
  ///
  /// 统一用 `/` 拼接（与 contract_repo.dart 等文件保持一致）；
  /// dart:io 的 [File] 在 Windows 上也能正确解析 `/` 路径分隔符。
  File? _targetFile(String fileName) {
    final dir = _contractsDir;
    if (dir == null || fileName.isEmpty) return null;
    return File('${dir.path}/$fileName');
  }

  /// 取消当前文件监听并清理定时器。
  void cancel() {
    _debounce?.cancel();
    _debounce = null;
    _sub?.cancel();
    _sub = null;
    _watchedFileName = '';
    _masterFileName = null;
    _contractsDir = null;
    // 同时清除 mtime 记录：若 cancel 后立即 start 绑定同一个文件，
    // 旧 mtime 可能抑制新监听的首轮事件（热重载失效）。
    // [start] 每次重新绑定都应从全新状态开始。
    _lastProcessedMtimes.clear();
    _lastProcessedContents.clear();
  }

  /// 销毁监听器（取消订阅 + 清理定时器 + 清除 mtime 记录）。
  ///
  /// [cancel] 已清除 mtime，此处无需额外处理；
  /// 保留此方法作为显式生命周期钩子，便于未来扩展。
  void dispose() {
    cancel();
  }
}