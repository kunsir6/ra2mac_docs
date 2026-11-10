# RA2/ → ConcordRTS 资源切分报告

分析对象：`RA2/`（从 Windows 可运行的红警2 + 尤里的复仇游戏目录整份拷贝）
产出：`ConcordRTS-GameData/`（独立资源包，1.5 GB / 554 文件）
配套脚本：`scripts/prepare-game-assets.py`

---

## 一、先说结论

**RA2 里 96% 的体积是 MIX 归档，而 ConcordRTS 一个都不从原目录读。**

它只读 `local_data/resources/mix_exports/`。所以「把 RA2 拷到工程里」并不成立——必须按引擎的层目录重新摆放，并把被代码以真实路径引用的内层归档拆出来。

三句话概括这次切分：

1. **15 个数据归档 / 785 MB 保留** → 按 `<stem>/<stem>.mix` 放进 `mix_exports/`，引擎递归索引后按文件名哈希直接命中条目；
2. **7 个内层归档 / 150 MB 单独拆出** → `local.mix`、`localmd.mix`、`sidec0*.mix`、`audio.mix`、`audiomd.mix`，因为代码要求它们是真实文件路径；
3. **约 68 MB 直接丢** → Windows 可执行、存档、安装器、说明书、缩略图缓存，引擎完全不碰。

一个反直觉的点：**内层归档拆出来是对的，哪怕它和父归档重复**。比如 `isotemp.mix` 既在 `ra2.mix` 里、又落在 `mix_exports/ra2/isotemp.mix`。引擎的 MIX 索引**不递归进 MIX 内部**，只扫磁盘上的 `.mix` 文件，所以不拆出来，地形 tile 就一条都读不到。后面第五节有实测证据。

---

## 二、源目录构成

| 类别 | 文件数 | 体积 | 处置 |
|---|---:|---:|---|
| MIX 归档（游戏数据） | 15 | 785.3 MB | ✅ 全收 |
| MIX 归档（过场动画） | 3 | 1006.9 MB | ⬜ 默认不收（`--with-movies` 可选） |
| 散装地图 `.mmx` / `.yro` | 59 | 9.8 MB | ✅ 全收 |
| 叫嚣语音 `Taunts/*.WAV` | 80 | 2.2 MB | ✅ 全收 |
| 存档 `.sav` / `.sed` | 32 | 38.6 MB | ❌ 用户进度，引擎不读 |
| Windows 可执行 `.exe` / `.dll` / `.sys` / `.tlb` / `.lcf` | 23 | 14.1 MB | ❌ 平台无关 |
| 其它二进制 `.dat` / `.key` / `.img` / `.016` / `.256` | 11 | 11.0 MB | ❌ 序列号、注册、补丁元数据 |
| `RMCACHE/*.MMP` | 90 | 3.0 MB | ❌ 地图缩略图缓存 |
| 文档 / 安装器 `.doc` / `.htm` / `.wsu` / `.lnk` | 23 | 1.0 MB | ❌ |
| 位图 / 图标 | 28 | 0.7 MB | ⬜ 仅取启动图 |
| `.csf` 语言文件 | 2 | 0.6 MB | ✅ 从归档里另抽一份 |
| `.ini` 玩家配置 | 7 | ~0 MB | ❌ 引擎用自己的 `runtime_config.ini` |
| **合计** | **375** | **1872.9 MB** | |

被丢掉的 Windows 侧文件举例：`gamemd.exe`、`YURI.exe`、`Ra2.exe`、`BINKW32.DLL`、`ddraw.dll`、`Blowfish.dll`、`SECDRV.SYS`、`Ra2.tlb`、`Woldata.key`、`Conquer.dat`、`00000409.016`、`RegSetup.exe`、`必须先注册.exe`、`红色警戒2.lnk`、`Readme.doc`、`WIN10运行红警2的方法/`、`Uninstall/`、`HTML/`。

---

## 三、ConcordRTS 的资源约定

### 3.1 两个根

启动参数（见 `启动.cmd`）：

