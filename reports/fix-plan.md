# 问题修复计划（fix-plan）

> 用途：本项目「待修复问题」的唯一台账。每轮开工先核对本表，收工前回写状态。
> 维护规则：
> 1. 新问题一律先登记再动手，登记必须写清「根因假设」，根因未明只允许登记为「只读计量」类任务。
> 2. 修复完成 → 状态改「已完成」并填关联报告；证明不成立/场景消失 → 改「已废弃」并写原因。
> 3. 复杂度一旦被实测推翻（改到第二个模块去），必须回来改分级并写原因，不许留在原批里硬啃。
>
> 分级口径：
> - **简单**：改动局部（单文件或单函数族）、根因已由日志/断言直接指认、与他项无耦合、可独立 revert。
> - **中等**：单模块内多文件、或需要新增只读计量才能定性；失败可整块回退。
> - **复杂**：跨模块 / 需重构 / 触及呈现层或输入链路架构；单独成轮，先写方案再动手。
>
> 性价比排序：S（半天内可见用户价值）＞A（清掉一条 known-red 或解掉一类卡点）＞B（体验打磨）＞C（基建/可观测性，回报延迟）。
>
> 最近更新：2026-11-12 12:12（第 10 轮开工：基线 **8/3/0**（`20261112-120122`）。
> **本轮第一发现：known-red 行正在掩盖新回归**。`ffdd7c5`（10:42，BUILD-03 速度阶梯）把 6 档从
> 「零等待哨兵」改成 5 档 ×1.5=281 拍/秒，但 interaction 冒烟里两张节奏表仍钉着 `speed6 → 0`，
> 于是 ESC 菜单断言先红（`gameSpeedSlider=geometry:yes/coord:no/pacing:no/drag:yes/kbd:yes`）。
> interaction 本来就是 known-red，`regress.sh` 不会报 RED-NEW；且该断言在 `RuntimeShell.cpp:38131`，
> 排在 footprint 命中（40422）**之前** → **M-12 这一轮根本测不到**。登记 S-11 修掉这道假门。）
>
> 第 9 轮收口：基线 **8/3/0** → **8/3/0**，零新回归。
> **M-18 定性翻案**：建筑投影不是产品缺陷，是门禁在自己的帧里看不见建筑——ore 探针把镜头
> 居中到「无 overlay 的空地」（探针判据本身就是没盖东西），同一帧要 `structureShadowsDrawn>0`
> 构造性不可能。M-20 四桶计量给出 `structureOff=2/empty=0`，自证帧第一栋 `CAAIRP` 即
> 13551 像素。`render` 仍红，阻塞点后移到 M-21（矿喷发动画，改前逐字相同）。
> 第 8 轮 08:29 的并发改动（建造就绪角标）其主人已提交（`7afbc54`/`2cb8364`/`4acf858`））

---

## 一、待修复 —— 简单（可打包批量修）

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | 状态 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|
| S-01 | 被动索敌会锁定建筑 | 空闲/攻击移动的单位在没有玩家命令时会自己跑去打敌方建筑（含武装防御塔），越过前线追塔 | `advanceRuntimeGuardBehavior` 的候选桶未按 `WorldObjectKind` 过滤，建筑与可移动目标同桶 | 高：直接改变对战手感，零售语义是「被动只打可移动目标」 | 1 行过滤 + 冒烟 | **S** | 简单 | 已完成（本批） | `reports/FIX-01-索敌策略与编队编号.md` |
| S-02 | 单位受伤不还手 | 坦克被光棱塔/电场打到只会原地挨打，必须玩家下命令才还击 | 伤害路径只调 `beginRuntimePanic`（平民逃跑），没有「CanRetaliate」分支 | 高：战场反馈最直观的一条 | 新增 1 函数 + 伤害点接线 | **S** | 简单 | 已完成（本批） | 同上 |
| S-03 | 选中单位不显示编队编号 | Ctrl+数字编队已生效（U-07），但选中后画面上看不到属于第几队 | 只有编队写入，没有绘制路径；`RuntimeWindowState` 也没有对应计数器 | 中高：编队可用性的最后一公里 | 1 绘制函数 + overlay 调用点 | **S** | 简单 | 已完成（本批） | 同上 |
| S-04 | interaction 夹具缺己方建筑 | repair cursor 断言永远拿不到 owner 匹配的建筑，`interaction` 常驻 KNOWN-RED | 冒烟夹具只放 Neutral 建筑，断言（RuntimeShell.cpp 要求 `owner==economy.owner`）永远不成立 | 中：清掉 1 条 known-red，恢复该条回归的信号价值 | 夹具注入 1 栋己方建筑 | **A** | 简单 | 已完成（第 2 轮 e1dede3；后续阻塞点后移到 M-10） | `reports/FIX-03-回归门禁口径三连.md` |
| S-05 | campaign gate 按现定义永不绿 | 40 任务里 13 个 `Map=` 为空 + Bink 视频缺失，断言要求全量覆盖 | 断言口径错：把「资产缺口」当成「产品缺陷」判红 | 中：清掉 1 条 known-red（该条已判 env-gap） | 改白名单 + 保留缺口计数打印 | **A** | 简单 | 已完成（第 2 轮 cd2e841，**该条转 PASS**） | `reports/FIX-03-回归门禁口径三连.md` |
| S-06 | render 阴影只读计量 | `structuresShadowsDrawn=0`，但 SHP 解析正常（shp=5），分不清是相机可见性还是阴影帧解析 | 未区分「不在视口」与「解析失败」 | 中：为 S-07 定性提供唯一判据 | 加 3 个只读计数 | **B** | 简单 | 已完成（`06c8ea2`，计量已出结论，**修复拆到 M-18**） | `reports/FIX-08-时钟纪元与建筑零投影.md` §2 |
| S-07 | result 记分动画只读计量 | 暂停态第二次 WM_PAINT 走 `reuseCachedFrame`，记分不前进 | 疑似平台相关（Windows 侧历史绿），需先证明缓存命中 | 中：同上，先计量再定性 | 加缓存命中计数 | **B** | 简单 | 已废弃（并入 M-17；缓存命中假设已被证伪，真因是时钟纪元） | `reports/FIX-08-时钟纪元与建筑零投影.md` §1 |
| S-08 | EVO-06 世界重绘只读计量 | 帧循环每 tick 无条件 `InvalidateRect`+`UpdateWindow`，不知多少次真改了画面 | 无计量 | 中：为「脏区驱动」提供基线数字 | 加 tick 内画面变更计数 | **B** | 简单 | 待修复（与 M-03 同源，落地时合并） | `reports/ON-2-前排任务现状对账.md` |
| S-09 | FPS 叠加层默认常显（U-17） | 每次提交帧后无条件画左下 96×22 `FPS: 60` 面板，正式版没有这个面板 | 该面板只为自测而加，`drawRuntimeFpsDisplay` 的三个调用点没有任何开关；`RuntimeMainFrameContract` 只断言面板**矩形**存在，不断言「画了」 | 高：正式版观感的第一眼硬伤，纯视觉、无模拟耦合 | 加 1 个偏好位 + 3 处调用点门控（`--show-fps` / `[Options] ShowFps`） | **S** | 简单 | 已完成（`c1ccfe6`） | `reports/FIX-05-夹具缺口与FPS叠加层.md` |
| S-10 | 启动日志把零售自带的重复建筑 id 报成异常 | 每次启动 `core` 都打印 `Duplicate building id ignored by capability index: [NAPSYA]` | 零售 `rulesmd.ini` 的 `[BuildingTypes]` 里 `NAPSYA` 确实出现两次（185 / 241），`rebuildTypeIndex` 按「重复即告警」处理，但「先到先得」正是零售语义（两处指向同一 section），不是数据损坏。告警缺 item 下标，也没区分 `Corrupt` 与 `Duplicate` 两种性质 | 低中：日志噪声，且会掩埋真正的解析重复 | 1 处消息分级（带 item 下标 + 降为 data-note） | **C** | 简单 | 已完成（`5ce280b`） | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §3 |

