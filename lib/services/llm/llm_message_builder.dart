/// LLM 消息列表构建工具
///
/// 单角色 [NarrativeTurnService] 与多角色 [StageTurnService] 的
/// `_buildLlmMessages` 逻辑几乎完全相同：
///   - 过滤系统消息（UI 展示用，不发给 LLM）
///   - 映射角色为 `user` / `assistant`
///   - 组装 `system prompt + 历史 + 当前输入`
///
/// 抽取为共享工具函数，消除两处约 15 行的重复样板。
library;

import '../../domain/models.dart';
import 'client.dart';

/// 构建 LLM 消息列表（系统提示词 + 历史 + 当前输入）。
///
/// 参数：
///   - [systemPrompt]：已构建好的系统提示词（单角色或多角色版本）
///   - [historyMessages]：历史消息（系统消息会被过滤不发送给 LLM）
///   - [userInput]：当前用户输入（命运指引）
List<LlmMessage> buildLlmMessageList({
  required String systemPrompt,
  required List<Message> historyMessages,
  required String userInput,
}) {
  final history = historyMessages
      .where((m) => m.role != MessageRole.system)
      .map(
        (m) => LlmMessage(
          role: m.role == MessageRole.fate ? 'user' : 'assistant',
          content: m.content,
        ),
      );
  return [
    LlmMessage(role: 'system', content: systemPrompt),
    ...history,
    LlmMessage(role: 'user', content: userInput),
  ];
}