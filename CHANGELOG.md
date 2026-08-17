# 📜 Mephisto 版本历史

所有值得注意的更改都会记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.4.1] - 浮士德帝国线 · 流式立即显示 · 输入历史 · 导出叙事 · 解析器健壮性 · 主题令牌收敛 · 无障碍增强

### ✨ 新特性

- 新增浮士德示范子版 `faust.imperial.meph`（帝国金殿 / 权柄幻象 if 线）：梅菲斯特以弄臣身份混入破产帝国宫廷，浮士德以星相家身份献策发行纸币、受命召唤海伦——灵魂完整度 / 皇眷 / 幻惑 / 权力欲 / 警觉五维状态机，双终局（沉沦 / 觉醒）
- **流式「立即显示全文」**：生成中点输入区「⏩」跳过打字机动画直接显示完整回复（单角色 / 多角色舞台均支持）
- **输入历史 + 多行输入**：桌面端 ↑ / ↓ 回溯最近 5 条命运指引，Shift+Enter 换行、Enter 发送；移动端保持单行回车发送
- **导出叙事**：存档菜单新增「导出叙事」，将完整对话导出为 Markdown 阅读版（`角色-命运纪事.md`）

### 🐛 修复

- 格式化器修复：`if` 关键字补充词边界（不再误伤 `gift`/`unified` 等英文单词）；冒号规整仅作用于锚点/状态键值对区块，散文内容中的冒号（如 `12:30`、`http://x.com`）不再被补空格篡改
- 解析器修复：`【角色名】` 首行 `# 注释` 不再被当作角色名；括号校验屏蔽引号内容（`包含 "("` 不再误报）；散文区块中的 `【xxx】` 行不再导致其后内容丢失（未知区块并入前一文本区块）
- 条件编译跳过双引号字符串内的 `||` / `&&`（`包含 "a||b"` 不再被错误切分为逻辑或）
- 序列化可逆性修复：`unquote` 反转义 `\"`；锚点与状态统一带引号输出（`"10"` 往返不再变数字）；键值对解析跳过引号内冒号
- 规则引擎透出动作执行反馈（`RuleRunResult.actionOutputs`）——`📊 状态「x」不存在`、`📊 除数不能为0` 等提示不再被静默丢弃
- 骰子面数校验统一：`roll(2d6)` 等非法表达式不再被当作 1d6 静默掷骰；`RollStore.roll` 防御非法面数
- 舞台分节解析：同一角色出现重复分节时追加合并，不再后者覆盖前者
- 记忆权重升级保留原 `id` / `createdAt`（不再新建对象丢弃身份信息）
- Markdown 无序列表续行合并失效：带续行的列表此前退化为纯文本，现按注释语义正确合并（`- 首行\n续行` 的续行并入列表项）

### 🚀 增强

- 流式输出性能：单/多角色叙事页改为窄监听，`streamingContent` 变化只重建消息流区域，AppBar / 输入栏 / 状态条 / 仪表盘不再整页重建
- 消息气泡按内容缓存（`_CachedBubble`），流式期间历史消息不再重复执行 Markdown 解析
- Markdown 渲染正则全部预编译为 `static final`；流式滚动改为 `jumpTo` 直落底部（消除逐 chunk 动画追尾抖动）
- 消息操作菜单按需构造（菜单触发时才构建，不再每次 build 生成）
- 首页契约列表惰性化：`ContractTreeSection` 由一次性构建改为 `ListView.builder` 懒构建，契约库上百时首帧 build 与内存不再 O(N)、滚动懒加载
- 系统提示词静态前缀缓存：角色/世界观/背景等静态层按指纹缓存复用（同一契约多轮生成免重复拼接），动态层（状态/记忆/规则/此刻）照旧每轮拼接
- 无障碍增强：状态条/角色状态芯片合并读屏语义（一次朗读而非逐段朗读 emoji）；消息气泡菜单入口暴露按钮语义；舞台角色气泡合并语义；附件移除按钮 / 角色芯片热区扩大至 ≥32px

### 🧹 重构

