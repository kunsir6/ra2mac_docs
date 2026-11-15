#!/bin/bash
# 构建状态体检（S-30）——回答一个问题：这个构建目录「要我重编 1647 个目标」是真改了参数，还是状态文件坏了？
#
# 用法：
#   bash ra2mac_docs/scripts/build-health.sh              # 体检默认两个产品目录
#   bash ra2mac_docs/scripts/build-health.sh build-product-arm build-product-x86_64
#   NINJA=/path/to/ninja bash ra2mac_docs/scripts/build-health.sh
#
# 为什么要它：第 41~43 轮连续三轮把 `ninja -n` 要求全量重编归因于「并发改了 cmake」，
# 于是三轮放弃源码修复。真因是 `.ninja_deps` 尾部截断——ninja 自己会在第一行报
# `warning: premature end of file; recovering`，然后所有 `stored deps info out of date`。
# 判据必须两条一起看：①本目录有截断告警且脏因是 deps ②**另一个构建目录同一刻干净**
# （真改了 cmake 的话两个目录会一起失效）。
#
# 判定：
#   clean    不必重编，或只有少量目标（正常增量）
#   WARN     待办 > 总量 30%，但没看到截断告警 —— 可能真改了大范围头文件，也可能是别的怪因
#   CORRUPT  .ninja_deps 截断 / 待办全量 —— 别归因于参数，直接付一次全量把它修回来
#
# 退出码：0 clean / 1 warn / 2 corrupt
# 设计约束：不构建（只 `-n`），不改任何文件；本机 grep/sed 是 shim，一律纯 bash 匹配。

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOCS=$(dirname "$SCRIPT_DIR")
ROOT=$(dirname "$DOCS")
SRC=$ROOT/ConcordRTS
NINJA=${NINJA:-$ROOT/.toolchain/bin/ninja}

if [ ! -x "$NINJA" ]; then
  echo "FATAL: 找不到 ninja（$NINJA）。查 build-product-arm/CMakeCache.txt 的 CMAKE_MAKE_PROGRAM。" >&2
  exit 3
fi

DIRS=""
if [ $# -gt 0 ]; then
  for a in "$@"; do DIRS="$DIRS $a"; done
else
  DIRS=" build-product-arm build-product-x86_64"
fi

WORST=0
SUMMARY=""

probe() {
  local dir=$1
  local log total=0 todo=0 trunc=0 depsbad=0 line first="" last=""
  log=$(mktemp "${TMPDIR:-/tmp}/build-health.XXXXXX") || return 3
  "$NINJA" -C "$SRC/$dir" -n >"$log" 2>&1
  local rc=$?
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ -z "$first" ] && first=$line
    last=$line
    case "$line" in
      *"premature end of file"*) trunc=$((trunc + 1)) ;;
      *"stored deps info out of date"*) depsbad=$((depsbad + 1)) ;;
    esac
    # 形如 [123/1647] 的待办行：右边那个数是总量
    case "$line" in
      \[*/*\]*)
        todo=$((todo + 1))
        local prog=${line%%]*}
        prog=${prog#\[}
        local n=${prog##*/}
        case "$n" in ''|*[!0-9]*) ;; *) total=$n ;; esac
        ;;
    esac
  done <"$log"
  rm -f "$log"

  local state=clean note=""
  # 分母必须是**图里所有目标数**，不能用 ninja 进度行的 `[3/3]` 右半边——那是「本次剩余」，
  # 只改一个 TU 时它也是 [2/2]，于是「待办 2/2 超过 30%」每次增量都成立，告警等于噪声（R64 实测）。
  local graph=0
  graph=$("$NINJA" -C "$SRC/$dir" -t targets all 2>/dev/null | wc -l | tr -d ' ')
  case "${graph:-}" in ''|*[!0-9]*) graph=0 ;; esac
  if [ "$rc" -ne 0 ]; then
    state=CORRUPT; note="ninja -n 自身退出码 $rc：$last"
  elif [ "$trunc" -gt 0 ]; then
    state=CORRUPT; note=".ninja_deps 截断（$trunc 行告警）→ 加 -d explain 可直接看脏因"
  elif [ "$total" -gt 0 ] && [ "$todo" -ge "$total" ] && [ "$total" -gt 200 ]; then
    state=CORRUPT; note="待办看起来是全量（$todo/$total）→ 先查 .ninja_deps 再决定是否重编"
  elif [ "$graph" -gt 0 ] && [ $((todo * 100)) -gt $((graph * 30)) ]; then
    state=WARN; note="待办 $todo/$graph 超过 30%，但没有截断告警"
  elif [ "$todo" -eq 0 ]; then
    state=clean; note="no work to do"
  else
    state=clean; note="增量 $todo/$graph"
  fi

  printf '  %-22s %-8s %s\n' "$dir" "$state" "$note"
  SUMMARY="$SUMMARY$dir=$state "
  case "$state" in
    CORRUPT) [ "$WORST" -lt 2 ] && WORST=2 ;;
    WARN) [ "$WORST" -lt 1 ] && WORST=1 ;;
  esac
}

echo "== 构建状态体检 =="
echo "   ninja   $NINJA"
echo "   source  $SRC"
echo
for d in $DIRS; do
  if [ ! -d "$SRC/$d" ]; then
    printf '  %-22s %-8s %s\n' "$d" "SKIP" "目录不存在"
    continue
  fi
  probe "$d"
done
echo

case "$WORST" in
  0) echo "   结论    clean：可以放心增量构建" ;;
  1) echo "   结论    WARN：先说清「改了什么」再动手，别一句「重配了」带过" ;;
  2)
    echo "   结论    CORRUPT：先看另一个目录是否同刻干净。"
    echo "           另一个干净 = 只是本目录状态坏了，付一次全量把 .ninja_deps 重写回来即可；"
    echo "           两个都脏 = 真改了编译参数/头文件，全量是应该的。"
    echo "           不要删 .ninja_deps 了事：删了照样全量，还丢掉 restat 记录。"
    ;;
esac
echo "   （判据出处：AUDIT-30 §四、第 44 轮纠正、AUDIT-56 §六.6）"
exit "$WORST"
