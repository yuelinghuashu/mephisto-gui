# 💾 平台存储策略

> Mephisto 的契约（`.meph`）存储在「契约目录」中。不同平台的存储方案受系统
> 沙盒机制与权限模型约束，这里的说明帮助你理解契约文件的真实存放位置。

## 1. 各平台契约目录

| 平台    | 默认契约目录                                                                 | 可自定义？                 |
| ------- | ---------------------------------------------------------------------------- | -------------------------- |
| 桌面端  | `~/Mephisto/contracts`（Linux/macOS 用 `$HOME`，Windows 用 `%USERPROFILE%`） | ✅ 任意路径                |
| Android | 应用私有目录（路径含应用包名 `yuelinghuashu.mephisto`，见下方完整路径）      | ❌ 仅在内部/外部沙盒间切换 |
| iOS     | 应用文档目录（沙盒）`.../Documents/Mephisto/contracts`                       | ❌ 系统沙盒限制            |

## 2. 优先级

```
用户自定义目录（shared_preferences 中 'mephisto_contracts_directory'）
  ↓ 未设置时
默认目录（平台自适应的默认位置）
```

## 3. 桌面端（Windows / macOS / Linux）

- **可自由指定任意目录**：设置页通过系统目录选择器（`getDirectoryPath`）选择
- 默认使用用户主目录下的 `~/Mephisto/contracts`，保证与旧版本路径一致
- 目录不存在时自动创建
- 可打开文件夹浏览契约文件

## 4. Android

### 两种存储位置（均为应用私有）

| 选项     | 实际位置                     | 特点                         |
| -------- | ---------------------------- | ---------------------------- |
| 内部存储 | 应用专用分区（默认）         | 占用系统内部空间，卸载清除   |
| 外部存储 | `Android/data/<包名>/files/` | 占用设备大容量分区，卸载清除 |

### 完整路径示例（包名 = `yuelinghuashu.mephisto`）

> 你可能在设置页看到路径中出现 `yuelinghuashu.mephisto`——这是**正常的**。
> Android 系统强制所有应用数据存放在**以应用包名（applicationId）命名的私有目录**下，
> 这是系统沙盒机制，应用无法更改。

- **内部存储**：`/data/user/0/yuelinghuashu.mephisto/app_flutter/Mephisto/contracts`
  - `/data/user/0/yuelinghuashu.mephisto/` 是系统为应用分配的私有数据目录（以包名命名）
  - `Mephisto/contracts` 是应用在其中自建的契约子目录
- **外部存储**：`/storage/emulated/0/Android/data/yuelinghuashu.mephisto/files/Mephisto/contracts`
  - `Android/data/yuelinghuashu.mephisto/` 是系统为应用分配的外部私有目录（以包名命名）
  - `Mephisto/contracts` 是应用在其中自建的契约子目录

> 无论是哪种存储，应用实际存放契约的目录名都是 `Mephisto/contracts`；
> 外层 `yuelinghuashu.mephisto` 目录由 Android 系统按包名自动创建，是所有 Android 应用的统一规则。

### 为什么无法自由指定目录？

- Android 11+（API 30）强制**作用域存储**：`dart:io` 无法直接读写用户公共目录（下载、文档、SD 卡）
- 系统文件选择器（SAF）只能做一次性选择，无法获得任意目录的常驻读写权限
- 因此 Android 仅在「内部沙盒 ↔ 外部存储」之间切换，二者都是应用私有目录

### 存储标记

- `mobile_external` 标记保存在 shared_preferences 中
- 切换后所有契约 CRUD（导入/加载/保存）自动指向新位置
- 旧的契约文件不会自动迁移（切换时需注意备份）

## 5. iOS

- **系统沙盒限制**：契约仅保存在应用文档目录
- 卸载应用即清除全部契约数据
- 设置页的「更改目录」会提示沙盒限制（如实告知，不隐藏）

## 6. 内置模板种子

首次启动（或首次切换契约目录）时，从 assets 复制内置模板：

- 内置模板：`assets/contracts/faust.meph`、`dantes.meph`
- 种子标记按目录绑定（`mephisto_contracts_seeded_<目录路径>`），避免新目录为空
- `force: true` 时强制恢复缺失的内置模板（空状态兜底按钮）

## 7. 相关代码

- `lib/services/storage/contract_dir.dart`：目录解析、种子、外部存储切换
- `lib/services/storage/contract_repo.dart`：契约文件的 CRUD 与文件名校验
- `lib/providers/contract_provider.dart`：契约加载与回退策略
