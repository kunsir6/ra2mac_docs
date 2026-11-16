# ConcordRTS 持续推进 · 运行日志

> 追加写，不覆盖。每条以 `## <时间> · <任务ID> · <结果>` 开头。
> 结果取值：done / partial / blocked / diagnose-only

---

---

## 已归档：第 1~24 轮（2026-11-10 ~ 2026-11-13）

7,553 行原文已移入 `progress/archive/RUNLOG-202611-r1-r24.md`（含队列初始化、P0~P1 移植期、
第 1~24 轮全部条目）。本文件自第 25 轮起续写，只保留最近轮次。
门禁：`bash ra2mac_docs/scripts/ledger-check.sh` 第 8 项（RUNLOG ≤1500 行 / ≤120KB）。

## 已归档：第 25~59 轮（2026-11-13 ~ 2026-11-15）

1002 行原文已移入 `progress/archive/RUNLOG-202611-r25-r59.md`（R70b 决策①：字节红线 94%，
开工先归档）。本文件只保留第 60 轮起的条目；第 1~24 轮见 `RUNLOG-202611-r1-r24.md`。
门禁：`bash ra2mac_docs/scripts/ledger-check.sh` 第 8 项（RUNLOG ≤1500 行 / ≤120KB）。

## 第 60 轮（2026-11-15，修复轮）M-26 结案：伞兵下落过程中可选

- 轮型：**修复轮**（单点，用户当场上报）。前置问题「原版伞兵下落中能否选中」由用户当场答：**能选**。
- **根因推翻原假设**：M-26 记的是「hit test 坐标口径错位（视觉带 z 偏移、命中框用地面脚点）」。
  实测不是——airborne 的拾取本来正常（`RuntimeAirbornePickingOrderSmoke` 早已覆盖跳喷飞行体的
  投影/命中/深度排序）。真因是 `cleanRuntimeSelection()` **每拍**把 `mission=="ParadropDrop"`
  从 `selectedObjectIds` 里删掉：点击那条路（`runtimePlayerLocalSelectable`）并不过滤它，
  所以点击确实进了列表，播完一帧、tick 收尾就被踢出——**「看起来像命中框问题、实际是选中生命周期问题」**。
  框选 `runtimeObjectCanBeBoxSelected()` 另有同一处排除。
- **改法**：删 `cleanRuntimeSelection` 与 `runtimeObjectCanBeBoxSelected` 的 ParadropDrop 分支，
  **保留命令锁**（`runtimeObjectCanMove` / `runtimePlayerActorTemporarilyCommandLocked`）：
  下落中可选中（能看血量/编队），落地那一刻 `SuperWeaponSupportAircraft.inl` 把 airborne 置 false、
  mission 换回 Guard 之后才可下令。支援飞机（SupportFlightEast/West）继续排除。
- **判据可反刷绿**（本轮重点）：`RuntimeParatrooperTargetSmoke` 追加 —— 下落中 localSelectable/box 为真
  → 走 UI 真实入口 `applyRuntimePlayerSelection` → **跑满一整拍仍在选中** → 移动令 `acceptedCount==0`；
  27 场景（9 单位 × 15/30/60Hz）全过。把旧行为改回去重建即红在
  `E1/15Hz selection erased while still descending`（rc=1），恢复后 rc=0。
- **门禁**：regress 接第 16 条 `paradropsel`（120s 上限，实测 2s）；全量 `13 PASS / 2 KNOWN-RED / 0 RED-NEW`
  （两条 known-red 是既有的 slave miner 与 M-25 载具穿步兵，与本轮无关）。
- **交付**：arm + x86_64 增量 → `lipo-universal.sh`（双切片 minos=12.0）→ `pack-dist.sh`；
  Rosetta 单独验 x86_64 切片（`--smoke-test` 与 `paradropsel` 均 rc=0）；`dist` = `e382dae`。
- 提交：src `e382dae`；docs `268b62a`。（不 push，按约定由人推。）

## 第 61 轮（2026-11-15，审计轮）EVO 主线收口 + 重复代码可复现归因

- 轮型：**审计轮**（`§零.4` 距 AUDIT-56 整五轮）+ `§零.1` 的 EVO 主线整体收口判定。源码 0 提交，`reports/AUDIT-61.md`。
- **EVO 判 done**：子项 4/4 用满、①④ 已交付且可复算（`pack-dist ⑨` 逐包断身份）；②③ 要新开 AppKit 模态面、
  本项目不调 `sendEvent` → 本环境无交互判据，三次跳票后移 `deferred.md`，重开条件 = **C-01 落地后**。
  代价：无数据树时仍只有一行诊断、无 About 面板。**这是本轮唯一「账目动作先于指标」的判断。**
- **S-24 补判 done**：前置（`.inl` 进 HEAD）已随 R58 `782e194` 成立，regress 第 15 条 `vehiclepass` 在跑、
  红项带前缀 —— 「门开了却挂 blocked」第三次（AUDIT-56 §3.2 是第二次）。新规则：blocked 前置必须可 grep。
