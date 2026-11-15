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
> **本轮（第 69 轮，2026-11-16）收口摘要 —— 重排轮（修复轮途中触发 §七）**
> 1. 轮型：开轮判修复轮，T+30 三条候选的根因假设**全部被实测推翻** → 按 §七.2 转重排，只做诊断 + 重排。
> 2. 旧顺序错在哪：R68 把「U-19 前先验 `--skirmish-build-smoke-test` 能不能出世界帧」写成了**一句前置验证**，
>    实测它是**要新建一条呈现通道**——该冒烟全程无 `CreateWindow`/`WM_PRINTCLIENT`/渲染调用
>    （`renderCheck=0.00ms` 就是因为那段没跑），17 条 smoke 的 artifacts 里零张世界帧。
> 3. 三条否决：①FPS 叠加层「默认常显」早在 `c1ccfe6`(11-12) 改为 opt-in，UI-01 §3.1 是死结论；
>    ②遭遇战国家列 `???` 是 Random 旗 `rani.shp` 的**位图内容**（`grep '???'` 零命中、`flagFor` 非空才 blit）；
>    ③放建筑 `placementSearch=1553ms` 出自诊断兜底路径，证不了用户路径会卡。
> 4. **登记 U-24 世界帧出口**（收益 A / 成本 中 / 中等，1 轮）：验收=一条命令出不带窗口的真实开局 800×600 BMP，
>    图里侧栏 168px / 资金数字 / 建筑 / 单位都在，且按像素数而非文件存在判。等价归档 S-24。
> 5. **M-03 按 §六.5 换赛道暂停**（连续 2 轮无产品行为变化）；再启必须 §六.3 三选一，不许第四次「先补对账」。
> 6. 质量：净增 **0/0**（源码无改动）；90,635 / 42,542 / 31,056 零变化；断言 0/0；TODO 0。清单 239 行 / 41 条 / 66KB 全绿。
> 7. **欠账（下轮必须还）**：连续第 4 轮无产品行为变化——U-24 下轮必须真的出图，否则按 §六.3 收口 U 线。

> **历史收口摘要索引（一行一轮，原文见 `reports/fix-plan-archive.md`）**：
> R68 修复：S-39 结案（载入页呈现冒烟进 regress 第 17 条 `loadingpages`，0.56s）+ 产物落点收成
> `RuntimeSmokeArtifacts.h`（源码树 `build/` 31MB→6.4MB，`f0c8f06`/`755abf2`）｜
> R67 修复：U 线取证入口实测一直存在（`CONCORD_LOADING_PRESENTATION_ONLY`），U-20/U-21 结案、
> U-23 移 deferred；产品修复=载入页缩略图铺满 216x166 槽位（槽位纯黑 21.7%→0.3%，`d60b1c7`）
> + 槽位内容门禁（`6cab55d`）｜
> R65 修复（`§六.5` 强制换赛道→打包与文档）：说明书的「回归现状」改为打包时现场生成，
> `--check` 照出上一版写的是 15 条/13 绿（`20af5cf`/`6aa4673`）｜
> R64 修复：S-37 二进制自证补齐两侧——`--version` 新增 `built:`，`compiled` 降为下界；
> regress 改「脏树→+WIP / 旧二进制→WARN」，伴生修 `build-health.sh` 分母（`73be404`）｜
> R63 修复（负结果）：删掉压住细判据的重绘兜底，静置 CPU 21.1%→20.8% 证明假设错（`25b6c53`）｜
> R62 清偿：战役动作白名单去重（−140/+3，`897de11`）+ 主线账目段 199 行压成 9 行表，登记 S-36｜
> R61 审计：EVO 主线判 done（②③ 移 deferred）+ S-24 补判 done + 重复代码首次可复现归因（`e29e63c`）｜
> R60 M-26 伞兵下落中可选：真因是 `cleanRuntimeSelection()` 每拍踢出选中，不是命中框（`e382dae`）｜
> R59 清单自证：`refs-in-queue`（S-32）照出 M-25 根因报告从未入库 + 交付说明书三处事实过时（S-33）｜
> R58 载具穿步兵判据进门禁 + 678 行并发 WIP 入库（`96ed2ee`）｜R57 构建与回归自证：
> build-health 三态 + regress 钉住 HEAD/compiled（`b4672b5`）｜R56 审计：两轮主目标不在台账、
> 6 条「门已开」的 blocked 挂 5 轮、`.ninja_deps` 截断复发（`03fd1b2`）。

---

