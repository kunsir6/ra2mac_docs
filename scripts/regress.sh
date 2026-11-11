#!/bin/bash
# ConcordRTS macOS 一键回归（无人值守，可自我判定）
#
# 用法：
#   bash ra2mac_docs/scripts/regress.sh                  # 全量，约 25-40 秒
#   bash ra2mac_docs/scripts/regress.sh --only menu,core # 只跑指定用例
#   CONCORD_BIN=/path/to/concord_runtime bash .../regress.sh
#
# 判定三态（不允许把红说成绿）：
#   PASS       退出码 0
#   KNOWN-RED  退出码非 0，且 id 已登记在 progress/regress/known-red.tsv（附原因）
#   RED-NEW    退出码非 0，且未登记 —— 这才是"你刚弄坏了什么"
# 退出码 = RED-NEW 条数。
#
# 设计约束（都是踩过的坑）：
#   * 不用 grep/sed：本机两者是 shim，多模式会静默返回空。纯 bash 字符串匹配。
#   * 必须 cd 到 ConcordRTS-GameData：资源根按工作目录解析。
#   * CONCORD_MAIN_MENU_HEADLESS_SMOKE 只给菜单那条用；带上它跑 skirmish 会退化成打印 help。
#   * attest 目录必须先存在，否则进程秒退，表现为 6ms 的假首帧。

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOCS=$(dirname "$SCRIPT_DIR")
ROOT=$(dirname "$DOCS")

BIN=${CONCORD_BIN:-$ROOT/ConcordRTS/build-product-arm/concord_runtime}
DATA=${CONCORD_DATA:-$ROOT/ConcordRTS-GameData}
BASE=${CONCORD_REGRESS_BASE:-$ROOT/ra2mac_docs/progress/regress}
STAMP=$(date +%Y%m%d-%H%M%S)
OUT=${CONCORD_REGRESS_OUT:-$BASE/$STAMP}
KNOWN_RED=$BASE/known-red.tsv
ONLY=""

usage() {
  cat <<'EOF'
ConcordRTS 回归编排器
  --only id[,id]   只跑指定用例（core menu loading skirmish attest render
                   interaction command build campaign result）
  --bin <path>     指定被测二进制（默认 build-product-arm/concord_runtime）
  --out <dir>      指定输出目录（默认 progress/regress/<时间戳>）
  -h               本帮助
判定：PASS / KNOWN-RED（已登记）/ RED-NEW（未登记）；退出码 = RED-NEW 条数。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY=",$2,"; shift 2 ;;
    --bin)  BIN=$2; shift 2 ;;
    --out)  OUT=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -x "$BIN" ] || { echo "FATAL: 找不到可执行文件 $BIN" >&2; exit 2; }
[ -d "$DATA" ] || { echo "FATAL: 找不到数据根 $DATA" >&2; exit 2; }
ART=$OUT/artifacts
mkdir -p "$ART/attest" "$BASE" || exit 2

