/// 舞台角色色板分配
///
/// 为多角色舞台的每一位角色分配一个稳定的主题色，
/// 供 UI 按角色着色消息气泡（左边框 + 角色名标签）。
///
/// 设计原则（与主题色板对齐，零契约侵入）：
///   - 复用 [AppTheme] 已有的主题色值（金色/深红/成功/警告）+ 4 种调和色
///   - 按字典序稳定分配（同一舞台每次进入颜色一致）
///   - 角色数超过色板长度时循环复用（5 个以内绝无撞色）
library;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 角色色板（与 AppTheme 色温体系调和）
///
/// 暖色系为主（延续 Mephisto 的金色/契约意象），
/// 兼顾不同角色的辨识度：
///   - 0 金（浮士德·契约）→ 品牌主色
///   - 1 深红（梅菲斯特·危险）
///   - 2 翡翠（神秘/自然）
///   - 3 藏青（理性/学者）
///   - 4 琥珀（警觉/炽热）
const List<Color> kStageRolePalette = [
  AppTheme.gold,
  AppTheme.crimson,
  Color(0xFF2E7D6B), // 翡翠（柔和绿，贴近 success 但更深沉）
  Color(0xFF3A4A8A), // 藏青（理性学者）
  Color(0xFFB26A00), // 琥珀（来自警告色加深）
  Color(0xFF7B4E9E), // 紫罗兰（神秘）
  Color(0xFFC65D3B), // 珊瑚（炽热）
  Color(0xFF52796F), // 松石（冷静）
];

/// 将角色名单分配为「角色名 → 主题色」的稳定映射。
///
/// 规则：
///   - 角色按字典序排序后依次取色板颜色（同角色永远同色）
///   - 角色名不区分大小写（contract.roleName 可能因用户书写大小写不同，
///     但同一舞台内保证稳定）
///
/// 参数：
///   - roleNames: 舞台全部角色名（去重后分配）
///
/// 返回：角色名（原始写法）→ 主题色。
Map<String, Color> assignRoleColors(List<String> roleNames) {
  final unique = roleNames.toSet().toList()..sort();
  final result = <String, Color>{};
  for (var i = 0; i < unique.length; i++) {
    result[unique[i]] = kStageRolePalette[i % kStageRolePalette.length];
  }
  return result;
}