#!/usr/bin/env python3
"""把交付说明书里「回归现状」那一段换成最近一次回归的真实读数。

为什么需要它（S-34）：
    事实的**生产者**是 regress.sh，**消费者**是发给用户的 `dist/README.txt`，
    中间缺一个生成步骤 —— 于是每加一条门禁，说明书里的「共 15 条：13 绿」就变成假话。
    第 59 轮手工改对过一次（S-33），第 60 轮加了 `paradropsel`（第 16 条）又错了。
    手工同步不成立：没有任何东西会提醒「该回来改说明书」。

数据源（按优先级）：
    1. `<regress-base>/latest.txt` ——  regress.sh 每次收尾覆盖写的一行 k=v；
    2. 退回去扫 `<regress-base>/<YYYYMMDD-HHMMSS>/report.md` 里最后一行 `PASS=..`。
    两处都没有 = 这台机器没跑过回归 → 生成「未跑过」而不是把旧数字抄一遍。

用法：
    python3 render-readme.py --in ConcordRTS/packaging/README-dist.txt --out /tmp/README.txt
    python3 render-readme.py --in ... --check          # 只比对，不一致退出码 1
    python3 render-readme.py --in ... --out ... --latest /tmp/latest.txt --known-red /tmp/kr.tsv

标记：源文件里用 `<!-- regress:begin -->` / `<!-- regress:end -->` 圈出被生成的那一段，
      渲染结果里这两行会被删掉（.txt 里留 HTML 注释会让人以为是漏写的内容）。
"""
import argparse
import os
import re
import sys

BEGIN = "<!-- regress:begin -->"
END = "<!-- regress:end -->"
FALLBACK = "（这台机器没有可用的回归产物：本段未生成，请先跑 `bash ra2mac_docs/scripts/regress.sh`）"


def parse_latest(path):
    """latest.txt 是一行 k=v（空格分隔）。缺字段返回 None。"""
    try:
        text = open(path, encoding="utf-8").read().strip()
    except OSError:
        return None
    fields = dict(part.split("=", 1) for part in text.split() if "=" in part)
    need = ("source", "stamp", "pass", "knownred", "new", "total")
    if any(k not in fields for k in need):
        return None
    return fields


def parse_report(path):
    """退化路径：从 report.md 里抠源码 hash 与最后的汇总行。"""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return None
    fields = {}
    for line in lines:
        m = re.search(r"PASS=(\d+)\s+KNOWN-RED=(\d+)\s+RED-NEW=(\d+)", line)
        if m:
            fields["pass"], fields["knownred"], fields["new"] = m.groups()
        m = re.search(r"源码 `([^`]+)`", line)
        if m and "source" not in fields:
            fields["source"] = m.group(1)
        m = re.match(r"# 回归结果 (\S+)", line)
        if m:
            fields["stamp"] = m.group(1)
    if "pass" not in fields:
        return None
    fields.setdefault("source", "?")
    fields.setdefault("stamp", "?")
    fields["total"] = str(int(fields["pass"]) + int(fields["knownred"]) + int(fields["new"]))
    return fields


def newest_report(base):
    try:
        names = sorted(n for n in os.listdir(base) if re.match(r"^\d{8}-\d{6}$", n))
    except OSError:
        return None
    for name in reversed(names):
        found = parse_report(os.path.join(base, name, "report.md"))
        if found:
            return found
    return None


def load_regress(latest, base):
    if latest and os.path.exists(latest):
        found = parse_latest(latest)
        if found:
            return found
    if base:
        found = parse_latest(os.path.join(base, "latest.txt"))
        if found:
            return found
        return newest_report(base)
    return None


def load_known_red(path):
    """known-red.tsv 四列：id / 原因 / status / 失败前缀。注释与空行跳过。"""
    rows = []
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return None
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = line.split("\t")
        if len(cols) < 3 or not cols[0].strip():
            continue
        rows.append((cols[0].strip(), cols[2].strip(), cols[3].strip() if len(cols) > 3 else ""))
    return rows


