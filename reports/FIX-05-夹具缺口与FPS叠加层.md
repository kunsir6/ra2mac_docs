# FIX-05 夹具缺口与 FPS 叠加层（2026-11-12 第 4 轮）

本轮两条问题的共同点：**都不动模拟层**。一条是 `build` 冒烟的世界里根本没有可悬停的单位（fixture-gap），
一条是正式版没有帧率面板而当前每帧都画（观感硬伤）。共用一次构建、一次回归。

回归结果：`PASS=6 KNOWN-RED=5 RED-NEW=0`（与基线一致，零新回归）。
`build` 仍红，但**阻塞点从第 3 个后移到第 4 个**（M-14），这是如实推进而不是无效修复。

---

## 一、M-11 `build` 悬停血条「没有单位」

### 现象

`build` 在第 3 个阻塞点停在：

```
Build smoke test failed: no unit available for hover health bar.
```

该冒烟的世界来自默认地图 `2peaks.map`，地图里 `Structures=10 / Units=0 / Infantry=0`——
建筑与地形齐全，但**一台单位都没有**。

### 根因

夹具缺口，不是产品缺陷。断言要找「一台非建筑对象」做悬停主体，而这张图从来不给单位。
上游 Windows 版此断言是绿的，说明差的是 macOS 侧夹具的构造方式，不是渲染/命中逻辑。

### 改法（`0ce035a`）

1. **用产品路径生成单位**：`addRuntimeObjectInstance(state, RuntimeBuildKind::Unit, "MTNK", cell)`。
   这一步会走 `applyRuntimePlacementObjectPose` / `runtimeInitialProducedFacing` / `subCell` 等，
   产出与真实生产完全同形的对象。
2. **必须让「自身包围盒中心命中回自己」**：悬停探针不是直接指定 id，而是把鼠标点设成
   `bounds` 中心再走真实的 `findProjectedObjectAtPoint`。第一次按「结构格 +2,+2」放，
   结果 `hover=0/1/0`（判成了建筑悬停）——基地建筑贴得紧，那个点落在建筑的命中框里。
   改成沿半径 2..10 的环逐格试，条件是「投影出单位 → 取包围盒中心 → 命中测试回本单位」，
   命中即停。
3. **探针后按 id 摘掉**：`erase(remove_if(id == 注入 id))`，后续阶段看到的仍是原始地图
   （日志 `Unit hover fixture: released id=31 objects=30`）。
4. 顺带处理了一个隐性悬垂：`push_back` 可能扩容让此前捕获的建筑指针失效，因此改存
   `structureProbeId` 并在注入后重新解析；`RuntimeObjectIndex` 本身只存 offset 且每次校验，
   删除后不会留下野指针。

### 结果

```
Unit hover fixture: injected MTNK id=31 at 62,42 (map shipped no units)
Unit hover health: type=MTNK selected=0 structureHover=0 unitHover=1
  pixelDelta=168 healthResource=10 healthFallback=0 ...
```

悬停单位血条这条断言**转绿**，`build` 推进到第 4 个阻塞点（M-14，见第三节）。

### 教训

> 「世界里没有可用对象」这句话不能直接当缺陷读。先问：这个对象应该由谁创建？
> 本项目的答案是 `addRuntimeObjectInstance`——手搓 `WorldObjectInstance` 结构体虽然能画出像素，
> 但 pose / `hasRenderPosition` / `subCell` / facing 都绕过产品路径，命中测试回不到自己，
> 于是「有像素却判定不是它」。第一版就是这么写的，`pixelDelta=851` 却 `unitHover=0`。

---

## 二、S-09 FPS 叠加层默认常显（U-17）

### 现象

窗口左下固定 96×22 面板，底色 `RGB(19,29,39)`、白字 `FPS: 60`，**任何提交路径都画**。
正式版 RA2 / 尤里的复仇没有这个面板（UI-01 §3.1，唯一一条「像素级证据 + 代码位置」都齐的硬伤）。

### 根因

该面板是为自测加的，加的时候没有留开关：`RuntimeShell.cpp` 的三条提交路径
（device overlay 合成、软件回退、无 backbuffer 直绘）都无条件调 `drawRuntimeFpsDisplay`。
`RuntimeMainFrameContract` 只断言 `runtimeFpsDisplayRect` **矩形非空**，不断言「画了」，
所以契约不会替我们兜住这个默认值。

### 改法（`c1ccfe6`）

- `RuntimeConfig::fpsOverlayEnabled`，默认 `false`（放在「player-local presentation preferences」段，
  与 `scrollCoasting` / `seeHiddenObjects` 同级，不进确定性模拟权威）。
- 解析 `[Options] ShowFps`；新增 CLI `--show-fps`（`RuntimeMain` 的 `showFps` → 覆盖配置）。
- 三个绘制点各自门控，**帧率计本身照旧运行**（`fpsDisplayMeter` 仍 record，只是不画），
  这样遥测/自测数据不被一起关掉。
- 不动 overlay 合成路径：游标叠加也走同一个 `composeWindowDeviceOverlayWin32`，
  把整段禁掉会把游戏自绘指针一起干掉。

### 结果

默认启动不再出现帧率面板；`--show-fps` 或 `[Options] ShowFps=yes` 可复现旧行为。
回归 11 条无变化（该面板不参与任何离屏断言的像素比对）。

---

## 三、新登记：M-14 `build` 移动帧选择框不覆盖可见身体

`build` 推到第 4 个阻塞点：

```
Build smoke test failed: mobile selection frames were not covering visible bodies
across land, naval, submerged, air, and infantry objects.
MTNK=55x40/56x36 aligned=yes DEST=87x66/86x66 aligned=yes
DLPH=43x25/43x25 aligned=no  SQD=92x51/100x41 aligned=no
ZEP=119x80/119x80 aligned=yes ENGINEER=23x34/29x32 aligned=yes
```

读数（`ready/move` 两个姿态）：

| 类型 | 现象 | 初步判断 |
|---|---|---|
| DLPH（潜航） | 两个姿态尺寸**完全相同** 43×25，却 `aligned=no` | 失败的不是尺寸谓词，而是同函数里的 `renderCenter.y - center.y == tileHeight/2`（潜航抬升半格）或 `pointInRectInclusive(bounds, selectionCenter)`。属「尺寸对、锚点偏」，**先分辨是实现偏还是断言口径偏** |
| SQD（步兵） | 92×51 → 100×41，两个姿态不一致 | 移动帧的 sprite 比待机帧宽/矮，选择框跟着换尺寸；要么选择框该锁尺寸（原版步兵框固定），要么断言的「≥ sprite」口径对动画帧不成立 |

两者都**没有**在本轮动手：`aligned=no` 的两种成因（尺寸 vs 锚点）必须先用只读计量切开，
否则会重演 M-10 那次「按直觉改产品、被反证指标打回」。已登记为 M-14（中等，needs-metering），
下一轮起手从此处接。

---

## 四、本轮提交

| hash | 一句话 |
|---|---|
| `0ce035a` | `fix:` build 冒烟按需注入可悬停单位（夹具缺口） |
| `c1ccfe6` | `fix:` FPS 叠加层默认关闭，`--show-fps` / `[Options] ShowFps` 开启 |

两个 commit 都按「行为修复」单独落，未夹带断言改动——本轮没有新增断言（M-11 是让既有断言拿到主语，
S-09 是让既有绘制拿到开关），因此没有配 `test:` commit。