## 一、待修复 —— 简单

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | attempts | 状态 | 验收条件 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| S-38 | BUILD-STAMP 仍靠人手写 | 第 65 轮打包后实测：包都验完了，`dist/BUILD-STAMP.txt` 仍停在上一轮的 `73be404/R64`，直到手工覆盖才与 HEAD 一致 | `§十二.5` 把「覆盖写 BUILD-STAMP」写成了**对人的动作**而不是脚本的收尾，而它又是判断 dist 新鲜度的唯一依据 → 忘了写 = 门禁看的那一行在说谎，且没有人会被提醒。与 S-34（说明书手写）同一形态 | **A**：dist 新鲜度判据本身不可信时，所有「dist 是最新」的结论都不成立 | 低：hash/时间/arch/minos/icon/buildtree 全在脚本手上；regress 三态从 `latest.txt` 读；新增一次 `arch -x86_64 --smoke-test`（约 1s，本来每轮手工跑） | **A** | 简单 | 1 | **已完成（第 66 轮，`f0826d5`）**：`pack-dist` 新增第 ⑫ 步自写；icon 比对改为回传数值；`regress=` 只认「HEAD + 干净树」那一跑，否则 `stale@<hash>` + WARN；x86_64 切片补 Rosetta 冒烟且失败不出包 | 不手工写任何文件时 stamp 首字段 == `git rev-parse --short HEAD`（实测 `6aa4673`）；`latest.txt` 的 source 不符 → `stale@`（已先红后绿）；无 `latest.txt` → `unknown` 而非抄旧值 | `reports/AUDIT-66.md` |
| S-39 | 载入页的取证入口不在门禁里 | U 线卡了六轮的说法是「拿不到真实窗口的载入帧」，而 `CONCORD_LOADING_PRESENTATION_ONLY=1 --loading-smoke-test` 一直能抓 11 页 × 两尺寸的生产窗口位图；但它是**手工跑**的，regress 里没有这一条，且 14 张 BMP 硬编码写进源码树 `build/` | 判据存在但不在日常门禁 = 事实的生产者与消费者之间缺一步。与 S-08（读数一直在文件里）、M-13（通道一直在）、S-38（脚本手上已有数值）同一形态，**第四次** | **A**：U-19 的 HUD 取证下一步就靠它；且 R67 那条产品修复（铺满槽位）没有门禁兜住就没意义 | 低：一条 `run_case`（实测 0.56s）+ 把落点参数化（一个 helper） | **A** | 简单 | 1 | **已完成（第 68 轮，`f0c8f06` + `a30ea22`）**：`runtimeSmokeArtifactPath()` 认 `CONCORD_SMOKE_ARTIFACT_DIR`（默认仍 `build/`），regress 第 17 条 `loadingpages` 把它指到本轮 artifacts；源码树 `build/` 31MB→6.4MB | regress 出现第 17 条且 PASS；跑完 `ConcordRTS/build/` 不再新增 `loading_*.bmp`（实测 14 张落进 `artifacts/loadingpages`） | `reports/FIX-68-载入页呈现冒烟进回归门禁.md` |
| S-40 | 其余冒烟仍把产物写进源码/数据树 | 实测 `ConcordRTS-GameData/build/` 有 `result_mission_victory.bmp` / `result_mission_defeat.bmp` / `result_players_allied.bmp`，`ConcordRTS/build/issue22_15_vehicle_terrain_slope/` 也在；与 S-39 同型但**不在同一主目标**内 | 写盘点各自硬编码相对路径 `build/`，没有统一出口；regress 的 cwd 是数据根 → 产物落进数据树，且绕开 R50 的留存策略 | **B**：磁盘占用 + 「数据树里混进生成物」会让人误以为它是数据的一部分 | 低-中：result 冒烟两处 + issue22 目录一处改调 `runtimeSmokeArtifactPath`，但 helper 现在在 loading 的 `.inl` 里，要先抽成公共诊断头 | **B** | 简单 | 1 | **已完成（第 68 轮，`755abf2`，伴生小项）**：落点抽成 `runtime/host/diagnostics/RuntimeSmokeArtifacts.h`（专用 env > `CONCORD_SMOKE_ARTIFACT_DIR` > 历史默认），result/slope 两处改用；实测两棵树的 bmp 均为 0，产物全在本轮 artifacts | 连跑 regress 两轮后 `ConcordRTS/build/` 与 `GameData/build/` 都不再新增产物；生成物只出现在本轮 artifacts | `reports/FIX-68-载入页呈现冒烟进回归门禁.md` §五 |
| M-19 | `NATBNK` 没有 temperate 美术 | `body=0x0 frame=0x0`，`2 loaded, 0 missing` 却什么都画不出来；`2peaks.map` 是 TEMPERATE | 资产缺口：`NewTheater=yes` 但导出集只有 `art/snow/natbnk.shp` | 中：任何「建筑可见/可点/有影子」的断言在该图上不可满足 | 补 temperate 变体，或让冒烟换图 | **C** | 简单 | 0 | 待修复（不阻塞门禁） | `2peaks.map` 上该建筑 `structureNoArt=0` 且 `drawn>0` | `reports/FIX-10-阴影掩码四桶与结构自证帧.md` §2 |
| S-19 | 地图预览产物的旧/新 A/B 没做 | 第 33 轮把 `MapPreviewExporter` 的分叉解码器换成 `RuntimeTmpCodec`（−647 行），但预览产物**没做逐字节对比** | `/tmp/tiles` 能从 `--extract-map-tiles` 抽到 213 块瓦片，但 `--export-map-tmp-preview` 卡在 `failed to open file: …/isotem.pal`（该调色板只在归档里） | 中：不做完，「删了 647 行且行为不变」这句话就不成立；做完全轮结论才闭环 | **高**（第 34 轮推翻上一轮的「30 分钟」：无按名抽取 MIX 的 CLI，要自己实现 Westwood CRC；旧二进制要另建构建树整编） | **B**（原 A，因成本翻倍而降） | 中等 | 0 | 待修复（前置=MIX 按名抽取 + 第二构建树） | `isotem.pal` 落进 palette-dir 后，`git show b2ebc4c^:src/assets/preview/MapPreviewExporter.cpp` 编旧二进制，两次 `--export-map-tmp-preview` 的 PPM **sha256 相同** | `reports/FIX-34-地图预览自带第二份TMP解码器.md` §四 |
| S-29 | regress 报告不记源码版本 | `report.md` 只记二进制 sha256(前16)+mtime，判不出「这个二进制是不是 HEAD 编的」；R55 实测 arm64 半边落后 16 小时正是这类盲区 | 判据只写「测了哪个二进制」，没写「对应哪个 commit」；编译时刻与 `git log -1 --format=%ci` 一比即知，但这个比较没人做 | **A**：让「回归 13/1/0」绑定具体 HEAD，否则 BUILD-STAMP 的 regress= 可能是别的树测的 | 低：报告头 3 行（取 `--version` 的 compiled + 与 HEAD 提交时刻比，落后打 WARN） | **A** | 简单 | 1 | **已完成**（`regress.sh`：`source <hash>[+WIP]` + dirty 数 + 自报 compiled；实测直接照出 R56 那 8082s 偏差） | 报告头出现 `source: <hash> compiled=<时刻>`；换回旧二进制必须打 WARN 而不是静默通过 | `reports/FIX-57-构建与回归的自证门禁.md` §二 |
| S-30 | 构建状态损坏无检测（`.ninja_deps` 截断复发） | arm 目录 `ninja -n` 要 1647 目标，`-d explain` 首行 `premature end of file; recovering`、脏因全是 `stored deps info out of date`；同时刻 x86_64 报 `no work to do` | 疑为并发写：两会话同时在一个构建目录跑 ninja，`.ninja_deps` 追加写入被截断。R41~43 三轮把这现象归因成「改了 cmake」而放弃源码修复 | **A**：误诊一次吃掉一整轮（R41~43 三轮）；一条检测把它变成一句明确提示 | 低：`ninja -n` 逐目录判定，命中截断或待办>30% 报出 | **A** | 简单 | 1 | **已完成**（`scripts/build-health.sh` 三态；接进 regress 预检与 pack-dist 组装前。**修法纠正**：全量重编修不回来，要删 `.ninja_deps`+`.ninja_log`） | 人为截断尾部后跑 regress 必须打 WARN 且退出码不变；正常状态零输出 | `reports/FIX-57-构建与回归的自证门禁.md` §一 |
| S-32 | 台账引用只查了一侧（队列侧无门禁） | `refs-head` 只遍历 `fix-plan.md` 的表格；`queue.json` 里的 `reports/*.md` 从来没人查。第 59 轮把三份未入库报告写进 queue，十一项门禁全绿 | R51 加 `refs-head` 时判对了树（判 HEAD 不判工作区），但只补了**一侧**——与 MIN_MACOS「只查一侧」同一形态 | **A**：台账是所有轮次的输入，它的链接指到不存在的文件等于台账在说谎；新门禁第一跑就照出 M-25 根因报告从未入库 | 低：`ledger-check.sh` +22 行，遍历 `tasks[].report(s)` 逐个 `git cat-file -e HEAD:` | **A** | 简单 | 1 | **已完成**（`ledger-check.sh` 第十二项 `refs-in-queue`；同时把 13 条 `ra2mac_docs/` 前缀的旧路径规范化） | 把一份未提交的报告写进 queue 的 `report` 字段后跑门禁必须 `LEDGER-BREACH refs-in-queue`；提交后转绿 | `reports/FIX-59-清单自证与交付说明书事实对账.md` §二 |
| S-33 | 交付说明书的事实过时（三处会误导操作） | `dist/README.txt`：①「共 14 条：13 绿 / 1 known-red」②「M-25 判据还没进 HEAD，所以不在日常门禁里」③数据根搜索顺序漏掉「包内指针最优先」 | 根因不是忘了改，是**没有任何东西量它**：pack-dist 每次覆盖写这份文件，却从不断言内容；它引用的事实散在 scripts / queue / regress 三处，谁改都不会想到回来改 | **A**：包要发给别人，说明书里写错的步骤会让人白折腾一轮；③尤其危险——按说明书设了环境变量却无效 | 低：改 3 段 + 文件头加「最后核对：轮次 + hash」 | **A** | 简单 | 1 | **已完成**（`ConcordRTS/packaging/README-dist.txt`；同时把「dmg 不常驻 dist」写进开头，并删掉那份挂旧 hash 的 dmg） | 三处与 `20261115-204728/report.md` 的汇总行、`known-red.tsv` 第 2 条、`RuntimeConfigPaths.cpp` 的搜索顺序逐字一致 | `reports/FIX-59-清单自证与交付说明书事实对账.md` §三 |
| S-37 | 「二进制自证」只查了 WIP 一侧（且读错字段） | 第 63 轮打包时包内自报 `compiled=Nov 15 19:25:24`，而二进制是 00:18 刚链接的；`regress.sh` 报告头对这 3.7 小时的落后一声没吭 | `compiled` 取自 `RuntimeMain.cpp` 一个 TU 的 `__DATE__/__TIME__`，增量构建不重编 → 它既不能证明「是这版」也不能证明「不是这版」；R57 的 WARN 又只判「比 HEAD 新」一侧——与 MIN_MACOS「只查一侧」同一形态，第三次 | **A**：这条坏了，S-29 想防的「测的不是 HEAD」照样漏 | 低（实测）：`--version` 取自身 stat mtime + 同架构两向判据；`RuntimeMain.cpp` 重编仅 1.5s | **A** | 简单 | 1 | **已完成（第 64 轮，`73be404`）**：`--version` 新增 `built:`（落盘时刻），`compiled` 降为下界；`regress.sh` 改「树脏 → +WIP / `built` 早于 HEAD → WARN」两向。**原 DoD 后半句按断言纠正处理**（「正常构建时 compiled 与 mtime 差 <60s」不重编时必然不等且正常）；伴生修掉 `build-health.sh` 的分母（进度行「本次剩余」→ `ninja -t targets all`） | 旧二进制或脏树必须打 WARN（已先红后绿地负向测过）；`built` 与 `stat` 的 mtime 逐字一致 | `reports/FIX-64-二进制身份自证补齐两侧.md` |
| S-34 | README 的回归现状靠人手写 | 说明书里「共 15 条：13 绿 / 2 known-red」**已经是假的**：R59 手工改对 14 条，R60 加第 16 条 `paradropsel` 又错，门禁一条没报 | 事实的生产者是 `regress.sh`、消费者是 `packaging/README-dist.txt`（被 pack-dist 原样 `cp` 进包），中间缺一个生成步骤——S-33 的处置只到「手工核一次」，与 S-37「只查一侧」同形态（第三次） | **A**：包要发给别人，说明书里的回归读数错了就等于交付物在说谎，且没有人会被提醒 | 中：regress 多写一行汇总 + 生成器 ~200 行 + pack-dist 接一步，零 C++ | **B** | 中等 | 1 | **已完成（第 65 轮，`20af5cf` + `03e4247` + `6aa4673`）**：`latest.txt`（一行 k=v）→ `render-readme.py`（标记替换 / `--check` / 无数据 rc=3）→ pack-dist 第 ⑩ 步；非 0 一律 exit 1。**已知残留**：known-red 的「用户可见含义」仍是人写（无廉价判据，已注明转绿后手删） | `render-readme.py --check` 对打包前的 `dist/README.txt` 必须退出码 1 并指出「应是 16 条/14 绿」；改 `known-red.tsv` 条数后重打包，说明书里该段自动跟着变 | `reports/FIX-65-说明书里的回归现状改为生成.md` |


