import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_notifier.dart';

/// 命运指引输入历史 Notifier（全局单列表）
///
/// 持久化最近 [maxHistory] 条用户输入（跨会话/跨契约保留），
/// 供 InputBar 的 ↑ / ↓ 快速回溯使用。
///
/// 设计决策（A1：全局共享）：
///   - 不按子版/契约/分支隔离历史——不同剧本常使用类似的方向词
///     （「调查」「询问」「前往」），全局共享反而更方便
///   - 存储量恒定：单个 SharedPreferences key，最多 [maxHistory] 条短文本，
///     不随子版文件数量增长，性能无虞
class InputHistoryNotifier extends AutoLoadNotifier<List<String>> {
  /// 历史上限（与 InputBar 原有 maxHistory 保持一致）
  static const int maxHistory = 5;

  /// SharedPreferences 存储键
  static const String key = 'mephisto_input_history';

  @override
  List<String> get defaultValue => const [];

  @override
  Future<List<String>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final list = decoded.whereType<String>().toList();
      state = list;
      return list;
    } catch (e) {
      // 恢复失败（JSON 损坏等）时保持默认值，不影响主流程
      debugPrint('InputHistoryNotifier.load 失败: $e');
      return null;
    }
  }

  /// 记录一条输入历史（去重 + 上限 [maxHistory] 条）。
  ///
  /// 去重规则：相邻重复不追加（连续发送相同内容无意义）。
  Future<void> push(String text) async {
    // 相邻重复去重
    if (state.isNotEmpty && state.last == text) return;

    final next = [...state, text];
    if (next.length > maxHistory) next.removeAt(0);
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(next));
    } catch (e) {
      debugPrint('InputHistoryNotifier.push 失败: $e');
    }
  }
}

/// 输入历史 Provider
final inputHistoryProvider =
    NotifierProvider<InputHistoryNotifier, List<String>>(
      InputHistoryNotifier.new,
    );
