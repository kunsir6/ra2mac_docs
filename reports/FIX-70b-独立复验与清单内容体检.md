# 第 70b 轮：独立复验 + 清单内容体检（同一工作区里有并发会话）

- **轮型：诊断轮**。判据不是 `queue.rules.brake`（无此键、`attempts≥3` 只有已 blocked 的 M-25），而是
  `rules.concurrency` 第三条的现场版：开轮 3 分钟内发现**另一个 WorkBuddy 会话（Electron pid 88868，
  08:23 启动）正在同一工作区改源码**，并且已经在 `ninja -C build-product-arm` 里编译（08:41 起）。
  这种状态下「改产品代码 + 跑构建 + 跑 regress + 打包」四件事全部会跟它抢同一批文件与同一棵构建树，
  按纪律转 diagnose-only：**本轮不改产品代码**，收口职责照做（`§十二`）。
- 本轮的价值不在新增修复，而在于：①给并发会话的交付做**第二个进程的独立复验**；②补上 `AUDIT-66`
  自己记下的缺口——`ledger-check.sh` 十三项全是**形状门禁**，没人查「这一行该不该存在」。

## 一、并发现场（本轮为什么不动源码）

| 时刻 | 事件 |
|---|---|
| 08:23 | 另一会话（Electron 88868）启动，工作区随之变脏 |
| 08:38 / 08:41 | `RuntimeMenuModalPauseSmoke.inl`（155 行）与 `RuntimeShell.cpp`（+38/−1）落盘 |
| 08:41→08:44 | 该会话 `ninja -C build-product-arm`，重编 RuntimeShell.cpp 并重签 |
| 08:44:55 / 08:47 | 源码提交 `5e28fcd`(fix) `d01fb3b`(test) |
| 08:44:59 | 该会话跑全量 regress：`pass=16 knownred=2 new=0 total=18`，`source=d01fb3b dirty=0` |
| 08:46 | 文档提交 `00c7756`（报告 + fix-plan + queue + regress.sh 第 18 条） |
| 09:48 | 该会话补 x86_64 切片 |
| 09:54~09:55 | **本轮**接上收口链（两架构 → lipo → 签名 → pack-dist） |

我的处置：08:43~08:58 全程只读（复跑冒烟、对数、读 diff），**不 stash、不提交别人的 WIP、不并发跑
regress**（`regress.sh` 的 `latest.txt` 走 `$LATEST.tmp && mv`，两个进程同时跑会互踩）。
`progress/.active` 仍停在 2026-11-12 的 `released`，**锁没被用过**——这次是靠 `ps` + `mtime` 看出来的。
教训：**锁释放了不等于没人在干活**，开轮第一件事应该是「有没有活进程在改这棵树」，而不只是读锁文件。

## 二、独立复验：修复是真的，判据也是真的

用**包内二进制**（`dist/尤里红警.app/Contents/MacOS/concord_runtime`）复跑第 18 条，而不是只看它的报告：

```
Menu modal pause: sfxChannelsStopped=yes liveSfxChannels=0 evaStopped=yes
                  bottomStripLeak=0 wholeClientLeak=0/480000
Menu modal pause: closeRestoresNothing=yes      → rc=0
```

- 哨兵法（先整屏刷品红 `0x00ff00ff`、再画菜单、数剩余哨兵）是对的形状：它把「哪块没盖住」变成一个**确定的数**，
  不依赖一张可遇不可求的对照图。**判据比结论值钱**，这条门禁以后能重复用。
- 红态数字与我的算术一致：`contentRect` 底部留 32px，`632×32 = 20224` px 会保持哨兵——
  与该会话报告里「哨兵实测 20224」对得上。这点很重要：**它不是「改完就绿」，是先有红数再转绿**。
- 我没有独立重测红态（要 checkout 父提交整棵树重编，与并发会话抢构建树不值得）。**这条记为未独立验证项**，
  依据是该会话报告里的实测数 + 代码路径推导，两者一致。

## 三、副作用审查（读代码，不改）

1. `const bool wasOpen` 挡掉了重复打开——`setRuntimeMenuOpen(state,true)` 在同一状态被调用两次不会重复 stop，
   幂等性成立；`open=false` 分支不动音频，符合「关菜单不复活」。
2. `muteRuntimeEvaPlaybackPreservingSubtitle` 在**有字幕**时把 `runtimeEvaBusyUntilTick` 顶到字幕结束时刻
   （不是清零）——这是有意的：字幕还在屏上时不该允许新的 EVA 抢占。副作用是 probe 的
   `evaBusyUntilTick == 0` 只在**无字幕**现场成立（它注入的正是无字幕态），所以这条断言比产品口径**窄**，
   不会误判，但也不能声称覆盖了「边播字幕边开菜单」。记为一个已知窄口。
