# 问题修复计划（fix-plan）

> 用途：本项目「待修复问题」的唯一台账。每轮开工先核对本表，收工前回写状态。
> 维护规则：
> 1. 新问题一律先登记再动手，登记必须写清「根因假设」，根因未明只允许登记为「只读计量」类任务。
> 2. 修复完成 → 状态改「已完成」并填关联报告；证明不成立/场景消失 → 改「已废弃」并写原因。
> 3. 复杂度过关即改：一旦发现要改到第二个模块去，回来改分级并写原因，不许留在原批里硬啃。
> 4. 体量红线：全文 ≤400 行；条目 ≤120 条；收口摘要每轮 ≤10 行；轮次一过就把清单原文迁 `reports/archive/`。
>    量的活由 `bash ra2mac_docs/scripts/ledger-check.sh` 做（第 25 轮 S-14 落地），别再靠人记得 `wc -l`。
> 5. 条目只允许 12 个字段：id / 标题 / 现象 / 根因假设 / 收益 / 成本 / 性价比 / 复杂度 / attempts / 状态 / 验收条件 / 关联报告。
>    一次性证据写进报告；缺「根因假设 / 收益 / 成本 / attempts / 验收条件」任一项的条目不许进排序。
>
> 分级口径 — **简单**：单文件单函数族、根因已由读数指认、可独立 revert。**中等**：单模块多文件或须先加只读计量才能定性、失败可整块回退。**复杂**：跨模块 / 需重构 / 触及呈现层或输入链路架构，单独成轮先写方案。
> 性价比 — **S**（半天内可见用户价值）＞**A**（清掉一条 known-red 或解掉一类卡点）＞**B**（体验打磨）＞**C**（基建/可观测性，回报延迟）。
> 主线计数 — 同一条产品线拆出的全部子项算一条主线，**≤4 子项 / ≤4 轮**，拆新 ID 不重置计数。
>
> **本轮（第 54 轮，2026-11-15）收口摘要 —— 修复轮（主目标 EVO-07 第一步）**
> 1. 轮型：修复轮。报告 `reports/FIX-54-版本身份自证与打包链新门禁.md`。源码 1 提交 `9477056`。
> 2. **上轮结论**：S-20 结案（wire 编解码器合一，regress 接第 14 条）。
> 3. **本轮变化**：EVO-07 拆成三段执行，本轮交付**能自证的那段**——`--version` 自己报出
>    版本/架构/编译时刻 + 包内 `BUILD-INFO.txt`（git hash + 打包时刻）；`pack-dist.sh` 新增
>    **第 ⑨ 门禁**：包内二进制报的 `package:` 行必须与包内文件逐字相同，专防「包换了、里面没换」。
> 4. **为什么不是完整 EVO-07**：数据根对话框与 About 面板都要新开 AppKit 模态面，本项目不调
>    `sendEvent` + 无 Accessibility 授权 → 交互验证不了，做出来是 §八.4 的未完成。dmg 留到下轮。
> 5. 质量四数：净增 **+73**（`RuntimeMain.cpp` 1,091→1,164）；90,715 / 42,542 / 30,794 三文件持平；
>    断言 0 组新增；TODO 0。
> 6. 回归 `13/1/0`（14 条，零 RED-NEW）；包内 + Rosetta `--smoke-test` rc=0；双切片 minos 12.0。
> 7. 清单：341 行 / 35 条 / 64KB / 5 类，十项门禁全绿；人工体检 **2 处**（S-25 状态矛盾已修、
>    EVO-07 三段式改写），见报告 §八。
> 8. **下轮起手（第 55 轮）**：EVO-07 的 dmg（`scripts/make-dmg.sh`，挂载卷验法=取二进制配
>    `CONCORD_DATA_ROOT` 跑 smoke）；`--version` 进 regress 第 15 条；EVO 主线整体收口判定。

---

## 一、待修复 —— 简单

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | attempts | 状态 | 验收条件 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| S-08 | 世界重绘只读计量 | 帧循环每 tick 无条件 `InvalidateRect`+`UpdateWindow`，不知多少次真改画面 | `tickAdvanced` 直接置 `repaintRequested`；**`reuseCachedFrame` 早已算出并传进 `recordRuntimeCompletedFrameDiagnostics`，但只用于把绘制阶段记 0，从未累加**。第 35 轮查明「有仪表无读数」的结构原因：出口 `writeRuntimeFrameDiagnosticsReport` 只被 `runRuntimeWindowSession` 收尾调用（`RuntimeShell.cpp:90368`），且 `sessionFrames==0` 直接 return | 中：M-03 的唯一基线 | 低：出口已存在，只差一次真会话（被 M-30 挡） | **B** | 简单 | 1 | **blocked**（`cf1903b` 仪器已装、离线探针验过；重开条件=①M-30 绿后跑一次真开局 ②第 38 轮把出口拆成 `flushRuntimeFrameDiagnosticsReport()` 供无窗口路径调） | `performance/latest.txt` 出现「复用帧/重绘帧/最长连续复用帧」三行且与实际相符 | `reports/FIX-35-帧诊断记复用与重绘.md` §一、`reports/AUDIT-35.md` §三.3 |
| M-19 | `NATBNK` 没有 temperate 美术 | `body=0x0 frame=0x0`，`2 loaded, 0 missing` 却什么都画不出来；`2peaks.map` 是 TEMPERATE | 资产缺口：`NewTheater=yes` 但导出集只有 `art/snow/natbnk.shp` | 中：任何「建筑可见/可点/有影子」的断言在该图上不可满足 | 补 temperate 变体，或让冒烟换图 | **C** | 简单 | 0 | 待修复（不阻塞门禁） | `2peaks.map` 上该建筑 `structureNoArt=0` 且 `drawn>0` | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §2 |
| S-19 | 地图预览产物的旧/新 A/B 没做 | 第 33 轮把 `MapPreviewExporter` 的分叉解码器换成 `RuntimeTmpCodec`（−647 行），但预览产物**没做逐字节对比** | `/tmp/tiles` 能从 `--extract-map-tiles` 抽到 213 块瓦片，但 `--export-map-tmp-preview` 卡在 `failed to open file: …/isotem.pal`（该调色板只在归档里） | 中：不做完，「删了 647 行且行为不变」这句话就不成立；做完全轮结论才闭环 | **高**（第 34 轮推翻上一轮的「30 分钟」：无按名抽取 MIX 的 CLI，要自己实现 Westwood CRC；旧二进制要另建构建树整编） | **B**（原 A，因成本翻倍而降） | 中等 | 0 | 待修复（前置=MIX 按名抽取 + 第二构建树） | `isotem.pal` 落进 palette-dir 后，`git show b2ebc4c^:src/assets/preview/MapPreviewExporter.cpp` 编旧二进制，两次 `--export-map-tmp-preview` 的 PPM **sha256 相同** | `reports/FIX-34-地图预览自带第二份TMP解码器.md` §四 |
| S-24 | 载具穿步兵冒烟未进门禁 | M-25 的判据已存在且现在红（`vehicle pass-through: emptyCell=1 friendlyInfantryCell=0`），但 `RuntimeVehicleInfantryPassThroughSmoke.inl` 仍是并发会话的未跟踪文件 | 门禁接线的前置是「被测冒烟在 HEAD 里」；未跟踪文件接进门禁，干净树重建后该环境变量消失 → 退回跑主档，以别的文案红出来，制造永久假 `cause-changed` | **A**：M-25 是用户已确认的 S 级缺陷，判据有了却不每轮跑，等于修完也可能静默退化 | 低：.inl 进 HEAD 后加一条 `run_case`（0.4s）+ 转绿前的 known-red 前缀 | **A** | 简单 | 0 | **blocked**（前置=.inl 进 HEAD） | regress 出现第 14 条 `vehiclepass`；接上时若红则登记前缀，M-25 修好后转 PASS 且前缀可注销 | `reports/FIX-43-regress接入混合编队收敛门禁.md` §六 |