> **简单区现状（第 10 轮核对）**：S-01~S-10 全部已完成或已废弃，只剩 S-08（与 M-03 同源，须合并做）。
> 第 10 轮新登记 S-11，性质是「别人改了产品语义、断言没跟上」，属典型简单批（两文件、根因由断言输出直接指认）。

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | 状态 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|
| S-11 | 速度阶梯改了，两处断言表还在钉旧哨兵 | interaction 的 ESC 菜单断言红在 `gameSpeedSlider`；`gameSpeedSlider=yes/no/no/yes/yes` → 几何/拖拽/键盘三组绿，**坐标组与全局节奏组红**。support-power 冒烟同样在 `initialRate != 0` 上判 fail | **已定性：断言表过期，不是产品缺陷**。`ffdd7c5` 把 7 档改为 31/37.5/46.88/62.5/93.75/187.5/281.25（6 档 = 5 档×1.5，`unlimited()` 恒 false）；`RuntimeShell.cpp:37667` 仍写 `== 0`、`expectedGameSpeedPacing` 末位仍写 `0`、`RuntimeSupportPowerSmoke.inl` 仍留 `initiallyUncapped/changedUncapped` 两支 | 高：它挡在 interaction 冒烟**靠前**的 ESC 菜单段，不清掉 M-12 永远测不到；清掉后该条才有信号价值 | 两文件共 ~15 行：两张表末位改 281、拆掉 uncapped 分支 | **S** | 简单 | 第 10 轮修复 |

