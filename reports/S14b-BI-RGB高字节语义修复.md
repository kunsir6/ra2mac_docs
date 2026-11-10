# S14b：32bpp BI_RGB 的高 8 位不是 alpha，CPU stamp 把它抹掉了

> 2026-11-11 06:33–06:55 · 人工接续轮（持 `.active` 独占锁）· 源码提交 `8ca47eb`
> 队列条目：`S14b`（done）、`ON-4-01`（superseded）、新增 `ON-4-05`

## 一、起点：一条只报位置的失败

上一轮 ON-2-01 的否定报告建议先做 ON-4-01 / S14b。开工先跑真实现状，不猜：

```
$ cd ConcordRTS-GameData && ../ConcordRTS/build-product-mac/concord_runtime --interaction-smoke-test
Selected path batch: 300 overlapping/clipped/zero-length RGB cases and current points exact; opaque/XOR fall back.
Interaction smoke test failed: selected path raster: mixed sequence/current point differs at 0
    (first pixel 18x17 ref=0x9269e6be optimized=0x0069e6be)
EXIT=1
```

S14b 的 detail 原本列了三个候选原因：stamp 包围盒、裁剪边界逐像素写入、当前位置。
`firstDifference()` 给出的两个像素值把三个候选一次全排除——**RGB 完全相同**
（`0x69e6be` = 画笔 `RGB(105,230,190)`），只有最高 8 位不同：`0x92` vs `0x00`。

## 二、定位：GDI 只写 24 位，stamp 写了 32 位

契约的 `reset()` 把两侧表面填成 `0x91293874U ^ (index * 13397U)`，**高 8 位随 index 变化且非零**。
reference 侧直接调 GDI 画；optimized 侧走 `RuntimeSelectedPathRaster` 的 CPU stamp 快路径。

| 侧 | 写入路径 | 对高 8 位做什么 |
|---|---|---|
| reference | `PixelSink::fillSpan()` → `applyRop2()` (`RuntimeWin32CompatGdi.cpp:1102-1125`) | `(dst & 0xFF000000u) \| (value & 0x00FFFFFFu)` —— **保留目标原值** |
| optimized | `RuntimeSelectedPathRaster.h:262` 直接 `pixels_[i] = pixel.color` | stamp 来自**每帧清零**的 scratch DIB，alpha 恒 0 —— **整 32 位覆盖** |

`applyRop2()` 的注释已经把理由写死了：32bpp BI_RGB 不带 alpha 语义，把高 8 位一起参与
ROP 会让后续把该 DIB 当 RGBA 源的路径整片变透明（`DSTINVERT` 也专门保住它）。
`supported()` 已把 ROP2 限定为 `R2_COPYPEN`，所以快路径应当精确等价于 `applyRop2` 的复制分支。

这不是几何错误，也不是裁剪错误，是**快路径没有复刻它要替代的那条写入语义**。

## 三、修法（3 文件 / +21 / −4）

两处 CPU stamp 落点改成同一条表达式：

```cpp
std::uint32_t& target = pixels_[y * width + x];
target = (target & 0xFF000000u) | (pixel.color & 0x00FFFFFFu);
```

- `src/ui/selection/RuntimeSelectedPathRaster.h:258-270`（选中路径 / 菱形 / 航点）
- `src/ui/selection/RuntimeSelectionFrameRaster.h:222-233`（选择框 / 血量框）
- 契约 `RuntimeSelectedPathRasterContract.inl` 的 `reset()` 加注释：背景高 8 位非零是**刻意保留的观测判据**，
  改成 0 或纯黑会让这类偏离重新变成不可见。

没有改断言、没有放宽比较、没有动 scratch 的清零逻辑——清零点仍然正确，错的是把清零值带到目标像素上。

## 四、验证：smoke 是一条契约链，修一条就暴露下一条

| 轮次 | 改动 | interaction smoke 结果 |
|---|---|---|
| 0（改动前） | — | `selected path raster ... differs at 0 (ref=0x9269e6be optimized=0x0069e6be)`，EXIT=1 |
| 1 | 修 `RuntimeSelectedPathRaster.h` | `Selected path raster: 240 mixed-order full-32-bit ... exact` 转绿；下一条 `selection frame raster: full32/currentpoint differs test=1 unit=0`，EXIT=1 |
| 2 | 修 `RuntimeSelectionFrameRaster.h`（**同一根因**） | `Selection frame raster: 720 ... exact; stamps=8552 fallbacks=448 ...` 转绿；下一条 `projection history contract: actual rubble/selling structure did not participate in scene-Z replay`，EXIT=1 |

第 1 轮和第 2 轮是同一个缺陷的两处落点，不是两个 bug。`stamps=8552 / fallbacks=448` 说明
720 条序列里绝大多数真的走了快路径，不是靠回退把断言"绕绿"的。

