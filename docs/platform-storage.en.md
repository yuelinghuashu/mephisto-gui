# 💾 Platform Storage Strategy

> Mephisto's contracts (`.meph`) are stored in a "contract directory." Storage schemes differ across platforms
> due to system sandbox mechanisms and permission models; this documentation helps you understand where contract files actually reside.

> **中文版：[简体中文](platform-storage.md)**

## 1. Contract Directory by Platform

| Platform | Default Contract Directory                                                                            | Customizable?                                    |
| -------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| Desktop  | `~/Mephisto/contracts` (Linux/macOS uses `$HOME`, Windows uses `%USERPROFILE%`)                       | ✅ Any path                                      |
| Android  | App private directory (path contains app package name `yuelinghuashu.mephisto`, see full paths below) | ❌ Only switch between internal/external sandbox |
| iOS      | App documents directory (sandbox) `.../Documents/Mephisto/contracts`                                  | ❌ System sandbox restriction                    |

## 2. Priority

```text
User-customized directory (stored under 'mephisto_contracts_directory' in shared_preferences)
  ↓ if not set
Default directory (platform-adaptive default location)
```

## 3. Desktop (Windows / macOS / Linux)

- **Any directory can be freely specified**: choose via the system directory picker (`getDirectoryPath`) on the settings page
- Defaults to `~/Mephisto/contracts` under the user home directory, keeping the path consistent with older versions
- The directory is auto-created if it does not exist
- The folder can be opened to browse contract files

## 4. Android

### Two Storage Locations (both app-private)

| Option           | Actual Location                  | Characteristics                                          |
| ---------------- | -------------------------------- | -------------------------------------------------------- |
| Internal storage | App-specific partition (default) | Uses system internal space, cleared on uninstall         |
| External storage | `Android/data/<package>/files/`  | Uses device mass storage partition, cleared on uninstall |

### Full Path Examples (package = `yuelinghuashu.mephisto`)

> You may see `yuelinghuashu.mephisto` in paths on the settings page—this is **normal**.
> Android forces all app data to be stored in a **private directory named after the app package name (applicationId)**,
> a system sandbox mechanism that apps cannot change.

- **Internal storage**: `/data/user/0/yuelinghuashu.mephisto/app_flutter/Mephisto/contracts`
  - `/data/user/0/yuelinghuashu.mephisto/` is the system-assigned private data directory (named after the package)
  - `Mephisto/contracts` is the contract subdirectory the app creates within it
- **External storage**: `/storage/emulated/0/Android/data/yuelinghuashu.mephisto/files/Mephisto/contracts`
  - `Android/data/yuelinghuashu.mephisto/` is the system-assigned external private directory (named after the package)
  - `Mephisto/contracts` is the contract subdirectory the app creates within it

> Regardless of storage type, the directory name where the app actually stores contracts is always `Mephisto/contracts`;
> the outer `yuelinghuashu.mephisto` directory is auto-created by the Android system based on the package name—a uniform rule for all Android apps.

### Why Can't the Directory Be Freely Specified?

- Android 11+ (API 30) enforces **scoped storage**: `dart:io` cannot directly read/write user public directories (Downloads, Documents, SD card)
- The system file picker (SAF) only provides one-time selection, not persistent read/write access to arbitrary directories
- Therefore, Android only switches between "internal sandbox ↔ external storage", both of which are app-private directories

### Storage Marker

- The `mobile_external` marker is stored in shared_preferences
- After switching, all contract CRUD (import/load/save) automatically points to the new location
- Old contract files are **not auto-migrated** (back up before switching)

### Uninstall Risk & Backup Guide

> ⚠️ **Uninstalling the app on Android wipes all contracts and saves with no way to recover them**
> (master `.meph`, child saves `*.child.meph`, custom branches).
> While production signing is not configured and upgrades require "uninstall then install", please back up first:

1. **Switch to external storage**: switch the contract directory to **"External Storage"** mode on the settings page
   (the internal-storage path `/data/user/0/...` requires root to access; the external-storage path is accessible via file managers)
2. **Back up the files**: via a phone file manager or **USB connection to a computer (MTP mode)**, open
   `/storage/emulated/0/Android/data/yuelinghuashu.mephisto/files/Mephisto/contracts`
   and copy **all `.meph` files** to a safe location (Downloads folder, computer, cloud drive)
3. **Restore the data**: after installing the new version, use the **"Import"** button on the home page to re-import the backed-up `.meph` files
   - Child saves (`*.child.meph` / custom branches) are the same `.meph` files as contracts, so importing restores them completely
   - Branch labels (the `@命运` system section) are preserved as well

## 5. iOS

- **System sandbox restriction**: contracts are only stored in the app documents directory
- Uninstalling the app clears all contract data
- The "Change Directory" button on the settings page will inform you of the sandbox restriction (honest disclosure, not hidden)

## 6. Built-in Template Seeding

On first launch (or first switch to a new contract directory), built-in templates are copied from assets:

- **Built-in single-character contracts** (`assets/contracts/`):
  - `faust.meph` (Faust)
  - `dantes.meph` (Edmond Dantès)
  - `joan_of_arc.meph` (Joan of Arc)
  - `arthur_sword.meph` (Young Arthur)
  - `gilgamesh.meph` (Gilgamesh)
  - `dantes.bonapart.meph` (Dantès × Bonapartist mole if-line, pre-seeded demo child)
  - `faust.imperial.meph` (Faust × Imperial Court / Illusion of Power if-line, pre-seeded demo child)
- **Built-in stages** (multi-character directories, `assets/contracts/<stage name>/`):
  - `Kurukshetra/`: `Arjuna.meph` + `Karna.meph` (Kurukshetra)
  - `Camlann/`: `Arthur.meph` + `Mordred.meph` (The Fall of Camlann)
- The seeding marker is bound to the directory (`mephisto_contracts_seeded_<directory path>`), preventing a new directory from being empty;
  an already-seeded directory will **not auto-restore** templates the user deleted (respecting user deletion);
  only `force: true` forcibly restores missing built-in templates (the empty-state fallback button), and it never overwrites existing user files

## 7. Related Code

- `lib/services/storage/contract_dir.dart`: directory resolution, seeding, external storage switching
- `lib/services/storage/contract_repo.dart`: contract file CRUD and file name validation
- `lib/providers/contract_provider.dart`: contract loading and fallback strategy
