# FIX-70 战斗内 ESC 菜单真正接管画面与声音

**轮型：修复轮**（第 70 轮，2026-11-16）。起点是用户报障，不是清单里的条目：

> 「战斗中点 esc，呼出战斗中的菜单。战斗显示跟菜单显示包括声音是有冲突的。」

这条报障把上一轮刚登记的 U-24（世界帧出口）从「下一轮的计划」直接变成了「本轮的工具」——
只是这次不需要整条通道，只需要一条能判「菜单有没有盖住整屏」的判据。

---

## 一、模态菜单在这一版里只做了一半

`runtimeMenuOpen` 为真时，代码已经做了三件事里的一件：

| 应有的模态语义 | 现状（修前） | 位置 |
|---|---|---|
| ① 模拟不走拍 | **已做** | 主循环 `else if (state.runtimeMenuOpen \|\| state.skirmishMatchFinished) tickAccumulator = 0.0;` |
| ② 整屏被菜单盖住 | **只盖了 contentRect** | `drawRuntimeMenuOverlay` 的 `FillRect(dc, &layout.contentRect, mask)` |
| ③ 在播的战斗音效 / EVA 停掉 | **一处都没做** | `setRuntimeMenuOpen` 完全不碰音频；全仓 `grep runtimeMenuOpen` 在音频路径上零命中 |

### 1.1 画面：底部 632×32 一直是战场

`runtimeMenuBackgroundLayout` 的 `contentRect` 是
`{0, 0, clientWidth - 168(侧栏), clientHeight - 32(动作条余量)}`，
而地图视口 `runtimeMapPixelViewport` 只减侧栏宽、**高度是满的**：

```
contentRect.bottom = 600 - 32 = 568        ← 菜单盖到 568
runtimeMapViewport.bottom    = 600          ← 战场一直画到 600
```

于是菜单打开时，底部 632×32 那一条仍然是战斗画面（`drawRuntimeMapWin32` 先画、菜单后盖但没盖到）。
在 800×600 下这条是 20,224 像素；换成更大的窗口，被漏掉的还是那 32px 高的一条。

### 1.2 声音：暂停停不住已经响起来的

主循环把 `tickAccumulator` 清零只保证「不会有**新**音效」，但两条通道不归 tick 管：

- 战斗音效 —— 8 条 MCI 通道池（`runtimeSfxChannelCount = 8`），一旦 `playFromStart` 就在设备侧自主播完；
- EVA 语音 —— `runtimeEvaWaveDevice()` 专用通道，同样自主播完。

而菜单自己的按钮音走 `MenuSoundDevice`（另一个接缝）。两边同时出声 = 用户听到的「声音冲突」。
音乐刻意不动：零售的选项菜单不打断 BGM，这一条写进了代码注释，避免下一轮有人「顺手」也停掉它。

---

## 二、改法（15 行产品代码，两个面同一个根因）

根因只有一个：**打开菜单时只改了 `runtimeMenuOpen` 这个标志，没有让它接管画面与声音**。
所以两个面放在一个 `fix:` commit（同一根因跨两个表现面，`§九.4`）。

1. `drawRuntimeMenuOverlay`：底色从 `layout.contentRect` 改为 `clientRect`。
   侧栏区域随后由 `drawRuntimeMenuSidebarBackground` 整体重画成菜单皮肤（先盖黑不会吃掉它），
   所以盖满整屏不会破坏菜单自己的左右分区。
2. `setRuntimeMenuOpen` 在 `open && !wasOpen` 时调
   `stopRuntimeSfxPlayback(state)` + `muteRuntimeEvaPlaybackPreservingSubtitle(state)`。
   用 `wasOpen` 判一次，避免「菜单已开时再设一次 true」重复停音。

---

## 三、判据：数哨兵像素，不跟参考图比

新冒烟 `CONCORD_COMMAND_SMOKE_MENU_MODAL_ONLY=1 --command-smoke-test`
（`src/ui/input/diagnostics/RuntimeMenuModalPauseSmoke.inl`），一次跑完四条：

1. 整屏 800×600 刷品红哨兵（菜单美术里不会出现这个颜色）；
2. 走**产品入口** `setRuntimeMenuOpen(state, true)`；
3. 画菜单，数剩下的哨兵像素（全屏 + 底部条带各数一次）；
4. 关掉菜单，断言音频簿记没有被重新点亮。

哨兵法的好处：任何「某块没被盖住」都变成一个确定的数字，不需要一张可遇不可求的原版对照图
（U-23 就是死在「缺原版同图同相机画面」上）。

**先红后绿（同一份冒烟，只切产品代码）**：