- 流式样板提取为 `StreamingCoordinator` mixin、生成收尾编排提取为 `GenerationCoordinator.runGeneration`；叙事页共享骨架 `NarrativeScaffold`、LLM 消息列表构建 `buildLlmMessageList` 抽取复用
- 舞台存档恢复提取为 `_restoreRoleSaves`；气泡视觉常量、记忆权重/运算符正则下沉共享定义
- 契约信息缓存治理：模块级全局 `Map` 迁移为 Riverpod Provider（`contractInfoCacheProvider`）
- 叙事 Reducer 的 `ReplySucceeded` 三次链式 `copyWith` 合并为单次调用
- 移除 `faust.utopia.meph`；收紧 `faust.imperial.meph` / Kurukshetra 高频 LLM 指令触发条件
- 记忆管理 LLM 失败日志携带完整堆栈（原仅 `$e` 无法定位角色/配置/阶段）
- 主题令牌收敛：补齐 `textTheme` 档位（`titleSmall` / `bodySmall` / `labelSmall`），收敛散落的 11/12/13px 字号魔数与硬编码颜色；兜底提示条颜色随明暗主题联动（新增 `AppTheme.warning*` / `onGold` / `onCrimson` 令牌）

### 🔧 工程化

- 测试覆盖增强（+45 用例，总计 512）：
  - 新增 ZIP 打包/导入边界测试（`contract_pack_test.dart`）
  - 新增存档命名规则独立测试（`meph_file_name_test.dart`）
  - 补 Markdown 渲染边界、舞台分节重复标题合并回归测试
  - 新增无障碍语义测试（`accessibility_test.dart`：合并读屏语义 / 按钮语义 / 热区尺寸）
  - 新增提示词静态前缀缓存行为测试（命中 / 动态段隔离 / key 不串 / 约束失效）
  - 核心组件 UI 黄金基准（`component_golden_test.dart`）
- 工程基建：`tool/validate_l10n.py`（zh/en .arb 键一致性断言，接入 CI）；`tool/coverage_summary.py` + CI coverage job（覆盖率仪表盘，不设硬门槛）

### 📚 文档

- 规则书写指南新增**反模式 8：LLM 指令触发条件过宽 → 高频误触发**（含 `faust.imperial.meph` / Kurukshetra 真实修复案例）
- README / README.en 内置契约列表补充示范子版说明；docs 内置模板与文档中心同步更新

<details>
<summary>## [1.4.0] - 多模型路由 · 首页信息密度优化 · 消息操作 · Markdown 渲染 · 流式性能提升</summary>

### ✨ 新特性

- 辅助任务模型（多模型路由）：设置页新增「⚙ 辅助任务模型」分区，可独立配置记忆提取 / 压缩使用的模型，默认关闭（所有任务共用主配置），API Key / Base URL 留空时继承主配置，API Key 安全存储到系统密钥链，主叙事不受影响
- 消息长按/右键操作菜单：复制 / 重新生成（「重新生成」自动以原指引重新发送）
- 叙事文本自研轻量 Markdown 渲染：**粗体**、_斜体_、标题、引用、列表、`行内代码`（零外部依赖）
- 单角色契约改单行紧凑卡片，树形嵌套 → 角色名 + 「分支 · N」入口 + 文件名，分支选择器点选直达
- 多角色舞台改单行卡片 + 角色芯片，色点 + 角色名 + 💾 存档徽标，点芯片直达，长按芯片弹出快捷菜单

### 🐛 修复

- 孤儿链深层子版丢失：通过「中间前缀父子关系」推导修复
- 超深文件名链栈溢出：递归截断改为直接返回叶子节点

### 🚀 增强

- 多模型路由：`MemoryManager.extract / compress / extractForRoles` 增加 `auxConfig` 参数，经 `LlmAuxConfig.resolve(mainConfig)` 合并缺省字段，单角色与多角色 Notifier 均已透传，记忆提取 / 压缩自动走独立模型
- 消息菜单收敛：移除「删除」项（「重新生成」仍通过 `MessageDeleted(cascadeFate: true)` 复用删除式状态迁移）
- 流式输出 StringBuffer 优化，消除长叙事下 O(n²) 字符串拼接开销
- 系统提示词末尾去重：单角色与舞台不再完整重复约束全文，每轮节省约 200-300 token
- 舞台分节失败自动降级：LLM 输出无法分节/提及归属时，逐角色独立调用生成，保障多角色回复不丢失
- 首页「最近编辑」抽成 memoized Provider，避免重复 IO；同步文件 IO 改异步；RegExp 预编译