## 二、待修复 —— 中等

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | attempts | 状态 | 验收条件 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| U-24 | 世界帧没有出口（U-19 HUD 对账的真前置） | 17 条 smoke 的 artifacts 里只有菜单/载入/结果页，**零张世界帧**；`--skirmish-build-smoke-test` 建了完整世界（部署 MCV、放 10 栋建筑）却全程无 `CreateWindow`/`WM_PRINTCLIENT`/渲染调用，`renderCheck=0.00ms` | 载入页能出帧是因为它**真建了生产窗口**（`CONCORD_LOADING_PRESENTATION_ONLY`）；世界路径没有对应物。与前四次「入口其实有、只是没接进门禁」**不同型**：这次入口真的不存在，要造 | **A**：一条解锁 U-19 整块（8 个子项）＋ UI-01 三条证据不足项；它是「世界里的东西画得对不对」唯一的帧级判据 | 中：世界路径要一个能 `WM_PRINTCLIENT` 的宿主，载入页那条通道可复用约 80%，预计 1 轮 | **A** | 中等 | 0 | 待修复（第 69 轮登记，重排后第 1 顺位） | 一条命令（`CONCORD_WORLD_PRESENTATION_ONLY=1 --skirmish-build-smoke-test` 或等价）**不开用户可见窗口**就把真实开局渲成 800×600 BMP 落 `CONCORD_SMOKE_ARTIFACT_DIR`；图里侧栏 168px / 资金数字 / 已知建筑 / 单位都在，**按像素数判**（蓝图区非空、数字区有非背景像素、cameo 非空）而不是「文件存在」 | `reports/FIX-69-重排-世界帧出口才是U19的前置.md` §三 |
| EVO-07 | 首次启动引导 + dmg 分发（**R54/R55 主目标，第 56 轮审计补行**） | 包发给别人后三问答不上：数据树放哪、这算哪一版、怎么装；无数据树时 `--smoke-test` 仍 rc=0 | 身份只活在**包外**（`dist/BUILD-STAMP.txt`），包一拷走判据就断；pack-dist 查了 id/icon/minos/包内 smoke，**唯独没查「plist 与包内二进制是否同一版」**；②③ 要新开 AppKit 模态面，本项目不调 `sendEvent`、Accessibility 未授权 → 交互路径本环境不可验证 | **A**：交付物能自证「我是哪一版、数据在哪」 | 四段式：①`--version`+包内 BUILD-INFO（已交 `9477056`）④dmg+说明书入库（已交 `10013d1`/`b4672b5`）；②About ③数据根提示各需一处新模态面 | **A** | 中等 | 2 | **已完成（第 61 轮整体收口，分段交付）**：①④ 交付且有门禁（`pack-dist ⑨` 逐包断身份）；②③ 判据缺失（本项目不调 `sendEvent`）→ 移 `progress/deferred.md`，**重开条件 = C-01 落地后**。未做的行为差异与代价见 AUDIT-61 §六 | ②About 三字段上屏后与 `--version` 一致；③把数据根移走后双击出现可读提示、选目录后能继续启动 | `reports/AUDIT-61.md` §六、`reports/FIX-54-版本身份自证与打包链新门禁.md`、`reports/FIX-55-dmg分发与说明书入库.md` |
| M-03 | 世界 idle 空转重绘 | 静止时也每 tick 全量重绘：真会话 7492 帧里 7479 帧重绘、33 次/秒、`renderMs≈16ms` | 原假设「`tickAdvanced` 无条件置 `repaintRequested` 是来源」**第 63 轮被实测推翻**：删掉那处兜底后静置 CPU 21.1%→20.8%（噪声）。真来源是 `simulationChanged` 的语义——它汇总**模拟侧**变化（effects/economy/triggers/动画 tick/移动），对战里每拍为真，不等于画面变。三条候选未定量：①动画计时器每拍递增但 SHP 帧号按 delay 才变 ②位姿亚格内推进落在同一像素 ③`continuousRuntimeFrame` 每帧都 Invalidate | 中：功耗与风扇 | 场景签名门必须建在「画了什么」（对象位姿帧号+动画帧号+相机+选中集+遮罩版本），每 30 拍强制重绘兜底 | **B** | 复杂 | 2 | **待修复（第 63 轮假设被推翻，`§七`）**：下一步只许先补「画面签名 vs 实际像素」逐帧对账拿到比例，不许直接改 `continuousRuntimeFrame` | 静止 3 秒内提交帧数下降 ≥80% 且画面无冻帧（人静置档，本环境造不出，需录像比对） | `reports/FIX-63-空转重绘的根因假设被推翻.md` §二 |
| M-04 | 提交节奏对齐显示刷新 | 帧提交与 60Hz 不同步，偶发丢帧/撕裂 | 用定时器而非 display link | 中：画面平滑度 | 接 CVDisplayLink | **B** | 中等 | 0 | 待修复 | 连续 600 帧间隔抖动 <2ms | `reports/ON-2-02a-呈现节奏计量与主人帧修复.md` |
| M-05 | 尤里复仇战役未接入 | 战役菜单只有基础版 ra2 任务 | 战役数据库只装了 ra2 的 mission 表 | 中高：资料片内容缺失 | 数据层接入 + 校验 | **B** | 中等 | 0 | 待修复 | YR 战役列表与 retail 任务数一致且能开局 | `reports/Q-04-RA2与YR拆分盘点.md` |
| M-06 | 日志与崩溃现场落地 | 崩溃后没有现场，只能靠重跑 | 无统一日志出口 | 中：排障效率 | 日志出口 + `--collect-diagnostics=<zip>` | **C** | 中等 | 0 | 待修复 | 人为崩溃后 zip 里含日志与栈 | — |
| M-07 | diagnostics 驱动入口 | 无人值守走不完 菜单→大厅→载入→世界（autostart 钩子已删） | 缺一个脚本化入口 | 中：自动化上限；M-13 同源 | 新增 CLI 驱动 | **C** | 中等 | 0 | 待修复（与 M-13 合并落地） | 一条命令无人值守进到世界并出帧 | — |
| S-23 | 3 台 MTNK 收在半径 2 而不是 3x3 | 第 13 条 `compactgroups` 里 `3MTNK_3SHAD` 终态 `groundRadius=2`；地面 3 台的目标格 (32,28)/(33,28)/(31,29) 与空中 3 架 SHAD **完全同格**，SHAD 终态 `airborne=0` | **已确认**：落位侧冲突——飞行器到达后落地（airborne 0）重新进入地面占位，压住地面单位的目标格，坦克被兜底挪到最近空格且不回填。`ground_target_reclaimed` 零触发 → 不是「先停再推」。分配器共格是被要求的（两层都必须用中心格），**不是修点** | **A**：这是「编队收得散不散」的唯一在线门禁，修好才有真绿基线 | 中：改落位分支（飞行器静默保持 airborne，或落地避开地面已认领格）；13 场景 0.7s 即时验 | **A** | 中等 | 1 | **已完成（`8e62b4d`，产品修复；第 44 轮定位、第 47 轮实施）** | `3MTNK_3SHAD` 的 `groundRadius=1` 且 `ground_final_cells` 不退化；同批 12 例保持 PASS；known-red 该行可注销 | `reports/FIX-44-混合编队地面层被落地飞行器占格.md`、`reports/FIX-47-飞行器落地礼让地面单位.md` |
| M-29 | UnholyAlliance 的验收样本是探针自己编的 | 完整链路第一道门 `option semantics ownerFactory=no unholy=no`。读数：模式只授予 9 栋对面**基础建筑**（无电站）；`loadedCatalog=46` 不含任何苏军条目；三台 MCV 走 rules 层而非目录段 | 原样本钉 NAPOWR/YAPOWR，零售模式从不提供该建筑 → 测的是不存在的规则 | 高：S-17 / M-13 的剩余门 | 低：已改完，剩 `unholy` 一段待一条读数 | **A** | 中等 | 1 | **已完成（断言纠正，`225d310`）**：`ownerFactory` 转 yes；第 35 轮 queue 侧对齐 done，剩余 `unholy` 段拆出为 **M-30**（不在本条续命）；不计入已修复 | `ownerFactory=yes` 且 `alliedYardForeign=no / foreignYardForeign=yes`；线段级判据见报告 §三 | `reports/FIX-33-UnholyAlliance的验收样本是探针自己编的.md` |
| S-20 | 多机对战两份字节编解码器已漂开 | `snapshots/RuntimeMultiplayerSnapshotTransfer.cpp` 与 `protocol/RuntimeMultiplayerMatchSetup.cpp` 各在匿名命名空间定义一套大端 `ByteWriter/ByteReader` | **不是复制品是分叉**（第 36 轮逐行 diff，R53 复核仍成立）：①错误文案前缀 `"snapshot "` vs `"match setup "` ②`require()` 一侧带下溢守卫 ③方法集不同（`writeBool` vs `writeByteVector/writeArray`） | **A**：两边对敲同一批字节流，漂开与分叉同级风险（无编译错误、无门禁可见） | 低-中（R53 实测）：共享头 + 前缀参数化即可**零文案改动**，一次编译过 | **A** | 中等 | 0 | **已完成（`6efad17`，R53）**：`network/detail/RuntimeBigEndianCodec.h` 取两侧方法并集、`label` 参数保住每条错误字符串逐字节不变、`require()` 统一带守卫；五条对战冒烟前后输出 `diff` 为空；regress 新增第 14 条 | 同一字节流经两条路径的**可观察行为**改动前后逐字节相同 + regress 出现第 14 条 `multiplayer` 并常绿 | `reports/FIX-53-对战wire格式两族编解码器收口.md`（首次登记 `reports/FIX-36-清偿轮-两族克隆实现收口.md` §三） |
| S-26 | 结构守卫的 inventory/trace 生产者只有 Windows 版 | 第 45 轮查明：`Run-StructureChecks.ps1` 要 `pwsh 7` + `clang-cl` + MSVC 前端 + CTest；`--inventory` 由 `Get-TestInventory.ps1` 生成，`--trace` 是那轮 configure 的 `configure-trace.jsonl`。本机两者都没有，所以**完整 scan 一次都没跑过**，1,268 条 `target:`/`test:` 例外也离线不可验 | 取证链整条绑在 Windows 工具链上；守卫本体是纯 Python，被它自己缺失的输入挡住 | **A**：这条不落地，结构守卫的日常价值只有第 45 轮装的两段（夹具自检 + 路径存在性），分层漂移仍无人守 | 中：CMake 在本机本来就能出 file-api codemodel，`ctest --show-only=json-v1` 能给用例注册表——不必照搬 PowerShell，但要对齐 `inventory.tests` 的字段形状 | **B** | 中等 | 0 | 待修复（第 45 轮登记；**不许**为了跑通而放宽 `--baseline` 的 policy） | `bash tools/structure/run.sh --inventory <本地生成> --trace <本地生成>` 在无 Windows 产物时跑完第 ③ 段并给出与基线一致的结论（零未登记命中） | `reports/FIX-45-结构守卫在macOS上第一次能跑.md` §五 |
| S-28 | **挤压原语**：目标格被友军步兵占着时没人让位 | 载具走到目标格，格上站着友军步兵 → crush 对友军恒否 → 寻路器把目标兜底换成远处空格，载具停在半径 2（`ground_target_unreached`） | **已确认**（R44/R48 两次实测）：缺的不是通行许可，是**让位**。**第 49 轮又否定了一条接缝**：挂在寻路结果侧（`applyRuntimeMovePathResult` 的 `goalAdjusted` 分支）在三条冒烟里零触发 → 必须挂在**移动推进侧**（`advanceRuntimeMoveBehavior`），载具**即将 commit 进格**时判 | **A**：它是 M-25 的**唯一前置**；单独也修「载具被自己步兵堵在终点前」这一类 | 中高：原语可在 `RuntimeSessionNavigation.cpp`（单 TU），但**调用点必须在 `RuntimeSessionWorld.cpp`**——该文件此刻有并发 WIP，开工前先看 `git status` | **A** | 中等 | 1 | **blocked**（第 50 轮随 unit-behavior 主线移出 `progress/deferred.md`；调用点在并发 WIP 的 World.cpp） | **先证可达**：读数 `displace from/to/id` 至少命中一次；**再证不变差**：`compactgroups` 13/13（点名 `12E1_2MTNK_tank_first` / `3MTNK_3SHAD`）+ regress 零 RED-NEW。顺序不许反。**单独落地不接 regress** | `reports/FIX-49-M-25方案-挤压原语与通行放行的顺序.md` §三、`reports/FIX-50-留存策略与M-25主线收口.md` §四 |
| S-35 | 战役「动作类型白名单」两份拷贝已漂开 | `RuntimeCampaignCoverage.h` 一份 inline + `RuntimeShell.cpp:14471` 一份（R58 `df8c421` 新增，只被 `--campaign-smoke-test` 的两处断言调用）；case 集差 8 型（shell 缺 13/39/43/49/50/58/59/64）。`dup-scan` 同口径：HEAD **146/13** vs `--ref b4672b5` **138/3**，差值全落这 10 组 | 白名单被复制；**AUDIT-61 §3.3 的「三份」口径有误**（`Coverage.h:25` 是事件类型白名单，不是动作） | **A**：同一事实两处，只改一处不报错 | 低（实测）：删 shell 副本 + 两处改调 header inline + 补一行 include | **A** | 简单 | 1 | **已完成（第 62 轮，`897de11`）**：−140/+3 行（含空行合并）；`--campaign-smoke-test` 输出与改动前逐字一致（`structuralFailures=0`，authored 数据不含那 8 型）。残留的「coverage 侧多声明 8 型」拆为 **S-36**，不在本条续命 | `dup-scan.py` 产品侧回到 ≤3 组；regress 16 条三态不变；冒烟输出逐字相同 | `reports/FIX-62-清偿轮-白名单去重与主线账目压缩.md` |
| S-36 | coverage 白名单多声明 8 个执行侧未实现的类型 | `runtimeCampaignCoverageActionTypeSupported` 认 13/39/43/49/50/58/59/64，而 `applyRuntimeCampaignAction` 的 `if (type==N)` 链里一个都没有——coverage 门禁因此把这 8 型算「已支持」，真正缺口被漏报 | 两份白名单之一是照着「零售 ini 里出现过的类型」抄的，不是按执行器实现列的。本轮只做了去重，没有判定哪边对 | **B**：coverage 门禁的数字可信度（不影响能不能玩） | 中：要逐型确认是「执行器真缺」还是「走的是 helper 分支」，再决定删白名单项（会让门禁变红，属断言纠正）或补执行器 | **B** | 中等 | 0 | 待修复（第 62 轮登记，只读扫描结论） | 8 型逐个给出「执行器有/无」的 grep 级证据；若确为无，白名单删这 8 项后 campaign 门禁仍 `structuralFailures=0` 或按「断言纠正」单独成 commit | `reports/FIX-62-清偿轮-白名单去重与主线账目压缩.md` §三 |

