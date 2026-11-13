# WIN-01 Windows 侧改动对账清单

统计窗口：2026-11-10 ~ 2026-11-13（106 个提交，分支 `main`，HEAD `94fbc71`）
生成时间：2026-11-13 10:01
用途：回答"这些天在 macOS 上做的修改，哪些会落到 Windows 版上"

## 一句话结论

**Windows 平台代码一行没动；但两平台共享的源码改了不少，Windows 重新编译就会带上这些行为变化。**
真正会让 Windows 玩家感觉到差异的是 6 条：游戏速度最快档、侧栏建造速度、就绪角标、FPS 层默认关闭、编队编号角标、被动索敌还手。

## 改动落点分布

按"文件被改动的次数"统计（一个提交改同一文件记 1 次）：

| 落点 | 次数 | 参与 Windows 编译 |
|---|---|---|
| `src/`（两平台共享） | 139 | 是 |
| `compat/win32/`（macOS 的 Win32 模拟层） | 115 | 否 |
| `cmake/`（构建脚本） | 24 | 部分（见注） |
| `tests/` | 19 | 是 |
| `cmake/Apple*.cmake`、`PlatformApple` 等 | 16 | 否 |
| `src/**/win32/`（真 Win32 实现） | 10 | 是（但本次未改语义） |
| `packaging/`（mac 打包） | 7 | 否 |
| `src/**/apple/` | 3 | 否 |

注：`cmake/CompilerAndPlatform.cmake` 是两平台共读的文件，但本期 5 次改动全部落在 `elseif(APPLE)` 分支内，Windows 的 `if(WIN32)` 链接清单与 `WIN32_EXECUTABLE` 属性未动。
`cmake/GameTargets.cmake`、`DevelopmentTargets.cmake`、`CoreTargets.cmake` 三个主清单自 11-10 起**零改动**。

---

## 表 1 对 Windows 生效的实质改动（21 条）

这些改动落在共享源码上，Windows 编译后行为会跟着变。

| 日期 | 提交 | 改动 | Windows 侧表现 |
|---|---|---|---|
| 11-10 | `0f11d9d` | 安全随机源、TCP_NODELAY、UI 时钟根因 | 随机源与 TCP_NODELAY 是共享链路，Windows 同样受益 |
| 11-10 | `8c18a3f` | 音乐策略 + 杂项符号接线 | 音乐选择策略同源，Windows 一致 |
| 11-10 | `a9cbd73` | D3D11 段落用 `#if defined(_WIN32)` 包裹 | 语义等价，只改了编译期边界；`#if` 内 Windows 代码原样保留 |
| 11-11 | `8d809dd` | Q-04 主菜单版本切换（RA2/YR 双源） | 主菜单多出版本切换入口；遭遇战 prewarm 缓存泄漏同步修掉 |
| 11-11 | `6ea8522` | 剧场字母单一表（候选序列 `[剧场字母, 通用 G]`） | 民用建筑不再错画雪地图，两平台绘制同源 |
| 11-11 | `a0d3a50` | 建筑温带=G、地表温带=T | 同上，贴图选择随之改变 |
| 11-11 | `4b7abc0` | 移除误入的无效头引用 | 构建修复，两平台都编不过的那次断链 |
| 11-11 | `15a2598` | CPU stamp 保留目标 alpha 字节 | 选中框/路径光栅的半透明像素更准 |
| 11-11 | `3cd18a9` | Q-07 菜单点击换页闭环 | 菜单导航走真实消息队列，点击换页生效 |
| 11-11 | `14c8ff3` | 路径规范化残留尾斜杠 | 资源路径解析，共享代码 |
| 11-12 | `ffdd7c5` | **速度表改七档有限阶梯**（6 档 = 5 档 ×1.5 = 281.25 拍/秒） | **最快档手感变**：不再"帧跑多快就多快"，七档严格单调 |
| 11-12 | `4acf858` | **侧栏生产乘数 16x/8x → 1** | **建造明显变慢**：兵营 0.43s→6.7s、矿场 1.7s→27s（速度 4 档） |
| 11-12 | `7afbc54` | 建造/防御就绪后顶部居中角标 | 新的 UI 元素，两平台都画 |
| 11-12 | `c1ccfe6` | FPS 叠加层默认关闭 | 默认不再画 FPS，需 `--show-fps` 或 `[Options] ShowFps=1` |
| 11-12 | `5ce280b` | 零售重复建筑 id 合并成一条 data-note | 启动解析日志变干净，不再逐条报异常 |
| 11-12 | `8e6b6e5` | 选中单位显示所属编队编号 | 选中时单位旁多一个数字角标（`drawRuntimeTeamNumberBadge`） |
| 11-12 | `a2b2c78` | 被动索敌不锁建筑 + 被打的空闲单位自动还手 | **战斗行为变**：纯仿真层（`RuntimeSessionCombat/World`） |
| 11-12 | `61858b3` | 潜航视觉下沉深度提为共享常量 | 无行为变化，纯重构 |
| 11-12 | `4a5cbe7` | idle overlay 补像素断言 + 下线旧选中框光栅 | 选中指示绘制路径变更 |
| 11-12 | `84288b6` | U-16：浮点 `from_chars` 换 `strtod`、对象身份改序号 | `strtod` 与序号是共享改动；部署目标本身只对 mac 生效 |
| 11-13 | `94fbc71` | 两栖登船加拒绝原因位 | 仅诊断输出，产品逻辑不变 |

