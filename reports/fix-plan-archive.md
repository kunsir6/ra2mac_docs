# fix-plan 存档：第 1~22 轮的收口摘要与打包清单

> 用途：`reports/fix-plan.md` 的体量缓冲层。计划正文只保留「本轮收口 ≤10 行 + 本轮打包清单 +
> 一行轮次索引」，历史原文全部落在这里，**不删不改**，需要追溯时按轮次查。
>
> 迁出时间：2026-11-13 第 23 轮收口。迁出原因：fix-plan 涨到 743 行，
> 违反它自己在同一轮写下的「全文 ≤400 行、历史收口压成一行索引」红线，其中约 500 行
> 是 22 份逐轮打包清单。
>
> 内容来源：原 `fix-plan.md` 头部的第 8~22 轮收口摘要（`>` 引用块原文），
> 以及原文件「五-旧 / 六~十一」各节的历史打包清单。章节标题里的序号前缀已去掉，
> 正文一字未改。

---

## 一、头部历史收口摘要（第 8~22 轮，原文）

上一轮收口：2026-11-13 13:45（第 22 轮收口）；
第 22 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
**C-02f 已完成**：MCV 拆包的六个谓词里只有「落点」不成立——验收要建筑左上角 `(6,6)`，
产品按 `runtimePlacementAnchorCellForFootprint` 落在地基锚点 `(7,7)`。改判「落在旧地基格清单内」
后四阵营全过（含被占领的 `GACNST`→`AMCV`）。新登记 **C-02g**：奴隶矿工出舱段
（`RuntimeSlaveMinerSmoke.inl:214`，新工人既不在建筑内也不在出舱渲染窗口）。
报告 `reports/FIX-23-MCV拆包落点是地基锚点.md`。

上一轮收口：2026-11-13 13:40（第 21 轮收口）；
第 21 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归。**C-02e 已完成**：生物反应堆段的两人
不是「没派路」也不是「被地基挡」，而是**进门格被寻路器的兜底目标换成了门外邻格**——
`applyRuntimeMovePathResult` 的 blocked-goal 豁免名单只认 `WorldObjectKind::Unit` 的 host，
建筑吸收器（反应堆/碉堡）不在内，两名乘客各自被换成对方所在的格子，互堵死且不自愈。
补 `runtimeBuildingAbsorberEntryKeepsGoal` 后 `power=650 aboard=5`，五人全部真实进入。
新登记 **C-02f**：MCV repack 段（`RuntimeMcvRepackSmoke.inl:145`），属暴露出来的旧问题。
报告 `reports/FIX-22-生物反应堆进门格不被兜底换掉.md`。

上一轮收口：2026-11-13 13:30（第 20 轮收口）；
第 20 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归。**C-02d 已完成**：读数证明
`cargoBeforeAction=4 / boatMovingBefore=0 / 无 host-busy` —— 卸载跑了，但一趟只放一件，
且船货顺序取决于 boarding 到达顺序，「按一下就断言 IFV 已出舱」实际在赌次序。改按拍推进后混编段转绿。
新登记 **C-02e**：生物反应堆段（AI action 62，五个步兵 800 拍未全部进入）。该路径走
`cellDistanceToObjectFootprint` 而非 `runtimeTransportTransferBodiesClear`，且零 transport trace，
与本轮改动无关。报告 `reports/FIX-21-混编段按拍等待.md`。

上一轮收口：2026-11-13 13:20（第 19 轮收口）；
第 19 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归。**C-02c 已完成**：两栖卸载给步兵
规划半径 2 外侧终点（`4f13ccc`），12 名步兵整仓下船转绿；坦克段与其余 9 条 smoke 全绿。
新登记 **C-02d**：混编段「载入 IFV 的整车下船」——一次动作后 IFV 仍未出舱（`ifv=null`、`boatCargo=3`），
该夹具在 23,23 周边零 `unload:` trace，说明 `unloadRuntimeUnitTransportMotion` 顶部就返回了，
已排除本轮引入。报告 `reports/FIX-20-两栖卸载外侧终点.md`。

上一轮收口：2026-11-13 13:10（第 18 轮收口）；
第 18 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
**上一轮结论被推翻并更正**：`unload:bodies` 的 `ticks=66/66` 不是「卡住」，而是 egress 的**第一拍**——
去掉重键只含「人+格子+原因」，读到的是首次命中时刻，不是终态。加 120 拍时间桶后（tick=1680）真形态是：
**11 名已出舱者 `bstate=none`、`moving=0`、位置=格子中心，把 8 个邻格全占满**，最后一名 `id=7`
找不到任何一条起点干净的走廊。结构性原因是两栖卸载**不规划外侧终点**（`remainingPath` 只在
`!runtimeAmphibiousTransport` 时计算），出舱就地停靠；8 格 × 0.5 身体互斥的实际容量远小于名义 32 子格。
下一轮取 A：给两栖卸载也规划半径 2 外侧终点（全水时退回就地停靠）。报告
`reports/FIX-19-卸载终态是被站着的人占满环.md`。

