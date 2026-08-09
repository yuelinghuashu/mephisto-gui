/// 舞台 Provider：多角色舞台的只读数据组装
///
/// 数据源来自 [stage_repo.dart]（目录级舞台发现 + 角色卡独立解析）。
/// 本层把「舞台名 + 角色契约列表 + 公共世界观」组装为可消费的 Provider，
/// 供未来 M3 的首页舞台聚合卡 / 多角色叙事页使用。
///
/// 多角色舞台在此阶段仅做**数据层组装**，不触碰现有单角色叙事引擎
/// （`NarrativeNotifier` 及其 313 个测试保持零改动）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/stage_repo.dart';

/// 指定舞台目录的加载 Provider（autoDispose：无监听时释放，舞台切换不常驻）
///
/// 使用 family 变体：以舞台目录绝对路径为参数，显式加载对应舞台。
final stageProvider =
    FutureProvider.autoDispose.family<StageLoaded?, String>((
      ref,
      dirPath,
    ) async {
  return loadStage(dirPath);
});

/// 契约根目录下所有舞台的列表 Provider（用于首页聚合卡）
final stageListProvider =
    FutureProvider.autoDispose<List<StageInfo>>((ref) async {
  return listStages();
});