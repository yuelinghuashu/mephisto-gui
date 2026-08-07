#!/usr/bin/env python3
"""Mephisto 构建配置静态断言。

在 CI 中执行，防止构建/打包层面的配置回归：
  1. AndroidManifest.xml 必须声明 INTERNET 权限（防止 Android Release 无法联网）
  2. iOS Info.plist 必须配置 ATS 本地网络（防止本地 Ollama 明文 HTTP 被拦截）
  3. release.yml 中 dpkg 版本号剥离必须同时处理 v/V 前缀（防止 dpkg 报错）
  4. ci.yml / release.yml 中关键构建步骤存在（防止构建配置被误删）

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


def check_workflow_paths() -> None:
    """ci.yml / release.yml 中关键构建与检查步骤必须存在。"""
    with open(CI_WORKFLOW, encoding='utf-8') as f:
        ci = f.read()
    with open(RELEASE_WORKFLOW, encoding='utf-8') as f:
        release = f.read()

    check('ci.yml 包含 flutter analyze', 'flutter analyze' in ci)
    check('ci.yml 包含 flutter test', 'flutter test' in ci)
    check('release.yml 包含 Android 构建', 'flutter build apk --release' in release)
    check('release.yml 包含 Linux 构建', 'flutter build linux --release' in release)
    check('release.yml 包含 Windows 构建', 'flutter build windows --release' in release)
    check('release.yml 包含 macOS 构建', 'flutter build macos --release' in release)
    check('release.yml 包含 iOS 构建', 'flutter build ios --release' in release)


def main() -> None:
    print('Mephisto 构建配置静态断言')
    print('=' * 46)
    check_android_internet()
    check_ios_ats()
    check_version_normalization()
    check_release_workflow_version_pattern()
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