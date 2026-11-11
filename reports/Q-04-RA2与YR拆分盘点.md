# Q-04 RA2 与 YR 拆分盘点（做"两个游戏"的可行性）

问题：引擎当前混跑两代数据，能否把红色警戒2（RA2）与尤里的复仇（YR）分开引用，做成两个游戏？
结论先行：**数据层天然分开，战役/音频/国家列表已支持双源；拦路虎集中在 6 个生产代码硬编码点 + 一批 stock fallback 默认值。方案 A（单引擎 + gameMode 开关）比方案 B（两个独立包）工程量小一个量级。**

---

## 一、数据层：天然两层，无需重排

`mix_exports/` 下的层目录本身就是按代际切的，且 `RuntimeShell.cpp` 的资产层优先级（见《RA2资源切分报告》3.3）已经是 YR 覆盖 RA2 的顺序：

| 层 | 体积 | 归属 |
|---|---:|---|
| `ra2/` | 549M | RA2 基础数据（ra2.mix 展开 + 内层归档） |
| `ra2md/` | 394M | YR 主数据 |
| `expandmd01/` | 5M | YR 资料片补丁 |
| `langmd/` `thememd/` `multimd/` `mapsmd03/` | 316M | YR 语言/音乐/地图 |
| `language/` `theme/` `multi/` `maps01/` `maps02/` `expand01/` | 127M | RA2 语言/音乐/地图 |
| `wdt/` `ecache01/` | 8M | 两代共用杂项 |

**拆包体积估算**：RA2 独立包 ≈ 700M（ra2 549 + language 101 + theme 73 等减去共享缓存）；YR 独立包 ≈ 900M（ra2md 394 + langmd 162 + thememd 89 + multimd 67 + mapsmd03 + expandmd01，若保留 RA2 音频回退再 +174M）。

## 二、rules INI 差异量化（`ra2/local/rules.ini` vs `ra2md/localmd/rulesmd.ini`）

| 指标 | 值 |
|---|---|
| YR 段数 | 1418（唯一） |
| RA2 段数 | 1141 |
| 共同段 | 1136 |
| **YR-only 段** | **282** |
| RA2-only 段 | 5（CAARMR / CABUNK01 / CAHOSP / MULTISPECIAL / VEINS） |

YR-only 类型（按 YR rules 的类型列表过滤）：

| 列表 | YR-only |
|---|---|
| 步兵 22 | YURIPR / YENGINEER / GGI / INIT / BORIS / BRUTE / VIRUS / CLNT / ARND / STLN / CAML / EINS / MUMY / RMNV / LUNR / DNOA / DNOB / SLAV / WWLF / YDOG / YADOG / PTROOP |
| 载具 25 | SMIN(奴隶矿车) / YHVR / PCV / SMON / YCAB / YTNK / BFRT / TELE / CAOS / DDBX / BCAB / BSUB / SCHP / SCHD / MIND(心灵主宰) / UTNK / ROBO / DOLY / CBLC / FTRK / AMBU / CIVP / JEEP / DNOA / DNOB |
| 建筑 100 | 约 2/3 是 CA* 城市装饰/战役专用（CASANF15 等），真正阵营科技约 20 段（YACNST / YAWEAP / YAREFN / YAPPET / NATBNK / NABNKR / YACOMD…） |
| 超武 6 | 基因突变 / 心灵支配 / 侦察机 / 力场盾 / 心灵侦测 / NUKESPECIAL 改良 |
| 飞行器 3 | BPLN / SPYP / CMISL(巡航导弹) |

全局段差异：`[General]` YR 多 108 键（CHRONO*/CMISL*/BARREL* 动画 ID、AI 抓捕、奴隶矿车数量等）；`[AI]` 多 8 键（THIRDBASEDEFENSES 等）；`[CombatDamage]` 多 24 键；`[Sides]` 多 `ThirdSide=YuriCountry`（YR 7 方 vs RA2 6 方）；`[Countries]` 索引因 Yuri 插入而右移（GDI: 10 vs 9）。