| 状态 | sfxChannelsStopped | liveSfxChannels | evaStopped | bottomStripLeak | wholeClientLeak |
|---|---|---|---|---|---|
| 修前 | no | 2 | no | **20224**（=632×32） | 20224 / 480000 |
| 修后 | yes | 0 | yes | **0** | **0** / 480000 |

`20224` 这个数不是估的：它就是 contentRect 少盖的那一条面积，和几何推导逐像素对上。

**关于声音判据的诚实边界**：冒烟注入的是「通道簿记正在播」（`runtimeSfxMciChannelActive` /
`runtimeEvaBusyUntilTick`），断言的是「打开菜单必须把它们清掉」这条规则。它**不声称**测到了
真实音频输出——设备侧出声由苹果音频底座自己负责，本机也无法在无人值守下收音。
要真验「听起来对不对」得人来听，这条留在人眼/人耳验收里。

---

## 四、回归与产物

- regress **18 条：16 PASS / 2 KNOWN-RED / 0 RED-NEW**（新增第 18 条 `menumodal`，0 秒）。
  两条 known-red（`command` 奴隶矿工段、`vehiclepass` M-25）文案与 R69 逐字相同；
  `menu` / `interaction` / `command` / `skirmishbuild` 全部维持原状态，没有引入 RED-NEW。
- 冒烟产物：`progress/regress/<stamp>/artifacts/menumodal/ingame_menu_800x600.bmp`——
  这张图是本项目**第一张「战斗内菜单」的可判读帧**（U-19/U-23 一直缺的正是世界帧，
  这条只解决了菜单态，世界态仍归 U-24）。
- dist 刷新见 §六。

---

## 五、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做什么**

- **没有验证「真的听不到战斗音效了」**。注入的是通道簿记，不是真实录音（见 §三边界）。
- 没有动音乐：BGM 在菜单里继续播是零售行为，不是缺陷。
- 没有做多显示器/高 DPI 下的哨兵判据扩展（冒烟固定 800×600）。
- 没有把这条门禁扩到「菜单子页」（设置/声音/键盘）——它们共用同一个叠加函数，风险低。

**遗留什么债**

1. **U-24 仍然要做**：本次只拿到「菜单态」的帧，世界态（有基地、有单位、有侧栏数据）依然零帧。
   U-19 的 HUD 对账仍被它挡着。
2. **边界情形没判**：`clientWidth < 800` 时菜单背景 `bkgdsm` 小于 contentRect，
   底色盖满整屏后那圈黑边是「菜单自己的边框」还是「没盖住」现在混在一起了，
   判据只看哨兵，看不出这一层——将来做小窗口适配时要重新给判据。
3. `runtimeMenuOpen` 在多人模式下**故意不暂停**（网络对局不能因为一个人开菜单就停），
   但本次的音频停止是挂在 `setRuntimeMenuOpen` 上的，**多人开菜单同样会把本地在播音效停掉**。
   这个行为没被验证过：它可能正确（本地听感更干净），也可能被玩家理解为「音效被吞」。
   已在本轮登记为遗留项，下轮遇到多人相关报障时先用它做第一嫌疑。

**放弃了什么**

- 放弃了「顺手把菜单子页也逐个截图入库」：判据相同、收益重复，只会让 artifacts 多几百 KB。
- 放弃了给 `menumodal` 加 known-red 兜底：它现在是硬绿，红了就是真坏了。

---

## 六、质量四数

| 指标 | 本轮 | 说明 |
|---|---|---|
| 净增行数 | **+193 / −1**（2 文件） | 其中 155 行是新冒烟文件、21 行是 env 分派样板、**产品代码只有 15 行** |
| 最大单文件行数 | `RuntimeShell.cpp` **90,672**（90,635 → +37）、`RuntimeMapRenderer.cpp` 42,542（未动）、`RuntimeSessionWorld.cpp` 31,056（未动） | +37 里 21 行是 `CONCORD_COMMAND_SMOKE_MENU_MODAL_ONLY` 的分派块（与既有 8 个 `*_ONLY` 分支同形态，留在原处比抽工厂更不容易漂开）；低于 `§五.3` 的 50 行说明线 |
| 新增断言 vs 新增产品代码 | **1 条门禁（4 个判据）vs 15 行产品** | 四条判据：整屏无残留 / 底部条带无残留 / SFX+EVA 被清 / 关掉不复活 |
| TODO/FIXME/临时探针 | **0 → 0** | 负向验证用的临时回退已还原，工作区干净（`git status` 空） |

**提交（源码仓库，均未 push）**

| hash | 一句话 |
|---|---|
| `5e28fcd` | fix: 战斗内 ESC 菜单真正接管画面与声音（模态性只做了一半） |
| `d01fb3b` | test: 模态菜单冒烟入库并接成 regress 第 18 条 |
