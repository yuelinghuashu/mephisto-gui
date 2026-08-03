/// Mephisto 叙事引擎 - 数据模型（Barrel 导出）
///
/// 统一导出所有核心数据模型。
/// 外部代码只需 `import 'package:mephisto/domain/models.dart'` 即可使用所有模型。
///
/// 拆分结构：
///   - [enums.dart]：枚举类型（MessageRole, DiceType）
///   - [values.dart]：值类型（StateValue sealed class）
///   - [entities.dart]：核心实体（Message, StateItem, Rule, Memory, HistoryEntry）
///   - [contract.dart]：契约模型（Contract）
///   - [config.dart]：配置模型（DiceResult, LlmConfig）
library;

export 'config.dart';
export 'contract.dart';
export 'entities.dart';
export 'enums.dart';
export 'values.dart';
