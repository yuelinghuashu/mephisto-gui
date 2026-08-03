# 📚 Mephisto 文档中心

> Mephisto（梅菲斯特）叙事引擎的深度文档。README 是总览，这里是与具体机制相关的完整参考。

## 📖 文档索引

| 文档                                | 内容                                             | 适用场景             |
| ----------------------------------- | ------------------------------------------------ | -------------------- |
| [契约语法参考](contract-syntax.md)  | `.meph` 文件完整格式：全部区块、值类型、错误处理 | 编写/编辑契约文件    |
| [规则引擎详解](rule-engine.md)      | 条件匹配、动作执行、骰子、互斥组的完整语法       | 设计角色行为规则     |
| [记忆系统](memory-system.md)        | 关键事件提取、摘要、超限压缩、长线一致性         | 理解叙事一致性的实现 |
| [存档系统](save-system.md)          | 母版/子版快照、分支命名、切换与恢复              | 理解子版存档机制     |
| [平台存储策略](platform-storage.md) | 各平台契约目录方案与沙盒限制                     | 理解跨平台存储行为   |

> 💡 编写与校验 `.meph` 契约，推荐搭配 **[VSCode Mephisto 插件](<(https://marketplace.visualstudio.com/items?itemName=yuelinghuashu.vscode-mephisto)>)**（语法高亮 / 自动补全 / 实时校验）。

## 🧭 导航关系

```text
README.md          ← 项目总览、快速开始（适合新用户）
├── docs/README.md ← 本索引（深度文档入口）
├── CHANGELOG.md   ← 版本历史
└── 各文档         ← 机制级细节
```