# 构建指纹：先回答"我到底在测哪个二进制"，否则结论可能是在测旧包
BIN_SHA=$(shasum -a 256 "$BIN" | cut -c1-16)
BIN_MTIME=$(date -r "$BIN" +%Y-%m-%dT%H:%M:%S)
BIN_EPOCH=$(stat -f%m "$BIN")
BIN_SIZE=$(stat -f%z "$BIN")
BIN_ARCH=$(lipo -archs "$BIN" 2>/dev/null | awk '{print $1}')
DIST_WARN=""
for app in "$ROOT"/dist/*.app; do
  [ -d "$app" ] || continue
  case "$(basename "$app")" in
    *"$BIN_ARCH"*) ;;
    *) continue ;;   # 只对同架构产物对账，跨架构本来就不该相同
  esac
  exe="$app/Contents/MacOS/concord_runtime"
  [ -f "$exe" ] || continue
  # 哈希不能用来对账 .app 里的二进制：ad-hoc 重签名会改写文件，哈希必然不同。
  # 真正要抓的是"dist 比 build 旧"这个陷阱（2026-11-11 用户复测跑到 11:29 旧包）。
  APP_EPOCH=$(stat -f%m "$exe")
  APP_MTIME=$(date -r "$exe" +%Y-%m-%dT%H:%M:%S)
  if [ $((BIN_EPOCH - APP_EPOCH)) -gt 60 ]; then
    DIST_WARN="$(basename "$app") 内二进制 mtime=${APP_MTIME} 早于 build 产物 ${BIN_MTIME}（dist 是旧包，别拿它复测）"
  fi
done

echo "== ConcordRTS 回归 =="
echo "   bin     $BIN"
echo "   sha256  $BIN_SHA   mtime=$BIN_MTIME   size=$BIN_SIZE"
echo "   data    $DATA"
echo "   out     $OUT"
[ -n "$DIST_WARN" ] && echo "   警告    $DIST_WARN"
echo

TSV=$OUT/results.tsv
printf 'id\tstate\tsecs\tevidence\treason\n' > "$TSV"

known_reason() {
  local want=$1 line id reason rest
  [ -f "$KNOWN_RED" ] || return 1
  while IFS=$'\t' read -r id reason rest; do
    [ -z "${id:-}" ] && continue
    case "$id" in \#*) continue ;; esac
    if [ "$id" = "$want" ]; then printf '%s' "$reason"; return 0; fi
  done < "$KNOWN_RED"
  return 1
}

pick_evidence() {
  local log=$1 tmp line last="" cand=""
  tmp=$(tail -n 60 "$log" 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    last=$line
    case "$line" in
      *failed*|*Failed*|*FAIL*|*failed,*) cand=$line ;;
      *Smoke\:*|*smoke\:*|*done\:*|*passed*) [ -z "$cand" ] && cand=$line ;;
    esac
  done <<< "$tmp"
  if [ -n "$cand" ]; then printf '%s' "$cand"; else printf '%s' "$last"; fi
}

PASS_N=0; KNOWN_N=0; NEW_N=0

run_case() {
  local id=$1 tmo=$2 envs=$3 args=$4
  if [ -n "$ONLY" ]; then
    case "$ONLY" in *",$id,"*) ;; *) return 0 ;; esac
  fi
  local log=$OUT/$id.log start end secs rc state reason ev
  start=$(date +%s)
  # shellcheck disable=SC2086
  ( cd "$DATA" && env $envs timeout "$tmo" "$BIN" $args ) > "$log" 2>&1
  rc=$?
  end=$(date +%s); secs=$((end - start))
  reason=""
  if [ $rc -eq 0 ]; then
    state="PASS"; PASS_N=$((PASS_N+1))
  elif reason=$(known_reason "$id"); then
    state="KNOWN-RED"; KNOWN_N=$((KNOWN_N+1))
  else
    state="RED-NEW"; NEW_N=$((NEW_N+1))
    [ $rc -eq 124 ] && reason="超时 ${tmo}s"
  fi
  ev=$(pick_evidence "$log")
  [ ${#ev} -gt 160 ] && ev="${ev:0:160}…"
  printf '  %-12s %-9s %3ss  %s\n' "$id" "$state" "$secs" "$ev"
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$state" "$secs" "$(printf '%s' "$ev" | tr '\t|' '  ')" "$(printf '%s' "$reason" | tr '\t|' '  ')" >> "$TSV"
}

echo "-- 执行 --"
# id           超时  env                                   args
run_case core        120 ""                                     "--smoke-test"
run_case menu        120 "CONCORD_MAIN_MENU_HEADLESS_SMOKE=1"   "--main-menu-ui-smoke-test $ART/menu.bmp"
run_case loading     300 ""                                     "--loading-smoke-test"
run_case skirmish    300 ""                                     "--skirmish-ui-smoke-test $ART/skirmish.bmp"
run_case attest      300 "CONCORD_ONSCREEN_ATTEST_LIMIT=6"      "--onscreen-attest-smoke $ART/attest"
run_case render      300 ""                                     "--render-smoke-test"
run_case interaction 300 ""                                     "--interaction-smoke-test"
run_case command     300 ""                                     "--command-smoke-test"
run_case build       300 ""                                     "--build-smoke-test"
run_case campaign    300 ""                                     "--campaign-smoke-test"
run_case result      300 ""                                     "--result-presentation-smoke-test"

TOTAL=$((PASS_N + KNOWN_N + NEW_N))
printf '\n-- 汇总 -- PASS=%s KNOWN-RED=%s RED-NEW=%s  共 %s 条\n' "$PASS_N" "$KNOWN_N" "$NEW_N" "$TOTAL"

MD=$OUT/report.md
{
  printf '# 回归结果 %s\n\n' "$STAMP"
  printf -- '- 二进制 `%s`\n- sha256(前16) `%s`   mtime `%s`\n- 数据根 `%s`\n' "$BIN" "$BIN_SHA" "$BIN_MTIME" "$DATA"
  [ -n "$DIST_WARN" ] && printf -- '- 警告：%s\n' "$DIST_WARN"
  printf '\n| 用例 | 结果 | 耗时 | 证据 | 已知原因 |\n|---|---|---|---|---|\n'
  while IFS=$'\t' read -r id state secs ev reason; do
    [ "$id" = "id" ] && continue
    printf '| %s | %s | %ss | %s | %s |\n' "$id" "$state" "$secs" "$ev" "$reason"
  done < "$TSV"
  printf '\nPASS=%s KNOWN-RED=%s RED-NEW=%s\n' "$PASS_N" "$KNOWN_N" "$NEW_N"
} > "$MD"

echo "   报告 $MD"
[ $NEW_N -gt 0 ] && echo "   $NEW_N 条 NEW-RED：先看 $OUT/<id>.log，确认后要么修，要么登记进 known-red.tsv"
exit $NEW_N
