import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../services/parser/meph_formatter.dart';
import '../services/parser/meph_parser.dart';
import '../services/storage/contract_repo.dart';

/// 契约编辑器
///
/// 基于 .meph 纯文本格式的直接编辑界面——这是最可靠的方式，
/// 因为规则语法是精确的、且 [parseMeph] / [serializeMeph] 可逆。
///
/// 实时校验：输入时防抖 400ms 调用 [parseMeph]，错误立即显示在编辑区下方，
/// 避免反复「保存 → 看错误 → 修改 → 再保存」的迭代。
/// 保存时仍做二次校验（双保险，防抖窗口内的最后编辑可能未实时校验到）。
///
/// 用途：
///   - 新建契约：传入空 [fileName]，预填 faust.meph 作为全语法教学模板
///   - 编辑母版：传入现有 [fileName] 与 [initialContent]，预填全文
///
/// 编辑体验提示：
///   需要更专业的编辑体验（行号、语法高亮、自动补全）时，
///   可在 VSCode 中安装 **Mephisto** 插件来编辑 `.meph` 文件。
class ContractEditorScreen extends StatefulWidget {
  /// 目标文件名（如 `my_story.meph`）；新建时可为空，保存时必须填写
  final String? fileName;

  /// 初始内容（编辑现有契约时预填；新建时自动加载 faust.meph 模板）
  final String? initialContent;

  const ContractEditorScreen({
    super.key,
    this.fileName,
    this.initialContent,
  });

  @override
  State<ContractEditorScreen> createState() => _ContractEditorScreenState();
}

class _ContractEditorScreenState extends State<ContractEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;

  /// 实时校验防抖定时器（400ms）
  Timer? _validateDebounce;

  /// 实时校验结果（null 表示格式正确；非 null 表示存在错误）
  MephParseError? _liveError;

  /// 新建模式是否仍在校验模板加载完成（编辑区先展示占位）
  bool _isNewLoading = false;

  bool get _isNew => widget.fileName == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fileName ?? '');
    _contentController = TextEditingController(
      text: widget.initialContent ?? _emptyContent,
    );
    _contentController.addListener(_onContentChanged);

    // 新建模式：异步加载 faust.meph 作为模板
    if (_isNew) {
      // 直接赋值（build 尚未执行，无需 setState）
      _isNewLoading = true;
      _loadTemplate();
    } else {
      // 编辑模式：预填后立即做一次实时校验，让用户第一时间看到格式状态
      _scheduleValidate();
    }
  }

  @override
  void dispose() {
    _validateDebounce?.cancel();
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 空内容占位（新建加载模板完成前的兜底）
  static const String _emptyContent = '';

  /// 异步加载 faust.meph 作为新建模板（覆盖全部 DSL 语法的最佳教学样例）。
  Future<void> _loadTemplate() async {
    String template;
    try {
      template = await rootBundle.loadString('assets/contracts/faust.meph');
    } catch (e) {
      // 模板加载失败（极端情况）：使用精简骨架兜底
      template = '''【角色名】
新角色

【锚点】
- 核心信念: 

【世界观】


【角色背景】


【开局场景】


【状态】


【规则】


''';
    }
    if (!mounted) return;
    _contentController.text = template;
    setState(() => _isNewLoading = false);
    _scheduleValidate();
  }

  /// 内容变化：调度防抖校验。
  void _onContentChanged() {
    _scheduleValidate();
  }

  /// 调度 400ms 防抖实时校验，避免每次击键都解析大文本。
  void _scheduleValidate() {
    _validateDebounce?.cancel();
    _validateDebounce = Timer(const Duration(milliseconds: 400), _validate);
  }

  /// 执行实时格式校验（解析失败时记录错误，供错误条展示）。
  void _validate() {
    final content = _contentController.text;
    if (content.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _liveError = null);
      return;
    }

    MephParseError? error;
    try {
      parseMeph(content);
    } on MephParseError catch (e) {
      error = e;
    } catch (_) {
      error = MephParseError(message: '无法解析的契约内容');
    }

    if (!mounted) return;
    setState(() => _liveError = error);
  }

  /// 保存契约：校验文件名 + 校验 .meph 格式 + 写入文件。
  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);

    // 1. 校验文件名
    var fileName = _nameController.text.trim();
    if (_isNew) {
      if (fileName.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('╳ 请填写文件名')),
        );
        return;
      }
      if (!fileName.endsWith('.meph')) {
        fileName = '$fileName.meph';
      }
      // 新建时检查重名
      if (!await isContractNameAvailable(fileName)) {
        messenger.showSnackBar(
          SnackBar(content: Text('╳ 文件名已存在: $fileName')),
        );
        return;
      }
    } else {
      // 编辑模式：使用传入文件名（不可改名，避免破坏子版关联）
      fileName = widget.fileName!;
    }

    // 2. 校验 .meph 格式（解析失败会抛带行号的 MephParseError）
    final content = _contentController.text;
    try {
      parseMeph(content);
    } on MephParseError catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '╳ 格式错误: ${e.message}'
            '（${e.blockName ?? ''}第 ${e.line ?? '?'} 行）',
          ),
        ),
      );
      return;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('╳ 解析失败: $e')),
      );
      return;
    }

    // 3. 写入文件
    try {
      await saveContract(fileName, content);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('╳ 保存失败: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, fileName); // 返回保存的文件名（null 表示取消/未保存）
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '✏️ 新建契约' : '✏️ 编辑契约'),
        centerTitle: false,
        actions: [
          // 一键格式化：文本级规范（缩进/空行/列表/规则运算符自动修复）
          IconButton(
            icon: const Icon(Icons.format_align_left, color: AppTheme.gold),
            tooltip: '格式化文本（调整缩进、空行并修复运算符空格）',
            onPressed: () {
              _contentController.text = formatMephText(_contentController.text);
              // 光标移到最后，直观看到格式化结果
              _contentController.selection = TextSelection.collapsed(
                offset: _contentController.text.length,
              );
            },
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('保存'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '取消',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- 文件名输入（新建模式）----
                if (_isNew) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '文件名（自动补 .meph 后缀）',
                      hintText: '如 my_story',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ---- .meph 源文本编辑区 ----
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(theme.brightness),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.2),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: _isNewLoading
                            ? '正在加载 faust.meph 模板...'
                            : '输入 .meph 契约内容...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ---- 实时校验错误条（有错误时显示）----
                if (_liveError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.crimson.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: AppTheme.crimson.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppTheme.crimson,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '第 ${_liveError!.line ?? '?'} 行'
                            '${_liveError!.blockName != null ? '，区块「${_liveError!.blockName}」' : ''}'
                            ': ${_liveError!.message}',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppTheme.crimson.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // ---- 格式提示（无错误时显示，分段展示便于阅读）----
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.gold),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• 契约以【区块名】组织：角色名 / 锚点 / 世界观 / '
                                '角色背景 / 开局场景 / 状态 / 规则 / 记忆 / 历史',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• 规则格式：[规则名] if 条件 -> 动作；'
                                '任意【自定义区块】可作为草稿/备忘，不会报错',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• 保存时自动校验格式并定位错误',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• 需要更专业的编辑体验（行号、语法高亮、自动补全）等等'
                                '可在 VSCode 安装 Mephisto 插件编辑 .meph 文件',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}