上一轮收口：2026-11-13 13:00（第 17 轮收口）；
第 17 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
**C-02c 已收窄**：卸载侧逐格给原因后，「600 拍不放空」变成两阶段读数——①八台 MTNK 占住舱门口八格时
八格全被 passability 拒（`occupied=14..21`，属预期的「堵住」判定）②挪开后**第一具出舱者（id=13）
停在船体原点没走开**，后续所有人的扫掠段起点都落在它身体里（`distance²=0`），于是全员等它。
出舱者不在 `pendingTransportTargets`，第 16 轮的同伴豁免对它不生效。下一步要量挡住者自己的
行为状态（`ticks`/`path.size()`/`moveTarget`）才能定「egress 渲染步卡住」还是「egress 后走不到
半径 2 终点」。报告 `reports/FIX-18-整仓卸载的八格拒绝表.md`。

上一轮收口：2026-11-13 12:50（第 16 轮收口）；
第 16 轮收口：基线 `10/1/0` → 收口 **`10/1/0`**，`RED-NEW=0`（`command` 的失败文案按新阻塞点
同步改第 4 列，属计划内的 cause-changed）。**登船互锁修好了**：12 名步兵 `aboard=10/12 → 12/12`。
根因不是运力、寻路、地形层或子格，而是 `runtimeTransportTransferBodiesClear` 的 foot-to-foot
最小间距 0.5：一格四子格，四人同格时彼此扫掠段起点距离只有 0.002~0.10，且四人同拍都在往板上挤
→ 谁也不能先动。**计划里的 A 方案（每拍只放一人）被读数否决**——单独一个动仍被站着/挤着的同伴挡住；
改成「同船步兵同伴不算路障」（载具与外部单位仍严格互斥，坦克段 `aboard=4`/`exits` 不重合照旧绿）。
源码 `498ae37` fix + `c7a1f2f` test。**新登记 C-02c**：整仓步兵卸载按拍推进 600 拍仍不放空
（原生问题，登船入舱会清 `pendingTransportTargets`，本轮豁免对它不生效）。报告
`reports/FIX-17-登船互锁解除与卸载新阻塞.md`。

第 16 轮开工：基线 **`10/1/0`**（`20261113-121025`，与第 15 轮收口逐条一致，`command` 前缀
`twelve infantry did not board` 未漂移）。简单区仍为空（S-08 缺静止连拍入口、S-13 卡守卫产物、
M-19 属资产侧），按「不为凑批量拆中等项」的既有纪律，本轮只做唯一 remaining known-red
**C-02**，取 A 方案（复杂，单独成轮，先写方案再动手）。

上一轮收口：2026-11-13 10:55（第 15 轮收口）；
第 15 轮：基线 `10/1/0` → 收口 **`10/1/0`**，零新回归，产品行为零改动（一条 `test:`）。
**C-02 根因收窄**：给登船路径加 `CONCORD_TRANSPORT_TRACE=1` 原因位后，卡点不是寻路/地形/子格，
也不是容量，而是**四个人同拍停在 (15,15) 同格互相锁死**——`runtimeTransportTransferBodiesClear`
的 foot-to-foot 最小间距 0.5 让每个人都在别人的扫掠走廊里，谁也不能先动。
报告 `reports/FIX-16-登船互锁的四道门计量.md`。

第 15 轮开工：基线 **`10/1/0`**（`20261113-095359`，与第 14 轮收口逐条一致）。
简单区仍为空（S-08 缺「静止连拍」入口、S-13 仍卡守卫产物），按纪律不为凑批量拆中等项；
本轮唯一 remaining known-red 是 `command`（C-02 混编登船 10/12），按「复杂单独成轮」只做它。

第 14 轮（`10/1/0` → **`10/1/0`**，零新回归，产品行为零改动，三条 `test:`）：
**M-02 结案为非缺陷**：命中框 = 画面框外扩 3px（`InflateRect(+3)`），而 `spriteBounds` 已被
`RuntimeUnitSelectionAlignmentSmoke` 逐像素证明等于真实绘制框；样本 `#9003` 的画面在框内真有 7px。
**C-02 阻塞点后移**：单位船卸载是逐人推进（一次点击只放一辆），旧断言「一次点击全员下船」
结构上不可能成立；修掉后卡在 12 名步兵登船 10/12。报告 `reports/FIX-15-框选结案与两栖卸载真阻塞点.md`。

第 13 轮收口：`10/1/0` → **`10/1/0`**，零新回归，产品代码零改动。
第 13 轮：基线 `10/1/0`（`20261112-201018`）→ 收口 **`10/1/0`**，零新回归，产品代码零改动。
主题：**框选断言原来在同义反复**——它自己重实现了一遍「包围盒 ∩ 矩形」再 applySelection，
产品拖选路径零覆盖。改为三条真实消息（DOWN/MOVE/UP）穿过 `runtimeWindowProc` 后，
顺带量出 M-02 的真实形态：`bbox=4 center=3 bboxOnly=1`，是**包围盒含精灵帧留白**，
不是台账里写的「世界坐标 vs 表面坐标错位」。报告 `reports/FIX-14-框选断言穿过消息循环.md`。
简单区仍为空（S-08 须与 M-03 合批、S-13 仍阻塞在守卫产物），按纪律不为凑批量去拆中等项。

