# BUILD-01 正版建造速度对账 + 建造/防御"就绪"角标

**日期**：2026-11-12
**输入**：用户提供的正版录像 `SVID_20261112_011757_1.mp4`（720×448 / 30fps / 84.9s，手机横屏录制，带中文字幕）
**结论一句话**：正版的建造速度确实**远慢于我们原来的速度 4**——差距不在公式，而在一行硬编码乘数
`runtimeSidebarBuildingProductionSpeedMultiplier = 16`（单位是 8）：按正版数据兵营应在 5～10 秒量级，
我们原来只有 **0.43 秒**。**已按确认把两个乘数都改成 1**，现在速度 4 是兵营 6.7s / 矿场 26.9s，
夹在"正版最快 5.3s"和"正版同档 10.1s"之间。角标已按"顶部居中、带底色、下两角圆角"实现并验收。

---

## 1. 视频里能直接读到的事实

| 观察项 | 结果 | 判据 |
|---|---|---|
| 分辨率/帧率 | 720×448，30fps，84.9s | `ffprobe` |
| 侧栏位置/宽度 | 右侧，约 **59px** 宽（两列 cameo，单格 ≈28px） | 裁 `crop=110:120:610:60` 放大 6× |
| 与正版 800×600 的差别 | 正版侧栏 168px、cameo 60×48；本片是缩放后的移动端/竖屏录制 | 同上 |
| 镜头 | 全程固定，同一片苏军基地 | 逐帧差分只有单位/光效在动 |
| 放置动作（绿色合法幽灵） | **t≈3.3s、22.0s、65.0s、70.5s** 各一次；70.5s 那次先绿后红（落到非法格） | 按 `g−r>40 ∧ g−b>40` 找连片绿色像素 |
| 两次放置的间隔 | **65.0s → 70.5s = 5.5s**（中间侧栏 cameo 变空） | cameo 灰度序列在 66.5–69.5s 落到 81.8（空槽） |

**这条 5.5 秒是最有用的外部锚点**：它说明该录像里一个 500 信用点的建筑（兵营/防御这一档）
从"上一座放下去"到"下一座可放"大约是 **5 秒级**，而不是十几秒级。换算到 1000 信用点 ≈ 10～11 秒。

> 说明：cameo 只有 28px，还被字幕与压缩糊过，**逐项读出"每座建筑各自用了多少秒"做不到**。
> 所以下面用发行版 `rulesmd.ini` 的权威常数换算，再用上面的 5.5s 锚点交叉验证。

## 2. 正版速度的换算（数据来源：发行版 rulesmd.ini）

```ini
[General]
BuildSpeed=.7   ; general build speed [time (in minutes) to produce a 1000 credit cost item]
```

即**每 1000 信用点 0.7 分钟（42 秒，按 15fps 的创作基准）**，每点信用点 0.042 秒。
正版逻辑帧率更高时按比例缩短：60 逻辑帧/秒 → 实战口径约 **10.5 秒 / 1000 信用点**，与视频的
5.5 秒（500 点）锚点吻合。

| 目标 | Cost | 创作基准时长 | 正版实战口径（≈60 逻辑帧/秒） |
|---|---|---|---|
| 兵营 GAPILE / NAHAND | 500 | 21.0s | **≈5.3s** |
| 矿场 GAREFN | 2000 | 84.0s | **≈21s** |
| 哨戒炮 NALASR（防御） | 500 | 21.0s | **≈5.3s** |
| 光棱塔 ATESLA | 1500 | 63.0s | **≈15.8s** |

## 3. 我们现在的实测

`runtimeCalculateProductionTiming()` 的创作时长与正版同源（`cost × 60 × BuildSpeed / 1000`），
但侧栏递交时又乘了一道**硬编码加速**：

```cpp
// src/runtime/session/detail/RuntimeProductionOperations.h:352
inline constexpr int runtimeSidebarProductionSpeedMultiplier = 8;         // 单位/步兵
inline constexpr int runtimeSidebarBuildingProductionSpeedMultiplier = 16; // 建筑/防御
```

实测（`--build-smoke-test` 新增字段 `structureBuildTicks`，本次跑出来的真值）：

```
Build result: placed GAPOWR ... sidebarBuildingProductionSpeed=16x ...
               readyBanner=yes structureBuildTicks=972
```

