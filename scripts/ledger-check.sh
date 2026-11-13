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

if [[ $fail -eq 0 ]]; then say "清单体量：全部在限内"; else say "清单体量：有超限项，当轮第一件事是压缩归档"; fi
exit $fail