## 三、引擎切换点盘点（生产代码，不含 diagnostics）

### 3.1 已就绪的双源支持

| 层 | 证据 |
|---|---|
| 战役库 | `CampaignDatabase.cpp` L1900-1931：`yrSpec`（battlemd.ini/ra2md.csf）与 `ra2Spec`（battle.ini/ra2.csf，ID 加 `ra2-` 前缀）**并排加载** |
| 战役 INI | `RuntimeCampaignDataSource.cpp` L445：`yr ? "rulesmd.ini" : "rules.ini"` |
| 音频 | `AudioSampleResolver.cpp`：sourceId `ra2`→audio.mix/ra2.csf/LANGUAGE，`yr`→audiomd.mix/ra2md.csf/langmd，互斥过滤 |
| 国家列表 | `RuntimeSkirmishMenu.cpp` / `RulesDatabase::loadCountries`：**动态读 rules 的 [Countries]**，换规则文件即自动换阵营 |
| 侧边栏 | `RuntimeShell.cpp` L17143：`sidec02md.mix` 是**覆盖**语义（尤里侧栏盖苏军侧栏），RA2 模式不命中即用原版 |

### 3.2 硬编码 YR 的切换点（方案 A 要动的全部清单）

| # | 位置 | 内容 | 改法 |
|---|---|---|---|
| 1 | `RuntimeShell.cpp` L49473-78 | 主规则路径候选写死 `local_data/rulesmd.ini` | 按 gameMode 换成 `rules.ini`（RA2 顶层需由 prepare 脚本多拷一份） |
| 2 | `RuntimeShell.cpp` L17022-97 | 资产层固定挂 `ra2md/localmd` + `ra2md` | 模式化：RA2 挂 `ra2/local` + `ra2` |
| 3 | `RuntimeShell.cpp` L86465 / L17447 / L17177 | `loadmd.mix`（加载画面）/ `conqmd.mix` / `ntrlmd.mix` | RA2 对应 `load.mix` / `conquer.mix`（已在 ra2 层）|
| 4 | `RuntimeShell.cpp` L18567-72 | `dialogn.pal` / `dialogy.pal` / `mpyscrn.pal` 取自 ra2md/localmd | RA2 用 ra2/local 的同名/对应调色板 |
| 5 | `RuntimeSessionScenario.cpp` | 合作战役 `coopcampmd.ini`（YR-only 文件） | RA2 无此文件，需容错跳过（或用 coopcamp.ini） |
| 6 | `RuntimeRandomMap.cpp` | 随机地图 `rmgmd.ini` | RA2 用 `rmg.ini`（ra2 层），需加候选 |
| 7 | `RuntimeCountryLoadingRender.inl` | 载入画面写死 `{yuri, Name:YuriCountry, YURIPR, yrii}` | 按规则里国家是否存在过滤 |
| 8 | `RuntimeSessionProduction.cpp` | `isoubn.pal`（城市夜晚调色板） | 从 ra2md 层改按地图所在层解析 |

非生产代码（diagnostics `.inl` 里大量 `YuriCountry`/`ra2md` 路径）**不需要动**——smoke 固定用 YR 规则跑，两模式并存时仍有效。

### 3.3 stock fallback 默认值（风险点，不是切换点）

`RulesDatabase.cpp` 的默认值带着 YR 内容，RA2 规则缺段时的行为需逐一验证：

- L2711：AI `BuildRefinery` 默认 `"NAREFN,GAREFN,YAREFN"` —— RA2 无 YAREFN 段，需确认 AI 对不存在类型的容错；
- L1581：基因突变产物写死 `"BRUTE"` —— RA2 规则下该超武不存在，不触发，安全；
- L1782：`sidePrefixes{"Ally","Sov","Yuri"}` 读 ParaDrop 键 —— RA2 缺 `YuriParaDropInf` → 空串，需确认空值不炸。

## 四、结论与建议

