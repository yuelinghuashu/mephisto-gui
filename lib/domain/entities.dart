/// Mephisto 叙事引擎 - 核心实体模型
///
/// 包含叙事引擎中所有核心实体类型：
///   - [Message]：单条对话消息
///   - [StateItem]：状态键值对
///   - [Rule]：规则定义
///   - [Memory]：长期记忆
///   - [HistoryEntry]：历史条目（存档用）
library;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';
import 'enums.dart';
import 'values.dart';

// ============================================================
// 消息模型
// ============================================================

/// 全局自增 ID 计数器。
///
/// 与时间戳组合生成唯一 ID（`<毫秒时间戳>-<自增序号>`），
/// 避免同一毫秒内创建多个对象时 ID 冲突（仅时间戳不足以保证唯一）。
int _idCounter = 0;

/// 生成全局唯一的对象 ID（时间戳 + 自增序号组合）。
String _generateUniqueId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  return '$ms-${_idCounter++}';
}

/// 单条对话消息
///
/// 代表叙事流中的一条消息，包含发送者、内容和时间戳。
///
/// 使用示例：
///   ```dart
///   final msg = Message.fate('你来到了天堂');
///   final reply = Message.assistant('浮士德：这里...好温暖');
///   ```
@immutable
class Message extends Equatable {
  /// 消息唯一标识（自动生成）
  final String id;

  /// 消息角色（命运/角色/系统）
  final MessageRole role;

  /// 消息内容
  final String content;

  /// 消息时间戳
  final DateTime timestamp;

  /// 骰子判定结果（仅系统消息承载，用于渲染「命运结算」卡片）
  ///
  /// 非 null 且非空时，UI 将其渲染为折叠/展开的命运结算卡片，
  /// 而非普通纯文本消息。
  final List<DiceResult>? diceResults;

  /// 构造函数
  Message({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.diceResults,
  }) : id = id ?? _generateUniqueId(),
       timestamp = timestamp ?? DateTime.now();

  /// 创建一条命运（用户）消息
  Message.fate(String content, {String? id, DateTime? timestamp})
    : this(
        id: id,
        role: MessageRole.fate,
        content: content,
        timestamp: timestamp,
      );

  /// 创建一条角色（AI）消息
  Message.assistant(String content, {String? id, DateTime? timestamp})
    : this(
        id: id,
        role: MessageRole.assistant,
        content: content,
        timestamp: timestamp,
      );

  /// 创建一条系统消息（可选承载骰子判定结果）
  Message.system(
    String content, {
    String? id,
    DateTime? timestamp,
    List<DiceResult>? diceResults,
  }) : this(
        id: id,
        role: MessageRole.system,
        content: content,
        timestamp: timestamp,
        diceResults: diceResults,
      );

  @override
  List<Object?> get props => [id, role, content, timestamp, diceResults];
}

// ============================================================
// 状态模型
// ============================================================

/// 状态键值对
///
/// 表示运行时状态中的一个键值对，如 `灵魂完整度: 85`。
@immutable
class StateItem extends Equatable {
  /// 状态键
  final String key;

  /// 状态值（类型安全，由解析时推断并构造对应子类型）
  final StateValue value;

  /// 构造函数
  const StateItem({required this.key, required this.value});

  @override
  List<Object?> get props => [key, value];
}

// ============================================================
// 规则模型
// ============================================================

/// 规则定义
///
/// 表示一条从契约中解析的规则：
///   [规则名] if 条件 -> 动作
@immutable
class Rule extends Equatable {
  /// 规则名称
  final String name;

  /// 条件表达式（原始字符串）
  final String condition;

  /// 动作表达式（原始字符串，不含 [group:xxx]）
  final String action;

  /// 互斥组名（空字符串表示无组）
  final String group;

  /// 源文件行号（用于错误定位）
  final int line;

  /// 构造函数
  const Rule({
    required this.name,
    required this.condition,
    required this.action,
    this.group = '',
    required this.line,
  });

  @override
  List<Object?> get props => [name, condition, action, group, line];
}

// ============================================================
// 记忆模型
// ============================================================

/// 长期记忆
///
/// 代表引擎从对话中提取的关键事件摘要。
/// 记忆会被自动提取、压缩和去重。
@immutable
class Memory extends Equatable {
  /// 记忆唯一标识
  final String id;

  /// 记忆内容
  final String content;

  /// 创建时间
  final DateTime createdAt;

  /// 构造函数
  Memory({
    String? id,
    required this.content,
    DateTime? createdAt,
  }) : id = id ?? _generateUniqueId(),
       createdAt = createdAt ?? DateTime.now();

  @override
  List<Object?> get props => [id, content, createdAt];
}

// ============================================================
// 历史条目
// ============================================================

/// 历史条目（存档用）
///
/// 与 [Message] 的区别：
///   - Message：UI 显示用（包含时间戳、ID 等）
///   - HistoryEntry：存储用（精简格式，用于子版存档）
@immutable
class HistoryEntry extends Equatable {
  /// 消息角色
  final MessageRole role;

  /// 消息内容
  final String content;

  /// 构造函数
  const HistoryEntry({required this.role, required this.content});

  @override
  List<Object?> get props => [role, content];
}