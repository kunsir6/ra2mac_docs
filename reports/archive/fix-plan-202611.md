# fix-plan 归档（第 1~24 轮条目原文）

> 迁出时间：2026-11-13 第 25 轮清单治理。
> 原因：`fix-plan.md` 每轮都进上下文，条目正文（尤其已完成条目的读数字段）不该长期占据主线。
> 主清单现在只保留 pending / measuring / blocked + 最近 10 条 done；本文件是它们的原文。
> 追溯某条历史条目时查这里，看现状查 fix-plan.md。

---

# 问题修复计划（fix-plan）

> 用途：本项目「待修复问题」的唯一台账。每轮开工先核对本表，收工前回写状态。
> 维护规则：
> 1. 新问题一律先登记再动手，登记必须写清「根因假设」，根因未明只允许登记为「只读计量」类任务。
> 2. 修复完成 → 状态改「已完成」并填关联报告；证明不成立/场景消失 → 改「已废弃」并写原因。
> 3. 复杂度一旦被实测推翻（改到第二个模块去），必须回来改分级并写原因，不许留在原批里硬啃。
> 4. 体量红线（本表每轮进上下文，本身是被治理对象）：全文 ≤400 行；条目 ≤120 条；每轮收口摘要 ≤10 行，历史收口压成一行索引；新增 N 条须同时归档 N 条已结案条目。
> 5. 条目只允许 12 个字段：id / 标题 / 现象 / 根因假设 / 收益 / 成本 / 性价比 / 复杂度 / attempts / 状态 / 验收条件 / 关联报告。一次性证据写进报告，不堆在条目里。
> 6. 每次补登记同步体检：悬空报告链接、状态与报告矛盾、重复条目、attempts 与收口不符。只追不治 = 没做这一步。
>
> 分级口径：
> - **简单**：改动局部（单文件或单函数族）、根因已由日志/断言直接指认、与他项无耦合、可独立 revert。
> - **中等**：单模块内多文件、或需要新增只读计量才能定性；失败可整块回退。
> - **复杂**：跨模块 / 需重构 / 触及呈现层或输入链路架构；单独成轮，先写方案再动手。
>
> 性价比排序：S（半天内可见用户价值）＞A（清掉一条 known-red 或解掉一类卡点）＞B（体验打磨）＞C（基建/可观测性，回报延迟）。
>
> 最近更新：2026-11-13 14:52（第 24 轮收口）；
> 第 24 轮收口：基线 `10/1/0`（`20261113-135721`）→ 收口 **`10/1/0`**（`20261113-143359`），零新回归。
> **C-02h 已完成（产品缺陷，`7b9f576`）**：blocked 档里工人不是被重叠重定位推走，而是被
> 「取消入场恢复」当成失败入场 —— 离场 Move 的目标格因墙圈未开不可达（`path=0` 即刻完成），
> 恢复逻辑用半径 6 搜索把站在自己炼油厂地基里的矿工直接搬到空地。改为「奴隶矿工的身体由
> 任务步负责」后 blocked 档转绿，`ore` / `no ore` 两档未动。新登记 **C-02i**：阻塞点后移到
> `runRuntimeSlaveMinerSmokeProbe` 后续段（`digging=1 carrying=1 cargo=4 credits=0`）。
> 报告 `reports/FIX-25-奴隶矿工离场不该被当成取消入场.md`。
>
> 体量自治理（第 23 轮起强制）：本文件只留「本轮收口 ≤10 行 + 本轮打包清单 + 轮次索引」。
> 轮次一过，摘要压成索引表中的一行、清单原文迁进 `reports/fix-plan-archive.md`。

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
| S-08 | EVO-06 世界重绘只读计量 | 帧循环每 tick 无条件 `InvalidateRect`+`UpdateWindow`，不知多少次真改了画面 | **第 14 轮已定位到行**：主循环 `if (tickAdvanced) state.repaintRequested = true;` + `continuousRuntimeFrame = world loaded && !IsIconic` → 进图后每帧整窗 `InvalidateRect`；`reuseCachedFrame` 因为 `repaintRequested` 恒真而永远走不到 | 中：为「脏区驱动」提供基线数字 | 把「本帧是否 reuse / 连续相同帧数 / 每秒 Invalidate 次数」接进现有 `RuntimeFrameDiagnostics` 周期输出 | **B** | 简单 | 待修复（方案见 FIX-15 §3；与 M-03 同源，先计量后动提交条件） | `reports/FIX-15-框选结案与两栖卸载真阻塞点.md` |
| S-09 | FPS 叠加层默认常显（U-17） | 每次提交帧后无条件画左下 96×22 `FPS: 60` 面板，正式版没有这个面板 | 该面板只为自测而加，`drawRuntimeFpsDisplay` 的三个调用点没有任何开关；`RuntimeMainFrameContract` 只断言面板**矩形**存在，不断言「画了」 | 高：正式版观感的第一眼硬伤，纯视觉、无模拟耦合 | 加 1 个偏好位 + 3 处调用点门控（`--show-fps` / `[Options] ShowFps`） | **S** | 简单 | 已完成（`c1ccfe6`） | `reports/FIX-05-夹具缺口与FPS叠加层.md` |
| S-10 | 启动日志把零售自带的重复建筑 id 报成异常 | 每次启动 `core` 都打印 `Duplicate building id ignored by capability index: [NAPSYA]` | 零售 `rulesmd.ini` 的 `[BuildingTypes]` 里 `NAPSYA` 确实出现两次（185 / 241），`rebuildTypeIndex` 按「重复即告警」处理，但「先到先得」正是零售语义（两处指向同一 section），不是数据损坏。告警缺 item 下标，也没区分 `Corrupt` 与 `Duplicate` 两种性质 | 低中：日志噪声，且会掩埋真正的解析重复 | 1 处消息分级（带 item 下标 + 降为 data-note） | **C** | 简单 | 已完成（`5ce280b`） | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §3 |

