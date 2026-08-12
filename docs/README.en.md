# 📚 Mephisto Documentation Center

> Deep documentation for the Mephisto narrative engine. README provides an overview; this is the complete reference for the underlying mechanics.

> **中文版：[简体中文](README.md)**

## 📖 Document Index

| Document                                            | Content                                                                            | Use Case                                           |
| --------------------------------------------------- | ---------------------------------------------------------------------------------- | -------------------------------------------------- |
| [Contract Syntax Reference](contract-syntax.en.md)  | Complete `.meph` file format: all sections, value types, error handling            | Writing/editing contract files                     |
| [Rule Engine Deep Dive](rule-engine.en.md)          | Full syntax for condition matching, actions, dice, mutual exclusion groups         | Designing character behavior rules                 |
| [Rule Writing Guide](rule-writing-guide.en.md)      | Seven-question checklist, seven anti-patterns, scene-chain pattern, rules-vs-LLM boundary | Writing efficient, correct rules        |
| [Stage System](stage-system.en.md)                  | Multi-character stage directory conventions, creation, and narrative mechanics     | Creating/maintaining multi-character stages        |
| [Memory System](memory-system.en.md)                | Key event extraction, summarization, over-limit compression, long-term consistency | Understanding narrative consistency implementation |
| [Save System](save-system.en.md)                    | Master/child snapshots, branch naming, switching and restoration                   | Understanding the child save mechanism             |
| [Platform Storage Strategy](platform-storage.en.md) | Contract directory schemes and sandbox restrictions per platform                   | Understanding cross-platform storage behavior      |

> 💡 For writing and validating `.meph` contracts, we recommend pairing with the **[VSCode Mephisto plugin](https://marketplace.visualstudio.com/items?itemName=yuelinghuashu.vscode-mephisto)** (syntax highlighting / auto-completion / real-time validation).

## 🧭 Navigation

```text
README.en.md     ← Project overview, quick start (for new users)
├── docs/README.en.md ← This index (deep documentation entry)
├── CHANGELOG.md  ← Version history
└── Each document ← Mechanism-level details
```

> 📌 **Documentation-version correspondence**: This documentation describes the behavior of the current repository code.
> If you are using an older release, some mechanisms (e.g., the 【角色背景】(Character Background) section, multi-level branch tree)
> may not yet be included; please refer to [`CHANGELOG.md`](../CHANGELOG.md).
