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
> 最近更新：2026-11-13 14:00（第 23 轮收口）；
> 第 23 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
> **C-02g 部分完成**：出舱判据把渲染窗口硬编码成 `[8,9]`，而步兵按子格站位——首拍斜向一步
> `(8,8)→(9,9)` 的渲染位是 `7.75,8.25`，差 0.25 判假红。改为「渲染位取整后判在地基内」，
> `ore` 与 `no ore` 两档转绿（含替补工人）。新登记 **C-02h**：`blocked` 档出现「工人瞬移 3 格」
> （`id=14` 从 `9,8` 直接到 `6,6`、无插值），疑为通用步兵重叠重定位把内部工人挪出墙圈。
> 报告 `reports/FIX-24-奴隶矿工出舱的子格偏移.md`。
>
> 上一轮收口：2026-11-13 13:45（第 22 轮收口）；
> 第 22 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
> **C-02f 已完成**：MCV 拆包的六个谓词里只有「落点」不成立——验收要建筑左上角 `(6,6)`，
> 产品按 `runtimePlacementAnchorCellForFootprint` 落在地基锚点 `(7,7)`。改判「落在旧地基格清单内」
> 后四阵营全过（含被占领的 `GACNST`→`AMCV`）。新登记 **C-02g**：奴隶矿工出舱段
> （`RuntimeSlaveMinerSmoke.inl:214`，新工人既不在建筑内也不在出舱渲染窗口）。
> 报告 `reports/FIX-23-MCV拆包落点是地基锚点.md`。
>
> 上一轮收口：2026-11-13 13:40（第 21 轮收口）；
> 第 21 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归。**C-02e 已完成**：生物反应堆段的两人
> 不是「没派路」也不是「被地基挡」，而是**进门格被寻路器的兜底目标换成了门外邻格**——
> `applyRuntimeMovePathResult` 的 blocked-goal 豁免名单只认 `WorldObjectKind::Unit` 的 host，
> 建筑吸收器（反应堆/碉堡）不在内，两名乘客各自被换成对方所在的格子，互堵死且不自愈。
> 补 `runtimeBuildingAbsorberEntryKeepsGoal` 后 `power=650 aboard=5`，五人全部真实进入。
> 新登记 **C-02f**：MCV repack 段（`RuntimeMcvRepackSmoke.inl:145`），属暴露出来的旧问题。
> 报告 `reports/FIX-22-生物反应堆进门格不被兜底换掉.md`。
>
> 上一轮收口：2026-11-13 13:30（第 20 轮收口）；
> 第 20 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归。**C-02d 已完成**：读数证明
> `cargoBeforeAction=4 / boatMovingBefore=0 / 无 host-busy` —— 卸载跑了，但一趟只放一件，
> 且船货顺序取决于 boarding 到达顺序，「按一下就断言 IFV 已出舱」实际在赌次序。改按拍推进后混编段转绿。
> 新登记 **C-02e**：生物反应堆段（AI action 62，五个步兵 800 拍未全部进入）。该路径走
> `cellDistanceToObjectFootprint` 而非 `runtimeTransportTransferBodiesClear`，且零 transport trace，
> 与本轮改动无关。报告 `reports/FIX-21-混编段按拍等待.md`。
>
> 上一轮收口：2026-11-13 13:20（第 19 轮收口）；
> 第 19 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归。**C-02c 已完成**：两栖卸载给步兵
> 规划半径 2 外侧终点（`4f13ccc`），12 名步兵整仓下船转绿；坦克段与其余 9 条 smoke 全绿。
> 新登记 **C-02d**：混编段「载入 IFV 的整车下船」——一次动作后 IFV 仍未出舱（`ifv=null`、`boatCargo=3`），
> 该夹具在 23,23 周边零 `unload:` trace，说明 `unloadRuntimeUnitTransportMotion` 顶部就返回了，
> 已排除本轮引入。报告 `reports/FIX-20-两栖卸载外侧终点.md`。
>
> 上一轮收口：2026-11-13 13:10（第 18 轮收口）；
> 第 18 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
> **上一轮结论被推翻并更正**：`unload:bodies` 的 `ticks=66/66` 不是「卡住」，而是 egress 的**第一拍**——
> 去掉重键只含「人+格子+原因」，读到的是首次命中时刻，不是终态。加 120 拍时间桶后（tick=1680）真形态是：
> **11 名已出舱者 `bstate=none`、`moving=0`、位置=格子中心，把 8 个邻格全占满**，最后一名 `id=7`
> 找不到任何一条起点干净的走廊。结构性原因是两栖卸载**不规划外侧终点**（`remainingPath` 只在
> `!runtimeAmphibiousTransport` 时计算），出舱就地停靠；8 格 × 0.5 身体互斥的实际容量远小于名义 32 子格。
> 下一轮取 A：给两栖卸载也规划半径 2 外侧终点（全水时退回就地停靠）。报告
> `reports/FIX-19-卸载终态是被站着的人占满环.md`。
>
> 上一轮收口：2026-11-13 13:00（第 17 轮收口）；
> 第 17 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
> **C-02c 已收窄**：卸载侧逐格给原因后，「600 拍不放空」变成两阶段读数——①八台 MTNK 占住舱门口八格时
> 八格全被 passability 拒（`occupied=14..21`，属预期的「堵住」判定）②挪开后**第一具出舱者（id=13）
> 停在船体原点没走开**，后续所有人的扫掠段起点都落在它身体里（`distance²=0`），于是全员等它。
> 出舱者不在 `pendingTransportTargets`，第 16 轮的同伴豁免对它不生效。下一步要量挡住者自己的
> 行为状态（`ticks`/`path.size()`/`moveTarget`）才能定「egress 渲染步卡住」还是「egress 后走不到
> 半径 2 终点」。报告 `reports/FIX-18-整仓卸载的八格拒绝表.md`。
>
> 上一轮收口：2026-11-13 12:50（第 16 轮收口）；
> 第 16 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，`RED-NEW=0`（`command` 的失败文案按新阻塞点
> 同步改第 4 列，属计划内的 cause-changed）。**登船互锁修好了**：12 名步兵 `aboard=10/12 → 12/12`。
> 根因不是运力、寻路、地形层或子格，而是 `runtimeTransportTransferBodiesClear` 的 foot-to-foot
> 最小间距 0.5：一格四子格，四人同格时彼此扫掠段起点距离只有 0.002~0.10，且四人同拍都在往板上挤
> → 谁也不能先动。**计划里的 A 方案（每拍只放一人）被读数否决**——单独一个动仍被站着/挤着的同伴挡住；
> 改成「同船步兵同伴不算路障」（载具与外部单位仍严格互斥，坦克段 `aboard=4`/`exits` 不重合照旧绿）。
> 源码 `498ae37` fix + `c7a1f2f` test。**新登记 C-02c**：整仓步兵卸载按拍推进 600 拍仍不放空
> （原生问题，登船入舱会清 `pendingTransportTargets`，本轮豁免对它不生效）。报告
> `reports/FIX-17-登船互锁解除与卸载新阻塞.md`。
>
> 第 16 轮开工：基线 **`10/1/0`**（`20261113-121025`，与第 15 轮收口逐条一致，`command` 前缀
> `twelve infantry did not board` 未漂移）。简单区仍为空（S-08 缺静止连拍入口、S-13 卡守卫产物、
> M-19 属资产侧），按「不为凑批量拆中等项」的既有纪律，本轮只做唯一 remaining known-red
> **C-02**，取 A 方案（复杂，单独成轮，先写方案再动手）。
>
> 上一轮收口：2026-11-13 10:55（第 15 轮收口）；
> 第 15 轮：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
> **C-02 根因收窄**：给登船路径加 `CONCORD_TRANSPORT_TRACE=1` 原因位后，卡点不是寻路/地形/子格，
> 也不是容量，而是**四个人同拍停在 (15,15) 同格互相锁死**——`runtimeTransportTransferBodiesClear`
> 的 foot-to-foot 最小间距 0.5 让每个人都在别人的扫掠走廊里，谁也不能先动。
> 报告 `reports/FIX-16-登船互锁的四道门计量.md`。
>
> 第 15 轮开工：基线 **`10/1/0`**（`20261113-095359`，与第 14 轮收口逐条一致）。
> 简单区仍为空（S-08 缺「静止连拍」入口、S-13 仍卡守卫产物），按纪律不为凑批量拆中等项；
> 本轮唯一 remaining known-red 是 `command`（C-02 混编登船 10/12），按「复杂单独成轮」只做它。
>
> 第 14 轮（`10/1/0` → **`10/1/0`**，零新回归，产品行为零改动，三条 `test:`）：
> **M-02 结案为非缺陷**：命中框 = 画面框外扩 3px（`InflateRect(+3)`），而 `spriteBounds` 已被
> `RuntimeUnitSelectionAlignmentSmoke` 逐像素证明等于真实绘制框；样本 `#9003` 的画面在框内真有 7px。
> **C-02 阻塞点后移**：单位船卸载是逐人推进（一次点击只放一辆），旧断言「一次点击全员下船」
> 结构上不可能成立；修掉后卡在 12 名步兵登船 10/12。报告 `reports/FIX-15-框选结案与两栖卸载真阻塞点.md`。
>
> 第 13 轮收口：`10/1/0` → **`10/1/0`**，零新回归，产品代码零改动。
> 第 13 轮：基线 `10/1/0`（`20261112-201018`）→ 收口 **`10/1/0`**，零新回归，产品代码零改动。
> 主题：**框选断言原来在同义反复**——它自己重实现了一遍「包围盒 ∩ 矩形」再 applySelection，
> 产品拖选路径零覆盖。改为三条真实消息（DOWN/MOVE/UP）穿过 `runtimeWindowProc` 后，
> 顺带量出 M-02 的真实形态：`bbox=4 center=3 bboxOnly=1`，是**包围盒含精灵帧留白**，
> 不是台账里写的「世界坐标 vs 表面坐标错位」。报告 `reports/FIX-14-框选断言穿过消息循环.md`。
> 简单区仍为空（S-08 须与 M-03 合批、S-13 仍阻塞在守卫产物），按纪律不为凑批量去拆中等项。
>
> 第 12 轮收口：`10/1/0` → **`10/1/0`**，零新回归，产品代码零改动。
> 本轮主题：**给判定器补一道「红的是同一件事」的闸**——S-12 落地，known-red 第 4 列存失败前缀，
> 前缀对不上就判 `RED-NEW(cause-changed)` 并计入退出码。唯一 known-red 仍是 `command`
> （C-02 两栖卸载，复杂，单独成轮）。报告 `reports/FIX-13-known-red失败前缀门禁.md`。
>
> 第 12 轮开工：基线 `10/1/0`（`20261112-200207`），与第 11 轮收口一致。
>
> 第 11 轮收口：`9/2/0` → **`10/1/0`**，零新回归。
> 本轮主题：**把「空 span 表两种语义」钉死**。M-12 加四桶计量后当场定性——不是可见性门错杀，
> 也不是谁挡住谁，而是**被采样的建筑整栋落在 map viewport 之外**（`drawsOffView=1 / visiblePixels=0`），
> 拿它去断言「点得到」构造性不可满足，与 M-18 同一条纪律。**`interaction` 转 PASS**，
> 唯一 known-red 只剩 `command`（C-02 两栖卸载，复杂）。
>
> 第 10 轮收口：`8/3/0` → **`9/2/0`**，零新回归。
> **`render` 十轮来首次转 PASS**（M-21 是探针把「帧」当「拍」，产品零改动）；
> interaction 越过一道**被 known-red 掩盖的新回归**（S-11）后，回到原登记点 M-12，
> 而 M-12 的问法本轮被计量改写了——不是「谁挡住谁」，是「空 span 表有两种语义」。
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
| S-08 | EVO-06 世界重绘只读计量 | 帧循环每 tick 无条件 `InvalidateRect`+`UpdateWindow`，不知多少次真改了画面 | **第 14 轮已定位到行**：主循环 `if (tickAdvanced) state.repaintRequested = true;` + `continuousRuntimeFrame = world loaded && !IsIconic` → 进图后每帧整窗 `InvalidateRect`；`reuseCachedFrame` 因为 `repaintRequested` 恒真而永远走不到 | 中：为「脏区驱动」提供基线数字 | 把「本帧是否 reuse / 连续相同帧数 / 每秒 Invalidate 次数」接进现有 `RuntimeFrameDiagnostics` 周期输出 | **B** | 简单 | 待修复（方案见 FIX-15 §3；与 M-03 同源，先计量后动提交条件） | `reports/FIX-15-框选结案与两栖卸载真阻塞点.md` |
| S-09 | FPS 叠加层默认常显（U-17） | 每次提交帧后无条件画左下 96×22 `FPS: 60` 面板，正式版没有这个面板 | 该面板只为自测而加，`drawRuntimeFpsDisplay` 的三个调用点没有任何开关；`RuntimeMainFrameContract` 只断言面板**矩形**存在，不断言「画了」 | 高：正式版观感的第一眼硬伤，纯视觉、无模拟耦合 | 加 1 个偏好位 + 3 处调用点门控（`--show-fps` / `[Options] ShowFps`） | **S** | 简单 | 已完成（`c1ccfe6`） | `reports/FIX-05-夹具缺口与FPS叠加层.md` |
| S-10 | 启动日志把零售自带的重复建筑 id 报成异常 | 每次启动 `core` 都打印 `Duplicate building id ignored by capability index: [NAPSYA]` | 零售 `rulesmd.ini` 的 `[BuildingTypes]` 里 `NAPSYA` 确实出现两次（185 / 241），`rebuildTypeIndex` 按「重复即告警」处理，但「先到先得」正是零售语义（两处指向同一 section），不是数据损坏。告警缺 item 下标，也没区分 `Corrupt` 与 `Duplicate` 两种性质 | 低中：日志噪声，且会掩埋真正的解析重复 | 1 处消息分级（带 item 下标 + 降为 data-note） | **C** | 简单 | 已完成（`5ce280b`） | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §3 |