> **简单区现状（第 23 轮收口核对）**：S-01~S-12 全部已完成或已废弃；在册简单项只剩
> S-08（须与 M-03 合批，且缺「静止连拍」入口——先造入口再谈读数）、
> S-13（结构守卫基线陈旧，卡在缺 `--inventory/--trace` 产物）、
> M-19（NATBNK 缺 temperate 美术，资产侧，不阻塞任何门禁）、
> S-14（计划表体量门禁，第 23 轮新登记——当轮已手工清到 160 行，缺的是防回涨的闸）。
> **仍有第 12 轮那两条核对结论**：`ICM_QUERY/ICM_OFF` 反写**早已修复**（`windows.h:1228`），
> 不作为待办重开；U-16 的「全局 pin 部署目标」属复杂，321 个测试目标要跟编，留作单独成轮。

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | 状态 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|
| S-11 | 速度阶梯改了，两处断言表还在钉旧哨兵 | interaction 的 ESC 菜单断言红在 `gameSpeedSlider`；`gameSpeedSlider=yes/no/no/yes/yes` → 几何/拖拽/键盘三组绿，**坐标组与全局节奏组红**。support-power 冒烟同样在 `initialRate != 0` 上判 fail | **已定性：断言表过期，不是产品缺陷**。`ffdd7c5` 把 7 档改为 31/37.5/46.88/62.5/93.75/187.5/281.25（6 档 = 5 档×1.5，`unlimited()` 恒 false）；`RuntimeShell.cpp:37667` 仍写 `== 0`、`expectedGameSpeedPacing` 末位仍写 `0`、`RuntimeSupportPowerSmoke.inl` 仍留 `initiallyUncapped/changedUncapped` 两支 | 高：它挡在 interaction 冒烟**靠前**的 ESC 菜单段，不清掉 M-12 永远测不到；清掉后该条才有信号价值 | 两文件共 ~15 行：两张表末位改 281、拆掉 uncapped 分支 | **S** | 简单 | 已完成（`d69980d`；interaction 越过 ESC 菜单段，回到 M-12） | `reports/FIX-11-被known-red掩盖的新回归.md` §1 |
| S-13 | 结构守卫基线列着已删文件 | `tools/structure/structure-baseline.json` 仍列 U-15 已删的两个文件；守卫是开发期静态检查（不在构建链里），本机没有它的 `--inventory/--trace` 产物，从没跑过 | 基线是「人工审过的精确清单」，删除文件后没回写；守卫本身没有生成产物的入口脚本 | 低：守卫当前不参与判定，脏基线只会在下次跑守卫时误报 | 需先补产物（守卫的 inventory/trace 由谁生成尚未查清），再重生成基线 | **C** | 简单（但阻塞在产物） | 待修复（第 12 轮登记，来自 `U-15` §遗留） | `reports/U-15-选中指示与矿量格.md` §遗留 |
| S-12 | known-red 会吞掉「失败原因被换掉」的新回归 | S-11 那次：交互条本来就红，速度表回归把红点从 footprint 前移到 ESC 菜单，三态判定仍报 KNOWN-RED。**只有人读日志才发现**，机器判定完全盲 | `regress.sh` 对已登记 id 只看「非零退出码」，不比对失败文案；`known-red.tsv` 也只记一句自由文本原因，没有可比对的锚 | 高：这是回归门禁可信度的地基——现在的 KNOWN-RED 只保证「红」，不保证「红的是同一件事」 | 小：`known-red.tsv` 第 4 列存失败前缀，`regress.sh` 只对该行做字符串包含比对；不一致即判 RED-NEW 并把两侧前缀打进报告 | **A** | 简单 | 已完成（`50d3a85`；自测两向：bogus 前缀→cause-changed、空前缀→KNOWN-RED+告警） | `reports/FIX-13-known-red失败前缀门禁.md` |
| S-14 | 计划表本体涨破它自己的体量红线 | `fix-plan.md` 曾涨到 743 行（红线 ≤400），其中约 500 行是第 1~22 轮的逐轮打包清单；红线写在第 4 条规则里，但没有任何东西去量它，所以它一路涨到有人手工 `wc -l` 才发现 | 规则只写不量：没有把「最近轮次的清单原文」交给独立的缓冲文件，也没有任何检查在超限时报警 | 中：本表每轮都进上下文，涨破后每轮都在为历史付费 | 小：`regress.sh` 或独立小脚本加一条 `wc -l` 门禁（>400 行即告警/判红），配合「轮次一过就迁存档」的写法 | **C** | 简单 | 待修复（第 23 轮登记；当轮已手工把 743 行清到 160 行，缺的是防回涨的闸） | `reports/fix-plan-archive.md` |