## 二、待修复 —— 中等

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | attempts | 状态 | 验收条件 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| M-03 | 世界 idle 空转重绘 | 静止时也每 tick 全量重绘，CPU/功耗浪费 | `tickAdvanced` 直接置 `repaintRequested`，缓存复用被判据本身短路 | 中：功耗与风扇 | 场景签名门（tick+相机+对象位姿帧号+选中集+资源+遮罩版本），每 30 帧强制重绘兜底 | **B** | 复杂 | 0 | 待修复（方案已写；**必须先有 S-08 读数**，漏字段的后果是冻帧） | 静止 3 秒内提交帧数下降 ≥80% 且画面无冻帧 | 同上 §3 |
| M-04 | 提交节奏对齐显示刷新 | 帧提交与 60Hz 不同步，偶发丢帧/撕裂 | 用定时器而非 display link | 中：画面平滑度 | 接 CVDisplayLink | **B** | 中等 | 0 | 待修复 | 连续 600 帧间隔抖动 <2ms | `reports/ON-2-02a-呈现节奏计量与主人帧修复.md` |
| M-05 | 尤里复仇战役未接入 | 战役菜单只有基础版 ra2 任务 | 战役数据库只装了 ra2 的 mission 表 | 中高：资料片内容缺失 | 数据层接入 + 校验 | **B** | 中等 | 0 | 待修复 | YR 战役列表与 retail 任务数一致且能开局 | `reports/Q-04-RA2与YR拆分盘点.md` |
| M-06 | 日志与崩溃现场落地 | 崩溃后没有现场，只能靠重跑 | 无统一日志出口 | 中：排障效率 | 日志出口 + `--collect-diagnostics=<zip>` | **C** | 中等 | 0 | 待修复 | 人为崩溃后 zip 里含日志与栈 | — |
| M-07 | diagnostics 驱动入口 | 无人值守走不完 菜单→大厅→载入→世界（autostart 钩子已删） | 缺一个脚本化入口 | 中：自动化上限；M-13 同源 | 新增 CLI 驱动 | **C** | 中等 | 0 | 待修复（与 M-13 合并落地） | 一条命令无人值守进到世界并出帧 | — |
| S-23 | 3 台 MTNK 收在半径 2 而不是 3x3 | 第 13 条 `compactgroups` 里 `3MTNK_3SHAD` 终态 `groundRadius=2`；地面 3 台的目标格 (32,28)/(33,28)/(31,29) 与空中 3 架 SHAD **完全同格**，SHAD 终态 `airborne=0` | **已确认**：落位侧冲突——飞行器到达后落地（airborne 0）重新进入地面占位，压住地面单位的目标格，坦克被兜底挪到最近空格且不回填。`ground_target_reclaimed` 零触发 → 不是「先停再推」。分配器共格是被要求的（两层都必须用中心格），**不是修点** | **A**：这是「编队收得散不散」的唯一在线门禁，修好才有真绿基线 | 中：改落位分支（飞行器静默保持 airborne，或落地避开地面已认领格）；13 场景 0.7s 即时验 | **A** | 中等 | 1 | **已完成（`8e62b4d`，产品修复；第 44 轮定位、第 47 轮实施）** | `3MTNK_3SHAD` 的 `groundRadius=1` 且 `ground_final_cells` 不退化；同批 12 例保持 PASS；known-red 该行可注销 | `reports/FIX-44-混合编队地面层被落地飞行器占格.md`、`reports/FIX-47-飞行器落地礼让地面单位.md` |
| M-29 | UnholyAlliance 的验收样本是探针自己编的 | 完整链路第一道门 `option semantics ownerFactory=no unholy=no`。读数：模式只授予 9 栋对面**基础建筑**（无电站）；`loadedCatalog=46` 不含任何苏军条目；三台 MCV 走 rules 层而非目录段 | 原样本钉 NAPOWR/YAPOWR，零售模式从不提供该建筑 → 测的是不存在的规则 | 高：S-17 / M-13 的剩余门 | 低：已改完，剩 `unholy` 一段待一条读数 | **A** | 中等 | 1 | **已完成（断言纠正，`225d310`）**：`ownerFactory` 转 yes；第 35 轮 queue 侧对齐 done，剩余 `unholy` 段拆出为 **M-30**（不在本条续命）；不计入已修复 | `ownerFactory=yes` 且 `alliedYardForeign=no / foreignYardForeign=yes`；线段级判据见报告 §三 | `reports/FIX-33-UnholyAlliance的验收样本是探针自己编的.md` |
| S-20 | 多机对战两份字节编解码器已漂开 | `snapshots/RuntimeMultiplayerSnapshotTransfer.cpp` 与 `protocol/RuntimeMultiplayerMatchSetup.cpp` 各在匿名命名空间定义一套大端 `ByteWriter/ByteReader` | **不是复制品是分叉**（第 36 轮逐行 diff，R53 复核仍成立）：①错误文案前缀 `"snapshot "` vs `"match setup "` ②`require()` 一侧带下溢守卫 ③方法集不同（`writeBool` vs `writeByteVector/writeArray`） | **A**：两边对敲同一批字节流，漂开与分叉同级风险（无编译错误、无门禁可见） | 低-中（R53 实测）：共享头 + 前缀参数化即可**零文案改动**，一次编译过 | **A** | 中等 | 0 | **已完成（`6efad17`，R53）**：`network/detail/RuntimeBigEndianCodec.h` 取两侧方法并集、`label` 参数保住每条错误字符串逐字节不变、`require()` 统一带守卫；五条对战冒烟前后输出 `diff` 为空；regress 新增第 14 条 | 同一字节流经两条路径的**可观察行为**改动前后逐字节相同 + regress 出现第 14 条 `multiplayer` 并常绿 | `reports/FIX-53-对战wire格式两族编解码器收口.md`（首次登记 `reports/FIX-36-清偿轮-两族克隆实现收口.md` §三） |
| S-26 | 结构守卫的 inventory/trace 生产者只有 Windows 版 | 第 45 轮查明：`Run-StructureChecks.ps1` 要 `pwsh 7` + `clang-cl` + MSVC 前端 + CTest；`--inventory` 由 `Get-TestInventory.ps1` 生成，`--trace` 是那轮 configure 的 `configure-trace.jsonl`。本机两者都没有，所以**完整 scan 一次都没跑过**，1,268 条 `target:`/`test:` 例外也离线不可验 | 取证链整条绑在 Windows 工具链上；守卫本体是纯 Python，被它自己缺失的输入挡住 | **A**：这条不落地，结构守卫的日常价值只有第 45 轮装的两段（夹具自检 + 路径存在性），分层漂移仍无人守 | 中：CMake 在本机本来就能出 file-api codemodel，`ctest --show-only=json-v1` 能给用例注册表——不必照搬 PowerShell，但要对齐 `inventory.tests` 的字段形状 | **B** | 中等 | 0 | 待修复（第 45 轮登记；**不许**为了跑通而放宽 `--baseline` 的 policy） | `bash tools/structure/run.sh --inventory <本地生成> --trace <本地生成>` 在无 Windows 产物时跑完第 ③ 段并给出与基线一致的结论（零未登记命中） | `reports/FIX-45-结构守卫在macOS上第一次能跑.md` §五 |
| S-28 | **挤压原语**：目标格被友军步兵占着时没人让位 | 载具走到目标格，格上站着友军步兵 → crush 对友军恒否 → 寻路器把目标兜底换成远处空格，载具停在半径 2（`ground_target_unreached`） | **已确认**（R44/R48 两次实测）：缺的不是通行许可，是**让位**。**第 49 轮又否定了一条接缝**：挂在寻路结果侧（`applyRuntimeMovePathResult` 的 `goalAdjusted` 分支）在三条冒烟里零触发 → 必须挂在**移动推进侧**（`advanceRuntimeMoveBehavior`），载具**即将 commit 进格**时判 | **A**：它是 M-25 的**唯一前置**；单独也修「载具被自己步兵堵在终点前」这一类 | 中高：原语可在 `RuntimeSessionNavigation.cpp`（单 TU），但**调用点必须在 `RuntimeSessionWorld.cpp`**——该文件此刻有并发 WIP，开工前先看 `git status` | **A** | 中等 | 1 | **blocked**（第 50 轮随 unit-behavior 主线移出 `progress/deferred.md`；调用点在并发 WIP 的 World.cpp） | **先证可达**：读数 `displace from/to/id` 至少命中一次；**再证不变差**：`compactgroups` 13/13（点名 `12E1_2MTNK_tank_first` / `3MTNK_3SHAD`）+ regress 零 RED-NEW。顺序不许反。**单独落地不接 regress** | `reports/FIX-49-M-25方案-挤压原语与通行放行的顺序.md` §三、`reports/FIX-50-留存策略与M-25主线收口.md` §四 |

