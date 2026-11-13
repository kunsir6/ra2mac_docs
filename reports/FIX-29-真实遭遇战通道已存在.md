# FIX-29 真实遭遇战的取证通道一直存在，缺的是「模式规则读不到」

**轮型：诊断/重排轮**（第 28 轮，2026-11-13）。触发依据：§七.1「根因假设被实测推翻」——
M-13 登记的根因是「macOS 上 skip 只能起真窗口，**没有会话状态出口就无法验收**」，本轮实测该前提不成立。

- 回归：`10/1/0` → `10/1/0`（`20261113-220040`），产品代码零改动，源码仓库零提交。
- 主题一句话：**入口、状态出口、断言都在，只是被一道自己会失败的闸挡在后面；那道闸失败的原因是数据层读不到模式规则。**

---

## 1. M-13 的旧前提被推翻：三样东西都已经存在

| 旧前提 | 实测 |
|---|---|
| 「`--skip-skirmish-menu` 是唯一进图入口，只能起真窗口」 | 另有 `--skirmish-build-smoke-test`（`RuntimeMain.cpp:305/997`），**无窗口**直接构造真遭遇战 |
| 「没有会话状态出口」 | 该冒烟自己就打印 `Skirmish start: <status> owner= credits= objects=`（`RuntimeShell.cpp:77753-77761`），并断言 `skirmishStartApplied` + 有己方工厂 + 有己方 `GACNST`（`:77764-77769`） |
| 「skip 不构造 playerSlots，所以没有真遭遇战」 | `runRuntimeSkirmishBuildSmokeTest` 在 `playerSlots` 为空时**自己补**「人 vs 电脑」两席位（`:77638-77660`），随后 `initializeRuntimeSkirmishStart` + 显式展开 MCV（`:77690-77695`） |

即：**U-19/U-20/U-22 需要的那条通道早就写好了，只是从没被任何人跑过**——它不在 `regress.sh` 的 11 条里。

## 2. 为什么没人跑它：它一跑就红，而且红在一个 30 谓词的门上

```
$ concord_runtime --skirmish-build-smoke-test      # 数据根 ConcordRTS-GameData
Skirmish build smoke failed: option semantics
  modeRules=no alliesAllowed=no mustAlly=no ownerFactory=no unholy=no
  megawealth=no startingPools=yes duelStart=no megawealthStart=no modStart=yes
  difficulty=yes crates=yes …(crate 族 14 项全 yes)… freeMCV=yes shortGame=yes
  mcvRepacks=yes superweapons=yes
```

读数本身就是一条强证据：**凡「需要读盘上的模式规则」的全 `no`，凡「不读盘」的全 `yes`**
（`startingPools` 用 stock rules、`modStart` 用 `loadFromString` 内存段、crate 族与难度项不依赖模式文件）。

## 3. 根因：模式规则只认松散文件，而它们只存在于 MIX 归档里

- `loadAndApplyRuntimeSkirmishModeRules`（`RuntimeSessionScenario.cpp:1320`）→
  `resolveRuntimeModeRulesOverridePath`（`RuntimeSessionNavigation.cpp:161`）。
- 后者只看 5 个**松散路径**（`mix_exports/expandmd01/…`、`mix_exports/ra2md/localmd/…` …），
  全部 `std::filesystem::is_regular_file`；找不到就返回空串 → `skirmishModeRulesLoaded=false`。
- 实际数据层 `find . -iname "MP*MD.ini"` 只有 **`mpmodesmd.ini` 一个**（模式索引表，28 行：
  `1=GUI:Battle, STT:ModeBattle, MPBattleMD.ini, standard, true`）。9 个模式各自的
  `MPBattleMD / MPTeamMD / MPFreeForAllMD / MPUnholyMD / MPMWMD / MPDuelMD / MPMeatMD / MPNavalMD / MPCoopMD`
  **一个都不在松散层**——它们躺在 `mix_exports/expandmd01/expandmd01.mix` 里（`flags=0x30000`，索引加密）。
- `runtimeDefaultModeRulesOverride`（`RuntimeSessionWorld.cpp:283`）把 9 个 `gameMode` 映到 9 个文件名，
  **而这 9 个文件名全都不存在于松散层**。