- **重复代码第一次做到可复现**：`dup-scan.py --ref b4672b5` 在上一轮 HEAD 上跑出 **138/3**，与 AUDIT-56 逐字一致；
  当前 HEAD **146/13** → **+8/+10 组全部归因 `df8c421`**：它在 `RuntimeShell.cpp:14471` 新增第三份「动作类型白名单」，
  与 `RuntimeCampaignCoverage.h` 两个 inline 版本构成三份，且三份 case 集**已经不同** → 登记 **S-35**。
- 质量四数：R57~R60 净增 **+1769/−33**（产品 ≈+1256，R58 一轮吃掉 96%）；90,757 / 42,542 / 31,056（+42/0/+262）；
  近 5 轮 test:2 / fix:1 = **2.0×（触发）**，60 提交 25:9 = 2.78×；TODO 0。
- 清单：383 行 / 38 条 / 59KB / rules 5 类 / 十三项门禁全绿。**人工体检 1 处矛盾**（S-24 状态与 DoD）。
  另记：**18 条 pending/blocked 在 queue 有全字段、plan 无行**（AUDIT-56 时 5 条）——结论改为「两份台账必然漂移，
  plan 该只留排序与主线账目」，属单独一轮的清偿活，本轮不动。
- regress `PASS=14 KNOWN-RED=2 RED-NEW=0` / **16 条**（21:54:40）；构建树两目录 clean，AUDIT-56 的两笔债（WIP / `.ninja_deps`）已结清。
- 下轮（62）**清偿轮**：比例闸触发禁新增断言；删/合对象 = S-35 的三份白名单 + R58 净增最大的两个越线文件。

---

## 第 62 轮（2026-11-15）清偿轮 —— 白名单去重 + 主线收口压成账目表

- **轮型：清偿轮**。三条判据同时成立：`§五.2` 腐烂预算（R57~60 净增 +1769 / −33）、`§八.3` 比例闸
  （近 5 轮 test:2/fix:1 = 2.0×，等于阈值即触发）、AUDIT-61 §7.1 已点名 S-35 是现成删除对象。
  KPI：净增 ≤0 且 regress 不退化 —— **达成**（源码 −137，回归 14/2/0 逐条不变）。
- **S-35 结案（`897de11`）**：删 `RuntimeShell.cpp` 的 `runtimeCampaignActionTypeSupported`（只被
  `--campaign-smoke-test` 两处断言调用），两处改调 `RuntimeCampaignCoverage.h` 的 inline 版本 + 一行 include。
  `-140/+3`。删的依据三条：①它只被冒烟调、产品路径零使用；②它是 header 那份的副本；③`--campaign-smoke-test`
  改动前后输出**逐字相同**（`structuralFailures=0`，authored 语料不含漂开的 8 型）。
- **口径纠正**：AUDIT-61 §3.3 说的「三份动作白名单」实际是 **2 份动作 + 1 份事件**
  （`Coverage.h:25` 是 `runtimeCampaignCoverageEventTypeSupported`，trigger event 不是 action）。
  dup-scan 按 case 标签序列比对，两类混算才凑成"三份"。
- **拆分 S-36**（等价替换）：`runtimeCampaignCoverageActionTypeSupported` 认 13/39/43/49/50/58/59/64，
  执行器 `applyRuntimeCampaignAction` 的 `if (type==N)` 链里一个都没有 → coverage 门禁把这 8 型算"已支持"，
  真缺口被漏报。**属断言纠正**（删白名单项可能让 campaign 门禁变红），`§八.2` 不许在清偿轮顺手做。
- **本表压缩**：八段「主线整体收口判定」199 行 → `## 四、主线账目` 一张 9 行表（子项/已用轮/判定/依据与代价/报告），
  原文迁 `reports/archive/fix-plan-mainlines-202611.md`（208 行一字未删）。fix-plan **377 → 201 行**。
  表的用法写死：两级计数先查它，子项到 4 或轮次到 4 → 必须整体收口（`§六.3`）。
- 质量四数：源码净增 **−137**（`1 file changed, 3 insertions(+), 140 deletions(-)`）；
  `RuntimeShell.cpp` **90,620**（−137）/ 42,542（0）/ 31,056（0）；新增断言 0 vs 产品 −137；TODO 0。
  重复代码 **136/3**（HEAD 146/13 → 回冻结基线 140/5 以内）。
- regress：`PASS=14 KNOWN-RED=2 RED-NEW=0` / 16 条（23:06:16）。构建树两目录 clean。
- 下轮（63）：S-36 的 8 型 grep 级判定（可能让 campaign 门禁变红，单独 `test:` commit）；或 S-08 帧诊断出口解耦。

## 2026-11-16 第 63 轮（修复轮）