## 二、待修复 —— 中等
|---|---|---|---|---|---|---|---|---|---|
| M-01 | EVO-08 compat 实现 CP1252 解码 | 零售 `Text=` 的智能标点（0x85/0x91…）被逐字节 widen 成控制字符，`build` 条常驻红 | compat 只有 UTF-8 分支，CP1252 直接返回 0 | 高：影响所有零售文本（含 EVA 字幕） | 编码表 + 请求路由 | **A** | 中等 | 已完成（FIX-02） | `reports/FIX-02-CP1252解码.md` |
| M-02 | ON-4-07 box selection 与投影不一致 | 框选结果和画面上框住的单位对不上 | 框选用世界坐标，投影用表面坐标，两套换算未对齐 | 中高：操作手感 | 换算对齐 + 断言 | **A** | 中等 | 待修复 | — |
| M-03 | ON-2-06 世界 idle 空转重绘 | 静止时也每 tick 全量重绘，CPU/功耗浪费 | 无脏区判定 | 中：功耗与风扇 | 脏区集合 + 提交条件 | **B** | 中等 | 待修复 | `reports/ON-4-04-性能基线.md` |
| M-04 | ON-2-02b 提交节奏对齐显示刷新 | 帧提交与 60Hz 不同步，偶发丢帧/撕裂 | 用定时器而非 display link | 中 | 需接 CVDisplayLink | **B** | 中等 | 待修复 | `reports/ON-2-02a-呈现节奏计量与主人帧修复.md` |
| M-05 | EVO-13 尤里复仇战役未接入 | 战役菜单只有基础版 ra2 任务 | 战役数据库只装了 ra2 的 mission 表 | 中高：资料片内容缺失 | 数据层接入 + 校验 | **B** | 中等 | 待修复 | `reports/Q-04-RA2与YR拆分盘点.md` |
| M-06 | EVO-04 日志与崩溃现场落地 | 崩溃后没有现场，只能靠重跑 | 无统一日志出口 | 中：排障效率 | 日志出口 + zip 收集 | **C** | 中等 | 待修复 | — |
| M-07 | EVO-03 diagnostics 驱动入口 | 无人值守走不完 菜单→大厅→载入→世界（autostart 钩子已删） | 缺一个脚本化入口 | 中：自动化上限 | 新增 CLI 驱动 | **C** | 中等 | 待修复 | — |
| M-08 | `build` 的 MCI 音乐探针口径 | CP1252 修好后 `build` 停在新阻塞 `mci=error-306`，整条条红 | macOS 无 MCI 后端；探针把「平台缺口」当「产品缺陷」判红（同 campaign 的 Bink） | 中：清掉 `build` 的剩余红，恢复该条信号价值 | 探针改 skip + 打印 `skipped(no MCI backend)` | **A** | 简单 | 已完成（第 2 轮 933d70c；后续阻塞点后移到 M-09） | `reports/FIX-03-回归门禁口径三连.md` |
| M-09 | `build` 建筑健康条比选择框高 2px | 健康条 `actual=61x33`，断言 `expected=61x31`（宽一致、分段 14/14 正常、无限血已正确隐藏） | **已定性：公式旧**。断言按「水平条」算高度（`+1`），实际血条贴冠顶**斜边**排布，包围盒 = 斜边竖直跨度(30) + 冠顶间隙(3) = 33 | 中：清掉 build 第 2 个阻塞点 | 1 处公式 + 常量共享 | **A** | 中等 | 已完成（`0e99bc1`；build 停在 M-11） | `reports/FIX-04-两条断言的几何口径.md` |
| M-10 | interaction 南向相机极值裸露 | 8 个钳制极值里只有 `S` 一项 `tile=398/625..458/655:no`：最南一行在视口底(640)以下被切 15px；`corners` 同时判红；void 全 0 | **已定性：实现是对的**。物理地图边缘的 reveal 预留被有意做成 −halfTile（相机提前半格停，把锯齿黑边留在客户区外）；错的是「极值 cell 必须完整可见」这条断言，与 `physicalMapEdgeCovered` 直接矛盾。钳到 0 后 void 立刻 0.012/856px，反证策略必要性 | 中：清掉 interaction 第 2 个阻塞点 | 允许溢出量 = 该方向负预留 | **A** | 中等 | 已完成（`469cfa8`；interaction 停在 M-12） | `reports/FIX-04-两条断言的几何口径.md` |
| M-11 | `build` 悬停血条找不到单位 | 血条断言转绿后，`build` 停在新阻塞 `no unit available for hover health bar`：夹具世界里只有建筑与地形，没有可悬停的单位 | **已定性：夹具缺口**。默认图 `Units=0`；且必须用 `addRuntimeObjectInstance` 生成（手搓结构体会绕过 pose/`hasRenderPosition`，像素画得出来但命中回不到自己），落点还要保证「自身包围盒中心命中回自己」 | 中：清掉 `build` 第 3 个阻塞点 | 注入 1 台己方 MTNK + 环型找落点 + 探针后按 id 摘掉 | **A** | 简单 | 已完成（`0ce035a`；build 停在 M-14） | `reports/FIX-05-夹具缺口与FPS叠加层.md` |
| M-12 | interaction 建筑「画得出、点不到」 | `structure footprint hit mismatch`。**原描述（命中框 vs 地基口径）已被计量推翻**：cells=4/4、hash 相同、preview/hit/footprint 三矩形逐边相等、bounds 覆盖 footprint，5 组谓词只剩 `rightClickMatches`，且目标为 `nullptr`（不是打到别的建筑） | **已收窄未定性**：命中点 (1043,73) 上只有 `CABUNK02` 一个候选，`structureSpriteHitSpans` 含该像素但 depth-visible spans 不含，被 `buildingPixelVisible` 拦下后整条对象被 `continue`，该像素无人顶替。剩两种可能：①真被别的对象挡住（应返回挡它的那个）②深度重放把这只 bunker 前墙误判不可见（可见性门错杀）。两者改法相反，不能猜 | 中：清掉 interaction 最后一个阻塞点，直接改善建筑点选手感 | 再一档计量（该像素上所有 spans 命中者的 depthVis 清单）→ 定性 → 单点修 | **A** | 中等 | 待修复（已计量收窄，`799c9b6`；**故意不动命中逻辑**）。第 10 轮补充：**当前测不到**——ESC 菜单断言（`RuntimeShell.cpp:38131`）排在其前且被 S-11 判红，S-11 修完才轮到它 | `reports/FIX-06-选择框与命中框的两条口径.md` §2 |
| M-13 | 真实遭遇战开局取证通道（U-18 + EVO-03 合流） | `--skip-skirmish-menu` 进的是战役图 `2peaks.map`（`Units:0 / Structures:10 / Players:1`），出图里没有基地车与己方建筑，游戏内 HUD 整块没有可信对照物 | skip 路径没有走遭遇战 bootstrap，而是直接吃 `DefaultMap`；`--skirmish-build-smoke-test` 报 `modeRules=no alliesAllowed=no` 也说明它没经过大厅配置 | 高：它是 U-19/U-20/U-22 的前置，不打通则整个 HUD 对账无法判定 | 中等偏高：要么让 skip 路径构造标准遭遇战 setup，要么换默认多人图 + 补 owner 注入；两条都要动启动路径 | **A** | 中等（与 M-07 同源，落地时优先合并） | 待修复（UI-01 登记） | `reports/UI-01-正式版观感对账.md` §3.2 |
| M-14 | `build` 移动帧选择框不覆盖可见身体 | 推进到第 4 个阻塞：`DLPH=43x25/43x25 aligned=no`（尺寸相同却不同过）、`SQD=92x51/100x41 aligned=no`（移动帧 sprite 变矮变宽）；MTNK/DEST/ZEP/ENGINEER 全绿 | 未明，两种成因必须切开：①尺寸谓词（`selectionBounds` 是否该锁固定尺寸）②锚点谓词（潜航 `renderCenter.y - center.y == tileHeight/2`、`pointInRectInclusive(bounds, selectionCenter)`）。DLPH 尺寸相等即指向 ② | 中：清掉 `build` 第 4 个阻塞点 | 先加只读计量（三个谓词分别计数）再定性 | **A** | 中等 | 已完成（`d2f36b3`；根因是断言公式，非产品） | `reports/FIX-06-选择框与命中框的两条口径.md` §1 |
| M-15 | `build` 队列单位时目录全不可排队 | M-14 断言转绿后暴露：`no unit/infantry catalog item`，找不到任一 `canQueue` 的 Unit/Infantry | **已定性：夹具缺口**。计量：total=46 unit=15 infantry=13 structure=18 credits=199200 power=200/0，全部 `reason="missing InfantryType"/"missing UnitType"`——钱/电/科技都放行，卡在 `runtimeOwnerHasCompatibleFactory`，即世界里没有己方生产基地（2peaks 的 `Structures:10` 全 Neutral）。与 M-11 同类 | 中：清掉 `build` 当前阻塞点 | 注入 1 栋己方兵营 + 1 栋己方战车工厂（`addRuntimeObjectInstance` + `refreshRuntimeObjectOccupancyAfterLocalChange`），落点避地基；改完要重跑整条 build（后面还有队列重排/取消/集结点断言） | **A** | 简单 | 已完成（`52bd380`；build 越过了队列/生产这一段） | `reports/FIX-07-build冒烟转绿.md` §1 |
| M-16 | `build` 低电探针被自己的前置挡死 | `sidebar low-power integration probe state is not low power`，探针一进门就要求 `runtimeEconomyLowPower`，而零售图没有耗电建筑（powerUsed 恒 0），净电永远为正 | **已定性：前置无人保证**。`runtimeEconomyLowPower` 判 `produced - used < 0`，探针走不到断言本体，属夹具职责缺位而非产品缺陷 | 高：它是 `build` 转 PASS 的最后一道门 | 冒烟侧临时抬高 powerUsed 再还原（3 行） | **S** | 简单 | 已完成（`c90ec0e`；**build 整条转 PASS**） | `reports/FIX-07-build冒烟转绿.md` §2 |
| M-17 | `result` 记分动画两次 paint 出同一张画面 | `original score animation stalled behind paused-frame cache`；计量 `changed=0 tick=300/300 frames=6/6 saved=yes`，三个子条件正常，只有画面没变 | **已定性：两个时钟纪元相减**。记分页取 `runtimeUiClockNow()`（macOS = `CLOCK_MONOTONIC`），而探针用 `GetTickCount64()` 写起点；两个纪元在 macOS 上不同 → `now - start` 恒为巨大值 → `runtimeUiScoreElapsed` 两次都钳到末帧 → 两张图逐像素相同。已排除缓存（门里带 `!runtimeResultScoreIsAnimated`） | 中：结算页动画是用户可见的一段 | 探针改用 `runtimeUiClockNow` 作基准（产品零改动） | **B** | 简单 | 已完成（`4cdc891`，**该条转 PASS**） | `reports/FIX-08-时钟纪元与建筑零投影.md` §1 |
| M-18 | 建筑完全不投影（`render` 的真红） | 自然地图阴影 `candidates=7 drawn=5 shp=5` 但 `structures=0`；`structureCand=2 structureEmpty=2`——两个候选进了地面阴影通道、掩码「解析成功」，却一个像素都没压暗 | **仍未定性，但排除了一条**：第 8 轮加 `CONCORD_SHADOW_TRACE` + 第三桶 `structureNoArt` 后，测得自然地图上确实存在 0×0 的 `NATBNK`（`NewTheater` 只有 `art/snow` 变体，图为 TEMPERATE），但 `structureNoArt=0` 而 `structureEmpty=2`，**记录侧那两个候选不是空体建筑**，故「资产缺口」解释不成立。剩下的可疑路径：①帧矩形与 viewport 不相交/裁剪到零宽时 `drawRuntimeVoxelShadowMask` 也 `return true` + 0 像素 ②span 生成空 | 高：建筑没有影子是画面硬伤 | 下一步很便宜：在 `recordRuntimeWorldObjectShadowResult` 里打印 type/instance/rect/intersects（追踪要打在记录点才能与汇总对上），一次构建即可裁定 ①/② | **A** | 中等 | 已定性并修门禁（`8b14b61`）：**非产品缺陷**。帧被 ore 探针居中到无 overlay 空地，建筑必在视口外；自证帧 `CAAIRP` = `drawn=4 pixels=13551` | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §2 |
| M-19 | 自然地图上的 `NATBNK` 没有 temperate 美术 | `body=0x0 frame=0x0 nonzero=0 globalH=126`，`Structure sprites: 2 loaded, 0 missing` 却什么都画不出来；`render` 的 trace 里反复出现同一实例 | **已定性：资产缺口**。`artmd.ini [NATBNK] NewTheater=yes`，导出集只有 `mix_exports/art/snow/natbnk.shp`（与 `_b`），`2peaks.map` 是 TEMPERATE | 中：任何「建筑可见/可点/有影子」的断言在该图上是不可满足的，先把这个洞标出来 | 资产侧：补 temperate 变体，或让冒烟换一张带可加载建筑的图 | **C** | 简单 | 待修复（不再阻塞任何门禁：`CAAIRP` 已能投影，降为画面完整性待办） | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §2 |
| M-20 | 离屏帧被记成「空掩码」 | `drawRuntimeVoxelShadowMask` 在 `!rectIntersects(imageRect, viewport)` 与 `clippedStartX >= clippedEndX` 两处直接 `return true`，`darkenedPixels` 保持 0，调用方看到的是「掩码解析成功但没压暗」 | **待验**：返回值同时承担「掩码有效」与「画了」两种语义，离屏/裁剪路径在统计上与真正的空掩码不可区分；`CAOILD` trace 已实测 `intersects=0` 走的就是这条 | 中：它可能是 M-18 的真因，也可能只是让 M-18 的读数失真的旁证 | 小：`drawRuntimeVoxelShadowMask` 增一个「是否真的落在视口内」的输出位，调用方据此分开计数 | **A** | 简单（实测后降级：一个函数 + 1 个 out 参数） | 已完成（`dd6eb31`）：读数由 `empty=2` 变 `off=2/empty=0` | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §1 |
| M-21 | `render` 矿喷发动画未被判为「已画」 | `oreGrowthSpawnerAnimationDrawn=false frames=11`，而 `ran/changed/ring=1/overlay` 全绿；被阴影门禁屏蔽 6 轮，第 9 轮门禁拆开后才露出来（改前基线日志逐字相同） | 未明：`frames=11` 说明帧号在推进，两种可能——①动画层数为 0（没进绘制循环）②层在但压暗像素为 0（同 M-18 的返回值语义问题，现已可分流） | 中：清掉 `render` 当前阻塞点 | 先看 `oreGrowthSpawnerAnimationDrawn` 的置位处（`RuntimeShell.cpp` ~34960 上游），再决定加计量还是直接修 | **A** | 中等 | 待修复（第 9 轮登记） | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §5 |