### 🧹 重构

- 新增 `LlmAuxConfig` 模型类（enabled / model / baseUrl / apiKey / maxTokens / timeoutSeconds），含 `resolve()` 便捷继承方法
- `GenerationSettings` 聚合新增 `auxLlmConfig` 字段，与主配置统一传给 Notifier
- 共享 API Key 读取逻辑（`_readApiKey`）抽为可复用方法，主/辅助 Key 统一处理迁移
- `SessionSaver` 与 `ChildSaveStore` 合并，删除过度封装层，存档逻辑直接并入 `ChildSaveStore`
- 存储键统一收敛，新增 `constants/storage_keys.dart` 集中管理
- 跨平台路径分隔符统一，改用 `path` 包 `p.basename()`；舞台角色 key 分隔符改为 `\u001F`
- 契约树构建抽离独立模块 `contract_tree_builder.dart`，纯函数从 `contract_provider.dart` 迁出
- `Contract` / `StateItem` / `Rule` / `HistoryEntry` 迁移 `@freezed`，消除手写样板约 150 行，支持嵌套 copyWith 级联

### 🔧 工程化

- 新增 3 条 lint 规则：`prefer_single_quotes` / `unnecessary_brace_in_string_interps` / `avoid_types_on_closure_parameters`
- 测试新增：辅助配置持久化 round-trip（未设置 null / 保存读取 / 清除回退）、`LlmAuxConfig.resolve` 字段继承与覆盖规则
- `StateValue` 四子类添加 `toString()`，调试打印显示实际值
- `home_screen_test.dart` 重写匹配新 UI（10 用例）；`rename_contract_dialog_test.dart` 适配真实异步 IO（8 用例）；`contract_provider_test.dart` 新增孤儿节点 + 深度守卫边界用例

</details>

<details>
<summary>## [1.3.0] - 新内置契约 · Android 正式签名 · 多角色舞台 · 界面与代码精简</summary>

### ✨ 新特性

- 内置契约扩充：joan_of_arc.meph（贞德·达尔克，天启时期，信仰/士气/生命体系）、arthur_sword.meph（少年亚瑟，石中剑时刻，王权之证/信心/悔意体系）、gilgamesh.meph（吉尔伽美什，恩奇都之死后，王权/求索/哀恸体系）、Camlann/ 舞台（卡姆兰之战，亚瑟王 × 莫德雷德父子对决）
- 多角色舞台系统，数据层（子目录 = 舞台）→ 生成管线（单次 LLM → 分节解析 → 各角色规则引擎独立运行）→ 独立存档 → 角色着色气泡 → 首页聚合卡
- Android 正式签名，release 签名密钥 + 缺失时优雅降级 debug 签名
- 契约 ZIP 导出/导入，命运树（母版 + 子版）与舞台目录一键打包 / 自动解压还原
- 记忆写回即存档，记忆提取完成立即持久化
- 首页最近编辑，快捷入口 + 按子树最近编辑时间排序
- LLM 超时 / 重试可配置 + 非流式 JSON 响应兜底

### 🐛 修复

- 记忆提取竞态，提取期间新记忆不再被旧结果覆盖，超限按权重取舍
- 文件监听阻塞，内容校验改异步读取，不再卡顿界面
- 自定义契约缺失/损坏时叙事页顶部警告条不再静默缺失
- narrative_provider 测试时序竞态，容器销毁前 flush 微任务，消除随机超时

### 🚀 增强

- 流式输出优化，气泡增量渲染 + 打字机光标
- 提示词构建加速，记忆排序去重 + DSL 关键字正则预编译
- 同步文件 IO 改异步，消除磁盘 IO 在 UI 线程的阻塞隐患

### 🧹 重构

- 界面与代码精简，首页分支树 / 契约卡 / 消息气泡去冗余结构
- 存档菜单精简，删除「保存当前进度」（每轮自动存档已覆盖），保留「另存为分支 / 删除存档」
- 共享工具抽取，文件名解析 / `relative_time` / 魔法值清理

### 🔧 工程化

- 新增 GitHub Actions CI，三平台 analyze + test
- `flutter_secure_storage` 9.2.4 → 11.0.0，系统级 API Key 加密存储
- 内置模板注册，3 个新单角色 + Camlann 舞台 + pubspec 资产声明
- 测试新增 5 份契约解析 + 种子更新，总数 459 个

