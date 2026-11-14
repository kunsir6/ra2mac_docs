# 第 40 轮（2026-11-14）——重排：五名奴隶矿工全部停在 `Queued` 的移动请求上

**轮型**：修复轮（无 brake、无 attempts≥3、腐烂预算未触发；AUDIT-35 之后四轮，审计轮落在第 41 轮）。
§八.3 比例闸仍在（近 5 轮 `test:`3 / `fix:`1 = 3.0×）→ 禁新增断言，只许改产品行为或清偿。
**收口方式改判为「重排」**：主目标（`command` / C-02i）一动手，第 25 轮死因报告的两条候选**同时被实测推翻** →
按 §七.1「根因假设被推翻」触发 Escalation，剩余时间锚点作废，只做诊断 + 重排（本轮源码零改动，HEAD 不变）。

---

## 一、主目标与读数方法

`command` 是回归里唯一一条 known-red（`PASS=11 KNOWN-RED=1 RED-NEW=0`，`20261114-233834`），
失败文案 `slave miner: workers did not dig, carry full loads and deposit credits: digging=1 carrying=1 cargo=4 credits=0`。
第 25 轮把它判 blocked 时留了「重开条件」：**一条默认静默的读数，一次运行就能裁定 ①/②**。

读数实现方式：在 `RuntimeSlaveMinerSmoke.inl` 的 3500 拍循环里挂一个 `CONCORD_SLAVE_PROBE` 门控的
每 120 拍一行读数，跑 `--command-smoke-test` 取 30 行，**取完当场删除**（§五.4：临时探针不许跨轮存活；
本轮源码零改动、零新增断言，见 §六质量四数）。读数每行内容：
`phase / cargo / mission / renderMoveActive / 承诺格 / 身体格 / 到地基距离(两者) / 行为(kind,state,target) / status`。

## 二、读数（终态，tick=5371；与 tick=5131 逐字相同）

```
home=7@22,10 move=0 build=0 lvl=0 bridge=0
w6 ph=1 cargo=0/0  mis=Guard mv=0 cell=23,11 body=23,11 dc=0     db=0     beh=move/1/24,12 st=leaving refinery for ore
w5 ph=3 cargo=4/100 mis=Guard mv=0 cell=24,11 body=24,11 dc=1     db=1     beh=move/1/22,10 st=returning
w4 ph=3 cargo=4/100 mis=Guard mv=0 cell=24,12 body=24,12 dc=1.414 db=1.414 beh=move/1/22,10 st=returning
w3 ph=1 cargo=0/0  mis=Guard mv=0 cell=24,11 body=24,11 dc=1     db=1     beh=move/1/24,12 st=leaving refinery for ore
w2 ph=1 cargo=0/0  mis=Guard mv=0 cell=24,10 body=24,10 dc=1     db=1     beh=move/1/24,12 st=leaving refinery for ore
```

`beh=move/1/…` 的 `1` 是 `RuntimeBehaviorState::Queued`。**五个人的行为全是 Queued，`renderMoveActive` 全是 0，
240 拍内一格没动。** 早段（tick 2011~2131）这同一批人是真的在动的（`mv=1`、w5 已 `digging`），
所以不是「这台机器上根本不会动」，而是**动到某个点之后全体停摆**。

## 三、被推翻的两条候选（第 25 轮死因报告的 ①/②）

- **①「`runtimeSlaveMinerWorkerAtRefinery` 从未成立（承诺格/身体格到地基距离不一致或 `renderMoveActive` 未清）」——
  表述对，但不是原因**。终态里 `w6` 的 `dc=0 db=0` 已经**满足**距离 0；它照样不交付，因为
  `advanceRuntimeSlaveMinerWorkerTask` 在 `RuntimeSessionProduction.cpp:7325-7336` 只要
  `state.behaviors` 里存在这个对象的行为就 `return false`——**任务步根本走不到 7339 的交付分支**。
  换句话说：不是「交付谓词不成立」，是「任务被自己的行为记录短路了」。
