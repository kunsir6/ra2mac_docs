# FIX-28 第 27 轮：清偿——跨轮存活的一次性探针清零（第二批）

**轮型：清偿轮。** 依据（§0.3 第三条）：近 5 轮提交 test: 3 条（`8dfc9f4` / `7c02812` / `c5d2b6c`）
对 fix: 1 条（`7b9f576`），比值 3.0 ≥ 2×，§8.3 比例闸本轮仍然生效（**本轮零新增断言**）。
同时命中 §5.4「临时探针必须同轮转成断言或删除，不许跨轮存活」——上一轮只清了产品侧，smoke 侧还留着 6 处。
KPI 按清偿轮口径：**净增 ≤0，regress 不退化**。

## 1. 本轮主目标与判定

主目标只有一个：**把「默认静默、只有知道变量名才存在的证据」从代码里清掉**。
判据不是「删了几行」，而是三个可查的事实：`grep` 这些变量名为 0、失败文案仍带现场、回归逐条一致。

盘点结果（全仓 `CONCORD_*TRACE*` 共 26 个变量，逐个看用途后分两类）：

| 变量 | 处置 | 理由 |
|---|---|---|
| `CONCORD_SLAVE_EMERGENCE_TRACE` | **删**（smoke 侧 6 处 → 0） | 第 23~24 轮 C-02g/h 一次性取证，问题已结案；放在 smoke 里等于「看起来能查」的假入口 |
| `CONCORD_MCV_REPACK_TRACE` | **删** | 第 22 轮一次性取证（六谓词压一句），答案已写进 FIX-23 |
| `CONCORD_HIT_SPAN_TRACE` | **删** | 第 11 轮一次性取证（可见像素 vs 深度像素），结论已进 FIX-12；现在由 `RuntimeMapRenderStats` 四个正式计数承担 |
| `CONCORD_SHADOW_TRACE` | **删** | 第 8~9 轮一次性取证，四桶计数（`structureShadow{OffScreen,ClippedOut,EmptyMasks,EmptyBodies}`）已接管它要回答的问题 |
| `CONCORD_TRANSPORT_TRACE` | **删**（23 处 → 0，含 `runtimeTransportTraceTick`） | C-02 主线第 15~22 轮的取证机器；主线第 25 轮已判 blocked，blocked 的原因写死在 FIX-26，不需要它再说话 |
| `CONCORD_RUNTIME_PERF_TRACE` / `CONCORD_RENDER_STAGE_TRACE` / `CONCORD_DATA_ROOT_TRACE` / `CONCORD_AUDIO_TRACE` 等 | 保留 | 长期诊断开关，有正式门控与文档，不是某一轮的一次性取证 |

## 2. 改法与「删了还查得到」

四处删法一致：**保留证据，去掉开关**。探针的价值在于「红了以后看什么」，不在于「平时静默」，
所以把关键值直接写进失败文案——断言通过时一分钱不花，红了当场有数。

- **S-15**（`RuntimeSlaveMinerSmoke.inl`）：删掉 `traceOffender` lambda 与 `step()` 里的
  `first-sighting` 整段 dump（含 renderFrom/renderTo/path/target 六项），改为一个 `describeWorker`
  文案构造器，接到四条 `fail()` 上：`new worker appeared…` / `worker teleported…` /
  `worker left without interpolated walk animation…` / `worker escaped through a closed wall ring…`。
  失败文案现在自带 `tick / id / cell / render / moving|still / hasRenderPos / phase / status`。
- **MCV 拆包**（`RuntimeMcvRepackSmoke.inl`）：原来「六条谓词一句话」，探针把 `yardStillThere /
  selection / live 全表` 打出来。改为六条谓词各自求值成命名量（`yardStillThere / landed / onFoundation`），
  失败文案逐项列出 `yardStillThere / selection / type / owner / canMove / cell / onFoundation / anchor`。
  这也顺手修掉了「一句话压六个条件」的老毛病——红了不用再猜是哪一个。
- **命中跨度**（`RuntimeStructureSpriteGeometry.inl`）：删 `runtimeHitSpanTraceEnabled()` 与
  整个四桶打印块（−64 行）。四桶的结论已经由 `RuntimeMapRenderStats` 的正式计数承担。
- **阴影**（`RuntimeMapRenderer.cpp`）：删 `runtimeShadowTraceEnabled/Take/RecordTraceTake`
  三个 helper 与两处打印块（绘制侧 34 行、记录侧 16 行），−90 行。四桶计数原样保留。
- **两栖转移**（`RuntimeSessionNavigation.cpp`，−105 行）：删 `runtimeTransportTraceEnabled` /
  `traceTransportBoarding` / `traceRuntimeTransportUnload` / 全局 `runtimeTransportTraceTick`
  与 21 条调用语句。调用点全是「拒绝点 + 原因串」的旁路打印，删掉后每个分支的 `return false / continue`
  一字未动；`std::string why`（顶部守卫的六字段）随打印一起没了。

## 2.5 事故：一次把 `if` 的唯一条语句删掉，构建当场失败

