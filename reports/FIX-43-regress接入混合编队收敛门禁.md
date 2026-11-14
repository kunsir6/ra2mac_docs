# 第 43 轮（修复轮）：把「混合编队收敛」接进唯一那道门

日期：2026-11-15
轮型：**修复轮**（无 brake、无 attempts≥3、无腐烂预算；距 AUDIT-41 两轮）
主目标：**S-22 —— regress 12 条对「混合编队不收敛」是盲的**

## 一、为什么这条值一轮

第 41 轮审计拿到的唯一一条**有实测证据**的判定漏洞：M-25 的试改（放行载具进友军步兵格）让
`12E1_2MTNK_tank_first` 从 PASS 变 `arrival_timeout`，而 `regress.sh` 输出 **11/1/0 一字未变**。
也就是说：一个能让整支混编部队永远收不了队的改动，可以通过我们唯一的日常门禁。

这不是「某个功能没测」，是**门禁的覆盖声明本身不成立**——第 41/42 两轮所有「零新回归」的结论
都建立在 12 条上，而这 12 条看不见这一类改动。收益口径 **A**（解掉一类卡点），成本低（加壳，不改源码）。

## 二、落地

`ra2mac_docs/scripts/regress.sh` 新增第 13 条：

```bash
run_case compactgroups 120 "CONCORD_COMMAND_SMOKE_COMPACT_GROUPS_ONLY=1" "--command-smoke-test"
```

该冒烟早就存在于 HEAD（`RuntimeCompactGroupDensitySmoke.inl`，也早已注册进 cmake 的 ctest），
只是从没进过 regress。**单跑 0.68 秒、7 个场景**，相对 20~40s 的整轮回归可以忽略；不需要新增断言（§八.3 比例闸不冲突）。

### 2.1 失败文案的形态决定了前缀怎么写

该冒烟的失败出口是：

```cpp
error = "Compact groups: " + std::to_string(failures) + " failed; " + firstFailure;
//  → Compact groups: 1 failed; 3MTNK_3SHAD: ground_final_not_compact
```

只有**计数**和**首个失败场景**两个维度。如果第 4 列只写场景名（`3MTNK_3SHAD: ...`），
那么 M-25 那种「tank_first 也挂掉」会变成 `2 failed; 3MTNK_3SHAD: ...; 12E1_2MTNK_tank_first: arrival_timeout`
——**仍然包含首失败子串** → 被判成 KNOWN-RED 静默吞掉，等于白接。
所以前缀把两个维度一起钉住：

```
Compact groups: 1 failed; 3MTNK_3SHAD: ground_final_not_compact
```

### 2.2 两道负向验证（代替「重放 M-25 试改」）

DoD 第二条原本写「把 M-25 的试改重放一次能被判红」。本轮**没做**：那要整编源码（当前 cmake 重配后
需 1,642 目标全量），且会与并发会话的 11 项 WIP 混在一起。改用两次单跑（各 1 秒，改的是 `/tmp` 下的
known-red 副本，不动真台账）：

| 验证 | 改法 | 结果 |
|---|---|---|
| 换首个失败场景 | 前缀里 `3MTNK_3SHAD: ground_final_not_compact` → `12E1_2MTNK_tank_first: arrival_timeout` | `RED-NEW(cause-changed)`，退出码 1 ✅ |
| 只改计数 | `1 failed` → `2 failed`，场景名不动 | `RED-NEW(cause-changed)`，退出码 1 ✅ |

两个维度各自独立生效，因此 M-25 那种「两个维度同时变」必然被抓。

## 三、接上就照出一条真红（新登记 S-23）

首跑读数：

```
Compact groups: 12E1_2MTNK_foot_first  … settled=2337 PASS
Compact groups: 12E1_2MTNK_tank_first  … settled=1870 PASS
Compact groups: 3MTNK_3SHAD … settled=1116 stable=90 groundRadius=2 airRadius=1 ground_final_not_compact
Compact groups: cases=7 passed=6 failed=1
```

判据在冒烟自己里算：地面容量 `minimumCells[0] = tanks + ships + ceil(infantry/3) = 3`，
`minimumRing(3) = 1`（3 个格只需 Chebyshev 半径 1 的 3x3 就装得下），实测 `groundRadius=2`。
`settled=1116` 说明**收敛了、不是超时**，只是收得散。

根因**未验证**，两条候选（改法相反，先只读计量）：
① 地面候选格按最近环取，但同目标的 3 架 `SHAD` 在 air 层的占用被一起算进避让；
② `tanksFirst` 分批下发，让第二批在第一批之外再开一圈。

