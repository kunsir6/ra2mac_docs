# ON 上屏工作计划（离屏验证 → 真窗口可玩）

> 起点：compat 面的能力缺口已清零（GDI 135/0 · Input 26/0 · ScreenDC 23/0 ·
> WindowCursor 14/0 · ChangeNotify 13/0 · Event 32/0 · Mapping 23/0 · Process 31/0），
> 遭遇战 shell smoke `EXIT=0`，队列 pending/blocked 均清零。
>
> 但现在所有判断依据都是**离屏像素（BMP）+ stderr 日志**。窗口是"顺带建出来的副产品"，
> 从来没有一条**用户视角**的验收。本计划就是补这一段。

---

## 一、先把"上屏"定义成可验收的四级

不分级的话"上屏"会变成一句口号——每个人心里的完成标准都不一样。

| 级别 | 判据（客观可查） | 当前 | 证据 |
|---|---|---|---|
| **L1 有窗口** | NSWindow 注册进窗口服务器、帧贴上 layer、进程常驻 | **达成** | `[cocoa] NSWindow created 1024x640 title=Command & Conquer: Yuri's Revenge visible=1` + `first frame attached` |
| **L2 自足启动** | 不带任何参数，在任意 cwd 启动都能进主菜单 | **未达成** | 不传 `--resource-root` 时 `shell.pal: palette resource not found` → 主菜单初始化失败 → 退出 |
| **L3 画面可信** | 屏幕上那幅画 = 渲染出来的那幅画（不是"贴上了"而是"贴对了"） | **未达成** | 只有 BMP 反推；无窗口侧像素证据（沙箱 `screencapture` 无权限） |
| **L4 可玩** | 真实鼠标键盘走完整链路进游戏内，画面持续刷新 | **部分** | `--interaction-smoke-test` 已进游戏世界（Players 1 / Waypoints 81），但卡 S14 像素契约 |
| **L5 可交付** | 双击 .app 即玩、可缩放/全屏、红叉真退出、性能达标 | **未达成** | 无 .app、`styleMask` 无 Resizable、`pumpEvents` 跳过 `AppKitDefined` 导致红叉只 orderOut |

**结论**：L1 已经成立了。真正挡路的是 L2（自足启动）和 L3（可信证据）——
这两个不解决，L4/L5 做得再多也无法向任何人证明"它真的上屏了"。

---

## 二、今天验证到的四条事实（含一次自我纠正）

### 事实 1：不带参数启动，主菜单起不来——根因不在资产，在路径解析

```
$ ./concord_runtime
[cocoa] NSWindow created 1024x640 title=Command & Conquer: Yuri's Revenge visible=1
Main menu palette load failed: shell.pal: palette resource not found: shell.pal
Main menu initialization failed: original shell assets are incomplete.
```

第一反应是"资产缺了"。查下去发现**资产不缺**：主菜单 smoke 全绿。

```
$ ./concord_runtime --resource-root ../ConcordRTS-GameData/RedAlert2 \
                    --local-data-root ../ConcordRTS-GameData/local_data \
                    --main-menu-ui-smoke-test /tmp/mm.bmp
Main menu smoke: 800x600 sideTopFrames=2 warningFrames=91 slotFrames=17
                 redButtonFrames=3 font=game.fnt lightGoldRamp=... rampPixels=1056,781,1428
EXIT=0
```

真正的根因在 `RuntimeConfigPaths.cpp`：

```cpp
bool isProjectRoot(const fs::path& path) {
    return pathExists(path / "local_data")
        && pathExists(path / "CMakeLists.txt")
        && (pathExists(path / "RedAlert2") || pathExists(path / ".git"));
}
```

这个判据假设**代码根与数据根是同一个目录**。实际布局是：

```
ra2mac/
├── ConcordRTS/            ← CMakeLists.txt + .git，但没有 local_data / RedAlert2
└── ConcordRTS-GameData/   ← local_data/ + RedAlert2/，但没有 CMakeLists.txt
```

两边都不满足条件 → `runtimeConfigProjectRoot` 回退到 `candidates.front()`（即 cwd）
→ `RedAlert2` 与 `local_data` 都解析到不存在的路径 → 主菜单拿不到 `shell.pal`。

**这是"离屏"最硬的根因**：默认启动路径根本找不到任何资产，只有显式传参（smoke 一直这么跑）
才能起来。所以过去所有"成功"都带着两根拐杖。

### 事实 2：带参数启动，主菜单真的活着

```
$ ./concord_runtime --resource-root ... --local-data-root ...
[cocoa] NSWindow created 1024x640 ...
Runtime menu host: sharedWindow=yes sameProcess=yes titleStable=yes
Main menu Bink animation unavailable: ... using the original extracted first frame.
$ kill -0 $pid   →  STILL ALIVE (7s)
```

窗口可见、进程常驻、等交互。不是闪退。

### 事实 3：遇到改错位置时会静默降级，不会报错

