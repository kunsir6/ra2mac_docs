# S3-1：DC 状态与查询（A 段 26 个符号）

日期：2026-11-10 04:5x
性质：**实现轮**。改动 `compat/win32/include/windows.h`（+38 行）、
`compat/win32/src/RuntimeWin32CompatGdi.cpp`（+约 420 行）、
新增 `compat/win32/selftest/CompatDcStateSemantics.cpp`（207 条断言）、
`cmake/PlatformApple.cmake` 与 `scripts/verify-win32-compat.sh` 各加一个目标。

结论先行：**A 段 25 个 + 提前拉进来的 `GetCurrentPositionEx`，外加两个声明了但无人调用的
Ext 读取（`GetViewportExtEx` / `GetWindowExtEx`），共实现 29 个；链接缺口 267 → 241（−26），
A 段零残留；七层自测全过（207 条新断言）。产品构建图仍是 0 编译错误。**

> 账目先说清：实现 29、缺口降 26。差的 3 个（`GetViewportExtEx` / `GetWindowExtEx` /
> `SetDCPenColor`）本来就不在缺口里——产品构建图里没有任何 TU 引用它们。这不是少做了，
> 是"声明了但没人调用"。数字对不上时先查这里。

---

## 1. 这一族看起来是"状态存取"，实际是像素路径的总开关

项目里有三条快路径，它们不约而同地做同一件事：**先在 DC 上逐项比对状态，任何一项
不符就静默退回逐图元的慢路径**。

| 快路径 | 位置 |
|---|---|
| `RuntimeSelectedPathRaster::supported()` | `src/ui/selection/RuntimeSelectedPathRaster.h:199` |
| `RuntimeSelectionFrameRaster` 构造函数 + `beginTrustedRestoredDcStateBatch()` | `.../RuntimeSelectionFrameRaster.h:155` |
| `RuntimeRadarPixelStore::isStandardDib()` | `src/ui/radar/win32/RuntimeRadarPixelStoreWin32.cpp:22` |

它要的初值是这样一组具体数字：

```
GetBkMode == TRANSPARENT(1)          GetROP2 == R2_COPYPEN(13)
GetGraphicsMode == GM_COMPATIBLE(1)  GetMapMode == MM_TEXT(1)
GetArcDirection == AD_COUNTERCLOCKWISE(1)   GetLayout == 0
GetCurrentObject(dc, OBJ_BRUSH) == GetStockObject(NULL_BRUSH)
GetWindowOrgEx/GetViewportOrgEx 均 (0,0)     GetClipBox == SIMPLEREGION(2)
```

**随手 `return 0` 会让其中五项永不成立，快路径永远关闭——而这不会让任何测试变红。**
现有契约全都是"快路径 vs 参考路径"在同一套 GDI 上自洽比较（`std::equal(reference.pixels,
optimized.pixels)`），两边一起走慢路时结果依然相等，于是全部通过。这是本层到目前为止
最隐蔽的一种失败模式：**不是崩溃，是静默降级**。

处置：所有初值按 Win32 文档钉死，并在自测里用**字面量**断言（`GetROP2(dc) == 13`，
不是 `== R2_COPYPEN`）——拿常量自比时，头文件把常量抄错也照样通过。同时把
`RuntimeSelectedPathRaster::supported()` 的判据逐条照抄成一轮用例，并额外断言
"破坏任一项后判据必须失配"，否则"全过"这个结论没有分辨力。

---

## 2. `GetObjectW`：一个函数，两种位图

这是本轮的实质性判断。Win32 里位图有两副面孔：

| | 创建方式 | `GetObject(sizeof(BITMAP))` | `GetObject(sizeof(DIBSECTION))` | `bmBits` |
|---|---|---|---|---|
| DIBSection | `CreateDIBSection` | 返回 `sizeof(BITMAP)` | 返回 `sizeof(DIBSECTION)` | 光栅内存 |
| 设备位图 DDB | `CreateCompatibleBitmap` | 返回 `sizeof(BITMAP)` | **返回 `sizeof(BITMAP)`**（于是调用点的 `!= sizeof(DIBSECTION)` 判据正确拒绝） | **`nullptr`** |

