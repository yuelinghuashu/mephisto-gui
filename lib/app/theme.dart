import 'package:flutter/material.dart';

/// Mephisto 应用主题配置
///
/// 本类提供完整的主题定义，包括：
///   - 亮色主题（暖白/深灰）
///   - 暗色主题（纯黑/暖白）
///   - 共用设计令牌（颜色、圆角、间距等）
///
/// 使用方式：
///   - AppTheme.dark()   → 获取暗色主题
///   - AppTheme.light()  → 获取亮色主题
///   - AppTheme.of(brightness) → 根据亮度自动选择
///
/// 设计语言：
///   - 主色：金色（#C9A84C）—— 贯穿两个主题
///   - 字体：衬线体（叙事正文）/ 无衬线体（界面文字）
///   - 圆角：8pt（输入框）/ 12pt（卡片）
///
/// 内部实现：
///   亮/暗主题共用 [_buildTheme] 工厂方法，根据 [Brightness] 选取对应色板，
///   消除两个主题之间的大量重复代码。
class AppTheme {
  /// 私有构造函数，禁止实例化
  ///
  /// 本类是纯工具类，只提供静态成员，不应被创建实例。
  AppTheme._();

  // ============================================================
  // 暗色主题色板
  // ============================================================

  /// 暗色主题背景色（极深灰，接近纯黑但更柔和）
  static const Color darkBackground = Color(0xFF0D0D0D);

  /// 暗色主题表面色（深灰）
  static const Color darkSurface = Color(0xFF1A1A1A);

  /// 暗色主题表面变体色（中灰，用于卡片/输入框等浮层）
  static const Color darkSurfaceVariant = Color(0xFF2A2A2A);

  /// 暗色主题分割线颜色
  static const Color darkDivider = Color(0xFF3A3A3A);

  /// 暗色主题主文本色（暖白，长时间阅读不刺眼）
  static const Color darkTextPrimary = Color(0xFFE8E0D0);

  /// 暗色主题次要文本色（灰金，用于辅助信息）
  static const Color darkTextSecondary = Color(0xFFA09888);

  // ============================================================
  // 亮色主题色板
  // ============================================================

  /// 亮色主题背景色（暖白，模拟旧书页质感）
  static const Color lightBackground = Color(0xFFF5F0E8);

  /// 亮色主题表面色（纯白）
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// 亮色主题表面变体色（浅暖灰，用于卡片/输入框等浮层）
  static const Color lightSurfaceVariant = Color(0xFFEAE3D5);

  /// 亮色主题分割线颜色
  static const Color lightDivider = Color(0xFFD5CDBF);

  /// 亮色主题主文本色（深灰，清晰易读）
  static const Color lightTextPrimary = Color(0xFF1A1A1A);

  /// 亮色主题次要文本色（中灰）
  static const Color lightTextSecondary = Color(0xFF666666);

  // ============================================================
  // 通用色板（两个主题共享）
  // ============================================================

  /// 品牌主色——金色
  ///
  /// 象征：契约、烛火、神秘感
  /// 用途：标题、强调元素、关键状态
  static const Color gold = Color(0xFFC9A84C);

  /// 金色暗色变体（古铜色）
  ///
  /// 用途：次要强调、装饰边框（colorScheme.secondary）
  static const Color goldDark = Color(0xFF8B5A2B);

  /// 深红色
  ///
  /// 象征：梅菲斯特、危险、关键事件
  /// 用途：警告、高风险叙事节点
  static const Color crimson = Color(0xFFB22222);

  /// 金色上的可读前景色（按钮/强调元素上的文字与图标）
  ///
  /// 金色（#C9A84C）为浅金，深色前景对比度更高；亮/暗主题通用。
  static const Color onGold = Color(0xFF000000);

  /// 深红色上的可读前景色（危险按钮上的文字与图标）
  ///
  /// 深红（#B22222）为深色底，白色前景对比度更高；亮/暗主题通用。
  static const Color onCrimson = Color(0xFFFFFFFF);

  /// 通用圆角尺寸
  ///
  /// 遵循 8 点网格系统：
  ///   - 8pt：输入框、按钮等小组件
  ///   - 12pt：卡片、面板等大组件
  static const double radiusSmall = 8.0;
  static const double radiusLarge = 12.0;

  /// 移动端断点（逻辑像素）
  ///
  /// 宽度低于此值时界面切换为移动端布局（更紧凑/底部弹出面板/分区导航）。
  /// 被叙事页、首页、设置页、契约卡等多处共享，此前各处以裸数字 `600`
  /// 分散定义，统一收敛至此消除漂移。
  static const double mobileBreakpoint = 600;