上面那条 `Bink animation unavailable` 就是降级：主菜单背景动画变成一张静帧。
这类"能跑但不对"的分支必须在上屏阶段显式记账，否则会被当成"正常"。

### 事实 4：游戏内已经跑起来过，卡在像素契约而不是呈现

```
$ cd ConcordRTS-GameData && ../ConcordRTS/build-product-mac/concord_runtime --interaction-smoke-test
Players: 1     Waypoints: 81     Cell bounds: 1,1 -> 181,181
Selected path batch: 300 overlapping/clipped/zero-length RGB cases and current points exact
Interaction smoke test failed: selected path raster: mixed sequence/current point differs at 0
```

游戏世界已经在跑（81 个路径点、181×181 格）。卡的是 `S14`：`Rectangle` 的 `PS_DOT`
被画成实线，与 `PolyPolyline` 的分量级描边不一致。这是**像素精确性**问题，不是上屏问题，
但它挡在游戏内验收的道上。

---

## 三、任务表

族 = 前缀。`ON-1` 收口即提交一次（见 `progress/queue.json` 的提交规则）。

### ON-1 自足启动（把拐杖抽掉）

| ID | 任务 | 验收 | 预估 |
|---|---|---|---|
| ON-1-01 | 数据根多级解析：显式参数 → `CONCORD_DATA_ROOT` 环境变量 → 兄弟目录扫描 → 逐级祖先扫描；判据改为「`local_data/` 与 `RedAlert2/` 同时存在」 | 在 `/tmp` 下执行绝对路径二进制，**不带任何参数**，日志出现 `menu host: sharedWindow=yes` 且 `sideTopFrames=2` | 45 min |
| ON-1-02 | 启动诊断：解析失败时打印「搜索过的路径列表 + 判定条件 + 缺哪个目录」，而不是一行 `palette not found` | 故意改名 `RedAlert2`，输出含 4 条候选路径与缺失项 | 30 min |
| ON-1-03 | `.app` bundle：Info.plist（`NSHighResolutionCapable`、`LSMinimumSystemVersion`、bundle id）、图标、`Resources` 挂数据根、ad-hoc `codesign` | `open ConcordRTS.app` 双击进主菜单，Dock 有图标 | 90 min |

### ON-2 呈现管线正式化

| ID | 任务 | 验收 | 预估 |
|---|---|---|---|
| ON-2-01 | 去掉每帧 `CGImageCreate`：按 surface 指针+尺寸缓存 `CGImage`，仅在指针/尺寸变化时重建；每帧只 `layer.contents` 赋值 | 计数器断言「1000 帧内 CGImage 创建 ≤ 2 次」 | 60 min |
| ON-2-02 | 刷新节奏：`CVDisplayLink` 或 1/60s 定时合并脏帧，避免"一帧贴多次"与"贴了但没合成" | 游戏内 30fps 时 present 调用数与帧数 1:1（±1） | 90 min |
| ON-2-03 | Retina 与缩放：`contentsScale` 跟随 `backingScaleFactor`、`styleMask` 加 `Resizable`、**任意拉伸铺满**（用户决策） | 2x 屏上 `contentsScale==2` 且无二次放大；把窗口拖到 1.7 倍后画面铺满、且不被 Q-12 的「上次呈现尺寸」掰回去 | 90 min |
| ON-2-04 | 窗口语义：红叉 → 投 `WM_CLOSE`→`WM_DESTROY`→退出；`Cmd+Q`；`Ctrl+Cmd+F` 全屏；最小化恢复保留内容 | 点红叉进程退出码 0；全屏进出后画面不丢 | 60 min |

### ON-3 上屏证据（没有截图权限时的替代方案）

| ID | 任务 | 验收 | 预估 |
|---|---|---|---|
| ON-3-01 | 窗口自证：`present` 后读回 `layer.contents` 的 CGImage 做 FNV hash，与同一帧 BMP 的 hash 比对；同时断言 `isVisible/isKeyWindow/backingScaleFactor/frame` | 5 个界面各一条 `presentHash == bmpHash` | 60 min |
| ON-3-02 | `--onscreen-capture <png>`：用 `CGWindowListCreateImage` 抓自己窗口（首次需用户授权屏幕录制一次） | 产出的 png 与 BMP 像素差 < 阈值 | 45 min |
| ON-3-03 | 人眼验收清单：30 秒操作剧本（菜单→单人→遭遇战→选图→开始）+ 每步期望现象，用户执行后回报 | 用户签字式回报"5 步全对/第 N 步不对" | 20 min |

### ON-4 游戏内上屏

