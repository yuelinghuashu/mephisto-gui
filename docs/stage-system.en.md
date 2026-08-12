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
4. **The backend maps the text to mentioned characters** via "mention attribution"
5. **Fallback**: if the output can be neither sectioned nor attributed by mentions, it generates per-character independently to guarantee everyone gets a response

> Dice rolls (`roll(1d100)` etc.) are supported too: when triggered, they appear as a "Fate Verdict" system-message card.

## 💾 Save Mechanism

- **Independent saves**: each character saves to `stage/character.child.meph`
- **Restore**: entering a stage restores each character's save; "Restart" returns to the master opening
- **Deleting a character card** cascades deletion of its `.child.meph` save
- **Reset only progress**: "Delete Save" removes only `.child.meph`, keeping the master character card

## 📂 Built-in Stage Examples

| Stage                            | Characters                     | Scene                                                        |
| -------------------------------- | ------------------------------ | ------------------------------------------------------------ |
| `Camlann/` (The Fall of Camlann) | `Arthur.meph` × `Mordred.meph` | Arthur's final father-son battle with Mordred                |
| `Kurukshetra/` (Kurukshetra)     | `Arjuna.meph` × `Karna.meph`   | The duel of the two champions on the Mahabharata battlefield |

## ⚠️ Notes

- **Unique character names**: each character's 【角色名】 inside a stage should be distinct (mutual-exclusion groups, memory injection, and bubble coloring are all isolated by character name)
- **A broken card does not break the stage**: if one character card fails to parse, that character is skipped and the rest load normally
- **Saves never masquerade as characters**: `.child.meph` files are automatically filtered out and never appear as extra characters on the home page

> 🔗 Related docs: [Contract Syntax](contract-syntax.en.md) · [Rule Engine](rule-engine.en.md) · [Save System](save-system.en.md) · [Platform Storage](platform-storage.en.md)