1. **可行，且比想象中近**：战役、音频、国家、侧边栏四大块已经双源就绪；真正要动的生产代码是上表 8 处，集中在 `RuntimeShell.cpp`（其 89k 行里约占 6 处）。
2. **推荐方案 A**：加 `gameMode = ra2 | yr` 配置（runtime_config.ini），8 处切换点全部收敛到一个 `GameMode` 枚举。RA2 模式的战役（missions.ini 列表）与遭遇战（RA2 阵营自动来自 rules.ini 的 [Countries]）随之生效。
3. **风险排序**：
   - 中：模拟层 stock fallback（3.3 三条）需跑 RA2 规则的全量 smoke 验证；
   - 中：RA2 地图（.map/.mmx）用的剧场归档在 ra2 层（isotemp/isosnow…），地图渲染层的剧场解析要确认不带 md 后缀回退（诊断代码里已有 `{"ra2md","ra2"}` 双目录尝试，生产层需对齐）；
   - 低：RA2-only 的 5 个段（VEINS 等）当前 YR 模式本来就没有，引擎已证明容忍缺段。
4. **数据包侧**：prepare-game-assets.py 需为 RA2 模式多导出 `local_data/rules.ini`、`art.ini`（当前只拷 rulesmd/artmd），并确认 `ra2/local/` 目录完整落地（rules.ini/art.ini/theme.ini 已在 ra2 层）。

## 五、RA2 规则实测（2026-11-11 追加）

用 `build-product-arm/concord_rules_dump` 对 `ra2/local/rules.ini`（RA2-only 资源根 /tmp/ra2-only-root）实跑：

| 测试 | 结果 |
|---|---|
| `--summary` 规则解析 | ✅ 步兵45/载具55/飞行器8/建筑296/武器138，**0 错误** |
| `--validate` 引用诊断 | ✅ 0 errors / 12 warnings（YR 基线 0/13，同一量级；均为列表悬空项与缺 Verses 的弹头） |
| `--economy-sandbox` | ✅ MCV 展开→电厂→矿厂→矿车运矿 3 趟，目标达成 |
| `--combat-sandbox`（MTNK vs APOC） | ✅ 武器/伤害/击毁链路正常 |
| `--ai-trigger-sandbox` | ✅ AI 经济→编队→进攻→胜利判定全链路 |
| `--tech-tree-report` | ✅ RA2 单位树（CARRIER/SHAD/SREF/MGTK/ZEP…）prereq/side 解析正确 |
| RA2 地图（从 MULTI.MIX 抽 MP02T2.MAP）`--map-summary` + `--pathfinding-sandbox` | ✅ 寻路沙盒全绿 |
| RA2-only 根 `--engine-status` | Rules **Ready**；Asset 计数 0 是"松散文件计数"口径（资源在 MIX 内属预期），非行为测试 |

**关键发现：运行时 INI 链已经完全双源**。`RuntimeSessionFeedback` 的 sound/EVA 走 `resolveRuntimeIniSource(config, RuntimeCampaignIniKind::Sound/Eva)`，而 `runtimeCampaignIniFileName` 对 rules/art/ai/sound/eva 五类全部按 sourceId 切换（yr→soundmd.ini，ra2→sound.ini）。**游戏会话侧 RA2 模式的音频/规则无需改代码。**

### 残留缺口（3 个，均可低成本关闭）

1. **CLI 侧 sound/eva 候选缺 ra2**：`analysis/cli/main.cpp` 的 `findSoundIniForEngineStatus`/`findEvaIniForEngineStatus` 候选链没有 `ra2/local/sound.ini`、`ra2/local/eva.ini`（只影响 `--engine-status`/`--audio-report` 报告，不影响游戏会话）；
2. **`AudioCatalog::firstExistingThemeIniPath` 缺 `ra2/local/theme.ini`** 候选（同样只影响 CLI 报告；真正的运行时音乐解析器 `AudioSampleResolver` 已有 `root/"ra2"/"local"/"theme.ini"`）；
3. **遭遇战地图列表只扫散目录**（`RuntimeSkirmishMapResources.cpp` 用 `fs::directory_iterator`，不进 MIX）：RA2 官方遭遇战图在 `MULTI.MIX`（97 张，名字形如 `MP02T2`）。但 `ra2/local/missions.pkt` 的 `[MultiMaps]` 段**完整枚举了所有地图名**——prepare 脚本按名单抽取为散文件即可关闭。

