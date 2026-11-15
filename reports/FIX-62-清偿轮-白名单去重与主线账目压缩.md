# 第 62 轮（清偿轮）：战役动作白名单去重 + 主线收口压成账目表

**轮型**：清偿轮（`§五.2` 腐烂预算 + 比例闸触发）。源码 `897de11` 一处删除，本表结构性压缩。

## 零、为什么是清偿轮

三条独立判据同时指向同一结论，缺一条都会让这轮走成"再修一个 bug"：

1. **腐烂预算**（`§五.2`）：R57~60 净增 **+1769 / −33**（产品侧 ≈+1256，R58 一轮吃掉 96%），
   连续多轮净增 >300 而删除 <20 → 下一轮强制清偿。
2. **比例闸**（`§八.3`）：近 5 轮 test: 2 / fix: 1 = **2.0×**（等于阈值即触发），60 提交 25:9 = 2.78×。
   闸的处置是"只许改产品行为或清偿"，而 R62 的产品候选都在 blocked/deferred 里（M-25 / S-28 / C-02i），
   所以只剩清偿这一条合法路径。
3. **AUDIT-61 §7.1 已经点了名**："`S-35` 的三份白名单就是现成的删除对象（合并即净减）"。

**KPI（`§五.2`）**：净增 ≤0 且 regress 不退化。本轮达成：源码 **−137 行**，回归三态不变。

---

## 一、删了什么：`RuntimeShell.cpp` 的战役动作类型白名单（`897de11`）

### 1.1 现象

`dup-scan`（`--ref b4672b5` 同口径复跑）在 AUDIT-61 报 HEAD **146 组 / 产品侧 13 组**，
比冻结基线 138/3 多出 **10 组**，全部落在 `RuntimeCampaignCoverage.h:91..171` × `RuntimeShell.cpp:14471..14551`。
逐处看不是扫描器假阳性，是 `case 0: case 1: …` 标签串——两个"哪些 action type 受支持"的函数实体：

| 位置 | 函数 | 调用者 |
|---|---|---|
| `runtime/campaign/RuntimeCampaignCoverage.h:83` | `runtimeCampaignCoverageActionTypeSupported` | coverage inventory（`unsupportedRuntimeCampaignCoverageActionTypes`） |
| `runtime/host/RuntimeShell.cpp:14463` | `runtimeCampaignActionTypeSupported` | **只有** `--campaign-smoke-test` 的两处断言（`86132` / `86147`） |

两份 case 集已经漂开 8 型：**shell 侧缺 13 / 39 / 43 / 49 / 50 / 58 / 59 / 64**（header 认、shell 不认）。

### 1.2 口径纠正：不是"三份"

AUDIT-61 §3.3 写的是"三份动作类型白名单"，把 `RuntimeCampaignCoverage.h:25` 也算进去了。
那一份是 **事件**类型白名单（`runtimeCampaignCoverageEventTypeSupported`，trigger event），
与动作类型不是同一个事实——dup-scan 按"case 标签序列"比对，两类混在一起也会命中。
真实数量是 **2 份动作白名单 + 1 份事件白名单**。这条纠正写进本轮报告，不改 AUDIT-61 原文（历史留痕）。

### 1.3 为什么可以删

三条一起成立才删的，缺一条都该先查：

1. **shell 那份只被冒烟调用**：两个调用点都在 `--campaign-smoke-test` 的"authored 数据里有没有不支持的 action"断言里，
   产品运行路径一次都没用。删它不动任何游戏行为。
2. **它自己是副本**：header 的 inline 版本是同一事实的另一份，且是 coverage 门禁长期在用的那一份。
3. **删后输出逐字相同**（实测）：`--campaign-smoke-test` 改动前后都是
   `structuralFailures=0 … events/actions/scripts/sources/audio=PASS env-gap=ACCOUNTED`。
   原因很直接：authored 战役数据里不含那 8 个漂开的类型，因此"更宽的那份"与"更窄的那份"在当前语料上判定一致。

### 1.4 怎么删

- 删除 `RuntimeShell.cpp:14463..14575` 的整个函数（−113 行），连同其上方一串历史删除留下的空行（合计 −140）；
- 两处调用改调 `runtimeCampaignCoverageActionTypeSupported`（+2）；
- 补一行 `#include "runtime/campaign/RuntimeCampaignCoverage.h"`（+1）。

### 1.5 靠什么兜住

| 门禁 | 结果 |
|---|---|
| `--campaign-smoke-test`（regress 第 11 条 `campaign`） | PASS，输出与改动前逐字一致 |
| `regress.sh` 全量 16 条 | `PASS=14 KNOWN-RED=2 RED-NEW=0`（与基线逐条相同） |
| `dup-scan.py` | **136 组 / 产品侧 3 组**（HEAD 146/13 → 回到冻结基线 140/5 以内） |

---

## 二、压了什么：fix-plan 八段"主线整体收口判定"→ 一张账目表

`§一.5` 写着"历史收口压成一行链式索引……当前它就是最大膨胀源"。上一轮审计又补了一句
（AUDIT-61 §3.5）："两份台账字段重复必然漂移"。这两条指向同一个位置：主清单里 `## 四` 到 `## 附六`
共 **199 行**是八段主线收口的完整推理（为什么判 done、谁否定了什么），而它每轮都进上下文。

**做法**：原文整体迁 `reports/archive/fix-plan-mainlines-202611.md`（208 行，一字未删），
主清单换成一张 **9 行表**：主线 / 子项（已用/上限 4）/ 已用轮 / 判定 / 依据与代价 / 报告。
表的用法写死："两级计数就查这张表，子项数到 4、或已用轮到 4 → 该线必须整体收口（`§六.3`）"。

