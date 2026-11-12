# FIX-11：被 known-red 掩盖的新回归（第 10 轮）

> 轮次：2026-11-12 第 10 轮
> 基线：`PASS=8 KNOWN-RED=3 RED-NEW=0`（`20261112-120122`）
> 收口：`PASS=9 KNOWN-RED=2 RED-NEW=0`（`20261112-121057` / 最终 `20261112-1215xx`）
> 源码 commit：`d69980d`（S-11）、`bf5fd7c`（M-21）、`0e72a10`（M-12 计量）
> 文档 commit：`2263e4f`（计划基点）+ 本报告所在的 `docs:` + 队列 `queue:`

本轮主题不是「按性价比挑一条」，而是**回归本身差点骗了我们**。

---

## 1. S-11：known-red 行正在掩盖新回归

### 现象

开工基线仍是 `8/3/0`，与第 9 轮收口逐字一致。但 `interaction` 的失败文案已经换了：

```
第 9 轮：structure footprint hit mismatch
第 10 轮：original ESC menu state/resources are invalid: ...
         gameSpeedSlider=yes/no/no/yes/yes
```

`regress.sh` 的三态判定只回答「这条 pass 还是 known-red」，不回答「known-red 的**原因**有没有变」。
interaction 早就在 `known-red.tsv` 里，于是这条**新回归**根本不会报 RED-NEW。

### 定位

`gameSpeedSlider` 那一串 5 个布尔依次是：几何 / 坐标 / 全局节奏 / 拖拽 / 键盘
（`RuntimeShell.cpp:37627`-`37760`）。读数是 `yes/no/no/yes/yes` —— 只有中间两组红，
而这两组正是**唯一两处钉死「6 档 = 0 拍/秒」这张旧表**的地方：

- `gameSpeedSliderRight`：`runtimeSimulationPacingTickRate(...) == 0`
- `expectedGameSpeedPacing{{31,38,47,63,94,188,0}}`

第 9 轮之后的 `ffdd7c5`（BUILD-03）把 6 档从 retail 的「零等待哨兵」改成 5 档 ×1.5 = **281.25 拍/秒**，
`unlimited()` 恒 false。它同步改了速度契约和时空冒烟，但这两张表漏掉了。

同一族还有一处：`RuntimeSupportPowerSmoke.inl` 仍按 `initiallyUncapped / changedUncapped`
两支要求「6 档速率为 0」，在 281 上直接 fail。它不在 11 条 smoke 里，所以连红都没人看见。

### 改法

只改断言，产品零改动（速度阶梯本身是对的：七档 31/37.5/46.88/62.5/93.75/187.5/281.25 严格单调）：

- 末位 `0` → `281`（两处）
- support-power 拆掉 uncapped 分支，改为「每一档都必须报有限正速率」，并保留「速率随档位递增」的单调性断言

### 为什么这条排在 M-21 前面

ESC 菜单断言在 `RuntimeShell.cpp:38131`，而 footprint 命中在 `40422`。**它排在前面**——
只要它红，冒烟根本走不到 M-12。不清掉这道假门，下一轮去查 M-12 只会白跑一趟。

修完 interaction 立刻回到 `structure footprint hit mismatch`，即原登记点，
证明 S-11 是「挡在前面的一道门」而不是 M-12 的替代品。

---

## 2. M-21：矿喷发动画探针把「帧」当「拍」用（`render` 转 PASS）

### 现象

`render` 十轮停在 `oreGrowthSpawnerAnimationDrawn=false frames=11`，
而同一行的 `ran/changed/ring=1/overlay=yes` 全绿。

### 根因

判据在 `RuntimeShell.cpp:33119`：`animationStats->terrainObjectAnimatedSprites > 0`，
而渲染侧（`RuntimeMapRenderer.cpp:40836`）的置位条件是：

```cpp
if (terrainFrameCount > 1 && terrainFrame > 0) ++stats.terrainObjectAnimatedSprites;
```

`frames=11` 是 `terrainFrameCount`（取所有地形对象的 max），说明**帧数够、精灵也画出来了**，
红的是 `terrainFrame`：`selectRuntimeTerrainObjectAnimationFrame` 对产矿地形走

```cpp
eventAge = runtimeTerrainOreSpawnAnimationAgeTicks(object, terrainType, animationTick, frameCount * delay);
if (eventAge < 0) return 0;
return clamp(eventAge / delay, 0, frameCount - 1);
```

`delay = runtimeTerrainObjectFrameDelayTicks(...)` = `runtimeRuleFramesToTicks(AnimationRate, fixedTickHz)`。
`[TIBTRE*]` 的 `AnimationRate=3`，30Hz 下 `delay = ceil(3*30/15) = 6` **拍**。
而探针推进的是 `eventTick + AnimationRate` = `eventTick + 3` —— 3 **帧**被当成 3 拍。
于是 `eventAge = 3 < delay = 6`，`eventAge/delay` 恒为 0，**永远选第 0 帧**。

### 改法

探针改成推进同一套单位：`eventTick + runtimeRuleFramesToTicks(AnimationRate, fixedTickHz)`。
`eventAge` 恰等于 `delay`，选出第 1 帧：