## 三、待修复 —— 复杂（单独成轮，先写方案）

| # | 标题 | 现象 | 根因假设 | 收益 | 成本 | 性价比 | 复杂度 | attempts | 状态 | 验收条件 | 关联报告 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C-01 | 事件分发接 `sendEvent` | 不走 `[NSApp sendEvent:]` → cursor rect 全失效、`isActive/isKeyWindow` 恒 0、tracking area 不回放 | 主循环自建 `nextEventMatchingMask` 分发，绕开 AppKit 正规路径 | 高：一次性修好一类系统级交互 | 改主循环 + 回归全部输入断言 | **A** | 复杂 | 0 | 待修复 | 真实鼠标移到按钮上时 cursor 变化、`isKeyWindow` 为真 | `reports/U-12-*`（见 MEMORY「不调 sendEvent」） |
| C-03 | 存档/读档真机往返 | 无存读档往返验证 | 未实现 | 高：存读档可用性 | 高 | **B** | 复杂 | 0 | 待修复 | 存→推进 300 拍→读，两次 simulation hash 相等 | — |
| C-04 | 全屏原生分辨率渲染 | 呈现表面跟随窗口而不是放大 800x600 | U-14 已把客户区尺寸交给游戏，剩余是表面重建与缩放策略 | 中：全屏清晰度 | 中高 | **B** | 复杂 | 0 | 待修复（U-14 吃掉一半） | 全屏下 view 尺寸 >1600px 时 surface 尺寸同比，单位像素尺寸不变 | `reports/U-14-全屏等于更大视口.md` |
| M-25 | 载具被友军步兵挡死（看着有空地却过不去） | 几个步兵站在一起后，载具**彻底**过不去（用户实测确认，不是减速）。判据 `vehicle pass-through` 现红：`emptyCell=1 friendlyInfantryCell=0` | 通行判定最后一支 `!runtimeCanEnterAndCrushCell` 对同阵营恒否 → 友军步兵格在寻路层等价于一堵墙（步兵有子格分支所以不受影响）。**第 44 / 48 轮两次实测**：只解除寻路否决会打红 `12E1_2MTNK_tank_first`（`arrival_timeout`），因为落位阶段没有任何让位或回填；第 48 轮再试「只放行停着的步兵」仍在同一处红——判别式在**规划时刻**问了**落位时刻**的性质 | **A**：用户实测的操作阻塞感，直接决定「这一脚开不开得过去」 | 高：必须两半同时上——①通行放行 ②commit 前挤压（`findRuntimePassableCellNear` 半径 1~2）+ 分配器按兵种分层目标格 | **B** | 复杂 | 3 | **blocked**（第 50 轮 §六.3② 整体收口：三次尝试全为负结果——R44 解除否决/R48 只放行停着的步兵/R49 接缝零触发；子项 4/4 已满，禁开第 5 个。重开条件见 `progress/deferred.md` 的 S-28 段） | `friendlyInfantryCell=1` **且** `compactgroups` 13/13 **且** `regress.sh` 零 RED-NEW，三条同时成立 | （另有并发会话一份未跟踪的 M-25 分析，未入库故不链接）、`reports/FIX-48-M-25挤压缺位移-读数与重排.md`、`reports/FIX-49-M-25方案-挤压原语与通行放行的顺序.md`、`reports/FIX-50-留存策略与M-25主线收口.md` |