### 结论

**RA2 模式可行性验证通过。** 规则层、模拟层（经济/战斗/AI/寻路）、运行时 INI 双源链全部就绪；3 个残留缺口都是 CLI 报告口径或数据打包问题，动引擎的只有 Q-04 第三节那 8 处 gameMode 切换点。安装器方案的"只勾 RA2"场景在数据侧已经成立。

## 七、不拆包如何运行两代（2026-11-11 追加：运行方式盘点）

前提：单一资源包（ra2/ 与 ra2md/ 层共存），在入口处选 edition。**已有机制比预想更完整**：

### 7.1 已就绪的 edition 开关

- **配置键已存在**：`runtime_config.ini` 的 `[Campaign] SourceId=ra2|yr`（`RuntimeConfig.cpp` L465）。空值 = 默认 yr 优先、ra2 兜底（`editionOrder` 返回 `{yr, ra2}`）。
- **会话 INI 链全双源**：`runtimeCampaignIniFileName` 对 Rules/Art/Ai/Sound/Eva 五类按 sourceId 切文件名；会话内的 rules/art（`RuntimeSessionWorld` L30511）、sound/EVA（`RuntimeSessionFeedback`）、战斗/AI 全部经 `resolveRuntimeIniSource` → `config.campaignSourceId`。
- **战役菜单已 edition 感知**：`CampaignDatabase` 并排加载两代战役（RA2 带 `ra2-` 前缀），菜单按 `campaign->sourceId` 选呈现资源与音频。

### 7.2 端到端实测（RA2 战役链路）

从 `ra2/local.mix` 抽 `MISSION.INI`（101 张战役图名单）→ 从 `ra2/Maps01.mix` 抽 `SOV01T.MAP`（苏军第一关，URBAN 剧场）→ RA2 规则下 `--map-summary` ✅、`--pathfinding-sandbox` ✅、`--victory-sandbox` ✅（BadGuy1/Player 等战役 house 解析正确）。**RA2 战役的地图/规则/house 链路在引擎里全部成立。**

### 7.3 运行两代的最小改动清单

| # | 改动 | 性质 |
|---|---|---|
| 1 | 遭遇战菜单 `RuntimeSkirmishMenu.cpp` 的 rulesPath 候选只有 rulesmd.ini（local_data / expandmd01 / localUiRoot 三处），无 rules.ini、无 sourceId——接上 `config.campaignSourceId` 并补 `rules.ini` 候选 | **唯一必须动的生产代码**（一处） |
| 2 | 主菜单加"游戏版本"入口（或两个启动入口），把 edition 写入 `[Campaign] SourceId` | UI/入口 |
| 3 | 菜单/加载画面素材按 edition 选（YR: bkgdlgy/loadmd.mix；RA2: bkgdlg/load.mix） | 素材选择 |
| 4 | prepare 脚本按 `missions.pkt [MultiMaps]` 名单抽 RA2 遭遇战图散文件（名字 MP02T2 等，97 张） | 数据侧 |

### 7.4 运行形态建议（不拆包）

```
红色警戒2 尤里的复仇.app          ← 现状即 YR 模式（默认）
    └─ 主菜单「新战役」里已可选 RA2 战役（ra2- 前缀条目）
    └─ 加一个「版本：尤里的复仇 / 红色警戒2」切换（写 SourceId）
        ├─ 遭遇战：按 SourceId 选 rules.ini/rulesmd.ini → 国家列表自动变（无尤里）
        └─ 战役：现有 ra2-/yr 双列表
```

即：**"运行红色警戒2"不是装另一份游戏，而是同一引擎 + 同一资源包，把 edition 从 yr 切到 ra2**。切换后的世界：RA2 规则、无尤里阵营的国家列表、RA2 战役、RA2 音频/音乐（audio.mix/theme.mix）。