## 二、待修复 —— 中等
|---|---|---|---|---|---|---|---|---|---|
| M-01 | EVO-08 compat 实现 CP1252 解码 | 零售 `Text=` 的智能标点（0x85/0x91…）被逐字节 widen 成控制字符，`build` 条常驻红 | compat 只有 UTF-8 分支，CP1252 直接返回 0 | 高：影响所有零售文本（含 EVA 字幕） | 编码表 + 请求路由 | **A** | 中等 | 已完成（FIX-02） | `reports/FIX-02-CP1252解码.md` |
| M-02 | ON-4-07 box selection 与投影不一致 | **两次证伪后结案为非缺陷**。①第 13 轮：「世界坐标 vs 表面坐标」不成立（拖拽框与命中共用 `leftPointer.start/current`，`picked==bbox`）；②第 14 轮：「包围盒含透明留白」也不成立——`bounds` 就是 `spriteBounds` 外扩 3px（`runtimeUnitSelectionBoundsForSprite` = `InflateRect(+3,+3)`），而 `spriteBounds` 已被`RuntimeUnitSelectionAlignmentSmoke` 对全类型×姿势×朝向×tileWidth 逐像素证明等于真实绘制框 | **已废弃（非缺陷）** | 无收益：擦边容差 3px 是零售同款手感；样本 `#9003` 的 `artInBand=7px`，车体真的在框里 | 无 | — | 简单 | 已废弃 | `reports/FIX-15-框选结案与两栖卸载真阻塞点.md` |
| M-03 | ON-2-06 世界 idle 空转重绘 | 静止时也每 tick 全量重绘，CPU/功耗浪费 | 同上：`tickAdvanced` 直接置 `repaintRequested`，缓存复用被判据本身短路 | 中：功耗与风扇 | **A 方案（场景签名门）**：每拍算廉价签名（tick+相机+对象位置/朝向/帧号+选中集+资源+遮罩版本），不变就不置 `repaintRequested` + 每 30 帧强制重绘兜底；**B 方案（像素差量门）**有自抑制风险（推动画的是重绘本身），只能配 `tickAdvanced` 一起判 | **B** | 复杂（呈现层提交条件） | 待修复（方案已写，单独成轮；漏字段的后果是冻帧，必须先有 S-08 读数） | `reports/FIX-15-框选结案与两栖卸载真阻塞点.md` |
| M-04 | ON-2-02b 提交节奏对齐显示刷新 | 帧提交与 60Hz 不同步，偶发丢帧/撕裂 | 用定时器而非 display link | 中 | 需接 CVDisplayLink | **B** | 中等 | 待修复 | `reports/ON-2-02a-呈现节奏计量与主人帧修复.md` |
| M-05 | EVO-13 尤里复仇战役未接入 | 战役菜单只有基础版 ra2 任务 | 战役数据库只装了 ra2 的 mission 表 | 中高：资料片内容缺失 | 数据层接入 + 校验 | **B** | 中等 | 待修复 | `reports/Q-04-RA2与YR拆分盘点.md` |
| M-06 | EVO-04 日志与崩溃现场落地 | 崩溃后没有现场，只能靠重跑 | 无统一日志出口 | 中：排障效率 | 日志出口 + zip 收集 | **C** | 中等 | 待修复 | — |
| M-07 | EVO-03 diagnostics 驱动入口 | 无人值守走不完 菜单→大厅→载入→世界（autostart 钩子已删） | 缺一个脚本化入口 | 中：自动化上限 | 新增 CLI 驱动 | **C** | 中等 | 待修复 | — |
| M-08 | `build` 的 MCI 音乐探针口径 | CP1252 修好后 `build` 停在新阻塞 `mci=error-306`，整条条红 | macOS 无 MCI 后端；探针把「平台缺口」当「产品缺陷」判红（同 campaign 的 Bink） | 中：清掉 `build` 的剩余红，恢复该条信号价值 | 探针改 skip + 打印 `skipped(no MCI backend)` | **A** | 简单 | 已完成（第 2 轮 933d70c；后续阻塞点后移到 M-09） | `reports/FIX-03-回归门禁口径三连.md` |
| M-09 | `build` 建筑健康条比选择框高 2px | 健康条 `actual=61x33`，断言 `expected=61x31`（宽一致、分段 14/14 正常、无限血已正确隐藏） | **已定性：公式旧**。断言按「水平条」算高度（`+1`），实际血条贴冠顶**斜边**排布，包围盒 = 斜边竖直跨度(30) + 冠顶间隙(3) = 33 | 中：清掉 build 第 2 个阻塞点 | 1 处公式 + 常量共享 | **A** | 中等 | 已完成（`0e99bc1`；build 停在 M-11） | `reports/FIX-04-两条断言的几何口径.md` |
| M-10 | interaction 南向相机极值裸露 | 8 个钳制极值里只有 `S` 一项 `tile=398/625..458/655:no`：最南一行在视口底(640)以下被切 15px；`corners` 同时判红；void 全 0 | **已定性：实现是对的**。物理地图边缘的 reveal 预留被有意做成 −halfTile（相机提前半格停，把锯齿黑边留在客户区外）；错的是「极值 cell 必须完整可见」这条断言，与 `physicalMapEdgeCovered` 直接矛盾。钳到 0 后 void 立刻 0.012/856px，反证策略必要性 | 中：清掉 interaction 第 2 个阻塞点 | 允许溢出量 = 该方向负预留 | **A** | 中等 | 已完成（`469cfa8`；interaction 停在 M-12） | `reports/FIX-04-两条断言的几何口径.md` |
| M-11 | `build` 悬停血条找不到单位 | 血条断言转绿后，`build` 停在新阻塞 `no unit available for hover health bar`：夹具世界里只有建筑与地形，没有可悬停的单位 | **已定性：夹具缺口**。默认图 `Units=0`；且必须用 `addRuntimeObjectInstance` 生成（手搓结构体会绕过 pose/`hasRenderPosition`，像素画得出来但命中回不到自己），落点还要保证「自身包围盒中心命中回自己」 | 中：清掉 `build` 第 3 个阻塞点 | 注入 1 台己方 MTNK + 环型找落点 + 探针后按 id 摘掉 | **A** | 简单 | 已完成（`0ce035a`；build 停在 M-14） | `reports/FIX-05-夹具缺口与FPS叠加层.md` |
| M-12 | interaction 建筑「画得出、点不到」 | `structure footprint hit mismatch`。**原描述（命中框 vs 地基口径）已被计量推翻**：cells=4/4、hash 相同、preview/hit/footprint 三矩形逐边相等、bounds 覆盖 footprint，5 组谓词只剩 `rightClickMatches`，且目标为 `nullptr`（不是打到别的建筑） | **已收窄未定性**：命中点 (1043,73) 上只有 `CABUNK02` 一个候选，`structureSpriteHitSpans` 含该像素但 depth-visible spans 不含，被 `buildingPixelVisible` 拦下后整条对象被 `continue`，该像素无人顶替。剩两种可能：①真被别的对象挡住（应返回挡它的那个）②深度重放把这只 bunker 前墙误判不可见（可见性门错杀）。两者改法相反，不能猜 | 中：清掉 interaction 最后一个阻塞点，直接改善建筑点选手感 | 断言前对焦样本建筑（21 行，纯冒烟） | **A** | 中等 | **已完成（`0b1f9e7` 计量 + `b855223` 修复，该条转 PASS）**。**已定性：不是产品缺陷，是取景问题**。四桶读数 `#8 CABUNK02 drawsInView=0 drawsOffView=1 visiblePixels=0 depthPixels=0`，该帧 `viewport=0,0,808,446`，而样本包围盒 `(983,58,1103,118)` —— 整栋落在视口右侧之外；`depthOnlyPixels=0` 同时排除「进过深度被压过」。上一段雷达场景把镜头停在地图几何中心，采样建筑与镜头互不约束，于是断言在要求一个屏幕上不存在的像素。`findProjectedObjectAtPoint` 未动（视口外返回 nullptr 是正确行为） | `reports/FIX-12-命中样本落在视口外.md` |
| M-13 | 真实遭遇战开局取证通道（U-18 + EVO-03 合流） | `--skip-skirmish-menu` 进的是战役图 `2peaks.map`（`Units:0 / Structures:10 / Players:1`），出图里没有基地车与己方建筑，游戏内 HUD 整块没有可信对照物 | skip 路径没有走遭遇战 bootstrap，而是直接吃 `DefaultMap`；`--skirmish-build-smoke-test` 报 `modeRules=no alliesAllowed=no` 也说明它没经过大厅配置 | 高：它是 U-19/U-20/U-22 的前置，不打通则整个 HUD 对账无法判定 | 中等偏高：要么让 skip 路径构造标准遭遇战 setup，要么换默认多人图 + 补 owner 注入；两条都要动启动路径 | **A** | 中等（与 M-07 同源，落地时优先合并） | 待修复（UI-01 登记） | `reports/UI-01-正式版观感对账.md` §3.2 |
| M-14 | `build` 移动帧选择框不覆盖可见身体 | 推进到第 4 个阻塞：`DLPH=43x25/43x25 aligned=no`（尺寸相同却不同过）、`SQD=92x51/100x41 aligned=no`（移动帧 sprite 变矮变宽）；MTNK/DEST/ZEP/ENGINEER 全绿 | 未明，两种成因必须切开：①尺寸谓词（`selectionBounds` 是否该锁固定尺寸）②锚点谓词（潜航 `renderCenter.y - center.y == tileHeight/2`、`pointInRectInclusive(bounds, selectionCenter)`）。DLPH 尺寸相等即指向 ② | 中：清掉 `build` 第 4 个阻塞点 | 先加只读计量（三个谓词分别计数）再定性 | **A** | 中等 | 已完成（`d2f36b3`；根因是断言公式，非产品） | `reports/FIX-06-选择框与命中框的两条口径.md` §1 |
| M-15 | `build` 队列单位时目录全不可排队 | M-14 断言转绿后暴露：`no unit/infantry catalog item`，找不到任一 `canQueue` 的 Unit/Infantry | **已定性：夹具缺口**。计量：total=46 unit=15 infantry=13 structure=18 credits=199200 power=200/0，全部 `reason="missing InfantryType"/"missing UnitType"`——钱/电/科技都放行，卡在 `runtimeOwnerHasCompatibleFactory`，即世界里没有己方生产基地（2peaks 的 `Structures:10` 全 Neutral）。与 M-11 同类 | 中：清掉 `build` 当前阻塞点 | 注入 1 栋己方兵营 + 1 栋己方战车工厂（`addRuntimeObjectInstance` + `refreshRuntimeObjectOccupancyAfterLocalChange`），落点避地基；改完要重跑整条 build（后面还有队列重排/取消/集结点断言） | **A** | 简单 | 已完成（`52bd380`；build 越过了队列/生产这一段） | `reports/FIX-07-build冒烟转绿.md` §1 |
| M-16 | `build` 低电探针被自己的前置挡死 | `sidebar low-power integration probe state is not low power`，探针一进门就要求 `runtimeEconomyLowPower`，而零售图没有耗电建筑（powerUsed 恒 0），净电永远为正 | **已定性：前置无人保证**。`runtimeEconomyLowPower` 判 `produced - used < 0`，探针走不到断言本体，属夹具职责缺位而非产品缺陷 | 高：它是 `build` 转 PASS 的最后一道门 | 冒烟侧临时抬高 powerUsed 再还原（3 行） | **S** | 简单 | 已完成（`c90ec0e`；**build 整条转 PASS**） | `reports/FIX-07-build冒烟转绿.md` §2 |
| M-17 | `result` 记分动画两次 paint 出同一张画面 | `original score animation stalled behind paused-frame cache`；计量 `changed=0 tick=300/300 frames=6/6 saved=yes`，三个子条件正常，只有画面没变 | **已定性：两个时钟纪元相减**。记分页取 `runtimeUiClockNow()`（macOS = `CLOCK_MONOTONIC`），而探针用 `GetTickCount64()` 写起点；两个纪元在 macOS 上不同 → `now - start` 恒为巨大值 → `runtimeUiScoreElapsed` 两次都钳到末帧 → 两张图逐像素相同。已排除缓存（门里带 `!runtimeResultScoreIsAnimated`） | 中：结算页动画是用户可见的一段 | 探针改用 `runtimeUiClockNow` 作基准（产品零改动） | **B** | 简单 | 已完成（`4cdc891`，**该条转 PASS**） | `reports/FIX-08-时钟纪元与建筑零投影.md` §1 |
| M-18 | 建筑完全不投影（`render` 的真红） | 自然地图阴影 `candidates=7 drawn=5 shp=5` 但 `structures=0`；`structureCand=2 structureEmpty=2`——两个候选进了地面阴影通道、掩码「解析成功」，却一个像素都没压暗 | **仍未定性，但排除了一条**：第 8 轮加 `CONCORD_SHADOW_TRACE` + 第三桶 `structureNoArt` 后，测得自然地图上确实存在 0×0 的 `NATBNK`（`NewTheater` 只有 `art/snow` 变体，图为 TEMPERATE），但 `structureNoArt=0` 而 `structureEmpty=2`，**记录侧那两个候选不是空体建筑**，故「资产缺口」解释不成立。剩下的可疑路径：①帧矩形与 viewport 不相交/裁剪到零宽时 `drawRuntimeVoxelShadowMask` 也 `return true` + 0 像素 ②span 生成空 | 高：建筑没有影子是画面硬伤 | 下一步很便宜：在 `recordRuntimeWorldObjectShadowResult` 里打印 type/instance/rect/intersects（追踪要打在记录点才能与汇总对上），一次构建即可裁定 ①/② | **A** | 中等 | 已定性并修门禁（`8b14b61`）：**非产品缺陷**。帧被 ore 探针居中到无 overlay 空地，建筑必在视口外；自证帧 `CAAIRP` = `drawn=4 pixels=13551` | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §2 |
| M-19 | 自然地图上的 `NATBNK` 没有 temperate 美术 | `body=0x0 frame=0x0 nonzero=0 globalH=126`，`Structure sprites: 2 loaded, 0 missing` 却什么都画不出来；`render` 的 trace 里反复出现同一实例 | **已定性：资产缺口**。`artmd.ini [NATBNK] NewTheater=yes`，导出集只有 `mix_exports/art/snow/natbnk.shp`（与 `_b`），`2peaks.map` 是 TEMPERATE | 中：任何「建筑可见/可点/有影子」的断言在该图上是不可满足的，先把这个洞标出来 | 资产侧：补 temperate 变体，或让冒烟换一张带可加载建筑的图 | **C** | 简单 | 待修复（不再阻塞任何门禁：`CAAIRP` 已能投影，降为画面完整性待办） | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §2 |
| M-20 | 离屏帧被记成「空掩码」 | `drawRuntimeVoxelShadowMask` 在 `!rectIntersects(imageRect, viewport)` 与 `clippedStartX >= clippedEndX` 两处直接 `return true`，`darkenedPixels` 保持 0，调用方看到的是「掩码解析成功但没压暗」 | **待验**：返回值同时承担「掩码有效」与「画了」两种语义，离屏/裁剪路径在统计上与真正的空掩码不可区分；`CAOILD` trace 已实测 `intersects=0` 走的就是这条 | 中：它可能是 M-18 的真因，也可能只是让 M-18 的读数失真的旁证 | 小：`drawRuntimeVoxelShadowMask` 增一个「是否真的落在视口内」的输出位，调用方据此分开计数 | **A** | 简单（实测后降级：一个函数 + 1 个 out 参数） | 已完成（`dd6eb31`）：读数由 `empty=2` 变 `off=2/empty=0` | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §1 |
| M-21 | `render` 矿喷发动画未被判为「已画」 | `oreGrowthSpawnerAnimationDrawn=false frames=11`，而 `ran/changed/ring=1/overlay` 全绿；被阴影门禁屏蔽 6 轮，第 9 轮门禁拆开后才露出来（改前基线日志逐字相同） | 未明：`frames=11` 说明帧号在推进，两种可能——①动画层数为 0（没进绘制循环）②层在但压暗像素为 0（同 M-18 的返回值语义问题，现已可分流） | 中：清掉 `render` 当前阻塞点 | 先看 `oreGrowthSpawnerAnimationDrawn` 的置位处（`RuntimeShell.cpp` ~34960 上游），再决定加计量还是直接修 | **A** | 中等 | 已完成（`bf5fd7c`，**render 转 PASS**）：探针按帧数推进（`eventTick+3`），而渲染侧 delay 是「拍」（`runtimeRuleFramesToTicks(3,30)=6`），`eventAge/delay` 恒 0 → 永远选第 0 帧。产品零改动 | `reports/FIX-11-被known-red掩盖的新回归.md` §2 |