## 三、待修复 —— 复杂（单独成轮，先写方案）

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | attempts | 状态 | 验收条件 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C-01 | 事件分发接 `sendEvent` | 不走 `[NSApp sendEvent:]` → cursor rect 全失效、`isActive/isKeyWindow` 恒 0、tracking area 不回放 | 主循环自建 `nextEventMatchingMask` 分发，绕开 AppKit 正规路径 | 高：一次性修好一类系统级交互 | 改主循环 + 回归全部输入断言 | **A** | 复杂 | 0 | 待修复 | 真实鼠标移到按钮上时 cursor 变化、`isKeyWindow` 为真 | `reports/U-12-*`（见 MEMORY「不调 sendEvent」） |
| C-03 | 存档/读档真机往返 | 无存读档往返验证 | 未实现 | 高：存读档可用性 | 高 | **B** | 复杂 | 0 | 待修复 | 存→推进 300 拍→读，两次 simulation hash 相等 | — |
| C-04 | 全屏原生分辨率渲染 | 呈现表面跟随窗口而不是放大 800x600 | U-14 已把客户区尺寸交给游戏，剩余是表面重建与缩放策略 | 中：全屏清晰度 | 中高 | **B** | 复杂 | 0 | 待修复（U-14 吃掉一半） | 全屏下 view 尺寸 >1600px 时 surface 尺寸同比，单位像素尺寸不变 | `reports/U-14-全屏等于更大视口.md` |
| M-25 | 载具被友军步兵挡死（看着有空地却过不去） | 几个步兵站在一起后，载具**彻底**过不去（用户实测确认，不是减速）。判据 `vehicle pass-through` 现红：`emptyCell=1 friendlyInfantryCell=0` | 通行判定最后一支 `!runtimeCanEnterAndCrushCell` 对同阵营恒否 → 友军步兵格在寻路层等价于一堵墙（步兵有子格分支所以不受影响）。**第 44 / 48 轮两次实测**：只解除寻路否决会打红 `12E1_2MTNK_tank_first`（`arrival_timeout`），因为落位阶段没有任何让位或回填；第 48 轮再试「只放行停着的步兵」仍在同一处红——判别式在**规划时刻**问了**落位时刻**的性质 | **A**：用户实测的操作阻塞感，直接决定「这一脚开不开得过去」 | 高：必须两半同时上——①通行放行 ②commit 前挤压（`findRuntimePassableCellNear` 半径 1~2）+ 分配器按兵种分层目标格 | **B** | 复杂 | 3 | **blocked**（第 50 轮 §六.3② 整体收口：三次尝试全为负结果——R44 解除否决/R48 只放行停着的步兵/R49 接缝零触发；子项 4/4 已满，禁开第 5 个。重开条件见 `progress/deferred.md` 的 S-28 段） | `friendlyInfantryCell=1` **且** `compactgroups` 13/13 **且** `regress.sh` 零 RED-NEW，三条同时成立 | （另有并发会话一份未跟踪的 M-25 分析，未入库故不链接）、`reports/FIX-48-M-25挤压缺位移-读数与重排.md`、`reports/FIX-49-M-25方案-挤压原语与通行放行的顺序.md`、`reports/FIX-50-留存策略与M-25主线收口.md` |

---

## 四、skirmish-mode-rules 主线：整体收口判定（第 31 轮，判 **done**）

