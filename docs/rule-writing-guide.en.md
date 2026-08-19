# 📖 Rule Writing Guide: A Practical Methodology for Efficient Contracts

> [Rule Engine Deep Dive](rule-engine.en.md) answers "what is syntactically **valid**"; this guide answers "**what is efficient, correct, and sustainable**".
> The anti-patterns below come from real fixes to built-in contracts—they are not theory, but pits players actually stepped into.

## 1. Before You Write: Nine-Question Design Checklist

Run through these nine questions before writing a rule:

| #   | Question                                                                                                                                       | What happens if you skip it                                                             |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| 1   | **In what scene will this rule trigger?** Does it make sense detached from the player's current location / state?                              | Cross-scene misfire (Anti-pattern 1)                                                    |
| 2   | **Does the condition use a "negative blacklist" to infer semantics?**                                                                          | Cannot enumerate all cases (Anti-pattern 2)                                             |
| 3   | **Can the state value this rule depends on be reached from the initial state?** Is there a rule producing it?                                  | Broken state chain, rule never fires (Anti-pattern 3)                                   |
| 4   | **Is this a passive rule? Is its condition only numeric thresholds?**                                                                          | Automatic punishment loop every round (Anti-pattern 4)                                  |
| 5   | **Are ending-rule conditions too harsh?** Do stacked hard keywords make triggering nearly impossible?                                          | Ending never reachable (Anti-pattern 5)                                                 |
| 6   | **Does each mutual-exclusion group have an opposite rule?** Does a single-member group still make sense?                                       | Mutual exclusion becomes meaningless (Anti-pattern 6)                                   |
| 7   | **Should the text this rule outputs be the same every time, or vary with the narrative flow?** If it should vary, should the LLM improvise it? | Repetitive narrative, character sounds like a broken record (Anti-pattern 7)            |
| 8   | **Is the LLM instruction's trigger condition too broad?** Does a character name / generic word alone trigger active output?                    | High-frequency false triggers crowding out other active narrative (Anti-pattern 8)      |
| 9   | **Can the trigger word be falsely fired by negations / ambiguous contexts?** Does it use unconditional state rebound?                          | Negation kills, one keyword deciding both directions, oscillation loop (Anti-pattern 9) |

---

## 2. Nine Anti-Patterns and Their Fixes

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

| Player input                          | Triggers regret | Reasonableness                                 |
| ------------------------------------- | --------------- | ---------------------------------------------- |
| "I got angry at an innocent civilian" | ✅              | Harming the weak → regret                      |
| "I'll teach that thief a lesson"      | ❌              | Punishing a wrongdoer is righteous → no regret |

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

**Wrong** (before the Faust contract fix): the ending requires the player to say **both** "停留"(stay) and "够了"(enough) at once, plus a soul-integrity threshold:

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

| Nature of text                                                                                                   | Use                           |
| ---------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| This text should be **identical every time** (contract terms, key lines, facts that must be anchored)            | `注入`                        |
| This text should **vary with context / prior events / character state** (dialogue, literary action descriptions) | LLM instruction (active rule) |

---

### Anti-pattern 8: Overly broad trigger conditions on LLM instructions → high-frequency false triggers

**Wrong** (before the `faust.imperial.meph` / `Kurukshetra` fixes): using a **single character name** or a **high-frequency generic word** as the trigger condition for an LLM instruction:

```meph
[梅菲斯特耳语] if 包含 "梅菲斯特" || 包含 "弄臣" -> 梅菲斯特以弄臣的谄媚口吻靠近{角色名}，用权力、金钱与美人的言辞诱惑他沉溺于这场宫廷大戏
```

**Problem**: Mephistopheles is a core character constantly present in the imperial court drama—whether the player questions him, tests him, or merely mentions him, the same "approaches flatteringly and tempts" line forcibly interrupts. Worse, active rules (LLM instructions) use **mutual-exclusion matching**: only the first matched rule runs per round. A high-frequency rule crowds out other active narrative space, pushing the script back to the same action repeatedly. `Kurukshetra/Karna.meph`'s `[敬敌]` (`包含 "阿周那"`—the opposing commander's name; discussing tactics triggers it) and `[黄金甲]` (`包含 "铠甲"`—a battlefield generic word; talking about enemy armor also triggers it) are the same class of problem: context-detached fixed emotional output firing over and over.

