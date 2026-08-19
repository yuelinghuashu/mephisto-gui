#!/usr/bin/env python3
"""Mephisto 构建配置静态断言。

在 CI 中执行，防止构建/打包层面的配置回归：
  1. AndroidManifest.xml 必须声明 INTERNET 权限（防止 Android Release 无法联网）
  2. iOS Info.plist 必须配置 ATS 本地网络（防止本地 Ollama 明文 HTTP 被拦截）
  3. release.yml 中 dpkg 版本号剥离必须同时处理 v/V 前缀（防止 dpkg 报错）
  4. ci.yml / release.yml 中关键步骤存在（ci 只承担代码检查 analyze/test，
     发布构建/打包全部归 release.yml，防止职责漂移或配置被误删）
  5. assets/contracts 下的舞台子目录必须在 pubspec.yaml 中显式声明
     （Flutter assets 不递归，漏声明会导致 rootBundle 加载舞台角色静默失败）
  6. 舞台子目录必须登记到 contract_dir.dart 的 _builtinStages
     （恢复内置角色/首次种子复制依赖它，漏登记会静默缺失）

用法：
  python3 tool/validate_build_config.py

退出码非 0 表示有断言失败。
"""

import os
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ANDROID_MANIFEST = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
IOS_INFO_PLIST = os.path.join(ROOT, 'ios', 'Runner', 'Info.plist')
RELEASE_WORKFLOW = os.path.join(ROOT, '.github', 'workflows', 'release.yml')
CI_WORKFLOW = os.path.join(ROOT, '.github', 'workflows', 'ci.yml')
PUBSPEC = os.path.join(ROOT, 'pubspec.yaml')
CONTRACTS_DIR = os.path.join(ROOT, 'assets', 'contracts')

failures: list[str] = []


def check(name: str, condition: bool, detail: str = '') -> None:
    """输出单个断言的 PASS/FAIL 结果。"""
    status = 'PASS' if condition else 'FAIL'
    print(f'[{status}] {name}' + (f' — {detail}' if detail else ''))
    if not condition:
        failures.append(name)


def check_android_internet() -> None:
    """AndroidManifest.xml 必须声明 INTERNET 权限。"""
    tree = ET.parse(ANDROID_MANIFEST)
    root = tree.getroot()
    ns = {'android': 'http://schemas.android.com/apk/res/android'}
    perms = [
        p.get('{http://schemas.android.com/apk/res/android}name')
        for p in root.findall('uses-permission')
    ]
    check(
        'Android 声明 INTERNET 权限',
        'android.permission.INTERNET' in perms,
        ', '.join(perms) if perms else '无权限声明',
    )


def check_ios_ats() -> None:
    """Info.plist 必须包含 ATS 本地网络配置（支持本地 Ollama）。"""
    try:
        with open(IOS_INFO_PLIST, 'rb') as f:
            plist = plistlib.load(f)
        ats = plist.get('NSAppTransportSecurity', {})
        check(
            'iOS 配置 ATS NSAllowsLocalNetworking',
            ats.get('NSAllowsLocalNetworking') is True,
            str(ats),
        )
    except Exception as e:  # noqa: BLE001
        check('iOS Info.plist 可解析', False, str(e))


def _strip_version_prefix(version: str) -> str:
    """与 release.yml 中 `${DEB_VERSION#[vV]}` 语义一致的去前缀函数。"""
    return re.sub(r'^[vV]', '', version)


def check_version_normalization() -> None:
    """dpkg 版本号规范化：v/V/无前缀输入都必须以数字开头。"""
    cases = {
        'v1.0.0': '1.0.0',
        'V1.0.0': '1.0.0',
        '1.2.3': '1.2.3',
        'V2.0.0-rc1': '2.0.0-rc1',
        'v1.0.0-beta.2': '1.0.0-beta.2',
    }
    all_ok = True
    for raw, expected in cases.items():
        actual = _strip_version_prefix(raw)
        ok = actual == expected and actual[0].isdigit()
        if not ok:
            all_ok = False
            print(f'  [FAIL] {raw} -> {actual}（期望 {expected}）')
    check('dpkg 版本号规范化 v/V', all_ok)


def check_release_workflow_version_pattern() -> None:
    """release.yml 必须使用 [vV] 版本剥离，而非只处理小写 v。"""
    with open(RELEASE_WORKFLOW, encoding='utf-8') as f:
        content = f.read()
    check(
        'release.yml 使用 [vV] 版本剥离',
        '#[vV]' in content,
        '需包含 ${DEB_VERSION#[vV]}',
    )