- 轮型：**修复轮**（无 brake、无在办 attempts≥3、腐烂预算未触发〔R62 净增 −137〕、距 AUDIT-61 两轮）。
  主目标 M-03 / ON-2-06 世界 idle 空转重绘。**结论是负结果**，按 `§七`（根因假设被实测推翻）把剩余
  时间转成重排。报告 `reports/FIX-63-空转重绘的根因假设被推翻.md`。
- **S-08 结案**：三行读数一直在 `ConcordRTS-GameData/local_data/performance/latest.txt`（真会话 226 秒、
  7492 帧、`复用 13 / 重绘 7479 / 最长连续复用 1`、33 次/秒、`renderMs=16`）。卡它 18 轮的不是技术，
  是 DoD 写「等一次真开局」却没写**产物落在哪个路径**——门开了没人去看。这条口径已写进本表。
- **删了什么（`25b6c53`，+14/−1）**：`RuntimeShell.cpp` 里
  `advanceRuntimeUiPresentation(state); if (tickAdvanced) { state.repaintRequested = true; }`
  ——100 行之前已经有 `if (simulationChanged || waterWakeChanged)` 的细判据，这处无条件兜底把它整体作废，
  而 `reuseCachedFrame` 的第一项条件就是 `!repaintRequested`。保留两处兜底：对战分支每拍重绘
  （画面由桥接泵提交，改动面在别的 TU）、本机分支每 30 拍强制重绘一次（漏报改动最坏延迟 1/3 秒）。
- **假设被推翻**：同一探针（`--skip-main-menu --skip-skirmish-menu`，起窗后 18s 采
  `top -l 2 -stats cpu -pid`）改前 **21.1%** / 改后 **20.8%**，两两截图不同（未冻帧）。
  真来源是 `simulationChanged` 的语义——它汇总的是**模拟侧**变化（effects/economy/triggers/动画 tick/移动），
  对战里 AI 一直在动所以每拍为真；**模拟变了 ≠ 画面变了**。M-03 的签名门必须建在「画了什么」上。
  三条候选未定量：①动画计时器每拍递增而 SHP 帧号按 delay 才变 ②位姿亚格内推进落在同一像素
  ③`continuousRuntimeFrame` 每帧都 Invalidate（`reuseCachedFrame` 为真也要 blit）。
- **拿不到的那一档**：本轮能自动造出的场景只有带 AI 的那种，而「人静置（无单位移动）」才是该省的一档；
  Accessibility 未授权、合成键鼠被丢，不能按键暂停 → 这一档的读数本环境做不出来，M-03 判「假设被推翻 + 新假设未定量」，
  **不是已修复**。
- 质量四数：源码净增 **+13**；`RuntimeShell.cpp` **90,633**（+13）/ 42,542（0）/ 31,056（0）；
  断言 0 vs 产品 +13；TODO 0。regress `PASS=14 KNOWN-RED=2 RED-NEW=0`（00:19:01，16 条逐条不变）。
- 清单：208 行 / 39 条 / 62KB / 十三项（提交后）全绿；主线账目补 **M-03（2 轮 / 2 子项，在办）**，
  「仍在办的主线：无」改掉了——上一轮那句其实从 R61 起就不再成立。
- dist：`25b6c53 2026-11-16T00:22:41 regress=pass14/known2/new0 arch=arm64+x86_64 minos=12.0 icon=96.2
  rosetta=rc0 pack=incremental+lipo-universal buildtree=clean wip=none round=R63`。
  arm 2:36 / x86_64 2:28 / lipo+签名+pack 约 1 分钟。
- 用时约 75 分钟（00:11→01:26）：**探索占了 35 分钟**（先按「最省的一处兜底」假设去定位，再为「怎么自动量」
  试了 interaction / skirmishbuild 两种冒烟——都不落诊断文件）。教训：这个仓库的帧诊断只对**窗口会话收尾**
  落盘，任何「自动量 paint 数」的设想都要先验「跑完会不会写文件」。
- 下轮（64）：优先挑一条能产出用户可观察行为的（`U-20` 载入画面地图预览 / `U-21` 主菜单右侧小屏 / `U-23` shroud 羽化）；
  M-03 只许先补「画面签名 vs 实际像素」逐帧对账；S-36 是现成的伴生中等项。
- **收口新发现（登记 S-37）**：包内自报 `compiled=Nov 15 19:25:24`，而二进制是 00:18 刚链接的——
  `compiled` 取自 `__DATE__/__TIME__` 所在 TU，增量构建不重编它，所以它是「版本 TU 的时刻」不是「二进制的时刻」；
  且 R57 的 WARN 只判「比 HEAD 提交时刻新」（WIP 烘进包），**没判更旧**（二进制落后于 HEAD）。
  本轮 `compiled` 比 HEAD 早 3.7 小时，报告头一声没吭。与 MIN_MACOS「只查一侧」同一形态，第三次。
