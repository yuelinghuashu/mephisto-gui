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
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'storage/contract_dir.dart';

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
  /// 文件变更回调（传入当前监听的文件名）
  final Future<void> Function(String fileName) onFileChanged;

  /// 监听不可用回调（文件系统不支持监听/监听流报错时触发）
  final VoidCallback? onUnavailable;

  /// 当前监听的文件变更订阅
  StreamSubscription<FileSystemEvent>? _sub;

  /// 文件变更防抖定时器
  Timer? _debounce;

  /// 当前监听的文件名（用于 sourceFileName 变化时重新绑定）
  String _watchedFileName = '';

  /// 契约目录（start 时解析并缓存）
  Directory? _contractsDir;

  /// 上次处理完的文件 mtime（抑制 saveChild 自我触发监听造成死循环）
  DateTime? _lastProcessedMtime;

  ContractFileWatcher({
    required this.onFileChanged,
    this.onUnavailable,
  });

  /// 当前监听的文件名
  String get watchedFileName => _watchedFileName;

  /// 开始或重新绑定对指定 .meph 文件的监听。
  ///
  /// 文件名未变化时不重复绑定；文件名变化时先取消旧订阅再绑定新文件。
  ///
  /// 注意：完整路径 = 契约目录（[getContractsDirectory]）+ 文件名，
  /// 与 [readContract] / [saveContract] 的路径解析保持一致。
  Future<void> start(String fileName) async {
    // 文件名未变化时不重复绑定
    if (fileName.isEmpty || fileName == _watchedFileName) return;

    cancel();
    _watchedFileName = fileName;

    try {
      final dir = await getContractsDirectory();
      _contractsDir = dir;
      if (!dir.existsSync()) return;

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

  /// 处理目录事件：防抖后触发文件变更回调。
  void _onDirEvent(FileSystemEvent _) {
    // 防抖：短时间内多次写入只触发一次（500ms）
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // mtime 抑制：saveChild 自己写文件也会触发事件，
      // 但 mtime 与上次处理后记录的一致 → 忽略，避免死循环
      final file = _watchedFile();
      if (file == null || !file.existsSync()) return;
      final mtime = file.lastModifiedSync();
      if (mtime == _lastProcessedMtime) return;

      // 处理期间暂停监听，避免「写 → 监听 → 再写」死循环；完成后恢复
      _sub?.pause();
      try {
        await onFileChanged(_watchedFileName);
        // 记录处理完的 mtime，抑制 saveChild 写文件触发的下一次监听
        final updated = _watchedFile();
        _lastProcessedMtime =
            updated != null && updated.existsSync()
                ? updated.lastModifiedSync()
                : null;
      } finally {
        _sub?.resume();
      }
    });
  }

  /// 当前监听文件的 [File] 对象（契约目录未解析时返回 null）。
  File? _watchedFile() {
    final dir = _contractsDir;
    if (dir == null || _watchedFileName.isEmpty) return null;
    return File('${dir.path}${Platform.pathSeparator}$_watchedFileName');
  }

  /// 取消当前文件监听并清理定时器。
  void cancel() {
    _debounce?.cancel();
    _debounce = null;
    _sub?.cancel();
    _sub = null;
    _watchedFileName = '';
    _contractsDir = null;
  }

  /// 销毁监听器（取消订阅 + 清理定时器 + 清除 mtime 记录）。
  void dispose() {
    cancel();
    _lastProcessedMtime = null;
  }
}