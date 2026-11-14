# FIX-47 — 飞行器落地礼让「正在赶往同格」的地面单位（S-23 结案）

**轮型：修复轮**（T+0~3 判定：无 brake、无 attempts≥3、无腐烂预算、距 AUDIT-46 一轮；
§八.3 比例闸近期 test: 为 0，不触发禁断言）。**主目标 S-23**，产品行为改动一处，
回归 `11/2/0` → **`12/1/0`**（第 13 条 `compactgroups` 由 KNOWN-RED 转 PASS）。

---

## 一、第 44 轮留下的两个候选修法，选 (a)

第 44 轮已把根因钉在落位侧：`3MTNK_3SHAD` 里地面 3 台的目标格与空中 3 架 SHAD 的目标格
**完全同格**（这是分配器被要求的行为，两层都必须用到中心格），而 SHAD 到达后
`airborne` 落回 0，重新进入**地面**占位，于是那一格对坦克来说变成已占用 → 兜底挪到半径 2。

两个候选：
- (a) 静默飞行器保持 `airborne` / 落地避开已认领格；
- (b) 被挤开后回填（单独不够）。

取 **(a)**，但**不是**"静默就不落地"——那会把直升机永远挂在天上，属于改坏零售行为。
落到具体判据上是：**只在这一格被另一个地面单位的移动目标认领时才推迟落地**，
认领一消失（对方到位或被改派）就照常落。

## 二、改法（14 行，单函数，`8e62b4d`）

`runtimeJumpjetShouldLand()`（`RuntimeSessionNavigation.cpp:9767`）是"空闲落地"的唯一判定口，
原来只检查自身状态（mission / behavior / 队列 / 航路点）+ 本格地形是否可落地。
在拿到 `current` 之后、查地形之前加一道**礼让检查**：

```
遍历 state.behaviors：
  · 跳过自己
  · 只认 kind == Move（战斗/追击不参与）
  · state 为 Complete/Idle 的一律跳过（已到位的不算认领）
  · moveTarget 必须就是本格
  · 该 mover 必须 alive 且 !airborne（空中单位不认领地面格）
命中任意一条 → return false（保持空中，下一拍重新判定）
```

不动起飞、不动寻路、不动战斗、不动分配器。飞行器的表现是"多盘旋一会儿再落"，
不是"永不落地"：坦克进入那格后行为转 Complete，认领消失，SHAD 下一拍即落。

## 三、读数

| 项 | 改动前 | 改动后 |
|---|---|---|
| regress 汇总 | `PASS=11 KNOWN-RED=2 RED-NEW=0`（`20261115-063122`） | **`PASS=12 KNOWN-RED=1 RED-NEW=0`**（`20261115-063716`） |
| `compactgroups` | `1 failed; 3MTNK_3SHAD: ground_final_not_compact; ground_target_unreached …` | `cases=13 passed=13 failed=0` |
| `command` | KNOWN-RED（前缀不变） | KNOWN-RED（前缀不变，逐字一致） |

同批 12 个场景（含 `5SHAD` 纯空中、`11MTNK` 纯地面）全部保持 PASS——礼让只在
"地面单位正在赶往该格"时生效，纯空编队没有认领者，落地行为与改动前逐字相同。

**定向验证（本轮加做，防"修好一处、改坏另一处"）**：落地有两套完全不同的入口，
本轮只碰了「空闲自动落地」。另跑文档里那条正牌落地冒烟：

```
CONCORD_COMMAND_SMOKE_AIRCRAFT_LANDING_ONLY=1 --command-smoke-test
→ Aircraft landing: passed=36 produced=144 touchdowns=36 saves=8+8 pairedTicks=53696 rc=0
```

36/36 全过（ORCA/BEAG × GAAIRC/AMRADR × 30/60 拍 × 四个停机位 + stop/redirect/host-loss），
说明 `dockRuntimeAircraft` 那条进库航线一字未动。

## 四、质量四数（§五.1）