## 八、版本切换改造落地（2026-11-11 22:25）

首页新增「版本」按钮（红警2/尤里的复仇二选一切换），点击即完成：写回 `config.campaignSourceId` → 重解析全部版本敏感菜单资源 → 当前页音乐立即切换 → 持久化到 `runtime_config.ini`。

### 代码改动

| 文件 | 改动 |
|---|---|
| `runtime/menu/RuntimeMainMenuController.h/.cpp` | 新增 `MenuAction::CycleEdition`、`cycleEdition()`、`editionButtonLabel()`、`RuntimeMainMenuServices::reloadEditionResources()`；Home 页按钮表加 slot 5 |
| `ui/main_menu/RuntimeMainMenu.cpp` | 抽出 `applyEditionResources()`：csf/credits/rules 配色/静态兜底图/sound.ini/themeCatalog/三主题路径单点重解析；`MenuAudio::initialize` 清缓存；smoke 契约改为 edition 感知 |
| `ui/skirmish/RuntimeSkirmishMenu.cpp` | csf、missions.pkt、rules（国家列表）、sound.ini 四处按 `campaignSourceId` 选源 |
| `assets/audio/AudioSampleResolver.cpp` | `themeMixPathCandidates` 补 `<root>/theme/THEME.MIX`（RA2 原声带位置） |

### 主题解析的关键修正

音乐池合并两代 catalog（ra2md/thememd.ini 先扫），按段名（INTRO）查轨会永远命中 YR 的 `INTRO|Drok`。修正：按 **edition 专属 soundName** 查找——RA2 用 `Grinder`/`RA2-Sco`/`Ra2-Opt`（来自 `ra2/local/theme.ini`），YR 用 `Drok`/`ScoreX`/`OptionX`。RA2 音轨从 `theme/THEME.MIX`（16 个散 WAV，含 RA2-SCO.WAV/RA2-OPT.WAV）解出并缓存。

### 字体约束

菜单位图字体（game.fnt）只覆盖 Big5 繁体字形——简体「红/复」与 ASCII 无字形渲染为 □。按钮文案定稿：**「版本：紅色警戒」/「版本：尤里的復仇」**。

### 验证

- `SourceId=ra2` 模式：menu smoke rc=0，RA2 文本表（單人遊戲/選項…）、版本按钮、静态背景图（`ra2/glsl.shp`，已从 ra2/local.mix 抽取）全部正确；遭遇战转场正常（rules→rules.ini，国家列表自动无尤里）。
- `SourceId=yr` 模式：menu smoke rc=0，行为与改造前一致。
- 全量回归：5 PASS + 6 KNOWN-RED（与基线一致），0 RED-NEW。

### 补遗：RA2 遭遇战地图接入（同日 22:27）

- 按 `ra2/local/missions.pkt` 名单从 `MULTI.MIX` 抽出 **87 张官方遭遇战图**散文件到 `mix_exports/multi/`（pkt 中其余 50 段是战役图 C*M*，不在 MULTI.MIX，也不进遭遇战列表）；
- `RuntimeSkirmishMenu` 地图扫描改为 edition 感知：RA2 模式扫 `multi/` + RA2 missions.pkt，YR 模式行为不变（`multimd/` + missionsmd.pkt）；
- 实测：RA2 模式遭遇战 smoke `maps=87 allPreviews=87` 全过（含 AI/阵营/预览）；YR 模式 `maps=161` 不变；全量回归仍为基线。

### 补遗二：加载画面双源接入（同日 22:58）

**遗留①排除**：主菜单背景 Bink（`ra2ts_l.bik`）是两代共用的零售前影片（候选链已含 `lang/`），RA2 模式无需处理；smoke 显示的 `video=static-fallback` 是 headless 行为，两模式一致。

