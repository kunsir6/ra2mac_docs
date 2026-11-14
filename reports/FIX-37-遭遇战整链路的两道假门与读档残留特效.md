# 第 37 轮（修复轮）：遭遇战整链路的两道假门 + 读档残留特效

> 轮型：**修复轮**。主目标 **M-30**（整链路 `unholy` 段，8 条条目的公共钥匙）。
> 回归 `10/1/0` → `10/1/0`（`20261114-165859` → `20261114-171407`），零新回归、`command` 前缀不变。

---

## 一、M-30：`unholy` 段恒 no，是验收要求了「侧栏可造」这件功能没有的事

### 读数（一次运行，`--skirmish-build-smoke-test`，0.2s 到该段）

```
option semantics modeRules=yes alliesAllowed=yes mustAlly=yes ownerFactory=yes
unholyRules=yes unholyCatalog=9 foreignItem=YABRCK foreignSide=2
alliedYardForeign=no foreignYardForeign=yes
unholy=no
unholyMcvs=2 unholyMcvDetail=[SMCV:tl=10:into=NACNST:owner=Russians,…
                               PCV:tl=10:into=YACNST:owner=YuriCountry]
```

其余 26 位全是 `yes`，只有 `unholy` 一位是 no。`unholyApplied` 是五个谓词的合取，
前四个已确认成立，第五个 `unholyMcvApplied` 里只有 **`unit->techLevel == 0`** 这一条为假。

### 根因

`rulesmd.ini` 里三台 MCV 的 `TechLevel` 都是 **10**（AMCV/SMCV/PCV 全部）。
而 UnholyAlliance 的发放走的是 **开局生成**：`spawnRuntimeUnholyAllianceMcvs`
（`RuntimeSessionWorld.cpp:15572`）直接 `addRuntimeObjectInstanceForOwner` 铺车，
**从头到尾不读 techLevel**；techLevel 只影响侧栏能不能造。

旧断言把「模式发放 → 侧栏可造」当成了同义词，于是这条链路从第 32 轮起一直
停在 option semantics 之后，后面几十段断言（含存档往返）自第 13 轮起从未执行过。

### 改法（`d2fff47`，test:，标「断言纠正」，不计入已修复）

换成**数据推导**的等价条件，三条都可独立被推翻：

1. 每台被发放的单位 `owner` 都不含本方（`AMERICANS`）——「对面阵营的 MCV」这句人话；
2. 发放台数 == `rules` 里**非本方**车厂数（本方 `GACNST` → 2 台 SMCV/PCV）；
3. 同一个调用在**非** UnholyAlliance 探针（同文件已有的 MeatGrind 探针）上返回空
   ——普通局不许开局白送 3 台 MCV，这是本条唯一能反向失败的性质。

失败文案同时带每台 `type/techLevel/deploysInto/owner`，下次再红不用重新加读数。

结果：`unholy=yes unholyMcvs=2 unholyNonNativeYards=2 unholyOffModeMcvs=0`，
整链路第一次跑过 option semantics，进到 `Skirmish start: … objects=14`。

---

## 二、连带修掉：读档后上一局的命中特效还飘在新地图上（`e32136b`）

跑过上一道门后立刻暴露：`transient save/load roundtrip diverged`，但失败行打出的
六个数字**全相等**（`projectile=yes next=相等 gattling=相等 crates=2/2 hash=相等`）。
把这 12 条谓词拆成逐项布尔（`379f06b`）后一次读数确定是 `impacts=no`。

- `impactEffects` 不在存档里（`RuntimeSaveDocument` 从不写它）；
- 也不在 `commitRuntimeLoadedState` 的 swap 白名单里（`RuntimeSessionPersistence.cpp:7752`）；
- 所以读档只是**把世界换掉**，旧世界的火花/死亡特效原样留在 live 状态里继续飘，
  直到自然过期。它们带的是旧世界的格坐标与对象 id，读档后已经没有意义。

改法：在 `commitRuntimeLoadedState` 末尾清一次 `live.impactEffects`。这是 UI 读档与
所有冒烟共用的唯一收口点，一处覆盖全部路径。修完 `impacts` 转 `yes`，
该段整体通过（这是它首次被执行到并通过）。

**判定依据**：该断言此前从未跑到。修完不是「改断言让它绿」，而是同一个断言
在同一个位置由 `impacts=no` 转 `yes`；`command` 那条 known-red 的失败前缀一字未变。

---

## 三、新阻塞 M-31：legacy 存档的「字符串手术」如今被载入拒绝

