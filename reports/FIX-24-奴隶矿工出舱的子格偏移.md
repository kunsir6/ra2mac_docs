# FIX-24 奴隶矿工出舱：子格偏移把渲染位挪出了硬编码窗口

- 轮次：2026-11-13 第 23 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-133904`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-135227`，零新回归）
- 源码提交：`c5d2b6c`（test: 奴隶矿工出舱判据改用子格取整的地基判定）
- 关联条目：**C-02g 部分完成**（`ore` / `no ore` 两档转绿）；新登记 **C-02h**（worker 瞬移 3 格）

## 1. 一次读数就把「谁、什么形态」说清了

`CONCORD_SLAVE_EMERGENCE_TRACE=1` 给每个「`lastCells` 没见过的新 id」打首次出现形态：

```
mode=ore why=first-sighting tick=1054 id=7
  cell=9,9 world=9,9 subCell=2 mission=Move alive=1 renderMove=1 hasRenderPos=1
  render=7.75,8.25 renderFrom=8,8 renderTo=9,9 path=3 target=12,9 phase=1
  status=leaving refinery for ore
```

失败判据是 `emerging`：

```cpp
const bool emerging = worker->renderMoveActive && worker->hasRenderPosition
    && worker->renderX >= 8.0 && worker->renderX <= 9.0
    && worker->renderY >= 8.0 && worker->renderY <= 9.0;
```

`renderX = 7.75` 差了 0.25，直接判「新工人出现在周边地面」。

## 2. 差的这 0.25 是子格偏移，不是位置错

同一行读数里 `renderFrom=8,8 renderTo=9,9`——这是它出厂后的**第一步**，斜着从 (8,8) 走到 (9,9)。
步兵按子格站位：一格四子格，`subCell=2` 的视觉偏移让身体落在 `(8-0.25, 8+0.25) = (7.75, 8.25)`。

也就是说：**committed cell 是 (9,9)（在地基内）、起点是 (8,8)（在地基内），渲染位却因为子格偏移
落在地基左边界外 0.25 格。** 产品没错，判据的窗口错了。

顺带解释了另一件事：`inside` 在这一拍也是 0——不是位置不对，而是
`runtimeSlaveMinerWorkerAtRefinery` 见到 `renderMoveActive` 就直接返回 false（正在走的人不算「到达」）。
所以这个分支**只能**靠 `emerging` 兜住，而 `emerging` 用的是夹具坐标窗口。

## 3. 硬编码窗口的来源

`[8,9]` 就是夹具把炼油厂放在 (8,8)、YAREFN 3x3 之后手算出来的。和 C-02f 的 `{6,6}` 是同一类：
**把夹具自己的摆位坐标当成了产品的落点规则。**

## 4. 改法（`c5d2b6c`，测试侧）

把渲染位取整成格子，再判它是否落在地基内，取整规则与产品 `runtimeSlaveMinerWorkerAtRefinery`
里的 `bodyCell` 完全一致（`std::lround`）：

```cpp
const RuntimeCellPoint bodyCell{
    static_cast<int>(std::lround(worker->renderX)),
    static_cast<int>(std::lround(worker->renderY))};
const bool emerging = worker->renderMoveActive && worker->hasRenderPosition
    && runtimeCellDistanceToObjectFootprint(probe, bodyCell, *host) == 0.0;
```

`(7.75, 8.25)` → `(8,8)` → 距离 0，成立。语义仍是「这人还在老地基上、正在往外走」，
只是改用几何而不是盒子。

读数：

```
Slave emergence: ore      interior spawn/save/load=ok continuous walk=ok workers=5 replacement=ok
Slave emergence: no ore   interior spawn/save/load=ok continuous walk=ok workers=5
```

`ore` 档连带把「替补工人」（打死一个 → 补一个）也跑通了。

## 5. 新阻塞：`blocked` 档的「瞬移 3 格」（C-02h）

```
Command smoke failed: slave emergence (blocked): worker teleported instead of walking
id=14 prev=9,8 cell=6,6 inside=0 renderMove=0 render=6,6
  mission=Guard status="no ore" phase=SeekingOre
```

时间线：`phase=walk-out` 起点只有 4 个工人，第 150 拍第 5 个（`id=18`）在 **(9,8)** 出生；
约 194 拍后 `id=14` 从 **(9,8)** 直接出现在 **(6,6)**，`renderMove=0`、渲染位就是 (6,6)——
**不是走过去的，是被放过去的**（3 格左、2 格上，一步到位且没有插值）。

三个已知事实：

1. 出生格是 `findRuntimeSlaveMinerWorkerSpawnCell` 挑的「半径 0 可走」的地基格，
   而它挑中了 `id=14` 所在的 (9,8)——因为一格四子格，两个步兵可以合法同格；
2. 之后发生的是 `mission=Guard` + `status="no ore"`，说明它已经从「出舱」任务被打回寻找矿；
3. 位移没有渲染插值，符合「重定位」而不是「移动」的特征。

根因假设（**未验证**）：通用步兵重叠重定位（夹具注释点名过的那条路径）在两名工人同格后
把人挪到最近的可走格；封死的墙圈内没有空位，于是搜索半径一路放大到 (6,6)。

## 6. 下一轮起手（C-02h）

1. 在 `setRuntimeObjectCell` / 重定位入口加只读位（`CONCORD_SLAVE_EMERGENCE_TRACE` 已有开关，
   加一条 `why=relocated from=.. to=.. radius=..` 即可），确认是不是重叠重定位；
2. 若确认，判断该修哪一层：
   - **产品**：重定位不该把「正在出舱的工人」挪出建筑（同类场景下这是可见 bug）；
   - **夹具**：出生点应避开已有工人的子格（`findRuntimePassableCellNear` 半径 0 只看格子不看子格，
     是出生点重复的直接原因）；
3. 注意本段三档（`ore` / `no ore` / `blocked`）**不要混改**：`ore` 与 `no ore` 已绿，
   改动只许影响 `blocked` 的墙圈场景。

## 7. 观察：连续三轮同一种病

C-02d 赌船货次序、C-02f 赌建筑左上角、C-02g 赌渲染窗口——**都是把「夹具自己造出来的坐标/次序」
写进断言的期望值**。第 13 轮以来这条链上真正的产品缺陷其实只有两处（C-02b 的登船互锁、
C-02e 的建筑进门格），其余全是这类同源问题。夹具一侧的通用改法是：
**期望值取几何（地基、格子、集合成员），不取常量。**