> **简单区现状（第 15 轮开工核对）**：S-01~S-12 全部已完成或已废弃；在册简单项只剩
> S-08（须与 M-03 合批，且缺「静止连拍」入口——先造入口再谈读数）、
> S-13（结构守卫基线陈旧，卡在缺 `--inventory/--trace` 产物）、
> M-19（NATBNK 缺 temperate 美术，资产侧，不阻塞任何门禁）。
> **仍有第 12 轮那两条核对结论**：`ICM_QUERY/ICM_OFF` 反写**早已修复**（`windows.h:1228`），
> 不作为待办重开；U-16 的「全局 pin 部署目标」属复杂，321 个测试目标要跟编，留作单独成轮。

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | 状态 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|
| S-11 | 速度阶梯改了，两处断言表还在钉旧哨兵 | interaction 的 ESC 菜单断言红在 `gameSpeedSlider`；`gameSpeedSlider=yes/no/no/yes/yes` → 几何/拖拽/键盘三组绿，**坐标组与全局节奏组红**。support-power 冒烟同样在 `initialRate != 0` 上判 fail | **已定性：断言表过期，不是产品缺陷**。`ffdd7c5` 把 7 档改为 31/37.5/46.88/62.5/93.75/187.5/281.25（6 档 = 5 档×1.5，`unlimited()` 恒 false）；`RuntimeShell.cpp:37667` 仍写 `== 0`、`expectedGameSpeedPacing` 末位仍写 `0`、`RuntimeSupportPowerSmoke.inl` 仍留 `initiallyUncapped/changedUncapped` 两支 | 高：它挡在 interaction 冒烟**靠前**的 ESC 菜单段，不清掉 M-12 永远测不到；清掉后该条才有信号价值 | 两文件共 ~15 行：两张表末位改 281、拆掉 uncapped 分支 | **S** | 简单 | 已完成（`d69980d`；interaction 越过 ESC 菜单段，回到 M-12） | `reports/FIX-11-被known-red掩盖的新回归.md` §1 |
| S-13 | 结构守卫基线列着已删文件 | `tools/structure/structure-baseline.json` 仍列 U-15 已删的两个文件；守卫是开发期静态检查（不在构建链里），本机没有它的 `--inventory/--trace` 产物，从没跑过 | 基线是「人工审过的精确清单」，删除文件后没回写；守卫本身没有生成产物的入口脚本 | 低：守卫当前不参与判定，脏基线只会在下次跑守卫时误报 | 需先补产物（守卫的 inventory/trace 由谁生成尚未查清），再重生成基线 | **C** | 简单（但阻塞在产物） | 待修复（第 12 轮登记，来自 `U-15` §遗留） | `reports/U-15-选中指示与矿量格.md` §遗留 |
| S-12 | known-red 会吞掉「失败原因被换掉」的新回归 | S-11 那次：交互条本来就红，速度表回归把红点从 footprint 前移到 ESC 菜单，三态判定仍报 KNOWN-RED。**只有人读日志才发现**，机器判定完全盲 | `regress.sh` 对已登记 id 只看「非零退出码」，不比对失败文案；`known-red.tsv` 也只记一句自由文本原因，没有可比对的锚 | 高：这是回归门禁可信度的地基——现在的 KNOWN-RED 只保证「红」，不保证「红的是同一件事」 | 小：`known-red.tsv` 第 4 列存失败前缀，`regress.sh` 只对该行做字符串包含比对；不一致即判 RED-NEW 并把两侧前缀打进报告 | **A** | 简单 | 已完成（`50d3a85`；自测两向：bogus 前缀→cause-changed、空前缀→KNOWN-RED+告警） | `reports/FIX-13-known-red失败前缀门禁.md` |

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
| C-02g | 奴隶矿工出舱段：新工人出现在周边地面 | `RuntimeSlaveMinerSmoke.inl:214`。`inspect()` 对不在 `lastCells` 的新工人要求「在建筑内」或「在渲染窗口 `renderX/Y∈[8,9]` 且 renderMoveActive」；`mode=ore` 即失败 | **已定性**：产品没错。新工人 `id=7` 的 committed cell 是 `(9,9)`（地基内）、起点 `(8,8)`（地基内），但 `subCell=2` 的子格偏移把渲染位放到 `7.75,8.25`，比窗口左界差 0.25 → 假红。窗口 `[8,9]` 是照夹具摆位 `(8,8)` 手算的 | 高：`command` 链条上的长段 | 已改（测试侧）：渲染位 `lround` 取整后判 `runtimeCellDistanceToObjectFootprint == 0`，与产品 `bodyCell` 取整规则一致 | **A** | 简单（单文件单判据） | **部分完成**（`c5d2b6c` test）：`ore` / `no ore` 转绿；`blocked` 档改由 C-02h 阻塞 | `reports/FIX-24-奴隶矿工出舱的子格偏移.md` |
| C-02h | `blocked` 档：工人瞬移 3 格（从 9,8 直接到 6,6） | `RuntimeSlaveMinerSmoke.inl:218`「worker teleported instead of walking」。`id=14 prev=9,8 cell=6,6 renderMove=0 render=6,6 mission=Guard status="no ore"`；第 150 拍 `id=18` 在 (9,8) 出生，约 194 拍后 `id=14` 从同格一步到 3 格外且无插值 | **根因假设（未验证）**：通用步兵重叠重定位把人挪到最近可走格；墙圈封死时空位搜索一路放大到 (6,6)。出生点重复的直接原因：`findRuntimeSlaveMinerWorkerSpawnCell` 的半径 0 检查只看格子不看子格 | 高：`command` 新阻塞点 | 先在 `setRuntimeObjectCell`/重定位入口加 `why=relocated from/to/radius` 只读位确认路径；确认后分「产品该修（出舱中的工人不该被挪出建筑）」与「夹具该修（出生点避开已占子格）」两条路，**别混改三档** | **A** | 中等（先量后改） | 待修复（第 23 轮登记） | `reports/FIX-24-奴隶矿工出舱的子格偏移.md` §5 |
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

