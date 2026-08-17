#!/usr/bin/env python3
"""Mephisto 测试覆盖率摘要（基于 flutter test --coverage 生成的 lcov.info）。

将 lcov 数据解析为按文件分组的覆盖率摘要，便于 CI 日志与本地开发直观看到
「哪些核心文件尚未被测试覆盖」，作为质量仪表盘（不设硬性门槛，避免误报）。

用法：
  flutter test --coverage
  python3 tool/coverage_summary.py [coverage/lcov.info]

退出码：恒为 0（只输出摘要，不阻塞 CI）。带 --fail-below <百分比> 时，
总行覆盖率低于阈值返回非 0（供需要硬门槛的场景使用）。
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LCOV = os.path.join(ROOT, 'coverage', 'lcov.info')
# 只关注应用代码（lib/），忽略测试/生成代码/平台层
SKIP_PREFIXES = ('/test/', '/.dart_tool/', 'generated')


def parse_lcov(path: str) -> list[dict]:
    """解析 lcov.info 为 [{'file': str, 'lines': int, 'hit': int}, ...]。"""
    records: list[dict] = []
    current: dict | None = None
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current = {'file': line[3:], 'lines': 0, 'hit': 0}
            elif line.startswith('DA:') and current is not None:
                # DA:<行号>,<执行次数>[,<分支信息>]
                parts = line[3:].split(',')
                current['lines'] += 1
                if int(parts[1]) > 0:
                    current['hit'] += 1
            elif line == 'end_of_record' and current is not None:
                records.append(current)
                current = None
    return records


def main(argv: list[str]) -> int:
    lcov_path = argv[0] if argv and argv[0].startswith('/') else DEFAULT_LCOV
    fail_below = None
    if '--fail-below' in argv:
        idx = argv.index('--fail-below')
        fail_below = float(argv[idx + 1])

    if not os.path.exists(lcov_path):
        print(f'未找到 {lcov_path}——请先运行 flutter test --coverage')
        return 1 if fail_below is not None else 0

    records = [
        r for r in parse_lcov(lcov_path)
        if r['file'].startswith('lib/')
        and not any(r['file'].startswith(p) for p in SKIP_PREFIXES)
        and r['lines'] > 0
    ]
    if not records:
        print('lcov 中没有 lib/ 下的有效记录。')
        return 0

    # 按行数降序（文件越大越靠前，帮助优先补覆盖大文件）
    records.sort(key=lambda r: r['lines'], reverse=True)

    total_lines = sum(r['lines'] for r in records)
    total_hit = sum(r['hit'] for r in records)
    total_pct = total_hit / total_lines * 100 if total_lines else 0

    print(f'lib/ 覆盖率摘要（共 {len(records)} 个文件，{total_lines} 行可执行）')
    print(f'总行覆盖率: {total_hit}/{total_lines} = {total_pct:.1f}%')
    print('-' * 52)
    print(f"{'文件':<56}{'行':>6}{'已覆盖':>8}{'比例':>8}")
    print('-' * 52)
    for r in records:
        pct = r['hit'] / r['lines'] * 100 if r['lines'] else 0
        rel = r['file'].replace('lib/', '', 1)
        print(f"{rel:<56}{r['lines']:>6}{r['hit']:>8}{pct:>7.1f}%")
    print('-' * 52)

    if fail_below is not None and total_pct < fail_below:
        print(f'总覆盖率 {total_pct:.1f}% 低于阈值 {fail_below:.1f}%')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