---

## 四、主线账目（一行一条；每段收口的完整推理见 `reports/archive/fix-plan-mainlines-202611.md`）

**两级计数就查这张表**：子项数到 4、或已用轮到 4 → 该线必须整体收口（`§六.3`），排队时报「已满」。

| 主线 | 子项（已用/上限 4） | 已用轮 | 判定 | 依据与代价 | 报告 |
|---|---|---|---|---|---|
| skirmish-mode-rules | 4/4（M-22 done、M-23 断言纠正、M-24 移出、S-17 转 blocked） | 3（R28~31） | **done** | 9 个模式规则从静默无效到生效（本线唯一 S 级价值）；代价：归档侧规则差异不进兼容哈希，跨机录像兼容会误判 | FIX-32 |
| C-02 两栖运输 | 9（超限 2 倍以上） | 11（R15~25） | **blocked** | 真产品缺陷 3 处、夹具/断言口径 5 处，产出密度约 27%；C-02i 移 deferred。代价：尤里奴隶矿工**不产生收入** | FIX-26 / FIX-40 |
| 真开局会话（阻塞簇 8 条） | —（共用一道门，不是主线） | — | 表已失效 | R38 门已开（`objects 14→38` 进 regress 第 12 条），S-08 与 U-19/20/21/23 已迁回 pending，「一次会话出四张」的合并纪律不变 | FIX-29 / AUDIT-56 |
| skirmish-option-semantics | 2（M-29 / M-30） | 1（R37） | **done** | 两处都是「把功能没有的性质写进验收」，无真产品缺陷；代价：`--skirmish-build-smoke-test` 仍未进 regress | FIX-33 |
| persistence-roundtrip | 1（M-31） | 2（R37~38） | **done** | legacy 段把版本降到 10 却留 16 字段记录 = 夹具在撒谎；代价：跨大版本字段迁移仍非全量回归 | FIX-38 |
| S-回归门禁 | 4/4（S-22 / S-23 / S-24 / S-25 移出） | 3（R43/44/47） | **done** | `compactgroups` 接入并首跑即照出真红（S-23）；代价：command 链尾 19 步仍零覆盖 | FIX-47 |
| unit-behavior | 4/4（M-25 blocked、M-26 done、M-28 移出、S-28 blocked） | 3（R48~50） | **blocked** | 三次尝试全是负结果（R44 否决面 / R48 判别式问了落位时刻 / R49 接缝零触发）；还缺 `advanceRuntimeMoveBehavior` 终局否决读数，而改动点正是并发 WIP 的 `RuntimeSessionWorld.cpp` | FIX-50 |
| 清单治理 | 4/4（S-14 / S-27 / S-32 / S-34） | 3（R25/R50、R59、R65） | **done（已满额）** | 十三项门禁只保证**形状**不保证**内容**——S-27 交付两周材料自相矛盾，门禁一条没报；形状门禁替代不了审计轮 | FIX-26 / AUDIT-51 / FIX-59 |
| M-03 空转重绘 | 2/4（S-08 done、M-03 attempts 2） | 2（R63 + S-08 计量轮） | **暂停（§六.5 换赛道）** | 第 1 轮（删兜底）假设被推翻；R68「最后一次机会」未执行、R69 按 §六.5 第 3 轮强制换赛道（做取证线 U-24）。再启必须按 §六.3 三选一（判 done 写剩余代价 / 降 blocked 写死因 / 移 deferred），**不许第四次「先补对账」** | FIX-63 / FIX-69 |
| 交付（首个双击体验） | 2/4（S-33 done、S-38 done） | 2（R59、R66） | **done** | 两条同型缺陷「可验证的事实靠人写」：说明书的回归现状（S-33/S-34）与 BUILD-STAMP（S-38）。代价：包内仍无 About 面板（EVO-07 ②在 deferred）；**R66 审计补行**，此前只有 queue 有行 | FIX-59 / FIX-65 / AUDIT-61 / AUDIT-66 |
| UI 对账 | 4/4（U-20 done、U-21 done、U-23 移出、U-19 未做） | 1（R67） | **done** | 一轮关掉三条：U-20 缩略图一直画得出来（旧的「黑框」是离屏夹具形态）、U-21 右屏是 Bink 视频的 static-fallback、U-23 缺原版同图同相机画面不可判。代价：HUD 逐项对账（U-19）没做，它的前置「载入页取证」本轮打通但**没进门禁** → 另开**独立**条目 S-39（新线「取证门禁」1 子项，不占本线第 5 格） | FIX-67 |
| 取证门禁 | 1/4（S-39 done） | 1（R68） | **done（1 轮关掉唯一子项）** | 把「载入页取证入口」从手工跑变成 regress 第 17 条（0.56s），并把产物落点从源码树挪到本轮 artifacts。价值不在这一条本身，而在它是 U-19 的**前置**：下一条要用真实帧的条目不必再论证一次「拿不到」。代价：只覆盖载入页，世界帧/HUD 仍无帧 | FIX-68 |
| 世界帧出口 | 1/4（U-24） | 1（R69） | **在办** | U-19 卡了 8 轮的真前置：世界路径根本没有出帧通道（不是入口没接进门禁）。成本从「一句验证」修正为「1 轮新建宿主」。代价：它是 B 级可观测性基建，本身不改用户可见行为，只能靠「解锁 U-19」兑现 | FIX-69 |

