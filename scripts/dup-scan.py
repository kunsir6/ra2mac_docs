#!/usr/bin/env python3
"""重复代码扫描器（S-21）——把「口径只活在报告散文里」的那个指标变成可执行实现。

背景：AUDIT-30 / 35 / 41 三轮对同一个量给出三组数（窗口组 125 / 139 / 140，产品侧 11 / 7 / 5），
差别不在代码而在口径没写死（「同文件内相隔 <25 行的窗口要不要折叠」原文没定义）。
本脚本把 AUDIT-41 实际使用的那套口径固定下来，作为此后审计与清偿排序的唯一口径。

口径（与 AUDIT-41 §二.3 逐项一致）
  1. 扫描范围：仓库内 .cpp/.h/.hpp/.inl/.mm/.cc，跳过 tests/ tools/ samples/。
  2. 窗口：25 行，步长 10（默认）。
  3. 非空占比 ≥70%：窗口内非空且非注释的行数 ≥17.5 才纳入（避免整段空行/花括号互相命中）。
  4. 归一化：每行 strip，丢掉空行与 `//` 整行注释，其余按换行拼接后取 sha256。
     归一化文本长度 <200 字符的窗口丢弃（纯花括号/纯 include 无意义）。
  5. 折叠：同一文件内起点相差 <25 行的命中视为同一处（一个长块被切成多个窗口）。
  6. 「窗口组」= 折叠后出现在 ≥2 处（可同文件）的哈希；「产品侧」= 组内每一处都不是夹具/冒烟。
     夹具判定按路径子串：smoke / fixture / oracle / old / original / test / fuzz / sample /
     legacy / admission / tools/ / tests/。

冻结基线（改口径必须同时改这里，否则下一轮审计的数又不可比）
  ref=77e75e7（第 41 轮 HEAD）→ 窗口组 140 / 产品侧 5。
  产品侧 5 组 = ReplaySandbox.cpp:41|.h:51、ReplaySandbox.cpp:51|.h:61、
  CampaignDatabase.cpp:481|RuntimeCampaignCoverage.h:31、
  RuntimeMultiplayerMatchSetup.cpp:51|SnapshotTransfer.cpp:61（S-20 真债）、同文件 :61|:71。

已知盲区（第 42 轮实测，写清免得下次又当成「没有重复」）
  固定步长 10 意味着起点偏移不是 10 的倍数的两份相同代码**互相看不到**。
  实例：RuntimeShell.cpp 50231 与 52676 的前 25 行逐字相同（25/25），偏移 2445 不是 10 的倍数
  → 默认口径不报。要查这一类用 `--step 1`（慢约 10 倍）。

用法
  python3 ra2mac_docs/scripts/dup-scan.py                 # 扫当前工作区
  python3 ra2mac_docs/scripts/dup-scan.py --ref 77e75e7   # 扫某个提交（可复现，不受并发 WIP 影响）
  python3 ra2mac_docs/scripts/dup-scan.py --json          # 机器可读
退出码：0 完成（本脚本不是门禁，不判红）。
"""
import argparse
import collections
import hashlib
import json
import os
import subprocess
import sys
import tarfile
import tempfile

EXT = ('.cpp', '.h', '.hpp', '.inl', '.mm', '.cc')
WIN, STEP, MIN_FILL = 25, 10, 0.7
SKIP_NEAR = 25
MIN_TEXT = 200
FIXTURE_KEYS = ('smoke', 'fixture', 'oracle', 'old', 'original', 'test', 'fuzz',
                'sample', 'legacy', 'admission')
BASELINE = {'ref': '77e75e7', 'window_groups': 140, 'product_groups': 5}


def is_fixture(rel):
    low = rel.lower().replace(os.sep, '/')
    return any(k in low for k in FIXTURE_KEYS)


def comment_only(line):
    t = line.strip()
    return (not t) or t.startswith('//') or t.startswith('/*') \
        or t.startswith('*') or t.startswith('*/')


def normalize(block):
    return '\n'.join(t for t in (s.strip() for s in block)
                     if t and not t.startswith('//'))