- **②「交付分支跑过、`resourceStorageCapacity==0` 吞掉入库」——排除**。`cargo` 终态仍是 `4`，
  若交付分支跑过，`task.cargoUnits` 会被清零（`RuntimeSessionProduction.cpp:7386-7388`）。
  `cargo=4` 一直不动 = 一次都没交付。

## 四、新的机制（本轮实测得出，尚未修）

三条串起来看：

1. **满载者站在唯一矿格上**。`w4`（`cargo=4`）身体格 = `24,12`，正是 `firstOre` 的锚点格；
   `w2/w3` 的离场目标也写着 `24,12` —— 它们要去的地方被一台满载的同伴占着。
2. **两个人的回家目标写着 `22,10`**，正是炼油厂自己的格子（`home=7@22,10`）。`allowedOccupiedObjectId`
   允许它们进自家地基（`entry=1` 一直成立），但距离 1~1.4 格就再也没靠近过。
3. **所有人的行为都停在 `Queued` 且 `renderMoveActive=0`**。⚠️ `Queued` 在本项目里有**两个**生产者：
   `submitRuntimeMovePathRequest`（`RuntimeSessionNavigation.cpp:6738`，请求已提交、路径还没算）与
   `applyRuntimeMovePathResult` 成功分支（`:6846`，路径已解析、等推进）。本轮读数只打了行为状态、
   **没打 `pathRequestPending` / `path.size()`**，所以「路径给了但没人推」与「请求挂在队列里没人消费」
   **还没分开**——这正是下一轮要给的那条读数（本文标题里的「已解析」是待验假设，不是结论）。
   可以确定的两件事：①不是「没地方可去」——`entry=1` 全程成立、目标格都在 1~1.4 格内；
   ②不是「还在等冷却」——冷却分支会把状态写成 `Blocked`（`:6623`），而这五个人是 `Queued`。

也就是说：这不是奴隶矿工专属的交付逻辑问题，而是**「已提交/已解析的移动请求在某些互锁几何下不再前进」**。
它是 movement 层的共性风险，不是 `RuntimeSessionProduction.cpp` 能关起门来的事——这正好解释了
为什么 C-02 这条线连拆 9 个子项都修不完：每次都在生产/任务侧找原因，而停摆发生在运动层。

## 五、重排（本轮产出）

- **C-02i 维持 blocked**，但重写「还缺什么」：不再是「一条交付读数」，而是**两条**——
  (a) 终态下这五个 `behavior.path` 是否为空（决定「路径没给」还是「给了不推进」）；
  (b) 运动层里「Queued 且 path 非空」的对象为何没被 `advanceRuntimeCommittedGroundMotion` 消费
  （是 subcell 占位、`runtimeMovePathBatchCompatible` 之外的门、还是「等别的单位让路」这一类隐含等待）。
- **不再在 C-02 之下开第 10 个子项**。若 (b) 成立，它属于新主线 `movement-stall`（运动层停摆），
  C-02i 只是它的第一个受害者；按 §六.2 拆新 ID 要继承该新主线的轮次，不许用它给 C-02 续命。
- **估值变化**（§七.3 要求条目级重估，不只调顺序）：
  C-02i 收益 **A→A**（奴隶矿工不产收入，仍是 S 级用户价值），成本 **中→高**（从「生产侧一处谓词」变成
  「运动层共性停摆」），性价比 **A→B**；这解释了为什么它在 blocked 里躺了 15 轮还修不动。
- **下轮候选**：一条只读读数即可把 (a)/(b) 分开（打印 `behavior.path.size()` + 谁在推进），
  仍然撞比例闸——所以第 41 轮按审计轮走（AUDIT-40），把这条读数排进第 42 轮。

## 六、质量四数与清单体检

