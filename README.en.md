<p align="center">
  <img src="assets/images/mephisto_logo.svg" width="160" alt="Mephisto" />
</p>

# 📜 Mephisto Narrative Engine

<p align="center">
  <a href="README.md"><img src="https://img.shields.io/badge/lang-简体中文-blue?style=flat-square" alt="简体中文" /></a>
  <img src="https://img.shields.io/badge/lang-English-blue?style=flat-square" alt="English" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/github/v/release/yuelinghuashu/mephisto-gui" alt="GitHub Release" />
  <img src="https://img.shields.io/github/license/yuelinghuashu/mephisto-gui" alt="License" />
  <img src="https://img.shields.io/github/actions/workflow/status/yuelinghuashu/mephisto-gui/ci.yml" alt="CI" />
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-blue" alt="Platforms" />
</p>

<p align="center" >
  <b><i>You write the soul of the character; Mephisto brings it to life, then watches where it leads.</i></b>
</p>

Mephisto is an AI narrative engine driven by "fate." It doesn't write stories for you—it sets a framework (the _Contract_) and keeps the narrative moving within that framework until the player is satisfied.

## ✦ Design Philosophy

In Goethe's _Faust_, Mephistopheles makes a pact with Faust: he grants Faust every wish, on the condition that—once Faust feels content and stops striving—his life comes to an end.

| _Faust_                                                        | Mephisto Engine                                  |
| -------------------------------------------------------------- | ------------------------------------------------ |
| Faust never stops striving, never satisfied                    | Narrative grows within the Contract framework    |
| Mephistopheles sets the condition: satisfaction ends the story | The engine defines the boundary of the rules     |
| Faust finally says "Stay, thou art so fair!"                   | The player finally feels "content"               |
| The pact is fulfilled; Faust's soul belongs to Mephistopheles  | The pact is fulfilled; the story reaches its end |

> **The original work is the root; fate is the branch. Every "Stay, thou art so fair!" is a destiny yet unwritten.**

## 🚀 Key Features

- **Contract System**: `.meph` contract files define character anchors, worldview, opening scenes, states, and rules; ZIP pack/restore supported (fate tree + stage directory one-click export)
- **Fate Guidance**: The player acts as "Fate," providing scene descriptions or plot pushes that the AI uses to unfold the narrative
- **Rule Engine**: Supports condition matching (contains/state/dice), action execution (state changes/memory injection), and mutually exclusive groups
- **Dice System**: `roll(1d2)` binary judgment / `roll(1d100)` high-precision fate judgment, with a "Fate Verdict" card rendering
- **Memory System**: Automatically extracts key event summaries (1-5 star importance), auto-compresses when over the limit, shaping long-term narrative consistency
- **Context Window**: Choose a history message tier (20 / 40 / 60 / All) on the settings page to control LLM token consumption
- **Child Save System**: Master contracts are read-only; runtime dialogues generate child snapshots, supporting branches and restoration
- **Rule Hot-Reload**: Save `.meph` → **only rules take effect instantly**, with dialogue/state/memory/history all preserved
- **Multi-Character Stage**: A subdirectory under the contracts folder = a stage, where multiple characters interact and save independently
- **Cross-Platform**: Windows / macOS / Linux / Android / iOS, with built-in contracts including Faust, Edmond Dantès, Joan of Arc, Young Arthur, and Gilgamesh

## 📖 Quick Start

1. **Configure LLM**: Go to "Settings → LLM Configuration", fill in API Key / Base URL / Model (compatible with OpenAI / DeepSeek / Ollama)
2. **Select a Contract**: On the home page, choose a built-in contract or import your own `.meph` file / `.zip` archive
   - Desktop: You can customize the contract directory on the settings page; Android: switch between internal/external storage; iOS: uses the app sandbox directory
3. **Enter Fate Guidance**: On the narrative page, enter scene progressions, and the AI will unfold the narrative in third-person literary prose
4. **Adjust Context Window (optional)**: On the settings page, "History Message Window" offers 20 / 40 / 60 / Send All tiers
5. **Customize Narrative Rules (optional)**: Edit style rules on the settings page, for example:

   ```text
   Generate the story in the poetic dialogue style of the original Faust
   ```

> **🔒 Security Note**: The API Key is persisted to system-level secure storage
> (Android Keystore / iOS · macOS Keychain / Windows DPAPI / Linux libsecret),
> do not configure on shared devices, do not screenshot or send it to chat groups.

## ✍️ Contract Syntax

```meph
【角色名】
Faust

【锚点】
- 核心信念：真理比生命更重要

【状态】
- 灵魂完整度：100

【世界观】
16 世纪的德意志，一个充满神秘学与契约的世界。

【开局场景】
烛火摇曳的书斋中，浮士德坐在成堆的典籍之间。

【规则】
[灵魂危机] if 状态.灵魂完整度 < 30 -> 注入 "浮士德的灵魂接近枯竭"
[契约觉醒] if 包含 "契约" && roll(1d100) -> 状态.灵魂完整度 += 10
```

> Full block descriptions can be found in [docs/contract-syntax.md](docs/contract-syntax.md),
> and the rule engine (conditions / actions / dice / mutual exclusion groups) is detailed in [docs/rule-engine.md](docs/rule-engine.md).

## 📚 Documentation Center

For a deeper understanding of Mephisto's mechanics, read the [docs](docs/README.md) documentation center:

| Document                                              | Content                                                          |
| ----------------------------------------------------- | ---------------------------------------------------------------- |
| [Contract Syntax Reference](docs/contract-syntax.md)  | `.meph` format, sections, value types, error handling            |
| [Rule Engine Deep Dive](docs/rule-engine.md)          | Conditions, actions, dice (1d2 / 1d100), mutual exclusion groups |
| [Memory System](docs/memory-system.md)                | Memory extraction, deduplication, compression                    |
| [Save System](docs/save-system.md)                    | Read-only master, child snapshots, branches                      |
| [Platform Storage Strategy](docs/platform-storage.md) | Contract directories and sandbox restrictions per platform       |

## 🔥 Rule Hot-Reload

Save `.meph` during an active narrative → **only rules take effect instantly**, with all runtime state preserved:

- Save in the narrative page ✏️ or VSCode → new rules apply immediately to the **next narrative turn**
- Character personality core (role name/anchors/worldview, etc.) is always preserved, avoiding narrative contradictions
- Naturally complementary to the "child save" system: hot-reload targets the **current session**, saves target **persistent snapshots**

## 🧩 VSCode Plugin

For writing `.meph` contracts, we recommend the **Mephisto VSCode plugin** (syntax highlighting / auto-completion / real-time validation):

[![VSCode Marketplace](https://img.shields.io/badge/VSCode-Mephisto%20Plugin-blue)](https://marketplace.visualstudio.com/items?itemName=yuelinghuashu.vscode-mephisto)

## 🧩 Tech Stack

- **Flutter** (Multi-platform UI)
- **Riverpod** (State management)
- **SharedPreferences** (Preference persistence)
- **flutter_secure_storage** (System-keychain API Key storage)
- **HTTP** (OpenAI-compatible SSE streaming calls)
- **MephParser** (Self-developed contract parser)

## 📁 Directory Structure

```text
lib/
├── app/          # App root, theme
├── domain/       # Data models (contract/message/rule/state)
├── providers/    # Riverpod state
├── screens/      # Screens (home/narrative/settings)
├── services/
│   ├── engine/   # Rule engine (conditions/dice/executor)
│   ├── llm/      # LLM client (SSE streaming)
│   ├── memory/   # Memory management
│   ├── parser/   # .meph parser/serializer
│   ├── prompt/   # System prompt builder
│   ├── session/  # Child save
│   └── storage/  # Contract directory/repository
└── widgets/      # Shared components
```

## 🧪 Testing & CI

```bash
flutter analyze
flutter test
```

- Tests cover the rule engine, Meph parser, LLM, memory, saves, Providers, and the full UI chain
- GitHub Actions automatically runs analyze + test on Linux / Windows / macOS, plus macOS/iOS build verification

## 🛠️ Platform Support & Testing Statement

> **Honest Disclosure**: This project is maintained by an individual. Due to hardware and account constraints,
> the following platforms have **not been verified on real devices** and may contain undiscovered bugs.

| Platform                                                   | Verification Status                            | Notes                                         |
| ---------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------- |
| **Windows**                                                | ✅ Verified on real device                     |                                               |
| **Linux**                                                  | ✅ Real device + local build passed            | Includes `flutter build linux` native build   |
| **Android**                                                | ✅ Verified on real device                     | External ↔ internal storage switch verified   |
| **macOS**                                                  | ⚠️ CI build passed, **not run on real device** |                                               |
| **iOS**                                                    | ⚠️ CI build passed, **not run on real device** |                                               |
| **Legacy HarmonyOS** (HarmonyOS 2/3/4)                     | ✅ Can run this project's Android APK          | Android compatibility layer, not tested       |
| **Pure HarmonyOS** (HarmonyOS NEXT / 5.0+)                 | ⛔ **Not supported**                           | Requires OpenHarmony Flutter fork migration   |

### System Version Requirements

| Platform    | Minimum                                                                               | Recommended                                |
| ----------- | ------------------------------------------------------------------------------------- | ------------------------------------------ |
| **Windows** | Windows 10 (Flutter desktop minimum)                                                  | Windows 11                                 |
| **Linux**   | GTK 3 + libsecret required (`libsecret-1-dev` for build, `libsecret-1-0` for runtime) | Recent distributions (e.g., Ubuntu 22.04+) |
| **Android** | Android 6.0 (API 23, `minSdk = 23`)                                                   | Android 10+ (API 29)                       |
| **iOS**     | iOS 13.0 (project configured `IPHONEOS_DEPLOYMENT_TARGET`)                            | iOS 16+                                    |
| **macOS**   | macOS 10.15 Catalina (project configured `MACOSX_DEPLOYMENT_TARGET`)                  | macOS 12 Monterey+                         |

### Platform Notes

- **iOS ATS plaintext HTTP**: `NSAllowsLocalNetworking` added for local Ollama (not verified on real device)
- **macOS window centering**: Swift implementation ready, not verified on real device
- **Android production signing**: configure `key.properties` to enable in-place upgrades with the same keystore
- **Back up before uninstall**: uninstalling clears all contracts and saves; use the home page "Export (ZIP)" feature first

> When filing an issue, please note platform/OS version/reproduction steps/whether using Ollama.

## ⚖️ Version

Full version history in [CHANGELOG.md](CHANGELOG.md).

## 📜 License

This project is open-sourced under the [MIT License](LICENSE). See [LICENSE](LICENSE).

## ☕ Sponsorship

<details>
<summary>☕ If this narrative ever moved you, buy Mephisto a coffee</summary>

<img src="./assets/images/ali-pay.jpg" width="200" height="280" alt="Alipay QR Code" />
<img src="./assets/images/wechat-pay.jpg" width="200" height="280" alt="WeChat Pay QR Code" />

</details>