---

## 表 2 共享层但只在冒烟/诊断里生效（22 条 test 类 + 7 条夹具修正）

这些也改 `src/`，但代码只被 `--xxx-smoke` 或契约测试调用，正常开局不走。代表项：

- `ffdd7c5` 之外的 10 余条 `test:` —— interaction/render/build/campaign/result 的断言拆分与计量
- `52bd380` / `0ce035a` / `c90ec0e` / `e1dede3` / `933d70c` / `cd2e841` / `32f154a` —— 冒烟夹具缺口补齐与临时探针移除（不是产品缺陷修复）
- `07e6a71` / `e7cbfa8` —— 框选断言改走 `CreateWindowExW` + `PostMessageW` 消息循环

> 注意：这些代码在 Windows 上同样参与编译，且部分目标带 `/W4 /WX`。功能不受影响，但**严格告警可能把新增代码里的未使用变量判成错误**，Windows 首次构建需留意。

---

## 表 3 Apple 专属（Windows 完全不参与编译）

`compat/win32` 是 macOS 上用 C++/Objective-C++ 重实现的 Win32 API，Windows 侧用真 SDK，这批文件在 `if(APPLE)` 分支才挂载。

| 系列 | 提交 | 内容 |
|---|---|---|
| U-01~U-03 | `9476d43` `6ef11de` `c4c3d42` `ef92802` | 消息泵（`pumpEvents`）、输入目标绑定、`acceptsFirstMouse` |
| U-04~U-05 | `a901d19` `89a1fc5` | 系统指针隐藏策略 |
| U-07 | `5c239f7` | `GetKeyState` 位布局（字节 bit7 vs SHORT bit15）修正 |
| U-09~U-11 | `b4014ca` `8839560` `3b297d3` | 全屏 `FullScreenPrimary`、指针出窗恢复、按需捕获 |
| U-14 | `3a6958c` | 全屏=更大视口（`ResizeSink`），`shared:1` 的那处也在 `apple::` 命名空间下 |
| ON-2 | `1e60afa` `501f1f2` `3cd43fb` `728f044` | 呈现抢位、首帧上屏、窗口缩放、红叉退出 |
| Q-05/Q-06 | `caf6931` `feb3438` `8ef6c4d` | NSWindow 首帧上屏、AppKit 事件 → `WM_*` 翻译 |
| S1~S12 | `f9f7c02` `6ff9b0d` `25dd8ee` `2dc2155` `0868aae` `d5e966e` `8ceb569` | 声明层、GDI/区域/图元/文件/进程/MCI、WM_TIMER、FSEvents |
| S8 | `9c412fb` | 两进程 smoke 的 19 符号兑现 |
| 其他 | `b2ee6fc` `760d44b` `549df79` `edfbcc3` | CP1252 解码、预定义窗口类、光标 smoke、菜单全链路 |
| 打包 | `ba08988` `36661f6` `955ff77` `93c99ff` | 圆角图标、`CFBundleIconFile`、图标源图、数据根多级探测 |
| 音频 | `1a2a8bb` `8157403` | XAudio2 混音、CoreAudio 后端（`src/audio/apple/`） |

---

## 表 4 Windows 平台自身（本期基本没动）

