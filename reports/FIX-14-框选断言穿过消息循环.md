# FIX-14 框选断言穿过消息循环（M-02 计量）

日期：2026-11-12（第 13 轮）
主题：**一条十二轮没被质疑过的断言，其实从来没跑过产品路径**。
本轮产品行为零改动（只改冒烟），回归 `10/1/0` → `10/1/0`，`RED-NEW=0`。

---

## 一、旧断言是假门

`interaction` 冒烟里「Box selection」那一段（原 `RuntimeShell.cpp` ~38498）是这样写的：

```cpp
std::vector<int> boxSelectionIds;
for (const RuntimeProjectedObject& projectedObject : projectedObjects) {
    if (projectedObject.object != nullptr
        && runtimeObjectCanBeBoxSelected(*projectedObject.object)
        && rectsIntersect(projectedObject.bounds, viewport)) {
        boxSelectionIds.push_back(projectedObject.object->instanceId);
    }
}
applySelection(state, boxSelectionIds, false, false);
if (state.selectedObjectIds.empty()
    || state.selectedObjectIds.size() != boxSelectionIds.size()) { ... fail ... }
```

它把「包围盒与矩形相交」**又实现了一遍**，然后直接 `applySelection`。也就是说：

- 产品的拖选路径 `runtimeWindowProc` → `handleRuntimeMapLeftPointerUp` →
  `host.boxProjectionItems()` → `applySelection`，**一次都没被执行**；
- 断言唯一验证的是「`applySelection` 会不会把传进去的 id 存下来」，
  这是同义反复——`applySelection` 自己就是存 id 的那半段。

后果：拖选链路整条断掉（比如 `moved` 判据、capture、投影重建任何一环），这条断言照样绿。
这正是 M-02（「框选结果和画面上框住的单位对不上」）能在台账上躺十二轮而没有任何判据的原因——
不是没人查，是**没有一条测试能看见它**。

## 二、改法：三次投递，走真实手势

照 `Team keys` 那段的写法（`WS_POPUP` 不上屏窗口 + `PostMessageW` / `PeekMessageW` /
`DispatchMessageW`），把拖拽拆成三条真实消息：

| 消息 | 参数 | 作用 |
|---|---|---|
| `WM_LBUTTONDOWN` | `MK_LBUTTON`, start | `handleRuntimeMapLeftPointerDown` 置 `active=true`、记 `start/current` |
| `WM_MOUSEMOVE` | `MK_LBUTTON`, end | `dx²+dy²>16` → `moved=true`（本段位移远超阈值） |
| `WM_LBUTTONUP` | `0`, end | `moved` 分支 → `boxProjectionItems` 逐项 `runtimeInputPixelRectsIntersect` → `applySelection` |

窗口用 `runtimeWindowProc` + `GWLP_USERDATA=<state>`，与 `Team keys` 同一条分发路径；
`DestroyWindow` 之后把 `WM_DESTROY` 造成的 `WM_QUIT` 吃掉，避免污染后续取消息的地方。

期待值仍按产品现行口径（包围盒 ∩ 拖拽框）独立算一遍，断言两者集合相等。
这仍然是对照同一条规则，但**执行侧换成了真实链路**：规则没变，走的路变了，
所以它能抓到「链路断了」，只是抓不到「规则本身不对」——后者见下节。

## 三、顺带做 M-02 的计量：bbox 与中心分开计数

拖拽框取 `viewport` 左侧 60%（`band=8,8 513,632`，800×600 客户端下的地图视口），
对每个可框选单位同时算两种口径：

- **bbox**：包围盒与拖拽框相交（产品现行口径，也就是本期断言的期望值）；
- **center**：包围盒中心落在拖拽框内（「框住谁」的手感口径）。

读数（`interaction` 冒烟）：

```
Box drag (message loop): band=8,8 513,632 bbox=4 center=3 bboxOnly=1 picked=4
Box drag bbox-only units: #9003(503,481 561,523 x103,99)
```

`picked=4` 与 `bbox=4` 相等 → 产品链路本身是通的、与既定口径一致。
差的那个是 `#9003`（HTNK，cell 103,99）：包围盒 `(503,481)-(561,523)` 宽 58，
只有 `503..513` 这 **10 px** 落在框内，中心 `(532,502)` 在框外。

## 四、定性：不是坐标错位，是 bbox 语义

先把一条**被证伪的假设**记下来：台账里 M-02 的根因写的是
「框选用世界坐标、投影用表面坐标，两套换算未对齐」。本轮实测不支持它——

- 拖拽框与命中判定**共用同一对字段** `state.leftPointer.start/current`：
  画框在 `RuntimeShell.cpp` 的 `Rectangle(dc, dragRect...)`，命中在
  `RuntimeMapLeftPointerController.cpp` 的 `drag{min/max(start,current)}`，同一坐标系、同一对数字；
- `runtimeRightPointerNativePoint/Rect` 在这一层都是**恒等转换**，
  视口与 `projectedObject.bounds` 已经在同一空间（旧断言拿 `bounds` 直接与 `viewport` 相交也是这个前提）；
- 如果真是整体错位，`picked` 与 `bbox` 不会恰好相等——错位会让两侧系统性偏向某一边。

所以 M-02 的真实形态是：**包围盒比精灵可见像素大**。
单位帧带透明留白，移动帧还会「变矮变宽」（M-14 的 `SQD 92x51 vs 100x41` 就是同一个帧族），
于是「只擦到包围盒边缘」的单位被选中，玩家看到的是「框在我旁边/框外，却把它选走了」。

### 为什么本轮到此为止

要判「那 10 px 里到底有没有可见像素」，需要单位级的可见像素跨度（类似
`extractRuntimeBuildingVisibleHitSpans` 但针对 Unit/Infantry）。本项目目前只有建筑侧有这层能力，
单位侧要新写一层逐像素可见性重放——那就是「改产品之前的又一次计量」，且是呈现层的活。
按纪律（M-18/M-12 两次教训：**关于可见像素的断言必须先有可见像素读数**）不在本轮猜。

两种改法的代价与风险，留给下一轮在拿到读数后选：

| 改法 | 改什么 | 风险 |
|---|---|---|
| A. 中心在框内 | 控制器 1 行：改比 `bounds` 中心 | 与零售「擦边也选」的习惯相反，可能变严 |
| B. 可见像素相交 | 单位侧新增可见跨度层，命中按跨度判 | 呈现层新增重放，成本高；但和 pick 的口径统一 |

## 五、本轮结论

- `interaction` 的框选断言**从同义反复变成真断言**：现在它验证产品拖选链路能跑通，
  且选中集合与独立算出的期望集合一致。链路若断，这条会红。
- M-02 从「坐标错位（未证）」改写为「bbox 含透明留白（已量出边界用例，未量到像素）」，
  台账里补上读数与两种改法。
- 回归 `10/1/0` → `10/1/0`，`RED-NEW=0`，产品代码零改动。

## 六、下一轮起手

1. **M-02 第二步（中等）**：给单位侧补一层「可见像素范围」计量（照 M-12 的四桶思路：
   `participating/drawsInView/visibleBoundsInBand`），先量 `#9003` 那 10 px 条带；
   有读数后再在 A/B 两种改法里选一个，并同步写一条「框外单位不许被选中」的反向断言。
2. **S-08 + M-03（合批）**：世界 idle 空转重绘的计量与脏区提交条件，仍未动。
3. **C-02（复杂，单独成轮）**：`command` 两栖卸载，唯一 remaining known-red。
