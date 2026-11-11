# FIX-07 build 冒烟转绿：补己方生产基地 + 低电探针自建前置（第 6 轮）

> 2026-11-12 · 自动化第 6 轮
> 主题：把 `build` 这条从第 1 轮起就常驻 KNOWN-RED 的冒烟清到底。
> 结果：**`build` 首次转 PASS**，回归 `PASS=6 KNOWN-RED=5` → **`PASS=7 KNOWN-RED=4`**，`RED-NEW=0`。

本轮修的两条同属「夹具缺了自己该有的东西」，产品逻辑零改动：一条是世界里没有己方生产基地，
一条是探针自己不建立前置条件。这也是 `build` 连红五轮的真正原因——它一直在冒烟的**前半段**就断了，
后面大半段断言（队列、集结点、电力、侧边栏、放置预览、EVA）从来没被执行过。

---

## 一、M-15 `no unit/infantry catalog item` —— 夹具缺己方生产基地

### 现象

上一轮把 M-14（潜航选择框）修掉后，`build` 推进到「队列一个单位」这一步就终止：

```
Build smoke test failed: no unit/infantry catalog item.
```

### 计量

补了一段只读输出（`64f2c95`）：

```
build catalog: total=46 unit=15 infantry=13 structure=18 credits=199200 power=200/0
  E1        queue=no start=no credits=yes lowPower=no reason="missing InfantryType"
  ENGINEER  queue=no start=no credits=yes lowPower=no reason="missing InfantryType"
  CMIN      queue=no start=no credits=yes lowPower=no reason="missing UnitType"
```

### 根因

钱够、电够、科技等级放行，每条都停在 `runtimeOwnerHasCompatibleFactory`：

```cpp
if (building != nullptr
    && toUpperAsciiTrim(building->factory) == toUpperAsciiTrim(item.requiredFactory)
    && runtimeFactoryOwnerCompatibleWithBuildItem(state, object, item)) { return true; }
```

`reason` 就是 `"missing " + item.requiredFactory`。2peaks 这张零售图 `Structures:10` 全是 Neutral，
玩家没有任何 `Factory=InfantryType`（兵营）或 `Factory=UnitType`（战车工厂）的建筑，
所以 15 个 Unit + 13 个 Infantry 一个都排不了。**这是夹具缺口，不是可用性缺陷。**

### 改法

在队列那一步之前，给夹具注入一栋己方兵营（GAPILE，`Power=-10`）与战车工厂（GAWEAP，`Power=-25`）：

1. 落点必须先避地基——结构锚点是**地基左上角那一格**，所以按 `object.x + width` 判占用，
   用「以地图第一栋建筑为参照、半径 2..24 的环搜」找一块 2x2 空地基；
2. 走 `addRuntimeObjectInstance`（产品创建路径），不手搓 `WorldObjectInstance`——M-11 的教训是
   手搓的结构体会绕过 pose/occupancy，像素画得出来但命中回不到自己；
3. 注入后 `refreshRuntimeObjectOccupancyAfterLocalChange` + `state.projectedObjectsCacheValid = false`。

### 验证

```
Build fixture: injected owned factories=2 owner=Americans
Build result: placed GAPOWR at 64,44 produced E1 objects 29 -> 33 credits=199000 power=200/0 ...
Building queue: structureSecondRejected=yes unitSecondQueued=yes structureSlot=single unitQueue=multi ...
```

队列、生产、信用点边界全部真跑起来了。

---

## 二、M-16 低电探针被自己的前置挡死

### 现象

M-15 修好后 `build` 立刻停在下一条：

```
Build smoke test failed: sidebar low-power integration probe state is not low power.
```

### 根因

`validateRuntimeSidebarLowPowerIntegration` 一进门就要求：

```cpp
if (!runtimeEconomyLowPower(state)) { diagnostic = "probe state is not low power"; return false; }
```

而 `runtimeEconomyLowPower` 判的是 `powerProduced - powerUsed < 0`。这张零售图上玩家没有耗电建筑，
`powerUsed` 恒为 0，刚建好的 GAPOWR 又只贡献 +200，净电永远是正的。**探针永远走不到断言本体**——
它不是失败，是被自己的前置条件挡死了。

