# FIX-03 回归门禁口径三连（campaign / build / interaction）

2026-11-12 第 2 轮。三个问题同一性质：**把「平台或资产缺口」当成「产品缺陷」判红**，
导致三条回归永久红、失去信号价值。同一批改动、一次构建、一次回归。

基线（本轮开工）：`PASS=5 KNOWN-RED=6 RED-NEW=0`
收口（本轮结束）：`PASS=6 KNOWN-RED=5 RED-NEW=0`，零新回归。

---

## 一、campaign：覆盖门禁区分「结构缺陷」与「资产缺口」（cd2e841，S-05）

### 现象
```
Campaign retail coverage gate: maps=40 objectives=27 events/actions/scripts/movies/sources/audio=FAIL
```
40 个任务里 37 个 FAIL，且 stderr 里 `unsupportedEvents=[] unsupportedActions=[] unsupportedScripts=[]`
全空、`error={}` 一条都没有——也就是说「事件/动作/脚本覆盖」这条门禁真正想守的东西**全部通过**，
红是别的原因。

### 根因
`runCampaignDatabaseSmokeTest` 的 `missionPassed` 是单条与链，把四类互不相同的判据压成了一个布尔：

| 判据 | 性质 | 本机实际 |
|---|---|---|
| `mapPath` 非空 | 资产 | 13 个任务的地图文件不在发行版里 → 为空 |
| `mission.available` | 派生自地图是否加载 | 上述 13 个必然 false |
| `victory/defeatActionCount > 0` 且可达 | 内容完整性 | 上述 13 个为 0/0（没有地图就没有 Triggers 可读） |
| 触发视频已在挂载资源内 | 资产（且播放器未实现） | 24 个任务的 Bink 缺失 → `UNRESOLVED` |
| 不支持的事件/动作/脚本、coverageErrors、edition 源 | **结构缺陷** | 0 |

另外顶部的 `availableMissionCount() == 40` 直接写死 40，等于要求「13 张缺失的战役图必须存在」。

### 改法
把单条与链拆成三级：

1. **结构缺陷**（判红）：`unsupportedEventTypes / ActionTypes / TeamScriptActionTypes` 非空、
   `coverageErrors` 非空、`edition` 源不可用。
2. **资产缺口**（只计数）：`mapPath` 为空（`mapAssetGapMissions`）、目录里有索引但文件不在挂载资源内
   （`movieAssetGapMissions`）。
3. **内容完整性**（只在有地图时判）：有地图的任务必须 win/lose 各至少一条可达 action。

配套三条约束，保证「不判红」不等于「不看」：

- `objectiveMissions == auditedMissions - mapAssetGapMissions`——有地图的任务条条要有完整 objective chain，
  少一条就红（这条是原门禁真正有价值的信号，保留为硬约束）。
- `availableMissionCount() == missionCount() - mapAssetGapMissions`——多一个少一个都说明有任务
  既没地图又没被登记成缺口，或反之被静默算成可用。
- 视频索引**在目录里查不到**仍然判红（那是元数据缺陷）；查到但文件不在，才算资产缺口。

判定行改为自带对账：
```
Campaign retail coverage gate: maps=40 objectives=27/27 available=27/27 structuralFailures=0
  map-asset-gaps=13 movie-asset-gaps=24 events/actions/scripts/sources/audio=PASS env-gap=ACCOUNTED
```

### 结果
`campaign` 由 KNOWN-RED 转 **PASS**，本轮唯一清零的已知红。同时把 27/27、0 结构缺陷这两个数字
变成每次回归都会打印的硬数字——覆盖退化会立刻显形，而不是被 37 条资产缺口噪声掩埋。

---

## 二、build：音乐探针在无 MCI 后端时降级（933d70c，M-08）

### 现象
```
Build smoke test failed: real music playback probe:
  Allied=Deceiver:member=yes:mci=error-306:no  Soviet=Tension:member=yes:mci=error-306:no
```

