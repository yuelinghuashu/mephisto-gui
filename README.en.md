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

- **Contract System**: `.meph` contract files define character anchors, worldview, opening scenes, states, and rules
- **Fate Guidance**: The player acts as "Fate," providing scene descriptions or plot pushes that the AI uses to unfold the narrative
- **Rule Engine**: Supports condition matching (contains/state/dice), action execution (state changes/memory injection), and mutually exclusive groups
- **Dice System**: `roll(1d2)` binary judgment / `roll(1d100)` high-precision fate judgment, with a "Fate Verdict" card rendering
- **Memory System**: Automatically extracts key event summaries, auto-compresses when over the limit, shaping long-term narrative consistency
- **Context Window**: Choose a history message tier (20 / 40 / 60 / All) on the settings page to control LLM token consumption and prevent long conversations from diluting response quality
- **Child Save System**: Master contracts are read-only; runtime dialogues generate child snapshots, supporting branches and restoration
- **Contract Export/Import (ZIP)**: A single-character fate tree (master + all child versions) or an entire multi-character stage directory can be exported as standard `.zip` with one click; import supports auto-extracting `.zip` files (with automatic duplicate-name serial numbering), so sharing / backup / migration no longer requires manually hunting through directories
- **Rule Hot-Reload**: Edit in the narrative page ✏️ or save the `.meph` in VSCode → **only rules take effect instantly**, with dialogue/state/memory/history all preserved
- **Customizable Style**: Freely set narrative rules to precisely control output literary style (poetic dialogue / stark realism, etc.)
- **Cross-Platform**: Windows / macOS / Linux / Android / iOS
  - Desktop: Windows / macOS / Linux, contracts stored in user home `~/Mephisto/contracts`, customizable directory
  - Android: contracts can switch between "app internal storage ↔ app external storage", supports importing `.meph` / `.zip` files
  - iOS: contracts stored in app sandbox documents (system restriction, cleared on uninstall), supports importing `.meph` / `.zip` files

## 📖 Quick Start

1. **Configure LLM**: Go to "Settings → LLM Configuration", fill in API Key / Base URL / Model (compatible with OpenAI / DeepSeek / Ollama)
2. **Select a Contract**: On the home page, choose a built-in contract (Faust / Edmond Dantès / Joan of Arc / Young Arthur / Gilgamesh) or import your own `.meph` file / `.zip` archive (for a whole fate tree or stage)
   - Desktop: You can customize the contract directory on the settings page; Android: switch between internal/external storage on the settings page; iOS: uses the app sandbox directory
3. **Enter Fate Guidance**: On the narrative page, enter scene progressions, and the AI will unfold the narrative in third-person literary prose
4. **Adjust Context Window (optional)**: On the settings page, "History Message Window" offers 20 / 40 / 60 / Send All tiers,
   controlling how many historical dialogue messages are sent to the LLM (consider tightening it on long conversations to save tokens and keep responses focused)
5. **Customize Narrative Rules (optional)**: Edit style rules on the settings page, for example:

   ```text
   Generate the story in the poetic dialogue style of the original Faust
   ```

> **🔒 Security Note**: The API Key is persisted to system-level secure storage
> (Android Keystore / iOS · macOS Keychain / Windows DPAPI / Linux libsecret),
> rather than a plaintext disk file; legacy plaintext keys left by older versions are auto-migrated on first read.
> Follow these best practices to minimize the risk of leakage:
>
> - **Use "Paste from Clipboard"**: The clipboard icon next to the API Key field on the settings page allows one-click import,
>   avoiding the Key lingering in your clipboard after manual entry
> - **Do not configure on shared/public devices**: even with secure storage, only use on your own device
> - **Do not screenshot / send in chat groups / sync to cloud backups**
>
> > In extreme cases (secure storage unavailable, e.g., system keyring failure), it gracefully falls back to
> > SharedPreferences plaintext—functionality is unaffected, but relying on that fallback on shared devices is not advised.

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

> Full block descriptions, value types, and error handling can be found in [docs/contract-syntax.md](docs/contract-syntax.md),
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

You can adjust rules in real-time during an active narrative **without breaking current progress**:

- **Only the rules section takes effect**: After saving the `.meph`, new rules (trigger conditions / actions / dice thresholds) apply immediately to the **next narrative turn**
- **Character personality locked**: The role name / anchors / worldview / background / opening scenes and other "personality core" sections are always preserved from the running version, avoiding narrative contradictions from runtime changes (e.g., historical replies still speak in the old character's voice)
- **Runtime state fully preserved**: Dialogue messages / state values / memory / history remain intact—there is no "changing rules = clearing progress"
- **Two trigger methods**:
  - Click the ✏️ button on the narrative page to open the in-app editor; changes take effect automatically after saving
  - Edit the contract file with an external editor like VSCode; the app automatically detects and hot-reloads

> This mechanism is naturally complementary to the "child save" system: hot-reload targets the **current running session**, while saves target **persistent snapshots**;
> detailed mechanics are described in [docs/save-system.md](docs/save-system.md).

## 🧩 VSCode Plugin

For writing `.meph` contracts, we recommend the **Mephisto VSCode plugin** for a more professional editing experience:

- **Syntax Highlighting**: Section titles, rules, conditions, and actions at a glance
- **Auto-completion**: Inline hints for keywords and structures
- **Real-time Validation**: Instant feedback on syntax errors, reducing post-save rework

[![VSCode Marketplace](https://img.shields.io/badge/VSCode-Mephisto%20Plugin-blue)](https://marketplace.visualstudio.com/items?itemName=yuelinghuashu.vscode-mephisto)

> The in-app editor is suitable for quick adjustments; use VSCode + the plugin when you need line numbers, syntax highlighting, auto-completion, and other professional capabilities.

## 🧩 Tech Stack

- **Flutter** (Multi-platform UI)
- **Riverpod** (State management)
- **SharedPreferences** (Preference persistence)
- **flutter_secure_storage** (System-keychain API Key storage: Android Keystore / iOS·macOS Keychain / Windows DPAPI / Linux libsecret)
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

## 🧪 Testing

```bash
flutter analyze
flutter test
```

Tests cover the rule engine, Meph parser, LLM, memory, saves, Providers, and the full UI chain,
along with `tool/validate_build_config.py` which performs 15 static assertions on Android/iOS/build scripts.

## 🚀 CI / CD

The project includes a GitHub Actions workflow (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml))
that automatically runs on Linux / Windows / macOS:

- `validate-build-config`: actionlint workflow syntax check + `tool/validate_build_config.py` build configuration assertions
- `analyze-and-test`: `flutter analyze` + `flutter test` (three platforms)
- `build-macos-ios`: macOS Release and iOS Release (no-codesign) compilation verification
- Desktop platform builds (Release); release workflow in [`.github/workflows/release.yml`](.github/workflows/release.yml)

## 🛠️ Platform Support & Testing Statement

> **Honest Disclosure**: This project is maintained by an individual. Due to hardware and account constraints,
> the following platforms have **not been verified on real devices** and may contain undiscovered bugs.
> Please verify thoroughly before releasing on any platform.

| Platform                                                   | Verification Status                            | Notes                                                                                                                                                    |
| ---------------------------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Windows**                                                | ✅ Verified on real device                     | Default window 1280×720 + centered on screen verified                                                                                                    |
| **Linux**                                                  | ✅ Real device + local build passed            | Includes `flutter build linux` native compilation (C++ runner changes)                                                                                   |
| **Android**                                                | ✅ Verified on real device                     | The **interaction experience** of external ↔ internal storage switching has been verified                                                                |
| **macOS**                                                  | ⚠️ CI build passed, **not run on real device** | macOS Release build verified on GitHub Actions; window centering Swift behavior still needs real-device verification                                     |
| **iOS**                                                    | ⚠️ CI build passed, **not run on real device** | iOS Release (no-codesign) build verified on GitHub Actions; sandbox/file-picker interactions not verified on real devices                                |
| **Legacy HarmonyOS** (HarmonyOS 2/3/4, Android-compatible) | ✅ Can run this project's Android APK          | Essentially an Android compatibility layer; existing `path_provider` / `file_selector` sandbox adaptations can be used directly; **not actually tested** |
| **Pure HarmonyOS** (HarmonyOS NEXT / 5.0+)                 | ⛔ **Not supported**                           | Flutter has no official target for this platform; requires an OpenHarmony Flutter fork and per-dependency migration (independent effort, not planned)    |

### System Version Requirements

| Platform    | Minimum                                                                               | Recommended                                |
| ----------- | ------------------------------------------------------------------------------------- | ------------------------------------------ |
| **Windows** | Windows 10 (Flutter desktop minimum)                                                  | Windows 11                                 |
| **Linux**   | GTK 3 + libsecret required (`libsecret-1-dev` for build, `libsecret-1-0` for runtime) | Recent distributions (e.g., Ubuntu 22.04+) |
| **Android** | Android 6.0 (API 23, `minSdk = 23`, required by `flutter_secure_storage`)             | Android 10+ (API 29)                       |
| **iOS**     | iOS 13.0 (project configured `IPHONEOS_DEPLOYMENT_TARGET`)                            | iOS 16+                                    |
| **macOS**   | macOS 10.15 Catalina (project configured `MACOSX_DEPLOYMENT_TARGET`)                  | macOS 12 Monterey+                         |

> **Notes**:
>
> - "Minimum" reflects **actual project configuration / official requirements** (iOS 13.0, macOS 10.15 both verifiable in build configs)
> - "Recommended" reflects **maintainer suggestions**, estimated from modern system features and stability; not fully tested across all platforms
> - Aligned with the platform statement: iOS/macOS version compatibility has not been fully verified on real devices; if issues arise, first check whether the system version is below the recommended value

### Platform Risks & Notes

1. **iOS ATS plaintext HTTP** (preventively fixed): iOS blocks plaintext HTTP by default. Users configuring local
   Ollama `http://localhost:11434/v1` would be blocked by ATS. Added
   `NSAppTransportSecurity → NSAllowsLocalNetworking` in `Info.plist` (only allows local loopback; HTTPS remains strictly protected).
   **This configuration has not been verified on a real iOS device.**
2. **macOS window centering**: `MainFlutterWindow.swift` dynamically centers based on `NSScreen.main.visibleFrame`;
   Swift API usage is correct, but not compiled on real macOS—signature/timing risks exist.
3. **iOS contract import**: `file_selector` (UIDocumentPicker) actual interaction on iOS is unverified.
4. **Android production signing (in-place upgrades supported)**:
   - The project has **production release signing configured**: when `android/key.properties` exists (local, not committed),
     builds automatically use the production signature; when missing, they gracefully fall back to the debug signature,
     so development / CI builds never break.
   - **Production signature + same signature → in-place upgrade**: subsequent versions signed with the same keystore
     can upgrade directly over the installed app, with no need to uninstall first.
   - ⚠️ **Keep the keystore and passwords safe** (`~/keystores/mephisto.jks`): losing them is irreversible, and switching
     signatures will force users to uninstall and reinstall; always keep signing every release with the **same keystore**.
     See the comments at the top of `android/app/build.gradle.kts` for how to generate the keystore and configure `key.properties`.

   > ⚠️ **If an uninstall-reinstall becomes necessary** (e.g., a debug-signed build was released earlier, or the signature changes):
   > uninstalling the app **wipes all contracts and saves** (master `.meph`, child saves `*.child.meph`, custom branches)
   > with **no way to recover them**. Back up first:
   >
   > **Easiest way: use the "Export (ZIP)" option in the ⋮ menu of a contract/stage card on the home page** —
   > pack a fate tree (master + all child versions) or an entire multi-character stage into a `.zip` and save it
   > to Downloads / computer / cloud drive; after reinstalling, just use the "Import" button on the home page to restore it.
   >
   > Manual backup (for Android external storage mode):
   > 1. Open `/storage/emulated/0/Android/data/yuelinghuashu.mephisto/files/Mephisto/contracts`
   >    via a phone file manager or **USB connection to a computer (MTP mode)**
   > 2. Copy **all `.meph` files** to your Downloads folder, computer, or cloud drive
   > 3. After installing the new version, use the **"Import"** button on the home page to re-import the backed-up `.meph` files
   >
   > Saves (child versions) are the same `.meph` files as contracts, so importing restores them completely,
   > including their branch labels (`@命运`).

### Guide for Filing Issues

If you encounter bugs on macOS / iOS, feel free to file an issue in the repository, noting:

- Platform and OS version (e.g., macOS 14.5 / iOS 17.4)
- Reproduction steps and expected behavior
- Whether using local Ollama / remote API

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
