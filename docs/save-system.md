# 💾 存档系统（子版机制）

> Mephisto 采用「母版只读 + 子版快照」的存档模型：母版契约是固定的「灵魂框架」，
> 每次运行产生的对话、状态变化、记忆与历史，都以**子版文件**的形式保存为独立快照。

## 1. 核心概念

| 概念 | 说明 |
| ---- | ---- |
| **母版** | 创作者定义的 `.meph` 契约（如 `faust.meph`），**永不改动** |
| **子版** | 运行时生成的完整快照（如 `faust.child.meph`），含母版全部数据 + 状态 + 记忆 + 历史 |
| **分支** | 用户自定义命名的子版（如 `faust.dark.meph`），表达不同的命运走向 |

## 2. 子版的构成

子版 = 母版全部数据 + 运行时状态变化 + 记忆 + 历史

序列化时注入三块运行时数据：

1. **【状态】**：运行时变化后的状态值（如灵魂完整度从 100 降到 60）
2. **【记忆】**：MemoryManager 提取的长期记忆
3. **【历史】**：本轮对话的完整历史消息（fate / assistant）

## 3. 命名规则

| 场景             | 文件名                          |
| ---------------- | ------------------------------- |
| 默认保存         | `faust.child.meph`              |
| 默认已存在       | `faust.child2.meph`（自动递增） |
| 自定义分支       | `faust.dark.meph`               |
| 自定义分支已存在 | `faust.dark2.meph`（自动递增）  |

- 子版与母版**存放在同一契约目录**，便于查找与管理
- 同名文件通过递增序号自动避免冲突

## 4. 常用操作

| 操作 | 说明 | 对应实现 |
| ---- | ---- | -------- |
| 保存 | 生成/覆盖子版文件（支持分支名或默认 `.child`） | `ChildSaveStore.save` |
| 恢复 | 从子版读取并解析为 Contract（失败返回 null） | `ChildSaveStore.restore` |
| 列出 | 列出某母版的所有子版（`baseName.*.meph` 排除母版） | `ChildSaveStore.listChildFiles` |
| 删除 | 删除单个子版文件 | `ChildSaveStore.delete` |
| 检查 | 判断子版文件是否存在 | `ChildSaveStore.exists` |

## 5. 首页 UI 中的子版

- 母版卡片可展开显示其所有子版
- 子版支持：进入叙事（恢复）、预览、重命名、删除
- 母版删除支持「级联删除」：连同其下所有子版一并删除

## 6. 重命名联动

母版重命名时，其下所有子版文件名前缀同步更新：

```
faust.meph → 歌德.meph
faust.child.meph → 歌德.child.meph   （前缀同步）
faust.dark.meph → 歌德.dark.meph
```

## 7. 相关代码

- `lib/services/session/child_save_store.dart`：子版存档核心实现
- `lib/services/session/session_saver.dart`：会话保存辅助
- `lib/services/parser/meph_serializer.dart`：契约序列化（注入运行时数据）
- `lib/services/parser/meph_parser.dart`：契约解析（恢复）
