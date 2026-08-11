import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import 'prefs_notifier.dart';

/// 首页分区折叠状态（舞台区 / 契约区）。
///
/// 管理首页两个大区块的整体收缩/展开：
///   - [HomeSectionVisibilityState.stageCollapsed]：多角色舞台区是否折叠
///   - [HomeSectionVisibilityState.contractCollapsed]：单角色契约区是否折叠
///
/// 继承 [AutoLoadNotifier]：首次构建自动从 SharedPreferences 异步恢复
/// 持久化状态（重启应用后保持用户偏好），恢复失败时降级为默认展开。
class HomeSectionVisibility
    extends AutoLoadNotifier<HomeSectionVisibilityState> {
  /// 无持久化数据时的默认状态（两者均展开，与旧版行为一致）
  @override
  HomeSectionVisibilityState get defaultValue =>
      const HomeSectionVisibilityState();

  @override
  Future<HomeSectionVisibilityState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return HomeSectionVisibilityState(
      stageCollapsed: prefs.getBool(homeStageSectionCollapsedKey) ?? false,
      contractCollapsed:
          prefs.getBool(homeContractSectionCollapsedKey) ?? false,
    );
  }

  /// 切换舞台区折叠状态并持久化。
  Future<void> toggleStageCollapsed() async {
    final next = !state.stageCollapsed;
    state = state.copyWith(stageCollapsed: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(homeStageSectionCollapsedKey, next);
  }

  /// 切换契约区折叠状态并持久化。
  Future<void> toggleContractCollapsed() async {
    final next = !state.contractCollapsed;
    state = state.copyWith(contractCollapsed: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(homeContractSectionCollapsedKey, next);
  }
}

/// 首页分区折叠状态的不可变值对象。
///
/// 仅两个布尔值，无需 freezed 生成样板。
@immutable
class HomeSectionVisibilityState {
  /// 舞台区是否折叠
  final bool stageCollapsed;

  /// 契约区是否折叠
  final bool contractCollapsed;

  const HomeSectionVisibilityState({
    this.stageCollapsed = false,
    this.contractCollapsed = false,
  });

  HomeSectionVisibilityState copyWith({
    bool? stageCollapsed,
    bool? contractCollapsed,
  }) {
    return HomeSectionVisibilityState(
      stageCollapsed: stageCollapsed ?? this.stageCollapsed,
      contractCollapsed: contractCollapsed ?? this.contractCollapsed,
    );
  }
}

/// 首页分区折叠状态 Provider。
final homeSectionVisibilityProvider =
    NotifierProvider<HomeSectionVisibility, HomeSectionVisibilityState>(
      HomeSectionVisibility.new,
    );