## 三、待修复 —— 复杂（单独成轮）

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | 状态 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|
| C-01 | EVO-15 事件分发接 `sendEvent` | 不走 `[NSApp sendEvent:]`，导致 cursor rect 全失效、`isActive`/`isKeyWindow` 恒 0、tracking area 不回放 | 主循环自建 `nextEventMatchingMask` 分发，绕开 AppKit 正规路径 | 高：一次性修好一类系统级交互 | 高：改主循环 + 回归全部输入断言 | **A** | 复杂 | 待修复 | 见 `MEMORY` 中「本项目不调 sendEvent」条目 |
| C-02 | EVO-09 两栖卸载卸不下坦克 | 船靠岸二次动作后 `transportPassengerIds` 仍非空 | 纯合成夹具、两次同点失败，疑共享模拟缺陷，需 Windows 基线对照 | 中 | 高：需对照基线 | **B** | 复杂 | 待修复 | `reports/EVO-02-红基线分诊.md` |
| C-03 | EVO-05 存档/读档真机往返 | 无存读档往返验证 | 未实现 | 高 | 高 | **B** | 复杂 | 待修复 | — |
| C-04 | EVO-14 全屏原生分辨率渲染 | 呈现表面跟随窗口，而不是放大 800x600 | U-14 已把「客户区尺寸」交给游戏，剩余是表面重建与缩放策略 | 中 | 中高 | **B** | 复杂 | 待修复（U-14 已吃掉一半） | `reports/U-14-全屏等于更大视口.md` |