**账目**：第 28~31 轮共 3 轮、4 个子项（M-22 done / M-23 done / M-24 移出 / S-17 转 blocked），
窗口用尽，**不再开第 5 个子项**。

- **M-22**（`2c7f1ea`）：9 个 `MP*MD.ini` 只在 `expandmd01.mix` 里，松散路径查不到 → 模式规则从未加载。
  改为「松散优先 + 归档按名回退」。**这是本轮线唯一的 S 级用户价值**：9 个模式的规则从静默无效变为生效。
- **M-23**（`4abfee7` + `cc53d95`）：不是产品缺陷，是断言把「请求被接受」当「基地已存在」。
  按拍等待后模式矩阵 **35/35 全绿**（第一次跑到尾）。标「断言纠正」，**不计入已修复**。
- **M-24** → `progress/deferred.md`（重开条件：多人联机/跨机录像判定实测/版本号本来要逼升）。
  未做的行为差异：归档侧的规则差异不进兼容哈希，**代价**是跨机录像兼容会误判；单人本地回放不受影响。
- **S-17** → blocked（阻塞改 M-29，属另一条主线）。**代价**：遭遇战链路继续没有日常门禁，回归仍是 11 条。

**判 done 的依据**：这条主线的用户价值（模式规则生效）已交付且有回归兜住；剩下的两段都不在本线内
（一个在录像层、一个在 option semantics 层），继续挂在本线只会让它变成第二条 C-02。

---

## 五、C-02 主线：整体收口判定（第 25 轮，判 **blocked**）

**账目**：第 15~25 轮共 11 轮，9 个子项（C-02 / b / c / d / e / f / g / h / i），超「≤4 子项 / ≤4 轮」红线两倍以上。
其中**真产品缺陷 3 处**（C-02b 登船互锁、C-02e 建筑进门格被兜底换掉、C-02h 离场被当取消入场），
**夹具/断言口径 5 处**（C-02c/d/f/g 及部分 i 的前置）。这条主线真实产出密度约 27%，其余是「每转绿一段就露出下一段」。

**结论：整条主线判 blocked，不再开第 10 个子项。** 剩余段 C-02i 移入 `progress/deferred.md`。
`command` 那条 known-red 继续以带前缀门禁的形式留在回归里（不隐藏、不注销），它的信号价值由前缀保证。

**C-02i 死因报告（只读结论，本轮未改代码）**
- 现象：`digging=1 carrying=1 cargo=4 credits=0`（3500 拍循环跑满，见 `RuntimeSlaveMinerSmoke.inl:474-499`）。
- **已排除 ①**「`context.credits` 不回写」：`HouseEconomyContext::credits` 是 `int&`（`HouseEconomyContext.h:9`），
  直指 `state.economy.credits`，`runtimeCreditBalanceAfterDeposit` 写的就是真账；排除手段是读结构体定义，不是跑读数。
- **已排除 ②**「`cargoValue<=0` 被当空返」：`task.cargoValue += value` 与 `++task.cargoUnits` 在同一分支同步执行
  （`RuntimeSessionProduction.cpp:7562-7564`），`value<=0` 时提前 return 且**不增** units。
  所以 `cargo=4` 必然伴随 `cargoValue>0`，不可能走「returned empty」分支。
- **剩余候选**（两条改法相反，不许猜）：
  ① 交付分支的前置谓词 `runtimeSlaveMinerWorkerAtRefinery` 从未成立 —— 它要求 `!worker.renderMoveActive`
  且**承诺格与身体格的到地基距离都 == 0**（`RuntimeSessionProduction.cpp:7232-7247`），
  而返程发的是 `findRuntimeEngineerEntryCell(..., "slave-delivery", 2)` 的**地基内**格，两者本该一致，
  不一致只可能是「人到了但 `renderMoveActive` 没清」或「身体格滞后一格」；
  ② 交付分支跑过、`recordRuntimeHouseResourceDelivery` 因 `resourceStorageCapacity==0` 吞掉入库 —— 但 credits
  在容量判断**之前**就已加，故纯容量解释不成立，只可能连带把 cargo 清零后循环重来。
- **第 40 轮实测把 ①/② 都推翻**（读数见 `reports/FIX-40-重排-奴隶矿工全员停在Queued的移动请求上.md`）：
  终态 `w6` 已满足 `dc=0 db=0`，却依然不交付——因为任务步在 `7325-7336` 见到「对象有行为」就 `return false`，
  走不到 `7339` 的交付分支；`cargo` 一直是 `4`，说明交付分支一次都没跑过（②排除）。
  真实现象：**五名工人全部停在 `Queued` 行为且 `renderMoveActive=0`，240 拍里一格没动**（`Queued` 的两义见报告 §四.3，未分开）；
  满载的 `w4` 站在唯一矿格 `24,12` 上，另外三人的离场目标也是这一格 → 结构性互锁。
- **还缺什么（重写）**：(a) 终态下这五个 `behavior.path` 是否为空（「没给路径」还是「给了不推进」）；
  (b) 运动层里「Queued 且 path 非空」为何没被消费。这是重开条件，不是新条目；若 (b) 成立，
  它属新主线 `movement-stall`，**不在 C-02 之下开第 10 个子项**。
- **估值重估**（§七.3）：收益 A→A，成本 中→高（生产侧一处谓词 → 运动层共性停摆），性价比 **A→B**。

**代价（写清）**：尤里的奴隶矿工目前**不产生收入**（挖得动、装得满、交不进去）。这是真实的产品行为差异，
以 blocked 记录在案，不假装已修。

---

## 六、阻塞簇：真开局会话（8 条共用一道门，第 35 轮）

| 条目 | 它要的读数/证据 | 真实前置 |
|---|---|---|
| M-13 / S-17 | 一次真遭遇战开局 + `objects>0` | **M-31**（legacy 段）；`Skirmish start … objects=14` 已由第 37 轮打出 |
| U-19 / U-20 / U-21 / U-23 | 真实窗口里 HUD/载入画面/主菜单小屏/羽化的截图 | M-31 → 真会话 |
| S-08 | `performance/latest.txt` 的复用/重绘三行 | M-31，或把出口解耦（`flushRuntimeFrameDiagnosticsReport`） |
| ON-3-01b | 五界面「上屏自证」的合成输入驱动 | 与上面同一道门，另需 C-01 |

**记账口径（第 35 轮起生效）**：这 8 条里只有钥匙条目带真实成本估值，其余 `cost` 一律指向钥匙，
**不许**再各自写「低/中」——一条链的代价抄 8 份，正是它们排了 4 轮都没动的直接原因。

