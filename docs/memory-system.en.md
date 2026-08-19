# 🧠 Memory System

> The memory system lets AI narratives stay consistent **across individual conversations**: it automatically extracts key events, deduplicates, compresses,
> and injects them into the system prompt as "memories," shaping the character's long-term continuity.
>
> **中文版：[简体中文](memory-system.md)**

## 1. Memory Lifecycle

```text
Conversation in progress (Fate ↔ Character)
    ↓
Memory extraction triggered every 3 rounds (maybeExtract)
    ↓
Extract 2-5 core event summaries from the most recent 20 messages
    ↓
Deduplicate (compare against existing memories, skip duplicates)
    ↓
More than 30? → Compress (summarize old memories + keep the most recent 5)
    ↓
Memory list injected into system prompt
```

## 2. Extraction Timing

- Extracted once every **3** dialogue rounds (controlled by `extractInterval = 3`)
- Rounds are counted by "fate" (player) messages
- The extraction window is the most recent **20** messages (`extractWindow = 10` × 2, including both fate and character messages)

## 3. Extraction Rules

MemoryManager constrains extraction behavior through the LLM prompt:

1. Extract **2-5** core events that significantly impacted the character, covering the full plot progression
2. Review the entire event chain of the dialogue, not just the last sentence
3. Each summary should be 20-60 characters (Chinese), retaining key characters, places, actions, and information
4. Ignore everyday pleasantries and meaningless dialogue
5. Do not re-extract events that already exist in the current memory
6. **Never modify or duplicate the character's core settings** (role name, anchors, state values, etc.)
7. Output format: one per line, starting with `- [weight] content`
   - Weight is an integer from 1-5 indicating this memory's importance to the character:
     5 = core oath / 4 = major plot event / 3 = general progress / 2 = minor info / 1 = edge detail
   - Use default 3 when unsure

> **Automatic weight assignment**: The LLM assigns a 1-5 weight when extracting,
> so automatically accumulated "major events" also gain access to the "never compressed + priority injection" protection.
> Falls back to default 3 when weight cannot be determined.

## 4. Deduplication and Compression

### Deduplication

- Newly extracted memories are compared line-by-line against existing memories (deduplicated by content)
- Fully duplicate entries are discarded
- **Weight upgrade**: When the same content appears with a higher weight, the old entry's weight is automatically upgraded (only discarded when new weight ≤ old weight)

### Compression (triggered when over the limit)

- Memory total limit is **30 entries** (`maxLimit`)
- Compression is triggered when the limit is exceeded:
  - Old memories (excluding the most recent 5) are compressed by the LLM into no more than 5 summaries
  - **The most recent 5 are preserved** (`compressRetain`) verbatim
  - **High-importance memories (importance ≥ 4) are never compressed by default**
  - When high-importance memories exceed **15 entries** (`highImportanceCap`), the lowest-weight high-importance entries are downgraded for compression to prevent unbounded token growth
  - The compressed summaries + recent originals + high-importance originals are merged into the new memory list

## 5. How Memory Affects Narrative

- The memory list is injected as part of the system prompt, providing the LLM with the long-term context of "what this character has been through"
- **Injected in descending importance**: high-importance (core character / major events) first, so the model prioritizes them
- **Configurable injection cap** (`maxMemories`): when over the cap, high-importance memories are all kept + the rest fill in by descending weight—over-cap memories **stay in the save file**, just not included this turn
- **Settings "Memory Injection Limit"**: choose 10 / 20 / 30 / all in the settings page (default 20), controlling the per-turn memory cap, preference persisted
- Combined with the contract's 【记忆】(Memory) section (initial memories) and runtime-extracted memories, it builds character consistency

## 6. Failure Degradation Strategy

| Scenario                                | Behavior                                                                 |
| --------------------------------------- | ------------------------------------------------------------------------ |
| LLM call fails                          | Silently skip this extraction/compression, keep the original memory list |
| Extraction result is empty              | Return the original memory list                                          |
| Extraction result is entirely duplicate | Return the original memory list                                          |
| Compression result is empty             | Keep the original memory list                                            |

> The memory system **never** interrupts the narrative main flow due to LLM exceptions.

## 7. Related Code and Constants

| Item                      | Value | Description                                                                                   |
| ------------------------- | ----- | --------------------------------------------------------------------------------------------- |
| `extractInterval`         | 3     | Extract once every N rounds                                                                   |
| `extractWindow`           | 10    | Extraction window (× 2 = 20 messages)                                                         |
| `maxLimit`                | 30    | Memory total limit                                                                            |
| `compressRetain`          | 5     | Most recent entries preserved during compression                                              |
| `highImportanceThreshold` | 4     | High-importance threshold (≥4 protected from compression by default)                          |
| `highImportanceCap`       | 15    | Max high-importance memories (beyond this, lowest-weight ones are downgraded for compression) |
| `maxMemories`             | null  | Injection cap (null = all; settings offers 10/20/30/all)                                      |

Core implementation: `lib/services/memory/memory_manager.dart`
