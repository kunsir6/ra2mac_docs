# 第 39 轮（清偿轮）：一次性阶段探针清零，与「为什么更大的删除做不了」

- 日期：2026-11-14
- 轮型：**清偿轮**。判定链见下，不靠感觉。
- 主目标：删掉 mac 侧仍在编译、但已无调查价值的两处**一次性阶段探针**（S41 场景绘制、帷幕遮挡候选）。
- 产品行为：**零变化**。本轮没有新增断言，也没有改任何判定条件。

## 一、轮型判定（T+0~3min）

| §0 条目 | 判定 | 依据 |
|---|---|---|
| 主线累计 >4 轮 | 否 | `skirmish-mode-rules`(3 轮/done)、`skirmish-option-semantics`(2 轮/done)、`persistence-roundtrip`(2 轮/done)、`C-02`(11 轮/blocked 不再开子项) |
| 诊断轮（brake） | 否 | `progress/.active` 为 `released`，无 held 锁 |
| **清偿轮** | **是** | 近 5 轮（R34~R38）`test:` 3 条 / `fix:` 1 条 = **3.0×**，触发 §八.3 比例闸 |
| 审计轮 | 否 | 上次 `AUDIT-35`，之后只过了 36/37/38 三轮 |
| 换赛道轮 | 否 | 近两轮有产品行为变化（`e32136b` 读档清残留特效） |

§0.3 与 §8.3 同时生效：**本轮禁新增断言、只许删/合/清偿**。

## 二、清偿对象与依据

### 2.1 删掉 S41 场景绘制的私有探针（`RuntimeScenePaintTrace.inl`，19 行）

- 它是什么：S41「direct-scene 分配失败」阶段的私有打印，条件是
  `state->frameProbeWin32->failSceneAllocation && getenv("CONCORD_S41_SCENE_PAINT_TRACE")`，
  逐相位打 `clip/visible/iconic/client/loaded/eligible/submitted/fps`。
- 为什么可以删：调查早已收口，报告结论已固化；**探针不是那个字段存在的理由**——
  `failSceneAllocation` 仍被 `RuntimeMainFrameContract.inl:139` 用来做
  「scene-allocation-fallback」的注入，本轮一字未动。
- 改动：删文件 + `RuntimeShell.cpp` 的 include 一行 + 三个调用点
  （`begin` 在 .inl 尾、`after-scene` / `eligibility` / `after-submit`）。
- 靠什么兜住：`render` 与 `core` 两条回归（该段在 `runtimeWindowProc` 的 WM_PAINT 主链上，
  每次上屏都会走到），外加编译期——删掉的是语句，不是分支。

### 2.2 删掉帷幔遮挡的候选清单打印（`RuntimeBehindMarkerRender.inl`，4 行）

- 它是什么：`CONCORD_BEHIND_MARKER_TRACE` 置位时逐候选打 `object/samples/coveredMask`。
- 为什么可以删：这是一次性读数（用来判「哪些单位被帷幕候选覆盖」），结论已进报告；
  **函数本体一字未动**，`stats.behindMarkerSprites / behindMarkerMissing / behindMarkerFrame`
  三个正式计数仍在，观感口径没变。
- 靠什么兜住：`render` 回归（该函数在 `RuntimeMapRenderer.cpp:20871` 被 include，每次世界渲染都会调用）。

## 三、判「不能删/不能合」的四处（本轮最重要的一半产出）

清偿轮的价值一半在删了什么，另一半在**把「看着该删其实不能删」写下来**，否则下一轮还会重查。

1. **`tools/diagnostics/{s33,s41,s43}/VisibleObserver.cpp` 三份 99% 相同**（400/401/408 行；
   `s41 ↔ s43` 逐行 diff 只有 9 行差异：s43 多一段 `uiMessageReady/Ok/RoundtripMs`）。
   **不删不合**：它们是 S33/S41/S43 各阶段跑出来的证据工具，输出 JSON 逐字段对应那几份报告；
   合并等于让某一阶段的产物「由后来的字段集生成」，历史证据就不再可复现。另外它们**不进 CMake**
   （`grep visible_observer cmake/*.cmake` 无命中），任何合并都拿不到 smoke 兜底。
2. **左右指针冒烟的同段代码（~300 行）**：`RuntimeMapLeftPointerSmoke.inl`(2246) 与
   `RuntimeMapRightPointerSmoke.inl`(1696) 有三段长相同（187 / 73 / 72 行），内容是
   `baseState`/`fullState` 的整段状态序列化 lambda。**不抽**：它是两份不同场景夹具的「全状态快照」，
   抽成共享会用一个 `bool` 把两段语义分叉进同一函数（第 36 轮对 low/high 桥面的同一条判据），
   而且单 commit 必然远超 200 行红线。