## 五、本轮（2026-11-13 第 23 轮）打包清单

主题：**硬编码坐标窗口 vs 子格几何**。基线 `10/1/0` → 收口 `10/1/0`，零新回归，产品零改动。
报告 `reports/FIX-24-奴隶矿工出舱的子格偏移.md`。

- **C-02g 部分完成（`c5d2b6c` test）**：失败工人的 `committed cell` 与起点都在地基内，
  但 `subCell=2` 的偏移把渲染位放到 `7.75,8.25`，比硬编码窗口 `[8,9]` 左界差 0.25。
  改为渲染位取整后判地基，`ore` / `no ore` 两档转绿（含替补工人）。
- **新登记 C-02h**：`blocked` 档「工人瞬移 3 格」（`9,8` → `6,6`，无插值、`render=6,6`），
  疑为重叠重定位；出生点重复的直接原因是出生格检查只看格子不看子格。
- **本段三档不许混改**：`ore` / `no ore` 已绿，改动只许影响 `blocked` 的墙圈场景。
- **同源问题盘点**：C-02d 赌次序、C-02f 赌左上角、C-02g 赌渲染窗口——夹具一侧的通用改法是
  「期望值取几何（地基/格子/集合成员），不取常量」。

## 五-旧、第 22 轮（2026-11-13）打包清单（存档）