| 提交 | 内容 | 对 Windows 的影响 |
|---|---|---|
| `7fe00ce` | P1 平台轴接入 | 提交说明原文即"Windows 分支零改动" |
| `373a39a` | 7 个字体 TU 放回 Apple 构建图 | 方向是给 Apple 补清单，Windows 原本就有 |
| `a8bee2a` | MapNativeOverlay/BackBuffer/雷达/位图 leaf 放回 Apple | 从 D3D11 链拆到 `if(WIN32 OR APPLE)`，Windows 仍include |
| `0915980` | 菜单/渲染/输入 diagnostics 补声明 | 补 compat 头声明，真 SDK 本来就有 |
| `21ef54d` | ARM-02 全量构建恢复 | 改动在 APPLE 分支与测试目标 |
| `f128ac9` | T 宽字符运行期语义 | `AppleTextContracts.cmake`，Windows 不 include |

`src/**/win32/` 下 11-11 起的提交数为 **0**。

---

## 判定方法与局限

判定依据（可复现）：

```bash
# Windows 专属实现是否被改
git log --since=2026-11-11 --oneline -- 'src/**/win32/*'          # → 空

# 主构建图是否变化
git log --since=2026-11-10 --oneline -- cmake/GameTargets.cmake \
    cmake/DevelopmentTargets.cmake cmake/CoreTargets.cmake         # → 空

# 共享代码是否混入 Apple 符号
git log --since=2026-11-11 -p -- src | grep '^+' | grep -E 'apple::|NSApp|NSWindow'   # → 仅命中一行注释
```

**局限（必须说明）**：本机是 macOS，没有 MSVC 工具链，以上全部是静态判定，**没有一次真实的 Windows 编译**。
"不会破坏 Windows 构建"这个结论的可信度，止步于"没有引入平台专属符号、没有改动构建图"。
要确认，需在 Windows 机器上执行一次 `编译.cmd`（内部走 `tools/Build-Game.ps1`）。

---

## 附录统计口径

附录共 106 条，其中「是」71 条（改到了 `src/` 共享源码或 `src/**/win32/`）。这 71 条不要全部当成行为变化，按性质再分：

| 性质 | 条数 | 说明 |
|---|---|---|
| 表 1：实质行为改动 | 21 | 会改变 Windows 玩家看到/玩到的内容 |
| 表 2：诊断与夹具 | 22 | test 类，只在 `--xxx-smoke` 里跑 |
| 移植任务（U/ON/Q/S 系列） | 28 | 改了共享文件，但形式是加 `#if defined(_WIN32)`、补声明、提取常量，产品行为不变 |

「否」35 条为纯 Apple 交付物：`compat/win32` 实现、`PlatformApple` 系 cmake、mac 打包与图标。

---

## 附录 全量提交（106 条，按时间倒序）

标记：`共享`=src 共享源码；`Win32`=src/**/win32；`compat`=Apple 模拟层；`构建`=cmake；`打包`=packaging

