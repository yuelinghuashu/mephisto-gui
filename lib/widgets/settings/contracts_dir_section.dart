import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mephisto/l10n/app_localizations.dart';

import '../../services/storage/contract_dir.dart';
import 'section_card.dart';

/// 契约目录设置区块（平台自适应）
///
///   - Android：内部沙盒 ↔ 应用外部存储切换
///   - iOS：点击如实提示（沙盒限制）
///   - 桌面端：系统目录选择器 + 打开文件夹
///
/// 从 settings_screen.dart 拆分而来，使页面聚焦组装。
class ContractsDirSection extends StatefulWidget {
  const ContractsDirSection({super.key});

  @override
  State<ContractsDirSection> createState() => _ContractsDirSectionState();
}

class _ContractsDirSectionState extends State<ContractsDirSection> {
  String? _contractsDirPath;

  /// 当前是否使用 Android 外部存储（仅 Android 可能为 true）
  bool _useExternalStorage = false;

  @override
  void initState() {
    super.initState();
    _loadContractsDir();
  }

  /// 加载当前契约目录路径 + 外部存储状态
  Future<void> _loadContractsDir() async {
    final dir = await getContractsDirectory();
    final useExternal = await isUsingMobileExternalStorage();
    if (mounted) {
      setState(() {
        _contractsDirPath = dir.path;
        _useExternalStorage = useExternal;
      });
    }
  }

  /// 选择新的契约目录（桌面端：系统目录选择器）。
  Future<void> _changeContractsDir() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    // 打开系统目录选择器
    final selected = await getDirectoryPath(
      initialDirectory: _contractsDirPath,
    );

    if (selected == null || selected.isEmpty) return; // 用户取消

    // 保存新目录
    final ok = await setContractsDirectory(selected);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsDirChangeFail)),
      );
      return;
    }

    // 刷新显示 + 提示
    await _loadContractsDir();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsDirChanged(selected))),
    );
  }

  /// iOS：「更改目录」提示（iOS 系统沙盒限制，仅应用内目录）。
  void _iosChangeContractsDir() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).settingsIosSandboxNotice),
      ),
    );
  }

  /// Android：切换「内部沙盒 ↔ 应用外部存储」。
  Future<void> _toggleMobileStorage() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final enabled = await setMobileExternalStorage(!_useExternalStorage);
    if (!enabled) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsStorageSwitchFail)),
      );
      return;
    }
    await _loadContractsDir();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _useExternalStorage
              ? l10n.settingsStorageExternalSwitched
              : l10n.settingsStorageInternalSwitched,
        ),
      ),
    );
  }

  /// 用系统文件管理器打开契约文件夹（仅桌面端可用）。
  Future<void> _openContractsDir() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final dir = await getContractsDirectory();

    if (!dir.existsSync()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsDirNotExist)));
      return;
    }

    // Linux 用 xdg-open，macOS 用 open，Windows 用 explorer
    // 移动端沙盒目录不可由用户直接浏览，此操作仅桌面端提供
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [dir.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [dir.path]);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.settingsPlatformNotSupported)),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsOpenFolderFail('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (defaultTargetPlatform) {
          TargetPlatform.android => l10n.settingsAndroidDirDescription,
          TargetPlatform.iOS => l10n.settingsIosDirDescription,
          _ => l10n.settingsDesktopDirDescription,
        }, style: theme.textTheme.labelLarge),
        const SizedBox(height: 12),

        // ---- 羊皮纸卡片容器 ----
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前路径显示（始终显示真实完整路径，不隐藏）
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contractsDirPath ?? l10n.settingsDirLoading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  // 移动端附加上下文说明（不替代路径，仅补充解释）
                  if (defaultTargetPlatform == TargetPlatform.android) ...[
                    const SizedBox(height: 4),
                    Text(
                      _useExternalStorage
                          ? l10n.settingsAndroidExternalLocation
                          : l10n.settingsAndroidInternalLocation,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                  if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsIosLocation,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              switch (defaultTargetPlatform) {
                // ---- Android：内部沙盒 ↔ 外部存储切换 ----
                TargetPlatform.android => Row(
                  children: [
                    Expanded(
                      child: Text(
                        _useExternalStorage
                            ? l10n.settingsAndroidExternalStorage
                            : l10n.settingsAndroidInternalStorage,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: Icon(
                        _useExternalStorage
                            ? Icons.storage_outlined
                            : Icons.sd_card_outlined,
                      ),
                      label: Text(
                        _useExternalStorage
                            ? l10n.settingsSwitchToInternal
                            : l10n.settingsSwitchToExternal,
                      ),
                      onPressed: _toggleMobileStorage,
                    ),
                  ],
                ),
                // ---- iOS：点击如实提示（沙盒限制，不隐藏） ----
                TargetPlatform.iOS => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: Text(l10n.settingsChangeDir),
                      onPressed: _iosChangeContractsDir,
                    ),
                  ],
                ),
                // ---- 桌面端：系统目录选择器 + 打开文件夹 ----
                _ => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: Text(l10n.settingsChangeDir),
                      onPressed: _changeContractsDir,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.settingsOpenFolder),
                      onPressed: _openContractsDir,
                    ),
                  ],
                ),
              },
            ],
          ),
        ),
      ],
    );
  }
}