### 回归（全绿）

```
--main-menu-ui-smoke-test                        EXIT=0  (sideTopFrames=2 / skirmish transition completed=yes)
--skirmish-ui-smoke-test                         EXIT=0  (maps=161 allPreviews=161 lobbyVisiblePixels=377167)
CONCORD_MAIN_MENU_POINTER_NAV_ONLY=1             EXIT=0  checks=48 failures=0 pages=0->1->0 forwardDiff=13780
concord_win32_compat_gdi_selftest                EXIT=0  135 checks / 0 failures
concord_win32_compat_user_selftest               EXIT=0  42 checks / 0 failures
concord_window_cursor_semantics_selftest         EXIT=0  14 checks / 0 failures
```

重编 `[2/2] Linking CXX executable concord_runtime`，0 FAILED；新链接二进制按本机约定
`codesign -s - --force` 后才运行。

## 五、新暴露的独立缺陷：转 `ON-4-05`

`--interaction-smoke-test` **仍未 EXIT=0**，但失败点已经换成投影几何族：

```
RuntimeProjectionHistoryContract.inl:378-380
resolveRuntimeBuildingVisibleHitSpansWin32(...) 后
    !actualSpans.contains(base.instanceId)
→ "actual rubble/selling structure did not participate in scene-Z replay"
```

`resolveRuntimeBuildingVisibleHitSpans`（`RuntimeStructureSpriteGeometry.inl:581-598`）先查
`findRuntimePaintBuildingVisibleHitSpans` 的绘制缓存，命中即 `return true`；否则才建
`RuntimeBuildingDepthFrameScope` 做几何 replay。契约要求"销售中 / 废墟"结构必须参与 scene-Z replay。

**判定为既有缺陷首次暴露，不是本轮回归**，依据两条：
1. 这条断言排在两条像素契约之后，改动前的第一次 smoke 就 `return` 在 `selected path raster`，
   它从未被执行过；文档库里 `projection history` / `scene-Z` 也零命中。
2. 契约第 374 行的 `fastPixels != originalPixels` 已通过，说明本轮改动没有引入像素差异；
   失败在读取 hit spans，与 GDI 像素写入无数据通路。

新任务 `ON-4-05` 的第一步写成动作而不是猜测：打印"命中缓存还是走 replay / spans 里有哪些
instanceId / base.instanceId 与 mission、rubble 状态"，拿到数字再定修法。

## 六、队列口径的拆分（不是放宽验收）

- `S14b` → **done**：它自己的断言（`Selected path raster` 240 用例）已转绿，且顺带清掉
  `Selection frame raster` 720 序列。verify 改写为绑定这两条具体断言。
- `ON-4-01` → **superseded**：detail 描述的 `Rectangle` 非实线改 4 条 `strokeLine` 已由
  `82af67d`（S14a）落地，是重复条目（并发诊断轮独立得出同一结论）。它写的
  "`--interaction-smoke-test` EXIT=0" 是**整条链**的终点，不该绑在单条像素任务上。
- 新增 `ON-4-05` 承接 smoke 全绿这个总目标。

理由：队列作者写这两条 verify 时，smoke 恰好停在像素契约处，误以为后面没有别的断言了。
把"清完这条断言"和"整条 smoke 全绿"拆开，是修正一个被事实推翻的验收假设，
与 S13 当年把单向契约改成双向契约同类；不是为了把红任务标绿。

## 七、教训（已写进 queue rules）

1. **32bpp BI_RGB 的高 8 位是负载数据，不是 alpha**。任何绕过 `PixelSink` 直接写 DIB 的
   快路径都必须复刻"只替换 RGB、保留目标高 8 位"，否则自洽契约会以 `ref=0x92… / opt=0x00…`
   这种「看着像颜色错、其实是字节语义错」的形状报出来。
2. **契约里的背景填充是判据的一部分**。`0x91293874 ^ index*13397` 的高位变化是唯一能观测
   到该偏离的东西；把它"简化"成清零，测试会全绿而缺陷依旧。
3. **smoke 是一串契约，不是单个断言**。修完一条必然暴露下一条，所以 verify 要绑定到
   "自己那条断言的输出"，`EXIT=0` 这种总目标单独挂一条任务，否则永远无法归因、也无法诚实标 done。
4. **并发机制本轮生效**：06:33 人工轮写入 `.active=held` 后，06:45 的自动化轮看到持锁，
   自动转 diagnose-only，未取锁、未碰源码、只写文档（queue v67 加注 + 报告）。
   两侧结论互补，没有发生 `peer_swept_worktree_into_family_commit` 那类串改。