这解决了一个具体的记账问题：`§十三.6` 每轮要报"主线 threads 各自已用几轮"，此前得从八段散文里现数，
现在一行一眼。同时把"已满额、不许再开第 5 个子项"的四条线（C-02 9 / unit-behavior 4 / S-回归门禁 4 /
skirmish-mode-rules 4）单独列一行——这是上一轮 AUDIT-61 要求"排队先看额度"的落点。

**fix-plan 377 → 201 行**（净 −176；账目表 +20、归档 +208 不计入主清单）。

---

## 三、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做什么**

- 没判定 S-35 残留的语义问题：去重只是把两份并成一份，**没有回答"哪份的 case 集是对的"**。
  拆出 **S-36**：`runtimeCampaignCoverageActionTypeSupported` 认 13/39/43/49/50/58/59/64，
  而执行器 `applyRuntimeCampaignAction` 的 `if (type==N)` 链里这 8 型一个都没有 → coverage 门禁把它们算"已支持"，
  真缺口被漏报。这属**断言纠正**（改了会让 campaign 门禁可能变红），按 `§八.2` 不能塞进清偿轮顺手做。
- 没动 RUNLOG（1058 行 / 88KB，两处门禁都在限内）。
- 没做 AUDIT-61 §3.5 那条"plan 只留排序、字段唯一来源 = queue"的结构改造：那是比"压收口段落"更大的活，
  且要先决定"plan 侧 38 行与 queue 侧 38 条怎么对齐"。

**遗留的债**

- S-36 的 8 型判定是**一条 grep 就能起步的活**，但结论会牵动 campaign 门禁的绿/红，必须单独一轮。
- 台账双份字段的问题仍在（本轮只压了收口段落，没碰表格结构）。
- 本轮仍是**零产品行为变化**：R57~62 六轮里只有 R58/R60 两轮动过产品代码。比例闸的分母靠"清偿"补不回来。

**放弃了什么**

- 放弃"把 header 白名单收窄到执行器交集"这条更彻底的方案：它会让 campaign coverage 门禁立刻可能变红，
  而这轮的定义是"删重复、不改行为"。窄化属于产品语义决定，不是清偿。
- 放弃在清偿轮里顺带做 S-34（README 回归现状改生成）——它是新增脚本逻辑（+行），与净增 ≤0 的 KPI 反向。

---

## 四、质量四数（`§五.1`）

| 指标 | 本轮 | 说明 |
|---|---|---|
| ① 净增行数 | 源码 **−137**（+3 / −140）；docs 主清单 **−176**，归档 +208 | `git diff --shortstat`：`1 file changed, 3 insertions(+), 140 deletions(-)` |
| ② 最大单文件 | `RuntimeShell.cpp` **90,620**（−137）；`RuntimeMapRenderer.cpp` 42,542（0）；`RuntimeSessionWorld.cpp` 31,056（0） | >8,000 行文件只做删除，未新增功能块 |
| ③ 断言 vs 产品代码 | 新增断言 **0** / 产品代码 **−137** | 清偿轮不加断言（`§八.3` 已禁） |
| ④ TODO / FIXME | **0 → 0** | 全仓 `src/**` 计数 |

**重复代码**：136 组 / 产品侧 3（HEAD 146/13；冻结基线 140/5）。产品侧 3 组是已知的三对
（`ReplaySandbox.cpp/h` ×2、`CampaignDatabase.cpp` × `RuntimeCampaignCoverage.h`），均在基线上。

---

## 五、清单体检（`§一.7`）

| 项 | 结果 |
|---|---|
| fix-plan 行数 | **201 / 400**（本轮 −176，压缩达标） |
| queue.json | 59KB / 120KB，38 条 / 120 条（本轮 S-35 done、新增 S-36，等价替换） |
| rules | 5 类 × ≤3 行（未动） |
| 悬空引用 | 提交前 `refs-head` 报 2 条（本轮新报告 + 归档文件尚未入库），提交后清零 |
| 状态与报告矛盾 | 查出 1 处：`S-35` 在 plan 里写"待修复"、报告 AUDIT-61 写"已登记"——本轮已改完成并链报告 |
| 重复条目 | 0（S-35 与 S-36 是"已做的去重"与"未判的语义"，不是同一件事） |
| attempts 与收口记录 | S-35 记 0→1（本轮一次改动即结案），一致 |

**门禁自身的一处口径瑕疵**：`refs-head` 只判 HEAD，因此"本轮尚未提交的新报告"必然报红，
提交后即绿——这是设计如此（R51 起判对树），不是漂移。

---

## 六、提交清单

| 仓库 | hash | 说明 |
|---|---|---|
| ConcordRTS | `897de11` | `refactor:` 删 `RuntimeShell.cpp` 的动作白名单副本，两处调用改调 coverage 头的 inline 版本（−140/+3） |
| ra2mac_docs | 见 `git log` | `docs:` 本轮报告 + fix-plan 主线账目压缩 + 归档原文 |
| ra2mac_docs | 见 `git log` | `queue:` S-35 done / S-36 新增 / v167 / decision r62 |

---

## 七、下轮起手（R63）

1. **S-36**：8 型逐个给"执行器有/无"的 grep 级证据，再决定删白名单项还是补执行器。属 `§八.2` 的断言纠正活，
   若删白名单导致 campaign 门禁变红，`test:` 单独成 commit、报告标"断言纠正"、不计入已修复。
2. **S-34**（README 回归现状由 pack-dist 生成）：+行数的基建活，适合修复轮做伴生项。
3. 比例闸的债：R57~62 只有两轮动过产品代码，建议 R63 主目标挑一条**可观察**的（S-08 帧诊断出口解耦是现成的：
   门已开、剩下的活是把出口拆成 `flushRuntimeFrameDiagnosticsReport()` 供无窗口路径调）。