**第 38 轮更新：这道门已经开了。** 真遭遇战整链路 `rc=0`（`objects 14 -> 38`），并已进 regress 第 12 条。
上表 8 条不再是「等钥匙」，而是「各自去取证」：
M-13 可直接判完成（判据已满足）；S-08 只需把出口拆成 `flushRuntimeFrameDiagnosticsReport()`
供无窗口路径调；U-19/20/21/23 需要真实窗口截图，按「一次会话出四张」合并做（各 1 轮，不许各开一轮）。

---

## 附、skirmish-option-semantics 主线：整体收口判定（第 37 轮，判 **done**）

**账目**：2 个子项（M-29 / M-30），窗口内完成，未开第 3 个。

- **M-29**（`225d310`）：验收样本 NAPOWR 是探针自己编的——零售模式只授予 9 栋对面**基础建筑**，
  从不给电站。改成从探针目录里按 `aiBasePlanningSide` 取。
- **M-30**（`d2fff47`）：验收要求 `techLevel==0`，而发放走 `spawnRuntimeUnholyAllianceMcvs`
  （开局生成，从不读 techLevel；零售三台 MCV 都是 10）。改成数据推导的等价条件 + 反向控制。

**判定依据**：两处都是「把功能没有的性质写进验收」，无真产品缺陷；该线的用户价值
（选模式时规则真的生效）已由 M-22 交付并有模式矩阵 35/35 兜住。
**代价（写清）**：`--skirmish-build-smoke-test` 仍未进 regress，日常门禁还是 11 条；
它剩下的红已不在本线内（legacy 兼容段），继续挂着只会变成第二条 C-02。

**新主线 `persistence-roundtrip`** 开账：1 轮 / 1 子项（M-31），不属于本线续命。

---

## 附二、persistence-roundtrip 主线：整体收口判定（第 38 轮，判 **done**）

**账目**：第 37~38 轮共 2 轮、1 个子项（M-31），未拆新 ID。

- **M-31**（`42db147`）：legacy 段把 v14 存档的版本号改成 10 却留着 16 字段的行为记录，
  v9~v13 的解析器只接受 12 字段 → `invalid behavior record`。这是夹具在撒谎，不是载入太严。
  降版本时截断记录后，整条遭遇战链路首次 `rc=0`。

**判定依据**：本线要证明的是「旧存档能被载入且瞬态集合回基线」，已在真链路上成立，
并由 regress 第 12 条长期兜住。剩下的存档工作是 C-03（存读往返的 simulation hash），
那是另一条线，不在此续命。
**代价（写清）**：没有构造「真·v10 全量夹具」，跨大版本（v10→v14）的字段迁移仍是
「靠 psychic 段那一处覆盖」，不是全量回归。

---

## 附三、S-回归门禁 主线：整体收口判定（第 47 轮，判 **done**）

**账目**：第 43~47 轮共 3 轮（R43 / R44 / R47）、子项 4/4 已满（S-22 done / S-23 done / S-24 blocked / S-25 移出），
**用满即收口，不再开第 5 个子项**。

- **S-22**（R43）：regress 第 13 条 `compactgroups` 接入，13 例 0.7~1s。它接上就照出真红，这是门禁该有的作用。
- **S-23**（R44 定位 / R47 实施，`8e62b4d`）：地面层与空中层按设计共享中心格，落地飞行器把该格变成地面占用，
  正在赶往的坦克被兜底挪到半径 2。改法：落地前礼让「本格被另一地面单位的 `Move` 目标认领」。
  13 例全绿，回归 `12/1/0`。
- **S-24** 留 **blocked**（前置=`RuntimeVehicleInfantryPassThroughSmoke.inl` 进 HEAD，现在仍是并发会话的未跟踪文件；
  未跟踪文件接进门禁，干净树重建后会以别的文案红出来，制造永久假 `cause-changed`）。
- **S-25** 移 `progress/deferred.md`（重开条件见该文件）：它是 `--command-smoke-test` 60 个分支的聚合改造，
  与「门禁覆盖」不是同一件事，继续挂在线上只会变成第二条 C-02。

**判 done 的依据**：本线的用户价值是「编队收敛有在线门禁，且这条门禁真会红」，两者都已交付
（第 13 条 + 一条真缺陷被它照出来并修掉）。

**代价（写清）**：`command` 链尾部 19 步仍然零覆盖（S-25 deferred）；载具穿步兵（M-25 的判据）仍不在门禁里，
也就是说 M-25 修好之后若退化，回归看不见。

---

## 附四、unit-behavior 主线：子项额度与 M-25 的重排（第 48 轮登记，第 49 轮定稿）

**账目**：子项 **4/4 已满**（M-25 / M-26 / M-28 / **S-28**），已用 3 轮（R32 起登记，R48 / R49 各一次方案级推进）。
**第 49 轮起不再开第 5 个子项**；S-28 是最后一个槽位，它就是为了让 M-25 能分两步走而拆出来的。

- **M-25**（attempts=**3**，第 49 轮按 §六.4② 拆出前置）：三段有依赖顺序——
  **S-28 挤压原语（前置）→ A 通行放行 → C 分配器分层（可选）**。
  **A 必须在 S-28 进 HEAD 之后才允许提交**（R44 只解除寻路否决、R48 只放行「停着的」步兵，两次都把
  `12E1_2MTNK_tank_first` 打红 `arrival_timeout`）。语义定稿：载具可进入「只站友军步兵」的格，
  **到达（含目标格）时由运动层把步兵挤到邻格**——两半一起才算修完。DoD 三条同时：判据 `friendlyInfantryCell=1`
  + `compactgroups` 13/13 + regress 零 RED-NEW。方案全文见 `reports/FIX-49-M-25方案-挤压原语与通行放行的顺序.md`。
- **S-28**（中等，本轮从中拆出）：新增 `runtimeDisplaceFriendlyInfantryFromCell`，只挑 Infantry/同阵营/存活/非空中，
  半径 **1~2**（不许更大，C-02h 的教训是半径 6 把矿工搬出自己基地），落位走 `setRuntimeObjectCell`，
  冷却 `nextRepathTick=tick+2` 防两车互挤抖动。`SHAD` 是 `Unit` 不是 `Infantry`，**不进挤压名单**，S-23 的落地礼让不受影响。
- **M-28**（工程师/间谍原地晃动）：`RuntimeSessionWorld.cpp` 的 `advanceRuntimeMoveBehavior` 与
  `RuntimeProductionOperations.h` 的 `findRuntimeEngineerEntryCell` 仍在并发会话的 678 行 WIP 里，**继续不碰**
  ——这也是 S-28 被刻意设计成「单 TU、不落 World.cpp」的原因。
- **M-26**（伞兵落地前点不中）：前置是「原版口径」未答，属取证类，不是代码类。

**额度纪律**：M-25 若第 50 轮仍拿不到产品行为变化，整线按 §六.3 三选一收口（不再拆子项）。
理由：本线已有两次「单点改法打红编队收敛」的实测，继续在通行判定里试错的边际收益已经趋零。