  /// 叙事页 AppBar 中「▸ 分支名」所需的最小宽度（逻辑像素）。
  ///
  /// 可用宽度低于此值时隐藏分支名显示（避免文本消失但箭头孤立的窄屏问题）。
  /// 估算值：分「 ▸ 」+ 两侧间距 + 最小分支名宽度。
  static const double minWidthForBranchDisplay = 120;

  /// 错误色（红色）
  ///
  /// 用途：骰子失败、错误提示
  static const Color error = Color(0xFFE53935);

  /// 暗色主题辅助标签文字色（比次要文本更暗，用于标签/占位）
  static const Color darkLabelSecondary = Color(0xFF666666);

  /// 亮色主题辅助标签文字色（浅灰，用于标签/占位）
  static const Color lightLabelSecondary = Color(0xFF888888);

  /// 当前主题的辅助标签文字色（labelMedium 默认色 / 输入框 hint 色）
  static Color labelSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? darkLabelSecondary : lightLabelSecondary;

  /// 暗色主题警告条背景色（深棕，用于契约兜底提示条）
  static const Color darkWarningContainer = Color(0xFF3A2A14);

  /// 亮色主题警告条背景色（浅暖橙，用于契约兜底提示条）
  static const Color lightWarningContainer = Color(0xFFFFF3E0);

  /// 暗色主题警告条前景/图标色
  static const Color darkWarningOnContainer = Color(0xFFE8C07A);

  /// 亮色主题警告条前景/图标色
  static const Color lightWarningOnContainer = Color(0xFFB26A00);

  /// 当前主题的警告条背景色（用于契约兜底提示条等置顶警告）
  static Color warningContainer(Brightness brightness) =>
      brightness == Brightness.dark
      ? darkWarningContainer
      : lightWarningContainer;

  /// 当前主题的警告条前景/图标色
  static Color warningOnContainer(Brightness brightness) =>
      brightness == Brightness.dark
      ? darkWarningOnContainer
      : lightWarningOnContainer;

  /// 当前主题的警告条正文文字色（比图标色略深，保证正文可读）
  static Color warningText(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFD9B878)
      : const Color(0xFF8C5A00);

  // ============================================================
  // 主题构建
  // ============================================================

  /// 亮色主题单例缓存。
  ///
  /// [ThemeData] 构造是重量级操作（内部构建大量派生对象）；此前
  /// `dark()` / `light()` 每次调用都重新构造，`MyApp.build` 每执行一次
  /// （主题/语言切换）就重建两份完整主题。缓存后全生命周期只构造一次。
  static final ThemeData _light = _buildTheme(Brightness.light);

  /// 暗色主题单例缓存。
  static final ThemeData _dark = _buildTheme(Brightness.dark);

  /// 创建暗色主题
  ///
  /// 基于 Flutter 原生 ThemeData.dark()，覆盖以下自定义属性：
  ///   - 背景色：极深灰（#0D0D0D）
  ///   - 主色：金色（#C9A84C）
  ///   - 文本色：暖白（#E8E0D0）
  ///   - 圆角：8pt / 12pt
  ///
  /// 适用场景：
  ///   - 夜间阅读
  ///   - 沉浸式叙事
  ///   - 追求神秘氛围
  static ThemeData dark() => _dark;

  /// 创建亮色主题
  ///
  /// 基于 Flutter 原生 ThemeData.light()，覆盖以下自定义属性：
  ///   - 背景色：暖白（#F5F0E8）
  ///   - 主色：金色（#C9A84C）
  ///   - 文本色：深灰（#1A1A1A）
  ///   - 圆角：8pt / 12pt
  ///
  /// 适用场景：
  ///   - 日间阅读
  ///   - 清晰度优先
  ///   - 追求干净、明亮的阅读体验
  static ThemeData light() => _light;

  /// 统一的主题构建工厂方法
  ///
  /// 亮/暗主题仅色板不同，组件样式（AppBar、TextField、卡片、SnackBar）
  /// 完全一致。根据 [Brightness] 在亮/暗色板中选取色值，消除重复代码。
  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // 从亮/暗色板中选取当前主题色值
    final background = isDark ? darkBackground : lightBackground;
    final surface = isDark ? darkSurface : lightSurface;
    final surfaceVariant = isDark ? darkSurfaceVariant : lightSurfaceVariant;
    final divider = isDark ? darkDivider : lightDivider;
    final textPrimary = isDark ? darkTextPrimary : lightTextPrimary;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;