产品侧的 `CampaignDeviceBitmapContract` 正是靠 `bmBits == nullptr` 断言"这是设备位图"。
本层两种位图共用同一块内存（否则没法光栅化），所以这是整层唯一一处**实现比对外语义更强**：
内部有像素，但对 DDB 必须回答"没有可寻址像素"。写进注释了——将来若有人照着 `GetObject`
的结果去 `memcpy`，读到的是不该暴露的地址。

如果这层只做 DIB、把 DDB 也报成 DIB，`CampaignDeviceBitmapContract` 会红；如果为了让它绿
而统一报 DDB，`RuntimeSelectedPathRaster` 会永久关闭。两条路都错，只能区分。

### `bmHeight` 的符号：两个字段、两条规则

`S3-诊断报告.md` 里留了一个未决问题：项目注释说"GetObject 把 top-down DIB 的高度归一到
正数"，而 SDK 文档说 `dsBm.bmHeight` 取自 `biHeight`（负数）。三处产品代码写的是
`dib.dsBm.bmHeight != height`（`height > 0`），且这些断言在 Windows 上是绿的——说明实测
确实是正数。所以本轮按字段分开处理：

- `dsBm.bmHeight` → **取绝对值**（迁就项目实测语义）；
- `dsBmih.biHeight` → **逐字节保留创建时入参**（负值原样带出），因为调用点对正负两解都接受
  （`biHeight == h || biHeight == -h`）。

两条规则都钉进了自测。这是"文档与实测冲突时先按实测、但把选择写死"的典型处置：注释错了
没人知道，断言错了编译不过。

---

## 3. 三个只有"往返测试"才抓得到的错误

### `SaveDC` 漏字段 = 污染不会被还原

`RuntimeRadarPixelStoreContract` 一类用例的形态是：`SaveDC → 污染 DC 状态 → 观察快路径是否
退让 → RestoreDC`。如果新增的 11 个状态字段不进 `CompatSavedState`，污染会在恢复后残留，
表现为后续用例**莫名其妙地走慢路径**——而且测不出来（快慢两路结果仍然相等）。

本轮把 DC 里每个可变字段都补进了快照，并加了一轮专门用例：设满 10 个字段 → `RestoreDC` →
逐项读回。

### `GdiSetBatchLimit` 必须真存取

调用点（`RuntimeFlakPresentationSmoke.inl:10`）写的是：

```cpp
struct RestoreGdiBatch {DWORD limit; ~RestoreGdiBatch(){GdiSetBatchLimit(limit);}} batch{GdiSetBatchLimit(1)};
```

靠返回值把旧上限存下来。恒返回同一个常数会让"还原"变成空操作，而且**恒等式测不出来**——
只有"设 1 → 返回 20 → 再设回 20"这种往返才验得出。已按 Win32 默认值 20 实现并断言往返。

### `SetViewportOrgEx` 的 out 参数是**旧**值

两个方向都是双指针语义，写反了不报错。项目里 `MapNativeOverlayWin32.cpp:163` 的用法是
"读参考 DC 的原点 → 设到录制 DC 上"，若 out 参数回填新值，那行代码会把自己刚设的值当成
旧值带走。已按"回填旧值"实现并断言。

---

## 4. 两处诚实的失败（刻意不做成"能用"）

**`GetClipBox` 对没有像素表面的 DC 返回 `ERROR`(0)。**

- 录制型 DC：裁剪框应当来自 `CreateEnhMetaFile` 的 `rcFrame`，本层没有保存那个矩形。
- 未选位图的内存 DC：也没有像素表面。

