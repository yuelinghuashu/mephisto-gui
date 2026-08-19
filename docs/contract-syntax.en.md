# 📜 Contract Syntax Reference (.meph File Format)

> Mephisto's _Contract_ is a plain-text file with the `.meph` extension.
> It defines the character's soul anchors, worldview, initial state, and behavioral rules—the "framework of fate" for the narrative engine.
>
> **中文版：[简体中文](contract-syntax.md)**

## 1. File Structure

A `.meph` file consists of several **sections** (`区块`). Each section starts with a `【Section Name】` title line, followed by the section content.

```meph
【角色名】
浮士德

【锚点】
- 核心信念：真理比生命更重要

【状态】
- 灵魂完整度：100
- 情绪：永不满足

【世界观】
16 世纪的德意志，一个充满神秘学与契约的世界。

【开局场景】
烛火摇曳的书斋中，浮士德坐在成堆的典籍之间。
```

## 2. Section Overview

| Section                            | Required    | Description                                                         |
| ---------------------------------- | ----------- | ------------------------------------------------------------------- |
| 【角色名】(Role Name)              | ✅          | Character name (affects the appellation in the system prompt)       |
| 【锚点】(Anchors)                  | Recommended | Core personality settings (list items)                              |
| 【状态】(State)                    | Optional    | Initial state variables (list items, type inference supported)      |
| 【世界观】(Worldview)              | Optional    | World background description (free text)                            |
| 【角色背景】(Character Background) | Optional    | Character's past experience / backstory (free text)                 |
| 【开局场景】(Opening Scene)        | Optional    | Narrative starting scene (free text)                                |
| 【历史】(History)                  | Optional    | Historical message snapshot (`fate` / `assistant` / `system` roles) |
| 【记忆】(Memory)                   | Optional    | Long-term memory entries (list items)                               |
| 【规则】(Rules)                    | Optional    | Behavior rules: `[Rule Name] if Condition -> Action`                |

### Constraints

- Section titles stand alone on a line, in the `【Name】` format
- The same section **cannot appear more than once** (duplication reports an error)
- Free-floating content outside any section reports an error
- Lines starting with `#` are comments

## 3. State Value Types

The 【状态】(State) list items use the `- key: value` format, with types inferred automatically:

| Written Form        | Type   | Example                   |
| ------------------- | ------ | ------------------------- |
| Integer             | int    | `- 灵魂完整度：100`       |
| Float               | double | `- 堕落指数：85.5`        |
| true/false          | bool   | `- 启用：true`            |
| Quoted string       | string | `- 情绪："暴怒"`          |
| Unquoted short text | string | `- 位置：书斋`            |
| Empty value         | string | `- 备注：` (empty string) |

> The separator supports both the Chinese colon `：` and the English colon `:`.

## 4. Rule Syntax

```text
[Rule Name] if Condition Expression -> Action Expression
```

### 4.1 Condition Expressions

| Condition             | Example                           | Meaning                                              |
| --------------------- | --------------------------------- | ---------------------------------------------------- |
| Contains text         | `包含 "黑暗"`                     | The input contains this text                         |
| Does not contain text | `不包含 "真实"`                   | The input does not contain this text                 |
| State comparison      | `状态.灵魂完整度 < 30`            | The state variable satisfies the comparison          |
| Dice roll             | `roll(1d100) >= 70`               | Anke-style dice roll (only 1d2 / 1d100)              |
| Logical combination   | `(包含 "a" \|\| 包含 "b") && ...` | Parenthesized grouping + `&&` and `\|\|` combination |

Comparison operators: `==` `!=` `<` `<=` `>` `>=` (no spaces allowed on either side).
Only two dice types are supported (other face counts and multiple dice report errors):

- `roll(1d2)`: binary judgment (yes/no, success/failure)
- `roll(1d100)`: high-precision fate judgment (1-100)

### 4.2 Action Expressions

| Action              | Example                       | Meaning                                   |
| ------------------- | ----------------------------- | ----------------------------------------- |
| Inject narrative    | `注入 "浮士德的灵魂接近枯竭"` | Injects text into the narrative flow      |
| State assignment    | `状态.位置 = "书斋"`          | Directly sets a state value               |
| Compound assignment | `状态.堕落指数 += 5`          | Numeric increment/decrement (`+=` / `-=`) |
| Compound action     | `注入 "a" && 状态.x += 10`    | Chain multiple actions with `&&`          |

### 4.3 Mutual Exclusion Groups

Mark an action with `[group:GroupName]` to make actions within the group mutually exclusive (only one executes per round):

```meph
[答话] if 包含 "船长" -> [group:答话] 注入 "谦逊地笑道"
[缄默] if 包含 "复仇" -> [group:答话] 注入 "沉默不语"
```

### 4.4 Execution Order (Two-Phase Model)

The rule engine executes in **two phases** within a single round:

1. **Phase 1: Passive rules execute in batch**—rules whose action type is "state modification / narrative injection"
   are evaluated one by one in file order; **when multiple match simultaneously, they all execute**
   (except in mutual exclusion groups, where only the first matching rule in the group executes)
2. **Phase 2: Active rules match exclusively**—rules whose action type is "LLM instruction / static text"
   are also evaluated in file order, but **only the first matching rule executes** (others are skipped even if they match)

- Within each phase, rules are evaluated in file appearance order (increasing line numbers)
- Mutual exclusion groups (`[group:GroupName]`) execute in condition-match order within their phase; once matched, the remaining actions in the group are skipped
- Whether an action is "passive" or "active" is determined by the action expression: actions starting with a `状态.` modification or `注入` are passive;
  the rest (such as `指令` text instructions handled by the LLM) are active

## 5. History and Memory

### History (【历史】section)

```meph
【历史】
- fate: 第一行\n第二行
- assistant：回应
- system: (extra narration: birds pass overhead)
```

- `fate:` fate (player) messages, `assistant:` narrative responses
- `system:` system messages (e.g. stage-mode "extra narration" overflow text); restored as system messages on load — never mistaken for character dialogue
- The `\n` escape is converted to a real newline

### Memory (【记忆】section)

```meph
【记忆】
- [5] 我是浮士德，与梅菲斯特立下赌约
- 浮士德正在书斋中
```

- Each memory can carry an optional **`[weight]` prefix** manually marking its importance (1-5 stars, default 3):
  `[5]` character-core memories are never compressed, `[4]` major events are likewise protected, low-weight memories may be compressed
- Old-format memories without a prefix are treated as 3 stars by default, fully backward-compatible
- See the [Memory System](memory-system.en.md) "Memory Importance" section for the full weight system

## 6. Common Errors

| Scenario                                    | Keyword in Error Message      |
| ------------------------------------------- | ----------------------------- |
| Free-floating content outside any section   | section                       |
| Duplicate section                           | duplicate                     |
| List item does not start with `-`           | list item                     |
| Rule missing `->`                           | action separator              |
| Comparison operator has a space (`> =`)     | comparison operator           |
| Compound assignment has a space (`+ =`)     | compound operator             |
| Invalid roll format / unmatched parentheses | dice expression / parentheses |
| Mutual exclusion group missing `]`          | group                         |
| Keyword has an internal space (`包 含`)     | keyword                       |

> The parser throws `MephParseError` with a specific reason; both the editor and tests can provide immediate feedback.
