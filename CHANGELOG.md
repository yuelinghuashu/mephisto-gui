# 📜 Mephisto 版本历史

所有值得注意的更改都会记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.3.0] - Android 正式签名 · 覆盖安装支持（未发布）

### ✨ 新特性

- **Android 正式签名**：配置 release 签名密钥库（`~/keystores/mephisto.jks`）+ `android/key.properties`，同一把密钥签名的后续版本可直接**覆盖安装**，无需先卸载旧版
- **签名优雅降级**：`android/app/build.gradle.kts` 检测到 `key.properties` 即用正式签名，缺失时自动回落 debug 签名，开发 / CI 构建不中断
- **记忆写回即存档**：记忆提取完成后立即持久化，关闭应用不再丢失新记忆
- **首页「最近编辑」快捷入口**：品牌标题右侧金色胶囊显示最近修改的契约（角色名 + 相对时间），点击直接进入叙事——列表再深也一眼可达
- **首页最近编辑排序**：顶层契约树按「子树最近编辑时间」降序排列，自动保存子版后母版树自动靠前
- **LLM 超时/重试可配置**：设置页新增「超时（秒）」「最大重试」输入，适配慢网络/长文本场景
- **非流式 JSON 响应兜底**：OpenAI 兼容代理返回标准 JSON（非 SSE）时自动提取 `choices[0].message.content`
- **多角色舞台（数据层）**：契约根目录下的一层子目录 = 多角色舞台（文件夹名 = 舞台前缀），内含 N 份平级 `.meph` 角色卡；舞台目录自动发现、每份角色卡独立解析组装；公共世界观取第一个角色（字典序）

### 🐛 修复

- 记忆提取竞态：提取期间新产生的记忆不再被旧结果覆盖，超限按权重取舍（低权重优先压缩以节省 token）
- 文件监听阻塞：内容校验改为异步读取，不再因磁盘 IO 卡顿界面
- 自定义契约缺失/损坏时叙事页无提示：`contractProvider` 兜底为空契约 + 同步设置 fallback notice，顶部警告条不再静默缺失
- narrative_provider 测试时序竞态：测试容器销毁前先 flush 微任务，消除偶发的「ProviderContainer already disposed」30 秒超时

### 🚀 性能与健壮性

- 流式输出优化：仅更新实际变化的流式气泡，未变化消息无需重绘，长对话滚动更流畅
- 提示词构建加速：记忆排序去重 + DSL 关键字正则预编译
- 编辑器冲突提示国际化：英文界面不再中英混杂
- 流式打字机光标：约 1.2 秒周期方波闪烁，替代静态竖线，输出节奏更直观
- 记忆提取提示词强化「语义相同不要重复提取」：措辞不同但同事件不再反复积累
- 空内容诊断日志增加 `Content-Type` 字段，排查更高效
- **同步文件 IO 改异步**：首页契约列表 mtime 读取、文件监听基线刷新改用异步 API（`exists` / `lastModified` / `readAsString`），消除磁盘 IO 在 UI 事件循环上的阻塞隐患

### 🧹 重构

- 文件名解析抽为共享工具，消除多处重复逻辑
- 魔法值清理：`DiceResult` 阈值系数 / 流式节流窗口 / 滚动容差抽为命名常量
- 新增 `relative_time.dart` 相对时间格式化工具（刚刚 / N 分钟前 / N 小时前 / N 天前 / 具体日期）

### 🔧 工程化

- 新增 GitHub Actions CI：push / PR 自动执行 `flutter analyze` + `flutter test`
- CI 增加 Linux 桌面构建验证（`flutter build linux --debug`），不再只在推送后才发现打包问题
- 安全存储升级：`flutter_secure_storage` 从 9.2.4 升级到 **11.0.0**（Android AES/GCM 加密等安全改进，平台子包同步升级；323 个测试全量回归通过）
- 清理根目录误建文件 `how f47ada9 --stat`（`git log` 命令参数被误当重定向目标的残留）
- 新增多角色舞台数据层测试 10 个（舞台目录发现 / 角色卡解析 / 公共世界观）
- **统一 Flutter 入口**：新增 `lib/main.dart` 转发入口（指向 `lib/app/main.dart`），修复 CI `flutter build linux` 报 `Target file lib/main.dart not found`；release.yml / Makefile 移除显式 `-t` 参数，各平台构建走默认入口
- 测试总数：**323 个**

### 📚 文档

