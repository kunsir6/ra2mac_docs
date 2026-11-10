# P5-02 · 放回第一批纯逻辑+GDI 的 win32 产品 leaf（9 符号）

结论先行：**放回 4 个文件的 9 个 C++ 符号，链接缺口 207 → 198（C 107 不变，C++ 100 → 91）。**
编译 0 错误、9 个符号零残留、0 个新增（无级联）。产品图配置通过。

## 一、对任务卡的修正：16 → 9

任务卡 P5-02 原计划「放回 16 符号（含 MapComposition 8）」，并在 touches 里留下一句
`cmake/MapNativeOverlayWin32.cmake 之外 —— 实际是 SkirmishBackBufferWin32Contracts.cmake 等 5 个`，
说明上一轮已隐约意识到纠缠。本轮把它查实：

**MapComposition 不能独立放回。** 证据链：

1. `MapCompositionWin32.h` **include 了 `MapNativeOverlayWin32.h`**；
2. `MapCompositionWin32` 有成员 `MapNativeOverlayWin32 native_;`，并调用
   `native_.begin()` / `native_.cancel()` / `native_.finish()`（`MapCompositionWin32.cpp` 实测）；
3. 两者在**同一个 leaf** `concord_map_native_overlay_win32` 里（`MapNativeOverlayWin32.cmake` 用
   `target_sources(... MapCompositionWin32.cpp)` 合并编译）。

所以「拆出 MapComposition 独立 leaf」会让它的 .o 链接时连带缺 MapNativeOverlay 的 20 个符号。
正确结论：**MapComposition 8 + MapNativeOverlay 20 必须一起放回**，且一起补头层 + 解耦 include
链 —— 这正是 P5-03 的完整内容。P5-02 只做「依赖已全部到位」的干净部分。

## 二、本轮放回的 9 符号（4 文件）

| 文件 | 符号 | 依赖（已到位） |
|---|---|---|
| `RuntimeSkirmishBackBufferWin32.cpp` | 4（ensure/release/upload/ensureDeviceBitmap） | 纯项目抽象 |
| `RuntimeRadarPixelStoreWin32.cpp` | 2（ctor/dtor） | GetClipBox + GetObjectW |
| `RuntimeResultBitmapTextWin32.cpp` | 1（drawResultBitmapTextWin32） | CreateSolidBrush/FillRect/IntersectClipRect |
| `FramePresenterWin32.cpp` | 2（Dib ctor + composeOverlay） | BitBlt/GdiFlush（已实现）；GetDC/ReleaseDC（S7，头已声明、链接仍缺） |

> 任务卡把 FramePresenter 记成 1 符号（只 Dib ctor）。实测它兑现 **2** 个：Dib ctor +
> `composeWindowDeviceOverlayWin32`。后者是自由函数，同文件定义，放回文件即一并兑现；
> 它内部取 `&::GetDC`/`&::ReleaseDC` 的地址，这两个 C-linkage 符号本就在 107 个缺口里（S7），
> 所以 C-linkage 缺口不变、无新增。

## 三、cmake 改法（4 个合约文件，统一套路）

套路：**把产品 leaf + `target_link_libraries(concord_runtime ...)` 从 `if(WIN32)` 里拎出来扩成
`if(WIN32 OR APPLE)`，把 contract 测试（依赖 gdi32/user32 + MSVC ABI + native fixture）留在
`if(WIN32)` 里。**

| 文件 | 改法 |
|---|---|
| `SkirmishBackBufferWin32Contracts.cmake` | `if(NOT WIN32)` → `if(NOT WIN32 AND NOT APPLE)`；产品 leaf 留在 return 之后；contract_leaf + add_executable + gdi32 + add_subdirectory(main_back_buffer) 包进 `if(WIN32)` |
| `RadarPixelStoreContracts.cmake` | 拆两个 `if`：`if(WIN32 OR APPLE)` 产品 leaf；`if(WIN32)` native_contract 测试 |
| `ResultBitmapTextContracts.cmake` | 拆两个 `if`：产品 leaf（含 link `concord_result_bitmap_text`）扩到 APPLE；contract 测试留 WIN32 |
| `SoftwareFrameContracts.cmake` | FramePresenter leaf 扩到 `if(WIN32 OR APPLE)`；`if(CONCORD_MSVC_FRONTEND)` + `add_subdirectory(frame_presenter)` + `include(D3D11FramePresenter.cmake)` 留 WIN32 |

关键不变式：**Windows 下每个文件的行为与改前完全等价**（`WIN32 OR APPLE` 在 Windows 下恒真、
`NOT WIN32 AND NOT APPLE` 恒假、contract 测试仍在 `if(WIN32)` 内），所以 Windows 构建图零回归。

## 四、验证

```
cmake -S . -B build-product-mac          配置通过（exit 0）
ninja -C build-product-mac concord_runtime  编译 0 错误，走到链接
未定义符号 207 → 198（C 107 不变，C++ 100 → 91）
  消失 9 = 本轮放回的 9 个（逐名核对）
  新增 0（无级联）
```

D3D11 presenter 的 14 个符号、字体 28、音频 7、GDI+ 7、SkirmishMusicPolicy 3、
runRuntimeInternetMenuClockContract 1、MapNativeOverlay 20、MapComposition 8 —— 全部**原地未动**，
继续缺。本轮没有"顺带兑现"任何不该兑现的东西。

## 五、边界（不能说成"成了"）

- **仍无可运行二进制**。放回的 4 个 leaf 编译 + 链接符号兑现，但产品可执行文件还没通过
  最终链接（缺 198 个符号），更没有跑起来。
- `FramePresenterWin32.cpp` 的 `composeWindowDeviceOverlayWin32` 内部取 `&::GetDC`/`&::ReleaseDC`
  地址，这俩仍缺（S7）。符号"兑现"只是"composeOverlay 这个 C++ 符号有了定义"，不是"它能跑"。
- 类②「D3D11 不被引用」的**运行时前提尚未落地**：`RuntimeShell.cpp` / `RuntimeSkirmishMenu.cpp`
  无条件 include D3D11 头并在 `FrameBackend::D3D11` 分支调用 `::create`。软件呈现模式下该分支
  运行时不会进，但**链接期**仍需要符号 —— 类②的 14 个 D3D11 符号因此继续缺，留待后续用
  `#if _WIN32` 裁剪调用点（本轮没碰，也不该在"放回"主线里碰）。
- 无 Windows 金标准可对拍，Windows 零回归是**条件分支逻辑等价**推出来的，非实测。

## 六、下一步

- **P5-03**：补 `getenv_s`（窄版）+ 32 个 EMR 常量（约 40 行头层），把
  `MapNativeOverlayWin32.cmake` 从 `D3D11FramePresenter.cmake` 的 include 链解耦，
  放回 MapComposition 8 + MapNativeOverlay 20 = 28 符号。缺口 198 → 170。