## 三、待修复 —— 复杂（单独成轮）

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | 状态 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|
| C-01 | EVO-15 事件分发接 `sendEvent` | 不走 `[NSApp sendEvent:]`，导致 cursor rect 全失效、`isActive`/`isKeyWindow` 恒 0、tracking area 不回放 | 主循环自建 `nextEventMatchingMask` 分发，绕开 AppKit 正规路径 | 高：一次性修好一类系统级交互 | 高：改主循环 + 回归全部输入断言 | **A** | 复杂 | 待修复 | 见 `MEMORY` 中「本项目不调 sendEvent」条目 |
| C-02 | EVO-09 两栖卸载卸不下坦克 | 原写「船靠岸二次动作后 `transportPassengerIds` 仍非空」 | **第 15 轮定位到门**：`CONCORD_TRANSPORT_TRACE=1` 读数 `transfer:bodies id=9/10/11/12 at=15,15 hull=16,16` + `boarding:transfer-refused`，四人**同拍停在同一格**，`runtimeTransportTransferBodiesClear` 的 foot-to-foot 最小间距 0.5 使彼此都在对方扫掠走廊内 → 互锁；先到的 10 人是在格子未挤满时逐个进的。同时 `advanceRuntimeUnitTransportBoarding` 原先把 `beginRuntimeTransportGroundTransfer` 的返回值 `(void)` 丢弃，导致「被拒」与「没走到」不可区分 | 高：两栖玩法可用性 | 两条候选改法方向相反：A 每拍只放一人（按 instanceId 定序）；B 对「同船等待乘客」不算障碍。B 会放宽坦克段依赖的身体互斥，须先绿 `aboard=4`/`exits` 不重合 | **B** | 复杂（模拟层入口排队） | **第 16 轮已修复（C-02a 部分）**：`498ae37` fix + `c7a1f2f` test。A 方案（每拍只放一人）被读数否决；真修法是「同船步兵同伴不算路障」（载具/外部单位仍严格互斥）。`aboard=10/12 → 12/12`。**剩余阻塞另立 C-02c** | `reports/FIX-17-登船互锁解除与卸载新阻塞.md` |
| C-02c | 整仓步兵卸载 600 拍仍不放空 | 舱门口 8 台 MTNK 移开后，`executeRuntimeSecondaryAction` + 按拍推进 600 拍，12 名步兵仍留在 LCRF 上，`simulationStatus=moved #7 to 15,15` | **第 18 轮定性（更正第 17 轮）**：`ticks=66/66` 是 egress 的第一拍，不是卡住——去重键缺时间维度。加 120 拍桶后终态（tick=1680）是 **11 名已出舱者 `bstate=none`/`moving=0`/位置=格子中心，占满 8 个邻格**，最后一名 `id=7` 无干净走廊。结构性原因：两栖卸载不规划外侧终点（`remainingPath` 只在 `!runtimeAmphibiousTransport` 时算），出舱就地停靠；8 格 × 0.5 身体互斥的实际容量远小于名义 32 子格 | 高：`command` 仅剩的这一条，且「满仓下船」是两栖玩法主路径 | **取 A（推荐）**：两栖卸载也规划半径 2 外侧终点，全水时退回就地停靠；动手前先补两个只读位（半径 2 的 16 格可用计数、站定者的 `subCell` 是否 `-1`） | **A** | 复杂（模拟层卸载排队） | **已完成**（`4f13ccc` fix + `7361f55` test）：出舱者获得半径 2 外侧终点，12 名步兵整仓下船 | `reports/FIX-20-两栖卸载外侧终点.md`
| C-02d | 混编段载入 IFV 的整车下船失败 | 一次 `executeRuntimeSecondaryAction` 后断言 IFV 已出舱且乘员仍在车内，实际 `ifv=null riderAlive=0 riderCell=23023 boatCargo=3` —— IFV 没出舱 | **已定性**：`cargoBeforeAction=4 / boatMovingBefore=0`、无 `unload:host-busy` —— 卸载跑了，但一趟只放一件（循环找到第一个能出去的货就 break），而船货顺序 = boarding 到达顺序，IFV 不保证第一；「按一下就断言 IFV 已出舱」在赌排队次序 | 高：`command` 唯一 remaining known-red 的新阻塞点 | 已改完：按拍推进到 IFV 出舱（600 拍上限），断言本体一条没放 | **A** | 中等（若要改产品才升为复杂） | **已完成**（`107b06b` test + `2c3616c` test） | `reports/FIX-21-混编段按拍等待.md`
| C-02e | 生物反应堆段：五个步兵 800 拍未全部进入 | `RuntimeBioReactorSmoke.inl:285-291` 断言 `power==5` 且 team step Complete，实际 `power=450 pending=2`（只进 3 人） | **已定性**：剩下的两人 `moveTarget` 分别是对方所站的格子、`path=0 pathReq=1`，`blockedTicks` 停在 1 不增。进门格本身没错（排队时五人目标都是地基格 `12,12`）；是路径请求回来的那一刻，`applyRuntimeMovePathResult` 的 `goalAdjusted` 分支把地基格换成门外邻格——该分支的豁免名单只认 `WorldObjectKind::Unit`（`runtimeUnitTransportApproachAllowsBodyDetour:11444`），建筑吸收器被漏掉；两人因此互换目标格互堵，而「重算进门格」只活在路径走完的分支里，永远轮不到 | 高：`command` 链条第三段，且反应堆吸收是被动收入主路径 | 已改：新增 `runtimeBuildingAbsorberEntryKeepsGoal`（同构条件 + `moveTarget` 在地基内），载具那条不动 | **A** | 中等（产品侧单谓词） | **已完成**（`d6654eb` fix + `8dfc9f4` test）：`pending=0 power=650 aboard=5` | `reports/FIX-22-生物反应堆进门格不被兜底换掉.md` |
| C-02f | MCV repack 段：拆包后没在旧地基上生成可移动的已选中车辆 | `RuntimeMcvRepackSmoke.inl:145`：`dispatchRuntimeSecondaryActionFromUi` + `finishRepacking` 之后六个谓词里落点不符——`cell=(7,7)`，验收要 `(6,6)`；其余五项（旧建筑已消失、恰好选中一件、type/owner/canMove）全过 | **已定性**：产品按 `runtimePlacementAnchorCellForFootprint` 把 MCV 放在地基**锚点**（GACNST 3x3 的中心 7,7）再找可走格；验收把「测试放置建筑用的左上角」当成了落点，是锚点规则改中心锚后没跟上的旧断言 | 高：`command` 新阻塞点，且四阵营/搬迁/再部署整段都排在它后面 | 已改（测试侧）：拆包前存旧地基格清单，断言落点在其中；失败文案带实际格与锚点。不做「把产品改成落左上角」 | **A** | 简单（单文件单断言） | **已完成**（`7c02812` test）：四阵营全过，含 Russians+GACNST→AMCV | `reports/FIX-23-MCV拆包落点是地基锚点.md` |
| C-02g | 奴隶矿工出舱段：新工人出现在周边地面（三档全绿） | `RuntimeSlaveMinerSmoke.inl:214`。`inspect()` 对不在 `lastCells` 的新工人要求「在建筑内」或「在渲染窗口 `renderX/Y∈[8,9]` 且 renderMoveActive」；`mode=ore` 即失败 | **已定性**：产品没错。新工人 `id=7` 的 committed cell 是 `(9,9)`（地基内）、起点 `(8,8)`（地基内），但 `subCell=2` 的子格偏移把渲染位放到 `7.75,8.25`，比窗口左界差 0.25 → 假红。窗口 `[8,9]` 是照夹具摆位 `(8,8)` 手算的 | 高：`command` 链条上的长段 | 已改（测试侧）：渲染位 `lround` 取整后判 `runtimeCellDistanceToObjectFootprint == 0`，与产品 `bodyCell` 取整规则一致 | **A** | 简单（单文件单判据） | **部分完成**（`c5d2b6c` test）：`ore` / `no ore` 转绿；`blocked` 档改由 C-02h 阻塞 | `reports/FIX-24-奴隶矿工出舱的子格偏移.md` |
| C-02h | 奴隶矿工出舱 blocked 档：内部工人瞬移 3 格 | `id=14` 从 `9,8` 一步到 `6,6`（3 格外），`render=6,6`、`renderMove=0`、无插值 | **已定性**：`recoverRuntimeCancelledStructureEntry` 只对 `Returning`/`Stored` 豁免奴隶矿工，而离场 Move（目标格被墙圈挡住、`path=0` 即刻完成）被当成失败入场，用半径 6 搜索把身体搬到空地。与重叠重定位无关（`reconcileRuntimeSubcells` 那条读数一条都没打） | 高：它挡住 `command` 整段，且暴露了「入场恢复」与「离场」的语义混淆 | 1 处判定（按任务归属豁免）+ 7 条只读计量 | **A** | 中等 | 1 | 已完成（`7b9f576`） | `reports/FIX-25-奴隶矿工离场不该被当成取消入场.md` |
| C-02i | 奴隶矿工段：挖了装了但货没卸下去 | `Command smoke failed: slave miner: workers did not dig, carry full loads and deposit credits: digging=1 carrying=1 cargo=4 credits=0` —— 计数各发生 1 次、`cargo=4` 仍在、`credits=0` | 未定性。两种可能：夹具等待拍数不足（交付在更晚的拍）或产品真的没把货交进去；`digging=1/carrying=1` 说明前两步是通的，卡在交付/卸载 | 高：这是 `command` 当前唯一阻塞点，清掉即整条转 PASS | 先加读数（谁持有 cargo、卸载守卫拒绝原因），再决定改哪层 | **A** | 中等 | 0 | 待修复（第 24 轮登记） | `reports/FIX-25-奴隶矿工离场不该被当成取消入场.md` §7 |
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
| S1 遗留：`ICM_QUERY`/`ICM_OFF` 取值反写 | **已完成（早于本台账，第 12 轮核对确认无需重开）** | `compat/win32/include/windows.h:1228` 已按 windwingdi.h 校正为 QUERY=1/ON=2/OFF=3，并写明「反写会让 `SetICMMode(dc,ICM_QUERY)!=ICM_OFF` 变成永远碰巧成立的假断言」；`RuntimeTerrainViewportFill.h:75`、`RuntimeRadarPixelStoreWin32.cpp:35` 的断言现在是真的在判 |