过了往返段后，链路立刻进到 legacy 兼容段（`RuntimeShell.cpp:81705`）：
拿一份 v14 的库存档文本，把 `Version=14` 改成 `Version=10`、删掉
`Projectiles/GattlingWeaponTimers/Crates/DeathWeaponRuntime/BuildLimitHistory`
五段，期望载入时这些瞬态集合**回到基线**。

实测载入**整体失败**：`error=invalid behavior record`，随后 12 个数字全是手术前
故意弄脏的值（`next=999999 / replayNext=99 / deathTombstones=5 / crates=2`），
说明是短路在载入本身，不是「清不干净」。

**已排除**：本轮两处改动都不碰行为记录解析（一处是 option semantics 的探针条件，
一处是 commit 末尾清 `impactEffects`），且该段此前从未执行过。

**未定的两种解释（改法相反，不许猜）**：

1. **夹具侧**：库存档已经演进（v14 有 `Behaviors` 记录段，v10 的记录布局不同），
   单改版本号不再是合法的 v10 存档 → 应该**另造**一份真正的 v10 夹具，而不是改版本号；
2. **产品侧**：载入应当对「版本号与段布局不一致」给出明确拒绝（它现在确实拒绝了，
   但文案 `invalid behavior record` 说不清是版本不符还是记录损坏）。

登记为 **M-31**（中等，先只读定性）。它属于**新的主线 `persistence-roundtrip`**，
不是 `skirmish-option-semantics` 的第 3 个子项——那条主线本轮已整体收口（见 §四）。

---

## 四、主线收口判定

**`skirmish-option-semantics` 判 done（第 37 轮）**：2 个子项、窗口内完成。

- M-29（`225d310`）：验收样本 NAPOWR 是探针自己编的，零售模式从不给电站；
- M-30（`d2fff47`）：验收要求 techLevel=0，而发放是开局生成、根本不看 techLevel。

两处都是**同一种形态**：把「功能没有的性质」写进验收。这条线上没有真产品缺陷。
代价（写清）：链路继续往后的 legacy 段仍红，所以 **S-17 仍不能接进 regress**（仍 11 条）。

`persistence-roundtrip` 新主线开账：1 轮 / 1 子项（M-31），已排除本轮引入。

---

## 五、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：M-31 只登记没动手（时间锚点到点，且两种解释改法相反，必须先用一份
  合法 v10 夹具定性）；S-17 未接进 regress（链路未整条绿，接进去就是登记一条 known-red，
  规则明确禁止）；并发会话的 `M-25`（unit-behavior）与其 compat 文本层 WIP 零触碰。
- **遗留债**：①本轮两次 `test:`（`d2fff47`/`379f06b`）仍是断言侧改动，
  近 60 提交 `test:`/`fix:` 比例未因本轮收敛；②`Run` 侧 `--skirmish-build-smoke-test`
  仍未进任何门禁，它已经连续暴露了 4 段「从未执行过」的断言（C-02d/f/g、M-30、本轮两段）；
  ③legacy 段的 v10 夹具不存在，每次靠字符串手术。
- **放弃了什么**：放弃了「顺手把 `recentExpiredProjectiles`/`recentReplayEvents` 一起清掉」
  ——它们在当前路径上是自然空的，没有失败证据支撑的清理会把「为什么清」变成猜测；
  也放弃了在本轮内追 `invalid behavior record` 的解析细节（读到 8.1 万行那一段
  至少还要一次构建 + 一次运行，会把收口挤掉）。

---

## 六、质量四数

| 指标 | 值 |
|---|---|
| 本轮净增行数 | **+77**（`105 insertions / 28 deletions`，3 个 commit） |
| 最大单文件 | `RuntimeShell.cpp` **90,551**（第 36 轮 90,482，+69 中含并发 WIP +6） |
| 断言 vs 产品代码 | 断言**改写 2 处、新增 0 条**（比例闸生效）；产品行为 **+8 行** |
| TODO/FIXME | 0 → 0 |

单次改动对 `RuntimeShell.cpp` 的净增最大为 +37（`d2fff47`），未触发 >50 行的说明义务。

## 七、清单体检

`ledger-check.sh` 七项全绿；35 → 35 条（新增 M-31 ↔ 归档 S-16 腾位）；
fix-plan 189 → 190 行（远低于 400）；queue 54 KB（限 120）；rules 5 类 7 键。
悬空报告引用 0 条；状态与报告矛盾 0 条；重复 id 0 条。