主题：**验收把「测试自己的坐标假设」写死了**。基线 `10/1/0` → 收口 `10/1/0`，零新回归，产品零改动。
报告 `reports/FIX-23-MCV拆包落点是地基锚点.md`。

- **C-02f 已完成（`7c02812` test）**：六个谓词逐项打印后只有落点不符（`7,7` vs 验收的 `6,6`）。
  产品按地基锚点落点、再找可走格；验收钉的是建筑左上角。改判「落在旧地基格清单内」后四阵营全过。
- **不做的事**：不改产品去落左上角（会让放置锚点规则自相矛盾），也不把锚点算法抄进测试
  （会随产品演进假红）；锚点只出现在失败文案里。
- **新登记 C-02g**：奴隶矿工出舱段（`RuntimeSlaveMinerSmoke.inl:214`），根因假设尚未验证。
- **链条观察（延续第四轮）**：阻塞点全是「第一次运行」的段落，形态是「多谓词压成一句 + 测试自己的
  坐标/次序假设写死」。C-02d 赌船货次序、C-02f 赌建筑左上角，属同一类。

## 五-旧、第 21 轮（2026-11-13）打包清单（存档）

主题：**建筑吸收器的进门格不该被兜底目标换掉**。基线 `10/1/0` → 收口 `10/1/0`，零新回归。
报告 `reports/FIX-22-生物反应堆进门格不被兜底换掉.md`。

- **C-02e 已完成（`d6654eb` fix + `8dfc9f4` test）**：三次采样把三种候选逐个否掉——
  不是「从未派路」（`after-issue` 五人 `path=1`），不是「被地基挡」（目标就是地基格），
  而是第 20 拍前后目标被换成**对方的格子**。根因是 `goalAdjusted` 豁免名单只认载具 host。
  补谓词后 `pending=0 power=650 aboard=5`。
- **`8dfc9f4`**：`CONCORD_BIOREACTOR_TRACE=1` 打地基格清单 + 每人 `moveTarget/entryCell/bstate/blocked/pathReq/path`，
  按 before-unload / after-unload / after-issue / 1·2·5·20·100·400 拍采样。默认静默。
- **顺带确认**：五人抢同一地基格**不是**缺陷（坦克碉堡段也如此），进人本身是按拍串行的。
- **新登记 C-02f**：MCV repack 段（旧问题被暴露，与本次改动无关）。
- **链条观察（延续）**：`command` 每转绿一段就露出下一段，且下一段全是「第一次运行」；
  第 19→21 轮连续三轮都是这种暴露式阻塞。

