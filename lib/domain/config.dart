/// Mephisto 叙事引擎 - 配置模型
///
/// 包含骰子结果 [DiceResult] 和 LLM 配置 [LlmConfig]。
/// 这些类型管理引擎的运行时行为和用户偏好。
library;

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'enums.dart';

// ============================================================
// 骰子结果
// ============================================================

/// 骰子判定结果
///
/// 用于展示骰子判定的详细信息。
/// 当规则条件中包含 roll() 表达式时，引擎会生成此结果。
///
/// 与 [RuleRunResult.rollInfo] 的关系：
///   - [ruleName]、[expression]、[value]、[maxValue]、[threshold]、[success]
///     提供了结构化访问能力（可分别取数值、阈值、状态）
///   - [displayString] 提供预格式化文本，直接用于 UI 展示和 LLM 提示词
@immutable
class DiceResult extends Equatable {
  /// 规则名称
  final String ruleName;

  /// 骰子表达式（如 "roll(1d100)"）
  final String expression;

  /// 实际掷出的点数
  final int value;

  /// 最大可能值
  final int maxValue;

  /// 判定阈值（可选，无阈值表示使用默认 50%）
  final int? threshold;

  /// 骰子点数是否达标（仅表示 roll() 部分 >= 阈值）
  final bool success;

  /// 整个规则条件是否真正匹配（即动作是否实际执行）
  ///
  /// 注意：`success` 只表示 roll() 部分达标，不等同于规则触发。
  /// 例如 `包含 "堕落" && roll(1d100) >= 50` 中，骰子掷出 86 时
  /// `success` 为 true，但如果输入不包含"堕落"，`triggered` 仍为 false。
  final bool triggered;

  /// 所属规则的执行动作（如 `状态.堕落指数 += 10`、`注入 "阴影蔓延"`）
  ///
  /// 用于在 [triggered] 为 true 时向用户展示「触发: {action}」。
  final String action;

  /// 构造函数
  const DiceResult({
    required this.ruleName,
    required this.expression,
    required this.value,
    required this.maxValue,
    this.threshold,
    required this.success,
    this.triggered = true,
    this.action = '',
  });

  /// 获取显示字符串（与旧 extractRollInfo 格式一致，兼容现有消费）
  String get displayString {
    final thresholdStr = threshold != null ? '（阈值 ≥ $threshold）' : '';
    final statusIcon = success ? '✦' : '╳';
    return '[$ruleName] $expression = $value/$maxValue $thresholdStr $statusIcon';
  }

  /// 命运反馈文案（根据成功与否和点数高低生成诗意化的判定反馈）。
  ///
  /// 参考《浮士德》时代意象（星象学/命运纺织线/天平审判/希腊神话），
  /// 避免重复使用"命运"字样，每条文案采用不同主题。
  ///
  /// 分档基于骰子面数 [maxValue] 自适应：
  ///   - 1d2（[maxValue] == 2）：安科二元判定，掷出 1 = 成功 / 掷出 2 = 失败，
  ///     只有两种结果，直接映射到成功/失败两档文案（不参与 1d100 的三分层）
  ///   - 1d100：75+ / 50-74 / <50（三分层）
  String get verdict {
    // ---- 1d2 安科二元判定：结果只有成功/失败两种，直接映射两档文案 ----
    if (maxValue == 2) {
      return success ? '星辰垂青，编织线为你而亮' : '星象错乱，诸神移开注视';
    }

    // ---- 1d100 高精度判定：三分层 ----
    final highBar = maxValue * 0.75; // 高分档
    final midBar = maxValue * 0.5; // 中分档

    // 成功判定
    if (success) {
      if (value >= highBar) {
        return '星辰垂青，编织线为你而亮';
      } else if (value >= midBar) {
        return '天秤轻轻向你的名字倾斜';
      } else {
        return '一根细线，堪堪撑住你的名字';
      }
    }
    // 失败判定
    if (value >= midBar) {
      return '星子偏移，你擦过了荣光的衣角';
    } else if (value >= maxValue * 0.25) {
      return '线轴空转，编织声渐渐远去';
    } else {
      return '星象错乱，诸神移开注视';
    }
  }

  @override
  List<Object?> get props => [
    ruleName,
    expression,
    value,
    maxValue,
    threshold,
    success,
    triggered,
    action,
  ];
}

// ============================================================
// LLM 配置
// ============================================================

/// LLM 配置
///
/// 按底层 API 协议区分后端：
///   - [LlmBackend.openaiCompatible]：OpenAI 兼容协议
///     （DeepSeek, OpenAI, 通义千问, Groq 等，仅 baseUrl + model 不同）
///   - [LlmBackend.ollama]：本地 Ollama 服务
@immutable
class LlmConfig extends Equatable {
  /// 默认 Base URL（OpenAI 兼容：DeepSeek）
  static const String defaultBaseUrl = 'https://api.deepseek.com/v1';

  /// 本地 Ollama 默认 URL
  static const String ollamaBaseUrl = 'http://localhost:11434/v1';

  /// 默认模型（OpenAI 兼容：DeepSeek）
  static const String defaultModel = 'deepseek-v4-flash';

  /// 后端类型
  final LlmBackend backend;

  /// 模型名称
  final String model;

  /// API 密钥（[backend] 为 [LlmBackend.ollama] 时为空字符串）
  final String apiKey;

  /// API 基础 URL
  ///   - DeepSeek：https://api.deepseek.com/v1
  ///   - OpenAI：https://api.openai.com/v1
  ///   - Ollama：http://localhost:11434
  final String baseUrl;

  /// 最大生成 Token 数
  final int maxTokens;

  /// 构造函数
  const LlmConfig({
    this.backend = LlmBackend.openaiCompatible,
    this.model = defaultModel,
    this.apiKey = '',
    this.baseUrl = defaultBaseUrl,
    this.maxTokens = 4096,
  });

  @override
  List<Object?> get props => [backend, model, apiKey, baseUrl, maxTokens];
}
