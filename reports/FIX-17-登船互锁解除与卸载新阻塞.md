# FIX-17 登船互锁解除：同船步兵同伴不再算路障

- 轮次：2026-11-13 第 16 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-121025`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-123454`，零新回归）
- 源码提交：`498ae37`（fix: 同船步兵同伴不再当路障）、`c7a1f2f`（test: 整仓步兵卸载按拍等待）
- 关联条目：C-02a（已完成）/ C-02c（新登记，整仓卸载）

## 1. 起点：上一轮只把根因压到「一道门」

第 15 轮（`reports/FIX-16-登船互锁的四道门计量.md`）用 `CONCORD_TRANSPORT_TRACE=1` 把
「12 人只上 10 人」拆到 `transfer:bodies` 门，并给出两条候选改法：

- **A（串行化）**：同 host 每拍只放一人，按 instanceId 定序；
- **B（不算障碍）**：同船等待乘客不算路障，但要先证明坦克段不退化。

本轮按计划先取 A。

## 2. 第一步：先把「被谁挡住」量出来（否决 A 的关键）

`runtimeTransportTransferBodiesClear` 增加可选出参 `std::string* blocker`，
在第一个挡住扫掠段的身体处写出 `id/kind/格子/线段距离`，并在
`beginRuntimeTransportGroundTransfer` 的 `transfer:bodies` trace 里带出。

第一次读数（只带 id/距离）：

```
transfer:bodies id=9  at=15,15 hull=16,16 other=13 kind=infantry cell=15,15 distance=0.0268 min=0.500
transfer:bodies id=12 at=15,15 hull=16,16 other=9  kind=infantry cell=15,15 distance=0.0021 min=0.500
transfer:bodies id=11 at=15,15 hull=16,16 other=8  kind=infantry cell=15,15 distance=0.1025 min=0.500
transfer:bodies id=10 at=15,15 hull=16,16 other=3  kind=infantry cell=15,16 distance=0.0999 min=0.500
```

第二档加了三个状态位（`selfPending / otherPending / moving`）才看清真形态：

```
id=9 blocked by other=13 infantry selfPending=1 otherPending=1 host=1 moving=1 alive=1
```

**四个人全是 `otherPending == host` 的同船排队者，而且 `moving=1`** —— 不是「有人站着挡路」，
是四个人同时在往同一块板上挤，每个人都在等别人先动。

由此 **A 方案被否决**：串行化只保证同拍只有一个人发起转移，但那一个人的扫掠段起点
（`a`）就落在原地同伴的身体里（距离 0.002~0.10，阈值 0.5），照样过不了 bodies 门。
串行化把「四个人互锁」变成「一个人被三个人锁」，一步也没前进。

## 3. 真修法：同船步兵乘客不算路障

`runtimeTransportTransferBodiesClear` 的 `inspect` 里，在算最小间距之前加一条豁免：

```cpp
const bool sameHostQueueMate = foot && otherFoot
    && selfIntent != end && selfIntent->second == hostId      // 我在这艘船的队列里
    && otherIntent != end && otherIntent->second == hostId;   // 他也在这艘船的队列里
if (sameHostQueueMate) return;   // 同伴不是路障
```

四条边界刻意收得很窄，为的是不碰坦克段：

| 条件 | 为什么必须有 |
|---|---|
| `foot && otherFoot` | 只放行步兵对步兵。步兵一格四子格，短暂重叠是零售语义；载具对载具仍 1.0 间距，`aboard=4` / 不叠车靠它 |
| `selfIntent->second == hostId` | 只放行「正在登这艘船的人」，不放过路人 |
| `otherIntent->second == hostId` | 只放行「同船排队者」，敌方单位、岸上闲逛的己方单位仍然是路障 |
| 不改 `minimum`、不改距离函数 | 除豁免外所有几何完全不变，反证容易 |

读数变化：`aboard=10/12 pending=2` → **`board()` 整段返回 true（12/12 全部进舱）**，
坦克段（`aboard=4`、`exits` 互不重合、深水拒卸、跨水、save/load、老兵度保持）全绿。

## 4. 新阻塞：整仓步兵卸载（C-02c）

登船转绿后，`command` 停在下一段：

```
Command smoke failed: amphibious transport: full infantry hold did not unload after 600 ticks: moved #7 to 15,15
```

这一段是「舱门口摆 8 台 MTNK 挡住 → 卸载被拒（12 人仍在上） → 把 MTNK 挪走 → 整仓下船」。
它此前被登船红挡住，从来没有被执行到。

两件事分清楚：

1. **旧断言在结构上不可能成立**（`c7a1f2f` test）：第 176 行原本是「按一次动作后整仓必须空」，
   而单位船卸载是逐人推进（`unloadRuntimeUnitTransportMotion` 一趟只放一个后 `break`）。
   同一文件第 121~137 行的坦克段早已改成「按拍推进到放空」，步兵段漏改。已改成同样的按拍循环。
2. **改成按拍后仍然红，且是原生问题**：600 拍（20 秒）内一个都没下来。
   **已排除本轮引入**——登船入舱时 `completeRuntimeTransportEntry` 会
   `pendingTransportTargets.erase(pendingIt)`，所以被卸下的兵 `selfIntent` 为空，
   第 3 节那条豁免对它不成立，卸载路径的判定与本轮改动逐字等价。
   剩下的候选是「舱门口子格被河岸/水面判据挡住」或「卸载候选格几何不可达」，两者都要先加只读位。

## 5. 纪律复盘

- **计划里的 A 方案是错的，且是被读数否决的**。第 15 轮报告写 A「代价小」，是在没有
  「被谁挡住」这一档读数时下的判断；补上 `otherPending/moving` 后，A 的前提（「只有一个动，别人让开」）
  当场不成立。**复杂项的方案在动手前是假设，不是结论。**
- 第二档计量值钱：第一档只给出 id 和距离，看起来像「有人站着挡路」，很容易顺手写成
  「等待者应该让开」；加上 `moving=1` 才看出是「四个人一起挤」。
- `known-red` 第 4 列必须跟着阻塞点改（`twelve infantry did not board` →
  `full infantry hold did not unload`），否则回归会报 `RED-NEW(cause-changed)`。
  本轮确实报了一次，改完后回到 `10/1/0`。
- 未提交他人改动：`reports/WIN-01-Windows侧改动对账清单.md` 是并发进程 10:03 生成的在建文档，
  本轮按路径显式提交自己的文件，未触碰它。

## 6. 下一轮起手（C-02c）

给 `unloadRuntimeUnitTransportMotion` 的候选格循环加卸载侧只读位，按顺序记：

1. 9 个候选格里，每个被拒的原因（passability / terrain level / subcell 用完 / `hullClearance` /
   `transition` / `bodies`）；
2. `simulationStatus` 里 `moved #7 to 15,15` 的 `#7` 是哪个 id、它的 `moveTarget` 与当前位置；
3. 若全部 9 格都被拒，先看 `water(s)` 把 16,16 周边标成了什么（水面还是岸），
   这决定「实现错」还是「夹具把船停在纯水面里」。

判红口径：12 名步兵在有限拍内全部下船，且 exits 用的地面子格互不重合（`infantrySlots`）。
