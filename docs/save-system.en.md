# 💾 Save System (Child Version Mechanism)

> Mephisto uses a "read-only master + child snapshot" save model: the master contract is a fixed "soul framework,"
> and each session's dialogue, state changes, memories, and history are saved as **child version files**—independent snapshots.

> **中文版：[简体中文](save-system.md)**

## 1. Core Concepts

| Concept    | Description                                                                                                                |
| ---------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Master** | The creator-defined `.meph` contract (e.g., `faust.meph`), **never modified**                                              |
| **Child**  | A complete snapshot generated at runtime (e.g., `faust.child.meph`), containing all master data + state + memory + history |
| **Branch** | A user-custom-named child (e.g., `faust.dark.meph`), expressing a different fate path                                      |

## 2. Composition of a Child

Child = all master data + runtime state changes + memory + history

Three runtime data blocks are injected during serialization:

1. **【状态】(State)**: state values after runtime changes (e.g., soul integrity dropping from 100 to 60)
2. **【记忆】(Memory)**: long-term memories extracted by MemoryManager
3. **【历史】(History)**: the complete dialogue history of this session (fate / assistant)

## 2.1 Fate Description (One-Line Branch Title)

When choosing **Save as Branch**, you may write a **fate description** summarizing where this branch leads.
It is written into the child file as an **independent system section `@命运`**, placed at the **very top**
of the file (as a facade section, visible immediately upon opening):

```meph
@命运
理想国支线：浮士德在边际海岸望向乌托邦

【角色名】
浮士德
```

The `@` prefix marks **system-generated metadata**, naturally distinct from user-written `【】` narrative
sections—the 【角色背景】(Background) section stays clean with no markers. When expanding the master
on the home page, each child shows:

- **Primary label**: the fate description (e.g., "Utopia branch: Faust looks toward the ideal land on the edge of the sea")
- **Secondary label**: the branch name (e.g., `utopia`, preserving the original naming)
- Bottom-right: the save file name

Branches without a fate description fall back to showing the branch name (same behavior as before).
Masters do not show a fate description (only the character name).

## 3. Naming Rules and the Multi-Level Branch Tree

### 3.1 Default "Save": Overwrite the Current Branch (No Increment)

`Save` (`ChildSaveStore.saveCurrent`) always **overwrites the current branch's default save**, never incrementing
the number, so the number of saves does not balloon. The naming rule is "current branch path + `.child`":

| Current File                                | Default Save File                        |
| ------------------------------------------- | ---------------------------------------- |
| Master `faust.meph`                         | overwrites `faust.child.meph`            |
| Branch `faust.dark.meph`                    | overwrites `faust.dark.child.meph`       |
| Second-level branch `faust.dark.light.meph` | overwrites `faust.dark.light.child.meph` |
| Opened save itself `faust.dark.child.meph`  | overwrites itself                        |

### 3.2 Save as Branch: Multi-Level Inheritance

`Save as Branch` (`ChildSaveStore.saveAsBranch`) uses the **current branch path** as the naming root +
a custom branch name to create a new file, supporting multi-level branch trees derived from existing branches:

| Scenario                                                       | New Branch File                           |
| -------------------------------------------------------------- | ----------------------------------------- |
| Master `faust.meph` → save as `dark`                           | `faust.dark.meph`                         |
| Branch `faust.dark.meph` → save as `light`                     | `faust.dark.light.meph`                   |
| Second-level branch `faust.dark.light.meph` → save as `utopia` | `faust.dark.light.utopia.meph`            |
| Save `faust.dark.child.meph` → save as `light`                 | `faust.dark.light.meph` (inherits `dark`) |

> The legacy scenario (directly calling the low-level `save`) still retains incrementing behavior:
> default `.child` already exists → `child2`; custom branch already exists → `branch2`.

### 3.3 General Rules

- Children are stored in the **same contract directory** as the master, for easy lookup and management
- Name collisions are avoided automatically via incrementing numbers (legacy low-level `save` scenario only)

## 4. Common Operations

| Operation | Description                                                                    | Implementation                  |
| --------- | ------------------------------------------------------------------------------ | ------------------------------- |
| Save      | Generate/overwrite a child file (supports branch name or default `.child`)     | `ChildSaveStore.save`           |
| Restore   | Read and parse a child into a Contract (returns null on failure)               | `ChildSaveStore.restore`        |
| List      | List all children of a master (`baseName.*.meph`, excluding the master itself) | `ChildSaveStore.listChildFiles` |
| Delete    | Delete a single child file                                                     | `ChildSaveStore.delete`         |
| Check     | Check whether a child file exists                                              | `ChildSaveStore.exists`         |

## 5. Children in the Home Screen UI

- A master card can expand to show all its children, using a "Tree of Fate" visual: the master is the root, and children grow as branches along a golden trunk
- Children support: enter narrative (restore), preview, rename, delete
- Master deletion supports "cascade delete": deletes all its children in one go

## 6. Rename Synchronization

When a master is renamed, the file name prefixes of all its children are synchronized:

```text
faust.meph → 歌德.meph
faust.child.meph → 歌德.child.meph   (prefix synced)
faust.dark.meph → 歌德.dark.meph
```

## 7. Contract Hot-Reload vs Saves

During an active narrative, **rules and memories can be hot-updated**, which complements the save mechanism:

- **Trigger**: saving via the ✏️ editor on the narrative page, or saving the current `.meph` in an external editor (VSCode)
- **Rules take effect immediately**: new trigger conditions / actions / dice thresholds apply immediately to the next narrative round
- **Memories take effect immediately**: modify the `[N]` weight prefix in the 【记忆】(Memory) section and save—runtime memories update instantly, so major events can be upgraded to "never compressed + priority injection" protection in real time
- **Character personality locked**: the role name / anchors / worldview / background / opening scenes static sections **always keep the original version**,
  avoiding narrative contradictions from runtime changes (e.g., historical replies still speak in the old character's voice)
- **Runtime state fully preserved**: dialogue / state / history remain intact (no child re-creation triggered)
- **File watching**: `Directory.watch` covers the contract directory; targets = **current source file + its master**—after entering a narrative, auto-save switches to the child file, so editing the master directly in VSCode also triggers an instant hot-reload; 500ms debounce + per-file mtime suppression eliminates the "re-save child → re-trigger" infinite loop
- **Save conflict detection**: the editor records disk mtime when opened; if the file was modified by an external process (VSCode / auto-save) at save time, a "Overwrite / Reload / Cancel" dialog appears—external changes are never silently lost

> Hot-reload targets the **current running session**, while child saves target **persistent snapshots**—the two complement each other:
> adjusting rules/memories doesn't affect any progress you've already saved; the new content naturally merges into the snapshot on the next child save.

## 8. Related Code

- `lib/services/session/child_save_store.dart`: core child save implementation
- `lib/services/session/session_saver.dart`: session save helper
- `lib/services/parser/meph_serializer.dart`: contract serialization (injects runtime data)
- `lib/services/parser/meph_parser.dart`: contract parsing (restoration)