→ 登记 **S-23**（中等 / B），`thread=S-回归门禁`。它和 S-22 是同一条线的两面：
一条是「门禁看不见」，一条是「门禁看见了、红着」。

## 四、DoD 偏差（原文不改，写在这里）

S-22 的验收条件是第 41 轮写下的两句，本轮**没有**改动它（§八.1）：

1. ~~「regress 输出 PASS=12」~~ → 实测 **PASS=11 / KNOWN-RED=2 / 共 13 条**。
   差的不是门禁没接上，是这条首跑即红。**不硬凑**：让 3MTNK_3SHAD 转绿是产品工作（已登记 S-23），
   把红登记成 known-red 才是正确形态，而不是反过来去改断言。
2. ~~「重放 M-25 试改能被判红」~~ → 未做，用 2.2 的两道负向验证代替（见上表）。

因此本条按「门禁已上线、DoD 第二句以等价手段达成、第一句的数值前提被现实推翻」结案，
偏差写在摘要与 queue 的 detail 里，不藏。

## 五、质量四数与收口

| 项 | 值 |
|---|---|
| 本轮净增行数 | 源码仓库 **零提交 / 0 行**；文档 +8/−1（`regress.sh` +8/−1，`known-red.tsv` +1，其余为改写） |
| 最大单文件行数 | `RuntimeShell.cpp` 90,626（0）/ `RuntimeMapRenderer.cpp` 42,542（0）/ `RuntimeSessionWorld.cpp` 30,794（0） |
| 断言 vs 产品代码 | 新增断言 **0** / 产品代码 **0**（§八.3 比例闸仍生效，本轮只加壳） |
| TODO/FIXME/探针 | 0 / 0（未新增探针） |

- 回归：基线 `11/1/0`（`20261115-030945`）→ 收口 `11/2/0`（`20261115-031104`），**13 条，RED-NEW=0**。
- 清单：`ledger-check.sh` **九项全绿**；`S-22` 结案进已完成窗口，新增 `S-23`，1:1 归档 `M-29` 到
  `queue-archive-202611c.json`（tasks 35 条不变）。
- dist：源码零改动 ⇒ 不重编，复用两切片重新 lipo + `pack-dist`，门禁逐条复核（见 §六）。

## 六、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做什么**
- 没重编源码。`ninja -n` 仍报 1,642 目标全量（并发会话改 `cmake/PlatformApple.cmake` 触发 cmake 重配）；
  本轮源码零改动，重编只会把 11 项未提交 WIP 烘进包，可追溯性更差。
- 没把「载具穿步兵」接进 regress，虽然它就是 M-25 那台缺陷的现成判据。
  原因：`RuntimeVehicleInfantryPassThroughSmoke.inl` 仍是并发会话的**未跟踪文件**；
  接上去之后，任何一次干净树重建都会使该环境变量不存在 → `--command-smoke-test` 退回跑主档，
  以另一条失败文案红出来，制造一条永久假 `cause-changed`。**登记为 S-24（blocked）**，
  等它随 M-25 一起提交再接线。
- 没做 S-22 的第二条 DoD（重放 M-25 试改），改用两道负向验证。

**遗留的债**
1. `3MTNK_3SHAD` 真红（S-23）现在挂在 known-red 里。它是一条**产品行为差异**，不是夹具问题：
   3 台坦克收成 5x5。known-red 只是让它「可见但不阻塞」，不等于修好。
2. 载具穿步兵（M-25）的判据已存在但**未进门禁**，且它现在是红的（`friendlyInfantryCell=0`）。
   接线的前置是那个 `.inl` 进 HEAD。
3. `command` 那条 known-red（奴隶矿工不交货）仍在。C-02i 本轮仍未取数 —— 按第 42 轮约定，
   第 44 轮起**移入 `deferred.md`**，不再占着「唯一 known-red」的位置给台账制造持续噪声。

**放弃的**
- 放弃「本轮顺手把 3MTNK_3SHAD 修绿」：它需要先加只读计量（每台目标格 + 候选环）再动分配器，
  在当前源码不可编译窗口（并发 WIP）里做等于盲改。
- 放弃「把 regress 扩到 14 条」：第 13 条已经证明「接上就红」，再加一条红只会把门禁的信号稀释。
  先把已接的两条（`command` / `compactgroups`）变成可持续的信号，再谈扩面。
