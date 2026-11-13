# FIX-27 第 26 轮：清偿——删掉跨轮存活的探针

**轮型：清偿轮。** 触发依据（§0.3 第三条）：近 5 轮提交 test: 4 条（`2c3616c` / `8dfc9f4` / `7c02812` / `c5d2b6c`）
对 fix: 2 条（`d6654eb` / `7b9f576`），比值 2.0 达线；同时 §8.3 比例闸因此对下一轮仍然生效。
KPI 按清偿轮口径：**净增 ≤0，regress 不退化**。

## 1. 删了什么

`CONCORD_SLAVE_EMERGENCE_TRACE` 的八处只读打印，共 **126 行**（产品代码，三个文件）：

| 文件 | 处 | 位点 |
|---|---|---|
| `RuntimeSessionProduction.cpp` | 4 | `no-ore-branch` / `exit-issue`（签发成功、`exit=none`）/ `departure-issue` |
| `RuntimeSessionNavigation.cpp` | 3 | `goal-adjusted` / `entry-recovery` / `reconcile-relocate` |
| `RuntimeSessionWorld.cpp` | 1 | `set-cell-jump`（`setRuntimeObjectCell` 跨 >1 格） |

## 2. 为什么可以删

- 这八处是**第 24 轮（C-02h）一次性取证**留下的：当时要回答的是「工人 3 格瞬移是谁改的格」，
  答案已在 `reports/FIX-25-奴隶矿工离场不该被当成取消入场.md` 里写死（`recoverRuntimeCancelledStructureEntry`
  把「path=0 即刻完成的离场」误判成失败入场）。问题已结案，读数没有第二次用途。
- C-02 主线第 25 轮**判 blocked**，重开条件是「先在交付段落一条新读数」（挂在
  `advanceRuntimeSlaveMinerWorkerTask` 入口），不是复用这八处——它们覆盖的是出舱/离场段，
  交付段一个都没打。留着等于把「看起来能查」的假入口留在代码里。
- 按 §5.4：临时探针必须同轮转成断言或删除，**不许跨轮存活**。这八处已经存活了两轮。
- 删的只是打印和「为打印而取的局部量」，没有一行参与判定，`setRuntimeObjectCell` 的改格、
  恢复搜索、寻路兜底分支全部原样。

## 3. 靠什么兜住

- 构建：`ninja -C build-product-arm concord_runtime` 通过（无新增 warning 类别）。
- 回归：`bash ra2mac_docs/scripts/regress.sh` → `PASS=10 KNOWN-RED=1 RED-NEW=0`，
  与基线逐条一致；`command` 的 known-red **失败前缀不变**
  （`slave miner: workers did not dig, carry full loads and deposit credits`），
  说明删的是旁路打印，不是把红项擦掉。
- 签名：新链接二进制已 `codesign -s - --force` 重签后再跑，未出现卡 U 状态。

## 4. 本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：`RuntimeSlaveMinerSmoke.inl` 里还有 6 处同名探针（smoke 侧 offender dump，仍是
  `CONCORD_SLAVE_EMERGENCE_TRACE` 门控）。本轮只清产品侧——一次改动同时动 smoke 侧要重跑三条
  smoke 才能确认判据没被影响，超出本轮时间锚点。登记为 **S-15**，下轮清偿时一并清掉并同步删掉
  这个环境变量本身（现在它仍有两个用途，删一半比不删更糟）。
- **遗留债**：M-13（真实遭遇战取证通道）本轮开工前做了 20 分钟只读定位但**没动手**，原因是它
  的验收条件（己方有 MCV、`Players≥2`、HUD 有资金与电力）在无窗口路径上无法观察，而 `--skip-skirmish-menu`
  在 macOS 上只能起真窗口（实测 `[cocoa] frame N` 有输出、但没有会话状态出口）。已确认的事实：
  `--skip-skirmish-menu` 只做 `showMainMenu/showSkirmishMenu=false`（`RuntimeMain.cpp:829-832`），
  **不构造** `playerSlots`（真遭遇战走的是 `applyRuntimeSkirmishSelection`，`RuntimeSkirmishSetup.cpp:31-44`），
  所以 `initializeRuntimeSkirmishStart` 走的是「无 slot 的单人兜底」分支。这条线索比原登记更具体，
  但取证通道本身仍是前置任务——先有 M-07/M-13 的只读出口，才谈得上修。
- **放弃了什么**：本轮没有把「清偿」扩成「顺手改行为」。八处探针旁边的判定逻辑一行没碰——
  清偿轮的纪律是只删不改，否则回归一旦红了无法二分到根因。

## 5. 质量四数

| 指标 | 数值 |
|---|---|
| 净增行数 | **−126**（3 files changed, 126 deletions；源码仓库零新增） |
| 最大单文件 | `RuntimeShell.cpp` 90,459（不变）／`RuntimeSessionWorld.cpp` 30,805→**30,794** |
| 断言 vs 产品代码 | 新增断言 0（比例闸生效）／净删产品代码 126 行 |
| TODO / FIXME | 0 → 0（持平） |

## 6. 清单体检

`bash ra2mac_docs/scripts/ledger-check.sh`：五项全绿（fix-plan 125→127 行 / queue 46KB / tasks 40 /
rules 5 类 / 无 detail 超 6 行）。悬空引用 0、状态矛盾 0、重复 id 0。新增 S-15 一条，同时把
`M-20` 从「最近 10 条已完成」挤出到归档，保持条目数不涨。

## 7. 两级计数

- 条目 attempts：S-15 新登记 0；M-13 本轮只做定位不计 attempts（未进排序，等取证通道先落地）。
- 主线 threads：C-02 已判 blocked（11 轮 / 9 子项，不再开第 10 个）；本轮动的就是它的**残留探针**，
  不构成新子项。其余主线（onboarding / UI 取证 / 存档）均 0 轮起算。

## 8. 下轮起手

清偿还剩一段（S-15 smoke 侧 6 处 + 删掉 `CONCORD_SLAVE_EMERGENCE_TRACE` 这个变量本身），
但**不建议连做两轮清偿**：下轮应回到修复轮，首选 M-13 的**前置**——给 `--skip-skirmish-menu`
加一条无窗口的会话状态出口（打印 `skirmishStatus` 与己方单位数），这是 M-13/M-07/U-19/U-20/U-22
共用的门；没有它，后面五轮都只能靠抓图猜。S-15 作为伴生小项塞进那一轮。
