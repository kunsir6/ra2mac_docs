# AUDIT-30 — 第 30 轮审计（2026-11-14 01:01~02:00）

**轮型：审计轮**（§6.7 每 5 轮强制；上次 AUDIT 为第 25 轮，本轮正好第 5 轮）。产品代码零改动、零新增断言。

## 一、指标（4 个数 + 两项）

| 指标 | 数值 | 判断 |
|---|---|---|
| 近 5 轮净增行数（25~29） | **−333**（R26 −126 / R27 −337 / R28 0 / R28b +19 / R29 +111） | 健康，无连续 300+ 净增，腐烂预算未触发 |
| 最大文件 | `RuntimeShell.cpp` 90,459（基线 90,459，**0**）｜`RuntimeMapRenderer.cpp` 42,578（基线 42,668，**−90**）｜`RuntimeSessionWorld.cpp` 30,794（基线 30,792，**+2**） | 三个月来首次三文件全部持平或下降 |
| 断言 vs 产品代码 | 近 5 轮新增断言 **0** / 产品代码 **+130**；近 60 提交 `test:`32 / `fix:`17 = **1.88×** | 近 5 轮已反转（0:2），比例闸可解除；但 60 提交窗口仍是 1.88×，与第 29 轮前的 1.88× 持平——**没恶化也没收敛** |
| TODO / FIXME / HACK | **0 / 0 / 0** | 干净 |
| TRACE 类 env 开关 | 15 个名字、约 26 处 `getenv` | 其中 6 个跨轮存活（`BIOREACTOR_TRACE` / `S41_SCENE_PAINT_TRACE` / `COMMAND_SMOKE_STAGE_TRACE` / `BEHIND_MARKER_TRACE` / `INPUT_TRACE` / `RULES_TRACE`），**未定性前不算债**，下轮判「永久开关 vs 跨轮探针」 |
| `*_OUTPUT` 类 env | 1,100+ 处 | 冒烟产物入口，合法，不是探针 |

## 二、对账

### 1. 清单体检（全部数值为实测）

- **行数/体积**：`fix-plan.md` 136 行（限 400）；`queue.json` 55 KB → **45 KB**（限 120）；tasks 46 → **35**（限 120）；rules 5 类 × ≤3 行（限 5 类）。`ledger-check.sh` 五项全绿。
- **悬空报告引用**：两本账共 29 个 `reports/*.md` 引用，**悬空 0**。（第 29 轮刚修过 5 条，本轮复核已清）
- **字段**：46 条全部满 13 个键，**无第 14 种字段**，结构合规。但——
  **12 条 pending 的 `root_cause` / `cost` 是空串**（`ON-5-01`、`ON-5-02b`、`ON-4-02d`、`ON-3-01b`、`ON-3-02`、`ON-2-04b`、`ARM-03`、`EVO-07`、`U-19`、`U-20`、`U-21`、`U-23`）。
  按 §一.4 它们**不许进排序**，而它们又全部不在 `fix-plan.md` 里 → 事实上是一批「永远排不上」的条目。本轮已把 `roi` 显式写成「待估（禁排序…）」，不再靠人记得。
- **状态与报告矛盾 2 条**（真数据错误，已修）：
  - `C-02g` queue=`measuring`，fix-plan 已列「已完成」（`c5d2b6c`）→ 改 `done`；
  - `C-02i` queue=`measuring`，fix-plan 已移 `deferred.md` → 改 `blocked` 并在 detail 写明重开条件位置。
- **重复条目 5 条**（已归档，见下）。
- **attempts 与收口记录**：`M-13`=2、`C-02g`/`C-02i`=2、`M-22`/`S-15`/`S-16`=1，其余 0，与 RUNLOG 逐条对得上，**无冲突**。
- **数据 bug**：`queue.json` 的 `root`/`repo` 指向 `/Users/zhenglk/ai-project/ra2mac`（**不存在的路径**，少了 `s`）→ 已改回 `AiProjects`。
- **归档**：11 条 → `queue-archive-202611b.json`（6 条已结案超窗口：M-21/S-11/M-12/S-12/C-02b/C-02c；5 条被取代：EVO-09 并入 C-02、U-18 并入 M-13、U-22 由 M-23/M-24 覆盖、ON-4-07 即已完成的 M-02、ON-4-03 合入 M-03）。46 → 35 条，done 8 条（≤10）。

### 2. 主线账目

| 主线 | 子项 | 已用轮次 | 状态 |
|---|---|---|---|
| **skirmish-mode-rules** | M-22(done) / M-23 / M-24 / S-17 | **2** | **子项已满 4 条上限**，剩 2 轮窗口，第 4 轮必须整体收口 |
| C-02 两栖+矿工 | 9（b~i） | 11（15~25 轮） | 已判 blocked，不许再开 |
| UI 对账 | U-19/20/21/23 | **0** | 4 条从未开工，且全部未估值 |
| ON-3 上屏自证 | 2 | 0 | 均 blocked（需 `[NSApp run]` / 合成输入） |
| ON-5 存活 | 2 | 0 | 未估值 |

**结论**：下一条要开的主线只有 skirmish-mode-rules，而它已经只剩 2 轮预算——这不是"还有空间"，是"必须收口"。