**判定性实验**（2 分钟，不改代码）：往 `mix_exports/expandmd01/` 放两个最小松散文件
`MPFreeForAllMD.ini`（`AlliesAllowed=no` / `AllyChangeAllowed=no` / `MustAlly=yes`）与 `MPMeatMD.ini`，
同一二进制重跑：

```
before: alliesAllowed=no
after : alliesAllowed=yes      ← 一个文件就够了，其余 20 项一字未动
```

即：**这道闸的失败原因不是产品逻辑，是「规则文件找不到」**。文件一到位（哪怕内容是我瞎写的），
`skirmishModeRulesLoaded` 立刻为真，判定随之翻面。实验后两个文件已删除（`ls | grep -c MP` = 0），数据根未留痕。

## 4. 这不是「测试专属问题」，用户侧同样成立

`loadAndApplyRuntimeSkirmishModeRules` 只有三个调用者：`RuntimeSessionProduction.cpp:1420`、
`RuntimeSessionWorld.cpp:5420`（都是真开局路径）、以及冒烟。所以：

> **在真实游戏里选 Duel / Megawealth / Meat Grind / Naval War / Unholy Alliance / TeamGame / Cooperative，
> 模式规则一条都不会生效。** 菜单列得出 9 个模式（`mpmodesmd.ini` 读得到），点了等于选普通 Battle。

这比 M-13 原本登记的「取证通道缺失」重要得多：它是一条**用户可见的产品缺口**，只是被归类成了可观测性问题。

## 5. 重排（旧顺序为什么错 / 新顺序依据什么）

| 旧 | 新 | 为什么 |
|---|---|---|
| M-13「先加会话状态出口，再合成两人 setup」 | **M-22「模式规则从 MIX 归档读」** 升为前置（A 级，中等） | 状态出口与两人 setup 都已经存在（§1），再做一遍是重复劳动。真正挡住通道的是 §3 |
| `--skirmish-build-smoke-test` 从未登记 | 登记为 **S-17**（进 regress 的第 12 条），但它有前置 | 先让它绿再进门禁；红了就登记 known-red 会让门禁失去意义 |
| M-13 复杂度「中等 / 阻塞在取证通道」 | 复杂度不变，**阻塞改为 M-22** | 根因换了，成本估值随之变：从「新增 CLI + 合成 setup」降到「加一条归档读取回退」 |

估值变化（§七.3 要求逐条重估，不许只调顺序）：

| 条目 | 旧收益/成本 | 新收益/成本 | 依据 |
|---|---|---|---|
| M-22（原无此条目） | — | **S / 中低**：9 个游戏模式从「静默无效」变为生效；单点函数 + 一个只读回退，改动局部 | §3 的判定性实验；`MixArchive::findEntryByName + readEntryData` 现成 |
| M-13 | A / 中（新增入口 + 出口 + setup） | **A / 低**（只差 M-22 + 把冒烟跑绿） | 入口/出口/断言已有，见 §1 |
| S-17 | — | **C / 低**（regress 加一条用例 + known-red 口径） | 依赖 M-22 先绿 |

## 6. 本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：没有实现 M-22。原因写在时间账上：本轮 40 分钟里有 12 分钟用于「确认通道存在」，
  剩下不足一次构建（2.5 min）+ 迭代 + 回归 + 报告的安全余量；`RuntimeSessionNavigation.cpp` 的
  改动要经过 `RuntimeShell.cpp` 侧 20 个 `option semantics` 谓词的实测才能定论，猜着写等于制造半成品。
  §七 明确「重排轮只做诊断、不许改产品代码」，本轮按此收口。
- **遗留债 ①**：`mix_exports/expandmd01/expandmd01.mix` 索引加密（`flags=0x30000`），
  验证归档里到底有没有 9 个 ini 需要 `MixArchive` 的能力（它已实现加密索引），
  **不能在 python 里两三行验完**——这也是没有在本轮硬啃的原因之一。
- **遗留债 ②**：`--skirmish-build-smoke-test` 的 `modeRules=no` 即使文件到位仍可能为 `no`：
  它要求 `GATECH` 的 `techLevel==11`，这是内容依赖（模式 ini 里的 tech level 表），
  与「文件找得到」是两件事，别把两件事混成一个 commit。
