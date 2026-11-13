# FIX-18 整仓卸载：把「600 拍不放空」拆成八格拒绝表

> **⚠️ 本文 §3 的「第一具出舱者停在船体原点没走开」已被第 18 轮推翻**（见
> `reports/FIX-19-卸载终态是被站着的人占满环.md`）。原因：trace 只按「人+格子+原因」去重，
> 打出来的是**首次命中时刻**；那一刻 egress 才刚起步，`ticks=66/66` 是满值不是冻住。

- 轮次：2026-11-13 第 17 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-123454`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-124323`，零新回归、产品行为零改动）
- 源码提交：`22fea50`（test: 卸载侧逐格给原因）
- 关联条目：C-02c（整仓步兵卸载），仍是唯一 remaining known-red 的唯一阻塞点

## 1. 起点

第 16 轮把登船互锁修掉后（`498ae37`），`command` 的失败点后移到：

```
amphibious transport: full infantry hold did not unload after 600 ticks: moved #7 to 15,15
```

一句话里有三个未知：**哪一格不行、为什么不行、600 拍里到底谁在卡**。
照本项目既有纪律，先拆读数，不动行为。

## 2. 本轮改法（只读，`CONCORD_TRANSPORT_TRACE=1`）

`unloadRuntimeUnitTransportMotion` 的候选格循环原本是两条合并的 `continue`：

```cpp
if (!findRuntimePassableCellNear(...) || std::abs(terrainLevelAtRuntimeCell(...) - host.level) > 1) continue;
if (!runtimeTransportTransferTransitionClear(...)
    || !runtimeTransportTransferBodiesClear(...)) continue;
```

拆成六个独立拒绝点并各给一行 trace（`traceRuntimeTransportUnload`，按
「人 + 格子 + 原因」去重，否则每拍重试会刷屏）：

| stage | 含义 |
|---|---|
| `unload:passable` | 该格不可通行（附带 `occupied=<id>` / `level` / `hullLevel` / `probe=<type>`）|
| `unload:level` | 地形层与船体不一致 |
| `unload:subcell` | 该格地面子格用尽 |
| `unload:clearance` | 出舱子格仍在船体 clearance（步兵 0.75）内 |
| `unload:transition` | 单格转移不合法（邻接/地基/可通行）|
| `unload:bodies` | 扫掠段里有别的身体（带 `other/kind/cell/distance²/minimum/...`）|
| `unload:no-exit` | 八格全被拒（这一拍的总结行）|

`bundary` 那条 `passable` 分支里的 occupancy 查询也放在 `runtimeTransportTraceEnabled()`
门控内，关掉环境变量只剩一次 `static bool` 读。

## 3. 读数（两个阶段，必须分开看）

冒烟这一段有两拍：**先摆 8 台 MTNK 堵住舱门口**（要求卸载被拒），**再把它们挪走**（要求整仓下船）。

阶段一（被堵，属预期）：

```
unload:passable id=13 cell=16,15 occupied=15  probe=E1/alive
unload:passable id=13 cell=15,16 occupied=17  probe=E1/alive
… 八格各被一台 MTNK 占住 …
unload:no-exit   id=13 cell=16,16
```

`occupied` 正好是 8 台 MTNK 的 instanceId（14~21），说明「堵住」是产品的正常判定，
不是缺陷。**这一阶段以前只有一句 `12 仍在船上`，看不出堵在哪。**

阶段二（挪开后，真问题）：

```
unload:bodies id=7 cell=17,17 other=13 kind=infantry cell=16,15
              distance²=0.000000 minimum=0.5 selfPending=- otherPending=- moving=1 alive=1
```

- `other=13` 是**第一具出舱者**，`moving=1`、`distance²=0`（正贴着船体原点）。
- 后续 `id=7` 的扫掠段起点落在它身体里 → 每个人都在等它让开。
- `selfPending/otherPending` 都是 `-`：出舱者不在 `pendingTransportTargets` 里，
  所以第 16 轮那条「同船排队同伴不算路障」的豁免**对它不生效**（当时已用这一点排除「本轮引入」）。

也就是说 C-02c 的真实形态不是「八格都不可用」，而是：

> **第一具出舱者停在船体位置没走开，把后面所有人都堵在舱里。**

这与 C-02a 是同一族（「一个人卡在门口，后面全员等它」），但角色反过来：
那次是**进舱**方向拥挤，这次是**出舱**方向第一个没走开。

## 4. 为什么本轮不改产品

要改必须先回答「id 13 为什么没走开」，而它的可能成因分属两条不同链路：

1. **一格 egress 渲染步没走完**：`advanceRuntimeGroundRenderSegment` 在
   `progress >= 1.0` 时才清 `transportTransferKind`；若中途被
   `runtimeGroundRenderStepWaitsForStoppedBody` 判「等身体停稳」，它会永远留在船体原点。
   可疑对象是**其余 11 具被 `syncRuntimeTransportCargoPositions` 同步到船体格**的货舱体——
   它们 `alive=false`，若没被 `runtimeAllGroundBodyIsSpatialCandidate` 排除，
   就是「船里的自己人把出舱者挡住」。
2. **egress 完成后走不到半径 2 的外侧终点**：`remainingPath` 为空时它停在邻格，
   而邻格正是下一具的扫掠段起点。

两者改法相反（一个动身体过滤，一个动外侧终点搜索），**必须先量 id 13 自己的
行为状态**（`renderMoveActive / renderMoveTicksRemaining / moveTarget / path.size()`）
才能定，不许猜。

## 5. 下一轮起手（C-02c 第二步）

在 `unload:bodies` 命中时，顺带打印**挡住者自己的**状态：

```
other=<id> state=<behavior.state> ticks=<renderMoveTicksRemaining>/<renderMoveTicksTotal>
target=<moveTarget> path=<path.size()> cell=<cell> render=<renderX,renderY>
```

判据：

- 若 `ticks>0` 且位置停在船体原点 → 走成因 1，去查 `runtimeGroundRenderStepWaitsForStoppedBody`
  对「inactive 货舱体」的处理（这是最可疑的一处：`alive=false` 的 11 具身体是否被当成障碍）；
- 若 `ticks==0 && path.empty()` → 走成因 2，去看 `remainingPath` 的半径 2 搜索为何全空
  （`futureFootGoals` 只在 `!runtimeAmphibiousTransport` 时统计，两栖船根本没统计）。

修好后判红口径不变：12 名步兵在有限拍内全部下船，且 `infantrySlots` 要求
（格子 + 子格）互不重合。
