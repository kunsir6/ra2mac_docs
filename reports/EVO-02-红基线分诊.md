# EVO-02 红基线分诊：6 条 KNOWN-RED 逐条定性

日期：2026-11-11 傍晚
被测二进制：`build-product-arm/concord_runtime`，sha256 前 16 位 `124acc522ea08706`，mtime 16:55
判据来源：`progress/regress/20261111-171321/*.log` + 源码定位（本轮**未改任何代码**）

## 结论表

| 用例 | 定性 | 根因一句话 | 修它的层 | 用户可见 |
|---|---|---|---|---|
| build | **code-red** | compat 只实现 UTF-8，CP1252 请求直接返回 0，零售文本里的 `0x85`（省略号）被逐字节 widen 成 U+0085 | `compat/win32` 编码层 | 是：所有 CP1252 智能标点变控制字符 |
| command | **code-red**（共享模拟） | 两栖船靠岸后二次动作没有卸下坦克，`transportPassengerIds` 仍非空 | 共享模拟（`RuntimeAmphibiousTransportSmoke.inl:114` 暴露） | 是：船靠岸卸不了车 |
| render | **code-red（未定因）** | 地图有 10 个建筑，但建筑阴影一个都没画（`structures=0`），SHP 阴影正常 5 个 | 待定：相机可见性 或 建筑阴影美术解析 | 可能是：建筑脚下没有影子 |
| result | **code-red（未定因，平台相关）** | 暂停态第二次 WM_PAINT 复用了缓存帧，记分动画不前进 | `RuntimeShell.cpp` WM_PAINT 的 `reuseCachedFrame` 闸门 | 是：胜利/失败记分页静止 |
| interaction | **fixture-gap** | 地图建筑全是 Neutral，断言要找一个"己方"建筑做修理光标 | 测试夹具（注入 1 个己方建筑） | 否 |
| campaign | **env-gap** | 40 个任务里 13 个 `Map=` 为空；另有一批 Bink 视频缺失 | 资产准备，不是代码 | 否（战役内容不完整） |

四类定性：`code-red`（产品缺陷）/ `fixture-gap`（测试夹具缺口）/ `env-gap`（资产缺口）。

## 逐条证据

### 1. build：CP1252 未实现（证据链完整）

零售文本（`mix_exports/ra2/local/eva.ini`）：

```
[EVA_EstablishBattlefieldControl]
Text=Establishing battlefield control\x85standby.
```

断言（`RuntimeShell.cpp:2348`）要求这段文字 widen 后含 `U+2026`（…）且不含 `U+FFFD`。
实际链路：

1. `widenRuntimeSubtitleText` 先用 `CP_UTF8 + MB_ERR_INVALID_CHARS` 严格解码 → `0x85` 非法，返回 0；
2. 回落到 `1252`（注释明确说是为了 retail 的智能标点）；
3. `codePageSupported(1252)` **只认 UTF-8 / CP_ACP / CP_OEMCP** → `MultiByteToWideChar` 返回 0；
4. 回落分支 `std::wstring(value.begin(), value.end())` 逐字节 widen → `0x85` 变成 U+0085（控制字符），不是 `…`。

日志里有一条直接证据（每次进程只打一次）：

```
[compat/win32] MultiByteToWideChar: only UTF-8 is supported here (CP_ACP/CP_OEMCP map to UTF-8 on this platform)
```

这条最值得先修：不是"测不出来"的问题，而是**产品里所有 CP1252 智能标点（…、'、"、–）在 macOS 上都会变成控制字符**，
影响的正是玩家要读的字幕、提示和任务文本。

### 2. command：两栖卸载（纯合成夹具，与平台无关）

`RuntimeAmphibiousTransportSmoke.inl` 全程自建 32×32 地形 + 直接注入水面元数据，不依赖资源包、不建窗口；
连跑两次同点失败（`LCRF @30Hz`，移动到 `{23,16}` 后 `executeRuntimeSecondaryAction` 返回成功但船里还剩 4 辆坦克）。

日志里的 `Failed to open INI file: amphibious-transport-probe` 是**正常现象**：夹具用这个假地图名，
自己造地形，不读 INI。