3. 音乐不动（零售选项菜单不打断 BGM），只停 8 通道 SFX 池 + EVA 通道——与用户报障的「声音冲突」对得上。
4. `stopRuntimeSfxPlayback` 是全清而非只清在播的，关菜单后由模拟下一拍自然重新发起——probe 的
   `closeRestoresNothing=yes` 把「不该自己复活」钉住了。

## 四、清单内容体检（`ledger-check` 查不到的那一层）

`bash ra2mac_docs/scripts/ledger-check.sh` 十三项全绿（252 行 / 43 条 / 72KB / rules 5 类）。
按 `§一.7` 再查内容，三条发现：

1. **RUNLOG 逼近硬顶：1296 行 / 113KB，门禁 1500 行 / 120KB（字节 94%）**。R70 一次 +21 行，
   按每轮 ~4KB 计，**下一两轮必破 120KB**。`§一.1` 说的是「超限当轮先压缩」，但到那时已经晚了——
   建议下一轮开工第一件事把 R60 以前的分段迁 `reports/archive/RUNLOG-archive-202611.md`，正文留一行索引。
2. **U-19 在 plan 里没有行**，而它已经是 U-24 之后第一顺位。plan 抬头自己写着「唯一台账」，
   `§一.4` 又规定「缺根因假设/收益/成本/attempts/验收条件的条目不许进排序」——**U-19 现在正好卡在这条自定规则上**：
   queue 里有全字段，plan 里查不到，于是「它凭什么排在第二」无从复核。
3. 16 条在办条目 plan 无行，其中 8 条是已登记的镜像对（`EVO-03≈M-07`、`ON-2-06≈M-03` …），
   5 条是 `AUDIT-56` 已登记为已知（ON-5-01/ON-5-02b/ON-4-02d/ARM-03/ON-2-04b），
   **真正新增的只有 U-19 与 ON-3-01b**。所以补 2 行而不是补 16 行——一次性补齐会把 252 行推到 268 行，
   并在 plan 里制造第二份详细台账（与 `§一.6` 的等价替换相反）。
4. 顺带确认：`S-38` 的 `attempts`（plan=1 / queue=0）**已被 R70 修掉**，plan/queue 状态矛盾本轮为 0。

## 五、质量四数

| 指标 | 数值 | 说明 |
|---|---|---|
| ①本轮净增行数 | **源码 0**（本轮）；同轮并发交付 `755abf2..d01fb3b` = **+193 / −1**（2 文件） | 我自己没有改产品代码 |
| ②最大单文件 | `RuntimeShell.cpp` **90,672**（R69 90,635 → +37） | 单次 <50 行，未触发准入条例 |
| ③断言 vs 产品代码 | 新增门禁 1 条（regress 第 18 条）；产品改动 15 行 | 同一轮 fix: 与 test: 分开提交 |
| ④TODO/FIXME | 0 → 0 | — |

## 六、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：U-24（世界帧出口）。它是重排后的第一顺位，但要动 `RuntimeShell.cpp` 的世界路径，
  与并发会话同一文件同一构建树，硬上就是制造冲突。
- **没做**：RUNLOG 归档。它需要按段搬移并把正文截短，而并发会话随时可能追加——**搬移期间它写一行我就丢一行**。
  只报数、不动手。
- **遗留债**：①U-19 / ON-3-01b 的 plan 行；②`progress/.active` 这次没被任何会话持有，
  「并发」是靠 `ps` 发现的——轮次锁的**写法**（`released` 之后没人再写）与实际并发脱节，值得单独一条；
  ③EVA 字幕并存态没有门禁（见 §三.2）。
- **放弃**：在 diagnose-only 轮里塞「顺手修小项」。并发窗口里任何一次编译都可能踩掉别人的产物，
  这一轮的克制本身就是产出。

## 七、dist

```
d01fb3b 2026-11-16T09:55:20 regress=pass16/known2/new0 arch=arm64+x86_64
        minos=12.0 icon=96.2 rosetta=rc0 buildtree=clean wip=none round=R70
```

开轮时 dist 停在 `755abf2`（R69），而源码 HEAD 已到 `d01fb3b` → **落后两个提交**。并发会话做完源码与文档
之后就停在收口前，这条链由本轮补齐：arm 重链 → x86_64（该会话 09:48 已建）→ `lipo-universal.sh`（两切片
minos 12.0、adhoc 重签通过）→ `pack-dist.sh --round R70`。门禁逐条独立复验：
`lipo -archs = x86_64 arm64`、两切片 `minos=12.0`、plist `LSMinimumSystemVersion=12.0`、
`arch -x86_64 --smoke-test rc=0`、包内 `menumodal` rc=0。**用户现在双击到的就是 `d01fb3b`。**