## 五-旧、第 20 轮（2026-11-13）打包清单（存档）

主题：**把「赌排队次序」的断言改成按拍等待**。基线 `10/1/0` → 收口 `10/1/0`，零新回归。
报告 `reports/FIX-21-混编段按拍等待.md`。

- **C-02d 已完成（`107b06b` test + `2c3616c` test）**：读数 `cargoBeforeAction=4 / boatMovingBefore=0 /
  无 host-busy` 把上一轮的两种解释（船没停稳 / 3 件是初始值）双双否掉——卸载跑了，一趟只放一件，
  而船货顺序 = boarding 到达顺序。改按拍推进到 IFV 出舱，断言本体（乘员仍在车内、cell 一致、gunner>=0）一条没放。
- **`2c3616c`**：卸载顶部守卫被拒时补 `unload:host-busy`（四条件 + mission + cargo），
  以后「整次卸载没发生」不再是一句「什么都没发生」。
- **新登记 C-02e**：生物反应堆段（AI action 62，五步兵 800 拍未全进）。已排除本轮改动
  （走 `cellDistanceToObjectFootprint`，零 transport trace）。
- **链条观察**：`command` 自第 13 轮卡在链条中段，后面段落全是「第一次运行」；
  每次转绿一段露出下一段。下一轮先列段落清单，再决定逐段修还是整批改「一次点击 = 一步到位」。
- **简单区仍空**（S-08 缺静止连拍入口、S-13 卡守卫产物、M-19 资产侧）。

## 五-旧、第 19 轮（2026-11-13）打包清单（存档）

主题：**A 方案落地——出舱步兵走开，环自然腾空**。基线 `10/1/0` → 收口 `10/1/0`，零新回归。
报告 `reports/FIX-20-两栖卸载外侧终点.md`。

- **C-02c 已完成（`4f13ccc` fix）**：`remainingPath` 的外侧终点搜索对「两栖船 + 步兵乘客」开启
  （`!runtimeAmphibiousTransport || runtimeInfantryUsesGroundSubcells(probe)`）。载具不变
  （坦克段要求 `cell` 距船体 ≤1.5、`exits` 互不重合），全水时 `findRuntimePath` 返回空自动退回就地停靠。
  `futureFootGoals` 同步对两栖船统计，避免同一外格重复派给多人。
- **读数**：`full infantry hold did not unload after 600 ticks` 消失，12 名全部下船；
  坦克段（`aboard=4`/`exits`/深水拒卸/跨水/save-load/老兵度）与其余 9 条 smoke 全绿。
- **`7361f55` test**：混编段失败文案拆成六个条件字段，一次读数定性
  （`ifv=null / riderAlive=0 / boatCargo=3`）。
- **新登记 C-02d**：混编段 IFV 未出舱。已排除本轮引入（该夹具零 `unload:` trace，说明没进候选格循环）。
- **简单区仍空**（S-08 缺静止连拍入口、S-13 卡守卫产物、M-19 资产侧）。

## 五-旧、第 18 轮（2026-11-13）打包清单（存档）

主题：**更正上一轮的结论——不是「有人卡住」，是「先出来的人把环站满」**。
基线 `10/1/0` → 收口 `10/1/0`，零新回归，产品行为零改动。报告 `reports/FIX-19-卸载终态是被站着的人占满环.md`。

- **`ff5cad2` test（只读）**：挡住者带出自身 `bstate/kind/transfer/ticks/path/target/render`；
  卸载 trace 去重键加 **120 拍时间桶**，行首打 `tick=`。
- **上一轮结论被推翻**：`ticks=66/66` 是 egress 第一拍（还没跑），不是冻住。只按
  「人+格子+原因」去重会把首次命中变成结论。
- **真终态**（tick=1680）：11 名已出舱者 `bstate=none`、`moving=0`、`render` 落在格子中心，
  8 个邻格各站一个，最后一名 `id=7` 八条走廊的起点全被占。
- **结构性原因**：两栖卸载不规划外侧终点（`remainingPath` 只在 `!runtimeAmphibiousTransport` 时算），
  出舱就地停靠；而步兵子格 0.5 间距 + 走廊扫掠 0.5 阈值，实际容量远小于 8×4。
- **下一轮取 A**：两栖卸载也规划半径 2 外侧终点（全水退回就地停靠）。动手前先量
  「半径 2 的 16 格可用数」与「站定者 `subCell` 是否 `-1`」。
- **简单区仍空**（S-08 缺静止连拍入口、S-13 卡守卫产物、M-19 资产侧）。

## 五-旧、第 17 轮（2026-11-13）打包清单（存档）

主题：**把「600 拍不放空」拆成八格拒绝表，把结论从「候选格不可用」改写成「第一具出舱者没走开」**。
基线 `10/1/0` → 收口 `10/1/0`，零新回归，产品行为零改动。报告 `reports/FIX-18-整仓卸载的八格拒绝表.md`。

- **C-02c 第一步（`22fea50` test，只读）**：`unloadRuntimeUnitTransportMotion` 的候选格循环从两条合并
  `continue` 拆成六个拒绝点（`passable/level/subcell/clearance/transition/bodies` + 每拍一条 `no-exit`），
  `passable` 分支附带 `occupied=<id>/level/hullLevel/probe=<type>`。
- **读数把两件事分开了**：①八台 MTNK 占住舱门口时八格全被 passability 拒（`occupied=14..21`），
  这是「堵住」的正确判定，不是缺陷；②挪开后**第一具出舱者 id=13 停在船体原点**（`distance²=0`、
  `moving=1`），后续 `id=7` 的扫掠段起点落在它身体里 → 全员在等它。
- **口径修正**：C-02c 不再是「舱门口被河岸/水面判据挡住」或「候选格几何不可达」，而是
  **「第一个出舱的没走开」**——与 C-02a「进舱方向拥挤」同族、方向相反。