- **放弃了什么**：没有顺手把 `--skirmish-build-smoke-test` 登记成 known-red 塞进 regress。
  它现在有 20+ 项 `no`，登记进去等于给一条「几乎全红」的用例盖合格章，违反 §八「转绿不算完成」的反向版本。

## 7. 质量四数（本轮）

| 指标 | 值 |
|---|---|
| 本轮净增行数（源码） | **0**（`git diff --shortstat` 空；诊断轮不改产品代码） |
| 最大单文件行数 | `RuntimeShell.cpp` 90,459（不变）/ `RuntimeMapRenderer.cpp` 42,578（不变）/ `RuntimeSessionWorld.cpp` 30,794（不变） |
| 新增断言 vs 新增产品代码行数 | 0 : 0 |
| TODO / FIXME / 一次性探针 | 0 / 0 / 0（持平，上一轮已清零） |

## 8. 清单体检（每轮必做）

`bash ra2mac_docs/scripts/ledger-check.sh` 全绿：fix-plan 128 行 / 400、queue 48 KB / 120 KB、
tasks 42 / 120、rules 5 类、超 6 行 detail 0 条。**本轮无压缩、无归档**（未触上限）。

人工四项（悬空引用 / 状态矛盾 / 重复 / attempts 与收口不符）：

1. **悬空引用**：`fix-plan` 里 3 个 `reports/*.md` 通配引用（`U-12-*`）仍在——但 `U-12` 是**历史轮号**，
   真实文件是 `U-12-*` 系列无固定名，属可接受的软引用，本轮不改（改错会制造新的悬空）。
2. **状态矛盾**：M-13 状态「待修复（阻塞在取证通道）」与实测矛盾 → **本轮已改写根因与阻塞点**（§5）。
   这是本轮唯一一处「计划与事实不符」，也是本次重排的触发点。
3. **重复条目**：M-07（diagnostics 驱动入口）与 M-13 在「无人值守进图」上重叠，但**不同层**
   （M-07 是 CLI/脚本驱动，M-13 是会话状态取证），保留两条、在 M-07 备注「与 M-13 共用入口」。
4. **attempts 一致性**：C-02 全系已 blocked、C-02i 在 `deferred.md`；M-13 旧 attempts=0 但**已被实测否决一次**，
   改 **attempts=1**（§六.1：未结案即 +1，且这次是「根因被推翻」不是「修失败」——一并写清，避免下轮误读为无进展）。

## 9. 两级计数

- **条目级**：M-13 attempts 1（根因推翻）；M-22 新增 attempts 0；S-17 新增 attempts 0。
  无 attempts ≥3 的未结案条目。
- **主线级**：C-02 主线 11 轮 / 9 子项 → **blocked（第 25 轮已收口，本轮未动）**。
  新开主线「遭遇战模式规则」= M-22 → S-17 →（放行）M-13，**已用 1 轮 / 1 子项**，红线 4 轮 / 4 子项。
  注意：M-22 与 M-13 **算同一条主线**（都是「真遭遇战能不能跑起来」），不许用拆新 ID 续命，
  这条主线的轮次从本轮起计。

## 10. 下轮起手

1. **M-22（A 级，中等，单点）**：给 `resolveRuntimeModeRulesOverridePath` /
   `loadAndApplyRuntimeSkirmishModeRules` 加「松散层找不到 → 从 `mix_exports/*/*.mix` 里按名读」的回退。
   先只读验证：用 `MixArchive::findEntryByName("MPMeatMD.ini")` 打出 `found=yes size=N`，
   确认 9 个名字里到底有几个在归档里（**一次运行，不改行为**）。
2. 判据：同一二进制 `--skirmish-build-smoke-test` 的 `alliesAllowed / mustAlly / unholy / megawealth /
   duelStart / megawealthStart` 至少 4 项由 `no` 转 `yes`；`modeRules` 单独看（它依赖 GATECH 内容，见 §6 债②）。
3. **不许**同时动 `--skip-skirmish-menu`（那是另一条线，且大概率是同一根因的下游）。