### 📚 文档

- README / README.en 内置契约列表与平台风险说明更新
- docs/platform-storage 新增「卸载风险与备份指引」

</details>

<details>
<summary>## [1.2.0] - 上下文窗口 · 记忆权重体系 · 编辑器健壮性 · API Key加密</summary>

### ✨ 新特性

- 历史消息窗口，设置页可选 20/40/60/全部（默认 40），控制 LLM 上下文长度
- 记忆权重体系，1-5 权重（5 核心 / 4 重大 / 3 一般 / 2 次要 / 1 边缘），`[权重]` 前缀标记，≥4 永不压缩
- 记忆权重自动分配，提取提示词输出 `- [权重] 内容`，自动记忆共享权重体系
- 记忆注入上限，设置页 10/20/30/全部（默认 20），超限高权重优先
- 记忆热重载，规则 + 记忆双区块热更新，改 `[N]` 前缀保存即生效
- 记忆权重持久化，serialize 始终输出 `[N]` 前缀，旧格式自动补 `[3]`
- 编辑器保存冲突检测，保存时提示「覆盖 / 重新加载 / 取消」，防静默丢失
- 设置页响应式，窄屏「分区入口 + 子页」，宽屏单页，区块延迟实例化
- 图标风格统一（浮士德契约风），设置「测试连接」替换现代科技感图标，记忆注入上限 4 档改用「书卷渐进」（书签 → 手稿 → 魔法书页 → 星光灌注），强化中古契约意象

### 🐛 修复

- Equatable 测试污染，props 仅按内容值比较，去掉 id / timestamp
- 文件监听 cancel，清除 mtime 抑制记录，重绑首轮热重载不再误抑制
- 外部修改母版不生效，监听目标扩为「源文件 + 母版」，按实际变化文件名过滤
- mtime 抑制按文件名独立记录，子版存档仍抑制，母版修改不误拦截
- 骰子 1d2 安科判定，默认「1 成功 / 2 失败」，verdict 改两档
- 【角色背景】缺失，`ContractPanel` 补齐 `Contract.background`
- 序列化空行，`_compactBlankLines()` 压缩连续空行
- 存档恢复失败，SnackBar 明确提示，不再静默空会话
- 流式竞态，同步标志位 + 状态双保险，防连点重复生成

### 🚀 增强

- 去重权重升级，新权重更高时升级旧记忆，永不降级
- 高权重上限，`highImportanceCap = 15`，超限降级压缩防 token 失控
- LLM 网络重试，三类网络异常统一指数退避
- 文件监听异常防护，回调失败仍恢复监听，防死循环
- API Key 安全最佳实践，设置页新增「从剪贴板导入」按钮，避免手输时 Key 残留剪贴板，README 补充泄露防护指南
- API Key 改用系统密钥链存储，引入 `flutter_secure_storage`，持久化到系统级安全存储（Android Keystore / iOS·macOS Keychain / Windows DPAPI / Linux libsecret），旧明文在首次读取时自动迁移，密钥链不可用时优雅降级 SharedPreferences 明文（功能不受损）

### 🧹 重构

- HomeScreen 用 `ListenableBuilder` 监听，消除 6 处 setState
- `copyWith` 无变化短路，减少无谓通知
- LLM 请求重试，连接超时指数退避，流式中途/业务错误不重试
- 记忆提取解耦，自动保存先行，异步提取 + 30s 超时
- 条件编译缓存，契约切换自动清除旧 AST
- 解析性能，高频正则提为常量，`depth` 惰性缓存
- 服务复用，`NarrativeTurnService` / `MemoryManager` 全局单例
- UI 首帧，监听绑定移入 `initState`
- 记忆排序复用，统一接入 `sortByImportance()`
- 首页缓存，预计算 `allInfos`，避免重复递归
- 文件检查，内存 Set 替代多次 `existsSync()`

### 🔧 工程化

