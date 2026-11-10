#!/usr/bin/env python3
"""对比两份 ConcordRTS 内核基线，判定是否逐字节等价。

用法:
    ./compare-core-baseline.py <reference.json> <candidate.json>

退出码:
    0  一致
    1  存在差异
    2  参数或文件错误
"""

import json
import sys


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    try:
        ref = load(sys.argv[1])
        cand = load(sys.argv[2])
    except (OSError, json.JSONDecodeError) as exc:
        print(f"读取失败: {exc}", file=sys.stderr)
        return 2

    differences = []

    def note(field, expected, actual):
        differences.append((field, expected, actual))

    # 1. 构建身份
    for field in ("git_commit", "cmake"):
        if ref.get(field) != cand.get(field):
            note(field, ref.get(field), cand.get(field))

    # 2. 测试计数（数量本身必须一致，否则说明目标集合被改动）
    ref_ctest = ref.get("ctest", {})
    cand_ctest = cand.get("ctest", {})
    for field in ("registered", "failed"):
        if ref_ctest.get(field) != cand_ctest.get(field):
            note(f"ctest.{field}", ref_ctest.get(field), cand_ctest.get(field))
    if cand_ctest.get("status") != 0:
        note("ctest.status", 0, cand_ctest.get("status"))

    # 3. 哈希：跨平台确定性的唯一金标准
    ref_smokes = {item["name"]: item for item in ref.get("smokes", [])}
    cand_smokes = {item["name"]: item for item in cand.get("smokes", [])}

    for name, ref_item in ref_smokes.items():
        cand_item = cand_smokes.get(name)
        if cand_item is None:
            note(f"smoke.{name}", "exists", "missing")
            continue

        ref_hash = ref_item.get("hash") or ""
        cand_hash = cand_item.get("hash") or ""
        if ref_hash and cand_hash and ref_hash != cand_hash:
            note(f"hash.{name}", ref_hash, cand_hash)
        elif bool(ref_hash) != bool(cand_hash):
            note(f"hash.{name}", ref_hash or "(none)", cand_hash or "(none)")

        ref_exit = ref_item.get("exit")
        cand_exit = cand_item.get("exit")
        # 77 是 CTest 的 skip 约定；两边都 skip 视为一致
        if ref_exit != cand_exit:
            if not (ref_exit == 77 and cand_exit == 77):
                note(f"exit.{name}", ref_exit, cand_exit)

    print(f"参考基线: {sys.argv[1]}  [{ref.get('os')}/{ref.get('arch')}]")
    print(f"候选基线: {sys.argv[2]}  [{cand.get('os')}/{cand.get('arch')}]")
    print()

    if not differences:
        print("一致：哈希、测试计数、退出码全部匹配。")
        return 0

    print(f"发现 {len(differences)} 处差异：")
    width = max(len(item[0]) for item in differences)
    for field, expected, actual in differences:
        print(f"  {field.ljust(width)}  参考={expected!r}  候选={actual!r}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
