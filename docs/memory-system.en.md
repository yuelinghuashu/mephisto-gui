# 🧠 Memory System

> The memory system lets AI narratives stay consistent **across individual conversations**: it automatically extracts key events, deduplicates, compresses,
> and injects them into the system prompt as "memories," shaping the character's long-term continuity.

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
7. Output format: one per line, starting with `- `

## 4. Deduplication and Compression

### Deduplication

- Newly extracted memories are compared line-by-line against existing memories (deduplicated by content)
- Fully duplicate entries are discarded

### Compression (triggered when over the limit)

- Memory total limit is **30 entries** (`maxLimit`)
- Compression is triggered when the limit is exceeded:
  - Old memories (excluding the most recent 5) are compressed by the LLM into no more than 5 summaries
  - **The most recent 5 are preserved** (`compressRetain`) verbatim
  - The compressed summaries + recent originals are merged into the new memory list

## 5. How Memory Affects Narrative

- The memory list is injected as part of the system prompt, providing the LLM with the long-term context of "what this character has been through"
- Combined with the contract's 【记忆】(Memory) section (initial memories) and runtime-extracted memories, it builds character consistency

## 6. Failure Degradation Strategy

| Scenario | Behavior |
| ---------------- | ------------------------------------- |
| LLM call fails | Silently skip this extraction/compression, keep the original memory list |
| Extraction result is empty | Return the original memory list |
| Extraction result is entirely duplicate | Return the original memory list |
| Compression result is empty | Keep the original memory list |

> The memory system **never** interrupts the narrative main flow due to LLM exceptions.

## 7. Related Code and Constants

| Item | Value | Description |
| ----------------- | --- | ----------------------- |
| `extractInterval` | 3 | Extract once every N rounds |
| `extractWindow` | 10 | Extraction window (× 2 = 20 messages) |
| `maxLimit` | 30 | Memory total limit |
| `compressRetain` | 5 | Most recent entries preserved during compression |

Core implementation: `lib/services/memory/memory_manager.dart`