- 确认 `flutter gen-l10n` 工作流与 ARB 一致
- 移除应用内记忆编辑 UI，统一「编辑器改 `[N]` 前缀」
- 新增测试，文件监听、窗口档位、本地兜底、LLM 重试、记忆权重、记忆热重载、设置页响应式
- 测试总数 290 个，新增 LLM 配置加密存储 / 明文迁移 / 降级测试
- 新增 `build-macos-ios` job，push/PR 验证 `flutter build macos --release` 与 `flutter build ios --release --no-codesign`
- 构建配置断言扩至 15 项，`validate_build_config.py` 增加 macOS/iOS 构建步骤存在性校验
- README 平台声明同步，macOS / iOS 从「从未编译运行」更新为「CI 编译通过，未真机运行」

</details>

<details>
<summary>## [1.1.0] - 规则热重载 · 国际化 · 文档</summary>

### ✨ 新特性

- 规则热重载，编辑器或 VSCode 保存 `.meph` 仅规则即时生效，人格锁定，运行态全保留
- 停止生成，生成中可点「停止」中断流式读取，已累积内容保留并收尾存档
- 界面国际化，中英文切换（设置页可选，偏好持久化），替换约 150 处硬编码中文
- 命运树可视化，母版为树根、子版沿金色主干生长
- 命运一句话，另存分支可填命运说明，以 `@命运` 区块独立存储
- 官方示范子版，新增 `dantes.bonapart.meph`、`faust.utopia.meph`
- 英文文档，新增 `README.en.md` 与 docs 全部 6 篇英文文档

### 🐛 修复

- LLM 配置缓存，`autoDispose` + 发送时强制重读，改 Key 无需重启
- 开局场景卡片移除合成斜体
- 国际化补全，首页品牌 + Provider 硬编码中文全量迁入 ARB
- 打开子版存档直接定位最新消息
- 滚动图标改垂直双箭头

### 🚀 增强

- 条件编译缓存加 LRU 容量上限
- LLM 错误响应体限 8KB 截断
- 契约目录扫描改异步，消除 UI 阻塞
- 文件监听不可用显示提示，不静默降级
- 契约列表并行读取（`Future.wait`）

### 🧹 重构

- `historyToMessages` 抽为共享纯函数
- 文件监听抽为 `ContractFileWatcher` 独立类
- LLM 配置文案全量迁 ARB，executor 用 switch 表达式
- 流式节流简化为一次性 Timer
- 新增共享测试助手
- 移除 Riverpod legacy API，统一 `debugPrint`

### 🔧 工程化

- Windows 移除 zip 整包，仅保留安装器
- 新增 `validate_build_config.py` + actionlint 检查
- 测试数提升至 221 个

### 📚 文档

- README 补充中英文赞助区块，修复收款码路径

</details>

<details>
<summary>## [1.0.0] - 首个正式发布</summary>

### ✨ 新特性

- 核心叙事：单轮管线（规则引擎 → 提示词 → LLM 流式 → 本地兜底）、系统提示词七层、SSE 流式 + 50ms 节流、骰子「命运结算」卡片（骰值 / 阈值 / 成败 / 诗意文案）
- 契约系统：`.meph` 词法解析（区块白名单、草稿宽容、精确报错）、序列化可逆（用于子版存档）、实时校验（400ms 防抖、错误定位行号）、一键格式化、契约 CRUD（导入/删除/重命名级联）、缺失/损坏自动回退内置模板并顶部提示
- 规则与记忆：两阶段规则执行（被动批量 + 主动互斥）、互斥组 `[group:xxx]`、条件 AST 缓存、骰子 `roll(1d2)` / `roll(1d100)` 阈值比较、记忆管理（每 N 轮提取、去重、超限压缩）
- 会话与存档：母版只读 + 子版快照、自动存档每轮覆盖、子版恢复 / 删除 / 列表（树状层级）、附加上下文（txt / md / meph 注入 LLM）
- 界面与适配：契约目录平台自适应、Android 内外存储切换、桌面三平台 1280×720 局中、内容宽度档位、双主题 + NotoSerifSC、iOS ATS 本地网络放行

### 🔧 工程化

- 191 个测试全链路覆盖
- CI：三平台 `flutter analyze` + `flutter test`

### 🖥 平台验证声明

> 个人维护，受硬件 / 账号限制，macOS 与 iOS 仅代码适配、从未编译运行。
> ✅ Windows / Linux（含原生编译）/ Android 已验证；
> ⚠️ macOS / iOS 仅代码适配；⛔ 纯血鸿蒙不支持。详见 README「平台支持与测试声明」。

</details>