- 提交：src `25b6c53`；docs `2948362`(报告+plan+RUNLOG) / `8d487fe`(queue v168) / 追加一轮
  `docs:`(S-37 报告段+plan 行) + `queue:`(v169)，共 4 个 docs 提交——超了「1~2 个」的红线，
  原因：S-37 是收口后才发现的，不许 amend（`§九.6`）只能追加。

## 2026-11-16 第 64 轮（修复轮）S-37 二进制身份自证补齐两侧

- 轮型：修复轮（无 brake / 无 attempts≥3 在办 / 腐烂未触发 / 距 AUDIT-61 三轮）。
  主目标 **S-37**；伴生 `build-health.sh` 的分母（同一主目标：门禁自身的假阳性）。
- **根因比台账写的更前一步**：不是「只查一侧」，是**读错了字段**。`compiled` 取
  `RuntimeMain.cpp` 一个 TU 的 `__DATE__/__TIME__`，增量构建不重编它 → 它既不能证明「是这版」
  也不能证明「不是这版」。R56 抓到 678 行 WIP 靠的是「该 TU 恰好在未提交改动里被重编」的巧合。
- 产品侧（`73be404`，+59/−2）：`--version` 新增 `built:` = 本文件 stat mtime（链接/重签/打包都刷新它），
  `compiled` 加括注降为下界；取不到打 `unknown`，**不许回退成 TU 时刻冒充构建时刻**。
- 脚本侧：`regress.sh` 两向判据——树脏由 `git status --porcelain` 直接定义 `+WIP`（不再由时刻反推）；
  `built` 早于 HEAD 提交 >60s → 警告「它不含 \<hash\>」。报告头与 `report.md` 同步改 `built=… compiled(下界)=…`。
- **负向验证（先红后绿）**：`touch -t 202611151200.00` 把二进制改旧 + 放一个未跟踪文件 →
  `source 25b6c53+WIP / dirty=1`，两条警告都打出（44377s）；复原后 `73be404 / dirty=0` 零警告。
- **伴生小项（负向验证时照出）**：`build-health.sh` 的待办比例分母取的是 ninja 进度行 `[2/2]` 的右半边
  ——那是「本次剩余」，只改一个 TU 也是 100%，于是**告警在正常增量下恒真**（噪声化，而它的用途正是
  「看见就该怀疑整图脏」）。分母改 `ninja -t targets all`（3268）；「待办看起来是全量」从 WARN 升 CORRUPT。
- **断言纠正**：原 DoD「正常构建时 compiled 与二进制 mtime 差 <60s」把机制写进了验收——
  不重编时必然不等且正常。生效条件改为三条（旧二进制 WARN / 脏树 +WIP / `built` 与 stat 逐字一致），三条都测过。
- **台账体检**：S-37 原挂 `thread=S-回归门禁`，该线 4/4 已满且判 done（R63 登记时未注意）→ 改独立
  `thread=身份自证`。这是「主线满额」的第一次现实触发，说明「拆新 ID 续命」的反面也存在：**往满额主线里塞新条目**。
- 质量四数：源码 **+57**（+59/−2）；`RuntimeShell.cpp` 90,633 / `RuntimeSessionWorld.cpp` 31,056 逐字持平（本轮未碰）；
  新增判据 3 条 vs 产品 +57；TODO 0、临时探针 0（`touch -t` 与 `.wip-probe.tmp` 已复原/已删）。
- 清单：214 行 / 40 条 / 68KB / v170 / 十三项门禁 commit 后复跑全绿。
- regress 16 条 **14/2/0**（62s 一次；改判据前后逐条不变）。
- 提交：src `73be404`；docs `(本轮)` scripts / 报告+plan+RUNLOG / queue v170。
- dist：`73be404 2026-11-16T01:29:13 regress=pass14/known2/new0 arch=arm64+x86_64 minos=12.0 icon=96.2
  rosetta=rc0 buildtree=clean wip=none round=R64`。arm 1.5s（RuntimeMain 单 TU）/ x86_64 1 分 20 秒。
- 用时约 25 分钟（01:24→01:49）：本轮三个改动都在「小 TU + 脚本」层，没有一次全 TU 重编。
- 下轮（65）：U-20/U-21/U-23 的共同前置（真实窗口「菜单→载入第 6 阶段」的自动驱动）**要么做要么降级**——
  它已是第四轮被当成「为什么拿不到读数」的理由；或 S-36。

## 2026-11-16 第 65 轮（修复轮，§六.5 强制换赛道 → 打包与文档）

- 轮型：修复轮。M-03 主线连续 2 轮无产品行为变化（R63 删兜底假设被推翻、S-08 只是计量）→
  本轮只许从「清偿 / 可观测性 / known-red / 打包与文档」选；known-red 两条分别挂 C-02（9 子项）与
  unit-behavior（4 子项）两条已满额 blocked 主线，不许用拆新 ID 续命 → 选**打包与文档**。
