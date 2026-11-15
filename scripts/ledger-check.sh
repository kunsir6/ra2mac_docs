#!/usr/bin/env bash
# 清单体量门禁（S-14）——「写进规则但没人量的指标一定会失真」。
# 用法：bash ra2mac_docs/scripts/ledger-check.sh [--quiet]
# 退出码：0 全部在限内；1 有超限项。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN="$ROOT/ra2mac_docs/reports/fix-plan.md"
QUEUE="$ROOT/ra2mac_docs/progress/queue.json"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

fail=0
say() { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }

check() { # name actual limit unit
  local name="$1" actual="$2" limit="$3" unit="$4"
  if [[ "$actual" -gt "$limit" ]]; then
    printf 'LEDGER-BREACH  %-14s %s%s > %s%s\n' "$name" "$actual" "$unit" "$limit" "$unit"
    fail=1
  else
    say "$(printf 'ok  %-14s %s%s / %s%s' "$name" "$actual" "$unit" "$limit" "$unit")"
  fi
}

# 1. fix-plan 行数（红线 400）
if [[ -f "$PLAN" ]]; then
  check fix-plan "$(wc -l < "$PLAN" | tr -d ' ')" 400 " 行"
else
  printf 'LEDGER-BREACH  fix-plan 缺失：%s\n' "$PLAN"; fail=1
fi

# 2. queue.json 体积（红线 120KB）与 tasks 条数（红线 120）
if [[ -f "$QUEUE" ]]; then
  check queue-bytes "$(( $(wc -c < "$QUEUE" | tr -d ' ') / 1024 ))" 120 " KB"
  read -r task_count rule_count <<<"$(python3 - "$QUEUE" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
r=d.get('rules',{})
cats=[k for k in r if isinstance(r[k],list)]
long=[k for k in cats if len(r[k])>3]
print(len(d.get('tasks',[])), f"{len(cats)}{'+超行:'+','.join(long) if long else ''}")
PY
)"
  check queue-tasks "${task_count:-9999}" 120 " 条"
  say "ok  queue-rules    $rule_count 类（限 5 类 × ≤3 行）"
  [[ "$rule_count" == 5* ]] || { printf 'LEDGER-BREACH  queue-rules 分类数异常：%s\n' "$rule_count"; fail=1; }
else
  printf 'LEDGER-BREACH  queue.json 缺失：%s\n' "$QUEUE"; fail=1
fi

# 3. 单条 detail ≤6 行
long_detail=$(python3 - "$QUEUE" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
bad=[t['id'] for t in d.get('tasks',[]) if t.get('detail','').count('\n')>5]
print(len(bad), ','.join(bad[:5]))
PY
)
check detail-lines "${long_detail%% *}" 0 " 条超 6 行"

# 4. 条目 id 唯一（第 31 轮踩过：并发会话各自新增，两本账撞了同一个 M-25）
dup_ids=$(python3 - "$QUEUE" <<'PY'
import json,sys,collections
d=json.load(open(sys.argv[1],encoding='utf-8'))
ids=[t.get('id','') for t in d.get('tasks',[])]
dups=[k for k,v in collections.Counter(ids).items() if v>1]
print(len(dups), ','.join(sorted(dups)[:5]))
PY
)
check dup-ids "${dup_ids%% *}" 0 " 条重复 id"

# 5. 条目字段完整性（第 34 轮加）：缺根因/收益/成本/性价比/复杂度/验收的条目
#    按 §一.4 不许进排序。第 30 轮审计记过 11 条、第 33 轮只处置 1 条、第 34 轮
#    才发现实际是 16 条——「写在规则里但没有东西去量」第二次失效，故做成硬门禁。
#    已结案（done）条目豁免：它们的历史字段已归档。
incomplete=$(python3 - "$QUEUE" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
need=['root_cause','value','cost','roi','complexity','verify']
def missing(t):
    return [k for k in need if not str(t.get(k,'')).strip() or str(t.get(k,'')).strip() in ('待估','未估')]
bad=[t.get('id','') for t in d.get('tasks',[]) if t.get('status')!='done' and missing(t)]
print(len(bad), ','.join(bad[:5]))
PY
)
check entry-fields "${incomplete%% *}" 0 " 条缺估值字段"

# 8. RUNLOG.md 体量（第 42 轮加）：第 41 轮审计发现它是清单之外唯一无人量的膨胀源——
#    516KB / 8,178 行，七项门禁一个都不管它。归档口径同 §一.2：正文只留最近轮次，
#    更早的原文进 progress/archive/，主文件留一行指针。
RUNLOG="$ROOT/ra2mac_docs/progress/RUNLOG.md"
if [[ -f "$RUNLOG" ]]; then
  check runlog-lines "$(wc -l < "$RUNLOG" | tr -d ' ')" 1500 " 行"
  check runlog-bytes "$(( $(wc -c < "$RUNLOG" | tr -d ' ') / 1024 ))" 120 " KB"
else
  printf 'LEDGER-BREACH  runlog 缺失：%s\n' "$RUNLOG"; fail=1
fi

# 9. 引用可追溯（第 51 轮加）：fix-plan 里的 reports/*.md 必须落在 docs HEAD 里。
#    旧做法判的是「工作区里有没有这个文件」，于是并发会话的未跟踪报告一路绿灯——
#    别人 clone 之后那些链接全是 404。第 50 轮把它记成「悬空引用」但没法治，根因就是判据选错了树。
#    代价：新增报告在提交前必然 BREACH（HEAD 里还没有）。收口顺序固定为「先 commit 报告，再跑本门禁」。
refs_missing=$(cd "$ROOT/ra2mac_docs" && python3 - <<'PY'
import re, subprocess
plan = open('reports/fix-plan.md', encoding='utf-8').read()
refs = [r for r in sorted(set(re.findall(r'`(reports/[^`]+\.md)`', plan))) if '*' not in r]
tracked = set(subprocess.run(['git', '-c', 'core.quotepath=false', 'ls-tree', '-r', '--name-only', 'HEAD'],
                             capture_output=True, text=True).stdout.split('\n'))
bad = [r for r in refs if r not in tracked]
print(len(bad), ','.join(bad[:3]))
PY
)
check refs-head "${refs_missing%% *}" 0 " 条引用不在 HEAD"

if [[ $fail -eq 0 ]]; then say "清单体量：全部在限内"; else say "清单体量：有超限项，当轮第一件事是压缩归档"; fi
exit $fail