```
concord_runtime --config local_data/runtime_config.ini \
                --resource-root RedAlert2 \
                --local-data-root local_data
```

- `--resource-root` → `RedAlert2/`：原游戏目录，**只用到极少数散文件**
- `--local-data-root` → `local_data/`：真正的资源根是它下面的 `resources/mix_exports/`

### 3.2 散文件优先，MIX 兜底

`MapPreviewExporter.cpp` 里的 `buildOverlayFileIndex` + `buildMixArchiveIndex` 构成两级解析：

```
候选散文件（递归索引 mix_exports 下所有文件，按小写文件名建表）
   ↓ 未命中
候选 MIX 条目（递归索引 mix_exports 下所有 .mix，按文件名 32 位哈希建表）
```

这就是为什么「把 MIX 原样放进 mix_exports」就能直接工作——不需要先全量解包。

### 3.3 层优先级（`RuntimeShell.cpp` 原文顺序）

```
modRoot
  > ra2md/localmd      ← 尤里的复仇本地覆盖
  > language           ← 红警2 语言包
  > langmd             ← 尤里语言包
  > expandmd02
  > expandmd01         ← 资料片补丁
  > ra2md              ← 尤里基础数据
  > ra2                ← 红警2 基础数据
  > mix_exports 根
```

**这条顺序决定了不需要在打包时纠结「哪个版本赢」**——把每个文件放回它自己的层目录，运行时由引擎按序挑。

### 3.4 代码里写死的路径（打包必须满足）

| 代码引用 | 期望落位 | 说明 |
|---|---|---|
| `runtimeSidebarMixPath` | `ra2/sidec01.mix`、`ra2/sidec02.mix` | 侧边栏图形 |
| `runtimeYuriSidebarOverrideMixPath` | `ra2md/sidec02md.mix` | 尤里侧边栏覆盖 |
| `CampaignDatabase` | `ra2/Maps01.mix`、`ra2/Maps02.mix` | 战役地图归档（顶层文件改名的别名） |
| `RuntimeCampaignDataSource` | `ra2/local.mix`、`ra2/local/` | 红警2 规则集 |
| `RuntimeCampaignMovieResolver` | `ra2md/movmd03.mix` | 尤里过场动画 |
| 主菜单初始化 | `local_data/rulesmd.ini` → `expandmd01/rulesmd.ini` → `RedAlert2/GameMD/rulesmd.ini` | 三级回退，第一个必须有 |
| 主菜单字体 | `RedAlert2/GameMD/game.fnt` 或 `Game/` | **只认散文件**，没有 MIX 回退 |
| 主菜单 CSF | `RedAlert2/GameMD/ra2md.csf` → `langmd/` → `lang/` | |
| 主题目录 | `RedAlert2/GameMD/thememd.ini` → `ra2md/localmd/thememd.ini` | |
| 叫嚣语音 | `RedAlert2/Taunts/` 或 `RedAlert2/GameMD/Taunts/` | |

---

## 四、归档 → 用途映射

| 源归档 | 体积 | 内容 | 落位 |
|---|---:|---|---|
| `ra2.mix` | 268.8 MB | 红警2 主数据（含内层地形/侧栏/规则归档） | `ra2/` |
| `ra2md.mix` | 195.1 MB | 尤里主数据 | `ra2md/` |
| `langmd.mix` | 80.7 MB | 尤里语言包：`ra2md.csf`、`game.fnt`、`keyboardmd.ini`、`missionsmd.pkt`、`audiomd.mix` | `langmd/` |
| `THEME.MIX` | 73.3 MB | 红警2 音乐 | `theme/` |
| `LANGUAGE.MIX` | 50.5 MB | 红警2 语言包 + `audio.mix` | `language/` |
| `thememd.mix` | 44.7 MB | 尤里音乐 | `thememd/` |
| `multimd.mix` | 29.8 MB | 尤里遭遇战官方地图 | `multimd/` |
| `MULTI.MIX` | 17.8 MB | 红警2 多人地图 | `multi/` |
| `WDT.MIX` | 5.9 MB | 天气/环境特效 | `wdt/` |
| `expandmd01.mix` | 4.6 MB | 尤里资料片补丁（战役地图、对话面板） | `expandmd01/` |
| `mapsmd03.mix` | 4.2 MB | 尤里战役地图 | `mapsmd03/` |
| `MAPS01.MIX` | 3.6 MB | 盟军战役地图 | `maps01/` + 别名 `ra2/Maps01.mix` |
| `MAPS02.MIX` | 3.0 MB | 苏军战役地图 | `maps02/` + 别名 `ra2/Maps02.mix` |
| `Ecache01.mix` | 2.2 MB | 缓存数据 | `ecache01/` |
| `expand01.mix` | 1.0 MB | 红警2 资料片补丁 | `expand01/` |
| ~~`movies01.mix`~~ | 340.9 MB | 过场动画 | 默认不收 |
| ~~`movies02.mix`~~ | 290.1 MB | 过场动画 | 默认不收 |
| ~~`movmd03.mix`~~ | 375.9 MB | 尤里过场动画 | 默认不收 |