S-16 的**第一次提交 `962f02e` 是坏的**：`unloadRuntimeUnitTransportMotion` 里
`if (remainingPath.empty())` 的**唯一一条语句**就是那句 `traceRuntimeTransportUnload("unload:no-goal", …)`。
按「删整条语句」扫描时它被删了，`if` 留下没有 body → `error: expected statement`。

处理：`git revert 962f02e`（`404afb5`，按 §9.6 不用 `--amend` / `reset --hard`）→ 用「先收集全部
待删区段、再按行号倒序一次删完」的脚本重做（`2777a5c`），并顺手收掉三处因此变成空壳的结构：
`if (host.airborne || host.renderMoveActive) { }`、`if (!beginRuntimeTransportGroundTransfer(…)) { }`
（改成 `(void)` 调用 + 注释说明为何总是返回 false）、以及顶部守卫里只喂给打印的 `why` 字符串。

代价：多花一次 4 分钟构建 + 一次回归。**这是本轮唯一的产品代码风险事件，已收口**。
教训（写进方式而不是记忆里）：批量删「某语句」时，先判它是不是某个 `if`/`for` 的**唯一 body**——
这种删除必须连控制语句一起处理，否则语法层就会挡下来（这次算是被编译器救了，如果换成循环体里的
`if` 加花括号，就会静默变成空分支）。

## 3. 质量数（§5.1 四个）

| 指标 | 数值 |
|---|---|
| 本轮净增行数 | **−337**（`git diff --shortstat 97a5393..HEAD` → `5 files changed, 59 insertions(+), 396 deletions(-)`；含 revert 的净零往返） |
| 最大单文件 | `RuntimeShell.cpp` **90,459**（未变）；`RuntimeMapRenderer.cpp` 42,668 → **42,578**（−90）；`RuntimeSessionWorld.cpp` 30,794（未变） |
| 新增断言 vs 新增产品代码 | **0 条断言 / 0 行产品逻辑**（全部是打印与文案；比例闸在生效） |
| TODO/FIXME/临时探针 | TODO/FIXME 前后都是 **0**；一次性 env 探针 **5 个 → 0**（`SLAVE_EMERGENCE` / `MCV_REPACK` / `HIT_SPAN` / `SHADOW` / `TRANSPORT`） |

## 4. 靠什么兜住

- **构建**：`ninja -C build-product-arm concord_runtime` 通过（49 个目标，仅既有 `u8path` 弃用 warning 与重复库链接 warning，与基线同类）。
- **回归**：`bash ra2mac_docs/scripts/regress.sh` → `PASS=10 KNOWN-RED=1 RED-NEW=0`，与基点
  `20261113-192309` 逐条一致（收口跑 `20261113-194809`）；`command` 的 known-red **失败前缀不变**
  （`slave miner: workers did not dig, carry full loads and deposit credits`）。
  这条前缀本身就是「删的是旁路打印、不是把红项擦掉」的证据：它来自同一文件里**另一段**探针
  （`runRuntimeSlaveMinerSmokeProbe`），本轮一字未改。
- **删除的边界**：只删「为打印而取的局部量」与打印本身。`inspect()` 的全部谓词、
  `drawRuntimeStructureActiveAnimations` 的调用、四桶计数的累加行，一行没动。
- **`git status`**：两仓库收口均干净（`progress` 保持软链）。

## 5. 本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：`CONCORD_S41_*` / `CONCORD_S43_*` 这批带轮次编号的老变量（10 个）。它们不是某一轮的
  一次性取证，而是某条渲染链的长期开关；真正该做的是「每个开关一份谁在用、什么时候可以删」的清单，
  不属于本轮主目标，也没有登记成条目（避免用新条目换旧条目来假装治理）。
- **遗留债**：清零后**一次性 env 探针为 0**。剩下的都是长期诊断开关（`RUNTIME_PERF` / `RENDER_STAGE` /
  `DATA_ROOT` / `AUDIO` / `VXL_*` 调参），有正式门控，不按探针口径治理。
- **放弃了什么**：**没有**把探针改成「只在失败时打印」的通用工具函数。看起来更优雅，
  但它会让调用点继续带着 env 语义，等于把债包装成基建；直接改文案更便宜，也更容易 review。
- **产品行为零变化**：本轮没有任何一行影响模拟、渲染或输入（唯一的语法级改动是 §2.5 那两处空壳，
  行为与原来等价）。C-02 主线仍是 blocked，M-13（真实遭遇战取证通道）仍是下一轮的主目标候选。

## 6. 清单体检

- `bash ra2mac_docs/scripts/ledger-check.sh` → 五项全绿：fix-plan 127 行 / queue 47KB / tasks 41 条 / rules 5 类。
- 本轮无新增条目以外的结构变更：S-15 结案并压进「最近 10 条已完成」一行链，新增 S-16（等价替换，总数不变）。
- 悬空引用：本轮报告自身为新建，`fix-plan` 与 `queue` 引用的路径均已核对存在。
- 状态与报告矛盾：S-15 的验收条件「全仓 grep 该变量为 0」已实测为 0（含注释已改写为 `CONCORD_*_TRACE` 泛称）。
