# P5-03 · 放回 MapComposition + MapNativeOverlay（28 符号，含头层 + cmake 解耦）

结论先行：**放回 MapComposition 8 + MapNativeOverlay 20 = 28 个 C++ 符号，链接缺口 198 → 177。**
净降 21 = 28 兑现 − 7 新增（放回后才有调用点的 7 个 Win32 API）。编译 0 错误、28 符号零残留、
misc/file/gdi 三个 selftest 全绿（66 / 147 / 80 checks）。

## 一、对任务卡的两处修正

1. **「32 个 EMR 常量」→ 实际 98 个**。`MapNativeOverlayReplayWin32.inl` 的 switch 实际
   用到 98 个 EMR 记录类型（S2 只补了 EMR_HEADER/EOF/BITBLT/STRETCHBLT 4 个），本轮补全其余
   94 个。全部按 wingdi.h 官方枚举值，关键易错值用 MSDN 核对过：`EMR_GDICOMMENT=70`、
   `EMR_SETLAYOUT=115`、`EMR_ALPHABLEND=114`、`EMR_TRANSPARENTBLT=116`、`EMR_GRADIENTFILL=118`。
   （CSDN 有篇博客把 115 写成 `EMR_ALPHADIBBLEND`，是第三方库的非标准定义，MSDN 官方
   gdiplusenums.h 明确 115=SetLayout。回放器按数值 switch，值错=记录类型静默串位。）

2. **「缺口 198 → 170」→ 实际 198 → 177**。任务卡写「170」是漏算了「放回 leaf 会把它自己
   还没实现的那批 Win32 API 变成新缺口」。这 7 个正是 MapNativeOverlay 的运行时依赖
   （见第三节），留 P5-04。

## 二、本轮做了什么

### 1. 头层补全（compat/win32/include/windows.h）

| 类别 | 内容 |
|---|---|
| EMR 常量 | 98 个（4 已有 + 94 新增），按 wingdi.h 官方值 |
| EMR 结构体 | `EMR`、`EMRGDICOMMENT`、`EMRMOVETOEX`、`EMRLINETO`、`EMRRESTOREDC`、`EMRCREATEPEN`、`EMREXTCREATEPEN`、`EMRSETPIXELV`、`EMRANGLEARC`，各带 offsetof static_assert 钉死字段偏移 |
| 配套类型 | `POINTL` 别名、`EXTLOGPEN32`（含 ULONG_PTR，8 字节对齐） |
| 常量 | `SPI_GETFONTSMOOTHING*`×4、`HORZRES/VERTRES/HORZSIZE/VERTSIZE`×4 |
| 声明 | `getenv_s`、`GdiComment`、`GetEnhMetaFileBits`、`PlayEnhMetaFileRecord`、`PtVisible` |

### 2. getenv_s 实现（RuntimeWin32CompatMisc.cpp）

窄版 `_wgetenv_s`，复用其内核（不加 UTF-8↔wchar_t 往返）。三态语义与宽版一致：
存在→0 且给含 NUL 元素数；不存在→0 且计 0；缓冲不够→ERANGE。selftest 加 14 checks。

### 3. cmake 解耦（关键一步）

`include(MapNativeOverlayWin32.cmake)` 原挂在 `D3D11FramePresenter.cmake` 末尾，而后者带
`message(FATAL_ERROR ...fxc.exe)`——Apple 绝不能 include 它。本轮把该 include 移到
`SoftwareFrameContracts.cmake` 的 `if(WIN32 OR APPLE)` 内，与 FramePresenter 同条件；
`MapNativeOverlayWin32.cmake` 加 `include_guard(GLOBAL)`。依赖 `concord_skirmish_back_buffer_win32`
在 `DevelopmentTargets.cmake` 里先于本文件 include，顺序安全。

### 4. 唯一源码改动（非 compat 层）

`src/ui/surface/win32/MapNativeOverlayReplayWin32.inl` 两处
`std::max(0L, RECT 差值)` → `std::max(static_cast<LONG>(0), ...)`。

原因：Windows 上 `LONG=long`（32 位），`0L` 与之同型；本平台 `LONG=int32_t`（32 位 int）
而 `0L` 是 64 位 long，`std::max` 模板推导失败（long vs int）。`static_cast<LONG>(0)` 在两平台
同型（Windows 是 long、macOS 是 int），语义不变。这是**放回纯逻辑 TU 时不可避免的最小平台适配**，
不是改 if(WIN32) 分支。其余 std::max/std::min 均已带显式模板参数或 cast，无需动。

## 三、7 个新增 C-linkage（留 P5-04）

| 符号 | MapNativeOverlay 调用点 | 实现复杂度 |
|---|---|---|
| `GdiComment` | marker() 写 EMR_GDICOMMENT | 机械（照 emfRecordBlit 追加记录） |
| `GetEnhMetaFileBits` | compile() 导出字节流 | 机械（读 EmfMetafile::bytes） |
| `GetDeviceCaps` | begin() 查 HORZRES/HORZSIZE 等 | 机械但值必须准（EMF 图框换算输入） |
| `SetPolyFillMode`/`GetPolyFillMode` | begin() 状态拷贝 | 机械（CompatDevice 加字段） |
| `PtVisible` | replay 判点是否在裁剪区 | 机械（照 region 判点） |
| `PlayEnhMetaFileRecord` | replay 回放单条记录到软件 DC | **硬活**（反序列化各记录类型） |

## 四、验证

```
cmake -S . -B build-product-mac                         配置通过（exit 0）
ninja -C build-product-mac concord_map_native_overlay_win32  编译 0 错误（仅 4 条无害 -Wformat）
ninja -C build-product-mac concord_runtime               编译 0 错误，走到链接
未定义符号 198 → 177（C 107 → 114，C++ 91 → 63）
  消失 28 = MapNativeOverlay 20 + MapComposition 8（逐名核对 0 残留）
  新增 7 = 上表（逐名核对，全部来自 MapNativeOverlay 调用点）
misc selftest  66 checks 0 failures（含新增 getenv_s 14 checks）
file selftest  147 checks 0 failures
gdi selftest   80 checks 0 failures
```

## 五、边界（不能说成"成了"）

- **仍无可运行二进制**（缺 177 符号）。MapNativeOverlay 这 28 个符号"有定义了"≠"能跑"——
  它内部还调 7 个未实现的 Win32 API，运行时必然失败。
- 4 条 `-Wformat`（`%lu` vs `DWORD`）是产品源码在 macOS 上的无害警告（DWORD 在 Windows 是
  unsigned long、本平台是 unsigned int），该 leaf 无 -Werror，不影响编译链接。
- 无 Windows 金标准，Windows 零回归是「条件分支逻辑等价 + 常量值官方核对」推出来的，非实测。

## 六、下一步

**P5-04**：补 7 个 C-linkage（前 6 个机械活 + PlayEnhMetaFileRecord 硬活），让 MapNativeOverlay
真正可运行，缺口 177 → 170。之后「放回」主线告一段落，剩余缺口转 S4（文本）与 S7（窗口）选型。