## 四、已完成 / 已废弃（核对结果）

| 条目 | 结论 | 依据 |
|---|---|---|
| U-07 Ctrl+数字编队 | 已完成 | 绑定层与消息循环双断言；本表 S-03 是其显示侧补齐 |
| U-09/U-12/U-13 全屏 | 已完成，U-13 判断已被 U-14 推翻 | `reports/U-14-全屏等于更大视口.md` |
| U-14 全屏=更大视口 | 已完成 | 同上；残余见 C-04 |
| U-16 最低系统版本 12.0 | 已完成 | `pack-dist.sh` 已加 minos/plist 门禁 |
| EVO-16 遭遇战 AI 默认开启 | 已完成 | `reports/EVO-16-遭遇战AI默认开启.md` |
| EVO-17 建造完成闪烁 | 已完成 | `reports/EVO-17-建造完成侧边栏闪烁.md` |
| L10N-01/02/03 界面简中化、字形、红叉 | 已完成 | `reports/L10N-*.md` |
| ON-2-01 呈现缓存（去掉每帧 CGImageCreate） | **已废弃**（方向被证伪） | 「不能缓存 CGImage」的结论本身成立，但当时的方案（按指针+尺寸缓存）会冻帧，见 `reports/ON-2-01-呈现缓存否定报告.md` |
| ON-5-02b 30 分钟存活 | 待修复（仍是 pending，属长时间人肉验收，不占本轮） | — |

---

## 五、本轮（2026-11-12 第 10 轮）打包清单

主题：**先修那道「假门」**。基线 `PASS=8 KNOWN-RED=3 RED-NEW=0`（`20261112-120122`），与第 9 轮收口一致；
但交互条的红点已经从 M-12 前移到 ESC 菜单——`ffdd7c5` 改速度阶梯时漏改两张断言表。

- S-11（简单，本批）：见 §一。
- M-21（中等，本批第二条，视余量）：`render` 矿喷发动画 `anim=no/frames=11`。

## 五-旧、第 9 轮（2026-11-12）打包清单（存档）

主题：**把「掩码有效」与「真的画了」分开**。S-10（日志分级）+ M-20（返回值语义）+ M-18
（定性收口），一次构建、一次回归。报告 `reports/FIX-10-阴影掩码四桶与结构自证帧.md`。

- **S-10 → 已完成（`5ce280b`，简单）**：逐条重复告警聚合成一条 `data-note`，带首次出现的
  item 下标；`Corrupt` 仍单独报。`core` 输出从 1 条噪声变成 1 条可读事实。
- **M-20 → 已完成（`dd6eb31`，实测后重分级为简单）**：`drawRuntimeVoxelShadowMask` 的 `bool`
  兼作「有效/已画」，离屏与裁剪两条路都 `return true` 且 `darkenedPixels=0`。改为可选
  `RuntimeShadowMaskOutcome`，结构阴影从 3 桶改 4 桶（`structureOff`/`structureClip`），
  读数由 `empty=2` 变为 `off=2/empty=0`。
