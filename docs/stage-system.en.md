# 🎭 Multi-Character Stage System

> A stage = a group of characters sharing the same narrative scene. You create multiple character cards, and they respond, clash, and fight side by side within a single fate.

## 🏗 Stage Directory Layout

A stage is organized exactly like single-character contracts — except multiple character cards are placed inside **one subdirectory**:

- **A stage = a one-level subdirectory under the contract root**, its folder name is the stage name (e.g. `Camlann/`)
- Contains **N flat `.meph` character cards** (e.g. `Arthur.meph` / `Mordred.meph`)
- Each character gets its own runtime save at `stage/character.child.meph` (generated automatically, no need to write it)
- **No deep nesting**: only flat character cards inside a stage directory, no subdirectories
  (to avoid confusion with the single-character child-version derivation based on `.` segmentation)

```text
contracts/
├── faust.meph          ← single-character contract (unaffected)
├── dantes.meph
└── Camlann/            ← stage = one-level subdirectory
    ├── Arthur.meph
    ├── Mordred.meph
    ├── Arthur.child.meph   ← auto-generated save (ignore it)
    └── Mordred.child.meph
```

## 🚀 How to Create a Stage

1. Create a new folder inside the contract directory (e.g. `my_stage/`)
2. Write each character as a `.meph` contract file and place it in that folder
3. Refresh the home page → the stage card appears automatically in the "Multi-Character Stages" section

> 💡 You can also use the "Import" feature on the home page to unzip a stage ZIP shared by others (the stage directory is restored as-is).

## 📜 Character Card Format

Character cards inside a stage **reuse the full contract syntax** (sections, state, rules, dice, memory — see [Contract Syntax Reference](contract-syntax.en.md)). Additional conventions:

- **Shared worldview**: the stage's 【世界观】 is taken from the **first character card** (the one that comes first in file-name dictionary order)
- Each character's 【锚点】【状态】【记忆】【规则】 runs **independently**, never mixed:
  - When Arthur's rule triggers a state change, Mordred's state is unaffected
  - Each character only sees their own memories, not others' past

## ⚙️ Narrative Mechanics

Each round of stage generation:

1. **Each character runs the rule engine independently** (state changes, memory injection, dice rolls are isolated per character)
2. **A single LLM call**: all characters share the same fate guidance
3. **Output is a "panoramic narrative stream"**: one flowing third-person novel that naturally mentions the characters who have screen time
   - Characters with screen time interact within the same passage (dialogue / action / clash)
   - Unmentioned characters = no screen time this round, not forced to appear
4. **Parsing & attribution**: the backend first tries to attribute each passage to a character via `【角色名】` section format (compatible with older model outputs); if the LLM does not use sections (panoramic narrative stream), it falls back to "mention attribution"—mapping the whole text to the characters mentioned
5. **Fallback**: if the output can be neither sectioned nor attributed by mentions, it generates per-character independently to guarantee everyone gets a response

> Dice rolls (`roll(1d100)` etc.) are supported too: when triggered, they appear as a "Fate Verdict" system-message card.

## 💾 Save Mechanism

- **Independent saves**: each character saves to `stage/character.child.meph`
- **Restore**: entering a stage restores each character's save; "Restart" returns to the master opening
- **Deleting a character card** cascades deletion of its `.child.meph` save
- **Reset only progress**: "Delete Save" removes only `.child.meph`, keeping the master character card

## 📂 Built-in Stage Examples

| Stage                            | Characters                                         | Scene                                                                                                  |
| -------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `Camlann/` (The Fall of Camlann) | `Arthur.meph` × `Mordred.meph`                     | Arthur's final father-son battle with Mordred                                                          |
| `Kurukshetra/` (Kurukshetra)     | `Arjuna.meph` × `Karna.meph`                       | The duel of the two champions on the Mahabharata battlefield                                           |
| `Lundao/` (Three Teachings)      | `Kongzi.meph` × `Laozhi.meph` × `Shijiamouni.meph` | A dream debate on Mount Song — Confucius, Laozi, and the Buddha argue over "wisdom"; one side prevails |

## ⚠️ Notes