- **净增行数**：源码 **0**（探针加上又删掉，`git diff` 对 `RuntimeSlaveMinerSmoke.inl` 为空）。
  工作区里那 7 文件 +339/−2 是并发会话的 WIP（`RuntimeAppleWindowSurface` / `RuntimeWin32CompatText*` /
  `PlatformApple.cmake` / `RuntimeShell.cpp` 15 行），本轮零触碰。
- **最大文件行数**：`RuntimeShell.cpp` **90,626**（本轮 0 行变化，其中 +15 是并发 WIP）；
  `RuntimeMapRenderer.cpp` 本轮未触碰。
- **断言 vs 产品代码**：新增断言 **0** / 新增产品代码 **0**（比例闸生效）。
- **TODO/FIXME**：`src/` 全量 **0**；一次性探针 **+1 → −1**（本轮净 0 存活）。

清单体检：fix-plan **228 行**、queue **56 KB / 35 条 / rules 5 类**，`ledger-check.sh` 七项全绿；
本轮**无新增条目**（改的是 C-02i 死因表述，不是新 ID），故不触发 §一.6 的 1:1 替换；
悬空报告引用 0、状态与报告矛盾 0、重复条目 0、attempts 与收口记录一致（C-02i 仍 2，本轮未再计 +1，
因为它没有「动手未结案」，是收口表述更新）。
本轮**未压缩归档**：三项体量都在限内，无 30 天以上日志需要合并。

## 七、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：没有改任何产品代码。§七 的 Escalation 明确要求本轮剩余锚点作废、只做诊断，
  用一条猜测的补丁去换「看起来修了」，正是 §八 要治的假完成。
- **遗留债**：`command` 仍是 known-red；奴隶矿工仍不产生收入（挖得动、装得满、交不进去），
  这段产品行为差异继续以 blocked 记账，不假装已修。
- **放弃**：本轮原计划的「同轮修完 + 打包新二进制」——因为 HEAD 未变，dist 仍是 `77e75e7` 编出来的那份，
  与 HEAD 一致（见 BUILD-STAMP）。宁可保留一份真实对应 HEAD 的包，也不把「改了探针又删掉」的中间态当成新版本。
- **代价**：C-02 这条线从「生产侧收尾」升级成「运动层共性停摆」后，它的修复成本会高于此前所有子项之和；
  如果 (b) 成立且牵连面 >2 模块，按 §七 它可能整体转 deferred。

## 八、dist 产物与门禁读数（本轮收口实测）

```
dist/BUILD-STAMP.txt:
77e75e7 2026-11-14T23:54:42 regress=pass11/known1/new0 arch=arm64+x86_64 minos=12.0 icon=96.2 rosetta=rc0 wip=concurrent(11 entries in tree)
```

- 完整打包链本轮**照跑**（arm 全量重编 → x86_64 → lipo → ad-hoc 重签 → `pack-dist.sh --bin build-universal/concord_runtime`），
  产物 `dist/尤里红警.app` 96 MB，`bundle-id org.concord.rts.yuri`、显示名「尤里红警」。
- 门禁逐条：`lipo -archs` = `x86_64 arm64`；两切片 `minos` 均 **12.0** 且与 plist `LSMinimumSystemVersion` 一致；
  `arch -x86_64 … --smoke-test` **rc=0**（交叉切片单独验过，不是盲区）；
  `pack-dist` 自身门禁：`icon diff-vs-generic=96.2/255`、plist 身份、包内 `--smoke-test rc=0` 全过。
- 回归用**编完的新二进制**重跑：`PASS=11 KNOWN-RED=1 RED-NEW=0`（`20261114-235343`），红点前缀未变。
- 因为本轮源码零改动（HEAD 仍是 `77e75e7`），这份包与上一份**代码等价**；重打是为了满足「dist 必须是当前 HEAD 编出来的」，
  并顺带验证了全量重编后的两切片仍能过 smoke。`wip=concurrent(11)`：工作区里并发会话的 11 项改动被一起编进了包
  （与此前几轮同一口径），本轮未触碰它们。
