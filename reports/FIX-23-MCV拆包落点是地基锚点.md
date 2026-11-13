# FIX-23 MCV 拆包：验收钉的是建筑左上角，产品给的是地基锚点

- 轮次：2026-11-13 第 22 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-133011`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-133719`，零新回归）
- 源码提交：`7c02812`（test: MCV 拆包的落点改判「在旧地基内」）
- 关联条目：**C-02f 已完成**；新登记 **C-02g**（奴隶矿工出舱段）

## 1. 六个谓词，只有一个不成立

`RuntimeMcvRepackSmoke.inl:145` 把「拆包成功」压成一条断言，六个谓词：

```
findObjectById(yardId) == nullptr      ← 旧建筑已消失
vehicle != nullptr                      ← 恰好选中一件
vehicle->type == faction.vehicle
vehicle->owner == faction.owner
runtimeObjectCanMove(*vehicle)
runtimeCellPointForObject(*vehicle) == {6, 6}
```

补 `CONCORD_MCV_REPACK_TRACE=1` 逐项打印后，第一个阵营（Americans / GACNST / AMCV）：

```
yardId=1 yardStillThere=0 selection=1 ids=2
  live: [#2 AMCV/Americans kind=1 cell=7,7 mission=Guard deployed=0 canMove=1 health=500]
```

**五个谓词全过，只有格子是 (7,7) 而不是 (6,6)。**

## 2. 产品是对的，验收错了

`undeployRuntimeStructure`（`RuntimeSessionWorld.cpp:15363`）写得明确：

```cpp
const RuntimeCellPoint origin = runtimePlacementAnchorCellForFootprint(
    runtimeCellPointForObject(*structure),
    runtimeStructureFootprintForObject(state, *structure));
...
const std::optional<RuntimeCellPoint> spawnCell =
    findRuntimePassableCellNear(state, probe, origin, 6, structure->instanceId);
```

落点 = **地基锚点**（矩形中心），然后在锚点附近找可走格。GACNST 是 3x3、左上角 (6,6)，
中心就是 (7,7)——读数与规则完全对上。

验收把 `{6,6}` 写死，即把「测试放置建筑时用的左上角坐标」当成了「拆包后车辆该出现的位置」。
这是放置规则从「左上角锚定」改成「中心锚定」之后没跟上的旧断言：该段自第 13 轮起从未执行到，
所以一直没被照出来。

顺带排除的另一种可能：**不是**「中心被占所以挤到 (7,7)」——四阵营都稳定落在中心，
而若中心被占，`findRuntimePassableCellNear` 会给出别的格，读数不会四次都一样。

## 3. 改法（`7c02812`，测试侧）

不做「把产品改成落左上角」这种事（那会让放置锚点规则自相矛盾），改断言的语义：

```cpp
// 拆包前存下旧地基格清单
const std::vector<RuntimeCellPoint> yardFoundation =
    runtimeStructureFootprintCellsForObject(probe, *yard);
const RuntimeCellPoint yardSpawnAnchor = runtimePlacementAnchorCellForFootprint(
    runtimeCellPointForObject(*yard), runtimeStructureFootprintForObject(probe, *yard));
...
// 断言落点在这份清单里，而不是再抄一份生成算法
std::find(yardFoundation.begin(), yardFoundation.end(),
    runtimeCellPointForObject(*vehicle)) == yardFoundation.end()
```

为什么不直接断言 `== yardSpawnAnchor`：那等于把产品的落点算法抄进测试，
一旦产品按「锚点被占就挪一格」进化，测试会跟着假红。地基清单是**语义**（在旧地基上），
锚点只是在失败文案里给线索。

读数：四阵营全过，包括被占领那一档（`GACNST` 由 Russians 拆包必须得到 `AMCV/Russians`）：

```
Americans    #2 AMCV/Americans   cell=7,7
Russians     #2 SMCV/Russians    cell=7,7
YuriCountry  #2 PCV/YuriCountry  cell=7,7
Russians     #2 AMCV/Russians    cell=7,7
```

## 4. 新阻塞：奴隶矿工出舱段（C-02g）

```
Command smoke failed: slave emergence (ore): new worker appeared on surrounding ground
```

`RuntimeSlaveMinerSmoke.inl:214`。`inspect()` 对**不在 `lastCells` 里的新工人**要求二者之一：
在建筑内（`runtimeSlaveMinerWorkerAtRefinery`），或处在出舱渲染窗口
（`renderMoveActive && renderX/renderY ∈ [8,9]`）。失败说明这名新工人既不在建筑内、
也不在那个窗口里。

夹具自己的注释给了根因假设（**尚未验证**）：

```cpp
// Loading a worker before its first movement must not invoke generic infantry
// overlap relocation and put it on the surrounding ground.
```

即「存档/读档发生在工人第一次移动之前」，载入时通用步兵重叠重定位把内部工人推到了周边地面。
待验证的读数：载入后逐个打 `cell / renderX,Y / renderMoveActive / hasRenderPosition /
runtimeSlaveMinerWorkerAtRefinery`，分清 ①载入 placements 就没把它们放进建筑
②进了但第一次 `advanceRuntimeSimulation` 被重叠重定位弹出 ③渲染位缺失导致 `emerging` 判据恒假。

## 5. 下一轮起手（C-02g）

1. 先只读：在 `inspect()` 里给「新工人」那一支加按拍 trace（`CONCORD_SLAVE_EMERGENCE_TRACE=1`），
   打印 `id / cell / inside / renderMoveActive / renderX,Y / hasRenderPosition / task.phase`；
2. 三种情形分流见 §4，注意 `mode` 有三档（`ore`/`no ore`/`blocked`），**先只跑 ore** 定位，
   不要把三档混在一轮里改；
3. 若确认是「载入时重叠重定位把内部工人推出去」，要判断这是产品缺陷（读档把人挪了）还是
   夹具缺口（应在载入后先推进零拍），二者改法相反，**别先动产品**。

## 6. 观察：这条链的阻塞点全是「第一次运行」

第 19→22 轮连续四轮的阻塞点都是「自第 13 轮起从未执行到」的段落，且形态高度一致：
**一条把多个谓词压成一句话的断言 + 一个把「测试自己的坐标/次序假设」写死的常量**。
C-02d 是赌船货次序，C-02f 是赌建筑左上角。这类断言在段落首次运行时必然假红，
所以「转绿一段露出下一段」还会继续，直到整条链跑通一次为止。
