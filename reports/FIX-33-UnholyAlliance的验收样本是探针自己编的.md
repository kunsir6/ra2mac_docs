# FIX-33 UnholyAlliance 的验收样本是探针自己编的（第 32 轮，修复轮）

**轮型：修复轮。** 主目标 M-29（主线 `skirmish-option-semantics`），产品行为零改动。

## 一、上轮结论与本案起点

第 31 轮把 `option semantics` 的阻塞点定在 `ownerFactory=no unholy=no`，并给出三个候选根因
（探针没拿到模式规则 / 工厂归属兼容没放宽 / 目录里没有 NAPOWR），要求先读数再改。
本轮读数把三条候选**全部否掉**，真因是第四个：**探针自己编了一个数据里不存在的样本**。

## 二、读数（一次运行搞定，`RuntimeShell.cpp:15654` 那三行）

```
ownerFactory=no unholyRules=yes unholyCatalog=9 sovietPower=no
alliedYardSoviet=no sovietYardSoviet=no
loadedCatalog=46 loadedHasNapowr=no loadedHasSmcv=no
unholyIds=YABRCK,NAPSIS,GAAIRC,GAPILE,AMRADR,NAREFN,NAHAND,NARADR,GAREFN
```

三条读数各自否掉一条：

| 读数 | 否掉了什么 |
|---|---|
| `unholyRules=yes` | 候选①「`unholyProbe` 新建只补了 rules/economy、模式规则没加载」不成立——规则确实加载了 |
| `unholyCatalog` 的 9 条全是各阵营**基础建筑** | 候选③「catalog 里没有 NAPOWR」是对的，但**不是缺陷**：零售模式就是不给电站 |
| `loadedCatalog=46` 且 `loadedHasNapowr=no` | 候选②无意义：真实玩家目录按 Owner 过滤，苏军条目从来不在里面 |

**零售 UnholyAlliance 真正授予的是 9 栋「对面那几家的基础建筑」**：兵营（GAPILE/NAHAND/YABRCK）、
矿厂（GAREFN/NAREFN）、雷达（AMRADR/NARADR）、空军指挥部（GAAIRC）、心灵探测器（NAPSIS）。
电站不在其中，所以拿 NAPOWR/YAPOWR 当样本，测的是一条根本不存在的规则。

三台 MCV 也不在模式 ini 的目录段里——它们走 rules 层的
`runtimeUnholyAllianceAdditionalMcvTypes`。旧断言把「目录里有 AMCV/SMCV/PCV」
当成了发放条件（`unholyOwnerApplied`），同样是编出来的前提。

## 三、改法（`225d310`，+63−46，单文件单函数）

1. **跨阵营样本改为从探针自己的目录里取**：按 `aiBasePlanningSide` 选第一栋非本方建筑
   （本轮取到 YABRCK / side=2），再由它的 side 决定用哪座车厂（`YACNST` / `NACNST`）。
   期望值从常量变成关系——这条主线已经第四次踩同一个坑（C-02d 赌船货次序、C-02f 赌建筑左上角、
   C-02g 赌渲染窗口、本轮赌电站）。
2. **删掉 `unholyOwnerApplied`**（目录里必须有三台 MCV），MCV 发放只在数据真正所在处断言一次：
   `runtimeUnholyAllianceAdditionalMcvTypes` 返回 2 台、含 SMCV/PCV、且 `techLevel==0`。
3. 两个兼容谓词各自具名（`alliedYardAcceptsForeignBuild` / `foreignYardAcceptsForeignBuild`），
   失败文案要能说出「哪一侧不同意」，而不是压成一句 `ownerFactory=no`。

**结果**：`ownerFactory` 由 `no` 转 **yes**（`alliedYardForeign=no foreignYardForeign=yes`——
本方车厂拒绝对面建筑、对面车厂接受，正是设计的语义）。`unholy` 仍为 `no`，阻塞点后移到
MCV 发放段，本轮时间不够再定位，已写进下轮起手。

## 四、质量四数

| 指标 | 值 |
|---|---|
| 本轮净增 | **+17**（`1 file changed, 63 insertions(+), 46 deletions(-)`，产品代码 0 行） |
| 最大单文件 | `RuntimeShell.cpp` 90,476（基线 90,459，+17）；`RuntimeMapRenderer.cpp` 42,578（不变）；`RuntimeSessionWorld.cpp` 30,794（不变） |
| 新增断言 vs 产品代码 | 断言改写 1 处（三合一段 → 关系式），**新增断言 0**；产品 +0 |
| TODO/FIXME | 0 → 0 |

大文件准入：`RuntimeShell.cpp` 净增 17 行 < 50，未触发说明义务。一次性读数
（`loadedCatalog` / `loadedHasNapowr` / `unholyIds`）**在同一轮内已删**，未跨轮存活。

## 五、回归

`bash ra2mac_docs/scripts/regress.sh`：**PASS=10 / KNOWN-RED=1 / RED-NEW=0**
（`20261114-033749`），`command` 失败前缀一字不变。
注：本轮构建把并发会话的 compat 文本层 WIP（6 文件 +324 行）编进了二进制，
回归是在「其 WIP 已入二进制」的前提下取的，不是纯基线。

## 六、清单体检

| 项 | 结果 |
|---|---|
| fix-plan 行数 | 162 → 162（≤400；M-29 行改写与摘要替换净增 0） |
| queue.json | 44 KB / 35 条 / 13 字段（全在限内） |
| `ledger-check.sh` | 六项全绿（fix-plan / queue-bytes / queue-tasks / queue-rules / detail-lines / dup-ids） |
| 悬空引用 | 0（新报告已回填到 M-29 与轮次索引） |
| 状态与报告矛盾 | 0（M-29 由「待修复」改「已完成（断言纠正）」并链本报告） |
| 重复条目 | 0 |
| 本轮压缩/归档 | 无需压缩（未触限）；本轮**未新增条目**（只改 M-29 状态），故不触发「等价替换」 |

## 七、两级计数

- **条目级**：M-29 attempts 0 → 1 后结案；C-02i=2（blocked，不再动）；无 attempts≥3 未结案条目。
- **主线级**：`skirmish-option-semantics` = M-29 一条子项、**2 轮**（第 31 轮登记、32 轮推进），
  子项数与轮次均未到限。但它已符合「深水区」形态（同一句多谓词、连续两轮产品行为无变化），
  **第 33 轮起按 §六.6 换赛道**，不许在本线开第二条子项。
  `skirmish-mode-rules` 已判 done（3 轮）；`C-02` 仍 blocked（11 轮）。

## 八、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：S-17（把 `--skirmish-build-smoke-test` 接进 regress 第 12 条）。虽然 M-29 的
  `ownerFactory` 门已清，但整条链路仍未跑通，**接进回归会立刻多一条红**，按纪律不接。
- **没做**：M-13（真实遭遇战开局取证）。它阻塞在同一个冒烟上，与本轮同因，等链路绿再谈。
- **遗留债**：`unholy` 这一段仍红，阻塞点已后移到 MCV 发放（`additionalMcvs` 数量/techLevel 之一为假），
  下轮一条读数即可裁定，不需要再改产品。
- **放弃了**：不再尝试「让 NAPOWR 出现在目录里」这条路。它的实现方式（放宽
  `addRuntimeRulesBuildCatalog` 的 Owner 过滤）会改所有模式的侧边栏内容，收益是假的
  （零售模式不提供该建筑），成本是真跨模块。
- **口径代价**：本轮按 §八.2 记为**断言纠正**，不计入「已修复」计数；产品行为净增 0。
