# 💾 Save System (Child Version Mechanism)

> Mephisto uses a "read-only master + child snapshot" save model: the master contract is a fixed "soul framework,"
> and each session's dialogue, state changes, memories, and history are saved as **child version files**—independent snapshots.

> **中文版：[简体中文](save-system.md)**

## 1. Core Concepts

| Concept | Description |
| ---- | ---- |
| **Master** | The creator-defined `.meph` contract (e.g., `faust.meph`), **never modified** |
| **Child** | A complete snapshot generated at runtime (e.g., `faust.child.meph`), containing all master data + state + memory + history |
| **Branch** | A user-custom-named child (e.g., `faust.dark.meph`), expressing a different fate path |

## 2. Composition of a Child

Child = all master data + runtime state changes + memory + history

Three runtime data blocks are injected during serialization:

1. **【状态】(State)**: state values after runtime changes (e.g., soul integrity dropping from 100 to 60)
2. **【记忆】(Memory)**: long-term memories extracted by MemoryManager
3. **【历史】(History)**: the complete dialogue history of this session (fate / assistant)

## 3. Naming Rules

| Scenario | File Name |
| ---------------- | ------------------------------- |
| Default save | `faust.child.meph` |
| Default already exists | `faust.child2.meph` (auto-increment) |
| Custom branch | `faust.dark.meph` |
| Custom branch already exists | `faust.dark2.meph` (auto-increment) |

- Children are stored in the **same contract directory** as the master, for easy lookup and management
- Name collisions are avoided automatically via incrementing numbers

## 4. Common Operations

| Operation | Description | Implementation |
| ---- | ---- | -------- |
| Save | Generate/overwrite a child file (supports branch name or default `.child`) | `ChildSaveStore.save` |
| Restore | Read and parse a child into a Contract (returns null on failure) | `ChildSaveStore.restore` |
| List | List all children of a master (`baseName.*.meph`, excluding the master itself) | `ChildSaveStore.listChildFiles` |
| Delete | Delete a single child file | `ChildSaveStore.delete` |
| Check | Check whether a child file exists | `ChildSaveStore.exists` |

## 5. Children in the Home Screen UI

- A master card can expand to show all its children
- Children support: enter narrative (restore), preview, rename, delete
- Master deletion supports "cascade delete": deletes all its children in one go

## 6. Rename Synchronization

When a master is renamed, the file name prefixes of all its children are synchronized:

```text
faust.meph → 歌德.meph
faust.child.meph → 歌德.child.meph   (prefix synced)
faust.dark.meph → 歌德.dark.meph
```

## 7. Rule Hot-Reload vs Saves

During an active narrative, **only rules can be hot-updated**, which complements the save mechanism:

- **Trigger**: saving via the ✏️ editor on the narrative page, or saving the current `.meph` in an external editor (VSCode)
- **Only rules take effect**: new trigger conditions / actions / dice thresholds apply immediately to the next narrative round
- **Character personality locked**: the role name / anchors / worldview / background / opening scenes sections **always keep the original version**,
  avoiding narrative contradictions from runtime changes (e.g., historical replies still speak in the old character's voice)
- **Runtime state fully preserved**: dialogue / state / memory / history remain intact (no child re-creation triggered)
- **File watching**: `Directory.watch` + 500ms debounce + mtime suppression, eliminating the "re-save child → re-trigger" infinite loop

> Hot-reload targets the **current running session**, while child saves target **persistent snapshots**—the two complement each other:
> changing rules doesn't affect any progress you've already saved; the new rules naturally merge into the snapshot on the next child save.

## 8. Related Code

- `lib/services/session/child_save_store.dart`: core child save implementation
- `lib/services/session/session_saver.dart`: session save helper
- `lib/services/parser/meph_serializer.dart`: contract serialization (injects runtime data)
- `lib/services/parser/meph_parser.dart`: contract parsing (restoration)