- **没做的事写在明处**：本轮不猜成因。要区分「egress 渲染步卡住」与「egress 后走不到半径 2 终点」，
  得先量挡住者自己的 `ticks/path.size()/moveTarget`，那是下一轮第一件事。
- **简单区仍空**（S-08 缺静止连拍入口、S-13 卡守卫产物、M-19 资产侧），继续不为凑批量拆中等项。

## 五-旧、第 16 轮（2026-11-13）打包清单（存档）

主题：**把「计划里的 A 方案」用一档读数否掉，换成真能解开死锁的那条边界**。
基线 `10/1/0` → 收口 `10/1/0`，`RED-NEW=0`。报告 `reports/FIX-17-登船互锁解除与卸载新阻塞.md`。

- **C-02a 登船互锁 → 已修复（`498ae37` fix）**：`runtimeTransportTransferBodiesClear` 加「被谁挡住」
  只读位（id/kind/格子/线段距离 + `selfPending/otherPending/moving`）后，读数 `otherPending==host`
  且 `moving=1` 证明是**四名同船排队者同拍互挤**，不是「有人站着挡路」。
  **A 方案（每拍只放一人）当场被否决**：单独一个动时扫掠段起点仍落在同伴身体里（0.002~0.10 < 0.5）。
  改为豁免「同为步兵 + 同船排队」的同伴；载具、非本船乘客、敌方单位仍严格互斥。
  `aboard=10/12 → 12/12`，坦克段 `aboard=4` / `exits` 不重合全绿。
- **C-02 的卸载断言 → 已修（`c7a1f2f` test）**：第 176 行「按一下就整仓放空」在结构上不可能成立
  （卸载逐人推进），照坦克段第 121~137 行的写法改成按拍推进到放空。
- **C-02c 整仓卸载 → 新登记（复杂）**：改成按拍后 600 拍仍未放空，`moved #7 to 15,15`。
  已排除「本轮引入」（登船入舱会 `erase(pendingTransportTargets)`，豁免对卸载不成立）。
- **简单批为什么仍是空的**：S-08 缺「静止连拍」入口、S-13 卡守卫 `--inventory/--trace` 产物、
  M-19 属资产侧。继续按「不为凑批量拆中等项」执行。
- **没做的事写在明处**：C-02c 只登记不动手——它要的卸载侧只读位（9 个候选格逐个记拒绝原因）
  是另一条独立链路，按「复杂项单独成轮、先写方案」留到下一轮。

下一轮起手：**C-02c**（卸载候选格九格逐项计量 → 判「舱门口被水面/岸线判据挡住」还是
「候选格几何不可达」）；其次 **S-08**（先造 `CONCORD_IDLE_REDRAW_TRACE` 静止连拍入口，再谈 M-03 门）。
剩余 known-red 仍只有 1 条（`command`，前缀已改为 `full infantry hold did not unload`）。

## 五-旧、第 15 轮（2026-11-13）打包清单（存档）

主题：**把「12 人只上 10 人」拆到具体那道门**。基线 `10/1/0` → 收口 `10/1/0`，`RED-NEW=0`，
产品行为零改动。报告 `reports/FIX-16-登船互锁的四道门计量.md`。

- **C-02 → 根因已定位**（`94fbc71`，复杂，test:）：`advanceRuntimeUnitTransportBoarding` 原先把
  `beginRuntimeTransportGroundTransfer` 的返回值 `(void)` 丢掉，于是「转移被拒」与「还没走到」
  在调用方完全同形，日志只剩 `status=moved`。加 `CONCORD_TRANSPORT_TRACE=1` 原因位后读数：
  `transfer:bodies id=9/10/11/12 at=15,15 hull=16,16` → 四人同格互锁（foot-to-foot 阈值 0.5），
  既不是寻路、地形层、子格耗尽，也不是运力。
- **简单批为什么仍是空的**：S-08 的前置（静止连拍入口）未造，S-13 仍卡守卫产物；
  S-01~S-12 已清。继续按「不为凑批量拆中等项」执行。
- **没做的事写在明处**：本轮只在 T+45 前完成计量与读数；两条候选改法（A 串行化 / B 放行同伴）
  方向相反且都要动模拟层排队，按「复杂单独成轮」留到下一轮，先写方案再动手。

下一轮起手：**C-02 取 A 方案**——同一 host 的整船转移每拍只放一人（按 instanceId 定序），
并补「同格四人有限拍内全部进舱」断言；坦克段（`aboard=4`、`exits` 互不重合）必须同时绿。
其次 **S-08**（先造 `CONCORD_IDLE_REDRAW_TRACE` 静止连拍入口，再谈 M-03 门）。

## 五-旧、第 14 轮（2026-11-12）打包清单（存档）

主题：**把两条「读一句话就动手」的旧结论拆到底**。基线 `10/1/0` → 收口 `10/1/0`，`RED-NEW=0`，
产品行为零改动。报告 `reports/FIX-15-框选结案与两栖卸载真阻塞点.md`。

- **M-02 → 已废弃（非缺陷）**（`e7cbfa8`，简单，test:）：补上「画面矩形」这一维后读数
  `artOutside=0 artOnly=0`，样本 `#9003` 的 `art=(506,484,558,520)`、`artInBand=7px`；
  而 `bounds=(503,481,561,523)` 四边各差 3 —— `bounds` 就是 `runtimeUnitSelectionBoundsForSprite`
  的 `InflateRect(+3)`，`spriteBounds` 已被 `RuntimeUnitSelectionAlignmentSmoke` 逐像素证明
  等于真实绘制框。结论：擦边容差，不是坐标错位、也不是幽灵框。留一条反向断言防「幽灵框」回归。
- **C-02 → 阻塞点后移**（`3e51fd0`，复杂，test:）：单位船卸载逐人推进（一趟只放一个后 `break`），
  旧冒烟按「一次点击全员下船」同步断言 → 结构上永不成立。改成按拍等待后**坦克段全绿**
  （含深水拒卸/跨水/save-load/生命老兵度保持），失败点落到混编段装船 `10/12`（2 人停在 15,15）。
  `known-red.tsv` 前缀同步改为 `twelve infantry did not board`。