**遗留③关闭**：破译 RA2 `load.mix`（83 条目）：
- 遭遇战加载屏 `ls800<country>.shp` ×9（ustates/russia/libya/iraq/germany/france/korea/cuba/ukingdom，无 yuri——RA2 无尤里国家）；
- 战役加载屏 `ls800a01-a12`（盟军）/`ls800s01-s12`（苏军）；
- palette 5 个：`mplsobs.pal`（观察者）、`ldscrna.pal`/`ldscrns.pal`（战役盟/苏）、**遭遇战 9 国共用 `mpls.pal`，且不在 load.mix 而在 `ra2/cache.mix`**（modding 社区资料交叉验证 + WID 命中）。

实现（`RuntimeShell::prepareRuntimeLoadingMaterial`）：RA2 模式 SHP 读 `ra2/load.mix`，palette 除 obs 外统一从 `ra2/cache.mix` 读 `mpls.pal`；YR 行为不变。loading smoke 输出增加 `source=` 字段。实测：RA2 `source=ra2/load.mix!ls800ustates.shp`、YR `source=ra2md/loadmd.mix!ls800ustates.shp`，均 `original=yes`。全量回归=基线。

**遗留（更新）**：遭遇战菜单 smoke 里的加载画面预览仍用 YR 素材（cosmetic，玩家实际看到的加载画面已正确）；版本按钮图标化、RA2 官方 Bink 背景仍待素材。

### 补遗三：遭遇战菜单版本缓存泄漏——RA2 模式出现重装大兵（同日 23:40）

**现象**：切到红警模式后，遭遇战里仍出现尤里复仇专属单位「重装大兵」（GGI；该单位只在 `rulesmd.ini`，RA2 `rules.ini` 无此段）。

**排查**：逐环节验证会话 rules 装载链均 edition 感知且正确——`resolveRuntimeRulesPath`→`resolveRuntimeIniSource`→`resolveRuntimeCampaignIniSource`；`editionOrder` 显式 `ra2` 时只返回 `{"ra2"}`（无 yr 回退）；loose 候选按 mod→localData→resourceRoot 顺序命中 `mix_exports/ra2/local/rules.ini`（磁盘实存）。rules 层无泄漏。

**根因**：遭遇战菜单的 **prewarm 状态复用判定不含 edition**。主菜单一打开就后台预热遭遇战状态（`prewarmRuntimeSkirmishMenu(config)`，此时 config 还是旧版本）；`runtimeSkirmishMenuReady` 复用缓存时只比较 `resourceRootPath`/`localDataRootPath`，`prewarmRuntimeSkirmishMenu` 的复用条件只看 `resourceWatch->unchanged(config)`——而版本切换**不改动任何被监视文件**，`localInputs` 监视清单（rulesmd.ini 等 4 个）也全是 YR 侧文件名。于是切换后首次进入遭遇战，直接拿到旧版本预热的 MenuState：国家列表/地图/单位全来自旧版 rules（GGI 泄漏）。

**修复**（`RuntimeSkirmishMenu.cpp`）：两处复用判定都加入 `campaignSourceId`（lowerAscii 归一化）比较：
- `prewarmRuntimeSkirmishMenu`：缓存 sourceId 与请求 sourceId 不同则丢弃重建；
- `runtimeSkirmishMenuReady`：复用前提加 sourceId 相等。不匹配的**在途预热任务**在 ready 后会被 ready 轮询判 false，自然触发重建（多等一次重建，正确性优先）。

**回归保护**：`RuntimeSkirmishPreloadSmoke.inl` 新增 edition 重建断言段——4 次同版本复用验证后，翻转 `campaignSourceId` 再预热，断言「缓存对象被替换、初始化成功、sourceId 与请求一致」（输出 `editionRebuilt=1`）。主菜单侧复用（`prewarmedMainMenuState`）不受影响：其 config 经 `publishMenuConfig` 与关闭时状态一致。

**验证**：RA2/YR 双模式 skirmish smoke rc=0（RA2 maps=87、YR maps=161），各连跑多次稳定；全量回归=基线（5 PASS + 6 KNOWN-RED，0 RED-NEW）；dist `.app` 已用 pack-dist.sh 重新装配（含修复二进制）。

