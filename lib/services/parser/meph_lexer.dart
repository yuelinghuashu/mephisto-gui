/// Mephisto .meph 契约词法分析
///
/// 负责将 .meph 文本按 `【区块名】` 切分为区块列表（每行带绝对行号）。
/// 与结构化解析（[meph_parser.dart]）分离，职责单一。
library;

/// .meph 解析错误
///
/// 携带行号与区块名，便于向用户精确定位问题。
class MephParseError implements Exception {
  /// 错误所在行号（从 1 开始；无法确定时为 null）
  final int? line;

  /// 错误所在区块名（无法确定时为 null）
  final String? blockName;

  /// 错误描述
  final String message;

  MephParseError({this.line, this.blockName, required this.message});

  @override
  String toString() {
    final loc = line != null ? '第 $line 行' : '位置未知';
    final block = blockName != null ? '，区块「$blockName」' : '';
    return 'MephParseError: $message（$block$loc）';
  }
}

/// 已知区块白名单
///
/// 与 CLI 一致：显式列出合法区块名，避免拼写错误导致的隐式 bug。
/// 含用户书写区块（【名称】）与系统保留区块（`@名称`，如 `@命运`）。
const Set<String> knownBlocks = {
  '角色名',
  '锚点',
  '世界观',
  '角色背景',
  '开局场景',
  '状态',
  '规则',
  '记忆',
  '历史',
  // ---- 系统保留区块（`@` 前缀 = 系统生成元数据，用户不应书写）----
  '@命运',
};

/// 带行号的内容行
class Line {
  /// 行的原始文本（保留缩进和空格）
  final String text;

  /// 源文件绝对行号（从 1 开始）
  final int number;

  const Line(this.text, this.number);
}

/// 切分后的区块（未解析内容）
class Block {
  /// 区块标题，如「角色名」「锚点」
  final String title;

  /// 内容行（不含标题行），每行带绝对行号
  final List<Line> content;

  /// 标题行号
  final int line;

  /// 是否为已知区块（在 [knownBlocks] 白名单中）
  final bool isKnown;

  const Block({
    required this.title,
    required this.content,
    required this.line,
    required this.isKnown,
  });
}

/// 将 .meph 文本切分为区块列表（词法分析）。
///
/// 处理规则（草稿宽容策略）：
///   - 空行与 `#` 注释：区块外跳过，区块内保留（结构完整）
///   - `【区块名】` 标题：切分区块。已知区块标记 [Block.isKnown] 为 true；
///     未知区块（如【草稿】【设定集】）同样切分但标记为 false —— 解析层
///     会静默忽略未知区块，方便用户书写备忘/草稿，不会报错。
///   - 残缺标题（`【xxx` 无闭合 `】`，或 `xxx】` 无开头 `【`）→ 格式错误
///   - 区块外的普通内容 → 格式错误
List<Block> lexMeph(String text) {
  final lines = text.split('\n');
  final blocks = <Block>[];
  var currentTitle = '';
  final currentContent = <Line>[];
  var currentLine = 0;
  var inBlock = false;

  for (var i = 0; i < lines.length; i++) {
    final lineNumber = i + 1;
    final line = lines[i];
    final trimmed = line.trim();

    // 空行与注释
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      if (inBlock) {
        currentContent.add(Line(line, lineNumber));
      }
      continue;
    }

    // 区块标题（已知或未知均接受，草稿宽容）
    final title = blockTitle(trimmed);
    if (title != null) {
      if (inBlock) {
        blocks.add(
          Block(
            title: currentTitle,
            content: List.of(currentContent),
            line: currentLine,
            isKnown: knownBlocks.contains(currentTitle),
          ),
        );
      }
      currentTitle = title;
      currentContent.clear();
      currentLine = lineNumber;
      inBlock = true;
      continue;
    }

    // 残缺标题：以【开头但无闭合】，或以】结尾但无开头 → 格式错误
    if (trimmed.startsWith('【') || trimmed.endsWith('】')) {
      // 区分两种错误，帮助用户定位真实原因：
      //   - 以【开头（如 `【xxx`、`【】`、`【xxx】正文`）→ 标题本身/格式问题
      //   - 仅以】结尾（如 `xxx】`）→ 缺失开头
      final message = trimmed.startsWith('【')
          ? _describeBrokenBlockHeader(trimmed)
          : '区块标题缺少开头的 "【"（应以 "【标题】" 独立成行）';
      throw MephParseError(line: lineNumber, message: message);
    }

    // 区块外的普通内容
    if (!inBlock) {
      throw MephParseError(line: lineNumber, message: '内容出现在任何区块之外');
    }

    currentContent.add(Line(line, lineNumber));
  }

  // 保存最后一个区块
  if (inBlock) {
    blocks.add(
      Block(
        title: currentTitle,
        content: List.of(currentContent),
        line: currentLine,
        isKnown: knownBlocks.contains(currentTitle),
      ),
    );
  }

  if (blocks.isEmpty) {
    throw MephParseError(message: '没有有效区块');
  }
  return blocks;
}

/// 检查一行是否为区块标题。
///
/// 支持两种形式：
///   - 用户区块：`【标题】`（如 `【角色名】`）
///   - 系统保留区块：`@标题`（如 `@命运`），独立成行
///
/// `@` 前缀是「系统生成元数据」命名空间，与用户 `【】` 区块天然区分。
/// 未知名称同样接受作为草稿宽容处理（标记 [Block.isKnown] 为 false 供解析层判断）。
String? blockTitle(String trimmed) {
  // 系统保留区块：@xxx 独立成行
  if (trimmed.startsWith('@')) {
    final title = trimmed.substring(1).trim();
    if (title.isEmpty) return null;
    return '@$title';
  }
  // 用户区块：【标题】
  if (!trimmed.startsWith('【') || !trimmed.endsWith('】')) return null;
  final title = trimmed.substring(1, trimmed.length - 1).trim();
  if (title.isEmpty) return null;
  return title;
}

/// 描述以 `【` 开头的残缺区块标题行（供错误信息精确定位）。
///
/// 覆盖三种情况：
///   - `【】`（空标题）
///   - `【xxx`（未闭合，无 `】`）
///   - `【xxx】正文`（标题行带正文，且未以 `】` 结尾——被外层 `endsWith('】')`
///     判为残缺；若恰好以 `】` 结尾则属于「标题行不允许带正文」）
String _describeBrokenBlockHeader(String trimmed) {
  final closeIdx = trimmed.indexOf('】');
  if (closeIdx == -1) {
    return '区块标题格式错误：缺少闭合的 "】"';
  }
  final title = trimmed.substring(1, closeIdx).trim();
  if (title.isEmpty) {
    return '区块标题格式错误：标题不能为空（应写为 "【标题】"）';
  }
  // 有闭合】但整行未以】结尾 → 标题行后面带了正文
  return '区块标题格式错误：标题行不允许携带正文（"【$title】" 应独立成行）';
}
