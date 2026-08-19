import 'package:flutter/material.dart';

/// 居中 + 可选最大宽度的内容包装
///
/// 叙事界面的输入区与状态条共用「居中受限」布局（内容占满可用宽度、
/// 超出 [contentMaxWidth] 时居中约束），提取为共享小组件消除重复。
class WidthConstrainedCenter extends StatelessWidget {
  /// 内容最大宽度（null 时占满可用宽度，不约束）
  final double? contentMaxWidth;

  /// 内部内容
  final Widget child;

  const WidthConstrainedCenter({
    super.key,
    required this.contentMaxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: contentMaxWidth ?? double.infinity,
        ),
        child: child,
      ),
    );
  }
}
