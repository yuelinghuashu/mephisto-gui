/// 叙事 Reducer 共享纯函数工具
///
/// 单角色 [narrative_reducer.dart] 与多角色 [stage_narrative_reducer.dart]
/// 之间大量状态迁移逻辑相同（历史转消息、附加上下文/移除附件）。
/// 本文件将这些纯函数集中定义，两个 Reducer 各自引用，消除重复实现。
library;

import 'models.dart';

/// 将历史条目列表转换为 UI 消息列表。
///
/// 历史条目只含命运 / 角色两类（系统消息不参与存档）；
/// 转换后生成对应的 [Message.fate] / [Message.assistant] / [Message.system]。
///
/// 被单角色与多角色 Reducer 共用的唯一实现（原 `historyToMessages` 与
/// `stageHistoryToMessages` 完全相同，合并为一份）。
List<Message> historyToMessages(List<HistoryEntry> history) {
  return [
    for (final h in history)
      switch (h.role) {
        MessageRole.fate => Message.fate(h.content),
        MessageRole.assistant => Message.assistant(h.content),
        MessageRole.system => Message.system(h.content),
      },
  ];
}

/// 追加一条附加上下文，返回 (新 fileName 列表, 新 content 列表) 元组。
///
/// 会话级附件是「文件名列表 + 内容列表」平行数组。单角色与多角色
/// Reducer 的 [NarrativeState] / [StageNarrativeState] 各自持有这两组
/// 字段，追加逻辑完全一致，因此提取为本纯函数。
(List<String>, List<String>) appendAttachment(
  List<String> fileNames,
  List<String> contexts,
  String fileName,
  String content,
) {
  return ([...fileNames, fileName], [...contexts, content]);
}

/// 移除指定索引的附加上下文，返回 (新 fileName 列表, 新 content 列表) 元组。
///
/// 索引越界时返回 null（表示无变化，调用方应直接返回原状态）。
(List<String>, List<String>)? removeAttachmentAt(
  List<String> fileNames,
  List<String> contexts,
  int index,
) {
  if (index < 0 || index >= fileNames.length) return null;
  return ([...fileNames]..removeAt(index), [...contexts]..removeAt(index));
}
