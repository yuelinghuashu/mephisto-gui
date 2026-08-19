import 'package:flutter_test/flutter_test.dart';
import 'package:mephisto/app/theme.dart';
import 'package:mephisto/domain/stage_color_palette.dart';

/// 角色色板分配测试
void main() {
  test('按字典序稳定分配（同角色永远同色）', () {
    final a = assignRoleColors(['梅菲斯特', '浮士德']);
    final b = assignRoleColors(['梅菲斯特', '浮士德']);
    expect(a, b);
    // Dart 默认按 UTF-16 code unit 排序：「梅」0x6885 < 「浮」0x6D6E
    // 因此梅菲斯特排首位 → 金；浮士德第二位 → 深红
    expect(a['梅菲斯特'], AppTheme.gold);
    expect(a['浮士德'], AppTheme.crimson);
  });

  test('角色名去重（同一角色不重复占色）', () {
    final colors = assignRoleColors(['浮士德', '浮士德', '梅菲斯特']);
    expect(colors.length, 2);
  });

  test('超过色板长度时循环复用', () {
    final roles = [
      '角色1',
      '角色2',
      '角色3',
      '角色4',
      '角色5',
      '角色6',
      '角色7',
      '角色8',
      '角色9', // 第 9 个 → 循环回第一色
    ];
    final colors = assignRoleColors(roles);
    expect(colors['角色1'], kStageRolePalette[0]);
    expect(colors['角色9'], kStageRolePalette[0]); // 循环
    expect(colors['角色2'], kStageRolePalette[1]);
  });
}
