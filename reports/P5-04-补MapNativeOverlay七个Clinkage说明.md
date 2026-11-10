# P5-04 · 补 MapNativeOverlay 的 7 个 C-linkage

链接缺口 **177 → 170**（C 114→107，C++ 63 不变），兑现 7 个符号、零新增。

## 一、兑现的 7 个符号

| 符号 | 语义 | 实现要点 |
|---|---|---|
| `GetPolyFillMode` / `SetPolyFillMode` | 填充模式读写 | `CompatDevice`/`CompatSavedState` 各加 `int polyFillMode = ALTERNATE`，`SaveDC`/`RestoreDC` 保存恢复；Set 返回旧值，非法模式返回 0 且不改状态 |
| `GetDeviceCaps` | 设备能力查询 | `HORZRES`/`VERTRES` 取 DC 位图宽高（录制 DC 无表面→诚实 0）；`HORZSIZE`/`VERTSIZE` 按 96 DPI 换算 `MulDiv(px,254,960)` 毫米；未知 index 返回 0 |
| `GetEnhMetaFileBits` | 导出定稿图元字节流 | 两段式：`cbBuffer=0` 查询长度、缓冲不足返回所需字节数，否则拷贝 |
| `GdiComment` | 往录制 DC 追加 `EMR_GDICOMMENT` | 记录布局 `nSize = sizeof(EMR)+sizeof(DWORD)+cbSize`，不参与边界合并（私有标记无 rclBounds） |
| `PtVisible` | 判点是否落在裁剪区 | 无裁剪→全可见；有裁剪→`regionContainsPoint(clip)`（NULLREGION 全不可见） |
| `PlayEnhMetaFileRecord` | 回放单条记录 | `EMR_HEADER`/`EOF`/`GDICOMMENT` 返回 TRUE；`EMR_BITBLT`/`EMR_STRETCHBLT` 反序列化内嵌位图重建源位图后交 `BitBlt`/`StretchBlt`；其余诚实失败 |

## 二、两个关键结论

### 1. PlayEnhMetaFileRecord 的范围远小于任务卡预期

任务卡写"反序列化 EMR_BITBLT/STRETCHBLT/SETPIXELV/LINETO/图元等记录"。实际核对后发现：**录制型 DC 目前只产出三种记录**——`EMR_GDICOMMENT`（marker）+ `EMR_BITBLT`/`EMR_STRETCHBLT`（位块传输）。图元/文本/alpha/区域在录制时就被对应函数显式拒绝（`LineTo`/`FillRect`/`Rectangle`/`GdiAlphaBlend` 等在录制 DC 上 `reportUnsupported`，不写流）。

因此回放只需正确支持这三种 + 诚实失败兜底，而不是实现 `scan()` 承认的全部 98 种记录类型。

### 2. extern "C" 块边界（本轮踩的坑）

`RuntimeWin32CompatGdi.cpp` 的对外 API 全部位于 `extern "C" { ... }` 块内（约 line 1452–3200），内部 helper（`emfBeginRecord`/`emfRecordBlit` 等）在块外。

第一版把 `GdiComment` 插在 `emfRecordBlit` 之后（块外），导致它是 C++ mangled 符号，与 `windows.h` 的 `extern "C"` 声明（`_GdiComment`）对不上，链接仍报未定义。移到 extern "C" 块内后解决。

**教训：往 Gdi.cpp 加新 API 必须落在 extern "C" 块内。**

## 三、验证（真实输出）

```
ninja concord_runtime          编译 0 错误，链接缺口 177 → 170
gdi selftest                  124 checks（新增 44），0 failures
verify-win32-compat.sh        10/10 层全绿
  1/10 头层声明      399 个函数声明可编译
  2/10 头层内联      67 checks
  3/10 GDI 实现      124 checks
  4/10 DC 状态       207 checks
  5/10 XAPO          25 checks
  6/10 EMF 录制回放  47 checks
  7/10 小族          66 checks
  8/10 区域裁剪      154 checks
  9/10 图元光栅      141 checks
 10/10 文件进程      147 checks
```

## 四、改动文件

| 文件 | 改动 |
|---|---|
| `compat/win32/src/RuntimeWin32CompatGdi.cpp` | 7 个 API 实现 + `polyFillMode` 字段（Device/SavedState）+ SaveDC/RestoreDC |
| `compat/win32/selftest/CompatGdiSemantics.cpp` | 新增 44 checks（polyFill 17 + EMF 往返 19 + PtVisible 8） |
