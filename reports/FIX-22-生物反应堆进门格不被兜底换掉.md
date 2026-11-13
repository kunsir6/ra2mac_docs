# FIX-22 生物反应堆进门：两人互换目标格之后互相堵死

- 轮次：2026-11-13 第 21 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-131040`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-132804`，零新回归）
- 源码提交：`d6654eb`（fix: 建筑吸收器的进门格不再被寻路器的兜底目标换掉）、
  `8dfc9f4`（test: 生物反应堆进门段加按拍采样读数）
- 关联条目：**C-02e 已完成**；新登记 **C-02f**（MCV repack 段）

## 1. 一次读数就把「三人进得去两人进不去」拆开了

按上一轮留下的分流表，先打 800 拍后的 `power / pending` 与五人状态：

```
[bioreactor] ai-entry ticks=800 pending=2 power=450 aboard=3 completion=0
#2=gone  #3=gone  #6=gone
#4 cell=11,11 target=12,11 footprintDistance=1.414 queued=1 bstate=1 blocked=1 path=0
#5 cell=12,11 target=11,11 footprintDistance=1.000 queued=1 bstate=1 blocked=1 path=0
```

`power=450` = 已进 3 人（150 + 3×100），`pending=2` 是剩下的两人。
`bstate=1` 是 `Queued`、`bkind=1` 是 `Move`——两人**都在移动指令里，但路径是空的**。

关键一眼：#4 站在 (11,11) 而目标是 (12,11)；#5 站在 (12,11) 而目标是 (11,11)。
**两人互指对方的格子**，谁的目标格都被对方身体占着。

## 2. 按拍采样把「谁改的」也定位了

加采样（`before-unload / after-unload / after-issue` + 第 1/2/5/20/100/400 拍），每拍打印地基格清单：

```
after-issue  pending=5 footprint=2x2(12,12)(13,12)(12,13)(13,13)
  #2..#5 target=12,12 entryCell=12,12 path=1   ← 排队时五人都对，路径也给了
entry-tick-1  pending=4 power=250      ← 第一个（本来就在 12,12 的 #6）瞬间进
  #3/#4/#5 target=12,12 entryCell=12,12 path=0 pathReq=1
entry-tick-20 pending=4 power=250
  #4 target=12,11   ← 就在这 20 拍里被改的
  #5 target=11,11   ← 而且是「对方的格子」
entry-end    pending=2 power=450      ← 之后 780 拍一动不动
```

排队时目标全对（都是地基格 `12,12`），所以问题不在 `findRuntimeEngineerEntryCell`；
是**路径请求回来的那一刻**把目标换掉了。

## 3. 根因：`goalAdjusted` 的豁免名单不认建筑

`applyRuntimeMovePathResult`（`RuntimeSessionNavigation.cpp:6760`）有一段：

```cpp
if (queuedPath.goalAdjusted && queuedPath.resolvedGoal != behavior.moveTarget
    && (工厂出货 || 克隆门 || omni crush || occupy || 载具 boarding || 研磨)) {
    // 守住真正的入口目标，只标 Blocked 等前面的人过完
}
...
if (queuedPath.reachable && queuedPath.goalAdjusted && !queuedPath.sharedApproachHit)
    behavior.moveTarget = queuedPath.resolvedGoal;   // ← 不豁免就换成兜底目标
```

地基格在寻路器眼里是「不可走的被占格」，于是 `goalAdjusted` 必然为真，兜底目标就是门外邻格。
豁免名单里唯一沾边的是 `runtimeUnitTransportApproachAllowsBodyDetour`，但它第 11444 行写着

```cpp
if (!host || host->kind != WorldObjectKind::Unit || ...) return false;
```

**只认载具兜客，不认建筑吸收器。** 生物反应堆与战斗碉堡都是 `Structure`，
于是它们享受不到「守住入口、等前面的人过完」这条语义。

两人各自被换成门外邻格，恰好换成了对方所在的那格：

- #4 → (12,11)（#5 站着）→ 目标格被身体占 → 寻路失败；
- #5 → (11,11)（#4 站着）→ 同上。

而**重新算进门格的逻辑（`RuntimeSessionTick.cpp:505-548`）只活在「路径走完」分支里**，
两人连一步都走不出去，永远轮不到重算——死锁不可自愈，`blockedTicks` 停在 1。

## 4. 改法（`d6654eb`，产品侧，一个谓词）

新增 `runtimeBuildingAbsorberEntryKeepsGoal`，条件与载具那条同构，只把 host 换成建筑：

- 该人有 `pendingTransportTargets`，且 host id 与 `pendingAllowedOccupiedObjectId` 一致；
- `kind == Move`、非自动获取、无共享目标、不在转移中（`transportTransferKind == None`）；
- host 是 `Structure`、活着、不在移动，且是 `infantryAbsorb` 建筑或坦克碉堡；
- **`moveTarget` 落在地基内**（`runtimeCellDistanceToObjectFootprint <= 0`）。

满足时在 §3 那段返回 true——清空路径、标 `Blocked`、按 `runtimeRepathCooldownTicks` 重试，
目标格原样保留。载具那条规则一个字没动（仍要求 `moveTarget` 在 hull 一格内 + 过 boarding 授权）。

读数：

```
entry-end pending=0 power=650 aboard=5   ← 5 人全部真实进入
```

`power=650` 与 `aboard=5` 同时成立，并且 `runtimeTeamScriptStepCompletion == Complete`，
生物反应堆段转绿。

## 5. 顺带确认的一件事：五人抢同一格不是缺陷

`findRuntimeEngineerEntryCell` 对每个乘客各自挑「最近可达的地基格」，五个人都挑到 `12,12`。
这是既有语义（坦克碉堡段也是单人挑同一格），进入是按拍的、一人进去下一个才可能占到格子，
不需要按人分配不同格。**真正坏的是目标被换掉，不是目标重复。**

## 6. 新阻塞：MCV repack 段（C-02f）

`RuntimeShell.cpp:63082` → `RuntimeMcvRepackSmoke.inl:145`：

```
Command smoke failed: MCV repack: click did not create a selected movable vehicle on the old foundation
```

第一个阵营（Americans / GACNST / AMCV）就失败：`dispatchRuntimeSecondaryActionFromUi` 之后
`finishRepacking` 跑完，`findObjectById(yardId)` 仍在 或 选中的车辆类型/所有者/可移动性/格子
任一不符。与 `pendingTransportTargets` 无关，属**被暴露出来的旧问题**（该段自第 13 轮起从未执行到）。

## 7. 下一轮起手（C-02f）

一次读数即可分流，不必先改产品：

1. `finishRepacking` 之后打 `yardId 是否还在 / selected.size() / 选中者 kind+type+owner /
   runtimeObjectCanMove / runtimeCellPointForObject / probe.pendingOccupyTargets.size()`；
2. 三种情形：①`yard` 还在（拆包根本没发生，查 `finishRepacking` 的计时前提与
   `runtimeMissionIsRepacking`）②选中的是 MCV 但 `canMove=false`（查拆包后 `mission/deployed`
   与体素/移动档位）③格子在但类型/所有者不对（查 `repack` 的 owner 继承）。
3. 若确认是「UI 点击路径没接上」，注意本项目**不调 `[NSApp sendEvent:]`**，
   `dispatchRuntimeSecondaryActionFromUi` 是合成的点击，必须走真实消息队列才算通过。
