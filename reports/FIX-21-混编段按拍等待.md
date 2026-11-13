# FIX-21 混编段整车下船：旧断言在赌船货排队次序

- 轮次：2026-11-13 第 20 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-130051`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-130833`，零新回归）
- 源码提交：`107b06b`（test: 混编段按拍推进）、`2c3616c`（test: 卸载顶部守卫补拒绝原因位）
- 关联条目：**C-02d 已完成**；新登记 **C-02e**（生物反应堆段）

## 1. 上一轮的两种解释，读数把它们分开了

FIX-20 §3 留了两个候选：①船没停稳，整次卸载被顶部守卫吞掉；②`boatCargo=3` 本来就是初始值。

补两处只读位（不上产品逻辑）：

1. `unloadRuntimeUnitTransportMotion` 顶部守卫被拒时打 `unload:host-busy`
   （`alive/health/airborne/renderMoveActive/mission/cargo`）；
2. 冒烟里 `executeRuntimeSecondaryAction` **之前**记 `cargoBeforeAction` 与 `boatMovingBefore`。

读数：

```
ifv=null riderAlive=0 riderCell=23023 boatCargo=3
cargoBeforeAction=4 boatMovingBefore=0 nestedUnloadTicks=0
```

两个候选**都不成立**：

- `cargoBeforeAction=4` → 3 件不是初始值，确实卸掉了 1 件；
- `boatMovingBefore=0` 且无 `unload:host-busy` → 卸载跑完了，顶部守卫没拦。

真形态是第三种：**一次动作只放一件，而被放出去的不是 IFV**。

## 2. 为什么不是 IFV

断言（`RuntimeAmphibiousTransportSmoke.inl:216-225`）在 **一次** `executeRuntimeSecondaryAction`
之后就要求 IFV 已在场上。但：

- `unloadRuntimeUnitTransportMotion` 的循环是「找到第一个能出去的货就 `break`」，
  一趟只放一件（这条在 FIX-15 的坦克段注释里已写明）；
- 船货顺序 = `transportPassengerIds` 的顺序 = **boarding 的到达顺序**。
  而 boarding 是各车自己走到船边完成的（`board()` 驱动 tick），
  所以 IFV 不保证排第一。

于是「按一下就断言 IFV 已出舱」实际是在赌排队次序——这次赌输了。

## 3. 改法（`107b06b`，测试侧）

照坦克段与步兵段已有的写法，改成按拍推进到 IFV 出舱为止：

```cpp
if (!executeRuntimeSecondaryAction(n, boatId)) return fail("nested cargo transit failed");
int nestedUnloadTicks = 0;
for (; nestedUnloadTicks < 30 * 20; ++nestedUnloadTicks) {
    if (findObjectById(n, ifvId) != nullptr) break;                 // IFV 已出舱
    const auto* waiting = findObjectById(n, boatId);
    if (waiting == nullptr || waiting->transportPassengerIds.empty()) break;
    step(n);
}
```

**要防的缺陷一条没放**：IFV 出舱后仍断言 `transportPassengerIds == {riderId}`、
乘员 `alive=false` 且 `cell` 与 IFV 一致、`activeGunnerMode >= 0`。

读数：混编段转绿，`command` 走到下一段。

## 4. 新阻塞：生物反应堆段（C-02e）

```
Command smoke failed: amphiphious transport: ...  →
Command smoke failed: bioreactor: AI did not complete five real arrivals
```

`RuntimeBioReactorSmoke.inl:277-291`：AI action 62 让 5 名步兵「真实走到」反应堆并进入，
800 拍后要求 `power == 5` 且 `runtimeTeamScriptStepCompletion == Complete`。

**已排除本轮两条改动**：

- 该路径是建筑吸收，判定用 `runtimeCellDistanceToObjectFootprint(...) == 0.0`
  （`completeRuntimeTransportEntry` 的 `bioReactor` 分支），**不走**
  `runtimeTransportTransferBodiesClear`——本轮与前三轮的改动都在这个函数里；
- 全程 `CONCORD_TRANSPORT_TRACE=1` **零** transport trace。

该段自第 13 轮（`command` 卡在登船 10/12）起从未被执行到，属原生未暴露段。

## 5. 下一轮起手（C-02e）

一次读数就能定性，不要先动产品：

1. 800 拍后打 `power`（即已进入几人）、`pendingTransportTargets.size()`、
   五人的 `cell / mission / behavior.state / blockedTicks`；
2. 分三种情形：
   - `pending` 清空但 `power=4` → 有人「进了又没进」，去查 `completeRuntimeTransportEntry` 的
     反应堆分支；
   - `pending` 非空且有人 `blockedTicks` 持续增长 → 是被地基/身体挡住，量挡住者；
   - 五人从没开始移动 → `issueRuntimeTeamScriptStep` 只把 intent 排上了、没派路，查 AI 侧派路。

## 6. 观察：`command` 是一条「从未执行过的段落链」

近四轮每次转绿一段，就露出下一段，而下一段多半仍带着「一次点击 = 一步到位」的旧断言：

| 轮次 | 转绿段 | 新阻塞 |
|---|---|---|
| 19 | 步兵整仓卸载 | 混编段 IFV |
| 20 | 混编段 IFV | 生物反应堆段 |

这不是巧合：`command` 从第 13 轮起就卡在链条中段，后面所有段落都成了「第一次运行」。
建议下一轮起**先把这条 smoke 的段落清单列出来**（它由多个子 smoke 串起来），
再决定是逐段修断言，还是先把「一次点击 = 一步到位」的写法整批改成按拍等待（后者可能一次清掉多段）。