- **M-18 → 已定性并修复门禁（`8b14b61`）**：**不是产品缺陷**。该帧被 ore 探针居中到一排
  「无 overlay 的空地」，建筑必然在视口外；`structureShadowsDrawn>0` 与其取景互斥。
  拆除该条到独立的「自证帧」：逐栋建筑对焦、独立 DIB/缓存，搜到第一栋真的压暗为止
  （缺剧场美术的建筑合法地不投影，不能混进管线判据）。`focus=CAAIRP` 即 `drawn=4 pixels=13551`。
- **M-19 → 状态不变（资产缺口，不再阻塞）**：`CAAIRP` 能投影后，NATBNK 的 temperate 缺图
  不再影响任何门禁判定，降级为「画面完整性」待办。

回归：`PASS=8 KNOWN-RED=3` → **`PASS=8 KNOWN-RED=3`**，`RED-NEW=0`（`20261112-101458`）。
`render` 仍红，但**阻塞点后移到 M-21**（矿喷发动画 `anim=no/frames=11`，改前基线逐字相同）。

移出本批：无。新登记 **M-21**（矿喷发动画未被判为已画，中等）。

下一轮起手：**M-21**——先看 `oreGrowthSpawnerAnimationDrawn` 的置位处，分辨「动画层数 0」
还是「层在但像素 0」；其次 **M-12**（右键命中的可见性门）。

## 五-旧、第 8 轮（2026-11-12）打包清单（存档）

主题：**一次被自己的计数器否决的定性**。简单区已清空（见 §一 说明），本轮按「一条中等单独成轮」
取 M-18（`render` 建筑零投影）——先拆掩码侧四元组，结果把上一轮的结论拆出了一个新的候选成因，
也拆出了一个差点写错的结论。

- **M-18 → 仍未定性，但排除了一条**（`c66d2f6`）：`CONCORD_SHADOW_TRACE=1` 打印
  body/frame 尺寸、掩码非零像素、阴影帧屏幕矩形与 `intersects`。发现两件事：
  ① 自然地图上确有 0×0 的 `NATBNK`（`NewTheater` 只有 `art/snow`，图为 TEMPERATE）——真资产缺口；
  ② 但新增第三桶后 `structureNoArt=0` 而 `structureEmpty=2`，**记录在这两个桶里的候选不是空体建筑**，
  追踪打印的绘制调用与统计记录的不是同一批 → 「资产缺口」解释不成立。
- **中途的自我否决**：曾实现过一版门禁分级（`emptyBodies == candidates` 时判资产缺口并放行），
  能让 `render` 立刻变绿，但它的前提正是被 `structureNoArt=0` 否掉的那条，绿只是把红色换了个位置。
  **已回退门禁，只留计量**；判据纪律：门禁转绿必须能说清它验证了什么。
- **新登记**：M-19（temperate `NATBNK` 美术缺失，资产缺口，简单）、M-20（离屏帧被记成空掩码，
  中等，`drawRuntimeVoxelShadowMask` 的两处 `return true` 同时兼作「有效」与「已画」）。

回归：`PASS=8 KNOWN-RED=3` → **`PASS=8 KNOWN-RED=3`**，`RED-NEW=0`（本轮不改判定，只加计量）。

移出本批：无（本轮只有一条中等，未启动第二条）。**未提交他人改动**：收敛时工作区里出现了
`src/ui/hud/RuntimeBuildReadyBanner.{h,inl}`、`RuntimeSessionProduction.cpp`、`RuntimeProductionHostState.h`
的改动（08:29 生成，内容是建造就绪角标，与 M-18 无关），判定为并发进程的在建工作，
本轮只按路径显式提交自己的三个文件，未触碰它们。

报告：`reports/FIX-09-建筑零投影的三桶计量.md`。

下一轮起手：**M-20 / M-18 合并做**——先在 `recordRuntimeWorldObjectShadowResult` 里打印
type/instance/rect/intersects（计量必须打在记录点，才能与汇总对上），一次构建即可裁定
「离屏被记成空掩码」还是「span 生成空」。

## 六、第 7 轮（2026-11-12）打包清单（存档）

主题：**把 `code-red:needs-metering` 清零口径**。剩下两条标着「疑为产品缺陷、先加只读计量」的
条目（`result` / `render`）都只红一句话，本轮把两句话都拆开：一条证明是夹具的时钟纪元错，
一条证明是真的产品缺陷。

- **M-17 → 已完成（`4cdc891`，`result` 转 PASS）**：记分页读 `runtimeUiClockNow()`（CLOCK_MONOTONIC），
  探针却用 `GetTickCount64()` 写「650ms/1600ms 之前」。两个纪元相减恒为巨大值，
  `runtimeUiScoreElapsed` 两次都钳到末帧 → 两张图逐像素相同 → `changed=0` 被读成「缓存冻帧」。
  探针改按渲染所读的时钟构造起点，产品零改动；实测 `changed=23872/24486/34795`。
- **S-06 → 已完成计量（`06c8ea2`），修复拆为 M-18**：`drawn=5` 而四个 kind 全 0 本身是不可能读数
  （地形树木的软阴影也记进 `shadowsDrawn`，却没有 kind 接住）。补 `structureCand` / `structureEmpty`
  后得到 `2/2`：建筑进了通道、掩码「解析成功」、压暗 0 像素 → **建筑零投影**，产品缺陷。
- **移出本批**：M-18（掩码空，需在 `drawRuntimeShpShadowFrame` / span 生成层再拆一层）、
  M-12（右键命中的可见性门）——两者都要先量后改，不在同一轮里连着动产品逻辑。
  本轮未启动任何中等问题，把时间全用在「让两条假红各归其位」上。