- README / README.en：「平台风险与注意事项」章节更新——Android 正式签名状态说明、密钥保管警告、`key.properties` 配置指引指向 `build.gradle.kts` 顶部注释
- docs/platform-storage：新增「卸载风险与备份指引」——卸载会清除全部契约与存档（母版/子版/分支），提供外部存储 + USB/MTP 备份、首页「导入」恢复的完整流程

<details>
<summary>## [1.2.0] - 上下文窗口 · 记忆权重体系 · 编辑器健壮性 · API Key加密</summary>

### ✨ 新特性

- **历史消息窗口**：设置页可选 20/40/60/全部（默认 40），控制 LLM 上下文长度
- **记忆权重体系**：1-5 权重（5 核心 / 4 重大 / 3 一般 / 2 次要 / 1 边缘），`[权重]` 前缀标记，≥4 永不压缩
- **记忆权重自动分配**：提取提示词输出 `- [权重] 内容`，自动记忆共享权重体系
- **记忆注入上限**：设置页 10/20/30/全部（默认 20），超限高权重优先
- **记忆热重载**：规则 + 记忆双区块热更新，改 `[N]` 前缀保存即生效
- **记忆权重持久化**：serialize 始终输出 `[N]` 前缀，旧格式自动补 `[3]`
- **编辑器保存冲突检测**：保存时提示「覆盖 / 重新加载 / 取消」，防静默丢失
- **设置页响应式**：窄屏「分区入口 + 子页」，宽屏单页；区块延迟实例化
- **图标风格统一（浮士德契约风）**：设置「测试连接」替换现代科技感图标；记忆注入上限 4 档改用「书卷渐进」（书签 → 手稿 → 魔法书页 → 星光灌注），强化中古契约意象

### 🐛 修复

- Equatable 测试污染：props 仅按内容值比较，去掉 id / timestamp
- 文件监听 cancel：清除 mtime 抑制记录，重绑首轮热重载不再误抑制
- 外部修改母版不生效：监听目标扩为「源文件 + 母版」，按实际变化文件名过滤
- mtime 抑制按文件名独立记录：子版存档仍抑制，母版修改不误拦截
- 骰子 1d2 安科判定：默认「1 成功 / 2 失败」，verdict 改两档
- 【角色背景】缺失：`ContractPanel` 补齐 `Contract.background`
- 序列化空行：`_compactBlankLines()` 压缩连续空行
- 存档恢复失败：SnackBar 明确提示，不再静默空会话
- 流式竞态：同步标志位 + 状态双保险，防连点重复生成

### 🚀 增强

- 去重权重升级：新权重更高时升级旧记忆，永不降级
- 高权重上限：`highImportanceCap = 15`，超限降级压缩防 token 失控
- LLM 网络重试：三类网络异常统一指数退避
- 文件监听异常防护：回调失败仍恢复监听，防死循环
- API Key 安全最佳实践：设置页新增「从剪贴板导入」按钮，避免手输时 Key 残留剪贴板；README 补充泄露防护指南
- **API Key 改用系统密钥链存储**：引入 `flutter_secure_storage`，API Key 持久化到系统级安全存储（Android Keystore / iOS·macOS Keychain / Windows DPAPI / Linux libsecret），旧明文在首次读取时自动迁移；密钥链不可用时优雅降级 SharedPreferences 明文（功能不受损）

### 🧹 重构

- HomeScreen 用 `ListenableBuilder` 监听，消除 6 处 setState
- `copyWith` 无变化短路，减少无谓通知
- LLM 请求重试：连接超时指数退避，流式中途/业务错误不重试
- 记忆提取解耦：自动保存先行，异步提取 + 30s 超时
- 条件编译缓存：契约切换自动清除旧 AST
- 解析性能：高频正则提为常量，`depth` 惰性缓存
- 服务复用：`NarrativeTurnService` / `MemoryManager` 全局单例
- UI 首帧：监听绑定移入 `initState`
- 记忆排序复用：统一接入 `sortByImportance()`
- 首页缓存：预计算 `allInfos`，避免重复递归
- 文件检查：内存 Set 替代多次 `existsSync()`

### 🔧 工程化