因为这是共享模拟代码，修它会同时影响 Windows —— 动手前必须先确认"Windows 侧这条是不是绿的"。

### 3. render：建筑阴影全灭，但不能按"资产缺失"结案

```
candidates=7 drawn=5 pixels=2966 shp=5 voxel=0 voxelMasks=0 structures=0
```

断言要求 `shpShadowsDrawn > 0`（满足）且 `structureShadowsDrawn > 0`（为 0）。
默认地图 `2peaks.map` 实测有 **10 个建筑**（CAAIRP / CAMACH / CAOILD×4 / CABUNK02×2 / CABHUT×2，全 Neutral）。
所以"地图没建筑"不成立，是建筑阴影没画出来。两种可能未区分：

- 建筑不在视口/投影候选里（相机初始位置问题 → 夹具）
- 建筑在候选里但阴影帧解析失败（美术/剧场字母 → 产品）

需要一次只读计量：把 7 个候选的 art id 与阴影帧命中情况打出来，才能定性。

### 4. result：记分动画被缓存帧挡住（平台相关嫌疑）

断言处（`RuntimeShell.cpp:36672`）在**没有 tick、没有 repaint 请求**的情况下连画两帧，
要求记分区域至少 1000 个像素不同。两帧完全相同 → 走了 `reuseCachedFrame` 分支。

`reuseCachedFrame` 的闸门里有一行专门为这个场景写的例外：

```cpp
&& !runtimeResultScoreIsAnimated(*state)
```

而 `runtimeResultScoreIsAnimated` 要 `skirmishMatchFinished && campaignMode && !bannerVisible`。
该断言来自 2026-10-10 初始上传（Windows 侧历史应为绿），所以更可能是**平台相关**而非逻辑本身错。
未定因，下一步要么补计量（打印三个谓词与时间差），要么在 Windows 侧确认基线。

### 5. interaction：夹具里没有己方建筑

`RuntimeShell.cpp:38341` 起遍历投影对象，条件是 `kind == Structure && owner == state.economy.owner`。
日志前文已证明地图 10 个建筑全是 `Neutral`，所以 `repairCursorPoint` 永远为空。
RUNLOG 2026-11-11 已把这条记为"下一缺口"，现在确认定性为夹具缺口，与产品无关。

### 6. campaign：资产缺口，且其中一部分永远绿不了

40 个任务中 **13 个 `Map=` 为空**（gdi/all01、all03 等未抽取），另有系统性告警：

```
warning: ra2-nod/sov12: authored PostScore video is not in mounted resources
warning: ra2-tutorial/trn01: map has no authored Basic.Intro video
```

`movies/sources/audio=FAIL` 里既有"地图没抽出来"（可补资产），也有"Bink 视频不存在"（产品已决定不接解码器）。
结论：**这条 gate 在 macOS 上按现在的定义永远不会绿**，应当把它改成"已知资产缺口白名单 + 只对新缺口报错"，
而不是留着一条永远红的用例污染基线。本轮不改，记为结论。

## 对基线的影响

`known-red.tsv` 的 status 全部落定（不再有 triage-pending）：

- `env-gap`：campaign
- `fixture-gap`：interaction
- `code-red`：build、command
- `code-red + needs-metering`：render、result

其中 **build 一条是净赚**：修完 `build` 用例转绿，回归基线从 5 绿 6 红变成 6 绿 5 红，
而且修的是玩家能看见的文字乱码，不是测试口径。

## 下一步（已立为任务）

| id | 内容 | 依据 |
|---|---|---|
| EVO-08 | compat 实现 CP1252 解码（含 selftest），build 用例转绿 | 本轮证据链最完整、成本最低、用户可见 |
| EVO-09 | 两栖卸载：先取 Windows 基线，再决定是修模拟还是修夹具 | 共享代码，不能单边改 |
| EVO-10 | interaction 夹具注入 1 个己方建筑 | 纯夹具，10 分钟内可完 |
| EVO-11 | render 阴影只读计量（候选 art id + 阴影帧命中） | 未定因，先计量再动手 |
| EVO-12 | result 记分动画只读计量（三个谓词 + 时间差） | 未定因，先计量再动手 |