GAPOWR（800 点）在建制里记 **972 tick**（fixedTickHz=30），跑起来每 tick 只推进 `16/972` 的成本
→ **61 tick 完成**。再乘 `runtimeGameSpeedTiming()` 的每 tick 墙钟（速度 4 = 0.0107s/tick）：

| 目标 | totalTicks | 速度 4 实际耗时 | 正版（同档/最快） |
|---|---|---|---|
| 兵营 | 630 | **0.43s** | 5.3s（最快）/ 10.1s（同档） |
| 矿场 | 2520 | **1.69s** | 21s / 40.3s |
| 哨戒炮（防御） | 630 | **0.43s** | 5.3s / 10.1s |
| 光棱塔 | 1890 | **1.27s** | 15.8s / 30.2s |

**结论：我们比正版快 8～12 倍**，和用户"正版比我们速度 4 慢很多"的观感一致，根因就是 16×/8× 这两个乘数。
其余系数（`MultipleFactory=.8`、`WallBuildSpeedCoefficient=3`、低电 0.5～0.8）都是从同一份 rules 读的真值，没有嫌疑。

### 已按确认改成 1（本轮落地）

`runtimeSidebarBuildingProductionSpeedMultiplier` 16→1、`runtimeSidebarProductionSpeedMultiplier` 8→1，
并把 `RuntimeShell.cpp` 里那条把 16/16/8/8 写成**字面量**的契约断言改成读常量（否则下次改常量还会被
自己的冒烟判红）。

改完实测（速度 4，`runtimeGameSpeedTiming` 每 tick 0.0107s）：

| 目标 | totalTicks | 现在 | 正版（同档 / 最快） |
|---|---|---|---|
| 兵营 500 | 630 | **6.72s** | 10.1s / 5.3s |
| 矿场 2000 | 2520 | **26.9s** | 40.3s / 21s |
| 哨戒炮 500（防御） | 630 | **6.72s** | 10.1s / 5.3s |
| 光棱塔 1500 | 1890 | **20.2s** | 30.2s / 15.8s |

各档位（兵营 / 矿场）：速度 0 = 20.2s / 80.6s，速度 3 = 10.1s / 40.3s，**速度 4 = 6.7s / 26.9s**，
速度 5 = 3.4s / 13.4s。速度 4 正好夹在"正版最快"和"正版同档"之间，和录像的秒级节奏对上了。

改完的连带验证：

| 项 | 结果 |
|---|---|
| `--build-smoke-test` | PASS，`sidebarBuildingProductionSpeed=1x sidebarUnitProductionSpeed=1x`，`buildProgress` 4.5ms→56ms（跑满 972 tick，符合预期） |
| `--computer-ai-smoke-test` | 输出与改前**逐字相同**（`structures=36 spent=45800 waves=6`，仍是既有 `attack=no / triggerTeamIsolation=no`）→ 这次改动没有把 AI 节奏带慢 |
| `multiplayer-gameplay-authority` / `multiplayer-house-authority` | 通过（固定 tick、哈希、快照、热恢复全绿） |
| `--skirmish-build-smoke-test` | 红，但**改前改后一字不差**（用 11-12 01:38 的旧 dist 二进制复跑，同样 `option semantics modeRules=no alliesAllowed=no ...`）。根因是数据里没有 `MPMeat/MPFreeForAll/MPTeam/MPUnholy` 这些模式 ini，`skirmishModeRulesLoaded=false`，与本改动无关 |
| 全量回归 | PASS=8 KNOWN-RED=3 RED-NEW=0（与基线一致） |


## 4. 建造/防御"就绪"角标（已实现）

需求：建筑/防御造好后写"就绪"，文字带底色，上方居中，底色**下方两角做圆角**（上两角因为是贴屏顶，
保持直角才像"挂下来的标签"）。

**实现要点**

- 状态：`RuntimeBuildReadyBannerState`（`src/ui/hud/RuntimeBuildReadyBanner.h`）——纯表现，
  不进存档、不进权威哈希、不进回放，和 `playerDefeatNotices` 同一类。
- 触发：`RuntimeSessionProduction.cpp` 的 `PlacementReady` 分支。只有"需要放置"的订单
  （建筑/防御/墙）会发这个事件，所以单位造完不会弹角标。
- 绘制：`src/ui/hud/RuntimeBuildReadyBanner.inl`，挂在 `paint.otherUiOverlays` 里。
  **不用 `RoundRect`**（它会把四个角一起削掉），改成逐行填充：底边往上 `radius` 行按圆的内缩量收窄，
  其余行整宽 → 上直角、下圆角一次成型。
