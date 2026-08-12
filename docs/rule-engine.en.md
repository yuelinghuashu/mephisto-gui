# ⚙️ Rule Engine Deep Dive

> The rule engine is the "behavior dispatcher" of Mephisto's contracts: it reads the 【规则】(Rules) section,
> checks player input and current state in each narrative round, and executes the corresponding action when a condition matches, driving continuous state evolution.
>
> **中文版：[简体中文](rule-engine.md)**

## 1. Rule Lifecycle

```text
Player Input (Fate Guidance)
    ↓
Phase 1: Passive rules execute in batch (state modification / narrative injection)
    ↓
Phase 2: Active rules match exclusively (LLM instructions / static text → only the first match executes)
    ↓
State updated → Enter next narrative round
```

## 2. Rule Structure

```text
[Rule Name] if Condition Expression -> Action Expression
```

- **Rule Name**: inside `[xxx]`, used for mutual exclusion group membership and debugging reference
- **Condition**: the expression after `if`, returns a boolean
- **Action**: the expression after `->`, multiple actions can be chained with `&&`

## 3. Condition System

### 3.1 Contains / Does Not Contain

Matches player input text:

```meph
[黑夜] if 包含 "黑暗" -> 注入 "阴影在你身后生长"
[明朗] if 不包含 "黑暗" && 包含 "阳光" -> 注入 "阳光穿透尘埃"
```

### 3.2 State Comparison

Compares variables in the contract's 【状态】(State) section (supports int / double / string):

```meph
[濒死] if 状态.灵魂完整度 < 30 -> 注入 "浮士德的灵魂接近枯竭"
[振作] if 状态.灵魂完整度 >= 70 || 状态.情绪 == "满足" -> 注入 "意志重新燃起"
```

> Note: `==` is for string or numeric equality; `!=` is for inequality.
> No spaces are allowed on either side of an operator (`> =` will report an error).

### 3.3 Dice Rolls (roll)

Anke-style random judgment, determining whether an event occurs or the tendency of the outcome:

```meph
[天启] if roll(1d100) >= 80 -> 注入 "命运的齿轮轰然转动"
```

- Only two dice types are supported (other face counts and multiple dice report errors):
  - `roll(1d2)`: binary judgment (yes/no, success/failure)
  - `roll(1d100)`: high-precision fate judgment (1-100)
- Invalid forms report errors: `roll(1d6)` (unsupported face count), `roll (1d100)` (has a space), `roll(2d100)` (multiple dice), `roll(1dx)` (non-numeric), etc.

### 3.4 Condition Combination and Precedence

- `&&` (AND) has higher precedence than `||` (OR)
- Parentheses `(...)` can be used for explicit grouping:

```meph
[抉择] if (包含 "深渊" || 包含 "凝视") && roll(1d100) >= 60 -> 注入 "你听见了深渊的低语"
```

## 4. Action System

### 4.1 Inject Narrative

Inserts text into the current narrative flow as AI input context:

```meph
-> 注入 "契约的一角在阴影中卷起"
```

### 4.2 State Modification

- Simple assignment: `状态.位置 = "书斋"`
- Compound assignment: `状态.堕落指数 += 10` / `状态.灵魂完整度 -= 5` (numeric types only)

### 4.3 Compound Actions

Chain multiple actions with `&&`, executed in sequence:

```meph
[契约] if 包含 "契约" && roll(1d100) -> 注入 "契约生效" && 状态.灵魂完整度 += 10
```

## 5. Mutual Exclusion Groups

Actions of rules in the same group are **mutually exclusive**—once one is matched and executed in a round, the rest are skipped:

```meph
[答话] if 包含 "船长" -> [group:船长回应] 注入 "谦逊地笑道"
[缄默] if 包含 "复仇" -> [group:船长回应] 注入 "沉默不语"
```

- Group names are arbitrary, but rules in the same group must use the same `[group:GroupName]`
- Rules within a group are evaluated in file order; the first match executes

## 6. Two-Phase Execution Model

Whether a rule is "passive" or "active" is determined by its **action expression**:

| Category | Action Type                                | Execution                                                                           |
| -------- | ------------------------------------------ | ----------------------------------------------------------------------------------- |
| Passive  | Starts with `状态.` modification or `注入` | **Batch execution**: all matching rules execute simultaneously                      |
| Active   | Others (e.g., `指令` LLM instructions)     | **Exclusive matching**: only the first matching rule executes; the rest are skipped |

Within the same round, all passive rules execute first (Phase 1), then active rules execute (Phase 2).
Within each phase, rules are evaluated in file appearance order; mutual exclusion groups
(`[group:GroupName]`) execute in condition-match order within their phase, skipping the remaining actions in the group once matched.

> Example: if rules of both "narrative injection" and "LLM instruction" types match,
> the narrative injection executes, and only the first matching LLM instruction is used.

## 7. Practical Example (Built-in faust.meph)

```meph
【规则】
[灵魂危机] if 状态.灵魂完整度 < 30 -> 注入 "浮士德的灵魂接近枯竭"
[契约觉醒] if 包含 "契约" && roll(1d100) -> 状态.灵魂完整度 += 10
```

- "灵魂危机" (Soul Crisis): when soul integrity drops below 30, inject a warning narrative
- "契约觉醒" (Pact Awakening): when the player mentions "契约" and the dice roll succeeds, soul integrity +10

## 8. Related Code

| Module                                 | Description                                 |
| -------------------------------------- | ------------------------------------------- |
| `lib/services/engine/condition.dart`   | Condition expression parsing and evaluation |
| `lib/services/engine/dice.dart`        | Dice rolling                                |
| `lib/services/engine/executor.dart`    | Action execution                            |
| `lib/services/engine/rule_engine.dart` | Rule engine main entry                      |
| `lib/services/parser/meph_dsl.dart`    | Rule syntax parsing and validation          |

> 📖 **How do you write rules that are efficient, correct, and sustainable?** The syntax reference only answers "what is valid"; the practical methodology—seven-question checklist, seven anti-patterns, the scene-chain pattern, and the "Rules vs LLM" boundary—lives in the **[Rule Writing Guide](rule-writing-guide.en.md)**.