### 3. 重复代码（25 行窗口、步长 10、忽略纯声明块）

125 组重复，按性质三分：

- **产品侧 11 组 = 1 对真债**：`assets/preview/MapPreviewExporter.cpp`（7,479 行）**整段复制**了
  `assets/codecs/RuntimeTmpCodec.cpp`（694 行）的 TMP 块解码循环（`rowWidth=4`、`xStart=(blockWidth-rowWidth)/2`、
  base/extra 两路赋值）。同一份解码逻辑两份实现，改一处必漏另一处。**本审计最高价值的一条债。**
- **冻结夹具 78 组 = 有意重复，禁止当死代码删**：`*Old*.inl` / `*Oracle*.inl` / `*original*.inl` 共 4,046 行
  （`RuntimeSlaveWorkerEconomyOldOracle` 2,285、`Consumers.original` 227、`MobileSlaveEconomyOldExitClosure` 657、
  `InputCancellationOld` 566 等），四个文件都有 `#include` 与可达调用点（`RuntimeShell.cpp:62020` 在 command 冒烟链上）。
  它们是"旧实现 vs 新实现"的等价性基线，**必须保留**——已写进本报告，防止下一轮清偿把它当垃圾删掉。
- **冒烟骨架 36 组 = 可抽取样板**：`RuntimeCameraKeySmoke` / `RuntimeKeyboardIngressSmoke` / `RuntimeKeyboardRouterSmoke`
  三份共享 4 组完全相同的 25 行块（同一段 WndProc 装配）；`MapRightPointerSmoke` 16 组、`MapLeftPointerSmoke` 7 组。
  纯测试骨架，抽取风险低。

### 4. 计划与报告一致性

- fix-plan 14 条 ↔ queue 35 条：**只有 14 条在两个账本里都有对应**（thread 已归一，id 仍是 `ON-2-06`=M-03 这种双名，第 25 轮的决定是保留双 id、靠 thread 归一，本轮**不再重命名**——重命名会打断 RUNLOG 里的历史 grep，收益小于风险）。
- queue-only 12 条（见上）既不在 fix-plan、也未估值 → 是本轮体检的主要结论。
- 近期报告与提交 hash：抽查 FIX-26~FIX-31 六份报告的 hash 全部能在 `git log` 中找到，**无虚报**。

### 5. 回归

本轮**未跑新回归**：`build-product-arm` 从 01:00 起被并发进程占用（`ninja -C build-product-arm concord_runtime`，
`RuntimeShell.cpp` 正在编译，其工作区还有 6 文件 +324 行的未提交改动）。跑现有二进制会把他人 WIP 的判定算到本轮头上。
引用最近一次真实基线：**PASS=10 / KNOWN-RED=1 / RED-NEW=0**（`20261113-235638`，`command` 前缀不变）。

## 三、下 5 轮的三条建议

1. **轮 31 = 修复轮，M-23 一次定性**（skirmish-mode-rules 第 3 轮）。给 `deployRuntimeComputerAiMcvs` 加
   `ids/cell/item/planned/requested/owner` 六字段失败文案，一次运行裁定「没 MCV / 没落点 / 请求被拒」。
   **同轮必须写 M-24 与 S-17 的二选一结论**——主线到 4 子项上限，轮 32/33 内必须整体收口（判 done 或 blocked，不允许再拆）。
2. **轮 32 建议清偿轮**（不必等腐烂预算触发）：① `MapPreviewExporter` 的 TMP 解码复制段改调 `RuntimeTmpCodec`；
   ② 抽取三份键盘冒烟的 25 行 WndProc 骨架。KPI：净增 ≤0 且 regress 不退化。
   **禁止**动 4,046 行 Old/Oracle/original 冻结夹具（见 §二.3）。
3. **轮 33 起清 12 条 queue-only 条目**：要么补 5 个必填字段（根因/收益/成本/attempts/验收）进 `fix-plan.md`，
   要么移 `deferred.md` 并写重开条件——**不允许继续躺在 queue 里当"看起来在排队"**。
   同一轮可把 `ledger-check.sh` 接成 `regress.sh` 第 0 步（S-14 遗留，退出码语义已想清：体量超限只告警不计数，不污染 RED-NEW 条数）。

## 四、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：不跑回归（并发构建占用）、不改产品代码、不改任何断言、不重命名 queue 的 9 个双名 id（理由见 §二.4）。
- **遗留债**：12 条未估值条目、6 个跨轮 TRACE 开关待定性、`MapPreviewExporter` TMP 复制段、36 组冒烟骨架重复、
  `ledger-check.sh` 尚未进 regress。
- **放弃了什么**：放弃「把 12 条未估值条目一次性补齐估值」——那需要真读数或真判断，凭空写 12 份估值就是把台账变成小说；
  只给它们打了「禁排序」标记，把决定留给下一轮真正要做它们的时候。
- **并发**：源码仓库有他人未提交改动（`compat/win32/src/RuntimeWin32CompatText*`、`RuntimeAppleWindowSurface.*`、
  `cmake/PlatformApple.cmake`，6 改 + 2 新，+324 行），另有 `ninja` 在跑。**本轮零触碰**，源码仓库零提交。