**仍在办的主线：世界帧出口（U-24，1 轮 / 1 子项，R69 登记）；M-03 空转重绘按 §六.5 暂停（2 轮 / 2 子项，再启需 §六.3 三选一）**。**`交付` 线第 66 轮补行后判 done（2 子项 / 2 轮）**：S-33 与 S-38 是同型缺陷，都由脚本生成取代人手复制。其余 M-25 / S-28 / C-02i / EVO-07 ②③ / M-28 全在 `progress/deferred.md`，重开条件写在那里。
**已满额、不许再开第 5 个子项**：C-02（9）、unit-behavior（4）、S-回归门禁（4）、skirmish-mode-rules（4）。


## 五、已完成 / 已废弃

条目正文（S-01~S-14、M-01~M-21、C-02a~C-02h 的读数与改法）已归档 →
`reports/archive/fix-plan-202611.md`（第 1~24 轮原文 164 行）。
最近 10 条已完成（一行一条，详情查归档与对应报告）；**第 69 轮等价归档 S-24**（载具穿步兵冒烟进门禁，R61 补判 done）→ `reports/FIX-43-regress接入混合编队收敛门禁.md` §六、`reports/archive/fix-plan-202611.md`：

**U-20 载入画面右下预览是否为空（第 67 轮结案，`d60b1c7` + `6cab55d`**：不是空的——`CONCORD_LOADING_PRESENTATION_ONLY=1
--loading-smoke-test` 抓生产窗口，槽位非纯黑 99.7%、颜色 419、两个起始点方块在位；顺带发现槽位是 216x166 而缩略图被等比缩成
216x130 居中，上下 18px 黑带在亮背景页上读作黑条 → 改为铺满。**U-21 主菜单右屏（同轮**：`video=static-fallback
animationSequence=0->0`，素材正确、缺的是 Bink 解码，不再是「素材用错/缺动画」二选一；不续命，要真动画就单开 Bink 条目）。
**U-23 羽化宽度移出** → `progress/deferred.md`（缺原版同图同相机画面，本机不可得）｜

