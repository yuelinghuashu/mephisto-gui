/// Mephisto 叙事引擎 - 核心实体模型
///
/// 包含叙事引擎中所有核心实体类型：
///   - [Message]：单条对话消息
///   - [StateItem]：状态键值对
///   - [Rule]：规则定义
///   - [Memory]：长期记忆
///   - [HistoryEntry]：历史条目（存档用）
///
/// `StateItem` / `Rule` / `HistoryEntry` 为纯值对象，由 freezed 生成
/// `copyWith` / `==` / `hashCode` / `toString`；
/// `Message` / `Memory` 含动态生成的 id/timestamp（刻意排除在等值比较外），
/// 保持手写 Equatable + `copyWith` 以保留「按内容比较」语义。
library;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config.dart';
import 'enums.dart';
import 'values.dart';

part 'entities.freezed.dart';

// ============================================================
// 消息模型
// ============================================================

/// 唯一 ID 生成器
///
/// 与时间戳组合生成唯一 ID（`<毫秒时间戳>-<自增序号>`），
/// 避免同一毫秒内创建多个对象时 ID 冲突（仅时间戳不足以保证唯一）。
///
/// 计数器封装为「类级静态字段」而非文件级全局变量：
///   - 文件级 `int _idCounter` 在库加载时即初始化，多个测试库并行
///     加载时共享同一全局状态，可能导致跨库 ID 冲突/非确定性
///   - 类级静态字段 + 私有构造函数使生成逻辑完全封闭在 domain 层，
///     不向外暴露任何可变状态访问点
class _UniqueIdGenerator {
  _UniqueIdGenerator._();

  /// 自增序号计数器（类级静态，进程内唯一）
  static int _counter = 0;

  /// 生成全局唯一的对象 ID（时间戳 + 自增序号组合）。
  static String generate() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '$ms-${_counter++}';
  }
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
  /// 唯一标识（自动生成）
  final String id;

  /// 命运/角色/系统
  final MessageRole role;

  final String content;

  final DateTime timestamp;

  /// 骰子判定结果（仅系统消息承载，用于渲染「命运结算」卡片）
  ///
  /// 非 null 且非空时，UI 将其渲染为折叠/展开的命运结算卡片，
  /// 而非普通纯文本消息。
  final List<DiceResult>? diceResults;

  /// 发言者角色名（仅多角色舞台的 assistant 消息非空）
  ///
  /// 由舞台 Reducer 在创建角色消息时附加（`roleTag: roleName`），
  /// UI 据此查询角色色板并着色气泡（左边框 + 角色名标签）。
  ///
  /// 单角色叙事 / 命运 / 系统消息恒为 null（向后兼容，零行为改变）。
  final String? roleTag;

  Message({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.diceResults,
    this.roleTag,
  }) : id = id ?? _UniqueIdGenerator.generate(),
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
  Message.assistant(
    String content, {
    String? id,
    DateTime? timestamp,
    String? roleTag,
  }) : this(
         id: id,
         role: MessageRole.assistant,
         content: content,
         timestamp: timestamp,
         roleTag: roleTag,
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

  // 注意：props 只包含「内容值」字段，不含 id / timestamp。
  //
  // `id` 是实例唯一标识（用于区分同一内容的多次出现），
  // `timestamp` 是创建时间——两者都不是「值」的一部分。
  // 含 id/timestamp 时，相同内容的消息在 Equatable 比较中永远不相等，
  // 且全局自增 ID 计数器在各测试/实例间持续递增，导致非确定性行为。
  @override
  List<Object?> get props => [role, content, diceResults, roleTag];
}

// ============================================================
// 状态模型
// ============================================================

/// 状态键值对
///
/// 表示运行时状态中的一个键值对，如 `灵魂完整度: 85`。
@freezed
abstract class StateItem with _$StateItem {
  /// 构造函数
  const factory StateItem({
    /// 状态键
    required String key,

    /// 状态值（类型安全，由解析时推断并构造对应子类型）
    required StateValue value,
  }) = _StateItem;
}

// ============================================================
// 规则模型
// ============================================================

/// 规则定义
///
/// 表示一条从契约中解析的规则：
///   [规则名] if 条件 -> 动作
@freezed
abstract class Rule with _$Rule {
  /// 构造函数
  const factory Rule({
    /// 规则名称
    required String name,

    /// 条件表达式（原始字符串）
    required String condition,

    /// 动作表达式（原始字符串，不含 [group:xxx]）
    required String action,

    /// 互斥组名（空字符串表示无组）
    @Default('') String group,

    /// 源文件行号（用于错误定位）
    required int line,
  }) = _Rule;
}

// ============================================================
// 记忆模型
// ============================================================

/// 长期记忆
///
/// 代表引擎从对话中提取的关键事件摘要。
/// 记忆会被自动提取、压缩和去重。
///
/// 极简设计（为"坚守人设"服务）：
///   - [content]：记忆内容，**.meph【记忆】区块永久全量保存，永不删除**
///   - [importance]：1-5 星重要性，仅用于**注入时的排序裁剪**——
///     每轮把最重要的记忆优先喂给 LLM，窗口占满即止（模型读不到的仍在文件里，
///     并非遗忘，只是这轮没带）
@immutable
class Memory extends Equatable {
  /// 记忆唯一标识
  final String id;

  /// 记忆内容
  final String content;

  /// 创建时间
  final DateTime createdAt;

  /// 重要性权重（1-5，默认 3 = 中等）
  ///
  /// 注入提示词时按权重降序排序，保证人设核心/重大事件优先被模型看到；
  /// 压缩时高权重（≥ [highImportanceThreshold]）永不丢弃。
  final int importance;

  /// 构造函数
  Memory({
    String? id,
    required this.content,
    DateTime? createdAt,
    this.importance = defaultImportance,
  }) : id = id ?? _UniqueIdGenerator.generate(),
       createdAt = createdAt ?? DateTime.now();

  /// 默认权重（中等）
  static const int defaultImportance = 3;

  /// 高权重阈值：≥ 此值视为「核心记忆」，压缩时永不丢弃
  static const int highImportanceThreshold = 4;

  /// 最大权重
  static const int maxImportance = 5;

  /// 创建带权重/标签/置信度的记忆副本（保留 id / createdAt）。
  Memory copyWith({String? content, int? importance}) {
    return Memory(
      id: id,
      content: content ?? this.content,
      createdAt: createdAt,
      importance: importance ?? this.importance,
    );
  }

  // 同上：props 仅按「内容」比较，id / createdAt / 元数据不参与等值判断
  // （保持跨测试确定性，与 Message 设计一致）。
  @override
  List<Object?> get props => [content];
}

// ============================================================
// 历史条目
// ============================================================

/// 历史条目（存档用）
///
/// 与 [Message] 的区别：
///   - Message：UI 显示用（包含时间戳、ID 等）
///   - HistoryEntry：存储用（精简格式，用于子版存档）
@freezed
abstract class HistoryEntry with _$HistoryEntry {
  /// 构造函数
  const factory HistoryEntry({
    /// 消息角色
    required MessageRole role,

    /// 消息内容
    required String content,
  }) = _HistoryEntry;
}