def collect(root):
    """只扫 git 跟踪的文件——工作区里的 build-* 目录含大量生成副本，
    直接 walk 会让同一份源码命中两次（第 42 轮实测：walk 1805 文件 / 280 组，ls-files 1773 / 140 组）。"""
    try:
        out = subprocess.run(['git', '-C', root, 'ls-files'], capture_output=True,
                             text=True, check=True).stdout.splitlines()
        picked = [os.path.join(root, rel) for rel in out
                  if rel.endswith(EXT)
                  and not any(part in ('tests', 'tools', 'samples')
                              for part in rel.replace(os.sep, '/').split('/')[:-1])]
        return sorted(picked)
    except (subprocess.CalledProcessError, OSError):
        pass
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root).replace(os.sep, '/')
        if any(p in rel_dir.split('/') for p in ('tests', 'tools', 'samples', '.git')):
            dirnames[:] = []
            continue
        for fn in filenames:
            if fn.endswith(EXT):
                out.append(os.path.join(dirpath, fn))
    return sorted(out)


def scan(root, step):
    files = collect(root)
    groups = collections.defaultdict(list)
    for path in files:
        rel = os.path.relpath(path, root)
        try:
            lines = open(path, encoding='utf-8', errors='replace').read().split('\n')
        except OSError:
            continue
        for i in range(0, max(0, len(lines) - WIN + 1), step):
            block = lines[i:i + WIN]
            filled = sum(1 for s in block if not comment_only(s))
            if filled < MIN_FILL * WIN:
                continue
            text = normalize(block)
            if len(text) < MIN_TEXT:
                continue
            groups[hashlib.sha256(text.encode()).hexdigest()].append((rel, i + 1))

    def collapse(locs):
        by_file = collections.defaultdict(list)
        for rel, ln in locs:
            by_file[rel].append(ln)
        merged = []
        for rel in sorted(by_file):
            for ln in sorted(set(by_file[rel])):
                if merged and merged[-1][0] == rel and ln - merged[-1][1] < SKIP_NEAR:
                    continue
                merged.append((rel, ln))
        return merged

    windows = []
    for digest, locs in groups.items():
        merged = collapse(locs)
        if len(merged) >= 2:
            windows.append((digest, merged))
    windows.sort(key=lambda it: (it[1][0][0], it[1][0][1]))
    product = [(d, loc) for d, loc in windows
               if all(not is_fixture(rel) for rel, _ in loc)]
    return len(files), windows, product


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), '..', '..', 'ConcordRTS'))
    ap.add_argument('--ref', default='', help='扫该提交的树（git archive），可复现')
    ap.add_argument('--step', type=int, default=STEP)
    ap.add_argument('--json', action='store_true')
    args = ap.parse_args()

    tmp = None
    root = os.path.abspath(args.root)
    if args.ref:
        tmp = tempfile.mkdtemp(prefix='dup-scan-')
        archive = subprocess.run(['git', '-C', root, 'archive', args.ref],
                                 capture_output=True, check=True)
        with tempfile.NamedTemporaryFile(suffix='.tar', delete=False) as fh:
            fh.write(archive.stdout)
            tar_path = fh.name
        with tarfile.open(tar_path) as tf:
            tf.extractall(tmp, filter='data')
        os.unlink(tar_path)
        root = tmp

    try:
        nfiles, windows, product = scan(root, args.step)
    finally:
        if tmp:
            import shutil
            shutil.rmtree(tmp, ignore_errors=True)

    if args.json:
        print(json.dumps({
            'ref': args.ref or 'worktree',
            'step': args.step,
            'files': nfiles,
            'window_groups': len(windows),
            'product_groups': len(product),
            'baseline': BASELINE,
            'product': [[list(map(str, loc)) for loc in locs] for _, locs in product],
        }, ensure_ascii=False, indent=2))
        return 0

    print(f'扫描 {nfiles} 文件  step={args.step}  窗口 {WIN} 行 / 非空 ≥{int(MIN_FILL*100)}%')
    print(f'窗口组 {len(windows)}   产品侧 {len(product)}   '
          f'（冻结基线 ref={BASELINE["ref"]}: {BASELINE["window_groups"]}/{BASELINE["product_groups"]}）')
    print('\n产品侧（组内每一处都不是夹具/冒烟）：')
    for digest, locs in product:
        print('  ' + '  |  '.join(f'{rel}:{ln}' for rel, ln in locs))
    if args.step != STEP:
        print(f'\n注意：step={args.step} 与冻结基线口径不同，数字不可与历史审计直接相比。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
