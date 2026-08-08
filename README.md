<p align="center">
  <img src="assets/images/mephisto_logo.svg" width="160" alt="Mephisto" />
</p>

# 📜 Mephisto 叙事引擎

<p align="center">
  <img src="https://img.shields.io/badge/lang-简体中文-blue?style=flat-square" alt="简体中文" />
  <a href="README.en.md"><img src="https://img.shields.io/badge/lang-English-blue?style=flat-square" alt="English" /></a>
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
<b><i>你写下角色的灵魂，梅菲斯特让它活过来，然后看它会走向何方。</i></b>
</p>

Mephisto（梅菲斯特）是一个基于「命运指引」的 AI 叙事引擎。它不替创作者写故事——它设定一个框架（契约），让叙事在框架内持续运动，直到玩家心满意足。

## ✦ 设计理念

在歌德《浮士德》中，梅菲斯特与浮士德立下契约：他满足浮士德的一切愿望，条件是——一旦浮士德感到满足而停止奋斗，他的生命即告终结。

| 《浮士德》                           | Mephisto 引擎            |
| ------------------------------------ | ------------------------ |
| 浮士德不断追求，无法满足             | 叙事在契约框架内持续生长 |
| 梅菲斯特设定条件：满足即终结         | 引擎设定规则边界         |
| 浮士德最终说出"你真美呀，请停留一下" | 玩家最终感到"心满意足"   |
| 契约完成，浮士德的灵魂归于梅菲斯特   | 契约完成，故事抵达终点   |

> **原典为根，命途为枝。每一句「请停留一下」，都是一条尚未被书写的命运。**

## 🚀 核心特性

- **契约系统**：`.meph` 契约文件定义角色锚点、世界观、开局场景、状态与规则
- **命运指引**：玩家以「命运」身份输入场景描述或情节推进，AI 据此展开叙事
- **规则引擎**：支持条件匹配（包含/状态/骰子）、动作执行（状态变更/记忆注入）、互斥组
- **骰子系统**：`roll(1d2)` 二元判定 / `roll(1d100)` 高精度命运判定，带「命运结算」卡片渲染
- **记忆系统**：自动提取关键事件摘要，超限自动压缩，塑造长期叙事一致性
- **上下文窗口**：设置页可选历史消息档位（20 / 40 / 60 / 全部），控制 LLM token 消耗，防止长对话稀释响应质量
- **子版存档**：母版只读，运行时对话生成子版快照，支持分支与恢复
- **规则热重载**：叙事页 ✏️ 或 VSCode 保存 `.meph` → **仅规则即时生效**，对话/状态/记忆/历史全保留
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
4. **调节上下文窗口**（可选）：设置页「历史消息窗口」可选 20 / 40 / 60 / 全部发送四档，
   控制发送给 LLM 的历史对话条数（长对话建议适度收紧以节省 token 并保持响应聚焦）
5. **自定义叙事规则**（可选）：设置页编辑风格规则，例如：

   ```text
   以《浮士德》原典的诗句对白风格生成故事
   ```

> **🔒 安全提示**：API Key 已持久化到系统级安全存储
> （Android Keystore / iOS · macOS Keychain / Windows DPAPI / Linux libsecret），
> 而非明文磁盘文件；旧版本残留的明文 Key 将在首次读取时自动迁移。
> 请遵循以下最佳实践，最大限度降低泄露风险：
>
> - **使用「从剪贴板导入」**：设置页 API Key 输入框旁的剪贴板图标可一键导入，
>   避免手输 Key 时长期残留于剪贴板
> - **勿在共享/公共设备上配置**：即使有安全存储，也建议只在自有设备上使用
> - **勿截图 / 勿发到聊天群 / 勿同步到云盘备份**
>
> > 极端场景（安全存储不可用，如系统密钥环异常）会自动降级为 SharedPreferences
> > 明文存储，仅影响本地设备——功能不受损，但不建议在共享设备上依赖该降级路径。

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

| 文档                                     | 内容                                    |
| ---------------------------------------- | --------------------------------------- |
| [契约语法参考](docs/contract-syntax.md)  | `.meph` 格式、区块、值类型、错误处理    |
| [规则引擎详解](docs/rule-engine.md)      | 条件、动作、骰子（1d2 / 1d100）、互斥组 |
| [记忆系统](docs/memory-system.md)        | 记忆提取、去重、压缩                    |
| [存档系统](docs/save-system.md)          | 母版只读、子版快照、分支                |
| [平台存储策略](docs/platform-storage.md) | 各平台契约目录与沙盒限制                |

## 🔥 规则热重载

你可以在叙事进行中实时调整规则，而**不会破坏当前进度**：

- **仅规则区块生效**：保存 `.meph` 后，新的规则（触发条件 / 动作 / 骰子阈值）立即用于**下一轮叙事**
- **角色人格锁定**：角色名 / 锚点 / 世界观 / 背景 / 开局场景等「人格本体」区块一律保留原运行版本，
  避免运行时改动导致叙事前后矛盾（如历史回复仍是旧角色口吻）