**S-08 世界重绘只读计量（第 63 轮判完成，`cf1903b`**：读数一直在
`ConcordRTS-GameData/local_data/performance/latest.txt`（真会话 226s/7492 帧、复用缓存帧 13 / 重绘 7479），
与 33 次/秒、`renderMs=16` 自洽；卡 18 轮的不是技术——DoD 只写「等一次真开局」没写**产物路径**。
**第 66 轮随 S-38 等价替换归档**（§一.6），详情见 `FIX-35` §一与 `FIX-63` §一）｜

**S-32 台账引用只查了一侧（第 59 轮，`ledger-check.sh` 第十二项 `refs-in-queue`**：R51 的 `refs-head` 判对了树
（判 HEAD 不判工作区）却只补了 fix-plan 一侧，队列侧零门禁；新门禁第一跑就照出 M-25 根因报告从未入库，
顺带把 13 条 `ra2mac_docs/` 前缀的旧路径规范化。**S-33 交付说明书三处事实过时（第 59 轮，`83b457d`**：
回归条数 14→15、M-25 判据「不在门禁里」的旧说法、数据根指针优先级——根因不是忘了改，是没有任何东西量这份文件；
同时删掉 `dist/` 里挂旧 hash 的 dmg，并把「dmg 不常驻 dist」写进说明开头。两条合计 +S-34 等价归档了 M-28）｜
**S-20 对战 wire 格式两族编解码器收口（第 53 轮，`6efad17`**：两份「已分叉」的 `ByteWriter/ByteReader` 并成 `network/detail/RuntimeBigEndianCodec.h`，方法取并集、错误文案前缀改构造参数 `label`（既有错误字符串逐字节不变，无断言纠正）、`require()` 统一带守卫；等价性用五条对战冒烟前后输出 `diff` 为空证明；顺带接上 regress 第 14 条 `multiplayer`（0.07s，此前这条 wire 路径零日常门禁）。净 −79 行。`preview-dedupe` 主线随之判 **done**：R36 + R53 共 2 轮 2 子项）｜**M-27 偷星后建造栏补老兵角标（第 52 轮，`dba2daf` + `b08e13c`：奖励早已生效（`applyRuntimeProducedObjectVeterancy` 读 `spies.hasVeteranProduction`），缺的是侧栏绘制点——建造按钮循环从不看 veteran；新增 `runtimeSidebarItemProducesVeterans` + 左下角 chevron（pips 图集，取不到退 `V`），判据为逐像素三连比对 `appearedPixels=24 / restoredDiff=0`。**DoD 改判**：原文「给兵营设 veterancy=2」的数据前提不存在（无建筑级等级），按 owner×类别改判）｜S-27 回归产物与旧交付包没有保留策略（第 50 轮：`regress.sh` 收尾「每天首跑 + 最近 20 次」、`pack-dist.sh` 的 `.archive` 留 5 个；实测目录 157→25（3.5GB→516MB）、包 42→5（3.6GB→481MB）；顺带清掉打包链无策略的 `.bak`（14 份 1.4GB→189MB）并固化成 `scripts/lipo-universal.sh`（备份+lipo+重签+逐切片 minos 校验）。**合计释放 7.3GB**。⚠ 本轮审计发现这条交付后计划/队列两侧都没回写，状态一直停在「待修复/pending」——已修正）｜S-23 飞行器落地礼让地面单位（第 47 轮：`runtimeJumpjetShouldLand` 加一道认领检查——本格被另一地面单位的 `Move` 目标占着时推迟落地，认领消失后照常落；`compactgroups` 13/13 全绿、回归 `12/1/0`；收窄处=只认 `Move`，追击/AreaGuard 不参与，写进报告 §六）｜S-13 结构守卫在 macOS 上第一次能跑（第 45 轮：完整检查链只有 Windows 版——`Run-StructureChecks.ps1` 要 pwsh7+clang-cl+CTest，`--inventory` 由 `Get-TestInventory.ps1` 生成；本轮接上不需要构建产物的两段 `tools/structure/run.sh`（366 例夹具 1.4s + 例外表路径存在性），清掉 16 条死条目〔U-15 的两个 Raster 文件 15 条 + 第 39 轮自删探针 1 条〕；DoD 偏差=完整 scan 仍缺生产者，拆出 S-26）｜S-22 regress 第 13 条：混合编队收敛（第 43 轮接入 `compactgroups`，0.7s / 7 场景；失败文案带「N failed; 首个失败场景: 原因」，前缀连计数一起钉住，两个维度任一变化即 `cause-changed`；DoD「PASS=12」有偏差——该条首跑即红 `3MTNK_3SHAD`，已在摘要写清）｜S-21 重复代码口径落库（`scripts/dup-scan.py`，`--ref 77e75e7` 复现 140/5 并冻结基线；顺带查出「walk 撞构建目录」与「步长 10 别名盲区」两条散文里没有的口径）｜M-13 真实遭遇战开局取证通道（第 38 轮结案：判据「退出码 0 且 objects>0」由 `skirmishbuild` 长期满足，`objects=14`，随第 12 条进 regress）｜M-31 legacy 存档降版本没连记录形状一起降（`42db147`，夹具侧：v14 记录 16 字段带着 `moveSegmentFrom`，v9~v13 只认 12 → 载入拒绝是对的；截断后整条链路首次 rc=0）｜S-17 真遭遇战整链路进 regress（`docs:` 第 38 轮，第 12 条 `skirmishbuild`，首接即真绿 PASS=11）｜M-30 UnholyAlliance 的 MCV 发放不要求 techLevel（`d2fff47`，断言纠正：发放是开局生成，不是侧栏可造；整链路首过 option semantics）｜M-23 电脑开局 MCV「不展开」（`4abfee7`+`cc53d95`，断言纠正：请求被接受≠基地已存在，模式矩阵 35/35）