### 必须拆出来的内层归档

| 内层归档 | 父归档 | 体积 | 为什么必须拆 |
|---|---|---:|---|
| `local.mix` | `ra2.mix` | 33.2 MB | 红警2 规则集 + **`game.fnt` 的唯一来源** |
| `localmd.mix` | `ra2md.mix` | 4.8 MB | `rulesmd.ini` / `artmd.ini` / `soundmd.ini` / `evamd.ini` / `thememd.ini` /  theaters |
| `sidec01.mix` | `ra2.mix` | 2.1 MB | 盟军侧边栏 |
| `sidec02.mix` | `ra2.mix` | 2.1 MB | 苏军侧边栏 |
| `sidec02md.mix` | `ra2md.mix` | 1.8 MB | 尤里侧边栏覆盖 |
| `audio.mix` | `LANGUAGE.MIX` | 35.7 MB | 红警2 音效库 |
| `audiomd.mix` | `langmd.mix` | 71.1 MB | 尤里音效库 |

---

## 五、产出与验证

### 5.1 目录结构

```
ConcordRTS-GameData/                      1.5 GB / 554 文件
├── RedAlert2/                            4.1 MB
│   ├── GameMD/
│   │   ├── game.fnt                      1.5 MB   位图字体
│   │   ├── ra2md.csf                     325 KB   尤里文本
│   │   └── thememd.ini                   2.7 KB   音乐目录
│   └── Taunts/                           80 个    叫嚣语音
├── local_data/
│   ├── runtime_config.ini
│   ├── rulesmd.ini                       725 KB
│   ├── artmd.ini                         329 KB
│   └── resources/mix_exports/
│       ├── ra2/           86 文件        553 MB
│       ├── ra2md/        108 文件        407 MB
│       ├── langmd/        10 文件        177 MB
│       ├── language/       8 文件        102 MB
│       ├── thememd/       11 文件         90 MB
│       ├── theme/          1 文件         80 MB
│       ├── multimd/      221 文件         69 MB   161 张官方地图 + 43 .mmx + 16 .yro
│       ├── multi/          1 文件         18 MB
│       ├── wdt/            1 文件        6.1 MB
│       ├── expandmd01/    15 文件        5.7 MB
│       ├── mapsmd03/       1 文件        5.1 MB
│       ├── maps01/         1 文件        4.1 MB
│       ├── maps02/         1 文件        3.1 MB
│       ├── ecache01/       1 文件        3.1 MB
│       └── expand01/       1 文件        1.1 MB
└── MANIFEST.json                         469 项 / 0 警告
```

清单构成（按来源）：

| 来源 | 项数 | 体积 |
|---|---:|---:|
| 顶层归档原样保留 | 15 | 785.3 MB |
| 内层归档拆出 | 7 | 150.3 MB |
| 按名提取的散文件 | 382 | 525.6 MB |
| 源目录直接拷贝 | 62 | 12.1 MB |
| 资源根散文件 | 3 | 1.8 MB |