- **S-08 / M-03 → 方案已写、本轮不动手**：机制钉到行（`tickAdvanced → repaintRequested` +
  `continuousRuntimeFrame` → 每帧整窗 `InvalidateRect`，`reuseCachedFrame` 永不到达）。
  两条候选路线（场景签名门 / 像素差量门）与各自的坑写在报告 §3；按「呈现层改动单独成轮」留到下一轮，
  顺序是先 S-08 出读数再动提交条件（漏字段的代价是冻帧）。
- **简单批为什么仍是空的**：S-01~S-12 已清；在册简单项只剩 S-08（与 M-03 同源，单独做是空计数器）
  与 S-13（阻塞在守卫 `--inventory/--trace` 产物）。不为凑批量拆中等项。

移出本批：C-02 的「步兵登船 10/12」——已定性为独立问题（入口排队 vs 几何阈值，改法相反），
登记为下一轮单独计量，不在本轮硬啃。

下一轮起手：**C-02 第二步**（在 `runtimeTransportBoardingAccessBodyClear` /
`beginRuntimeTransportGroundTransfer` 拒绝分支按 id 记账，先钉「第一个人为什么被拒」）→
**S-08 计量**→ 再谈 **M-03 门**。

**S-08 的前置条件（本轮查清、不能跳）**：现有 11 条回到里没有任何一条**静止场景连拍多帧**的入口
（`result` 的记分动画在动、`render` 每帧都在换探针位、`interaction` 只画几帧就断言），
而 S-08 要的正是「同一静止画面连拍 N 帧、其中多少帧像素完全一致」。
所以 S-08 的落地顺序是：先加一个 `CONCORD_IDLE_REDRAW_TRACE=1` 的静止连拍入口（进图后不输入、
连拍 120 帧、对后台缓冲按 97 dword 采样哈希），再把这个比例接进 `RuntimeFrameDiagnostics`。
没有这一步，写出来的只是「一个没人读的计数器」——这也是前几轮一直没动它的原因。

## 五-旧、第 13 轮（2026-11-12）打包清单（存档）

主题：**一条十二轮没被质疑过的断言，其实从来没跑过产品路径**。基线 `10/1/0`（`20261112-201018`），
收口同结果，零新回归，**产品代码零改动**（只改冒烟）。报告 `reports/FIX-14-框选断言穿过消息循环.md`。

- **M-02 → 已计量（`07e6a71`，中等，test:）**：`interaction` 的「Box selection」断言原来是
  **自己重实现了一遍**「包围盒 ∩ 矩形」再直接 `applySelection`，产品拖选路径
  （`handleRuntimeMapLeftPointerUp` → `boxProjectionItems`）一次都没被执行，链路整条断掉它也绿。
  改为 `WS_POPUP` 不上屏窗口 + `PostMessageW(Wm_LBUTTONDOWN/MOUSEMOVE/LBUTTONUP)` 走真实分发。
  实测 `bbox=4 center=3 bboxOnly=1 picked=4`，`#9003` 包围盒只有 10px 进框、中心在框外。
  **原根因「框选用世界坐标、投影用表面坐标」被证伪**：两者共用同一对 `leftPointer.start/current`，
  `runtimeRightPointerNative*` 是恒等转换；真错位不会让 `picked` 与 `bbox` 恰好相等。
  收窄为「包围盒含精灵帧透明留白」，改法 A（判中心）/ B（按可见跨度）留待单位侧可见像素计量后再选。
- **简单批为什么是空的**：S-01~S-12 已在第 1~12 轮全部完成或废弃；在册简单项只剩
  S-08（必须与 M-03 合并做，单独做只是加一个没人读的计数器）、S-13（仍阻塞在守卫的
  `--inventory/--trace` 产物，见其 `main()` 的四个必填参数）。
  **不为凑批量去拆中等问题**——第 12 轮已经定过这条纪律，本轮继续照办。
- **没做的事写在明处**：本轮到 T+50 只完成「断言换链路 + 一档计量」，
  没有动产品行为，也没有去猜那 10px 条带的像素内容。

回归：`10/1/0` → **`10/1/0`**，`RED-NEW=0`（`20261112-201714`）。

移出本批：无（本轮只启动一条中等，按「一轮一条中等」执行完）。

下一轮起手：**M-02 第二步**——给单位侧补可见像素范围计量（照 M-12 的四桶思路），
量 `#9003` 那 10px 条带，再在 A/B 两种改法里选一个并补「框外单位不许被选中」的反向断言。
其次 **S-08 + M-03 合批**（世界 idle 空转重绘 → 脏区提交条件）；
**C-02** 仍是唯一 remaining known-red（复杂，需 Windows 基线对照，单独成轮）。

## 五-旧、第 12 轮（2026-11-12）打包清单（存档）

主题：**判定器自身的可信度**。基线 `PASS=10 KNOWN-RED=1 RED-NEW=0`（`20261112-200207`），
收口同结果，零新回归，**产品代码零改动**。报告 `reports/FIX-13-known-red失败前缀门禁.md`。

- **S-12 → 已完成**（`50d3a85`，简单，文档仓库）：`known-red.tsv` 扩到四列，第 4 列存失败前缀；
  `regress.sh` 对已登记 id 做「包含」比对，对不上判 `RED-NEW(cause-changed)` 并计入退出码；
  空前缀的行在开跑前逐条告警。自测两向（bogus 前缀 / 空前缀）都实测过。
  三个实现坑写进报告 §2：比对要用未截断的失败行、`known_reason` 必须离开命令替换、
  `$var` 后紧跟全角字符要写 `${var}`（本轮又踩一次）。
- **简单批为什么只有一条**：S-01~S-11 已在第 1~11 轮全部完成或废弃，本轮开工核对后，
  在册可动手的简单项只有 S-12；S-08 必须与 M-03 合并做，S-13 阻塞在守卫产物。
  **不为凑批量去拆中等问题**——那会把「一批小修」变成「一批未计量的猜测」。