- 主目标 **S-34**：`dist/README.txt` 的「回归现状」改为打包时现场生成。
  **这条已经在说谎**：新加的 `--check` 打在上一版 `dist/README.txt` 上，第 123 行照出
  「应是 16 条 / 14 绿，实为 15 条 / 13 绿」——R59 手工改对 14 条，R60 加第 16 条 `paradropsel` 又错，
  门禁一条没报（没有任何东西在量这份文件）。
- 根因：生产者（`regress.sh`）与消费者（`packaging/README-dist.txt`）之间**缺生成步骤**。
  S-33 的处置只到「手工核过一次」，与 S-37「只查一侧」/MIN_MACOS 同形态——第三次。
- 改法三处、零 C++：`regress.sh` 收尾写 `progress/regress/latest.txt`（一行 k=v）→
  `scripts/render-readme.py`（标记替换 / `--check` / 无数据 rc=3 / 渲染结果删标记）→
  `pack-dist.sh` 第 ⑩ 步改调它（rc=3 打 WARN 继续，其它非 0 `exit 1`：宁可不出包，不出会说谎的包）。
- 负向验证四条：改 `known-red.tsv` 条数 → 说明书跟着变（19/15/3/1 渲染正确）；空 base →
  「本机没有可用的回归产物」；`--check` 抓出打包前那份假话（rc=1）；打包后复跑 `--check` 转 ok。
- 刻意没做：把「`dist/README.txt` 与最近一次回归不一致」加进 `ledger-check`——每轮中途回归已跑、
  打包在收口，这条有 20 分钟合法红窗，会变成恒真噪声（与 R64 修的 `build-health` 分母同坑）。
- 质量四数：源码 **+17/−12**（仅 `packaging/README-dist.txt`，产品代码 0 行）；90,633 / 42,542 / 31,056
  三条逐字持平；新增判据 1 条（`--check` 的 STALE/ok）+ 生成器 5 个分支 vs 产品 0 行；TODO 0。
- regress 16 条 `14/2/0` 逐条不变（本轮无 C++ 改动，两次跑同一份二进制）。
- 清单 214 行 / 40 条 / 65KB / rules 5 类 / 十三项全绿；R63 的内联决策键迁 `archive/queue-decisions-202611e.json`。
- 提交：src `6aa4673`（说明书改标记）；docs `20af5cf`（scripts）/ `03e4247`（降级可见）/ `docs:`（报告+plan+RUNLOG）/
  `queue:` v171。**4 个 docs 提交，超 1~2 红线**：第二个 scripts 提交是负向验证时才发现
  「兜底静默」这条，按「不许 amend」只能补提交，如实记在这里。
- 下轮（66）：U-20/U-21/U-23 的共同前置（真实窗口「菜单→载入第 6 阶段」自动驱动）**第五轮**了，
  按 `§六.4` 要么做、要么降级 blocked 写死因；或 S-36。距 AUDIT-61 已 5 轮 → 若按 `§五.7`
  该排审计轮（本轮已顺手做了清单体检，但没做净增/断言/重复代码对账）。

## 第 66 轮（2026-11-16）审计轮 —— 三条帐目矛盾 + S-38 结案

- 轮型：**审计轮**（`§六.7`，距 AUDIT-61 整五轮）。不写产品代码；附带做 S-38（落在「对账」范围：
  「dist 是不是最新」的唯一判据本身不可信）。
- **三条帐目矛盾**（`§一.7` 的体检，全部修掉）：①**S-38 在 fix-plan 没有行**——R65 摘要写「新开交付线挂 S-38」，
  实际只写进 queue 与主线段落，表里没有（R56 查过 EVO-07 同一形态，第二次）②**EVO-06 = S-08 的队列侧镜像**，
  S-08 第 63 轮已判 done，queue 仍 `pending/attempts=1`，detail 里还留着两条**并不需要**的重开条件
  ③**S-35 挂 `thread=清单治理`**，而这条线已 4/4 满额 done → 满额线被虚增到 5 子项。
  结构性原因：13 项门禁全是**形状门禁**（查「这一行有没有 12 个字段」），不查「这一行该不该存在」。
- **S-38 结案**（`f0826d5`）：`pack-dist` 第 ⑫ 步自写 `BUILD-STAMP`。`regress=` 只认「HEAD + 干净树」
  那一跑，对不上写 `stale@<hash>` + WARN（**不抄旧三态**：抄旧值比留空更危险，它看上去是真的）；
  x86_64 切片补 Rosetta 冒烟且失败不出包（`§十二.2` 里唯一还没进脚本的门禁）；新增 `--round`。
- 负向验证两条，先红后绿：`source=deadbee` → `regress=stale@deadbee` + WARN；移走 `latest.txt` →
  `regress=unknown`。两次都确认没抄上一跑的 14/2/0。
- 质量四数：源码 **+93/−155**（R62~65 合计，产品 ≈+76/−143）；90,633 / 42,542 / 31,056（RuntimeShell **−124**）；
  断言 vs 产品 近 5 轮 **0×**（60 提交 22/10=2.2×）；TODO 0。
