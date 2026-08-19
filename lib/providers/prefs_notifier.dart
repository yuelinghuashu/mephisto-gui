/// 基于 SharedPreferences 的 Notifier 抽象基类
///
/// 两层设计：
///   - [AutoLoadNotifier]：统一「首次构建自动调用 load()」的样板，
///     适用于任何需要异步恢复的 Notifier（包括多字段配置）
///   - [PrefsNotifier]：在 [AutoLoadNotifier] 之上封装「单键字符串持久化」，
///     适用于主题/宽度/规则文本等单值用户偏好
///
/// 消除多个 Controller 中重复的 `build()` 样板与 load/save 实现。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首次构建自动调度 load() 的 Notifier 基类。
///
/// 子类只需声明 [defaultValue]，并在 [load] 中恢复持久化状态。
/// [load] 返回恢复后的状态值（无持久化数据或恢复失败时返回 null）。
abstract class AutoLoadNotifier<T> extends Notifier<T> {
  /// 无持久化数据时的默认状态
  T get defaultValue;

  @override
  T build() {
    // 首次构建时自动从持久化恢复（双保险：即使外部未显式调用 load 也可靠）
    // 捕获异步异常，避免 SharedPreferences 异常时产生未处理异步错误
    Future.microtask(() async {
      try {
        await load();
      } catch (e) {
        // 恢复失败时保持默认值，不影响主流程
        debugPrint('AutoLoadNotifier.load 失败: $e');
      }
    });
    return defaultValue;
  }

  /// 从持久化存储恢复状态；返回恢复后的值（无数据时返回 null）
  Future<T?> load();
}

/// 单键字符串持久化的 Notifier 基类。
///
/// 统一实现 load/save/clear 样板；子类只需声明：
///   - [key]：SharedPreferences 存储键
///   - [fromStorage] / [toStorage]：序列化与反序列化
///
/// 适用场景：主题模式、内容宽度、叙事规则文本等单值偏好。
abstract class PrefsNotifier<T> extends AutoLoadNotifier<T> {
  /// SharedPreferences 存储键
  String get key;

  /// 将持久化字符串解析为状态值；返回 null 表示无有效数据（保持当前状态）
  T? fromStorage(String raw);

  /// 将状态值序列化为持久化字符串
  String toStorage(T value);

  @override
  Future<T?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final parsed = fromStorage(raw);
    if (parsed == null) return null;
    state = parsed;
    return parsed;
  }

  /// 保存状态（写入持久化 + 更新状态）
  Future<void> save(T value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, toStorage(value));
    state = value;
  }

  /// 清除持久化状态（回退默认值）
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    state = defaultValue;
  }
}