- 动效：130ms 缓降落下 → 停留 1.9s → 180ms 收回；纯时间函数 `runtimeBuildReadyBannerReveal()`，
  可被冒烟逐帧驱动，不依赖真实时钟。
- 美化：深青→墨蓝竖向渐变 + 底部 1px 青色 hem（沿用侧栏 busy 色 `RGB(92,204,236)`）+ 顶部 1px 内缝
  与一行更暗的 bevel + 白字 1px 黑投影；字号 21 加粗（HUD 常规 18 不加粗）。

**验收**（`CONCORD_COMMAND_SMOKE_BUILD_READY_BANNER_ONLY=1 --command-smoke-test`）

```
Build ready banner smoke passed: viewport=732x600 banner=104x36
  centred=yes topFlush=yes topCorners=square bottomCorners=rounded
  textPixels=202 hemPixels=86 slideIn=130ms hold=1900ms slideOut=180ms PASS
```

判据全部从**自己画出来的 DIB 反推包围盒**，不拿 layout 函数算期望值（否则 layout 错时冒烟会一起错）：

1. 未激活 / 起始帧 / 到期后：像素与背景**逐个相同**（一个像素都不许变）；
2. 停留段：包围盒上边 == 视口上边（贴顶）、高度 == 36、不越出视口、水平居中误差 ≤2px；
3. 上两角有底色（直角），下两角是背景（圆角），底边中段填满、底边左起第 1 列必须是背景（收了 ≥1px）；
4. 白字墨迹 ≥20 像素，且左右留白各 ≥8px、上下留白各 ≥3px（居中）；
5. 底部 hem 颜色像素 ≥20；
6. 窄视口（240px）下收窄且仍居中。

**端到端**：`--build-smoke-test` 里加了硬断言——结构 `PlacementReady` 之后
`state.buildReadyBanner.active && itemKey == 该建筑 id`，日志 `readyBanner=yes`。

**回归**：`bash ra2mac_docs/scripts/regress.sh` → PASS=8 KNOWN-RED=3 RED-NEW=0（与基线一致）。

## 5. 那条"16/16/8/8"契约是怎么处理的

第一次把两个常量改成 1 时，`--build-smoke-test` 立刻红：

```
Build smoke test failed: sidebar building, defense, infantry, or vehicle
production did not apply the expected category speed.
```

因为 `RuntimeShell.cpp` 把 16/16/8/8 写成了**字面量契约**：

```cpp
&& sidebarProductionRateAccelerated(*buildingIt, 16)
&& sidebarProductionRateAccelerated(*defenseTimingIt, 16)
&& sidebarProductionRateAccelerated(*infantryTimingIt, 8)
&& sidebarProductionRateAccelerated(*vehicleTimingIt, 8);
```

改成读常量即可，契约保留"侧栏速率 = 创作速率 × 分类乘数"这个语义，只是把乘数变成唯一真值：

```cpp
&& sidebarProductionRateAccelerated(*buildingIt,
       static_cast<std::uint64_t>(runtimeSidebarBuildingProductionSpeedMultiplier))
...
```

这样以后再调节奏只改一处，不会再被自己的冒烟判红。

## 6. 顺手修掉的既有红灯（与本次需求无关）

全量构建里 `tests/ui/main_menu_controller/concord_main_menu_controller_value_contract` 编译失败：
`RuntimeMainMenuServices` 在 Q-04（`8d809dd`）加了纯虚 `reloadEditionResources()`，但测试里的
`Host` 没跟上 → `abstract class is marked 'final'`。补上 `void reloadEditionResources() override` 后
该测试 `checks=224 failures=0`，全量构建 **1613/1613 目标全绿**。

## 7. 证据

- `BUILD-01-就绪角标-停留.bmp` / `BUILD-01-就绪角标-放大.png`（4×，看清圆角与 hem）
- `BUILD-01-就绪角标-下滑中.bmp`（落下中途，顶边已在视口内、底边还没到位）
- `BUILD-01-就绪角标-对局合成预览.png`（**合成图**：角标是真实渲染像素，底图是既有对局截图，
  只为看观感，不作为"已在真实对局里出现"的证据）

## 8. 已确认的决定

1. 16×/8× → **改成 1**（本轮已落地，见 §3）。
2. 角标文案 **保持纯"就绪"**，不带建筑名（与原版 cameo 一致）。