---

## 附五、unit-behavior 主线：整体收口判定（第 50 轮，判 **blocked**）

**账目**：第 48~50 轮共 3 轮、子项 **4/4 已满**（M-25 blocked / M-26 pending / M-28 pending / S-28 blocked），
**产品行为变化 0 次**。窗口用尽，不再开第 5 个子项。

**三次尝试全是负结果**（这是判 blocked 的唯一依据）：
R44 解除寻路层否决 → `12E1_2MTNK_tank_first` 打红 `arrival_timeout`；
R48 只放行「停着的」友军步兵 → 同一处仍红（*在规划时刻问了落位时刻的性质*）；
R49 挤压原语挂寻路结果侧 → 三条冒烟**零触发**，整文件回退（*接缝错*）。

**已排除**：「判别式不够窄」（R48 就是最窄的那一版，仍红）、「接缝在 `applyRuntimeMovePathResult`」（零命中）。
**还缺**：`advanceRuntimeMoveBehavior` 里「即将 commit 进格」那一步的终局否决是谁——一条读数就能定，
但它必须改 `RuntimeSessionWorld.cpp`，而该文件带着并发会话 678 行 WIP（跨 5 轮未提交）。

**判定**：整线 **blocked**。S-28 随线移出到 `progress/deferred.md`（重开条件写在那里）。
M-26 / M-28 仍留在待修复表里但**不属于本线推进**：M-28 的前置是并发 WIP 的
`advanceRuntimeMoveBehavior`＋`findRuntimeEngineerEntryCell`，M-26 的前置是「原版口径」未答（取证类）。

**代价（写清）**：载具被友军步兵堵在终点前这个**用户实测确认**的缺陷继续存在，且不在任何门禁里
（S-24 因此继续 blocked：判据 `RuntimeVehicleInfantryPassThroughSmoke.inl` 仍是未跟踪文件）。
这是真实的产品差距，不假装已修。

---

## 附六、清单治理 主线：整体收口判定（第 51 轮，判 **done**）

**账目**：2 个子项 / 2 轮，**S-14**（`ledger-check.sh` 五项门禁，第 25 轮）、**S-27**（留存策略，第 50 轮）均已交付。
本轮把门禁补到**十项**（新增 `refs-head`：fix-plan 里 `reports/*.md` 引用必须落在 docs HEAD 内），
补的正是「本地有、干净树没有」这一类——R50 把那条未跟踪引用记成「悬空引用」但没法治，因为旧检查判的是工作区。

**判 done 的依据**：这条线要的是「清单自己会量自己、超限当场拦」，十项门禁覆盖体量/结构/字段/引用/磁盘，已成立。
**代价（写清）**：它只保证台账**形状**正确，不保证**内容正确**——S-27 交付两周材料互相矛盾（计划写待修复、
队列写 pending、报告写已落地），十项门禁一条都没报。形状门禁替代不了审计轮的人工对账，别再想加门禁来解决。

**新增纪律（AUDIT-51 起）**：`blocked` 条目的「重开条件」每**审计轮**逐条复查一次——条件开了就回 `pending`，
不许挂着当免死金牌。第 51 轮首次执行，查出 11 条里 6 条的门早已开了（见 `reports/AUDIT-51.md` §五）。

---

## 七、已完成 / 已废弃

条目正文（S-01~S-14、M-01~M-21、C-02a~C-02h 的读数与改法）已归档 →
`reports/archive/fix-plan-202611.md`（第 1~24 轮原文 164 行）。
最近 10 条已完成（一行一条，详情查归档与对应报告）：

**S-20 对战 wire 格式两族编解码器收口（第 53 轮，`6efad17`**：两份「已分叉」的 `ByteWriter/ByteReader` 并成 `network/detail/RuntimeBigEndianCodec.h`，方法取并集、错误文案前缀改构造参数 `label`（既有错误字符串逐字节不变，无断言纠正）、`require()` 统一带守卫；等价性用五条对战冒烟前后输出 `diff` 为空证明；顺带接上 regress 第 14 条 `multiplayer`（0.07s，此前这条 wire 路径零日常门禁）。净 −79 行。`preview-dedupe` 主线随之判 **done**：R36 + R53 共 2 轮 2 子项）｜**M-27 偷星后建造栏补老兵角标（第 52 轮，`dba2daf` + `b08e13c`：奖励早已生效（`applyRuntimeProducedObjectVeterancy` 读 `spies.hasVeteranProduction`），缺的是侧栏绘制点——建造按钮循环从不看 veteran；新增 `runtimeSidebarItemProducesVeterans` + 左下角 chevron（pips 图集，取不到退 `V`），判据为逐像素三连比对 `appearedPixels=24 / restoredDiff=0`。**DoD 改判**：原文「给兵营设 veterancy=2」的数据前提不存在（无建筑级等级），按 owner×类别改判）｜S-27 回归产物与旧交付包没有保留策略（第 50 轮：`regress.sh` 收尾「每天首跑 + 最近 20 次」、`pack-dist.sh` 的 `.archive` 留 5 个；实测目录 157→25（3.5GB→516MB）、包 42→5（3.6GB→481MB）；顺带清掉打包链无策略的 `.bak`（14 份 1.4GB→189MB）并固化成 `scripts/lipo-universal.sh`（备份+lipo+重签+逐切片 minos 校验）。**合计释放 7.3GB**。⚠ 本轮审计发现这条交付后计划/队列两侧都没回写，状态一直停在「待修复/pending」——已修正）｜S-23 飞行器落地礼让地面单位（第 47 轮：`runtimeJumpjetShouldLand` 加一道认领检查——本格被另一地面单位的 `Move` 目标占着时推迟落地，认领消失后照常落；`compactgroups` 13/13 全绿、回归 `12/1/0`；收窄处=只认 `Move`，追击/AreaGuard 不参与，写进报告 §六）｜S-13 结构守卫在 macOS 上第一次能跑（第 45 轮：完整检查链只有 Windows 版——`Run-StructureChecks.ps1` 要 pwsh7+clang-cl+CTest，`--inventory` 由 `Get-TestInventory.ps1` 生成；本轮接上不需要构建产物的两段 `tools/structure/run.sh`（366 例夹具 1.4s + 例外表路径存在性），清掉 16 条死条目〔U-15 的两个 Raster 文件 15 条 + 第 39 轮自删探针 1 条〕；DoD 偏差=完整 scan 仍缺生产者，拆出 S-26）｜S-22 regress 第 13 条：混合编队收敛（第 43 轮接入 `compactgroups`，0.7s / 7 场景；失败文案带「N failed; 首个失败场景: 原因」，前缀连计数一起钉住，两个维度任一变化即 `cause-changed`；DoD「PASS=12」有偏差——该条首跑即红 `3MTNK_3SHAD`，已在摘要写清）｜S-21 重复代码口径落库（`scripts/dup-scan.py`，`--ref 77e75e7` 复现 140/5 并冻结基线；顺带查出「walk 撞构建目录」与「步长 10 别名盲区」两条散文里没有的口径）｜M-13 真实遭遇战开局取证通道（第 38 轮结案：判据「退出码 0 且 objects>0」由 `skirmishbuild` 长期满足，`objects=14`，随第 12 条进 regress）｜M-31 legacy 存档降版本没连记录形状一起降（`42db147`，夹具侧：v14 记录 16 字段带着 `moveSegmentFrom`，v9~v13 只认 12 → 载入拒绝是对的；截断后整条链路首次 rc=0）｜S-17 真遭遇战整链路进 regress（`docs:` 第 38 轮，第 12 条 `skirmishbuild`，首接即真绿 PASS=11）｜M-30 UnholyAlliance 的 MCV 发放不要求 techLevel（`d2fff47`，断言纠正：发放是开局生成，不是侧栏可造；整链路首过 option semantics）｜M-23 电脑开局 MCV「不展开」（`4abfee7`+`cc53d95`，断言纠正：请求被接受≠基地已存在，模式矩阵 35/35）