| ID | 任务 | 验收 | 预估 |
|---|---|---|---|
| ON-4-01 | 清 S14：`Rectangle` 在 `pen.style != PS_SOLID` 时按 `PolyPolyline` 分量顺序改走 `strokeLine` | `--interaction-smoke-test` EXIT=0 | 60 min |
| ON-4-02 | 真实输入进游戏：合成 `WM_LBUTTONDOWN/UP` + 双击 + 右键，走消息队列进大厅、选图、开局（不直调内部函数） | 逐屏断言窗口尺寸/标题/像素特征，全程 EXIT=0 | 120 min |
| ON-4-03 | 游戏内帧循环：脏区 + 节流 + 连续帧差异断言（单位移动时相邻帧 hash 必不同） | 连续 60 帧至少 50 帧 hash 不同 | 90 min |
| ON-4-04 | 性能基线：菜单 / 大厅 / 游戏内三档的首帧时间、帧时间 P50/P95、峰值 RSS | 表格落 `progress/perf-onscreen.md`，游戏内 P95 < 16.7ms | 60 min |

### ON-5 稳定性

| ID | 任务 | 验收 | 预估 |
|---|---|---|---|
| ON-5-01 | 全链路进出：菜单→遭遇战→开局→返回菜单→退出，无泄漏无崩溃 | 三轮循环 RSS 不单调上涨；退出码 0 | 60 min |
| ON-5-02 | 30 分钟存活：主菜单挂机 + 游戏内挂机 | 无冻 UI、无 RSS 漂移 > 10% | 45 min |

---

## 四、为什么是这个顺序

1. **ON-1-01 排第一**，因为它把"必须带拐杖"变成"一条命令就能跑"。在此之前，
   任何"上屏成功"的说法都只是"我传对了参数"。而且它风险最低：Windows 上数据本来就在
   仓库内，多级探测不会触发。
2. **ON-3 紧跟其后**，不是因为难，而是因为它是**证据基础设施**。后面每一项都要靠它证明，
   越晚做，返工越多。
3. **ON-2 放在 ON-4 之前**：进游戏之前呈现管线必须先撑得住。每帧 `CGImageCreate`
   在菜单上无所谓（菜单只在交互时重绘），在游戏内 30~60fps 就是每秒几十 MB 的分配。
4. **ON-4 是价值兑现点**，但也是最大不确定区（S14 只是第一块石头）。
5. **ON-5 收尾**，因为它需要前面全部成立才有意义。

---

## 五、四点决策（已定，2026-11-11）

| # | 决策 | 结论 | 落地 |
|---|---|---|---|
| 1 | 主菜单 Bink 动画 | **保持首帧静帧**，不接解码器 | 已是现状（日志 `Bink animation unavailable`），记为已知降级 |
| 2 | 缩放策略 | **任意拉伸**（画面铺满窗口），不做整数倍 letterbox | `ON-2-03` 改为 `contentsGravity=Resize` 铺满；风险是像素会糊，可接受 |
| 3 | 全屏 | **只做窗口 + 系统全屏**，不做独占/改分辨率 | `ON-2-04` 范围收敛到 红叉退出 / Cmd+Q / Ctrl+Cmd+F / 最小化恢复 |
| 4 | 人眼验收 | **愿意跑一次 30 秒剧本** | `ON-3-03` 剧本已交付：`progress/ON-3-03-人眼验收剧本.md` |

---

## 六、与既有队列的关系

- `S14`（`Rectangle` 的 `PS_DOT` 描边）当前 `in_progress`，本计划把它吸收为 `ON-4-01`，
  内容不变、只是挂到正确的族下，避免它孤立地挡在游戏内验收门口。
- `Q-14`（Cooperative 数据缺失）仍 `blocked`，与本计划无关，不解除。
- 本计划不触碰 `if(WIN32)` 分支内部任何一行；所有改动走「新增函数 + APPLE 分支」或
  「平台无关的路径解析泛化」（后者在 Windows 上结果与原来一致）。

---

## 七、诚实边界

写在最前面，免得后面被当成"已完成"：

- **沙箱没有屏幕录制权限**，`screencapture` 拿不到像素。L3 在没有 ON-3-02/03 之前
  只能靠"present 调用发生了"来推断，不能靠"屏幕上确实显示了"来确认。
- **`.app` 的图标取自原版 YR 封面**（`packaging/icon-source.png`，256px）。它被
  `.gitignore` 的 `*.png` 规则排除，不进仓库；缺图标时打包脚本只警告不失败。
  对外分发前必须换成自有图标。
- 主菜单是**分多次局部绘制**的：`CONCORD_MENU_DUMP_FRAME=4` 抓到的是"背景已画、
  按钮未画"的中间态。取参照图必须用 `FRAME` ≥ 16，否则会误判成"按钮丢了"。
  这个坑本轮踩过一次（一度以为是 1024×640 布局缺陷）。
- 主菜单 Bink 动画、Cooperative 模式、中文版差异（`ra2.csf` vs `ra2md.csf`）都是
  **已知降级**，不在本计划的"完成"定义里。
- 本计划完成后，能说"在 Mac 上双击能进主菜单、能进遭遇战、能开局看到游戏画面"；
  不能说"和 Windows 版完全一致"——那需要逐界面像素对账，是另一个量级的工程。