1. **本轮净增**：+14 行（`1 file changed, 14 insertions(+)`，产品代码，单 TU）。
2. **最大文件行数**（HEAD）：`RuntimeShell.cpp` 90,611（0）/ `RuntimeMapRenderer.cpp` 42,542（0）/
   `RuntimeSessionWorld.cpp` 30,794（0）。三处均未触碰。
3. **新增断言 vs 新增产品代码**：0 / 14。本轮**零新增断言**（§八.3 比例闸下仍按"能不改断言就不改"）。
4. **TODO/FIXME**：0 → 0。无临时探针（改动即产品逻辑，无 env 开关）。

## 五、两本账

- **条目级**：`S-23` attempts 1 → 结案（第 44 轮 attempts=1 是"根因确认"那一轮，本轮在同一 attempts 上完成实施，
  不再 +1，避免把"同一件事的两步"记成两次失败）。
- **主线级 `S-回归门禁`**：子项 4/4 已满（S-22 / S-23 / S-24 / S-25），用满 3 轮 →
  **本轮整体收口，判 done**，见 `fix-plan.md` §九。禁止再开第 5 个子项。

## 六、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做**
- 没有把 `S-24`（载具穿步兵冒烟）接进 regress：那个 `.inl` 仍是并发会话的未跟踪文件，
  干净树重建后环境变量会消失并制造永久假 `cause-changed`（第 43 轮的结论仍然成立）。
- 没有动 `S-25`（`--command-smoke-test` 首败即断、掩蔽尾部 19 步）：它是 60 分支的结构改造，
  属中等，单独成轮。
- 没有碰并发会话的 11 项 WIP（`compat/win32` 文本层、`RuntimeSessionWorld` 等），一个 hunk 都没动。

**遗留债**
- 礼让判据只覆盖 `kind == Move` 的认领。**追击（`Chasing`）与 AreaGuard 的落点不参与**：
  一个正在追敌的地面单位被落地的飞行器占格时仍会被兜底挪走。这是有意的收窄（追击目标本身会变），
  但它是已知行为差异，写在这里而不是留给下一个人发现。
- `ground_target_reclaimed` 仍零触发——本轮改动发生在"到达之前"，所以这条读数继续沉默，
  它证明不了新逻辑，也否定不了。真正兜住这次改动的是 `compactgroups` 13 例全绿。

**放弃**
- 放弃"落地时挑一个不冲突的空格"的方案：那会让飞行器落点与玩家下令的格不一致，
  且在没有冲突的图上也要额外搜格（默认行为被动过）。礼让的代价只是"多飞一拍"，可逆。
- **放弃本轮开第二个中等项**（§四.3 的余量条款）：剩下的中等项里 `M-25`/`M-28` 正被并发会话占着
  （两份未跟踪 `.inl` + 678 行 WIP），`S-08`/`S-26` 是元工作（AUDIT-46 刚点过这一类），
  `M-26` 落在输入拾取链上、验证只能靠新增断言。宁可本轮只有一个产品目标，也不在同一轮里
  既改行为又改判据。

## 七、清单体检（§一.7）

- `fix-plan.md` 247 行 / `queue.json` 69KB / 35 条 / rules 5 类 —— 九项门禁全绿（`ledger-check.sh`）。
- 悬空报告引用：0（S-23 报告指向 FIX-44，本轮新增 FIX-47）。
- 状态与报告矛盾：修 `S-23` 状态（根因已确认 → 已完成）；`compactgroups` 已从
  `known-red.tsv` 注销（**这是本轮唯一必须同步的一处**，否则下一轮它转绿后仍占着 known-red 名额）。
- 重复条目 / attempts 与收口不符：无。

## 八、dist

见本轮收口记录（`dist/BUILD-STAMP.txt`）。两端切片重编 → lipo → adhoc 重签 → `pack-dist.sh`，
stamp 里带 `wip=concurrent(11)`：本机树上有并发会话的 11 项未提交改动，
按十.3 的链路重编**会**把它们烤进包，这与第 44 轮同一处理，stamp 明示。