def check_assets_stage_dirs() -> None:
    """Flutter assets 不递归，舞台子目录必须在 pubspec.yaml 中显式声明。

    新增内置舞台（如 `assets/contracts/Kurukshetra/`）时若忘记在
    pubspec.yaml 的 `flutter.assets` 中声明，rootBundle 将无法加载
    舞台角色文件（运行时静默失败）。此断言在 CI 中强制同步声明。
    """
    # ---- 读取 pubspec.yaml 中 flutter.assets 列表 ----
    declared: list[str] = []
    in_flutter = False
    in_assets = False
    try:
        with open(PUBSPEC, encoding='utf-8') as f:
            for line in f:
                stripped = line.strip()
                if stripped == 'flutter:':
                    in_flutter = True
                    in_assets = False
                    continue
                if not in_flutter:
                    continue
                if stripped == 'assets:':
                    in_assets = True
                    continue
                if in_assets:
                    if stripped.startswith('- '):
                        declared.append(stripped[2:].strip().rstrip('/'))
                    elif stripped and not stripped.startswith('#'):
                        # 遇到下一个顶层键（如 fonts:）则结束 assets 段
                        in_assets = False
                        in_flutter = False
    except OSError as e:
        check('pubspec.yaml 可读取', False, str(e))
        return

    # ---- 检测 assets/contracts/ 下的舞台（子）目录 ----
    stage_dirs: list[str] = []
    if os.path.isdir(CONTRACTS_DIR):
        for entry in os.listdir(CONTRACTS_DIR):
            full = os.path.join(CONTRACTS_DIR, entry)
            if os.path.isdir(full):
                stage_dirs.append(entry)

    # ---- 每个舞台目录都必须被显式声明 ----
    missing = [
        d for d in stage_dirs
        if f'assets/contracts/{d}' not in declared
    ]
    check(
        'assets/contracts 舞台子目录均已声明',
        not missing,
        ', '.join(f'assets/contracts/{d}' for d in missing) if missing else
        ', '.join(f'assets/contracts/{d}' for d in stage_dirs) or '无舞台目录',
    )


def _extract_builtin_stage_keys() -> list[str]:
    """从 contract_dir.dart 提取 `_builtinStages` 的舞台目录名。

    `_builtinStages` 是「恢复内置角色 / 首次种子复制」的权威数据源；
    舞台目录名以 `'Name': [` 形式出现在 map 中。
    """
    dart_file = os.path.join(ROOT, 'lib', 'services', 'storage', 'contract_dir.dart')
    try:
        with open(dart_file, encoding='utf-8') as f:
            content = f.read()
    except OSError as e:
        return []
    m = re.search(r'_builtinStages\s*=\s*\{(.*?)\};', content, re.DOTALL)
    if m is None:
        return []
    return re.findall(r"'([A-Za-z0-9_]+)':\s*\[", m.group(1))


def check_builtin_stage_sync() -> None:
    """新增舞台必须同步登记到 `contract_dir.dart` 的 `_builtinStages`。

    舞台资产有三处需同步：assets/contracts/ 实盘目录、pubspec.yaml
    声明、`_builtinStages`（恢复内置/种子复制）。前两者已由
    [check_assets_stage_dirs] 校验；本断言补上「实盘目录 ↔
    `_builtinStages`」链路——漏登记会导致「恢复内置角色」时舞台
    文件夹不出现（静默缺失，本次 Lundao 曾踩中）。
    """
    stage_dirs: list[str] = []
    if os.path.isdir(CONTRACTS_DIR):
        for entry in os.listdir(CONTRACTS_DIR):
            full = os.path.join(CONTRACTS_DIR, entry)
            if os.path.isdir(full):
                stage_dirs.append(entry)

    registered = set(_extract_builtin_stage_keys())
    unregistered = [d for d in stage_dirs if d not in registered]
    check(
        '内置舞台已登记 _builtinStages（恢复内置可用）',
        not unregistered,
        ', '.join(unregistered) if unregistered
        else ', '.join(stage_dirs) or '无舞台目录',
    )


def check_workflow_paths() -> None:
    """ci.yml 只承担代码检查；release.yml 承担全部发布构建与打包。"""
    with open(CI_WORKFLOW, encoding='utf-8') as f:
        ci = f.read()
    with open(RELEASE_WORKFLOW, encoding='utf-8') as f:
        release = f.read()

    # ---- CI 职责：仅代码检查（analyze + test），不进行平台构建 ----
    check('ci.yml 包含 flutter analyze', 'flutter analyze' in ci)
    check('ci.yml 包含 flutter test', 'flutter test' in ci)
    check(
        'ci.yml 不承担平台构建（发布构建归 release.yml）',
        'flutter build' not in ci and 'sudo apt-get' not in ci,
    )

    # ---- release.yml 职责：全部平台发布构建 ----
    check('release.yml 包含 Android 构建', 'flutter build apk --release' in release)
    check('release.yml 包含 Linux 构建', 'flutter build linux --release' in release)
    check('release.yml 包含 Windows 构建', 'flutter build windows --release' in release)
    check('release.yml 包含 macOS 构建', 'flutter build macos --release' in release)
    check('release.yml 包含 iOS 构建', 'flutter build ios --release' in release)
    check('release.yml 包含 iOS no-codesign', '--no-codesign' in release)


def main() -> None:
    print('Mephisto 构建配置静态断言')
    print('=' * 46)
    check_android_internet()
    check_ios_ats()
    check_version_normalization()
    check_release_workflow_version_pattern()
    check_assets_stage_dirs()
    check_builtin_stage_sync()
    check_workflow_paths()
    print('=' * 46)
    if failures:
        print(f'失败：{len(failures)} 项断言未通过')
        for name in failures:
            print(f'  - {name}')
        sys.exit(1)
    print('全部断言通过 ✓')


if __name__ == '__main__':
    main()