第 12 轮收口：`10/1/0` → **`10/1/0`**，零新回归，产品代码零改动。
本轮主题：**给判定器补一道「红的是同一件事」的闸**——S-12 落地，known-red 第 4 列存失败前缀，
前缀对不上就判 `RED-NEW(cause-changed)` 并计入退出码。唯一 known-red 仍是 `command`
（C-02 两栖卸载，复杂，单独成轮）。报告 `reports/FIX-13-known-red失败前缀门禁.md`。

第 12 轮开工：基线 `10/1/0`（`20261112-200207`），与第 11 轮收口一致。

第 11 轮收口：`9/2/0` → **`10/1/0`**，零新回归。
本轮主题：**把「空 span 表两种语义」钉死**。M-12 加四桶计量后当场定性——不是可见性门错杀，
也不是谁挡住谁，而是**被采样的建筑整栋落在 map viewport 之外**（`drawsOffView=1 / visiblePixels=0`），
拿它去断言「点得到」构造性不可满足，与 M-18 同一条纪律。**`interaction` 转 PASS**，
唯一 known-red 只剩 `command`（C-02 两栖卸载，复杂）。

第 10 轮收口：`8/3/0` → **`9/2/0`**，零新回归。
**`render` 十轮来首次转 PASS**（M-21 是探针把「帧」当「拍」，产品零改动）；
interaction 越过一道**被 known-red 掩盖的新回归**（S-11）后，回到原登记点 M-12，
而 M-12 的问法本轮被计量改写了——不是「谁挡住谁」，是「空 span 表有两种语义」。

第 9 轮收口：基线 **8/3/0** → **8/3/0**，零新回归。
**M-18 定性翻案**：建筑投影不是产品缺陷，是门禁在自己的帧里看不见建筑——ore 探针把镜头
居中到「无 overlay 的空地」（探针判据本身就是没盖东西），同一帧要 `structureShadowsDrawn>0`
构造性不可能。M-20 四桶计量给出 `structureOff=2/empty=0`，自证帧第一栋 `CAAIRP` 即
13551 像素。`render` 仍红，阻塞点后移到 M-21（矿喷发动画，改前逐字相同）。
第 8 轮 08:29 的并发改动（建造就绪角标）其主人已提交（`7afbc54`/`2cb8364`/`4acf858`））

---

## 二、逐轮打包清单（第 1~22 轮，原文）

## 第 22 轮（2026-11-13）打包清单

主题：**验收把「测试自己的坐标假设」写死了**。基线 `10/1/0` → 收口 `10/1/0`，零新回归，产品零改动。
报告 `reports/FIX-23-MCV拆包落点是地基锚点.md`。

- **C-02f 已完成（`7c02812` test）**：六个谓词逐项打印后只有落点不符（`7,7` vs 验收的 `6,6`）。
  产品按地基锚点落点、再找可走格；验收钉的是建筑左上角。改判「落在旧地基格清单内」后四阵营全过。
- **不做的事**：不改产品去落左上角（会让放置锚点规则自相矛盾），也不把锚点算法抄进测试
  （会随产品演进假红）；锚点只出现在失败文案里。
- **新登记 C-02g**：奴隶矿工出舱段（`RuntimeSlaveMinerSmoke.inl:214`），根因假设尚未验证。
- **链条观察（延续第四轮）**：阻塞点全是「第一次运行」的段落，形态是「多谓词压成一句 + 测试自己的
  坐标/次序假设写死」。C-02d 赌船货次序、C-02f 赌建筑左上角，属同一类。

## 第 21 轮（2026-11-13）打包清单

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

## 第 20 轮（2026-11-13）打包清单

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

## 第 19 轮（2026-11-13）打包清单

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

## 第 18 轮（2026-11-13）打包清单

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

## 第 17 轮（2026-11-13）打包清单

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

## 第 16 轮（2026-11-13）打包清单

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

## 第 15 轮（2026-11-13）打包清单

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

## 第 14 轮（2026-11-12）打包清单

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

## 第 13 轮（2026-11-12）打包清单

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

## 第 12 轮（2026-11-12）打包清单

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

## 第 11 轮（2026-11-12）打包清单

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

## 第 10 轮（2026-11-12）打包清单

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

## 第 9 轮（2026-11-12）打包清单

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

## 第 8 轮（2026-11-12）打包清单

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

## 第 7 轮（2026-11-12）打包清单

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

## 第 6 轮（2026-11-12）打包清单

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

## 第 5 轮（2026-11-12）打包清单

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

## 第 4 轮（2026-11-12）打包清单

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

## 第 3 轮（2026-11-12）打包清单

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

## 第 2 轮（2026-11-12）打包清单

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

## 第 1 轮（2026-11-12）打包清单

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