**已移出主清单的条目**（不占条目数、不进排序，只留指针）：S-25（`--command-smoke-test` 首败即断、
掩蔽链尾 19 步）→ `progress/deferred.md` 第 61 行（第 47 轮随 `S-回归门禁` 收口移出；
**第 54 轮才从本表删掉行**，此前一直留在「待修复」，十项门禁查不出这类内容矛盾）。

更早 10 条（M-23 电脑开局 MCV「不展开」/ S-21 / S-16 / S-15 / S-14 / C-02h / C-02g / **M-22 游戏模式规则从归档读取** / 炮塔炮管共享几何 `04e366d` / 动画层四副本收一份 `1563d7a`）正文已压回
`reports/archive/fix-plan-202611.md`，只留指针——按 §一.2「最近 10 条 done」口径（第 53 轮归档 M-23，等价替换本轮结案的 S-20）。

**第 30 轮审计遗留**：原 12 条 queue-only 条目缺根因与成本。**第 34 轮已全部清零**——但实测是
**16 条**而不是 11 条：审计那 11 条漏了 8 条「fix-plan 条目的队列侧镜像」（`ON-2-06≈S-08`、
`ON-2-02b≈M-04`、`EVO-03≈M-07`、`EVO-04≈M-06`、`EVO-05≈C-03`、`EVO-13≈M-05`、`EVO-14≈C-04`、
`EVO-15≈C-01`），第 32 轮并发会话又新登记了 `M-25~M-28`、`EVO-06`。
处置：7 条补估值留 pending / 4 条 UI 对账降 blocked（死因=真实开局取证通道未绿，离屏空白不能当证据）/
8 条镜像估值指向 fix-plan / `ON-3-02` 已移 deferred。**防复发**：`ledger-check.sh` 第 7 项
`entry-fields`（缺 6 个字段任一即 `LEDGER-BREACH`，已负向测过会报 `1 M-25`）。

---

## 八、轮次索引（一行一轮；原文见 `reports/fix-plan-archive.md` 与 `reports/archive/`）