---

## 五、本轮（2026-11-13 第 24 轮）打包清单

主题：**「入场恢复」不该吃掉「离场」**。基线 `10/1/0` → 收口 `10/1/0`，零新回归。
报告 `reports/FIX-25-奴隶矿工离场不该被当成取消入场.md`。

- **C-02h 已完成（`7b9f576` fix）**：三次读数、两次自我否定——先按「重叠重定位」查
  （`why=reconcile-relocate` 一条没打，否定），再在 `setRuntimeObjectCell` 抓「跨 >1 格」整体赋值
  （命中 `9,8 → 6,6 resetRender=0`），最后定位到 `recoverRuntimeCancelledStructureEntry`。
  根因：只对 `Returning`/`Stored` 豁免奴隶矿工，而离场 Move 的目标格被墙圈挡住（`path=0` 即刻完成），
  被当成失败入场 → 半径 6 搜索把身体搬到空地。
- **改法边界**：按「任务归属」豁免，不按「目标格在地基外」（试过不成立：恢复时 `prevTarget`
  已被兜底改回自己脚下）。没有放宽成「所有步兵」。
- **留下的读数**：7 条 env-gated（`CONCORD_SLAVE_EMERGENCE_TRACE`），默认静默。
- **新登记 C-02i**：`digging=1 carrying=1 cargo=4 credits=0`，阻塞点后移到验收后半段。