- `dup-scan` **136/3**，**首次低于冻结基线**（`77e75e7` 140/5；AUDIT-61 是 146/13）。
- regress 16 条 `14/2/0` 逐条与 R65 相同——本轮无 C++ 改动，**这不是又验了一遍，是没东西可验变**。
- 清单 216 行 / 40 条 / 63KB / rules 5 类 / 十三项全绿；S-38 补行 + 等价归档 S-08（`§一.6`）+ 补 `交付` 主线行。
- 放弃项：没给 `ledger-check` 加「plan 与 queue 的 id 集合配对」——映射是多对一（EVO-06≈S-08、ON-2-06≈S-08
  两条 queue 行对一条 plan 行），先要有映射表才不产生噪声。这是下一次清单治理的入口。
- 下轮（67）：修复轮。在办 22 条里只有 **U-20/U-21/U-23** 的产出用户可观察；它们共用「菜单→载入第 6 阶段」
  自动驱动这道前置，**已第六轮被当理由**——建议 R67 直接把它做成条目（判据=一条命令跑到载入阶段并截到可判读帧），
  做不出来就降级 blocked 写死因，不许第七次跳票。M-03 只剩一次机会（第 3 轮无行为变化即整体收口）。

## 第 67 轮（2026-11-16，修复轮）U 线取证通道 + 载入页缩略图铺满槽位

- 轮型：修复轮（无 brake / 无 attempts≥3 在办 / 腐烂未触发 / 距 AUDIT-66 一轮 / M-03 已在 R65 换过赛道）。
- **六轮「前置」实测早就有**：`CONCORD_LOADING_PRESENTATION_ONLY=1 --loading-smoke-test` 就把生产窗口按
  `WM_PRINTCLIENT` 抓成 11 页 × 800x600/640x480。与 S-08（读数一直在文件里）、M-13（通道一直在）同型，**第三次**。
- **U-20 结案**：槽位非纯黑 99.7%、颜色 419、两个起始点方块在位——缩略图一直是画出来的；旧的「黑框」来自离屏
  夹具（`if (!loading.runtime) return;` 提前退出），不是产品缺陷。
- **产品修复 `d60b1c7`**：实测页面美术的槽位就是 216x166（纯黑区与目标矩形逐像素重合），而渲染按等比缩成 216x130
  居中 → 上下各 18px 黑带，在观察者/尤里页（背景亮）读作两条黑条。改为铺满，槽位纯黑 **21.7%→0.3%**。
  口径依据=遭遇战选图面板对同一素材是拉伸铺满。代价：28% 纵向拉伸，回退 6 行。
- **门禁 `6cab55d`**：槽位内容（非纯黑 ≥50% / 颜色 ≥24）。旧判据只有标记差分，全黑槽位也能过。
  commit message 里「颜色 393/330」是改动前采样值，改后实测 419/365、opaque 99.7%——不改写历史提交，以报告为准。
- U-21 结案（右屏是 Bink 视频的 static-fallback，`animationSequence=0->0`，素材正确）；U-23 移 deferred（缺原版同图同相机画面）。
- 质量四数：源码 **+44/−23**（3 文件）；90,633 / 42,542 / 31,056 三者零变化；断言 1 条 vs 产品净 −1 行；TODO 0。
- regress 16 条 `14/2/0` 逐条不变。
- 清单 234 行 / 41 条 / 70KB / rules 5 类 / 十三项全绿；登记 S-39（载入呈现冒烟进门禁），等价出队 U-23；UI 对账主线判 done。
- 下轮（68）：S-39（4 秒的门禁）→ U-19（HUD 对账，需世界帧）；M-03 只剩一次机会。

## 第 68 轮（2026-11-16，修复轮）S-39：取证通道进门禁，产物挪出源码树

- 轮型：修复轮（无 brake / 无 attempts≥3 在办 / 腐烂未触发 / 距 AUDIT-66 两轮 / M-03 已在 R65 换过赛道）。
- **S-39 结案**：regress 第 17 条 `loadingpages`（`CONCORD_LOADING_PRESENTATION_ONLY=1`）——真建生产窗口，
  `WM_PRINTCLIENT` 抓 11 页 × 800x600/640x480，断言槽位内容（非纯黑≥50%/颜色≥24），**0.56 秒**。
  它兜住 R67 的缩略图铺满修复：没有门禁，槽位退回等比缩放留黑带不会有人被提醒。
- **产物落点 `f0c8f06`**：新增 `runtimeSmokeArtifactPath()`（认 `CONCORD_SMOKE_ARTIFACT_DIR`，默认仍 `build/`），
  三处写盘点改用它。原本接进门禁后 14 张 BMP 会落到数据树的 `build/`，每轮 23MB 且绕开 R50 留存策略。
  源码树 `build/` 31MB→**6.4MB**（`rm` 掉 14 张历史残留，剩下的 `issue22_15_*` 归 S-40）。
