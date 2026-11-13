# 移出主清单的条目（deferred）

> 规则：进本文件 = 从 `fix-plan.md` 移出，不再每轮进上下文，**不开新条目、不占主线计数**。
> 每条必须写清「重开条件」——没有重开条件的 deferred 等于悄悄放弃，不允许。

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
