# FIX-12 命中样本落在视口外（interaction 转 PASS）

> 轮次：2026-11-12 第 11 轮
> 基线：`PASS=9 KNOWN-RED=2 RED-NEW=0`（`20261112-190119`）
> 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（见 §4）
> 结论：**M-12 不是产品缺陷**。「建筑画得出、点不到」的真正原因是**被采样的建筑整栋落在
> 深度重放的视口之外**——pick 侧的可见性过滤是对的，断言在要求一个不存在的像素。
> 产品代码零改动（`findProjectedObjectAtPoint` 未动）。

---

## 一、把「空 span 表」拆成四桶

第 10 轮的读数是 `spansSprite=140 spansForeground=0 spansVisible=0 inSprite=yes inVisible=no`，
于是问题被改写成「空 span 表同时表示『没参加重放』与『全被挡住』」。这两个候选都指向产品，
但都拿不出证据。本轮先加计量（`0b1f9e7`）：

`CONCORD_HIT_SPAN_TRACE=1` 打开后，`extractRuntimeBuildingVisibleHitSpans` 对**每个空 span 参与者**
打印五个数：

| 桶 | 含义 |
|---|---|
| `participating` | 在 `frame.participatingIds` 里（有资格产出可见像素） |
| `drawsInView` | 该 id 的绘制矩形与视口**相交**的条数 |
| `drawsOffView` | 该 id 的绘制矩形与视口**不相交**的条数 |
| `visiblePixels` | 深度缓冲里 `visibleOwner == id` 的像素数 |
| `depthPixels` | 深度缓冲里 `depthOwner == id` 的像素数（进过深度） |

汇总行另给 `unownedPixels` / `depthOnlyPixels` / `visibleOwners` / `emptyParticipants`。

## 二、读数：两种候选都不成立

失败那一帧：

```
Hit span trace: tick=0 reference=no resolved=yes viewport=0,0,808,446 pixels=360368
  participants=7 draws=12 unownedPixels=349264 depthOnlyPixels=0 visibleOwners=3 emptyParticipants=4
  empty #8 participating=yes drawsInView=0 drawsOffView=1 visiblePixels=0 depthPixels=0
```

而同一冒烟打出的样本包围盒是 `previewBounds=footprintBounds=hitBounds=(983,58,1103,118)`。

三点互证：

1. **`drawsInView=0 / drawsOffView=1`**：CABUNK02 的唯一一次绘制矩形与视口 `(0,0,808,446)` 不相交。
   建筑在视口右侧之外（左边界 983 > 808）。
2. **`visiblePixels=0` 且 `depthPixels=0`**：它连深度都没写过——不是「进了深度又被压过」
   （全帧 `depthOnlyPixels=0` 也印证没有这种像素）。
3. **`emptyParticipants=4` 而 `visibleOwners=3`**：7 个参与者的 4 个空条目里，至少 3 个是
   「绘制在视口外」，不是「被遮挡」。

所以「没参加重放」与「全被挡住」都不是原因，**第三种情况**才是：参加了重放，但绘制被视口裁掉，
命中测试因此按「不可见」处理——这是正确的行为，因为视口外的像素在屏幕上根本不存在。

### 为什么样本会落在视口外

同一冒烟的前一段是雷达/相机极值场景，结束时把镜头显式停在**地图几何中心**
（`state.camera.worldOffsetX/Y = centeredCameraX/Y`），随后直接
`buildProjectedObjects(state, viewport)` 取「第一个 footprint > 1×1 的建筑」当样本。
镜头停在哪儿与样本建筑在哪儿，这两件事此前**没有任何约束**——样本可能整栋在视口外。

## 三、改法：断言前先对焦（产品零改动）

在采样前把镜头对焦到样本建筑，再重建投影（`b855223`，纯冒烟改动）：

```cpp
if (framingTarget != nullptr) {
    centerRuntimeCameraOnCell(state, clientRect, runtimeCellPointForObject(*framingTarget));
    ensureRuntimeCameraForViewport(state, viewport);
    invalidateRuntimeObjectProjectionCache(state);
}
projectedObjects = buildProjectedObjects(state, viewport);
```

结果：

```
Hit footprint: object #8 CABUNK02 previewFootprintCells=4 hitFootprintCells=4
  selectionBounds=120x60 rightClickTargetBounds=120x60 footprintHash=6214199620800725115
  consistent=yes footprintPreserved=yes visibleStructurePixelsHit=yes
  rightClickTargetUsesFootprint=yes selectionUsesFootprint=yes
```

对焦后同一条 trace 的视口变成 `(0,142,726,637)`——说明该帧视口**不是**固定的客户区矩形，
而是随相机与地图边界裁剪后的可见区。这也解释了为什么「视口外」与「镜头停在哪儿」是同一条
问题：**换镜头等于换视口**。

## 四、回归

| 时间 | 结果 | 目录 |
|---|---|---|
| 开工基线 | `PASS=9 KNOWN-RED=2 RED-NEW=0` | `20261112-190119` |
| 收口 | `PASS=10 KNOWN-RED=1 RED-NEW=0` | 见 `progress/regress/` 最新目录 |

`interaction` 由 KNOWN-RED 转 PASS，`command`（C-02 两栖卸载）仍是唯一 known-red，零新回归。

## 五、教训

1. **关于「可见像素」的断言必须先让对象在画面里。** 这与 M-18（建筑零投影）是同一族：
   探针把镜头放到看得见的地方，才谈得上断言「看不见」。两次都是「相机取景」被当成产品缺陷查。
2. **`visiblePixels=0` 有两种以上解释，只有 `depthPixels` 能分开。** 「没进光栅」「进了深度被压过」
   「光栅了但被视口裁掉」三者在 span 表上完全同形，分别对应三种不同的改法（夹具 / 遮挡 / 取景）。
3. **先问「这个像素在屏幕上存在吗」**。pick 的可见性过滤一旦遇到视口外坐标，
   返回 nullptr 是正确行为；把它当 bug 改 pick，会把「看不见的东西可以点」这条防御拆掉。