```
Resource growth probe: ... anim=yes/frames=11 sample=TIB01@98,53 ...
```

产品渲染路径**一行未动**。这不是「改产品迁就断言」，而是让探针停在真实会取到第 1 帧的时刻；
改前那一刻在真实对战里也存在（事件后 3 拍），只是探针只肯测 3 拍。

**`render` 由 KNOWN-RED 转 PASS**，这是本项目第一次把这条从第 1 轮就红的 smoke 清掉。

---

## 3. M-12：空 spans 的语义没有定义（本轮只计量，不修）

### 本轮读到的数

```
type=CABUNK02 cells=4/4 hash=same
previewBounds=(983,58,1103,118) footprintBounds=(983,58,1103,118) hitBounds=(983,58,1103,118)
previewEqFootprint=yes hitEqFootprint=yes boundsContainsFootprint=yes rightClick=no
  rightClickTarget none
  spansSprite=140 spansForeground=0 spansVisible=0 visibleRows=none inSprite=yes inVisible=no
  rightClickProbe=(1043,73) objects=14
    candidate #8 CABUNK02 footprintHit=yes bodyClip=no diamond=yes spans=yes depthVis=yes
```

### 这否掉了上一轮的假设

第 5 轮把 M-12 写成「该像素上只有 CABUNK02，sprite spans 含它、depth-visible spans 不含，
被 `buildingPixelVisible` 拦下后无人顶替」。那句话听起来像「被别的对象挡住了」。
实测：**该像素上只有它一个候选**（14 个对象里没有第二个 diamond/spans 命中），
而且它自己的 `visibleBuildingHitSpans` 是**空的**——不是这个像素不可见，是**整栋楼零可见像素**。

所以「谁挡住谁」这个问法本身是错的：没有任何东西挡它。

### 真正的问题定义

`resolveRuntimeBuildingVisibleHitSpans` 的产出里，空的 span 表同时承担两种语义：

1. **没参加绘制** —— 源码注释写得很清楚：「Invisible buildings intentionally retain an empty entry.
   Missing resources keep the existing geometric/fallback selection instead.」
   即 `runtimeInvisibleMapBuilding` 为真、`image=null`、`!resolved` 之外的路径会留一个空表占位，
   本意是「别按像素可见性判它」。
2. **参加了但一个像素都没留下** —— 全被前面的对象压掉，或绘制矩形被裁到视口外。

`findProjectedObjectAtPoint` 的 `buildingPixelVisible` 只看到 `hasBuildingDepthVisibility &&
!contains(visibleSpans, point)`，**分不出这两种**，于是把 (1) 也当成 (2)，
整栋楼 `continue`，右键返回 nullptr —— 正是「画得出、点不到」。

### 为什么不在本轮改

两种定性改法相反：

- 若属 (1)：pick 侧应**忽略**空表（回落几何/fallback），改 `buildingPixelVisible`。
- 若属 (2)：那是可见性重放本身的问题（绘制矩形/深度合成），改 pick 只会掩盖它。

判据必须来自重放侧，不能来自 pick 侧。**下一轮第一件事**：在
`extractRuntimeBuildingVisibleHitSpans` / `resolveRuntimeBuildingDepthDraws` 里给每个参与 id
记三个数——`draws` 条数、`draw.rect ∩ viewport` 是否为空、扫描到的 `visibleOwner` 像素数——
把 (1)/(2) 分桶。这是纯计量，一轮能做完。

---

## 4. 流程教训

1. **known-red 的行必须带「原因指纹」**。三态判定只保护「不许新增红」，不保护
   「已知红的原因被换掉」。本轮 interaction 换了原因却仍显示 KNOWN-RED，`RED-NEW=0` 是假的安全感。
   下一轮起，`known-red.tsv` 的第三列之外应再记一截**失败前缀**（如
   `original ESC menu state/resources`），regress 比对时若前缀变了就单独报一行。
   这条建议已写进 `queue.json` 的 decisions。
2. **「阻塞点后移」既是进展也是警报**。第 9 轮记的是「interaction 停在 M-12」，
   第 10 轮开工却停在 M-12 **前面**——后移一旦反向，就是被别人改动打破的信号。
3. 一个 10 轮没清掉的红（`render`），根因往往不是深，而是**单位**：
   `AnimationRate` 是帧、`delay` 是拍，这两个词在同一个函数体内相邻出现，没人去核。
   凡「帧 / 拍 / 毫秒」三种单位同处一段，必须显式命名变量（`...TickDelay` / `...FrameDelay`）。

---

## 5. 本轮改动清单

| 条目 | commit | 性质 | 影响 |
|---|---|---|---|
| S-11 速度表两处 + support-power | `d69980d` | 断言 | interaction 越过 ESC 菜单段，回到真正的 M-12 |
| M-21 矿喷发探针单位 | `bf5fd7c` | 断言（探针） | **render 转 PASS** |
| M-12 四层 spans 计量 | `0e72a10` | 只读计量 | 问题定义从「谁挡住谁」改为「空表两种语义」 |

产品代码（渲染/模拟/输入）**本轮零改动**。
