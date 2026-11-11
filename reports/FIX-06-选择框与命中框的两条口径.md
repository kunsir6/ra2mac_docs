# FIX-06 选择框与命中框的两条口径（第 5 轮）

> 2026-11-12 · 自动化第 5 轮
> 主题：`build` 与 `interaction` 两条已知红的阻塞点，本轮都不按「改一个数就对」处理，
> 先把两处的谓词/四边差值打成只读计量，拿到数字再定性。

本轮源码改动全部落在**诊断与断言**侧，产品行为零改动。回归
`PASS=6 KNOWN-RED=5 RED-NEW=0`（与开工基线一致，零新回归）。

---

## 一、M-14 `build` 移动帧选择框不覆盖可见身体 —— 已完成（断言公式错）

### 现象

`--build-smoke-test` 报：

```
mobile selection frames were not covering visible bodies across land, naval,
submerged, air, and infantry objects.
MTNK=55x40/56x36 aligned=yes DEST=87x66/86x66 aligned=yes DLPH=43x25/43x25 aligned=no
SQD=92x51/100x41 aligned=no ZEP=119x80/119x80 aligned=yes ENGINEER=23x34/29x32 aligned=yes
```

DLPH（海豚）与 SQD（乌贼）在**静止帧**尺寸完全相同（43x25/43x25）却判 `aligned=no`，
这条原来被写成「移动帧 sprite 变矮变宽」，实际上是误读——SQD 移动帧确实变了（92x51→100x41），
但静止帧一样红。

### 计量（只读）

`validateUnitSelectionBounds` 里有 6 个谓词，原来只有一个 `aligned=no` 出口，把多谓词耦合压成一句。
先把它拆成 `sprite / cover / rect / cx / cy / inb` 六项逐项打印：

```
probe DLPH sprite=37x19 sel=43x25 expected=43x25 d(0,0,0,0) dy=5/15 hit=1 pass[sprite=1 cover=1 rect=1 cx=1 cy=0 inb=1]
probe SQD  sprite=86x45 sel=92x51 expected=92x51 d(0,0,0,0) dy=5/15 hit=1 pass[sprite=1 cover=1 rect=1 cx=1 cy=0 inb=1]
```

六个谓词里**只有 `cy` 失败**：选择框尺寸、与预期矩形逐边相等、水平锚点、包围盒包含中心，
全部通过。所以「选择框没盖住身体」这个描述本身是错的——盖住了，只是锚点差异与断言预期不符。

### 根因

断言里潜航单位的预期垂直偏移写的是 `camera.tileHeight / 2`，60x30 瓦片下等于 **15px**。
而绘制侧的真实下沉是「1/3 个地图层级」：

```cpp
// src/render/core/RuntimeMapRenderer.cpp: drawLevelForObject
// A shallow visual offset: five pixels with the normal 60x30 tiles.
return objectRenderLevel(object)
    - (object.submerged ? runtimeSubmergedVisualDepthLevels() : 0.0);
```

`projectCellXY` 里每层级折算 `tileHeight / 2` 像素，所以 1/3 层级 = **5px**，与 `dy=5` 完全一致。
15 与 5 差 10px，于是 DLPH/SQD 永久判红。

为什么当年会写成半格：这条常量原本只是 `drawLevelForObject` 里的函数内 `constexpr`，
渲染器之外看不见，断言只能自己猜一个「差不多半格」的数字。

### 改法

1. `refactor(prep)`：把常量提为头文件 inline `runtimeSubmergedVisualDepthLevels()`，
   绘制与断言共用同一个来源（`61858b3`）。
2. `test:`：断言按该常量折算像素，并把 6 个谓词逐个打进失败输出（`d2f36b3`）。

```cpp
const int expectedRenderDeltaY = probeType.submerged
    ? static_cast<int>(std::llround(
          runtimeSubmergedVisualDepthLevels()
              * static_cast<double>(aquaticSelectionProbe.camera.tileHeight) / 2.0))
    : probeType.airborne ? -runtimeAircraftSpriteLiftPixels(*match->object, true) : 0;
```

### 验证

```
Unit selection bounds: MTNK=55x40/56x36 DEST=87x66/86x66 DLPH=43x25/43x25
SQD=92x51/100x41 ZEP=119x80/119x80 ENGINEER=23x34/29x32 fixed=yes aligned=yes hit-area=independent
```

