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

```text
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

### 卸载风险与备份指引

> ⚠️ **Android 上卸载应用会一并清除全部契约与存档（母版 `.meph`、子版 `*.child.meph`、自定义分支），且无法恢复。**
> 在「未配置正式签名 → 升级需先卸载再安装」期间，务必先备份：

1. **切换外部存储**：在设置页将契约目录切换到「外部存储」模式
   （内部存储路径 `/data/user/0/...` 需 root 才能访问，外部存储路径可通过文件管理器访问）
2. **备份文件**：通过手机文件管理器或 **USB 连接电脑（MTP 模式）**，打开
   `/storage/emulated/0/Android/data/yuelinghuashu.mephisto/files/Mephisto/contracts`
   ，将其中**所有 `.meph` 文件**复制到安全位置（下载目录、电脑、云盘）
3. **恢复数据**：安装新版本后，使用首页**「导入」**功能重新导入备份的 `.meph` 文件
   - 子版存档（`*.child.meph` / 自定义分支）与普通契约同为 `.meph` 文件，导入即可完整恢复
   - 分支标签（`@命运` 系统区块）也会一并保留

## 5. iOS

- **系统沙盒限制**：契约仅保存在应用文档目录
- 卸载应用即清除全部契约数据
- 设置页的「更改目录」会提示沙盒限制（如实告知，不隐藏）

## 6. 内置模板种子

首次启动（或首次切换契约目录）时，从 assets 复制内置模板：

- **内置单角色契约**（`assets/contracts/`）：
  - `faust.meph`（浮士德）
  - `dantes.meph`（基督山伯爵）
  - `joan_of_arc.meph`（贞德）
  - `arthur_sword.meph`（少年亚瑟）
  - `gilgamesh.meph`（吉尔伽美什）
  - `dantes.bonapart.meph`（基督山伯爵 × 波拿巴党卧底 if 线，预置示范子版）
  - `faust.imperial.meph`（浮士德 × 帝国金殿 / 权柄幻象 if 线，预置示范子版）
- **内置舞台**（多角色目录，`assets/contracts/<舞台名>/`）：
  - `Kurukshetra/`：`Arjuna.meph` + `Karna.meph`（俱卢之野）
  - `Camlann/`：`Arthur.meph` + `Mordred.meph`（卡美洛之陨）
- 种子标记按目录绑定（`mephisto_contracts_seeded_<目录路径>`），避免新目录为空；
  已种子过的目录**不再自动恢复**被用户删除的模板（尊重用户删除），仅 `force: true`
  强制恢复缺失的内置模板（空状态兜底按钮），且不覆盖用户已有文件

## 7. 相关代码

- `lib/services/storage/contract_dir.dart`：目录解析、种子、外部存储切换
- `lib/services/storage/contract_repo.dart`：契约文件的 CRUD 与文件名校验
- `lib/providers/contract_provider.dart`：契约加载与回退策略
