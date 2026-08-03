<p align="center">
  <img src="assets/images/mephisto_logo.svg" width="160" alt="Mephisto" />
</p>

# 📜 Mephisto 叙事引擎

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/github/v/release/yuelinghuashu/mephisto-gui" alt="GitHub Release" />
  <img src="https://img.shields.io/github/license/yuelinghuashu/mephisto-gui" alt="License" />
  <img src="https://img.shields.io/github/actions/workflow/status/yuelinghuashu/mephisto-gui/ci.yml" alt="CI" />
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-blue" alt="Platforms" />
</p>

> **你写下角色的灵魂，梅菲斯特让它活过来，然后看它会走向何方。**

Mephisto（梅菲斯特）是一个基于「命运指引」的 AI 叙事引擎。它不替创作者写故事——它设定一个框架（契约），让叙事在框架内持续运动，直到玩家心满意足。

## ✦ 设计理念

在歌德《浮士德》中，梅菲斯特与浮士德立下契约：他满足浮士德的一切愿望，条件是——一旦浮士德感到满足而停止奋斗，他的生命即告终结。

| 《浮士德》                           | Mephisto 引擎            |
| ------------------------------------ | ------------------------ |
| 浮士德不断追求，无法满足             | 叙事在契约框架内持续生长 |
| 梅菲斯特设定条件：满足即终结         | 引擎设定规则边界         |
| 浮士德最终说出"你真美呀，请停留一下" | 玩家最终感到"心满意足"   |
| 契约完成，浮士德的灵魂归于梅菲斯特   | 契约完成，故事抵达终点   |

> **梅菲斯特不是恶魔，不是守护者。**
> **他是那个让叙事无法停下的机制。**

## 🚀 核心特性

- **契约系统**：`.meph` 契约文件定义角色锚点、世界观、开局场景、状态与规则
- **命运指引**：玩家以「命运」身份输入场景描述或情节推进，AI 据此展开叙事
- **规则引擎**：支持条件匹配（包含/状态/骰子）、动作执行（状态变更/记忆注入）、互斥组
- **骰子系统**：`roll(1d2)` 二元判定 / `roll(1d100)` 高精度命运判定，带「命运结算」卡片渲染
- **记忆系统**：自动提取关键事件摘要，超限自动压缩，塑造长期叙事一致性
- **子版存档**：母版只读，运行时对话生成子版快照，支持分支与恢复
- **自定义风格**：可自由设置叙事规则，精准控制输出文学风格（诗句对白/冷峻白描等）
- **跨平台**：Windows / macOS / Linux / Android / iOS
  - 桌面端：Windows / macOS / Linux，契约存储于用户主目录 `~/Mephisto/contracts`，可自定义目录
  - Android：契约可在「应用内部存储 ↔ 应用外部存储」间切换，支持导入 `.meph` 文件
  - iOS：契约存储于应用沙盒文档目录（系统限制，卸载即清除），支持导入 `.meph` 文件

## 📖 快速开始

1. **配置 LLM**：进入「设置 → LLM 配置」，填入 API Key / Base URL / Model（兼容 OpenAI / DeepSeek / Ollama）
2. **选择契约**：首页选择内置契约（浮士德 / 埃德蒙·唐泰斯）或导入自己的 `.meph` 文件
   - 桌面端可在设置页自定义契约目录；Android 可在设置页切换内部/外部存储；iOS 使用应用沙盒目录
3. **输入命运指引**：在叙事页输入场景推进，AI 将以第三人称文学叙事展开
4. **自定义叙事规则**（可选）：设置页编辑风格规则，例如：

   ```text
   以《浮士德》原典的诗句对白风格生成故事
   ```

> **🔒 安全提示**：API Key 以明文保存于本地偏好存储（shared_preferences），
> 仅限在可信的个人设备上使用。请勿在共享/公共设备上配置 API Key，
> 并避免将存储文件外泄；如需更高级别的保护，请考虑使用系统级密钥库。

## ✍️ 契约语法