六类对象（陆/海/潜/空/步兵）全部 `aligned=yes`。`build` 阻塞点后移到 M-15（见第三节）。

---

## 二、M-12 `interaction` 建筑 footprint 命中失配 —— 已计量，未修复（有意）

### 现象

`--interaction-smoke-test` 报 `structure footprint hit mismatch`。这条断言实际是 5 组谓词连写：

```cpp
if (previewCells.empty() || previewCells.size() != hitCells.size()
    || previewHash != hitHash
    || !runtimeRectEquals(previewBounds, projectedObject.footprintBounds)
    || !runtimeRectEquals(hitBounds, projectedObject.footprintBounds)
    || projectedObject.bounds.left > projectedObject.footprintBounds.left
    || ... || !rightClickMatches) { ... }
```

一句报错背后可能是几何口径、可能是命中测试、也可能是可见性过滤。先全部打出来：

```
type=CABUNK02 cells=4/4 hash=same
previewBounds=(983,58,1103,118) footprintBounds=(983,58,1103,118) hitBounds=(983,58,1103,118)
previewEqFootprint=yes hitEqFootprint=yes boundsContainsFootprint=yes rightClick=no
```

### 结论：几何全部一致，失败在「右键命中回不到自己」

- 预览格 / 命中格：4/4，hash 相同。
- 预览框、命中框、地基框：三个矩形**逐边完全相等**。
- `bounds` 覆盖 `footprintBounds`：成立。

也就是说 M-12 根本不是「命中框按动画包围盒还是按地基算」的问题——三者已经统一。
唯一致命的谓词是 `rightClickMatches`，而且命中目标为 `nullptr`（不是「打到了别的建筑」）。

### 逐对象计量

把命中点周围所有候选都打出来：

```
rightClickProbe=(1043,73) objects=14
  candidate #8 CABUNK02 footprintHit=yes bodyClip=no diamond=yes spans=yes depthVis=yes
```

只有一个候选。它在 `findProjectedObjectAtPoint` 里的走向是：

```cpp
if (it->usesFootprintHit) {
    if (runtimeSpriteHitSpansContainWin32(it->structureSpriteHitSpans, point)) {
        if (buildingPixelVisible(*it)) return &*it;   // ← 这里返回 false
        continue;                                     // ← 于是整条对象被跳过
    }
    ...地基菱形兜底...
}
```

`spans=yes` 说明该像素**在建筑自己的可见像素里**；`depthVis=yes` 说明这个对象参与了深度重放；
但 `visibleBuildingHitSpans`（深度过滤后的可见像素集）不含该点，于是 `buildingPixelVisible` 为假，
按注释的既定规则「被别的场景对象挡住的像素不能通过地基重新变得可选」，整条对象被 `continue` 跳过。
而这一像素上**没有任何别的对象顶替**，结果就是：画得出、点不到的空洞。

### 为什么本轮不动手

命中逻辑的口径还没定：这个像素到底是「真的被什么东西挡住」（那就该返回挡它的那个对象），
还是「深度重放把这只 bunker 的前墙算成了不可见」（那就是可见性门的缺陷）。
两种定性的改法完全相反，而动 pick 会直接影响点击手感。

第 3 轮的 M-10 已经吃过一次同类亏：按直觉把负预留钳到 0，被 `physicalMapEdgeCovered` 与
void 指标当场反证。所以本轮只落计量（`799c9b6`），**不改命中**。下一轮的第一件事是把该像素上
所有 spans 命中对象与各自深度可见性一起打印，把「谁挡住谁」钉死。

---

## 三、新登记

### M-15 `build` 停在 `no unit/infantry catalog item`（已定性：夹具缺口）

unit selection 断言转绿后，`build` 冒烟推进到「队列一个单位/步兵」这一段：

```cpp
const auto unitIt = std::find_if(state.economy.catalog..., [&](const RuntimeBuildCatalogItem& item) {
    return (item.kind == RuntimeBuildKind::Infantry || item.kind == RuntimeBuildKind::Unit)
        && runtimeBuildAvailability(state, item).canQueue;
});
```