3. **`RuntimeSecondWindowResourceTrace.inl`（P11，24 行）**：Windows 专用路径（SDL3.dll / HWND /
   `EnumThreadWindows`），mac 侧根本不编译 → 删了没有任何回归能证明「只是删了打印」。
   **留**，等 Windows 基线跑起来再一起清。
4. **产品侧已无逐字重复的静态函数**：本轮用「函数体归一化后精确哈希」扫了 1031 个 `.cpp/.inl/.mm`，
   跨文件完全相同的静态函数 **0 组**。这与第 36 轮的结论一致——剩下的「同构」全是**已经漂开的分叉**，
   合并必改行为，清偿轮不许做。

## 四、质量四数

| 指标 | 数值 |
|---|---|
| 本轮净增行数（本人提交） | **−27**（删 19 行文件 + `RuntimeShell.cpp` −4 + `RuntimeBehindMarkerRender.inl` −4） |
| 最大单文件行数 | `RuntimeShell.cpp` 90,626（−4）；`RuntimeMapRenderer.cpp` 42,542（0，其 include 的 .inl −4）；`RuntimeSessionWorld.cpp` 30,794（0） |
| 新增断言 vs 新增产品代码 | 0 / 0（清偿轮，比例闸生效） |
| TODO/FIXME/临时探针增减 | 0 → 0；一次性探针 **2 族**（`CONCORD_S41_SCENE_PAINT_TRACE`、`CONCORD_BEHIND_MARKER_TRACE`）→ 0 |

（`git diff --stat` 全仓显示 `+15/−8`：其中 `+15` 是并发会话在 `RuntimeShell.cpp` 的 WIP，不在本轮账上。）

## 五、清单体检

- `fix-plan.md` 228 行（≤400）；`queue.json` 57KB（≤120KB）；tasks 35 条（≤120）；rules 5 类；`ledger-check.sh` 七项全绿。
- 状态矛盾：0（`command` 已知红与 `C-02i` blocked 的口径一致，都是「交付段缺一条读数」）。
- 悬空报告引用：0（本轮新增报告即本文件）。
- 重复条目：0。
- attempts 与收口记录：一致（`C-02i` att=2 与固定在第 25 轮；`M-25` att=1 由并发会话持有）。
- 本轮未压缩、未归档（体量均在限内，且本轮没有新增条目 → 按 §一.6 无需 1:1 替换）。

## 六、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：`command` 那条唯一 known-red 的夹具侧重取证。它是上一轮亲手写下的「下轮起手」，
  但本轮被 §八.3 比例闸改判为清偿轮，而它需要新增一条读数（test: 类）——撞闸，故顺延。
  代价：`C-02i` 的 blocked 判定再挂一轮，奴隶矿工不产生收入这条产品行为差异继续留在账上。
- **遗留债**：P11（Windows 专用）探针未清，等 Windows 基线；`S-19` 的 PPM 逐字节 A/B 仍缺调色板来源。
- **放弃了什么**：本轮没有为了「看起来有产出」去动大文件（`RuntimeShell.cpp` 只删了 4 行）。
  按 §五.3，90k 行文件的局部修补是允许的，但没有把它当成本轮的产出指标。
- **新发现（操作层，值得记）**：`ninja` 启动时报
  `warning: premature end of file; recovering`，随后把 arm64 那半边**全量重编 1642 个目标**——
  并发会话上次被中断时把 `build-product-arm/.ninja_log` 写坏了。增量构建因此退化成全量，
  本轮打包时间预算被它吃掉约 18 分钟。下一轮若再遇到同样的 warning，不要再等增量，
  直接按「全量 15~20 分钟」排时间锚点。

## 七、提交

- 源码 `refactor(render):` 删掉两处一次性阶段探针（S41 场景绘制、帷幕遮挡候选）
- 文档 `docs:` 本报告 + 计划收口摘要
- 文档 `queue:` 队列 v146（RUNLOG + decisions）

## 八、dist 产物（本轮已更新）

```
77e75e7 2026-11-14T22:36:49 regress=pass11/known1/new0 arch=arm64+x86_64 minos=12.0 icon=96.2 wip=concurrent(11 entries in tree)
```

- 链路：arm64 全量重编（RC=0）→ x86_64 增量（3 步，RC=0）→ `lipo -create` → adhoc 重签 →
  `pack-dist.sh --bin build-universal/concord_runtime`。
- 门禁：`lipo -archs` = `x86_64 arm64`；两切片 `minos` 均 12.0 且与 plist 一致；
  `arch -x86_64 …/concord_runtime --smoke-test` rc=0（合并后与包内各验一次）；pack 内部门禁全过
  （icon diff 96.2/255、plist 身份、包内 smoke rc=0）。
- `wip=concurrent`：工作区仍有并发会话的 11 项（compat 文本层 6 项 + 2 个未跟踪 smoke + `RuntimeShell` 的 8 行接线），
  本轮零触碰；这些改动已随本轮构建进入二进制，与上一轮同一口径。