| 日期 | 提交 | 主题 | 落点 | Windows |
|---|---|---|---|---|
| 11-13 | `94fbc71` | test: 两栖登船加拒绝原因位——把「转移没开始」拆成四道门与同格互锁 | 共享 | 是 |
| 11-12 | `3e51fd0` | test: 两栖冒烟按拍等待装船/卸载——两者都是逐人推进，不是一次点击全员 | 共享 | 是 |
| 11-12 | `e7cbfa8` | test: 框选补反向断言——被选中的单位画面矩形必须真进框 | 共享 | 是 |
| 11-12 | `07e6a71` | test: 框选断言改走消息循环，并把 bbox/中心两种口径分开计量 | 共享 | 是 |
| 11-12 | `b855223` | test: footprint 命中断言前先把样本建筑对焦进视口 | 共享 | 是 |
| 11-12 | `0b1f9e7` | test: 命中 spans 加四桶计量——把「没进光栅」与「进了但零可见像素」分开 | 共享 | 是 |
| 11-12 | `2d87e9c` | chore: 删掉「6 档返回 0 标识不限速」的过期注释 | 共享 | 是 |
| 11-12 | `0e72a10` | test: interaction 命中失配再补一层计量——命中像素在四层 spans 里的待遇 | 共享 | 是 |
| 11-12 | `bf5fd7c` | test: 矿喷发动画探针按「拍」推进，不再把 AnimationRate 当拍数用 | 共享 | 是 |
| 11-12 | `d69980d` | test: 两张速度表按 7 档有限阶梯改写——6 档是 281 拍/秒，不再是 0 哨兵 | 共享×2 | 是 |
| 11-12 | `ffdd7c5` | fix: 最快档不再是"零等待哨兵"，改为 5 档的 1.5 倍有限速率 | 共享×3 tests×3 | 是 |
| 11-12 | `8b14b61` | test: render 阴影门禁拆出「建筑自证帧」，不再要求 ore 探针帧看到建筑 | 共享 | 是 |
| 11-12 | `dd6eb31` | test: 阴影掩码返回值拆出离屏/裁剪两种结局，结构阴影从三桶改四桶 | 共享×3 | 是 |
| 11-12 | `5ce280b` | fix: 零售重复建筑 id 合并成一条 data-note，不再逐条报成解析异常 | 共享 | 是 |
| 11-12 | `4acf858` | fix: 侧栏生产乘数 16x/8x 回到 1，建造节奏对齐正版 | 共享×2 | 是 |
| 11-12 | `2cb8364` | test: 主菜单契约的 Host 补上 Q-04 新增的 reloadEditionResources 纯虚实现 | tests | 否 |
| 11-12 | `7afbc54` | feat: 建造/防御就绪后落一个顶部居中角标，并暴露结构建造 tick 实测 | 共享×6 | 是 |
| 11-12 | `c66d2f6` | test: 建筑阴影补三桶计量与只读追踪，M-18 仍是"掩码在但画不出" | 共享×3 | 是 |
| 11-12 | `06c8ea2` | test: render 阴影失配拆出结构候选/空掩码两个计数 | 共享×3 | 是 |
| 11-12 | `4cdc891` | test: result 记分动画探针按渲染所读的 uiClock 纪元取起点 | 共享 | 是 |
| 11-12 | `7f71e72` | test: result 记分动画失配拆四个子条件计量 | 共享 | 是 |
| 11-12 | `c90ec0e` | fix: 低电探针由夹具显式建立前置，不再依赖环境恰好低电 | 共享 | 是 |
| 11-12 | `52bd380` | fix: build 冒烟补己方兵营与战车工厂（夹具缺口，队列链路得以真跑） | 共享 | 是 |
| 11-12 | `64f2c95` | test: build 冒烟在目录不可排队时打印 catalog 构成与逐项原因 | 共享 | 是 |
| 11-12 | `799c9b6` | test: interaction 建筑 footprint 命中失配加逐对象计量 | 共享 | 是 |
| 11-12 | `d2f36b3` | test: 潜航单位选择框断言按 1/3 层级下沉计，不再按半格 | 共享 | 是 |
| 11-12 | `61858b3` | refactor(prep): 潜航视觉下沉深度提为共享常量，绘制与断言同源 | 共享×2 | 是 |
| 11-12 | `c1ccfe6` | fix: FPS 叠加层改为默认关闭（--show-fps / [Options] ShowFps 才画） | 共享×4 | 是 |
| 11-12 | `0ce035a` | fix: build 冒烟按需注入一台可悬停单位（夹具缺口，不再把空世界判成产品缺陷） | 共享 | 是 |
| 11-12 | `469cfa8` | test: 相机极值断言按物理边缘预留口径（边缘 cell 允许溢出 half-tile） | 共享 | 是 |
| 11-12 | `0e99bc1` | test: 建筑血条包围盒按冠顶斜边计算（旧断言用水平条公式，少算 2px） | 共享 | 是 |
| 11-12 | `e1dede3` | fix: interaction 夹具把一栋既有建筑改为己方所有，修理光标断言不再永久红 | 共享 | 是 |
| 11-12 | `933d70c` | fix: 音乐播放探针在无 MCI 后端时降级为资产断言（不再把 306 当产品缺陷） | 共享 | 是 |
| 11-12 | `cd2e841` | fix: campaign 覆盖门禁区分「结构缺陷」与「资产缺口」，不再把缺图/缺 Bink 判红 | 共享 | 是 |
| 11-12 | `b5df7a3` | test: 两个新冒烟的默认执行点移到 amphibious 已知红之前，保证全量 command 覆盖本轮断言 | 共享 | 是 |
| 11-12 | `b2ee6fc` | fix: compat 实现 CP1252 解码，零售 Text= 的智能标点不再变控制字符 | compat | 否 |
| 11-12 | `2df22e3` | test: 索敌策略与编队编号的行为断言 | 共享×2 | 是 |
| 11-12 | `8e6b6e5` | fix: 选中单位显示所属编队编号 | 共享 | 是 |
| 11-12 | `a2b2c78` | fix: 被动索敌不再锁定建筑 + 被打的空闲单位自动还手 | 共享×2 | 是 |
| 11-12 | `84288b6` | U-16 最低系统版本降到 12.0：浮点 from_chars 换 strtod + 对象身份改用序号 | 共享×3 | 是 |
| 11-12 | `32f154a` | EVO-16/17 收尾：移除临时敌军生成探针 | 共享 | 是 |
| 11-12 | `4a5cbe7` | U-15 选中指示与载矿条（补）：idle overlay 加像素断言，下线旧选中框光栅 | 共享×3 | 是 |
| 11-12 | `3a6958c` | U-14 全屏=更大视口：ResizeSink 把客户区交给游戏（单位 1:1、更多地图）+ 镜头居中 | 共享 compat×3 | 是 |
| 11-11 | `8d809dd` | Q-04 主菜单版本切换（RA2/YR 双源）+ 遭遇战 prewarm 版本缓存泄漏修复 | 共享×11 tests compat×2 | 是 |
| 11-11 | `3b297d3` | U-11 指针捕获（按需捕获）：⌃⌘G 抓住 / ⌃⌘ 放开 / 点回自动再抓 | compat | 否 |
| 11-11 | `8839560` | U-10 系统指针：移出窗口立刻恢复（[NSCursor set] 是全局的，不是区域限定） | compat | 否 |
| 11-11 | `b4014ca` | U-09 全屏：绿灯改 FullScreenPrimary + 自测点真绿灯 + 鼠标坐标按表面反算 | compat | 否 |
| 11-11 | `ba08988` | U-08 app 身份：封面图标做成 macOS 圆角（图标被 IconServices 采用 96.2/255） | 打包×3 | 否 |
| 11-11 | `5c239f7` | U-07 键状态表：Ctrl/Shift/Alt 全通（interaction 编队断言 1 条 + F1-F12 键码） | 共享 compat×5 | 是 |
| 11-11 | `d0fac3f` | U-06 侧栏指针消失：视口外回落标准箭头（interaction 新增 HUD 游标断言） | 共享 | 是 |
| 11-11 | `bd38300` | 清理调试期的临时代码：移除自测钩子与追踪日志，只留行为修复 | 共享 compat×3 | 是 |
| 11-11 | `89a1fc5` | U-05 指针策略定案：一律隐藏系统指针 + 两处兜底（不予采用 SetCursor 镜像） | compat×4 | 否 |
| 11-11 | `a901d19` | U-04 菜单里系统指针与游戏指针重叠：窗口区域内改用不可见光标 | compat×2 | 否 |
| 11-11 | `b1b394f` | autostart 自测：按钮还没布局好时重试，而不是第一次没找到就放弃 | 共享 | 是 |
| 11-11 | `ef92802` | U-03 续：窗口补 acceptsFirstMouse + acceptsMouseMovedEvents | compat | 否 |
| 11-11 | `c4c3d42` | U-03 进世界后点击无反应：输入目标只绑第一次，之后每跳都投给已退场的窗口 | compat | 否 |
| 11-11 | `6ef11de` | U-02 进世界后仍无响应：PeekMessageW 补 pumpEvents（世界循环与加载页都不走 GetMessageW） | compat | 否 |
| 11-11 | `35fa986` | ON-4-07(1/2) 交互 smoke 夹具补移动单位：框选与命令链首次真正被执行 | 共享 | 是 |
| 11-11 | `9476d43` | U-01 大厅不处理事件（彩虹圈）：MsgWaitForMultipleObjectsEx/WaitMessage 补 pumpEvents | 共享 compat | 是 |
| 11-11 | `14c8ff3` | 修两处真缺陷：路径规范化残留尾斜杠 / compat 变更通知不校验目录 | 共享 compat | 是 |
| 11-11 | `21ef54d` | ARM-02 全量构建恢复：1823 目标从不再失败（原卡在 [182/1823]） | tests×7 构建×4 | 否 |
| 11-11 | `3c3579f` | ON-4-06 tooltip 契约：把「前提不成立」与「真缺陷」分开（恒红断言转绿） | 共享 | 是 |
| 11-11 | `682c51e` | ON-4-02c(2/3) 大厅点 Start 发起开局：closing + 窗口退场 + 参数不丢（6 断言） | 共享 | 是 |
| 11-11 | `17e7af4` | ON-4-02c(1/3) 大厅选图往返走队列：Lobby→MapSelection→选图→回 Lobby（5 断言） | 共享×2 | 是 |
| 11-11 | `aa2965a` | ON-4-02b 大厅窗口的队列路径：PostMessageW 拖动滑块生效（3 断言） | 共享 | 是 |
| 11-11 | `157e78c` | ON-4-02a 真实点击驱动转场：主菜单→单人页→发起遭遇战（26 断言 EXIT=0） | 共享×2 | 是 |
| 11-11 | `2226103` | ON-4-05 projection history 契约：rubble 与 selling 分开断言（14 案例通过） | 共享 | 是 |
| 11-11 | `728f044` | ON-2-04 窗口关闭：红叉真退出（EXIT=0）+ 系统全屏显式禁用（无 willEnter） | compat×3 | 否 |
| 11-11 | `36661f6` | PKG-01 打包：Info.plist 的 CFBundleIconFile 跟随 app 名（双产物标识区分） | 打包 | 否 |
| 11-11 | `3cd43fb` | ON-2-03 窗口可缩放：Resizable 上线，1.7 倍验收通过（scale 2.0 / 内容未重采样） | compat | 否 |
| 11-11 | `1e60afa` | ON-2 呈现层：主人自身帧不再被抢位规则丢弃（提交 1→200/15s） | compat | 否 |
| 11-11 | `03b982d` | ON-3-01 上屏自证：layer 回读与同帧 DIB 逐像素对账（3 档 match=yes） | 共享 compat×2 | 是 |
| 11-11 | `15a2598` | S14b CPU stamp 保留目标 alpha 字节（240+720 契约用例转绿） | 共享×3 | 是 |
| 11-11 | `501f1f2` | ON-2-05 首帧上屏修复：空白首绘不得抢呈现位（客户区全黑 → 主菜单真上屏） | compat×2 | 否 |
| 11-11 | `955ff77` | ON-1 图标源图入库：packaging/icon-source.png（120 KB，此前被 .gitignore 的 *.png 吞掉） | 打包 other | 否 |
| 11-11 | `93c99ff` | ON-1 上屏自足启动：数据根多级探测 + .app 双击即玩（3 任务，Cmd+Q EXIT=0） | 共享×4 compat Apple-cmake 打包×2 | 是 |
| 11-11 | `0b75ff6` | S14 虚线矩形改走路径描边：批量契约 300 用例逐像素相同（断言 1/2 转绿） | 共享 compat | 是 |
| 11-11 | `fe90ab6` | S13 遭遇战 shell smoke 全绿：161 地图全预览（模态循环/呈现抢位/coop 双向契约） | 共享×2 compat | 是 |
| 11-11 | `8ceb569` | S12 目录变更通知族：FSEvents 后端（13 断言）+ 修掉退出期 mutex 崩溃与 pumpEvents 阻塞 | 共享 compat×7 Apple-cmake | 是 |
| 11-11 | `549df79` | Q 遭遇战第一层：窗口类光标 + 呈现窗口唯一化（cursor smoke 全绿，14 断言自测） | compat×3 Apple-cmake | 否 |
| 11-11 | `edfbcc3` | Q 菜单全链路面绿：屏幕 DC + WM_DESTROY 语义（smoke EXIT=0，含 skirmish 转场） | compat×4 Apple-cmake | 否 |
| 11-11 | `760d44b` | compat 预定义窗口类：STATIC 等 7 个系统类可直接创建（hosted shell 0x0 → 有效句柄） | compat | 否 |
| 11-11 | `3cd18a9` | Q-07 菜单点击换页闭环：真实消息队列驱动导航（48 断言 / 按钮列差异 13780） | 共享×2 | 是 |
| 11-11 | `8ef6c4d` | Q-06 补投递闭环自测：26 断言钉住 WM_* 翻译（坐标 16 位字/滚轮高位字） | compat Apple-cmake | 否 |
| 11-11 | `feb3438` | Q-06 输入接入：AppKit 事件 → WM_* 消息（菜单从"能看"到"能点"） | compat×4 | 否 |
| 11-11 | `caf6931` | Q-05 Cocoa 呈现层：NSWindow 1024x640 首帧上屏（屏幕上从无到有） | 构建 compat×3 Apple-cmake | 否 |
| 11-11 | `9c412fb` | S8 两进程 smoke 真跑通：19 符号兑现、三进程 120 tick（lifecycle checks=29） | 构建 compat×6 Apple-cmake | 否 |
| 11-11 | `6ea8522` | Q 剧场字母单一表：候选序列 [剧场字母, 通用 G]（首候选命中 149→242，民用建筑不再画雪地图） | 共享×4 | 是 |
| 11-11 | `f128ac9` | T 宽字符运行期语义：emoji 路径与文本不丢字符（23 断言，wchar_t=4） | tests 构建 Apple-cmake | 否 |
| 11-11 | `4b7abc0` | Q 剧场字符：移除 a0d3a50 误入的无效头引用（该头未入树，保留即构建断裂） | 共享 | 是 |
| 11-11 | `a0d3a50` | Q 剧场字符：建筑温带=G、地表温带=T（死探针 362→0，gg* 直命中 21） | 共享 | 是 |
| 11-11 | `d5e966e` | S11 WM_TIMER 真正派发：菜单恢复每秒探针（1s 59 条 / 自测 37 断言） | compat×7 Apple-cmake | 否 |
| 11-10 | `1a2a8bb` | P4 XAudio2 混音器：多条语音并行出声（混音 52/40 断言全绿，缺口 0→0） | tests×2 compat×2 Apple-cmake×2 | 否 |
| 11-10 | `8157403` | P4 CoreAudio 音频后端：产品首次链接并出声（缺口 8→0 / 累计 280→0） | tests×2 构建 compat Apple-cmake×2 apple-src×3 | 否 |
| 11-10 | `0868aae` | S4 GDI 文本族：窗口出字闭环（窗口自测 61/61 断言全绿） | tests compat×3 Apple-cmake | 否 |
| 11-10 | `8c18a3f` | P5 音乐策略+杂项接线：5 符号清零（缺口 13→8） | 共享 构建 | 是 |
| 11-10 | `a9cbd73` | P5 D3D11 presenter 不被引用：15 符号编译出（缺口 28→13） | 共享×3 Win32 | 是 |
| 11-10 | `25dd8ee` | S6 GDI+ PNG 导出：7 符号兑现（缺口 35→28） | compat×2 Apple-cmake | 否 |
| 11-10 | `2dc2155` | S7 窗口/消息/输入后端：纯离屏兑现 74 符号（缺口 109→35） | compat×3 Apple-cmake | 否 |
| 11-10 | `0915980` | P5/T 平台对位：菜单/渲染/输入 diagnostics 补声明 | 共享×19 Win32 | 是 |
| 11-10 | `373a39a` | P5-06 字体族：7 字体 TU 放回 Apple 构建图（缺口 138→109） | Win32×6 构建×6 Apple-cmake | 是 |
| 11-10 | `a8bee2a` | P5 平台对位：MapNativeOverlay/BackBuffer/雷达/位图 leaf 放回 Apple | Win32 构建×6 | 是 |
| 11-10 | `6ff9b0d` | S2-S10 兼容层实现：GDI/区域/图元/文件/进程/MCI/CRT（缺口 280→109） | compat×18 | 否 |
| 11-10 | `f9f7c02` | S1 兼容层头层：Win32 声明层落地（37→30 TU 可编译） | compat×10 | 否 |
| 11-10 | `0f11d9d` | P2 消除失败 TU：安全随机源 + TCP_NODELAY + UI 时钟 + RuntimeShell 根因（失败 TU 12→1） | 共享×4 Win32 tests | 是 |
| 11-10 | `7fe00ce` | P1 平台轴接入：多平台骨架成立（Windows 分支零改动） | 构建 Apple-cmake | 否 |

合计 106 条；其中改到两平台产品源码（`共享` 或 `Win32`）71 条，其余 35 条只碰 Apple 模拟层、构建脚本或打包。

注：`tests` / `构建` 列虽然也会进入 Windows 构建，但多数属于 Apple 侧新增的目标与清单调整，未计入上表的「是」。
