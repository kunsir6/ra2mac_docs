#!/bin/bash
# ConcordRTS macOS 一键回归（无人值守，可自我判定）
#
# 用法：
#   bash ra2mac_docs/scripts/regress.sh                  # 全量，约 30-45 秒
#   bash ra2mac_docs/scripts/regress.sh --only menu,core # 只跑指定用例
#   CONCORD_BIN=/path/to/concord_runtime bash .../regress.sh
#
# 判定三态（不允许把红说成绿）：
#   PASS       退出码 0
#   KNOWN-RED  退出码非 0，id 已登记在 known-red.tsv，且失败文案仍以登记的前缀开头
#   RED-NEW    退出码非 0，且未登记 —— 这才是"你刚弄坏了什么"
#   RED-NEW(cause-changed)  已登记，但失败文案换了 —— 同样是"你刚弄坏了什么"，
#               只不过它藏在一条本来就红的用例里（S-11 就这么漏过一轮）。
# 退出码 = RED-NEW 条数（含 cause-changed）。
#
# known-red.tsv 四列：id <TAB> 原因 <TAB> status <TAB> 失败前缀
#   第 4 列为空 = 该条放弃文案门禁（只判"红"），登记时尽量别留空。
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
                   interaction command build campaign result skirmishbuild
                   compactgroups）
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

# —— 产物保留策略（S-27）：每天首跑 + 最近 N 次，其余删除 ——
# 单次产物约 26MB，第 46 轮审计时已堆到 157 次 / 3.6GB，且不在任何门禁里。
# 只删严格匹配 YYYYMMDD-HHMMSS 的目录（known-red.tsv 这类同目录文件一律不碰）。
prune_regress_outputs() {
  local root=$1 keep_recent=${2:-20}
  local dirs d day prev_day="" keep=" " removed=0 tail_list
  [ -d "$root" ] || return 0
  dirs=$(ls -1 "$root" 2>/dev/null | sort)
  [ -n "$dirs" ] || return 0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    day=${d%%-*}
    if [ "$day" != "$prev_day" ]; then
      keep="$keep$d "
      prev_day=$day
    fi
  done <<< "$dirs"
  tail_list=$(printf '%s\n' "$dirs" | tail -n "$keep_recent")
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$keep" in *" $d "*) ;; *) keep="$keep$d " ;; esac
  done <<< "$tail_list"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$d" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
      *) continue ;;
    esac
    [ "$d" = "$STAMP" ] && continue
    case "$keep" in *" $d "*) continue ;; esac
    rm -rf -- "$root/$d"
    removed=$((removed + 1))
  done <<< "$dirs"
  if [ "$removed" -gt 0 ]; then
    echo "   pruned   $removed 次历史产物（保留每天首跑 + 最近 $keep_recent 次）"
  fi
  return 0
}

prune_regress_outputs "$BASE" 20

TSV=$OUT/results.tsv
printf 'id\tstate\tsecs\tevidence\treason\n' > "$TSV"

KNOWN_REASON_TEXT=""
KNOWN_PREFIX_TEXT=""

