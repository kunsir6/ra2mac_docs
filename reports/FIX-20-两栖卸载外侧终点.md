# FIX-20 两栖卸载给出舱步兵规划外侧终点：整仓下船转绿

- 轮次：2026-11-13 第 19 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-125134`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-130051`，零新回归）
- 源码提交：`4f13ccc`（fix: 两栖卸载给步兵规划半径 2 外侧终点）、
  `7361f55`（test: 混编段失败文案拆成六个条件字段）
- 关联条目：**C-02c 已完成**；新登记 **C-02d**（混编段载入 IFV 未出舱）

## 1. 改法（取 A）

FIX-19 定性为「出舱者就地停在环上，8 个邻格被先出来的人占满」。对应改法只有一条：
**让出舱者下船后走开**。`unloadRuntimeUnitTransportMotion` 里原本是

```cpp
std::vector<RuntimeCellPoint> remainingPath;
if (!runtimeAmphibiousTransport(state, host)) { … 半径 2 搜外侧终点 … }
```

两栖船一律没有外侧终点。改成

```cpp
if (!runtimeAmphibiousTransport(state, host) || runtimeInfantryUsesGroundSubcells(probe)) { … }
```

三条边界：

| 边界 | 为什么 |
|---|---|
| 只对**步兵**开启 | 坦克段断言要求 `cell` 距船体 ≤1.5、`exits` 互不重合；让坦克走出去会直接破断言，而坦克也确实该贴着船停下卸人 |
| 载具保持原状 | 同上，零风险 |
| 全水自动退回 | `findRuntimePath` 搜不到路就返回空 → `remainingPath` 为空 → 与改动前完全一致，不会把兵推进水里 |

附带把 `futureFootGoals`（半径 2 外格的「已认领」计数）对两栖船也统计，
否则多个出舱者会被派到同一个外格上。

## 2. 读数

`command` 的 `full infantry hold did not unload after 600 ticks` **消失**，12 名步兵全部下船。
回归 `10/1/0` → `10/1/0`：坦克段（`aboard=4`、`exits` 互不重合、深水拒卸、跨水、save/load、
老兵度）与其余 9 条 smoke 全绿。

出舱者现在带着 `path=1~2`、`target=16,14 / 17,14` 往外走（trace 可见），环会被腾空。

## 3. 新阻塞：混编段（C-02d）

步兵段通过后，`command` 停在下一段（此前从未被执行到）：

```
loaded IFV lost its soldier/gunner when disembarking:
  ifv=null ifvCargo=- gunner=- rider=3 riderAlive=0 riderCell=23023 boatCargo=3
```

这条断言（`RuntimeAmphibiousTransportSmoke.inl:221-225`）在**一次** `executeRuntimeSecondaryAction`
之后要求 IFV 已经出舱、且它的乘员还在 IFV 里。读数说明 IFV 根本没出舱。

**已排除本轮引入**：该夹具（船停在 23,23）在 23,23 周边**零 `unload:` trace**，
说明 `unloadRuntimeUnitTransportMotion` 在顶部就返回了、根本没进候选格循环——
而本轮改的正是候选格循环里的外侧终点。最可能是顶部守卫
（`!host.alive || host.health <= 0 || host.airborne || host.renderMoveActive`）
在「`move()` 后船还没停稳」时把整次卸载吞掉，与本轮改动无关。

## 4. 下一轮起手（C-02d）

一次读数即可定性，先不要改产品：

1. 在 `unloadRuntimeUnitTransportMotion` 顶部守卫被拒时给一行 trace
   （`unload:host-busy why=alive/health/airborne/renderMoveActive`）；
2. 在冒烟里 `executeRuntimeSecondaryAction` **之前**打出 `transportPassengerIds.size()`，
   把「3 件是初始值」与「4 件卸了 1 件」分开——本轮读数 `boatCargo=3` 这两种解释都成立；
3. 若确认是「船没停稳就点卸载」，那这条断言和之前两轮踩的是同一个坑
   （「一次点击 = 一步到位」），应按拍等待而不是改产品。

## 5. 纪律复盘

- 本轮**没有**重犯 C-02a 的错（先试计划里的方案再被读数否决），FIX-19 的定性直接给出了
  唯一可行改法，一次构建就转绿。
- 但连续两轮都在「阻塞点后移」上收尾：`command` 每转绿一段就暴露下一段，
  而下一段往往还带着「一次点击 = 一步到位」的旧断言。下一轮起手的第 2 条就是为此准备的。