**已移出主清单的条目**（不占条目数、不进排序，只留指针）：S-25（`--command-smoke-test` 首败即断、
掩蔽链尾 19 步）→ `progress/deferred.md` 第 61 行（第 47 轮随 `S-回归门禁` 收口移出；
**第 54 轮才从本表删掉行**，此前一直留在「待修复」，十项门禁查不出这类内容矛盾）。

**第 56 轮审计的清单体检结论**：`ON-5-01` / `ON-5-02b` / `ON-4-02d` / `ARM-03` / `ON-2-04b` 五条
**只在 queue 有、本表无行**（`EVO-07` 也缺，已补进第二节）。十项门禁只查「有行的条目」，
连行都没有的一条也报不出——这是 `ledger-check.sh` 的结构性盲区，不是漏跑。处置：留指针不补行
（补 5 行会让本表逼近 400 行且它们都不在近期排序里），下轮若要动手先补行再排序。

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

## 六、轮次索引（一行一轮；原文见 `reports/fix-plan-archive.md` 与 `reports/archive/`）

| 轮 | 日期 | 主题 | 报告 |
|---|---|---|---|
| 69 | 2026-11-16 | 重排（`§七`：三条候选假设全被推翻）：U-24「世界帧出口」才是 U-19 的真前置——`skirmishbuild` 全程不建窗口不出帧，17 条 smoke 零张世界帧；M-03 按 `§六.5` 暂停；UI-01 §3.1（FPS 常显）标废弃（已于 `c1ccfe6` 修掉） | `reports/FIX-69-重排-世界帧出口才是U19的前置.md` |
| 68 | 2026-11-16 | 修复：S-39 结案——载入页呈现冒烟进 regress 第 17 条（0.56s，兜住 R67 的槽位修复）；`runtimeSmokeArtifactPath()` 把 14 张 BMP 挪到本轮 artifacts（源码树 build/ 31MB→6.4MB）；登记 S-40 | `reports/FIX-68-载入页呈现冒烟进回归门禁.md` |
| 67 | 2026-11-16 | 修复：U 线取证通道（入口一直存在，第六轮才发现）→ U-20/U-21 结案、U-23 移 deferred；产品修复：载入页缩略图铺满 216x166 槽位（去黑带）+ 槽位内容门禁；登记 S-39 | `reports/FIX-67-载入画面缩略图铺满槽位与U20U21结案.md` |
| 66 | 2026-11-16 | 审计（`§六.7` 满五轮）：三条帐目矛盾（S-38 无行 / EVO-06 状态 / S-35 线程）+ S-38 结案（pack-dist 自写 BUILD-STAMP，`f0826d5`） | `reports/AUDIT-66.md` |
| 65 | 2026-11-16 | 修复（`§六.5` 换赛道→打包与文档）：说明书的「回归现状」改为生成——`regress.sh` 写 `latest.txt`、新增 `render-readme.py`、pack-dist 第 ⑩ 步接上；`--check` 照出上一版说明书的假话（`20af5cf`/`6aa4673`） | `reports/FIX-65-说明书里的回归现状改为生成.md` |
| 64 | 2026-11-16 | 修复：S-37 二进制自证补齐两侧——`--version` 新增 `built:`（落盘时刻）、`compiled` 降下界；regress 改「脏树→+WIP / 旧二进制→WARN」；伴生修 `build-health.sh` 分母（`73be404`） | `reports/FIX-64-二进制身份自证补齐两侧.md` |
| 63 | 2026-11-16 | 修复（负结果，`§七` 重排）：删掉压住细判据的重绘兜底（`25b6c53`），静置 CPU 21.1%→20.8% 证明**假设错**；S-08 结案（读数一直在） | `reports/FIX-63-空转重绘的根因假设被推翻.md` |
| 62 | 2026-11-15 | 清偿：战役动作白名单去重（S-35，−140/+3）；fix-plan 八段主线收口 199 行 → 9 行账目表；登记 S-36 | `reports/FIX-62-清偿轮-白名单去重与主线账目压缩.md` |
| 61 | 2026-11-15 | 审计：EVO 主线判 done（②③ 移 deferred）、S-24 补判 done、重复代码首次可复现归因（`--ref` 复跑） | `reports/AUDIT-61.md` |
| 60 | 2026-11-15 | M-26 结案：伞兵下落中**可选**（用户定口径）。真因是 `cleanRuntimeSelection` 每拍删 `ParadropDrop`，不是命中框错位；命令锁保留，regress 接第 16 条 `paradropsel` | `reports/FIX-60-伞兵下落中可选.md` |
| 59 | 2026-11-15 | 清单自证：`refs-in-queue` 照出队列引用撑 N 轮未入库报告；交付说明书三处事实过时 | `reports/FIX-59-清单自证与交付说明书事实对账.md` |
| 58 | 2026-11-15 | M-25 载具穿步兵判据进门禁（known-red）+ 678 行并发 WIP 入库 | `reports/FIX-58-载具穿步兵判据进门禁与并发WIP收口.md` |
| 57 | 2026-11-15 | 构建与回归的自证：`build-health.sh` 三态检测（S-30）+ regress 报告钉住 HEAD/compiled（S-29）；**R44「再全量一次就能修 .ninja_deps」被证伪**，真修法是删 deps+log | `reports/FIX-57-构建与回归的自证门禁.md` |
| 56 | 2026-11-15 | 审计：**R54/R55 的主目标 EVO-07 在台账里没有行**；AUDIT-51 查出的 6 条「门已开」blocked 挂 5 轮未回写；queue 的 `decisions_r49~r55` 8 键迁存档；`.ninja_deps` 截断复发 | `reports/AUDIT-56.md` |
| 55 | 2026-11-15 | EVO-07 ④ dmg 收口：`make-dmg.sh` 挂载后重验 7 条（含跨机模拟 a/b）；`dist/README.txt` 改为入库源、每次打包覆盖（旧版三处过期） | `reports/FIX-55-dmg分发与说明书入库.md` |
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
