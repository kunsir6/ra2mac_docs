# 移出主清单的条目（deferred）

> 规则：进本文件 = 从 `fix-plan.md` 移出，不再每轮进上下文，**不开新条目、不占主线计数**。
> 每条必须写清「重开条件」——没有重开条件的 deferred 等于悄悄放弃，不允许。

## M-24 录像兼容哈希漏算归档侧模式规则

- **移出日期**：2026-11-14（第 31 轮，skirmish-mode-rules 主线整体收口判 done）
- **原属主线**：skirmish-mode-rules（4 子项，第 31 轮用尽窗口，判 done）
- **现象**：`RuntimeMatchReplayRuntime.inl:47-49` 只在 `resolveRuntimeModeRulesOverridePath()` 返回非空时
  `mixFile()`，而该函数只查松散层。模式规则已改为「松散优先 + 归档回退」（M-22）后，
  归档命中时这段**整段不执行** → 模式规则文本不进哈希。
- **后果**：同一套有效规则下，「有松散 `MP*MD.ini` 的机器」算出的 `matchReplayCompatibility`
  与「只有归档的零售机器」不同 → 可回放的录像可能被判不兼容；反过来，归档侧的规则差异也不会被发现。
- **为什么可以移出**：只影响跨机兼容判定，单人本地回放不经过这条比较；且改它要动
  `ReplaySimulation` 版本号（逼升），一次性会让所有旧录像判不兼容，属于「要有发布窗口才做」的改动。
- **重开条件**：任一条成立即重开——① 多人联机实装并开始用该哈希做准入；
  ② 出现「同一录像在两台机器上判定不同」的实测；③ 版本号本来就要因为别的原因逼升。
- **改法草案**（重开时直接用，不必重新设计）：把 `mixFile(mode)` 换成「模式规则文本入哈希」——
  `loadRuntimeModeRulesIni` 已经能同时拿到松散与归档两种来源的文本，取它返回的文本做
  `runtimeStableHashMixString` 即可，天然消掉两台机器的路径差异。

## C-02i 奴隶矿工交付段：挖得动、装得满、交不进去

- **移出日期**：2026-11-13（第 25 轮，C-02 主线整体收口）
- **原属主线**：C-02 两栖/奴隶矿工（该主线已用 11 轮 / 9 子项，超红线两倍以上，判 blocked）
- **现象**：`Command smoke failed: slave miner: workers did not dig, carry full loads and deposit credits:
  digging=1 carrying=1 cargo=4 credits=0`（`RuntimeSlaveMinerSmoke.inl:474-499`，3500 拍循环跑满）
- **已排除**（第 25 轮静态排除，非跑读数）：
  1. `context.credits` 不回写 —— `HouseEconomyContext::credits` 是 `int&`，直指 `state.economy.credits`；
  2. `cargoValue<=0` 被当空返 —— `cargoValue += value` 与 `++cargoUnits` 同分支同步，`value<=0` 时提前 return 且不增 units。
- **剩余候选**：① `runtimeSlaveMinerWorkerAtRefinery` 的复合谓词（`!renderMoveActive` + 承诺格与身体格到地基距离都 == 0）从未成立；
  ② 交付分支跑过但 cargo 被清零后循环重来。
- **重开条件（三条同时满足才重开）**：
  1. 先落地一条默认静默的读数，挂在 `advanceRuntimeSlaveMinerWorkerTask` 入口，每 120 拍打一行
     `id / phase / mission / cargo / renderMoveActive / 到地基格距离 / behavior.kind`；
  2. 该读数**一次运行**能裁定 ①/②（能打出来就是定性证据，打不出来本身也是结论）；
  3. 主人线账目重新起算：重开时按新主线登记，**不带 C-02 的 11 轮**，且必须与别的赛道交替（不连续 2 轮）。
- **代价（已知的产品行为差异）**：尤里的奴隶矿工目前不产生收入。挖得动、装得满、交不进去。
  这是真实缺陷，以 blocked 记录，不假装已修；`command` 那条 known-red 继续带前缀门禁留在回归里。

## C-02 主线剩余未做的行为差异（收口时一并记录）

- 奴隶矿工「移动式」分支（`SMIN` 折叠/展开时的货物继承）已由 C-02f/`RuntimeSlaveMinerSmoke` 后半段覆盖，
  但**交付读数为 0** 使该段从未被执行到，所以「折叠后货物不丢」目前只有序列化往返的证据，没有端到端证据。
- 两栖运输的**全水域**场景（`C-02c` 的「全水时退回就地停靠」分支）只有代码路径，没有夹具覆盖。

## ON-3-02：`--onscreen-capture`（第 33 轮移出，等价替换 S-19 的入口）

- **现象**：想要一条"屏幕上真的是这幅画"的证据，用 `CGWindowListCreateImage` 抓本进程窗口。
- **死因（已排除什么）**：`CGWindowListCreateImage` 在 macOS 26 SDK 已标 **unavailable**（不只是 deprecated），
  编译直接报错（`CGWindow.h:271`）。替代路径只剩两条，都不缺工时而是缺前置：
  ① `screencapture -l <windowNumber>` 子进程（需 TCC 屏幕录制授权）；② ScreenCaptureKit（macOS 14+，异步 + 同样要授权）。
- **还缺什么**：本机 Accessibility/屏幕录制授权未批（见 MEMORY「本机 Accessibility 未授权」），
  合成输入与抓屏都被系统丢弃，所以这条**不是写代码能推进的**。
- **重开条件**：用户侧一次性授予屏幕录制权限，且 `screencapture -l` 能稳定抓到本项目窗口一帧；
  届时先做 `--onscreen-capture` 的最小实现（子进程 + 与同帧 BMP 比对平均通道差 <2），再接回五界面自证。
- **代价（未做带来的）**：`attest` 那条 smoke 只能证明"我们交给了系统的那份位图"，不能证明"屏幕合成结果"。
  这条差距在 ON-3-01b（五界面上屏自证）里同样存在，但不阻塞任何判定。