- **Unique character names**: each character's 【角色名】 inside a stage should be distinct (mutual-exclusion groups, memory injection, and bubble coloring are all isolated by character name)
- **A broken card does not break the stage**: if one character card fails to parse, that character is skipped and the rest load normally
- **Saves never masquerade as characters**: `.child.meph` files are automatically filtered out and never appear as extra characters on the home page

## 🎭 Stage Rule Design Guide (Lessons from the Trenches)

Stage rules differ **fundamentally** from single-character contracts—each round, **all characters share the same player input and each runs its own rule engine independently**. This imposes two hard constraints on rule design. Violating them produces counter-intuitive results (all issues below were reproduced and fixed during the `Lundao/` (Three Teachings) stage's development):

### 1. Don't write "counter" rules (e.g. `[克道] if 包含 "道法自然"`)

**Wrong intuition**: "The player quoted Laozi's words, so I (Confucius) should rebut them—write a rule that gives Confucius points when the player mentions '道法自然'."

**Actual result**: The engine cannot tell whether the player is _quoting_ Laozi or _helping_ Confucius rebut him—any input containing "道法自然" triggers the counter rules of **all three characters**. Measured:

- Player inputs "无为而无不为" (trying to side with Laozi) → Laozi himself gains **+0** (missing trigger word), Confucius/Shakyamuni each gain **+4**
- Player inputs "仁者爱人" (trying to side with Confucianism) → Laozi's "counter-Confucius" +4 outpaces Confucius's own +3
- The three-way ending is broken: after 5 rounds of siding with Confucius, **all three ending conditions are met simultaneously**

**Correct approach**: each character should only write **self-gain rules** (trigger words bound to their own canon), making "which school the player sides with → that school rises" the sole driver. For cross-school exchanges, use **named-response rules**—the condition must include the other character's name (e.g. `包含 "老子" && 包含 "道"`), and it should **only add the home dimension, never bias** (responding to others should not advance one's own victory):

```meph
# Confucius's card: player names Laozi and discusses Dao → Confucius responds (only adds 仁德, no bias)
[应答老子] if 包含 "老子" && (包含 "道" || 包含 "自然" || 包含 "无为") -> 状态.仁德 += 2
```

### 2. Narrow generic words to phrases / proper terms

Lone generic characters are matched by **all** characters' rules under shared input. Measured: a Buddhist rule `[缘起性空] if 包含 "空"` fires on "仰望天空" (gazing at the sky), "空白" (blank), "空间" (space)—"空" is a high-frequency Chinese character. **Use full phrases or school-specific terms for home trigger words** (e.g. `缘起` / `般若` / `性空`) to keep unrelated inputs like "sky" out.

### 3. Ending rules must fire exactly once

An ending-injection rule (condition met → inject the ending text) will **re-inject the same ending every round** while its condition keeps being met. Measured: Faust's ending kept re-injecting for 20 rounds after it fired. Two lock patterns:

- **State flag**: set a flag when the ending fires, and guard the rule with `状态.归途 == "未决"` (`dantes.meph`'s `[天平方正]` / `[宽恕彼岸]`—also makes two endings mutually exclusive)
- **State/location migration**: the ending action itself changes the state the condition depends on (`gilgamesh.meph`'s `[归来]` moves the location back to Uruk; `faust.meph`'s `[灵魂归主]` sets the mood to "ending")—the condition stops being met, naturally one-shot

### 4. Set soft caps / floors on values

Under shared input, a player persistently siding with one school plus uncapped accumulation distorts values (measured: dantes hatred grew to 250, joan morale to 325, gilgamesh sorrow went negative). Add `状态.xxx < 上限` guards to growth rules and `> 下限` to decay rules (soft caps allow a single increment to slightly overshoot but forbid unbounded accumulation).

> 💡 These complement the [Rule Writing Guide](rule-writing-guide.en.md)'s "nine anti-patterns": anti-pattern 9 covers negation/context gating in single-character contracts; this section covers the stage-specific (multi-character shared-input) constraints. The Three Teachings stage (`Lundao/`) is a complete worked example of all three points.

> 🔗 Related docs: [Contract Syntax](contract-syntax.en.md) · [Rule Engine](rule-engine.en.md) · [Save System](save-system.en.md) · [Platform Storage](platform-storage.en.md)