## 六、轮次索引（一行一轮；原文见 `reports/fix-plan-archive.md`）

| 轮 | 日期 | 主题 | 报告 |
|---|---|---|---|
| 24 | 2026-11-13 | 「入场恢复」不该吃掉「离场」 | `reports/FIX-25-奴隶矿工离场不该被当成取消入场.md` |
| 23 | 2026-11-13 | 硬编码坐标窗口 vs 子格几何 | `reports/FIX-24-奴隶矿工出舱的子格偏移.md` |
| 22 | 2026-11-13 | 验收把「测试自己的坐标假设」写死了 | `reports/FIX-23-MCV拆包落点是地基锚点.md` |
| 21 | 2026-11-13 | 建筑吸收器的进门格不该被兜底目标换掉 | `reports/FIX-22-生物反应堆进门格不被兜底换掉.md` |
| 20 | 2026-11-13 | 把「赌排队次序」的断言改成按拍等待 | `reports/FIX-21-混编段按拍等待.md` |
| 19 | 2026-11-13 | A 方案落地——出舱步兵走开，环自然腾空 | `reports/FIX-20-两栖卸载外侧终点.md` |
| 18 | 2026-11-13 | 更正上一轮的结论——不是「有人卡住」，是「先出来的人把环站满」 | `reports/FIX-19-卸载终态是被站着的人占满环.md` |
| 17 | 2026-11-13 | 把「600 拍不放空」拆成八格拒绝表，把结论从「候选格不可用」改写成「第一具出舱者没走开」 | `reports/FIX-18-整仓卸载的八格拒绝表.md` |
| 16 | 2026-11-13 | 把「计划里的 A 方案」用一档读数否掉，换成真能解开死锁的那条边界 | `reports/FIX-17-登船互锁解除与卸载新阻塞.md` |
| 15 | 2026-11-13 | 把「12 人只上 10 人」拆到具体那道门 | `reports/FIX-16-登船互锁的四道门计量.md` |
| 14 | 2026-11-12 | 把两条「读一句话就动手」的旧结论拆到底 | `reports/FIX-15-框选结案与两栖卸载真阻塞点.md` |
| 13 | 2026-11-12 | 一条十二轮没被质疑过的断言，其实从来没跑过产品路径 | `reports/FIX-14-框选断言穿过消息循环.md` |
| 12 | 2026-11-12 | 判定器自身的可信度 | `reports/FIX-13-known-red失败前缀门禁.md` |
| 11 | 2026-11-12 | 关于「可见像素」的断言必须先对焦 | `reports/FIX-12-命中样本落在视口外.md` |
| 10 | 2026-11-12 | 先修那道「假门」 | `reports/FIX-11-被known-red掩盖的新回归.md` |
| 9 | 2026-11-12 | 把「掩码有效」与「真的画了」分开 | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` |
| 8 | 2026-11-12 | 一次被自己的计数器否决的定性 | — |
| 7 | 2026-11-12 | 把 `code-red:needs-metering` 清零口径 | — |
| 6 | 2026-11-12 | 把连红五轮的 `build` 清到底 | — |
| 5 | 2026-11-12 | 多谓词断言必须逐项计量 | — |
| 4 | 2026-11-12 | 夹具缺口 + 观感硬伤，两条都不动模拟层 | — |
| 3 | 2026-11-12 | 两条判红的根因都在断言口径，不在产品 | `reports/FIX-04-两条断言的几何口径.md` |
| 2 | 2026-11-12 | 回归门禁的「资产缺口 vs 产品缺陷」口径 | `reports/FIX-03-回归门禁口径三连.md` |
| 1 | 2026-11-12 | — | — |

> 第 1 / 7 / 8 轮等未单独出报告的轮次，细节在 `progress/RUNLOG.md` 同轮小节。