| 轮 | 日期 | 主题 | 报告 |
|---|---|---|---|
| 54 | 2026-11-15 | EVO-07 第一步：`--version` 自报版本/架构/编译时刻 + 包内 BUILD-INFO 构建戳；pack-dist 新增第 ⑨ 门禁（包内身份自证） | `reports/FIX-54-版本身份自证与打包链新门禁.md` |
| 53 | 2026-11-15 | 对战 wire 格式两族编解码器收口（S-20）；「合并必然改文案」被证伪，成本 中→低-中；regress 接第 14 条 | `reports/FIX-53-对战wire格式两族编解码器收口.md` |
| 52 | 2026-11-15 | 偷星后建造栏补老兵角标；M-27 的 DoD 数据前提被改判（无建筑级等级） | `reports/FIX-52-偷星后建造栏补老兵角标.md` |
| 51 | 2026-11-15 | 审计：11 条 blocked 里 6 条的等门条件早已满足（没人复查）；S-27 交付后两侧未回写；门禁九→十项（`refs-head`） | `reports/AUDIT-51.md` |
| 50 | 2026-11-15 | 清偿：留存策略落地（regress 每天首跑+最近 20 次、`.archive` 留 5 个，释放 6.1GB）；unit-behavior 主线判 blocked | `reports/FIX-50-留存策略与M-25主线收口.md` |
| 49 | 2026-11-15 | 方案：M-25 的挤压原语必须先于通行放行；M-25 attempts=3，拆出前置 S-28（unit-behavior 第 4/4 子项） | `reports/FIX-49-M-25方案-挤压原语与通行放行的顺序.md` |
| 48 | 2026-11-15 | 重排：M-25 的「只放行停着的步兵」判别式被 `tank_first` 打红——规划时刻问不了落位时刻的性质；M-25 改判复杂 | `reports/FIX-48-M-25挤压缺位移-读数与重排.md` |
| 47 | 2026-11-15 | S-23 结案：飞行器落地礼让正在赶往同格的地面单位；`compactgroups` 13/13，回归 `12/1/0`；`S-回归门禁` 主线收口 | `reports/FIX-47-飞行器落地礼让地面单位.md` |
| 46 | 2026-11-15 | 审计：连续 8 轮零产品行；重复代码首次可复现；登记 S-27（磁盘） | `reports/AUDIT-46.md` |
| 45 | 2026-11-15 | S-13 结案：结构守卫接上 macOS 可跑的两段（夹具 366 例 + 基线路径存在性），16 条死条目清零；登记 S-26 | `reports/FIX-45-结构守卫在macOS上第一次能跑.md` |
| 44 | 2026-11-15 | S-23 根因确认：地面目标格被落地飞行器占着；登记 S-25（command 链掩蔽 19 步）；纠正 .ninja_deps 误判 | `reports/FIX-44-混合编队地面层被落地飞行器占格.md` |
| 43 | 2026-11-15 | regress 第 13 条：混合编队收敛进门禁（S-22）；首跑暴露 3MTNK_3SHAD 真红（S-23） | `reports/FIX-43-regress接入混合编队收敛门禁.md` |
| 42 | 2026-11-15 | 清偿：RUNLOG 归档（8,178→640 行）+ 重复代码口径落库（S-21，复现 140/5） | `reports/FIX-42-清偿轮-RUNLOG归档与重复代码口径落库.md` |
| 41 | 2026-11-15 | 审计：重复代码指标三轮三个数（口径无脚本）；regress 12 条不覆盖混合编队收敛 | `reports/AUDIT-41.md` |
| 40 | 2026-11-14 | 重排：五名奴隶矿工停在 `Queued` 的移动请求上，C-02i 的 ①/② 被同时推翻 | `reports/FIX-40-重排-奴隶矿工全员停在Queued的移动请求上.md` |
| 39 | 2026-11-14 | 清偿：两处一次性阶段探针清零（−27）；写下四处「看着该删其实不能删」 | `reports/FIX-39-清偿轮-一次性阶段探针清零.md` |
| 38 | 2026-11-14 | legacy 存档降版本要连记录形状一起降（夹具侧）；S-17 进 regress（12 条） | `reports/FIX-38-legacy存档降版本要连记录一起降.md` |
| 37 | 2026-11-14 | unholy 段要求 techLevel=0 是假门；读档残留特效（产品修） | `reports/FIX-37-遭遇战整链路的两道假门与读档残留特效.md` |
| 36 | 2026-11-14 | 清偿：炮塔/炮管与动画层解析两族克隆收口（−103）；登记 S-20 | `reports/FIX-36-清偿轮-两族克隆实现收口.md` |
| 35 | 2026-11-14 | 审计：8 条条目共用「真开局会话」一道门；S-08 判 blocked；立 M-30 | `reports/AUDIT-35.md` |
| 34 | 2026-11-14 | 帧诊断记「复用/重绘」；11 条缺估值条目实测是 16 条 | `reports/FIX-35-帧诊断记复用与重绘.md` |
| 33 | 2026-11-14 | 地图预览自带第二份 TMP 解码器（清偿：−638 行，待 A/B） | `reports/FIX-34-地图预览自带第二份TMP解码器.md` |
| 32 | 2026-11-14 | UnholyAlliance 的验收样本（NAPOWR）是探针自己编的；`ownerFactory` 转绿 | `reports/FIX-33-UnholyAlliance的验收样本是探针自己编的.md` |
| 31 | 2026-11-14 | 电脑开局 MCV 是「转向后落地」，不是没展开；35/35 全绿 + 主线收口 | `reports/FIX-32-电脑开局MCV是转向后落地.md` |
| 30 | 2026-11-14 | 审计：queue 46→35、2 条状态矛盾、TMP 解码双实现、主线子项已满 4 | `reports/AUDIT-30.md` |
| 29 | 2026-11-13 | 游戏模式规则从归档读取（模式从静默无效到生效） | `reports/FIX-31-游戏模式规则从归档读取.md` |
| 28b | 2026-11-13 | 挂机 37GB 内存爆炸：光标同步在 autoreleasepool 外（用户报障追加轮） | `reports/FIX-30-挂机内存泄漏-autoreleasepool.md` |
| 28 | 2026-11-13 | 真遭遇战取证通道早已存在；20 项 `no` 的共因是模式规则读不到（重排） | `reports/FIX-29-真实遭遇战通道已存在.md` |
| 27 | 2026-11-13 | 五族一次性探针清零（清偿：净增 −319 行） | `reports/FIX-28-探针清零第二批.md` |
| 26 | 2026-11-13 | 删掉跨轮存活的探针（清偿：净增 −126 行） | `reports/FIX-27-删掉跨轮存活的探针.md` |
| 25 | 2026-11-13 | 清单治理达标 + C-02 主线收口（判 blocked） | `reports/FIX-26-C-02主线收口与清单治理.md` |
| 24 | 2026-11-13 | 「入场恢复」不该吃掉「离场」 | `reports/FIX-25-奴隶矿工离场不该被当成取消入场.md` |
| 23 | 2026-11-13 | 硬编码坐标窗口 vs 子格几何 | `reports/FIX-24-奴隶矿工出舱的子格偏移.md` |
| 22 | 2026-11-13 | 验收把「测试自己的坐标假设」写死了 | `reports/FIX-23-MCV拆包落点是地基锚点.md` |
| 21 | 2026-11-13 | 建筑吸收器的进门格不该被兜底目标换掉 | `reports/FIX-22-生物反应堆进门格不被兜底换掉.md` |
| 20 | 2026-11-13 | 把「赌排队次序」的断言改成按拍等待 | `reports/FIX-21-混编段按拍等待.md` |
| 19 | 2026-11-13 | A 方案落地——出舱步兵走开，环自然腾空 | `reports/FIX-20-两栖卸载外侧终点.md` |
| 18 | 2026-11-13 | 不是「有人卡住」，是「先出来的人把环站满」 | `reports/FIX-19-卸载终态是被站着的人占满环.md` |
| 17 | 2026-11-13 | 把「600 拍不放空」拆成八格拒绝表 | `reports/FIX-18-整仓卸载的八格拒绝表.md` |
| 16 | 2026-11-13 | 用一档读数否掉计划里的 A 方案 | `reports/FIX-17-登船互锁解除与卸载新阻塞.md` |
| 15 | 2026-11-13 | 把「12 人只上 10 人」拆到具体那道门 | `reports/FIX-16-登船互锁的四道门计量.md` |
| 14 | 2026-11-12 | 把两条「读一句话就动手」的旧结论拆到底 | `reports/FIX-15-框选结案与两栖卸载真阻塞点.md` |
| 13 | 2026-11-12 | 一条十二轮没被质疑过的断言其实没跑过产品路径 | `reports/FIX-14-框选断言穿过消息循环.md` |
| 12 | 2026-11-12 | 判定器自身的可信度 | `reports/FIX-13-known-red失败前缀门禁.md` |
| 11 | 2026-11-12 | 关于「可见像素」的断言必须先对焦 | `reports/FIX-12-命中样本落在视口外.md` |
| 10 | 2026-11-12 | 先修那道「假门」 | `reports/FIX-11-被known-red掩盖的新回归.md` |
| 9 | 2026-11-12 | 把「掩码有效」与「真的画了」分开 | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` |
| 8 | 2026-11-12 | 一次被自己的计数器否决的定性 | — |
| 7 | 2026-11-12 | 把 `code-red:needs-metering` 清零 | — |
| 6 | 2026-11-12 | 把连红五轮的 `build` 清到底 | — |
| 5 | 2026-11-12 | 多谓词断言必须逐项计量 | — |
| 4 | 2026-11-12 | 夹具缺口 + 观感硬伤，两条都不动模拟层 | — |
| 3 | 2026-11-12 | 两条判红的根因都在断言口径 | `reports/FIX-04-两条断言的几何口径.md` |
| 2 | 2026-11-12 | 「资产缺口 vs 产品缺陷」口径 | `reports/FIX-03-回归门禁口径三连.md` |
| 1 | 2026-11-12 | — | — |