- 同型第四次：S-08 / M-13 / S-38 / S-39 都是「事实的生产者存在，入口不在清单里」。下轮遇「拿不到 X」
  先搜 `CONCORD_*` 开关与冒烟入口。
- **伴生小项 S-40 同轮做完（`755abf2`）**：result 冒烟仍写 `GameData/build/`（5 张）、slope 仍写
  `ConcordRTS/build/issue22_15_*`——落点抽成 `runtime/host/diagnostics/RuntimeSmokeArtifacts.h`
  （专用 env > `CONCORD_SMOKE_ARTIFACT_DIR` > 历史默认），两处改用。实测两棵树的 bmp **均为 0**。
- 质量四数：源码 **+48/−7**（4 文件，全在 diagnostics）；90,635（+2）/ 42,542 / 31,056；
  断言 0 / 新增门禁 1；TODO 0。产品行为改动 0 行——本轮只加门禁与改落点。
- regress **17 条 `15/2/0`**（15 绿、2 known-red 不变、0 RED-NEW）；清单 239 行 / 41 条 / 66KB / 十三项全绿；
  登记 S-40，按 §一.6 与 S-39 出队等价替换（另归档 S-35 到 queue-archive-202611d）。
- 没做：U-19（前置是世界帧；实测 `skirmishbuild` 只打 metadata 行、`attest` 只写日志不落图 →
  **HUD 帧仍无出口**，下轮第一件事是定这个出口的形状）、M-03（只许先补逐帧对账，时间不够，不做一半）。
- 下轮（69）：M-03 最后一次机会；U-19 先验 `--skirmish-build-smoke-test` 能否出世界帧。
- dist：`755abf2 2026-11-16T06:18:49 regress=pass15/known2/new0 arch=arm64+x86_64 minos=12.0 icon=96.2
  rosetta=rc0 buildtree=clean wip=none round=R68`。门禁逐条独立复验（lipo/minos/plist/Rosetta/身份三处一致/icon），
  并用**包内二进制**复跑第 17 条 → `loadingpages PASS`、两棵树 bmp 仍为 0。

## 第 69 轮（2026-11-16，重排轮）三条候选全被推翻 → 世界帧出口才是 U-19 的前置

- 轮型：开轮判修复轮，T+30 触发 `§七`（三条候选的根因假设**全部被实测推翻**）→ 转重排，只诊断 + 重排 + 打包。
- **旧顺序错在估错成本**：R68 把「U-19 前先验 `--skirmish-build-smoke-test` 能不能出世界帧」写成一句前置验证。
  实测 `runRuntimeSkirmishBuildSmokeTest`（`RuntimeShell.cpp:77659`）建完整世界、部署 MCV、放 10 栋建筑，却
  **全程无 `CreateWindow` / `WM_PRINTCLIENT` / 渲染调用**（`renderCheck=0.00ms` 就是因为那段没跑）；17 条 smoke 的
  artifacts 只有菜单/载入/结果页，**零张世界帧**。所以它不是「验一下」，是要**新建一条呈现通道**。
- 三条否决（本轮唯一实质产出）：
  ①FPS 叠加层「默认常显」——`c1ccfe6`（11-12，UI-01 出报告同一天）已改为 opt-in；UI-01 §3.1 是死结论，就地标废弃。
  ②遭遇战第二行国家列 `???`——是 Random 旗 `rani.shp` 的**位图内容**（`grep '\?\?\?'` 零命中、`flagFor` 非空才 blit），零售原样。
  ③放建筑 `placementSearch=1553ms`——出自冒烟的兜底路径（`placementValid==false` → `findRuntimePlacementCellNearBase`），
  单人对战 `selectRuntimeReadyPlacement` 不走它 → 证不了用户路径会卡，不修、不登记。
- **登记 U-24「世界帧出口」**（收益 A / 成本 中 / 中等，重排后第 1 顺位），验收按**像素数**判而不是「文件存在」；
  等价归档 S-24。主线账目：新增「世界帧出口」线，M-03 按 `§六.5` 暂停（再启须 `§六.3` 三选一）。
- 质量四数：源码 **0/0**（无改动）；90,635 / 42,542 / 31,056 零变化；断言 0/0；TODO 0。
- regress 17 条 `15/2/0` 不变（本轮无源码改动，不是又验了一遍）。
- 清单：242 行 / 42 条 / 67KB / rules 5 类 / 十三项全绿（refs 两项在报告入库前先红后绿地测过）。
- **欠账**：连续第 4 轮无产品行为变化（R65 起）。下轮 U-24 必须真的出图，否则按 `§六.3` 收口 U 线。
- dist：`755abf2 2026-11-16T07:25:05 regress=pass15/known2/new0 arch=arm64+x86_64 minos=12.0 icon=96.2
  rosetta=rc0 buildtree=clean wip=none round=R69`（无源码改动，仍重跑 lipo+重签+pack 确保 dist 与 HEAD 一致）。

