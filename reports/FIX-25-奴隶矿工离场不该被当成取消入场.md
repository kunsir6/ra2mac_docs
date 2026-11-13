# FIX-25 奴隶矿工离场不该被当成「取消入场」（C-02h）

- 轮次：2026-11-13 第 24 轮
- 目标：C-02h（中等，先量后改）
- 结果：**已完成**（产品缺陷，一处判定 + 七条只读计量）
- 提交：`7b9f576`（fix）
- 回归：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`20261113-143359`）

## 1. 现象

`command` 冒烟的 `slave emergence (blocked)` 档（炼油厂被一圈 `GAWALL` 围死，120 拍后炸开一格）：

```
[slave-emerge] mode=blocked why=teleported tick=344 id=14 new=0 cell=6,6
    inside=0 renderMove=0 hasRenderPos=1 renderX=6 renderY=6
    phase=0 status=no ore emerged=4/5 tasks=5
```

工人 `id=14` 从 `(9,8)` 一步跨到 `(6,6)`（3 格外），`renderMove=0` 且渲染位与格子重合
——**没有插值**。断言 `worker teleported instead of walking` 判红。

## 2. 两次否定 + 两次收窄

| 步 | 动作 | 读数 | 结论 |
|---|---|---|---|
| ① | 怀疑 `reconcileRuntimeSubcells` 的 `NeedsMoveOut` 分支（那里也是直接改格 + `clearRuntimeRenderPosition` + 半径 6 搜索） | 加 `why=reconcile-relocate` 后**一条都没打** | **否定** |
| ② | 改在 `setRuntimeObjectCell`（所有整体改格都必经）加「跨 >1 格」读数 | `why=set-cell-jump tick=344 id=14 from=9,8 to=6,6 resetRender=0` | 确认是整体赋值，不是逐格走 |
| ③ | 在 `recoverRuntimeCancelledStructureEntry` 入口加读数 | `prevKind=1(Move) prevTarget=9,8 allowedOccupied=1` | 定位到函数 |
| ④ | 在无矿分支的三处加读数 | tick=1：`exit=6,6 issued=1 path=0 allowedOccupied=1` | 看到出发 Move 的目标格不可达 |

## 3. 根因

`runtimeCancelledStructureEntryNeedsRecovery` 只对 `Returning` / `Stored` 的奴隶矿工豁免：

```cpp
const auto slave = state.slaveMinerTasks.find(object.instanceId);
if (slave != end && slave->second.refineryId == hostId
    && (phase == Returning || phase == Stored)) return false;
```

而 `blocked` 档的时序是：

1. 炼油厂被墙圈围死，`findNearestRuntimeStructureResourceCell` 找不到**够得着**的矿
   → 走「无矿」分支，`phase=SeekingOre`、`status="no ore"`；
2. 该分支给工人签发一条**离场** Move（`issueRuntimeHarvesterMoveToCell(..., "Move", ...,
   refinery->instanceId, exactTarget=true)`），目标格是
   `findRuntimeSlaveMinerWorkerExitCell` 选出来的 `(6,6)` —— **墙圈外**；
3. 墙圈关着，`(6,6)` 不可达 → `path=0`，行为立刻「完成」；
4. 完成时进入「取消入场恢复」：`allowedOccupied=1`（炼油厂）、身体在地基里、
   奴隶任务 `phase=SeekingOre` **不在豁免名单** → `findRuntimePassableCellNear(..., 6)`
   把身体直接搬到最近空地 `(6,6)`，并 `clearRuntimeRenderPosition` +
   `assignRuntimeInfantrySubcellAtCurrentLocation`。

于是「工人走过去」变成了「工人被瞬移过去」。恢复逻辑本身没错——它是为**失败的入场**
（工程兵没进去、载具被拒）准备的；错在把「离场」也当成了「入场」。

## 4. 改法

```cpp
const auto slave = state.slaveMinerTasks.find(object.instanceId);
if (slave != state.slaveMinerTasks.end() && slave->second.refineryId == hostId) {
    // 奴隶矿工的身体由任务步自己负责：运送与离场都合法地站在自己炼油厂的地基里。
    return false;
}
```

用「任务归属」而不是「目标格在地基外」来判离场。后者试过、**不成立**：恢复执行时
`prevTarget` 已被寻路兜底改回自己脚下 `(9,8)`（在地基内），按距离判会漏掉。

没有放宽成「所有步兵不恢复」，也没有去改寻路兜底策略（那是第 21 轮 C-02e 的领域，
本轮只需保证「不该恢复的时候不恢复」）。

## 5. 读数与验证

```
Slave emergence: blocked interior spawn/save/load=ok continuous walk=ok workers=5 closed/reopened exit=ok
Slave delivery: adjacent ore return=ok partial load=ok blocked entry=ok no intake=ok vehicle intake=ok
```

`ore` / `no ore` 两档仍绿（三档未混改）。全量回归 `10/1/0`（`20261113-143359`）。

## 6. 留下的只读计量

全部由 `CONCORD_SLAVE_EMERGENCE_TRACE` 门控，默认静默、零输出：

| 位置 | 标签 | 用途 |
|---|---|---|
| `reconcileRuntimeSubcells` 重定位分支 | `why=reconcile-relocate` | 排除/确认子格重定位 |
| `setRuntimeObjectCell` | `why=set-cell-jump` | 抓任何「跨 >1 格」的整体赋值 |
| `recoverRuntimeCancelledStructureEntry` | `why=entry-recovery` | 确认取消入场恢复命中 |
| `applyRuntimeMovePathResult` | `why=goal-adjusted` | 看目标被兜底换成哪一格 |
| 无矿分支入口 | `why=no-ore-branch` | 看在不在炼油厂、有没有行为 |
| 出口格签发 | `why=exit-issue` | 看退出格与是否签发成功 |
| 离场 Move 签发 | `why=departure-issue` | 看出发目标与 path |

这组读数的价值在**否定能力**：本轮第一、二步都是先排除一个"看起来最像"的嫌疑，
再让读数把自己否掉。

## 7. 下一轮起手（C-02i）

阻塞点已后移到 `runRuntimeSlaveMinerSmokeProbe` 的后续段（自第 13 轮起从未被执行到）：

```
Command smoke failed: slave miner: workers did not dig, carry full loads and deposit credits:
digging=1 carrying=1 cargo=4 credits=0
```

- `digging=1 / carrying=1 / cargo=4 / credits=0` 是一组计数断言，说明"挖"和"装"各发生过一次，
  但货没卸下去。先看该段夹具（`RuntimeSlaveMinerSmoke.inl` 后半段）的计数口径与等待拍数，
  再决定是夹具等待不足还是产品真没交付。
- **纪律照旧**：先加读数，不凭直觉改；多谓词压成一句的断言必须拆开逐项打印。