只有一句报错，分不清「夹具里没有工厂」与「可用性判定恒 false」。补一段只读计量后：

```
build catalog: total=46 unit=15 infantry=13 structure=18 credits=199200 power=200/0
  E1        queue=no start=no credits=yes lowPower=no reason="missing InfantryType"
  ENGINEER  queue=no start=no credits=yes lowPower=no reason="missing InfantryType"
  ...
  CMIN      queue=no start=no credits=yes lowPower=no reason="missing UnitType"
```

结论明确：**不是可用性判定坏了**。目录 46 项齐全、钱够（199200）、电够（200/0）、科技等级放行，
每条都停在 `runtimeOwnerHasCompatibleFactory` 这一步——`reason` 就是 `"missing " + item.requiredFactory`，
即世界里没有任何己方建筑带 `Factory=InfantryType` / `Factory=UnitType`。

这与 M-11 是同一类问题（2peaks 世界里 `Structures:10` 全为 Neutral，没有己方生产基地）。
所以 M-15 = **fixture-gap**，修法是给 build 冒烟补一栋己方兵营与一栋己方战车工厂，
走 `addRuntimeObjectInstance` + `refreshRuntimeObjectOccupancyAfterLocalChange`，
与 M-11 注入 MTNK 同一条产品创建路径。

本轮没做这一步：夹具落点要避开既有建筑的地基，改完还要重跑整条 `build`（它后面还有队列重排/取消/
集结点等一串断言），属独立一小批工作。时间锚点已到收口，按纪律不在末尾硬塞。

### M-12 的下一轮起手（更细一档的计量）

在同一失败分支里，对命中点打印每个对象的 `structureSpriteHitSpans` 命中情况、
`visibleBuildingHitSpans` 命中情况、`hasBuildingDepthVisibility`，以及该像素上所有
「spans 含此点但 depthVis 不含」的对象清单。目标是把「画得出点不到」的成因归到
「被遮挡」或「可见性门错杀」其中一侧。

---

## 四、本轮教训

1. **多谓词断言必须逐项计量。** `aligned=no` 与 `hit mismatch` 这种出口，把 6 条/5 条谓词压成一句，
   会直接把人引向错误的描述（「选择框没盖住身体」其实是「锚点差 10px」）。本轮两处都补了逐项输出，
   这一步的收益比修复本身更大——M-12 的整个方向（「命中框 vs 地基口径」）就是被这句报错误导的。
2. **负数/分数余量先找来源。** M-10 是负预留，M-14 是 1/3 层级：都是「看着像 bug 其实是策略/设计」的量。
   断言侧拍一个「半格」的近似值，就会永久判红。
3. **提常量时注意匿名命名空间。** 第一次把 `runtimeSubmergedVisualDepthLevels()` 的声明放进公共头、
   定义留在 `RuntimeMapRenderer.cpp`，链接直接失败——那个区域整个在匿名命名空间里（`nm` 显示
   `_GLOBAL__N_1` 内部链接）。改用头文件 inline 才既能共享又不破坏封装。
   判据：`nm <obj> | grep 符号名`，`t`（小写）就是内部链接。
4. **一条冒烟「修完仍红」不等于修复无效。** 本轮 build 从 M-14 推进到 M-15、interaction 从几何失配
   收窄到单个右键谓词，都是真实推进；`known-red.tsv` 里必须写清「现在停在哪」，否则下一轮会重走。

---

## 五、提交清单

| hash | 说明 |
|---|---|
| `61858b3` | refactor(prep): 潜航视觉下沉深度提为共享常量，绘制与断言同源 |
| `d2f36b3` | test: 潜航单位选择框断言按 1/3 层级下沉计，不再按半格 |
| `799c9b6` | test: interaction 建筑 footprint 命中失配加逐对象计量 |
| `14c0875` | docs: 第 5 轮开工——计划登记 M-14/M-12 的只读计量阶段 |
| 本轮收口 | docs: 本报告 + 计划状态；queue: v109 |

回归：`bash ra2mac_docs/scripts/regress.sh` → `PASS=6 KNOWN-RED=5 RED-NEW=0`（基线同，零新回归）。
两条已知红的状态更新为「阻塞点后移」，**不是**「修复无效」。
