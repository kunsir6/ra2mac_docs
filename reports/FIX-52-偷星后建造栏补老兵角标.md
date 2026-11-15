# FIX-52 · 偷星后建造栏补老兵角标（第 52 轮，修复轮）

> 轮型：**修复轮**（无 brake / 无 attempts≥3 / 距 AUDIT-51 一轮）。主目标 **M-27**。
> §八.3 比例闸在 AUDIT-51 已解除（近 5 轮 test:0 / fix:1），本轮允许新增断言。

## 一、本轮结论（先看这四行）

1. **M-27 从「从未实现」变成「有绘制点、有像素级判据」**：侧栏建造按钮左下角按 owner×类别显示 chevron。
2. **计划里那条验收条件的数据前提是错的**：M-27 原文写「给兵营设 `veterancy=2`」——产品里**没有**「建筑身上的等级」，
   偷星奖励是 `RuntimeSpySystemState` 上的 `owner × 类别` 布尔（`veteranInfantry/Vehicles/Aircraft`）。
   本轮按真实数据模型改判验收（下文 §三.2），报告标题下不改写原文。
3. 判据不是「代码跑过」，是**逐像素三连比对**：基线 → 拿到奖励 → 清掉奖励，
   `appearedPixels=24 / restoredDiff=0`。
4. 回归 `12/1/0` 不变（13 条，零 RED-NEW），`command` 前缀逐字未变。

## 二、现象与根因

**现象（用户实测）**：兵营、战车工厂偷到敌方建筑拿到老兵等级之后，建造栏里看不到星；玩家无法预判造出来的单位带不带级。

**根因（本轮读代码确认，两条）**：

1. **奖励侧是好的，不需要修**：间谍渗透 `Factory=InfantryType/UnitType/AircraftType` 的建筑后，
   `RuntimeSpySystemState` 会给**渗透方**打上对应类别的 veteran 布尔
   （`RuntimeSpySystem.cpp:804-856`），而造出来的单位在 `applyRuntimeProducedObjectVeterancy`
   （`RuntimeSessionCombat.cpp:243-272`）里正是读这个键决定 `veterancy=1`。也就是说「偷星真的生效了」。
2. **显示侧一个绘制点都没有**：`drawRuntimeSidebar` 的建造按钮循环
   （`RuntimeShell.cpp` 原 20605~20754）只画 cameo / 进度钟 / 就绪文字 / 队列数字 / 低电指示，
   从来不看 veteran 状态。世界视图那头有 `drawRuntimeVeterancyBadge`，但它是给 `RuntimeProjectedObject` 用的，
   与侧栏不同一条路径。**这不是刷新不及时，是从未实现。**

## 三、改法

### 1. 产品（`dba2daf`，单文件 +104 行）

- 新增 `runtimeSidebarItemVeteranProduction(state, item)`：`Infantry→Infantry`、
  `Unit` 且 `runtimeBuildItemUsesPadAircraft` 为真→`Aircraft`、其余 `Unit` 且 `findUnitType("UnitType")` 命中→`Vehicles`、
  其余（建筑 / 防御 / 查不到的条目）返回空——**建筑类不给老兵奖励**，与渗透侧的 `Factory=BuildingType` 分支一致。
- 新增 `runtimeSidebarItemProducesVeterans(state, item)`：把上一步的类别交给
  `state.spies.hasVeteranProduction(runtimeRepairDepotCanonicalOwnerId(state, state.economy.owner), 类别)`，
  **与生产路径同一个键、同一个 owner 归一化**，不新造第二套判定。
- 新增 `drawRuntimeSidebarVeterancyBadge(dc, state, buttonRect)`：取 `pips` 图集的 veteran 帧（8×5 chevron），
  画在按钮**左下角**（右上角被队列数字占着、中心是「就绪」、右下角可能压到进度钟边缘）；
  图集取不到时退化成 14×14 的 `V` 字形，与 `drawRuntimeVeterancyBadge` 同一降级口径。
- 调用点在 cameo 之后、进度钟之前，因此角标不会被遮住，也不会盖住队列数字。

**为什么不能拆出去（§五.3 要求解释 >50 行的单次改动）**：侧栏建造按钮的唯一绘制循环在
`RuntimeShell.cpp` 的 `drawRuntimeSidebar` 里，`src/ui/sidebar/` 下只有页面控制与 pip 条，
没有任何 cameo 绘制入口；而这枚角标要复用定义在同一 TU 后半段的 `runtimeVeterancyPipFrames` /
`loadRuntimeUiShpFrame` / `drawRuntimeUiShpFrameNativeAt`（三者都在匿名命名空间里，跨 TU 拿不到）。
拆成新文件的代价是再复制一份图集解析与降级逻辑，正是 M-19/S-20 那类「第二套实现」的来源。

### 2. 验收条件改判（原 DoD 的数据前提不成立）

原条件：「给兵营设 `veterancy=2` 后重绘侧栏，断言该 build button 的角标区域出现星形像素
（或 `lastSidebarVeterancyBadges == 2`），且等级回落后角标消失。」

按 §八.2 记**断言纠正**：产品里没有「建筑身上的 veteran 等级」这个字段，偷星是 owner×类别；
若照原文去给建筑设 `veterancy`，测的是夹具自己编出来的状态（M-29/M-30 两次同型）。
改判为：**同一条 cameo 的角标区域，在「拿到间谍老兵生产」时必须变、在「清掉」时必须逐像素回到基线**。