### 改法

前置由夹具自己建立，而不是指望环境恰好低电。冒烟侧临时抬高已用电，画完立刻还原：

```cpp
const int savedPowerUsed = state.economy.powerUsed;
state.economy.powerUsed = std::max(savedPowerUsed, state.economy.powerProduced + 50);
const bool ok = validateRuntimeSidebarLowPowerIntegration(state, diagnostic);
state.economy.powerUsed = savedPowerUsed;   // 不许污染后续断言
```

探针本体一个字没改（仍是 `indicators=0/0`、`redPixels=0`、`normalCameos>0` 三条）。

### 验证

```
Sidebar UI: ... power=200/0 net=200 lowPower=no ... lowPowerIndicator=indicators=0/0 redPixels=0 normalCameos=5
Runtime Build Smoke timings: startup=437.02ms ... total=2014.61ms
```

`--build-smoke-test` 退出码 0。这是 `build` 自第 1 轮登记 known-red 以来**第一次真正跑完**。

---

## 三、`result` 记分动画：已拆计量，未修（有意）

### 计量

```
score probe Americans changed=0(need>=1000) tick=300/300 frames=6/6 saved=yes
```

四个子条件里三个正常（tick 没被推进、帧计数 +1、存图成功），只有 `changed=0`：
第二次 `paint()` 拿到的是**同一张画面**。

### 已排除与待查

- 缓存门本身是有的：`reuseCachedFrame` 里明确带 `&& !runtimeResultScoreIsAnimated(*state)`，
  注释也写着「The score SHP animation must redraw even though the terminal world is paused」。
- 所以方向不是「没重绘」，而是「重绘了但记分帧不变」。记分动画的时间源是
  `runtimeUiClockNow(state)`（`state.uiClock->nowMs()`），而冒烟只改
  `state.campaignScore.presentationStartedAtMs`；若 `uiClock` 在冒烟里是冻结时钟，
  两次 paint 拿到同一个 elapsed，条形数自然一样。
- 下一轮先验一件事：`paint()` 之前 `uiClock->nowMs()` 是否可推进；若不可推进，
  是「探针该推进时钟」还是「记分页该按 elapsed 而非绝对时钟取帧」，两种改法不同，不能猜。

---

## 四、回归

| 轮次 | PASS | KNOWN-RED | RED-NEW |
|---|---|---|---|
| 第 6 轮开工基线 | 6 | 5 | 0 |
| 第 6 轮收口 | **7** | **4** | 0 |

唯一变化是 `build` 由 KNOWN-RED 转 PASS，`known-red.tsv` 已删掉该行。
其余四条（`interaction` 右键可见性门、`render` 阴影计量、`command` 两栖卸载、`result` 记分帧）保持原状。

---

## 五、提交清单

| hash | 说明 |
|---|---|
| `9bec677` | docs: 第 6 轮开工（基线 6/5/0） |
| `52bd380` | fix: build 冒烟补己方兵营与战车工厂（M-15） |
| `c90ec0e` | fix: 低电探针由夹具显式建立前置（M-16，**该条转 PASS**） |
| `7f71e72` | test: result 记分动画失配拆四个子条件计量 |
| 本轮收口 | docs: 本报告 + 计划状态；queue: v110 |

## 六、教训

1. **连红五轮的冒烟，先问「它跑到第几段断的」。** `build` 的 11 条已知红记录了五轮「阻塞点后移」，
   但每轮都只推进一小步，原因是它前半段就断了，后面大半段断言从未执行。补上夹具后一次性跑到尾。
2. **探针的前置条件要自己建立。** 「环境恰好低电」不是夹具职责内的假设——零售图没有耗电建筑，
   这条断言等于永远不会执行。凡是断言开头就要求某种状态的，先看那个状态由谁保证。
3. **注入对象的落点是地基左上角那一格。** 按 `object.x` 判占用而不是渲染中心，
   否则 2x2/3x2 的多格建筑会算出重叠地基。
