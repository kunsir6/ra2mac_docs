# FIX-60 伞兵下落过程中可选（M-26 结案）

> 轮次：第 60 轮（2026-11-15 21:0x）｜类型：修复轮（单点）｜用户口径：**原版下落过程中能选**
> 关联：队列 `M-26`、fix-plan 附四/附五、回归第 16 条 `paradropsel`

## 一、现象与口径

用户在遭遇战里空投伞兵，落地之前点不动，落地之后正常。第 59 轮把这条挂在 `M-26`，
根因假设写的是「hit test 坐标口径错位（视觉位置带 z 偏移、命中框仍用地面脚点）」，
但前置问题「原版到底能不能选」一直没答，于是只当取证类挂着。

**2026-11-15 20:53 用户定口径：下落过程中能选。** 于是这条从「先答口径」变成「判决错误、必须修」。

## 二、真因（推翻原假设）

不是命中框算错了，是**三处显式把 `mission=="ParadropDrop"` 排除在外**，其中最要命的一处每拍执行：

| # | 位置 | 行为 |
|---|---|---|
| ① | `RuntimeSessionWorld.cpp` `cleanRuntimeSelection()` | 每拍末尾把 `mission=="ParadropDrop"` 从 `selectedObjectIds` 里删掉 |
| ② | `RuntimeShell.cpp` `runtimeObjectCanBeBoxSelected()` | 框选直接不接受 |
| ③ | `RuntimeSessionWorld.cpp` `runtimeObjectCanMove()` ＋ `RuntimeSessionFeedback.cpp` `runtimePlayerActorTemporarilyCommandLocked()` | 下落中拒绝一切命令 |

关键在于**点击那条路（`runtimePlayerLocalSelectable`）并不过滤 ParadropDrop**：点下去的瞬间它
真的进了选中列表，播完这一帧、tick 收尾就被 ① 清扫掉。所以观感不是「没点中」，而是「点中了立刻消失」——
一条「看起来像命中框问题、实际是选中生命周期问题」的假象。这也解释了为什么按命中口径去查会一无所获：
airborne 的拾取本身是好的，`RuntimeAirbornePickingOrderSmoke` 早就覆盖了跳喷飞行体的投影/命中/深度排序。

## 三、改动

- ①删除 ParadropDrop 分支，②删除该 mission 判断，③**原样保留**。
  即：**下落中可选中（能看血量、状态、编队），但仍不能下令**——命令锁要等落地
  （`SuperWeaponSupportAircraft.inl` 里 `renderLevel<=ground` 那一帧把 `airborne=false`、`mission` 换回 `Guard`）。
  SupportFlightEast/West（支援飞机）继续排除：它们从来不是玩家单位。
- 三处都写了注释指向这条口径，避免下一轮有人「顺手清理」把它改回去。

## 四、判据（可反刷绿）

新增断言写进 `RuntimeParatrooperTargetSmoke.inl`（原生空投夹具，27 场景 = 9 种单位 × 15/30/60Hz）：

1. 下落中 `runtimePlayerLocalSelectable` 为真、`runtimeObjectCanBeBoxSelected` 为真；
2. 走 UI 真实入口 `applyRuntimePlayerSelection`（左键与框选共用）→ 选中列表含该 id；
3. **再跑满一整拍**（`advanceRuntimeSimulation`，内含 `cleanRuntimeSelection`）→ 仍在空中，且**仍在选中列表**；
4. 此时下移动令必须 `acceptedCount==0`（防止把命令锁一起放开）；
5. 每场景都跑，收尾断言 `selectableCases == cases`（27/27）。

**反刷绿实测**：把 ① 的 ParadropDrop 分支改回去重建，冒烟立刻红：
`Paratrooper targeting: E1/15Hz selection erased while still descending`（rc=1）。恢复改动后 rc=0。

## 五、验证

- 冒烟单跑：`CONCORD_COMMAND_SMOKE_PARATROOPER_TARGET_ONLY=1 <bin> --command-smoke-test`
  → `27 native drops … 27 mid-air selectable drops`，rc=0，约 2s。
- 全量回归：`13 PASS / 2 KNOWN-RED / 0 RED-NEW`（两条 known-red 是既有的 slave miner 与 M-25 载具穿步兵，
  与本改动无关）。
- 新增回归第 16 条 `paradropsel`（120s 上限，实测 2s），`--only paradropsel` 已验接线。

## 六、遗留与不做的事

- **命令锁没动**：下落中能选不能令。若后续要「空中就能指定落点」，那是另一条产品行为，需单独登记。
- 配套观察（非缺陷，已答口径）：遭遇战大厅的 `AI` 勾选是**电脑 AI 总开关**，勾掉连 MCV 展开都不做
  （`advanceRuntimeComputerAi` 直接 return，`deployRuntimeComputerAiMcvs` 在其内）；战役 AI 走
  `campaignHouseProduction` 分支，不受它影响。要「建基地但不进攻」得另开细粒度开关，不在本轮范围。