`ERROR` 既不等于 `SIMPLEREGION` 也不等于 `NULLREGION`，所有调用点都会走"不支持"分支——
这正是想要的。返回一个编出来的矩形会让依赖 `!= SIMPLEREGION` 的雷达快路径在复杂情况下
继续走快路，那比报错危险得多。

**`GetObjectW(font, sizeof(LOGFONTW), &lf)` 返回 0。**

字体要到 S4 才有真实度量数据。调用点写的是 `== sizeof(LOGFONTW)`，返回 0 会让断言当场变红；
回填一个假 LOGFONT 会让后续排版按错误的字高去算——**宁可红，不可假绿**。
`GetObjectType(font)` 仍然正常返回 `OBJ_FONT`（库存字体对象是真实存在的）。

---

## 5. `LAYOUT_LTR` 是 0，所以"同时选 LTR 和 RTL"不可表达

第一版校验写的是"LTR 与 RTL 必须恰好选一个"，自测断言 `SetLayout(LTR|RTL)` 返回
`GDI_ERROR` —— 当场失败。原因是 `LAYOUT_LTR` 就是 0，`0|1` 等于只选 RTL，这个组合在数值上
不存在。真正需要拒绝的是**未知标志位**（`0x10` 之类）。已改成只校验未知位。

这条记下来是因为它很典型：校验逻辑里"两选一"的直觉在这里没有对应物，写出来是一段
永远走不到的死代码。

---

## 6. 验证

### 七层自测（`scripts/verify-win32-compat.sh`）

| 层 | 结果 |
|---|---|
| 1 头层声明（仅编译） | 395 个声明与常量可编译 |
| 2 头层内联语义 | 67 checks |
| 3 GDI 对象/位图传输 | 80 checks |
| **4 DC 状态与查询（新）** | **207 checks** |
| 5 XAPO / CXAPOBase | 25 checks |
| 6 EMF 录制与回放 | 47 checks |
| 7 小族（CRT `_s` / COM / 定时器 / MCI） | 52 checks |

### 链接缺口

| | 总数 | C-linkage | 项目 C++ |
|---|---|---|---|
| S9 后 | 267 | 167 | 100 |
| **S3-1 后** | **241** | **141** | 100 |

消失的 26 个 = 实现 29 个中真正被 `concord_runtime` 引用的那部分（另 3 个无引用，见开头账目）。
C++ 段一个没动（本任务不碰它）。
产品构建图 **0 编译错误**，剩 241 个全是链接期缺口。

---

## 7. 现在还不能声称的东西

- **三条快路径仍然 `available() == false`**——不是因为状态不对（状态判据已经全过，第 4 层
  用例逐条复现了 `supported()`），而是因为 `LineTo` / `FillRect` / `Ellipse` 还不存在
  （C 段，S3-3）。`RuntimeSelectedPathRasterContract` 那条 `default DIB path unavailable`
  现在还会红，红在光栅器上。
- **`GetClipBox` 永远返回 `SIMPLEREGION` 或 `NULLREGION`**：裁剪区表示目前只有矩形，
  `COMPLEXREGION` 要等 S3-2 的多边形 region。届时这条判断必须跟着改，否则复杂裁剪区会被
  报成简单区域，依赖 `!= SIMPLEREGION` 的调用点会在复杂裁剪下继续走快路。
- `SetMapMode` 接受 `MM_ANISOTROPIC` 但**没有真正映射坐标**（现在没有绘制函数，无从体现）。
  S3-3 落地图元时必须实现 `(x - windowOrg) * viewportExt / windowExt + viewportOrg`，
  否则"返回成功但不缩放"就是本层最不该出现的静默错误。
- `MulDiv` 除数为 0 时返回 −1，但**没有置 `LastError`**（S10 才有 `SetLastError` 的线程局部
  存储）。
- `EC` 段之外的 `GetDC`/`ReleaseDC` 仍然没有（S7）：它们要求窗口后端或离屏 DC 语义。
