# 📖 Rule Writing Guide: A Practical Methodology for Efficient Contracts

> [Rule Engine Deep Dive](rule-engine.en.md) answers "what is syntactically **valid**"; this guide answers "**what is efficient, correct, and sustainable**".
> The anti-patterns below come from real fixes to built-in contracts—they are not theory, but pits players actually stepped into.

## 1. Before You Write: Seven-Question Design Checklist

Run through these seven questions before writing a rule:

| # | Question | What happens if you skip it |
|---|----------|----------------------------|
| 1 | **In what scene will this rule trigger?** Does it make sense detached from the player's current location / state? | Cross-scene misfire (Anti-pattern 1) |
| 2 | **Does the condition use a "negative blacklist" to infer semantics?** | Cannot enumerate all cases (Anti-pattern 2) |
| 3 | **Can the state value this rule depends on be reached from the initial state?** Is there a rule producing it? | Broken state chain, rule never fires (Anti-pattern 3) |
| 4 | **Is this a passive rule? Is its condition only numeric thresholds?** | Automatic punishment loop every round (Anti-pattern 4) |
| 5 | **Are ending-rule conditions too harsh?** Do stacked hard keywords make triggering nearly impossible? | Ending never reachable (Anti-pattern 5) |
| 6 | **Does each mutual-exclusion group have an opposite rule?** Does a single-member group still make sense? | Mutual exclusion becomes meaningless (Anti-pattern 6) |
| 7 | **Should the text this rule outputs be the same every time, or vary with the narrative flow?** If it should vary, should the LLM improvise it? | Repetitive narrative, character sounds like a broken record (Anti-pattern 7) |

---

## 2. Seven Anti-Patterns and Their Fixes

### Anti-pattern 1: Rule not bound to scene state → cross-scene misfire

**Wrong** (before the `joan_of_arc.meph` fix): the opening is in Chinon castle (court), yet battle rules have no location constraint—saying "冲锋"(charge) or "受伤"(injured) in the court triggers battle rules:

```meph
[负伤] if 包含 "受伤" || 包含 "中箭" || 包含 "流血" -> 状态.生命 -= 10
```

**Problem**: There is no battle in the court; "injured / hit by arrow" is battlefield context. Without location binding, health drops out of nowhere in the court.

**Fix**: Add `状态.位置 != "希农"` constraint to battle rules, and add a scene-transition rule to connect "court → battlefield":

```meph
[出征] if 状态.位置 == "希农" && (包含 "出征" || 包含 "出发") -> 状态.位置 = "奥尔良"
[负伤] if 状态.位置 != "希农" && (包含 "受伤" || 包含 "中箭") -> 状态.生命 -= 10
```

> 💡 **Location is the "coordinate" of the narrative scene**. Any rule describing "something happening in a place" should consider binding to location.

---

### Anti-pattern 2: Using a "negative blacklist" to infer semantics → cannot enumerate

**Wrong** (before the `arthur_sword.meph` fix): inferring "this anger deserves regret" by excluding enemies:

```meph
[王的怒火] if 包含 "愤怒" && 不包含 "敌人" && 不包含 "撒克逊" && ... -> 状态.悔意 += 10
```

**Problem**: It implies "anger at non-enemies = wrong". Arthur getting angry at and striking **thieves, bullies, or corrupt officials** is righteous, not regrettable. A blacklist can never enumerate every "anger that need not be regretted".

**Fix**: Use **positive semantics** to capture the true trigger of regret—the player explicitly expresses harming someone who should not be harmed (the innocent / the weak):

```meph
[王的怒火] if (包含 "愤怒" || 包含 "冲动") && (包含 "无辜" || 包含 "平民" || 包含 "弱者" || 包含 "过当") -> 状态.悔意 += 10
```

| Player input | Triggers regret | Reasonableness |
|--------------|-----------------|----------------|
| "I got angry at an innocent civilian" | ✅ | Harming the weak → regret |
| "I'll teach that thief a lesson" | ❌ | Punishing a wrongdoer is righteous → no regret |

> 💡 **When a positive keyword can describe the semantics, never use `不包含` for negative inference**. `不包含` is only for "these specific cases do not happen," not for "the semantics is the complement of...".

---

### Anti-pattern 3: Broken state chain → rule never fires (consumed without a source)

**Wrong** (before the `arthur_sword.meph` fix): state `悔意` starts at 0, no rule ever increases it, yet a rule requires `悔意 >= 20`:

```meph
【状态】
- 悔意： 0

【规则】
[忏悔] if 状态.悔意 >= 20 && ... -> 状态.悔意 = 0
```

**Problem**: `悔意` is forever 0, so `[忏悔]`'s `>= 20` is never true—the whole "anger → resentment → reflection → release" loop is dead, and hard to spot (syntax is valid, parsing reports no error).

**Fix**: First add a source rule for regret, then let the consuming rule depend on it:

```meph
[王的怒火] if ... -> 状态.悔意 += 10
[忏悔] if 状态.悔意 >= 20 && (包含 "自责" || 包含 "忏悔") -> 状态.悔意 = 0 && 状态.信心 -= 5
```

> 💡 **Check the state chain**: for every rule that consumes a state, trace back whether a rule produces it or it has an initial value. Broken chains are silent—the parser won't complain, but the rule never fires.

---

### Anti-pattern 4: Pure-threshold passive rule → auto-triggers every round, forming a punishment loop

**Wrong** (a slip during the `Camlann/Arthur.meph` fix): changing the condition from "threshold + keyword" to pure threshold:

```meph
[旧伤] if 状态.伤疤 >= 10 -> 状态.王权威严 -= 5
```

**Problem**: Passive rules (`状态.` modification) **evaluate every round**. As long as `伤疤 >= 10`, authority drops every round no matter what the player says—and no rule clears scars, so the deduction continues infinitely until the value bottoms out.

**Fix**: Keep a `包含` keyword as an **active gate**, so it only triggers when the player mentions the old wound:

```meph
[旧伤] if 状态.伤疤 >= 10 && 包含 "旧伤" -> 状态.王权威严 -= 5
```

> 💡 **Passive rule + pure numeric threshold = an automatic punishment factory**. For any passive rule (action starting with `状态.` or `注入`), keep at least one `包含` / `不包含` keyword or a dice roll in the condition, so triggering depends on the player's behavior—not "fires automatically when the number arrives and loops forever."

---

### Anti-pattern 5: Too many hard constraints on an ending rule → nearly unreachable

**Wrong** (before the `faust.utopia.meph` fix): the ending requires the player to say **both** "停留"(stay) and "够了"(enough) at once, plus a soul-integrity threshold:

```meph
[说出停留] if 包含 "停留" && 状态.灵魂完整度 >= 80 && 包含 "够了" -> ...
```

**Problem**: "够了" is a word players rarely use in natural dialogue. Stacking multiple hard keywords makes the ending almost impossible to reach in practice—players never arrive at the canonical conclusion.

**Fix**: Keep only **one** semantic keyword + a state threshold:

```meph
[说出停留] if 包含 "停留" && 状态.灵魂完整度 >= 80 -> ...
```

> 💡 **The fewer hard constraints an ending rule has, the better**. The process of accumulating the numeric threshold is itself the "pre-requisite difficulty"; the keyword merely recognizes the player's intentional action.

---

### Anti-pattern 6: One-sided mutual-exclusion group → exclusion semantics become meaningless

**Wrong** (before the `faust` / `gilgamesh` fixes): a mutual-exclusion group with only one rule:

```meph
[暗影缠身] if ... -> [group:侵蚀] 状态.灵魂完整度 -= 5
[抗争] if ... -> [group:命运] 状态.求索 += 10
```

**Problem**: Mutual exclusion means "**if A matches, B is skipped**". With only one rule in the group, there is no counterpart to exclude—the group tag is a decoration.

**Fix**: Add a semantic opposite to each group:

```meph
# faust: darkness erodes ↔ light recovers
[暗影缠身] if 包含 "黑暗" -> [group:侵蚀] 状态.灵魂完整度 -= 5
[烛火映心] if 包含 "光明" -> [group:侵蚀] 状态.灵魂完整度 += 5

# gilgamesh: defy fate ↔ submit to fate
[抗争] if 包含 "挑战" && 包含 "命运" -> [group:命运] 状态.求索 += 10
[臣服] if 包含 "认命" || 包含 "放弃" -> [group:命运] 状态.求索 -= 20
```

> 💡 **A mutual-exclusion group = a "behavior choice"**. Every group should correspond to a clear either-or (or choose-one-of-N) narrative node: fight or surrender, anger or regret, defy or submit.

---

### Anti-pattern 7: LLM-instruction action with hardcoded text → repetitive narrative, amnesia

**Wrong**: using `注入` to write a character's dialogue/reaction as a fixed line:

```meph
[梅菲斯特低语] if 包含 "低语" -> 注入 "梅菲斯特冷笑着靠近，低声说：『与我作一场交易如何？』"
```

**Problem**: Every trigger fires the same sentence, ignoring the narrative flow already established—by the third time the player hears it, the character sounds like a broken record, and the line may contradict earlier plot (amnesia). Character dialogue is **creative output** and should vary with context, prior events, and the character's current state.

**Fix** (exemplified by `Kurukshetra/Arjuna.meph`): use an **active rule (LLM instruction)** describing "who speaks, what intent, what style/boundaries"—the exact wording is improvised by the LLM against the current narrative flow:

```meph
[黑天低语] if 包含 "黑天" || 包含 "奎师那" -> 黑天开口，以神的视角敦促{角色名}记起自己为何而战——但不可以简单说服他，要让他自己认清法与不忍的界限
```

Note the action does **not** start with `注入 "..."` or `状态.xxx`—it is an instruction description that gets injected into the LLM input as a directive.

**💡 Judgment criteria**:

| Nature of text | Use |
|----------------|-----|
| This text should be **identical every time** (contract terms, key lines, facts that must be anchored) | `注入` |
| This text should **vary with context / prior events / character state** (dialogue, literary action descriptions) | LLM instruction (active rule) |

---

## 3. Scene-Chain Pattern: Organizing Multi-Stage Narrative with a Location State Machine

The advanced use of location binding (see Anti-pattern 1) is treating location as the "cursor" of a scene chain, organizing a complete arc from "depart → journey → arrive → return".

Using the three-act structure of `gilgamesh.meph` as an example:

```text
Uruk (opening) ──[启程(depart)]──▶ Wilderness ──[抵尽头(reach the edge)]──▶ End of the World ──[归来(return)]──▶ Uruk (ending)
```

```meph
# Scene transitions (changing location = advancing the scene)
[启程] if 状态.位置 == "乌鲁克" && (包含 "出发" || 包含 "启程") -> 状态.位置 = "荒野" && 状态.求索 += 10
[抵尽头] if 状态.位置 == "荒野" && (包含 "尽头" || 包含 "海边") -> 状态.位置 = "世界尽头" && 状态.求索 += 15

# Journey encounters (only after leaving Uruk)
[狮战] if 状态.位置 != "乌鲁克" && (包含 "狮子" || 包含 "猛兽") -> 状态.王权 += 5

# Ending (must be at the end of the world with quest fulfilled)
[归来] if 状态.位置 == "世界尽头" && 状态.求索 >= 100 && (包含 "回家" || 包含 "归来") -> 状态.位置 = "乌鲁克" && 状态.王权 += 15
```

**Design points**:

1. **Let only scene-transition rules change location**—ordinary rules changing location will disorder the chain
2. **Constraint each stage's rules with `位置 == current scene` or `位置 != initial scene`**—lock rules into their chapter
3. **Bind ending rules to "endpoint location + threshold"**—ensures the player completes the journey while allowing keyword-initiated closure

---

## 4. The Division of Labor Between Rules and the LLM

The rule engine is **deterministic**; the LLM is **creative**. The key to writing an efficient contract is clarifying the boundary—**use rules for what must be certain, leave creation to the LLM**.

| Concern | Rules or LLM | Reason |
|---------|--------------|--------|
| State numeric changes (health / faith / morale) | **Rules** | Must be precise, perceivable by the player, forming a feedback loop |
| Dice judgments (success/failure, probability events) | **Rules** | Engine provides structured `roll(1d100)` result and a Fate Settlement card |
| **Trigger conditions** for narrative turns (when to enter the ending / when to shift mindset) | **Rules** | Needs determinism; prevents "fate" from being arbitrarily decided by the LLM |
| Character dialogue, action description, emotional expression | **LLM** | Needs creativity and literary quality; rules cannot enumerate |
| **Semantic understanding** of player context ("punishing a thief" vs "harming the innocent") | **LLM-first + rules capturing explicit signals** | LLM understands context; rules only capture the semantic keywords the player explicitly states |

**The fix for Anti-pattern 2 embodies this boundary**: when to regret and when not is, at heart, semantic understanding—delegated to LLM narrative; rules only capture unmistakable regret signals the player explicitly states. **Rules should not infer on behalf of the LLM; they should only confirm explicit facts.**

**Anti-pattern 7 embodies this boundary on the "action output" dimension**: state numbers and trigger conditions use rules for determinism, while character dialogue and literary description belong to creation—describe the intent with an LLM instruction and hand the wording back to the LLM.