**Fix**: add **context-word gating** to LLM instruction conditions—trigger only when the player explicitly expresses the corresponding intent:

```meph
# Character name / item name + context words gate together
[梅菲斯特耳语] if (包含 "梅菲斯特" || 包含 "弄臣") && (包含 "低语" || 包含 "耳语" || 包含 "引诱" || 包含 "蛊惑") -> 梅菲斯特以弄臣的谄媚姿态靠近{角色名}，用权力、金钱与美人的言辞诱惑他
[敬敌] if 包含 "阿周那" && (包含 "敬" || 包含 "憾" || 包含 "兄弟" || 包含 "可惜") -> {角色名}流露出对阿周那的复杂敬意
[黄金甲] if 包含 "黄金甲" -> {角色名}提及已献给因陀罗的黄金甲，但笃定太阳的庇护从未离开
```

> 💡 **LLM instruction trigger conditions should align with player intent**. Character names / high-frequency words only carry "character presence"; they should not trigger LLM active output alone. Active output should be gated by "character name / special item name + an explicit interactive context word. If you only need in-scene presence, use a passive `注入` description instead of an LLM instruction.

---

### Anti-pattern 9: Single-keyword trigger with no negation/context gating → false triggers from negations and ambiguous words

**Wrong** (real examples from before the built-in templates were fixed): a single **generic word** as the trigger, with neither negation handling nor context distinction:

```meph
[临终] if 包含 "倒下" -> 状态.生命 = 0
[心魔] if 包含 "原谅" -> 状态.怨毒 -= 15
[蛇之窃] if 包含 "仙草" && roll(1d100) >= 70 -> 状态.求索 -= 30
[灵魂维系] if 状态.灵魂完整度 <= 25 -> 状态.灵魂完整度 = 30
```

**Problems** (all reproduced by template tests):

1. **Negation kills the player**: `包含 "倒下"` matches "I will **never** fall" / "**Don't** fall"—the player declares they won't fall, yet the rule zeroes their HP. Similarly `包含 "原谅"` makes "I will **never** forgive my father" _reduce_ the grudge.
2. **Ambiguous word without context**: `包含 "仙草"` cannot distinguish "I **found** the herb" (a gain) from "the herb was **stolen**" (a loss)—the same keyword triggers `[永生]` (+5) and probabilistically `[蛇之窃]` (-30), punishing the player for doing the right thing.
3. **Unconditional state rebound**: `状态.灵魂完整度 <= 25 -> = 30` is a **pure-threshold rule** (see Anti-pattern 4) that ignores the player's input—once spirit drops below 25, any utterance snaps it back to 30, forming a 25↔30 oscillation loop where the player can never truly fall into the abyss.

**Fix**:

```meph
# 1. Negation guard: state gate + exclude negators
#    HP ≤30 and explicitly falling (no "不会") zeroes it—saying "I won't fall" at full HP is safe
[临终] if 状态.生命 <= 30 && 不包含 "不会" && (包含 "倒下" || 包含 "重伤" || 包含 "临终") -> 状态.生命 = 0

# 2. Compound phrases demand affirmative intent: require the full utterance, not a lone word
#    "I would never forgive" does not contain "我愿意原谅" → no fire; "我愿意原谅" reduces the grudge
[心魔] if 状态.怨毒 >= 20 && (包含 "我愿意原谅" || 包含 "放下仇恨" || 包含 "试着原谅") -> 状态.怨毒 -= 15

# 3. Context words separate gain from loss: never let one keyword decide both directions
[蛇之窃] if 状态.位置 == "世界尽头" && (包含 "被窃" || 包含 "被偷" || 包含 "偷走" || 包含 "丢了") && roll(1d100) >= 70 -> 状态.求索 -= 30

# 4. Context-triggered instead of unconditional rebound: ordinary dialogue no longer forces state changes
[灵魂维系] if 状态.灵魂完整度 <= 25 && (包含 "濒死" || 包含 "崩溃" || 包含 "消散" || 包含 "撑不住") -> 状态.灵魂完整度 = 30
```

**💡 Three writing rules**:

| Rule                                                                           | Example                                                                             |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| **Guard negations**: add `不包含 "不会" / "绝不"`                              | `包含 "倒下" && 不包含 "不会"`                                                      |
| **Disambiguate**: use full intent phrases, not lone words                      | `包含 "我愿意原谅"` over `包含 "原谅"`                                              |
| **Never one keyword, two directions**: split gain/loss events by context words | "found the herb" → `[永生]`; "herb stolen" → `[蛇之窃]`                             |
| **Never unconditional**: state-rebound rules must bind context words           | `灵魂完整度 <= 25` alone = unconditional; add `&& 包含 "濒死"` for a real condition |

> 💡 **Why `不包含 "不会"` isn't enough**: it stops "I won't fall," but Chinese has "绝不 / 休想 / 岂能 / 未曾" and more—blacklists can never be exhaustive. **The more reliable approach is positive gating**: use complete phrases the player must actively utter ("我愿意原谅", "我撑不住了") as conditions—they naturally exclude negation and match real expressions more closely.

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

| Concern                                                                                       | Rules or LLM                                     | Reason                                                                                         |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| State numeric changes (health / faith / morale)                                               | **Rules**                                        | Must be precise, perceivable by the player, forming a feedback loop                            |
| Dice judgments (success/failure, probability events)                                          | **Rules**                                        | Engine provides structured `roll(1d100)` result and a Fate Settlement card                     |
| **Trigger conditions** for narrative turns (when to enter the ending / when to shift mindset) | **Rules**                                        | Needs determinism; prevents "fate" from being arbitrarily decided by the LLM                   |
| Character dialogue, action description, emotional expression                                  | **LLM**                                          | Needs creativity and literary quality; rules cannot enumerate                                  |
| **Semantic understanding** of player context ("punishing a thief" vs "harming the innocent")  | **LLM-first + rules capturing explicit signals** | LLM understands context; rules only capture the semantic keywords the player explicitly states |

**The fix for Anti-pattern 2 embodies this boundary**: when to regret and when not is, at heart, semantic understanding—delegated to LLM narrative; rules only capture unmistakable regret signals the player explicitly states. **Rules should not infer on behalf of the LLM; they should only confirm explicit facts.**

**Anti-pattern 9 embodies this boundary on the "condition matching" dimension**: negations and ambiguous contexts ("I will never fall" vs "I can't hold on, I'm falling"; "found the herb" vs "the herb was stolen") are likewise semantic understanding—a rule's trigger should only capture the player's **explicitly expressed affirmative signal** (a complete intent phrase), handing the "does this sentence really mean that?" judgment back to LLM narrative. Rules confirm facts; they do not read minds.

**Anti-pattern 7 embodies this boundary on the "action output" dimension**: state numbers and trigger conditions use rules for determinism, while character dialogue and literary description belong to creation—describe the intent with an LLM instruction and hand the wording back to the LLM.

---

## 5. Stage Mode: Extra Constraints Under Shared Input

Single-character contracts only respond to "the player interacting with this one character"; but in a **multi-character stage, all characters share the same player input and each runs its own rule engine independently**—which makes Anti-pattern 9's context gating even more critical in stages, and introduces two constraints that don't exist in single-character contracts:

1. **Don't write cross-school "counter" rules** (e.g. `[克道] if 包含 "道法自然"`): when the player quotes Laozi, the counter rules of Confucius/Laozi/Shakyamuni **all fire**, breaking player alignment and the three-way ending. Instead use **self-gain rules + named-response rules** (condition includes the other character's name, and only adds the home dimension, never bias).
2. **Generic words get matched by all characters simultaneously**: lone generic characters (e.g. "空", "自然") misfire more easily under shared input than in single-character contracts—narrow home trigger words to full phrases / proper terms.

3. **Ending rules must fire exactly once**: while the condition stays met, the same ending re-injects every round—use a state flag (`状态.归途 == "未决"`) or a state/location migration lock.
4. **Set soft caps / floors on values**: persistent alignment with one school plus uncapped accumulation distorts values.

> 📖 Full details, the reproduction record, and the `Lundao/` (Three Teachings) worked example: **[Stage System doc](stage-system.en.md) → "Stage Rule Design Guide"**.
