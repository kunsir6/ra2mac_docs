# EVO 进化路线图（2026-11-11 傍晚）

前提变化：**游戏已经能正常运行**。用户明确「暂时不方便做太多验证」。

这条前提直接改写了排序判据。此前衡量性价比是「影响效果 ÷ 难度」，现在要再加一个硬约束：
**能不能由机器自己证明**。凡是需要人眼看一眼才算完成的，一律降级；凡是能变成断言、计量或
产物的，优先。理由很直白——不能自证的任务，一旦排进去就会卡住整条链路。

## 一、先体检：回归到底有多少是绿的

在排任何计划之前，先回答「现在到底什么状态」。实测 11 条 smoke（`build-product-arm`，
sha256 `124acc522ea08706`，16:55 构建）：

| 用例 | 结果 | 证据 |
|---|---|---|
| core | PASS | 启动报告正常，仅有 `NAPSYA` 重复建筑告警（数据层） |
| menu | PASS | `rampPixels=1056,781,1428`，`font=game.fnt`，transition 完成 |
| loading | PASS | 6/6 阶段，`firstFramePrewarmed=yes`，`coverageComplete=yes` |
| skirmish | PASS | `maps=161 allPreviews=161 lobbyVisiblePixels=377167` |
| attest | PASS | `records=6 failures=0`，layerHash==dibHash |
| render | KNOWN-RED | `natural-map shadow pipeline did not draw ... candidates=7 drawn=5 structures=0` |
| interaction | KNOWN-RED | `no owned structure for repair cursor`（夹具 10 建筑全 Neutral） |
| command | KNOWN-RED | `amphibious transport: shore unload left tanks aboard` |
| build | KNOWN-RED | `semantic audio probe: ... evaTextEncoding=no`（其余 30 余项 yes） |
| campaign | KNOWN-RED | `movies/sources/audio=FAIL`（maps=40 但视频/素材未齐） |
| result | KNOWN-RED | `score animation stalled behind paused-frame cache` |

**5 绿 6 红。** 六条红里只有 interaction 那条在 RUNLOG 里有记录，其余五条从未被记录过。
这修正了一个此前隐含的判断：「回归全绿」。准确说法是——**被反复使用的那几条是绿的，
其余大部分没人跑过，跑起来是红的**。

这不是坏消息。六条红里至少三条看起来是夹具/数据缺口（campaign 的视频、interaction 的
中立建筑、render 的地图候选），把它们跟真缺陷分开，才有可能谈「健康度」。

## 二、七条进化路线

排序 = 杠杆（解锁多少事）÷ 成本，且全部满足「机器可自证」。

### T0 · 立刻做

**EVO-01 回归编排器（本轮已完成）**
`ra2mac_docs/scripts/regress.sh`，11 条用例、约 20 秒、三态判定：

- `PASS` / `KNOWN-RED`（已登记，附原因）/ `RED-NEW`（未登记，退出码=条数）
- 构建指纹：sha256 + mtime + 架构，并对 dist 做「是否比 build 旧」告警
- 报告落 `progress/regress/<时间戳>/`，`report.md` 给人看、`results.tsv` 给机器读
  （每轮产物 20 秒可重建，故不入库；入库的判据是 `known-red.tsv` 与脚本本身）
- 纯 bash，不用被 shim 的 grep/sed；强制 cd 到 GameData；每条都有 timeout 护栏

有了它，「这次改动有没有弄坏东西」从一轮人工排查变成 20 秒。这是后面所有计划的地基。

**EVO-02 红基线分诊**
六条红逐条定性：`env-gap`（数据/授权缺失）还是 `code-red`（真缺陷）。只读日志，不改代码。
不先把红分完类，后面每次改动都要在「到底是不是我弄坏的」上浪费一轮。

### T1 · 一次投入解锁多条

**EVO-03 diagnostics 驱动入口（最高杠杆）**
`--diagnostics-drive=menu,single,lobby,loading,world`，走真实消息队列合成点击，产品主循环
保持原样。它是被删掉的 `CONCORD_SKIRMISH_AUTOSTART` 的正确形态（独立入口，不侵入产品代码）。
一次投入同时解锁三条卡了很久的任务：

- ON-5-01 全链路进出三轮（泄漏）
- ON-3-01b 五界面上屏自证
- ON-4-02d 跨 TU 首帧

**EVO-04 日志与崩溃现场**
`~/Library/Logs/ConcordRTS/` 常驻日志 + `--collect-diagnostics=<zip>`。
在你暂时不看屏幕的这段时间里，这是唯一能把故障现场交给我的通道。

### T2 · 有明确验收数值

**EVO-05 存档/读档真机往返**：存→推进 30s→读，`deterministicSimulationStateHash` 必须相等。
现有 save/load 断言全是内存态；macOS 上文件落哪、Load Game 能不能读回来，没人验过。
这是「能不能真玩下去」的分水岭，且完全自动可判。

**EVO-06 世界重绘只读计量**：不改行为，只统计「每 tick 里有几次真的改变了画面」。
ON-2-06 的降级理由仍然成立（改 `changed` 语义会影响 Windows，本机无法回归），所以先拿数字，
再决定要不要碰。零风险决策输入。

### T3 · 给别人用

**EVO-07 首次启动引导 + dmg**：数据根缺失改成可读对话框（选目录/退出），About 显示版本/架构/
构建时间，两份 thin 产物各出一个 dmg。对你自己玩没有收益，故排最后。

## 三、明确不做（避免反复讨论）

| 项 | 理由 |
|---|---|
| Bink 动画解码 | 成本高，静帧已作为产品决策接受（rules.decisions） |
| 系统全屏 | 需 `[NSApp run]`，与当前 compat 主循环架构冲突（ON-2-04b blocked） |
| 屏幕合成抓图 | macOS 26 SDK 里 `CGWindowListCreateImage` 已 unavailable（ON-3-02 blocked） |
| 再追帧率/CPU 数字 | 已 52fps，对「能玩」边际收益约等于零 |
| 修改共享模拟层 | 会同时影响 Windows，本机无法回归——除非 EVO-06 给出压倒性数字 |

## 四、验收方式

每轮收尾固定两步，都不需要人：

1. `bash ra2mac_docs/scripts/regress.sh` → 必须 `RED-NEW=0`
2. 报告落 `progress/regress/<时间戳>/report.md`，并在 RUNLOG 贴出 PASS/KNOWN-RED/RED-NEW 三数

只有出现新的 `RED-NEW` 时才需要人判断；`KNOWN-RED` 是已登记的历史账，按 EVO-02 的结论
逐条转为修复任务或永久结案。