散文件里 63 个是 `.mix`（48 个内层归档，含各地形 `isodes.mix` / `isotemp.mix` / `isosnow.mix` / `isourb.mix` / `isoubn.mix` / `isolun.mix` / `neutral.mix` / `load.mix` 等），162 个 `.map`，71 个 `.pcx`，53 个 `.shp`，25 个 `.ini`，12 个 `.pal`。

### 5.2 实测验证

用项目自带的 `concord_rules_dump` 直接对着资源包跑，四项全通：

**① 规则解析**（`--rules local_data/rulesmd.ini --summary`）

```
Infantry types:    65      Weapon types:      205
Vehicle types:     79      Projectile types:  40
Aircraft types:    11      Warhead types:     116
Building types:   399      Warnings:            7
```

**② 地图解析**（`--map multimd/2peaks.map --map-summary`）

```
Theater: TEMPERATE     Size: 0,0,80,102      Start points: 2
Iso tiles: 16218       Overlay: 409          Waypoints: 81
```

**③ 地形表解析**（`--map-tile-report`）

```
TileSets: 82    Tile slots: 838    Map iso tiles: 16218
Unique tileIndex: 213              Unresolved tiles: 0
```

**④ 从 MIX 索引真解出 tile**（`--extract-map-tiles`，决定性证据）

```
extracted Rmpfx08.tem  local_data/resources/mix_exports/ra2/isotemp.mix
...
Summary: Extracted 213 / Not found 0 / Failed 0
```

213 个地形块全部从 `ra2/isotemp.mix` 命中，**0 缺失 0 失败**。这条证明了第 4 节「内层归档必须拆」的判断是对的——不拆 `isotemp.mix` 出来，这 213 个 tile 一个都读不到。

---

## 六、怎么用

```bash
cd ConcordRTS-GameData

# 规则/地图/资源查询类命令
../ConcordRTS/build-product-mac/concord_rules_dump \
  --rules local_data/rulesmd.ini --summary

# 若要跑 concord_runtime（macOS 侧窗口后端尚未实现，见 P2/P3）
../ConcordRTS/build-product-mac/concord_runtime \
  --config local_data/runtime_config.ini \
  --resource-root RedAlert2 \
  --local-data-root local_data
```

重新生成（换个源目录或要带动画）：

```bash
python3 scripts/prepare-game-assets.py \
  --source RA2 \
  --out ConcordRTS-GameData \
  --dump ConcordRTS/build-product-mac/concord_rules_dump \
  --repo ConcordRTS \
  [--with-movies]
```

脚本是幂等的，可以反复跑；提取一律走「临时文件 + 原子改名」，不会先删后写。

---

## 七、还没覆盖的部分

| 缺口 | 影响 | 补法 |
|---|---|---|
| **过场动画** | 战役过场黑屏 | `--with-movies`（+1.0 GB），或预转码 MP4 绕开 Bink |
| **单位 / 建筑美术** | 战局里模型、步兵图缺失 | 需按 `artmd.ini` 的段名派生 `.vxl` / `.hva` / `.shp`（约 1000+ 名字）再批量提取 |
| **图标 / 侧栏按钮图案** | 部分 UI 元素缺图 | 已抽到源码字面量覆盖的 53 个 `.shp`，其余靠 MIX 索引兜底 |
| **音乐轨命名** | 10 条已抽，`BrainFreeze` 等少数未命中 | `thememd.ini` 的 `Sound=` 与归档内实际名不完全一致，需逐条核对 |

为什么不做全量解包：MIX 只存文件名哈希、不存名字，**无法枚举**。现在的策略是「按代码字面量 + 资源清单反查哈希」，覆盖了引擎实际请求的名字；剩下的是靠 MIX 索引在运行时按 ID 现查，不缺数据、只是不是散文件。

---

## 八、一句话备忘

RA2 那份 1.8 GB 里，**引擎真正能吃的只有 MIX 归档本身**；把它们按层摆进 `mix_exports/`、再把 7 个内层归档拆成真文件，剩下的交给运行时索引——这样 1.5 GB 就够跑通规则、地图、地形、音效，不用重写任何解包逻辑。
