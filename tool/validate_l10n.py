#!/usr/bin/env python3
"""Mephisto 本地化键一致性断言。

在 CI 中执行，防止新增/删除文案时 zh/en 两个 .arb 文件键集合失步
（漏翻或用不到的键）：任一语言缺键会导致 `AppLocalizations.of(context)`
在对应 locale 下抛出 MissingLocalizationKeyException，让界面崩溃。

用法：
  python3 tool/validate_l10n.py

退出码非 0 表示有断言失败。
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N_DIR = os.path.join(ROOT, 'lib', 'l10n')
ARB_FILES = ['app_zh.arb', 'app_en.arb']
# 支持的语言（模板 locale + supportedLocales 中的其余语言）
TEMPLATE = 'app_zh.arb'
OTHERS = ['app_en.arb']

failures: list[str] = []


def check(name: str, condition: bool, detail: str = '') -> None:
    status = 'PASS' if condition else 'FAIL'
    print(f'[{status}] {name}' + (f' — {detail}' if detail else ''))
    if not condition:
        failures.append(name)


def _load_keys(file_name: str) -> tuple[str, set[str]]:
    path = os.path.join(L10N_DIR, file_name)
    if not os.path.exists(path):
        check(f'{file_name} 存在', False, '文件缺失')
        sys.exit(1)
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    # 收集「真正的键」：排除以 @ 开头的元数据键（@@locale 等 FLutter 内部元数据）
    keys = {k for k in data if not k.startswith('@')}
    return file_name, keys


def main() -> int:
    print(f'检查 {L10N_DIR} 下 zh/en 键一致性…')
    file_names = [_load_keys(f) for f in ARB_FILES]
    keys_by_file: dict[str, set[str]] = dict(file_names)

    # 1. 每个文件自身：键名唯一（JSON 已保证，但防御重复）
    # 2. 模板之外的每个语言：与模板键集合完全一致
    template_keys = keys_by_file[TEMPLATE]
    for other in OTHERS:
        other_keys = keys_by_file[other]
        missing = template_keys - other_keys
        extra = other_keys - template_keys
        check(
            f'{other} 与 {TEMPLATE} 键集合一致',
            not missing and not extra,
            '缺 ' + (', '.join(sorted(missing)) if missing else '无')
            + ('；多 ' + ', '.join(sorted(extra)) if extra else ''),
        )

    if failures:
        print('\n失败项: ' + ', '.join(failures))
        return 1
    print('所有本地化键一致性检查通过。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