## 第 70 轮（2026-11-16，修复轮）用户报障：战斗内 ESC 菜单的模态性只做了一半

- 报障原话：「战斗中点 esc，呼出战斗中的菜单。战斗显示跟菜单显示包括声音是有冲突的。」
- 根因一条：打开菜单只改了 `runtimeMenuOpen` 标志，没让它接手画面与声音。
  ①画面：`drawRuntimeMenuOverlay` 底色只盖 `contentRect`，而 contentRect 底部留了 32px 动作条余量；
  地图视口高度却是满的（只减侧栏 168）→ 800×600 下底部 `632×32 = 20224` 像素仍是战场。
  ②声音：`setRuntimeMenuOpen` 在音频路径上零命中；主循环的 `tickAccumulator=0` 只挡住「新音效」，
  已经在播的 8 条 SFX 通道池与 EVA 专用通道会自主播完，和菜单自己的按钮音（另一个设备接缝）叠播。
- 改法（产品 15 行，`5e28fcd`）：底色改盖满 `clientRect`（侧栏随后由 `drawRuntimeMenuSidebarBackground` 重画成菜单皮肤）；
  `open && !wasOpen` 时 `stopRuntimeSfxPlayback` + `muteRuntimeEvaPlaybackPreservingSubtitle`。
  **音乐刻意不动**——零售选项菜单不打断 BGM，注释里写死理由防后人顺手停掉。
- 判据（`d01fb3b`，regress 第 18 条 `menumodal`，0 秒）：**品红哨兵法**——整屏刷哨兵色→画菜单→数残留像素。
  先红后绿（同一份冒烟只切产品代码）：修前 `bottomStripLeak=20224 liveSfxChannels=2 evaStopped=no`，
  修后 `0 / 0 / yes`。20224 与几何推导（632×32）逐像素对上。
  诚实边界：声音判据断言的是「通道簿记被清」，不声称测到真实音频输出（无人值守收不了音）。
- 质量四数：净增 **+193/−1**（新冒烟 155 行 + env 分派样板 21 + 产品 15）；`RuntimeShell.cpp` 90,635→90,672（+37，低于 50 行说明线）；
  断言 1 条（4 判据）vs 产品 15 行；TODO 0。regress **18 条 16/2/0**。
- 遗留：①U-24 世界态帧仍缺（本轮只拿到「菜单态」帧，`artifacts/menumodal/ingame_menu_800x600.bmp` 是首张可判读的战斗内菜单帧）；
  ②多人对局开菜单也会停本地音效，该行为未验证，下次多人报障先当第一嫌疑；③小窗口下 `bkgdsm` 小于 contentRect，
  盖满后「菜单边框」与「没盖住」在判据上分不开。

## 2026-11-16 12:37 · ON-5-02b（菜单档）· done

**轮型：台架轮**（队列首条，零代码改动）。只做菜单档，世界档拆 `ON-5-02c`。

- 命令：包内二进制 + `CONCORD_PRESENT_STATS=1 CONCORD_PRESENT_STATS_UNTIL_SEC=1800` + `/usr/bin/time -l`，
  不加任何 `--skip`（要的就是真实主菜单）。**1800.01s / EXIT=0**。
- 读数：paints=23436（**13.02/s**，10 秒短跑 13.39/s）、attempts=23438、blank=2、redundant=0、
  takeover=0；user CPU 204.36s（**11.4%**）、sys 52.92s；`maxRSS` 352.9 MiB；**峰值 footprint 157.66 MiB**。
- 判据：`vmmap -summary` 每 45 s 采 24 点，**恒定 119.3M**（12:25:46 一次 134.3M，下一采样点回落）；
  峰值比 10 秒短跑只多 **16 KB** → 这条路径 **30 分钟无泄漏**，S-18 的修复（`505024d`）在长时间尺度上成立。
- **口径警告（写进报告防误判）**：`maxRSS` 314→353 MiB（+38.9 MiB）是高水位线口径，含可回收页；
  10 秒短跑里启动期就已顶到 314 MiB。判泄漏一律用 footprint 斜率 + malloc 分配计数。
- 两件未定性的：①`Main menu Bink animation unavailable … using the original extracted first frame`
  → Bink 在本平台不支持，台架覆盖的是「静态菜单 + 光标收敛器每帧跑」，不是视频播放；
  ②静态主菜单仍 13.02 paints/s、11.4% CPU——与 M-03 同族另一条路径，不猜来源。
- 台账健身：RUNLOG R25~59 迁 `archive/RUNLOG-202611-r25-r59.md`（1297→301 行 / 116KB→31KB）；
  U-19 补进 fix-plan §一（此前只在主线账目里出现）。
- 没做：构建/regress/dist（台架测的就是 CPU 与 RSS，并发负载污染读数）；世界档（`ON-5-02c`）。
- **规则债**：`rules.commit` 的「近 4 轮 fix ≤1 → 下轮必须产出产品行为变化」本轮触发而未兑现 → R72 必办。
