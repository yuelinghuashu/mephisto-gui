import 'package:flutter/material.dart';

/// 设置分区独立子页
///
/// 移动端窄屏下，[SettingsScreen] 由「单页垂直堆叠全部区块」切换为
/// 「分区入口列表 + 点击进入独立子页」的导航模式。本组件是通用子页包装：
/// AppBar（返回按钮 + 分区标题）+ 居中受限的滚动内容容器。
///
/// 设计要点：
///   - [builder] 延迟构建区块内容——入口列表页**不实例化**各区块组件，
///     避免进入设置页时就触发 `ContractsDirSection` 等组件的 IO 初始化
///   - 内容宽度 maxWidth 600（与桌面端单页模式一致），窄屏自动占满
class SettingsSectionPage extends StatelessWidget {
  /// 分区标题（AppBar 显示 + 返回语义）
  final String title;

  /// 区块内容构建器（进入本页时才实例化）
  final WidgetBuilder builder;

  const SettingsSectionPage({
    super.key,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: false),
      // 滚动区域占满全屏宽；内容宽度约束下移到内部列，保持居中固定 600px
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: builder(context),
            ),
          ),
        ],
      ),
    );
  }
}