- **核对掉两条报告遗留**：`ICM_QUERY/ICM_OFF` 反写早已修复（`windows.h:1228`），记入 §四 不再重开；
  结构守卫脏基线登记为 S-13（阻塞在缺 `--inventory/--trace`）。

回归：`10/1/0` → **`10/1/0`**，`RED-NEW=0`（`20261112-200412`、`20261112-200531` 两次一致）。

移出本批：无。本轮没有启动中等问题——剩余两条 known-red 之外的中等项（M-02 框选、M-13 真实遭遇战
取证通道）都需要先写计量或动启动路径，一轮做不完，按纪律留给下一轮单独起手。

下一轮起手：**C-02（command 两栖卸载，复杂，单独成轮）**——先写方案再动手，需要 Windows 基线对照；
若不想背对照成本，取 **M-02**（框选与投影不一致，先量两套坐标的差值）。
另：S-13 若要清，第一步是查清守卫的 `--inventory/--trace` 由谁生成，别先改 json。

## 五-旧、第 11 轮（2026-11-12）打包清单（存档）

主题：**关于「可见像素」的断言必须先对焦**。基线 `PASS=9 KNOWN-RED=2 RED-NEW=0`（`20261112-190119`），
与第 10 轮收口一致。报告 `reports/FIX-12-命中样本落在视口外.md`。

- **M-12 → 已定性**（`0b1f9e7` test，四桶计量）：`CONCORD_HIT_SPAN_TRACE=1` 对空 span 参与者逐 id 打
  `participating/drawsInView/drawsOffView/visiblePixels/depthPixels`。读数
  `#8 CABUNK02 drawsInView=0 drawsOffView=1 visiblePixels=0 depthPixels=0`，
  且该帧 `viewport=0,0,808,446`，而建筑投影包围盒是 `(983,58,1103,118)` —— **整栋落在视口右侧之外**。
  「空 span 表两种语义」的两种候选（没参加重放 / 全被挡住）**都不成立**，`depthOnlyPixels=0` 也排除了
  「进了深度又被压过」。同一冒烟上一段把镜头停在雷达场景的几何中心，采样建筑因此在视口外。
- **M-12 → 已修复**（`b855223` test）：断言前先把样本建筑 `centerRuntimeCameraOnCell` 进视口，
  `ensureRuntimeCameraForViewport` + `invalidateRuntimeObjectProjectionCache` 后重建投影，再用同一套谓词。
  产品 pick 路径**零改动**（`findProjectedObjectAtPoint` 未动）——视口外返回 nullptr 是正确行为。
  对焦后同一条 trace 的视口由 `(0,0,808,446)` 变为 `(0,142,726,637)`，说明该帧视口随相机/地图边界裁剪，
  「视口外」与「镜头停在哪儿」是同一条问题。
- **S-12 → 待修复**（本轮登记，来自 FIX-11 的流程欠账）：known-red 只保证「红」，不保证「红的是同一件事」。
  简单区再也不是空的——下一轮可直接当简单批做。

回归：`PASS=9 KNOWN-RED=2` → **`PASS=10 KNOWN-RED=1`**，`RED-NEW=0`（`20261112-191034`）。
唯一 known-red 是 `command`（C-02 两栖卸载，复杂，需单独成轮）。

移出本批：无。本轮没有启动第二条中等问题——简单区开工时为空（S-01~S-11 全完成），
唯一在册的简单项 S-12 是本轮**新登记**的，登记与实现不同轮，避免把「门禁本身」和「门禁读数」
混在同一次提交里。

下一轮起手：**S-12**（known-red 失败前缀门禁），其次 **C-02**（command 两栖卸载，复杂，单独成轮）。

## 五-旧、第 10 轮（2026-11-12）打包清单（存档）

主题：**先修那道「假门」**。基线 `PASS=8 KNOWN-RED=3 RED-NEW=0`（`20261112-120122`），与第 9 轮收口一致；
但交互条的红点已经从 M-12 前移到 ESC 菜单——`ffdd7c5` 改速度阶梯时漏改两张断言表。
报告 `reports/FIX-11-被known-red掩盖的新回归.md`。

- **S-11 → 已完成（`d69980d`，简单）**：`gameSpeedSliderRight` 与 `expectedGameSpeedPacing`
  末位 `0` → `281`，support-power 拆掉 uncapped 两支。interaction 立刻回到 `structure footprint hit mismatch`
  （即原登记点），证明 S-11 只是挡在前面的一道门。
- **M-21 → 已完成（`bf5fd7c`，中等）**：探针推进用「帧」、渲染 delay 用「拍」，
  `eventAge=3 < delay=6` → `eventAge/delay` 恒 0 → 永远第 0 帧。改为
  `runtimeRuleFramesToTicks(AnimationRate, fixedTickHz)` 后 `anim=yes/frames=11`。
  **`render` 由 KNOWN-RED 转 PASS**，产品代码一行未动。
- **M-12 → 只计量（`0e72a10`，中等）**：四层 spans 读数 `sprite=140/foreground=0/visible=0`，
  `inSprite=yes inVisible=no`。定性从「谁挡住谁」改写成「空表两种语义」，见报告 §3。

回归：`PASS=8 KNOWN-RED=3` → **`PASS=9 KNOWN-RED=2`**，`RED-NEW=0`（`20261112-121717`，
另有一次同结果 `20261112-121057`）。

移出本批：M-12（性质从「命中口径」变为「可见性重放语义」，需要先加分桶计量，不在本批硬啃）。
新登记 S-11（已当轮完成）。

下一轮起手：**M-12**——先给 `extractRuntimeBuildingVisibleHitSpans` 加 `draws` / `rect∩viewport` /
`visibleOwner 像素数` 三桶，把「没参加重放」与「全被挡」分开，再决定改 pick 还是改重放。
其次 **C-02**（command 两栖卸载，复杂，需单独成轮）。

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