### 根因
`validateRuntimeMusicPlayback` 用 `mciSendStringW(L"status concord_runtime_music mode")` 回 `playing`
作为「真的在出声」的判据。macOS 没有 MCI 后端，compat 层**如实**返回 `MCIERR_DEVICE_NOT_INSTALLED(306)`
（这是刻意设计：假装成功会让调用方以为音乐在播，见 `RuntimeWin32CompatMisc.cpp` 的注释）。
所以这条探针在 macOS 上永远不可能绿——它测的是平台缺口，不是产品行为。

### 改法
按后端是否存在分两路，**不删断言**：

- 后端缺失（`statusError == MCIERR_DEVICE_NOT_INSTALLED`）：要求
  `runtimeMusicStarted && !runtimeMusicPath.empty() && belongsToFaction`（选曲、落盘路径、阵营归属），
  `mci` 一栏改报 `skipped(no MCI backend)`。
  「后端缺失必须报 306、不许假成功」这条反向断言仍然隐含在分支条件里——如果哪天 compat 层
  改成返回 0，探针会掉进 `playing` 分支、因 `mode` 不是 `playing` 而失败。
- 有后端（Windows）：口径完全不变，必须 `playing`。

### 结果
```
Real music playback probe: Allied=Deceiver:member=yes:mci=skipped(no MCI backend):yes
  Soviet=Tension:member=yes:mci=skipped(no MCI backend):yes
```
探针过后**暴露下一个阻塞点**（登记为 M-09）：
```
Build smoke test failed: structure health bar did not span the raised selection edge or infinite health was visible.
  edge=no actual=61x33 expected=61x31 segments=14/14 infiniteHidden=yes
```

---

## 三、interaction：夹具把一栋既有建筑改为己方所有（e1dede3，S-04）

### 现象
```
Interaction smoke test failed: no owned structure for repair cursor.
```

### 根因
修理光标断言遍历投影对象，要求 `kind == Structure && owner == state.economy.owner`
（`runtimeCursorObjectAtPoint` 还要能命中它）。而 interaction 夹具用的 `2peaks.map` 十栋建筑
全部是 Neutral——夹具里根本没有己方建筑，这条断言在这个夹具上不可能成立。

### 改法
在既有的夹具注入块里（已在五条像素/投影契约之后、`buildProjectedObjects` 之前）加一段：
把**最后一栋** Structure 的 `owner` 改成 `economy.owner`。

选「改既有建筑」而不是「合成新建筑」：art / rules / footprint 全部来自真实地图，
投影与命中测试一定成立；合成建筑要自己编 footprint，命中测试随时可能不认。
选**最后一栋**而不是第一栋：`visibleObjectIds.front()` 是后续选中/hover 断言的夹具对象，
不能动它的归属。

### 结果
修理光标链路整段转绿（日志里 `Context cursors: ... repair=yes`），探针过后**暴露下一个阻塞点**
（登记为 M-10）：
```
Interaction smoke test failed: one of 8 clamped camera extremes exposed edge-connected renderer void:
  S=142/142@0/4260->428/640 tile=398/625..458/655:no ...
```
八个钳制极值里只有 **S** 这一向裸露（把地表映射到表面后，南侧最下一行 tile 没画到）。

---

## 四、批内移出与本批边界

- 本批三条都只改**探针/夹具口径**，未动任何产品行为分支，因此不涉及呈现层/输入链路架构，
  不违反「复杂问题单独成轮」的约定。
- build 与 interaction 两条**修完仍红**，但红的原因换成了更靠后的真实阻塞（M-09 / M-10）。
  这不是「修了没用」，而是原先前置失败把后面的断言整段屏蔽了——记录在案，下一轮从新位置接手。
- 未在本批硬啃：M-09（健康条比选择框高 2px）与 M-10（南向极值裸露）都需要先读选择框/相机钳制的
  几何口径才能判断「是实现错还是断言公式错」，属中等问题，不塞进本批。

## 五、验证

| 项 | 结果 |
|---|---|
| 构建 | `ninja -C build-product-arm concord_runtime` 全绿（仅 `u8path` 弃用警告） |
| 签名 | `codesign -s - --force` 已执行（否则卡 U 状态） |
| 回归 | `PASS=6 KNOWN-RED=5 RED-NEW=0`，共 11 条，产物 `progress/regress/20261112-020518` |
| 新增 RED-NEW | 0 |