    // 基础主题（亮/暗）
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      // ---- 基础色 ----
      scaffoldBackgroundColor: background,
      primaryColor: gold,

      // ---- 颜色方案 ----
      colorScheme:
          (isDark ? const ColorScheme.dark() : const ColorScheme.light())
              .copyWith(
                primary: gold,
                secondary: goldDark,
                surface: surface,
                error: error,
              ),

      // ---- 应用栏 ----
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),

      // ---- 文字主题 ----
      // 注意：必须基于 `base.textTheme.copyWith(...)` 增量覆盖——
      // 若整体替换为只含部分角色的新 `TextTheme`，未定义的角色
      // （titleLarge / titleMedium 等）会变为 null，所有
      // `theme.textTheme.titleLarge?.copyWith(...)` 链因 `?.` 短路
      // 而静默失效（品牌标题/设置页标题/抽屉标题样式丢失）。
      textTheme: base.textTheme.copyWith(
        /// 叙事正文（bodyLarge）
        ///
        /// 用于：世界观、叙事文本、角色对话
        /// 特点：大字号、宽行高、衬线体（由外部字体提供）
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.8),

        /// 通用正文（bodyMedium）
        ///
        /// 用于：状态描述、辅助信息
        bodyMedium: TextStyle(color: textPrimary, fontSize: 16, height: 1.6),

        /// 大标题（titleLarge）
        ///
        /// 用于：品牌区标题、设置分区图标等强调级标题
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),

        /// 标题（titleMedium）
        ///
        /// 用于：卡片标题、Sheet 标题、抽屉标题等
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),

        /// 小标题（titleSmall）
        ///
        /// 用于：卡片标题、分区标题等强调性小标题
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),

        /// 辅助正文（bodySmall）
        ///
        /// 用于：次要说明、设置项副标题、骰子卡片说明
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),

        /// 标签文字（labelLarge）
        ///
        /// 用于：按钮文字、标签、次要标题
        labelLarge: TextStyle(color: textSecondary, fontSize: 13),

        /// 辅助文字（labelMedium）
        ///
        /// 用于：提示信息、状态条
        labelMedium: TextStyle(color: labelSecondary(brightness), fontSize: 12),

        /// 最小标签（labelSmall）
        ///
        /// 用于：文件名、时间、芯片等最小辅助文本
        labelSmall: TextStyle(color: textSecondary, fontSize: 11),
      ),

      // ---- 分割线 ----
      dividerColor: divider,

      // ---- SnackBar 提示条 ----
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // ---- 卡片主题 ----
      cardTheme: CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // ---- 弹窗菜单主题（统一 ⋮ 菜单 / 存档菜单，契合羊皮纸+金色风格）----
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceVariant,
        // 实色背景，无需透明 tint（避免额外合成层）
        textStyle: TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: gold.withValues(alpha: 0.3)),
        ),
        // 低阴影：减少弹出/收起动画的阴影模糊重绘成本
        elevation: 2,
      ),

      // ---- 输入框主题 ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: gold),
        ),
        hintStyle: TextStyle(color: labelSecondary(brightness)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  // ============================================================
  // 统一入口
  // ============================================================

  /// 根据亮度自动选择主题
  ///
  /// 参数：
  ///   - brightness: Brightness.dark 或 Brightness.light
  ///
  /// 返回值：
  ///   - 对应的 ThemeData 实例
  ///
  /// 使用示例：
  ///   ```dart
  ///   ThemeData theme = AppTheme.of(Brightness.dark);
  ///   ```
  static ThemeData of(Brightness brightness) {
    switch (brightness) {
      case Brightness.dark:
        return dark();
      case Brightness.light:
        return light();
    }
  }

  // ============================================================
  // 主题化取值（根据当前亮度返回对应变体）
  // ============================================================

  /// 当前主题的表面变体色（卡片/输入框等浮层背景）
  static Color surfaceVariant(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceVariant : lightSurfaceVariant;

  /// 当前主题的分割线颜色
  static Color divider(Brightness brightness) =>
      brightness == Brightness.dark ? darkDivider : lightDivider;

  /// 当前主题的次要文本色
  static Color textSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  // ============================================================
  // 共享动画样式
  // ============================================================

  /// 弹窗菜单动画样式（统一加速：默认 300ms → 120ms，菜单弹出更快更流畅）。
  ///
  /// 被首页契约卡片的 ⋮ 菜单与叙事页存档菜单共用，消除重复定义。
  static const AnimationStyle popupAnimationStyle = AnimationStyle(
    duration: Duration(milliseconds: 120),
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
}