### 3. 判据（`b08e13c`，单文件 +111 行，进 `RuntimeBuildingReadySmoke`）

三连渲染，裁剪 infantry cameo 左下角 **18×18**：

| 步骤 | 动作 | 期望 |
|---|---|---|
| ① 基线 | `state.spies` 干净 | 得到 `baseline` 像素块 |
| ② 拿到奖励 | 间谍系统自己的 `save/load` 格式写入 `VeteranMask=1` | `appearedPixels > 0` |
| ③ 清掉奖励 | `OwnerCount=0` 重载 | `restoredDiff == 0`（逐像素等于 ①） |

实测输出：

```
Sidebar veteran badge: cameo=E1 appearedPixels=24 restoredDiff=0
```

24 像素 = 8×5 chevron 的非透明部分，说明走的是 **pips 图集**那条路，不是 `V` 字形兜底。

两个夹具细节（都是被前几轮教训逼出来的）：
- **兵营用产品路径注入**（`addRuntimeObjectInstanceForOwner` + `refreshRuntimeObjectOccupancyAfterLocalChange`），
  不是手搓 `WorldObjectInstance`——M-11 见过手搓实例「画得出但点不到」。
  侧栏步兵页按「有对应工厂」过滤，而这条夹具的基地只有一座部署好的 MCV，不注入则步兵页是空的（本轮第一版就撞在这里）。
- **veteran 标志用间谍系统自己的 `load()` 写**，不新增「测试专用 setter」：格式是产品自己的存档格式，
  格式漂了这条会以 `spy veteran fixture rejected` 明确报错，而不是静默变绿。

## 四、验证

- **目标断言**：`CONCORD_COMMAND_SMOKE_BUILDING_READY_ONLY=1 --command-smoke-test` → `rc=0`，
  打出上面那行读数。
- **整批回归**：`bash ra2mac_docs/scripts/regress.sh` → `PASS=12 KNOWN-RED=1 RED-NEW=0`（13 条），
  `command` 的失败前缀逐字未变；`compactgroups` 13/13。
- **包内冒烟**：`--smoke-test` 原生 rc=0、`arch -x86_64 … --smoke-test` rc=0。

## 五、质量四数

| 指标 | 数值 |
|---|---|
| 本轮净增行数 | **+215**（产品 +104 / 断言 +111，删除 0） |
| 最大单文件 | `RuntimeShell.cpp` 90,611 → **90,715**（+104）；`RuntimeMapRenderer.cpp` 42,542（持平）；`RuntimeSessionWorld.cpp` 30,794（持平） |
| 断言 vs 产品代码 | 新增断言 **1 组三连比对**（3 个谓词）/ 产品 +104 行 |
| TODO/FIXME | 0 → 0 |

## 六、清单体检

- `fix-plan.md` 339 → 341 行（≤400）；条目新增 0（M-27 原地转完成，等价替换不触发）；
  queue 34 条、61KB→63KB、rules 5 类 12 键；`ledger-check.sh` 十项全绿。
- 悬空引用：新增报告 1 条，已落在 docs HEAD 内（本轮 docs commit）。
- 状态矛盾：M-27 计划/队列两侧同步转 `done`（R51 刚记过「交付后两侧没回写」的教训）。
- **顺带清掉一处重复**：`已完成` 段落尾部 `04e366d` / `1563d7a` 两条与下一段「更早 9 条」逐字重复（AUDIT-51 记过但只修了别处），本轮删掉尾部那份。

## 七、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做**
- 精英（elite）三级角标：偷星只授予 veteran（1 级），数据层没有「 infiltrate 两次变精英」这条路，
  不凭想象加第三种图标。真要做，先确认零售是否叠星。
- `runtimeCountryGrantsVeterancy`（国家自带老兵）不参与角标：那是 rules 阵营属性，不是「偷星」，
  一起点亮会让一开局满屏星（用户报的是偷星这一路）。
- U-19/U-20/U-21/U-23 的真实窗口取证（AUDIT-51 已指出门开了），仍欠一轮合并取证。

**遗留债**
- 这条判据现在只在 `CONCORD_COMMAND_SMOKE_BUILDING_READY_ONLY` 子冒烟里，**没进 regress**
  （regress 13 条仍是那 13 条）。要不要接成第 14 条，得先量它单跑耗时（本轮实测 ~1.4s，够便宜）。
  按 R43 的教训，接入前先确认它现在是绿的——是绿的。
- `RuntimeBuildingReadySmoke.inl` 现在同时承担「建造就绪状态机」与「侧栏角标渲染」两件事，111 行是净增；
  若将来再加渲染类断言，应先把它拆成两个子冒烟。
- 并发会话在 `RuntimeShell.cpp` 仍有 41 行未提交 WIP（本轮只按 hunk 提交自己的 3 段，未触碰）；
  dist 里的二进制**包含那 41 行**，stamp 已标 `wip=concurrent(11)`。

**放弃**
- 放弃「给建筑加 `veterancy` 字段」这条看似更贴原文的路：那会让一个只在渗透时产生的 owner 级状态
  复制到每栋建筑上，还要处理拆建、换主、存档迁移，收益只有「更贴合一句写错的验收条件」。