- 确认 `flutter gen-l10n` 工作流与 ARB 一致
- 移除应用内记忆编辑 UI，统一「编辑器改 `[N]` 前缀」
- 新增测试：文件监听、窗口档位、本地兜底、LLM 重试、记忆权重、记忆热重载、设置页响应式
- 测试总数：**290 个**（新增 LLM 配置加密存储 / 明文迁移 / 降级测试）
- 新增 `build-macos-ios` job：push/PR 验证 `flutter build macos --release` 与 `flutter build ios --release --no-codesign`
- 构建配置断言扩至 15 项：`validate_build_config.py` 增加 macOS/iOS 构建步骤存在性校验
- README 平台声明同步：macOS / iOS 从「从未编译运行」更新为「CI 编译通过，未真机运行」

</details>

<details>
<summary>## [1.1.0] - 规则热重载 · 国际化 · 文档</summary>

### ✨ 新特性

- **规则热重载**：编辑器或 VSCode 保存 `.meph` 仅规则即时生效，人格锁定，运行态全保留
- **停止生成**：生成中可点「停止」中断流式读取，已累积内容保留并收尾存档
- **界面国际化**：中英文切换（设置页可选，偏好持久化），替换约 150 处硬编码中文
- **命运树可视化**：母版为树根、子版沿金色主干生长
- **命运一句话**：另存分支可填命运说明，以 `@命运` 区块独立存储
- **官方示范子版**：新增 `dantes.bonapart.meph`、`faust.utopia.meph`
- **英文文档**：新增 `README.en.md` 与 docs 全部 6 篇英文文档

### 🐛 修复

- LLM 配置缓存：`autoDispose` + 发送时强制重读，改 Key 无需重启
- 开局场景卡片移除合成斜体
- 国际化补全：首页品牌 + Provider 硬编码中文全量迁入 ARB
- 打开子版存档直接定位最新消息
- 滚动图标改垂直双箭头

### 🚀 性能与健壮性

- 条件编译缓存加 LRU 容量上限
- LLM 错误响应体限 8KB 截断
- 契约目录扫描改异步，消除 UI 阻塞
- 文件监听不可用显示提示，不静默降级
- 契约列表并行读取（`Future.wait`）

### 🧹 架构优化

- `historyToMessages` 抽为共享纯函数
- 文件监听抽为 `ContractFileWatcher` 独立类
- LLM 配置文案全量迁 ARB，executor 用 switch 表达式
- 流式节流简化为一次性 Timer
- 新增共享测试助手
- 移除 Riverpod legacy API，统一 `debugPrint`

### 🔧 构建与工程化

- Windows 移除 zip 整包，仅保留安装器
- 新增 `validate_build_config.py` + actionlint 检查
- 测试数提升至 221 个

### 📚 文档

- README 补充中英文赞助区块，修复收款码路径

</details>

<details>
<summary>## [1.0.0] - 首个正式发布</summary>

### 🎭 核心叙事

- 单轮管线：规则引擎 → 提示词 → LLM 流式 → 本地兜底
- 系统提示词七层；SSE 流式 + 50ms 节流
- 骰子「命运结算」卡片：骰值 / 阈值 / 成败 / 诗意文案

### 📜 契约系统

- `.meph` 词法解析：区块白名单、草稿宽容、精确报错
- 序列化可逆（用于子版存档）
- 实时校验：400ms 防抖、错误定位行号
- 一键格式化；契约 CRUD（导入/删除/重命名级联）
- 缺失/损坏自动回退内置模板并顶部提示

### 🎲 规则与记忆

- 两阶段规则执行：被动批量 + 主动互斥
- 互斥组 `[group:xxx]`；条件 AST 缓存
- 骰子 `roll(1d2)` / `roll(1d100)` + 阈值比较
- 记忆管理：每 N 轮提取、去重、超限压缩

### 💾 会话与存档

- 母版只读 + 子版快照；自动存档每轮覆盖
- 子版恢复 / 删除 / 列表（树状层级）
- 附加上下文：txt / md / meph 注入 LLM

### 📱 界面与适配

- 契约目录平台自适应；Android 内外存储切换
- 桌面三平台 1280×720 局中
- 内容宽度档位；双主题 + NotoSerifSC
- iOS ATS 本地网络放行

### ✅ 测试与工程化

- 191 个测试全链路覆盖
- CI：三平台 `flutter analyze` + `flutter test`

### 🖥 平台验证声明

> 个人维护，受硬件 / 账号限制，**macOS 与 iOS 仅代码适配、从未编译运行**。
> ✅ Windows / Linux（含原生编译）/ Android 已验证；
> ⚠️ macOS / iOS 仅代码适配；⛔ 纯血鸿蒙不支持。详见 README「平台支持与测试声明」。

</details>