回归：`PASS=7 KNOWN-RED=4` → **`PASS=8 KNOWN-RED=3`**，`RED-NEW=0`。
`known-red.tsv` 删 `result` 行，`render` 行按新定性改写（`code-red`，不再是 `needs-metering`）。

报告：`reports/FIX-08-时钟纪元与建筑零投影.md`。

下一轮起手：**M-18（建筑零投影，先拆掩码侧四元组：`shadowImage` 宽高/非零像素数/span 数/阴影中心与 viewport）**，
其次 **M-12**（命中像素上所有 spans 命中对象的 depthVis 清单）。

## 六、第 6 轮（2026-11-12）打包清单（存档）

主题：**把连红五轮的 `build` 清到底**。两条都是「夹具缺了自己该有的东西」，产品逻辑零改动。

**M-15 → 已完成（`52bd380`）**：2peaks 世界 `Structures:10` 全 Neutral，没有
`Factory=InfantryType/UnitType` 的己方建筑，catalog 里 15 个 Unit + 13 个 Infantry
全部停在 `runtimeOwnerHasCompatibleFactory`。注入 GAPILE + GAWEAP（owner=己方），
落点用环搜避开既有建筑地基（按 `object.x + width` 判占用，不是渲染中心），
注入后 `refreshRuntimeObjectOccupancyAfterLocalChange`。

**M-16 → 已完成（`c90ec0e`）**：低电探针一进门就要求 `runtimeEconomyLowPower`，
但零售图没有耗电建筑、净电恒正，探针走不到断言本体。改为冒烟侧临时抬高 `powerUsed`
再还原，探针本体不改。**`build` 由此整条转 PASS。**

**M-17 → 已计量，未修**：`result` 的记分动画 `changed=0`，但 tick/frames/save 三项正常。
已排除「没重绘」（缓存门里有 `!runtimeResultScoreIsAnimated`）；待验的是
`uiClock->nowMs()` 在冒烟里是否冻结（记分帧按它取 elapsed，而冒烟只改 presentationStartedAtMs）。

回归结果：`PASS=6 KNOWN-RED=5` → **`PASS=7 KNOWN-RED=4`，`RED-NEW=0`**。
`known-red.tsv` 删掉 `build` 行，`result` 行按计量改写。

移出本批：`result`（呈现层时间源，需先验时钟），按复杂度留在下一轮。
报告：`reports/FIX-07-build冒烟转绿.md`。

下一轮起手：**M-17（先验 uiClock 在 result 冒烟里能否推进）**，其次 **M-12**（命中像素的 depthVis 清单）。

## 七、第 5 轮（2026-11-12）打包清单（存档）

主题：**多谓词断言必须逐项计量**。M-14（`build` 移动帧选择框）与 M-12（`interaction` footprint 命中）
两条已知红都只有一句「aligned=no / hit mismatch」出口，把 5~6 条谓词压成一句话，导致问题描述本身
就是错的（M-14 被写成「选择框盖不住身体」，其实盖住了；M-12 被写成「命中框与地基口径不一致」，其实三个矩形逐边相等）。
本轮先把两处拆成逐项计量，拿到数字再定性；产品行为零改动。

**M-14 → 已完成（`61858b3` + `d2f36b3`）**：六个谓词里只有 `cy` 失败。潜航的预期垂直偏移写成
`tileHeight/2`（=15px），而 `drawLevelForObject` 的实际下沉是 **1/3 层级**（=5px）。
把常量提为头文件 inline `runtimeSubmergedVisualDepthLevels()` 供绘制与断言共享，断言按它折算像素。
六类对象全部 `aligned=yes`，`build` 阻塞点后移到 M-15。

**M-12 → 已计量收窄，故意不修（`799c9b6`）**：几何三项（cells / hash / 三矩形）全部一致，
`boundsContainsFootprint` 也成立，唯一失败谓词是 `rightClickMatches` 且目标为 `nullptr`。
命中点 (1043,73) 上只有 `CABUNK02`，其 `structureSpriteHitSpans` 含该像素、depth-visible spans 不含，
被 `buildingPixelVisible` 拦下后整条对象 `continue`，该像素无人顶替——「画得出、点不到」的空洞。
两种定性（真被遮挡 vs 可见性门错杀）改法相反，动 pick 会重演 M-10 的误改，故本轮只留计量。

回归结果：`PASS=6 KNOWN-RED=5 RED-NEW=0`（与开工基线一致，零新回归）。
两条已知红都属「阻塞点后移」，不是修复无效：`build` → M-15，`interaction` → 右键命中的可见性门。

移出本批：无（本轮未硬啃，M-12 的修复按计划留到下一轮先补一档计量）。

报告：`reports/FIX-06-选择框与命中框的两条口径.md`。

下一轮起手：**M-15**（夹具缺口已定性，直接补己方兵营+战车工厂，一次构建看 build 推进到哪），随后
**M-12**（补一档计量：该像素上所有 spans 命中对象的 depthVis 清单，先钉死「谁挡住谁」再动 pick）。

基线回归（开工前）：`PASS=6 KNOWN-RED=5 RED-NEW=0`，与第 4 轮收口一致。

## 八、第 4 轮（2026-11-12）打包清单（存档）

主题：**夹具缺口 + 观感硬伤，两条都不动模拟层**。M-11 给 build 冒烟补一个可悬停单位（fixture-gap），
S-09 把 FPS 面板做成默认关（UI-01 §3.1 唯一确证的硬伤）。共用一次构建与一次回归。
报告：`reports/FIX-05-夹具缺口与FPS叠加层.md`。

- **M-11**：`build` 停在 `no unit available for hover health bar`；默认图只有建筑与地形。
  用 `addRuntimeObjectInstance` 注入 1 台己方 MTNK（不用手搓结构体），并沿半径 2..10 找一个
  「自身包围盒中心命中回自己」的格子，探针结束后按 id 摘掉。→ `0ce035a`（该断言转绿）