def pretty_stamp(stamp):
    """20261116-023144 → 2026-11-16 02:31"""
    m = re.match(r"^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})", stamp)
    if not m:
        return stamp
    return "%s-%s-%s %s:%s" % m.groups()


def build_block(latest, base, known_red_path):
    regress = load_regress(latest, base)
    rows = load_known_red(known_red_path) if known_red_path else None
    if regress is None and rows is None:
        return [FALLBACK]

    out = []
    if regress is None:
        out.append(FALLBACK)
    else:
        total = regress["total"]
        out.append(
            "`bash ra2mac_docs/scripts/regress.sh` 共 **%s 条：%s 绿 / %s known-red / %s 新红**"
            "（最近一次 %s，源码 `%s`）。"
            % (total, regress["pass"], regress["knownred"], regress["new"],
               pretty_stamp(regress["stamp"]), regress["source"])
        )
    out.append("两个数字都会随树变，以报告头的 `-- 汇总 --` 行为准，别拿这份说明书当门禁。")
    out.append("**本段由 `pack-dist.sh` 第 ⑩ 步自动生成**（`ra2mac_docs/scripts/render-readme.py`）"
               "—— 手改会在下次打包时被覆盖；要改事实请去改 `known-red.tsv` 或跑一次回归。")

    if rows is None:
        out.append("")
        out.append("（没读到 `known-red.tsv`，当前 known-red 条目未列出。）")
    elif not rows:
        out.append("")
        out.append("当前没有登记任何 known-red。")
    else:
        out.append("")
        out.append("当前 known-red（`progress/regress/known-red.tsv` 共 %d 条，失败文案前缀已钉住，"
                   "原因换掉即判 cause-changed）：" % len(rows))
        for rid, status, prefix in rows:
            suffix = "" if prefix else "（未钉前缀：只判红）"
            out.append("· `%s` —— %s%s" % (rid, status, suffix))
    return out


def render(src_text, block):
    lines = src_text.splitlines()
    try:
        begin = next(i for i, l in enumerate(lines) if l.strip() == BEGIN)
        end = next(i for i, l in enumerate(lines) if l.strip() == END and i > begin)
    except StopIteration:
        return None
    return "\n".join(lines[:begin] + block + lines[end + 1:]) + "\n", (begin, end)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--latest")
    ap.add_argument("--known-red")
    ap.add_argument("--base", default=None)
    args = ap.parse_args()

    project = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    base = args.base or os.path.join(project, "ra2mac_docs", "progress", "regress")
    known_red = args.known_red if args.known_red is not None else os.path.join(base, "known-red.tsv")

    src_text = open(args.src, encoding="utf-8").read()
    block = build_block(args.latest, base, known_red)
    rendered = render(src_text, block)
    if rendered is None:
        sys.stderr.write("render-readme: %s 里没有 %s / %s 标记\n" % (args.src, BEGIN, END))
        return 2
    rendered_text, _ = rendered

    if args.check:
        target = args.out or args.src
        try:
            current = open(target, encoding="utf-8").read()
        except OSError:
            current = ""
        if current == rendered_text:
            print("ok  readme-regress  %s 与回归产物一致" % target)
            return 0
        want = rendered_text.splitlines()
        got = current.splitlines()
        for i in range(max(len(want), len(got))):
            w = want[i] if i < len(want) else "<缺行>"
            g = got[i] if i < len(got) else "<缺行>"
            if w != g:
                print("STALE 第 %d 行起不一致：\n  应是: %s\n  实为: %s" % (i + 1, w, g))
                break
        return 1

    if not args.out:
        sys.stderr.write("render-readme: 需要 --out 或 --check\n")
        return 2
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(rendered_text)
    print("readme    回归现状段 %d 行 ← %s" % (len(block), os.path.basename(args.src)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