# 命中已登记的 id 时把原因/前缀写进上面两个全局量（不用 $(...) 取值，
# 命令替换会 fork 子 shell，全局量带不回来）。
known_lookup() {
  local want=$1 line id reason status prefix rest
  [ -f "$KNOWN_RED" ] || return 1
  while IFS=$'\t' read -r id reason status prefix rest; do
    [ -z "${id:-}" ] && continue
    case "$id" in \#*) continue ;; esac
    if [ "$id" = "$want" ]; then
      KNOWN_REASON_TEXT=${reason:-}
      KNOWN_PREFIX_TEXT=${prefix:-}
      return 0
    fi
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

# 开跑前把台账自身的问题摊开：缺前缀的行等于放弃文案门禁，宁可先在屏幕上说出来。
known_red_preflight() {
  local line id reason status prefix rest n=0 bare=0
  [ -f "$KNOWN_RED" ] || { echo "   警告    没有 known-red.tsv，任何非零退出码都会判 RED-NEW"; return 0; }
  while IFS=$'\t' read -r id reason status prefix rest; do
    [ -z "${id:-}" ] && continue
    case "$id" in \#*) continue ;; esac
    n=$((n+1))
    if [ -z "${prefix:-}" ]; then
      bare=$((bare+1))
      echo "   警告    known-red 行「${id}」没有失败前缀（第 4 列），该条只判红不判原因"
    fi
  done < "$KNOWN_RED"
  echo "   known-red $n 条，其中 $bare 条无前缀门禁"
}
known_red_preflight
echo

run_case() {
  local id=$1 tmo=$2 envs=$3 args=$4
  if [ -n "$ONLY" ]; then
    case "$ONLY" in *",$id,"*) ;; *) return 0 ;; esac
  fi
  local log=$OUT/$id.log start end secs rc state reason evfull ev
  start=$(date +%s)
  # shellcheck disable=SC2086
  ( cd "$DATA" && env $envs timeout "$tmo" "$BIN" $args ) > "$log" 2>&1
  rc=$?
  end=$(date +%s); secs=$((end - start))
  # 失败行先取出来：既要显示，也要拿它跟前缀比对（比对必须用未截断的原文）。
  evfull=$(pick_evidence "$log")
  reason=""
  if [ $rc -eq 0 ]; then
    state="PASS"; PASS_N=$((PASS_N+1))
  elif known_lookup "$id"; then
    reason=$KNOWN_REASON_TEXT
    if [ -n "$KNOWN_PREFIX_TEXT" ] && [ -n "$evfull" ]; then
      case "$evfull" in
        *"$KNOWN_PREFIX_TEXT"*)
          state="KNOWN-RED"; KNOWN_N=$((KNOWN_N+1))
          ;;
        *)
          # 登记说红在这里，实际红在别处 —— 按新回归处理，别让 known-red 吞掉它。
          state="RED-NEW(cause-changed)"; NEW_N=$((NEW_N+1))
          reason="失败原因已变：登记前缀「${KNOWN_PREFIX_TEXT}」未出现在本轮失败行；登记原因「${reason}」"
          ;;
      esac
    else
      state="KNOWN-RED"; KNOWN_N=$((KNOWN_N+1))
      [ -z "$KNOWN_PREFIX_TEXT" ] && reason="${reason}（未登记失败前缀，本行只判红）"
    fi
  else
    state="RED-NEW"; NEW_N=$((NEW_N+1))
    [ $rc -eq 124 ] && reason="超时 ${tmo}s"
  fi
  ev=$evfull
  [ ${#ev} -gt 160 ] && ev="${ev:0:160}…"
  printf '  %-12s %-22s %3ss  %s\n' "$id" "$state" "$secs" "$ev"
  [ -n "$reason" ] && printf '  %-12s %-22s        ↳ %s\n' "" "" "$reason"
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
# 第 12 条（S-17）：真遭遇战整链路。它才是「遭遇战能不能开起来」的门，
# skirmish 那条只验 UI。第 38 轮 M-31 夹具修正后首次整条 rc=0。
run_case skirmishbuild 300 ""                                   "--skirmish-build-smoke-test"
# 第 13 条（S-22，第 43 轮）：混合编队收敛。`command` 主档跑不到这段——第 41 轮实测
# M-25 的试改让 `12E1_2MTNK_tank_first` 从 PASS 变 `arrival_timeout`，而 12 条门禁一字未变。
# 该冒烟 0.7 秒跑 7 个场景，单跑一次即可。失败文案带「N failed; 首个失败场景: 原因」，
# 所以第 4 列前缀连**计数**和**首个失败场景名**一起钉住：换掉任一个都会判 cause-changed。
run_case compactgroups 120 "CONCORD_COMMAND_SMOKE_COMPACT_GROUPS_ONLY=1" "--command-smoke-test"

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
if [ $NEW_N -gt 0 ]; then
  echo "   $NEW_N 条 NEW-RED：先看 $OUT/<id>.log，确认后要么修，要么登记进 known-red.tsv"
  echo "   （状态带 cause-changed 的表示「这条本来就红，但红的原因换了」——同样按新回归处理）"
fi
exit $NEW_N