- **运行态全保留**：对话消息 / 状态值 / 记忆 / 历史丝毫无损，不存在「改规则 = 清进度」
- **两种触发方式**：
  - 叙事页右上角 ✏️ 打开应用内编辑器，保存后自动生效
  - 直接在使用 VSCode 等外部编辑器修改契约文件，应用自动检测并热更新

> 该机制与「子版存档」天然互补：热重载针对**运行中的当前会话**，存档针对**持久化快照**；
> 详细机制见 [docs/save-system.md](docs/save-system.md)。

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
- **flutter_secure_storage**（系统密钥链存储 API Key：Android Keystore / iOS·macOS Keychain / Windows DPAPI / Linux libsecret）
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

测试覆盖规则引擎、Meph 解析、LLM、记忆、存档、Provider 与 UI 全链路，
另有 `tool/validate_build_config.py` 对 Android/iOS/打包脚本做 15 项静态断言。

## 🚀 CI / CD

项目内置 GitHub Actions 工作流（[`.github/workflows/ci.yml`](.github/workflows/ci.yml)），
在 Linux / Windows / macOS 三平台自动运行：

- `validate-build-config`：actionlint 工作流语法检查 + `tool/validate_build_config.py` 构建配置断言
- `analyze-and-test`：`flutter analyze` + `flutter test`（三平台）
- `build-macos-ios`：macOS Release 与 iOS Release（no-codesign）编译验证
- 桌面平台构建（Release），发布工作流见 [`.github/workflows/release.yml`](.github/workflows/release.yml)

## 🛠️ 平台支持与测试声明

> **诚实标注**：本项目由个人维护，受硬件与账号条件限制，以下平台**未经过真机验证**，
> 可能存在尚未发现的 bug。在对应平台发布前，请务必先完成验证。

| 平台                                          | 验证状态                       | 说明                                                                                                |
| --------------------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------- |
| **Windows**                                   | ✅ 真机验证                    | 窗口默认尺寸 1280×720 + 屏幕居中已验证                                                              |
| **Linux**                                     | ✅ 真机验证 + 本机构建通过     | 含 `flutter build linux` 原生编译（C++ runner 改动）                                                |
| **Android**                                   | ✅ 真机验证                    | 外部存储 ↔ 内部沙盒切换的交互体验已验证                                                             |
| **macOS**                                     | ⚠️ CI 编译通过，**未真机运行** | macOS Release 构建已在 GitHub Actions 验证编译；窗口居中 Swift 行为仍需真机验证                     |
| **iOS**                                       | ⚠️ CI 编译通过，**未真机运行** | iOS Release（no-codesign）构建已在 GitHub Actions 验证编译；沙盒/文件选择器交互未在真实设备验证     |
| **旧版鸿蒙**（HarmonyOS 2/3/4，兼容 Android） | ✅ 可运行本项目 Android APK    | 本质是 Android 兼容层，现有 `path_provider` / `file_selector` 沙盒适配可直接用；**未实测**          |
| **纯血鸿蒙**（HarmonyOS NEXT / 5.0+）         | ⛔ **不支持**                  | Flutter 官方无此平台目标，需用 OpenHarmony Flutter 分支独立建工程并逐依赖移植（独立工作量，未立项） |

### 系统版本要求

| 平台        | 最低版本                                                               | 推荐版本                               |
| ----------- | ---------------------------------------------------------------------- | -------------------------------------- |
| **Windows** | Windows 10（Flutter 桌面最低要求）                                     | Windows 11                             |
| **Linux**   | 需 GTK 3（主流发行版均可）                                             | 近两年发布的发行版（如 Ubuntu 22.04+） |
| **Android** | Android 6.0（API 23，`minSdk = 23`，受 `flutter_secure_storage` 限制） | Android 10+（API 29）                  |
| **iOS**     | iOS 13.0（项目配置 `IPHONEOS_DEPLOYMENT_TARGET`）                      | iOS 16+                                |
| **macOS**   | macOS 10.15 Catalina（项目配置 `MACOSX_DEPLOYMENT_TARGET`）            | macOS 12 Monterey+                     |

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

### 提出 Issue 的指南

如果你在使用 macOS / iOS 时遇到 bug，欢迎在仓库提交 Issue，并注明：

- 平台与系统版本（如 macOS 14.5 / iOS 17.4）
- 复现步骤与期望行为
- 是否使用本地 Ollama / 远端 API

## ⚖️ 版本

完整版本历史见 [CHANGELOG.md](CHANGELOG.md)。

## 📜 许可证

本项目采用 [MIT License](LICENSE) 开源，详见 [LICENSE](LICENSE) 文件。

## ☕ 赞助支持

<details>
<summary>☕ 若这叙事曾打动你，不妨请梅菲斯特喝一杯</summary>

<img src="./assets/images/ali-pay.jpg" width="200" height="280" alt="支付宝收款码" />
<img src="./assets/images/wechat-pay.jpg" width="200" height="280" alt="微信收款码" />

</details>