```meph
【角色名】
浮士德

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

> 完整区块说明、值类型与错误处理见 [docs/contract-syntax.md](docs/contract-syntax.md)，
> 规则引擎（条件 / 动作 / 骰子 / 互斥组）详见 [docs/rule-engine.md](docs/rule-engine.md)。

## 📚 文档中心

深入了解 Mephisto 的机制，请阅读 [docs](docs/README.md) 文档中心：

| 文档 | 内容 |
| ---- | ---- |
| [契约语法参考](docs/contract-syntax.md) | `.meph` 格式、区块、值类型、错误处理 |
| [规则引擎详解](docs/rule-engine.md) | 条件、动作、骰子（1d2 / 1d100）、互斥组 |
| [记忆系统](docs/memory-system.md) | 记忆提取、去重、压缩 |
| [存档系统](docs/save-system.md) | 母版只读、子版快照、分支 |
| [平台存储策略](docs/platform-storage.md) | 各平台契约目录与沙盒限制 |

## 🧩 VSCode 插件联动

编写 `.meph` 契约推荐使用 **Mephisto VSCode 插件**，获得更专业的编辑体验：

- **语法高亮**：区块标题、规则、条件、动作一目了然
- **自动补全**：内联提示关键字与结构
- **实时校验**：输入即反馈语法错误，减少保存后的返工

[![VSCode Marketplace](https://img.shields.io/badge/VSCode-Mephisto%20插件-blue)](https://marketplace.visualstudio.com/items?itemName=yuelinghuashu.vscode-mephisto)

> 应用内编辑器适合快速调整；需要行号、语法高亮、自动补全等专业能力时，使用 VSCode + 插件效率更高。

## 🧩 技术栈

- **Flutter**（多端 UI）
- **Riverpod**（状态管理）
- **SharedPreferences**（偏好持久化）
- **HTTP**（OpenAI 兼容 SSE 流式调用）
- **MephParser**（自研契约解析器）

## 📁 目录结构

```text
lib/
├── app/          # 应用根、主题
├── domain/       # 数据模型（契约/消息/规则/状态）
├── providers/    # Riverpod 状态
├── screens/      # 页面层（首页/叙事/设置）
├── services/
│   ├── engine/   # 规则引擎（条件/骰子/执行器）
│   ├── llm/      # LLM 客户端（SSE 流式）
│   ├── memory/   # 记忆管理
│   ├── parser/   # .meph 解析/序列化
│   ├── prompt/   # 系统提示词构建
│   ├── session/  # 子版存档
│   └── storage/  # 契约目录/仓库
└── widgets/      # 共享组件
```

## 🧪 测试

```bash
flutter analyze
flutter test
```

测试覆盖规则引擎、Meph 解析、LLM、记忆、存档、Provider 与 UI 全链路。

## 🚀 CI / CD

项目内置 GitHub Actions 工作流（[`.github/workflows/ci.yml`](.github/workflows/ci.yml)），
在 Linux / Windows / macOS 三平台自动运行 `flutter analyze` + `flutter test` + 桌面构建。

## 🛠️ 平台支持与测试声明

> **诚实标注**：本项目由个人维护，受硬件与账号条件限制，以下平台**未经过真机/构建验证**，
> 可能存在尚未发现的 bug。在对应平台发布前，请务必先完成验证。

| 平台                                          | 验证状态                        | 说明                                                                                                |
| --------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Windows**                                   | ✅ 真机验证                     | 窗口默认尺寸 1280×720 + 屏幕居中已验证                                                              |
| **Linux**                                     | ✅ 真机验证 + 本机构建通过      | 含 `flutter build linux` 原生编译（C++ runner 改动）                                                |
| **Android**                                   | ✅ 真机验证                     | 外部存储 ↔ 内部沙盒切换的**交互体验**待实测确认                                                     |
| **macOS**                                     | ⚠️ 仅代码适配，**从未编译运行** | 窗口居中 Swift 代码、XIB 尺寸改动未在真实 macOS 验证                                                |
| **iOS**                                       | ⚠️ 仅代码适配，**从未编译运行** | 沙盒目录、文件选择器交互未在真实设备验证                                                            |
| **旧版鸿蒙**（HarmonyOS 2/3/4，兼容 Android） | ✅ 可运行本项目 Android APK     | 本质是 Android 兼容层，现有 `path_provider` / `file_selector` 沙盒适配可直接用；**未实测**          |
| **纯血鸿蒙**（HarmonyOS NEXT / 5.0+）         | ⛔ **不支持**                   | Flutter 官方无此平台目标，需用 OpenHarmony Flutter 分支独立建工程并逐依赖移植（独立工作量，未立项） |

### 系统版本要求

| 平台        | 最低版本                                                                   | 推荐版本                               |
| ----------- | -------------------------------------------------------------------------- | -------------------------------------- |
| **Windows** | Windows 10（Flutter 桌面最低要求）                                         | Windows 11                             |
| **Linux**   | 需 GTK 3（主流发行版均可）                                                 | 近两年发布的发行版（如 Ubuntu 22.04+） |
| **Android** | Flutter 工具链默认 `minSdk`（跟随 `flutter.minSdkVersion`，当前约 API 21） | Android 10+（API 29）                  |
| **iOS**     | iOS 13.0（项目配置 `IPHONEOS_DEPLOYMENT_TARGET`）                          | iOS 16+                                |
| **macOS**   | macOS 10.15 Catalina（项目配置 `MACOSX_DEPLOYMENT_TARGET`）                | macOS 12 Monterey+                     |

> **说明**：
>
> - 「最低版本」为**项目真实配置/官方要求**（iOS 13.0、macOS 10.15 均可在构建配置中查证）
> - 「推荐版本」为**维护者建议**，基于现代系统特性与稳定性推定，并未经全平台实测
> - 与平台声明一致：iOS / macOS 的版本兼容性未经过真机全量验证；若遇问题，先确认系统版本是否低于推荐值

### 已确认的隐患点（代码层面排查）

1. **iOS ATS 明文 HTTP**（已预防性修复）：iOS 默认禁明文 HTTP。用户配置本地
   Ollama `http://localhost:11434/v1` 时会被 ATS 拦截。已在 `Info.plist` 添加
   `NSAppTransportSecurity → NSAllowsLocalNetworking`（仅放行本地回环，HTTPS 仍严格保护）。
   **该配置尚未在 iOS 真机验证生效**。
2. **macOS 窗口居中**：`MainFlutterWindow.swift` 中按 `NSScreen.main.visibleFrame` 动态居中，
   Swift API 用法正确，但未在真实 macOS 编译，存在签名/时序风险。
3. **iOS 契约导入**：`file_selector`（UIDocumentPicker）在 iOS 的实际交互未验证。
4. **Android 存储切换**：沙盒 ↔ 外部存储切换后的目录体验（数据可见性、切换时机）未实测。

### 提出 Issue 的指南

如果你在使用 macOS / iOS 时遇到 bug，欢迎在仓库提交 Issue，并注明：

- 平台与系统版本（如 macOS 14.5 / iOS 17.4）
- 复现步骤与期望行为
- 是否使用本地 Ollama / 远端 API

## ⚖️ 版本

当前版本 **v1.0.0**：功能骨架完整，核心叙事/存档/分支流程已调通，测试完备度 191 个（含 UI 层关键路径测试）。

完整版本历史见 [CHANGELOG.md](CHANGELOG.md)。

## 📜 许可证

本项目采用 [MIT License](LICENSE) 开源，详见 [LICENSE](LICENSE) 文件。
