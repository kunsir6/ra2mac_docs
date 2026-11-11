# FIX-04 两条断言的几何口径（M-09 / M-10）

> 第 3 轮（2026-11-12 03:07 起）。主题：**两条判红的根因都不在产品，而在断言口径本身**。
> 两条都先量几何再动，改动全是断言侧，产品路径零改动。
> 产物：`0e99bc1`（M-09）、`469cfa8`（M-10），回归 `PASS=6 KNOWN-RED=5 RED-NEW=0`。

## 结论先说

| 条目 | 登记时的判断 | 实测结论 | 处置 |
|---|---|---|---|
| M-09 建筑血条 61x33 vs 61x31 | 疑「实现多画 2px」 | **公式旧**：断言按水平条算高度，实际贴斜边画 | 改断言（test:） |
| M-10 南向极值 tile 未覆盖 | 疑「相机南向钳制多放一行」 | **实现是对的**：物理边缘 −half-tile 提前停是策略，反过来才露 void | 改断言（test:） |

两条都属「上一轮前置失败把后续断言整段屏蔽」的延续：清了前置之后暴露出来的，
是断言自己的问题，不是产品退化。

---

## 一、M-09 建筑血条包围盒高度

**现象**：`build` 条 `edge=no actual=61x33 expected=61x31`，宽一致、14/14 分段正常、
无限血（CABHUT）已正确隐藏。

**量的过程**（2x2 footprint，tile 60x30）：

1. 选择框四个 footprint 角 → 冠顶角 `crownPoint(corner, verticalHeight, clearance)`，
   `clearance=3`。
2. 血条锚点沿**冠顶斜边**排布：`firstAnchor = topEnd.x-5`，`deltaX = leftEnd.x+4 - firstAnchor.x = 51`，
   13 个区间共 14 个锚点，每个锚点 y 按斜边斜率取整（`edgeRise/edgeRun = 30/60`）。
3. `bounds = {leftEnd.x, topEnd.y, topEnd.x+1, lastAnchor.y + 7}`：
   `lastAnchor.y = topEnd.y + lround(51*0.5) = topEnd.y + 26` → 高 = 33。

所以 33 = 斜边竖直跨度(30) + 冠顶间隙(3)；**旧断言的 `+1` 是「水平条」口径**，
它对横向排布的车辆血条成立，对沿斜边排布的建筑面积血条天然少 2px。
几何侧另有 `selectionHealthBarMatchesCrownEdge` 精确锁死了 clearance=3 / pip 高 7 /
斜率一致性，本次没有改动它。

**改法**：把 `3` 提成 `kStructureHealthBarClearance`，绘制路径与断言共享；
断言高度改为 `footprint.height * tileHeight/2 + kStructureHealthBarClearance`。
宽度断言（`depth*halfTileWidth+1`）保持原样——它本来就是对的。

**效果**：`Structure hover health: ... edge=61x33 segments=14/14 resource=14 fallback=0
selection-edge=yes CABHUT=infinite-hidden`，该断言转绿；`build` 条停在下一个阻塞点（M-11）。

---

## 二、M-10 相机南向钳制极值

**现象**：`edgeCells=4/4:no`，`S=142/142@0/4260->428/640 tile=398/625..458/655:no`，
即最南一行在视口底(640)以下被切了 15px；`corners=4/4:no`；而 `void` 全 0。

**先试的错方向（已回退）**：`safeReveal()` 在 `available < cover` 时会返回**负数**
（南向 available=0、cover=15 → −15），看起来像 bug，于是把下限钳到 0。

实测立刻被同一文件里的 `physicalMapEdgeCovered` 断言打回，更关键的是
**void 从 `0.000/0` 变成 `0.012/856px`**：负数预留是**有意的策略**——物理地图边缘
（LocalSize 已到 IsoMapPack 末）让相机提前半格停住，把渲染的锯齿黑边留在客户区外。
改成 0 就把那条黑边拉了进来。**数据反证了「实现错」的假设**，这也印证了「先量再改」：
如果先按直觉改产品再补断言，就会把一条正确的策略当成 bug 修掉。

**真正的错**：两条断言互相矛盾——
- `physicalMapEdgeCovered`（正确）：物理边缘预留必须是 −half-tile，且 `cover >= halfTile`；
- 极值 cell / envelope corner 断言（错误）：要求最极端 cell **完整**落在视口内。

两者在几何上不可同时成立：要「无 void」就得提前半格停，停下必然切掉半格。

**改法**（`RuntimeShell.cpp`，产品路径零改动）：
- 每个方向先算允许溢出量 `allowedOverhang{Left,Right,Top,Bottom} = max(0, -reveal.*)`；
- 极值 cell：中心必须在视口内，且四向溢出量 ≤ 对应方向允许量
  （只有物理边缘方向得 15px，其余方向仍是 0，严格性不变）；
- envelope corner：同样的四向允许量；
- 用户可见保证继续由 `runtimeCurrentCameraVoidCoverage` 的 ratio 独立度量（未放宽）。

**效果**：`edgeCells=4/4 corners=4/4`，`S ... tile=398/610..458/640:yes`，
`revealReserve=60/30/120/0 expected=60/30/120/0 physicalEdge=half-tile-covered`，
void 回到 `0.000`。该条停在下一个阻塞点（M-12）。

---

## 三、回归

```
PASS=6 KNOWN-RED=5 RED-NEW=0     （基线同，零新回归）
build        KNOWN-RED  结构血条断言已绿 → 停在「无单位可做悬停血条」（M-11）
interaction  KNOWN-RED  相机/预留断言已绿 → 停在「structure footprint hit mismatch」（M-12）
```

两条仍然红，但**红的原因都换了**：不是修复无效，而是前置屏蔽解除后暴露出的下一个阻塞点。
两者都已登记，M-11 判为 fixture-gap（简单），M-12 需先量命中框与 footprint 的口径（中等）。

## 四、可复用结论

1. **包围盒断言必须先确认「条是横的还是斜的」**。斜边图元的高 = 跨度 + 间隙，用水平条公式
   会恒定差 slope 那一段，且差值随 footprint 增大。
2. **遇到负数预留/负数余量，先找是谁依赖它**，不要直接钳到 0。本次的反证指标是
   void ratio：策略正确时它恰好为 0，钳到 0 后立刻出现 856px 边缘 run。
3. 同一 smoke 里两条断言对同一物理量（极值 cell 可见性）要求相反时，**以用户可见指标
   （void）为准**，把另一条改成策略容忍的形式，而不是改产品去迁就断言。