- **S-09**：`drawRuntimeFpsDisplay` 三个调用点加偏好位门控（默认关，`--show-fps` / `[Options] ShowFps` 打开）。→ `c1ccfe6`

回归结果：`PASS=6 KNOWN-RED=5 RED-NEW=0`（与基线一致，零新回归）。
`build` 仍红但**阻塞点后移**：悬停单位已绿，现停在 M-14（移动帧选择框覆盖）。

移出本批：无。本轮没有硬啃中等问题（M-12 需先量 footprint 两侧差值，时间不够则不启动，
避免重演 M-10 那次按直觉改产品被反证指标打回）。

下一轮起手：**M-14（build 第 4 个阻塞，先加三个谓词的只读计数）** 与 **M-12（interaction footprint 命中框）**，
两者同属「选择框/命中框几何口径」，可各写一段计量后一并定性。

## 九、第 3 轮（2026-11-12）打包清单（存档）

主题：**两条判红的根因都在断言口径，不在产品**。两条都先量几何再动手，产品路径零改动，
共用一次构建与一次回归。报告 `reports/FIX-04-两条断言的几何口径.md`。

- **M-09 血条包围盒**：断言改用「斜边跨度 + 冠顶间隙」，间隙常量 `kStructureHealthBarClearance`
  与绘制共享。→ `0e99bc1`（该断言转绿）
- **M-10 相机极值**：先试「把 −15 钳到 0」，被 `physicalMapEdgeCovered` 打回且 void 从 0 变
  0.012/856px，确认负数预留是策略；改断言：允许溢出量 = 该方向负预留（其余方向仍为 0）。→ `469cfa8`

回归结果：`PASS=6 KNOWN-RED=5 RED-NEW=0`（与基线一致，零新回归）。
两条仍红但**阻塞点后移**：build → M-11（夹具无单位），interaction → M-12（footprint 命中框）。

移出本批：无。但**一次错误方向被记录在案**——M-10 曾按「钳到 0」改产品，实测被 void 指标否决并回退，
教训写进报告第四节（遇到负数余量先找依赖它的断言，不要直接钳 0）。

下一轮起手：**M-11（build 夹具注入单位，简单）** 与 **M-12（footprint 命中框只读计量，中等）**。
M-11 便宜，清了 build 只剩一条即转 PASS；M-12 要先量两侧 bounds 差值才能定性，若时间只够一个取 M-11。

---

## 十、第 2 轮（2026-11-12）打包清单（存档）

主题：**回归门禁的「资产缺口 vs 产品缺陷」口径**。三条同一性质，只改探针/夹具口径，不动产品行为，
共用一次构建与一次回归。报告 `reports/FIX-03-回归门禁口径三连.md`。

- **S-05 campaign 覆盖门禁**：拆成「结构缺陷（判红）/ 资产缺口（计数）/ 内容完整性（仅有地图时判）」三级，
  并把 `availableMissionCount == missionCount - mapAssetGaps` 做成硬约束。→ `cd2e841`（**该条转 PASS**）
- **M-08 MCI 音乐探针**：后端缺失时降级为「选曲/落盘/阵营归属」三断言 + 「不许假成功」的反向断言。→ `933d70c`
- **S-04 interaction 夹具**：把最后一栋 Neutral 建筑改 owner 为己方，修理光标断言不再永久红。→ `e1dede3`

回归结果：`PASS=6 KNOWN-RED=5 RED-NEW=0`（基线 5/6/0，本轮唯一清零项是 campaign，零新回归）。
两条修完仍红但**红的原因换了**：build 停在 M-09、interaction 停在 M-10——都是原先前置失败
把后续断言整段屏蔽，属于如实推进，不是无效修复。

移出本批：M-09 / M-10 未在本批硬啃。两者都要先量几何口径才能判断「是实现错还是断言公式错」，
属中等问题，单独立项。

下一轮起手：**M-09（健康条 2px）** 与 **M-10（南向极值裸露）** 二者同源（都是选择框/相机几何的口径问题），
可先各写一段只读计量再动手；若只能选一个，取 M-09（build 只剩这一步，清了即转 PASS）。

---

## 十一、第 1 轮（2026-11-12）打包清单（存档）

承接上一轮被截断的 WIP（`progress/.active` 记 `auto-acquire-policy+team-number`）：

- **S-01 + S-02 合并为一个 fix**：同一根因族（自动索敌通道），共享「谁可以自动选谁」的判定，一个 commit 落地可独立回退。→ `a2b2c78`
- **S-03 单独一个 fix**：纯呈现层新增，与索敌无耦合。→ `8e6b6e5`
- **配套 test**：`RuntimeGuardAcquisitionPolicySmoke.inl` + `RuntimeTeamNumberBadgeSmoke.inl`。→ `2df22e3`
- **加做 M-01（CP1252）**：简单批收完后仍有余量，按性价比取第一个中等问题。→ `b2ee6fc`

移出本批：无。但有一条**断言**被移出：原索敌冒烟的第 5 场景「被敌方坦克打伤后还手」
实测自相矛盾（该夹具 15s 内无弹丸，且被动索敌先给了受害者行为，无法区分「伤害触发」），
已删除并在报告里写清理由；只能靠伤害触发的场景由磁暴线圈那条覆盖。

回归结果：`PASS=5 KNOWN-RED=6 RED-NEW=0`（与基线一致，未引入新红）。
`build` 仍红但**换了原因**：CP1252 已绿，现停在 MCI 音乐探针（新登记 M-08）。

下一轮起手：**M-08（MCI 探针口径，简单）** → 若一次构建内能带上，再并 **S-04**（interaction
夹具注入己方建筑）/ **S-05**（campaign gate 白名单口径）。三条都只改探针/夹具口径，
不动产品行为，可同一批构建、统一回归。
