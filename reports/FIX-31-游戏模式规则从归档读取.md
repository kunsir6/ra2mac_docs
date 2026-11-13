# FIX-31 游戏模式规则从归档读取（M-22）

- 轮次：第 29 轮（2026-11-13）
- 轮型：**修复轮**（主线「遭遇战模式规则」第 2 轮 / 第 2 个子项，未到限）
- 基线：`regress 10/1/0`（`20261113-234640`）；收口：`10/1/0`（`20261113-235638`），零新回归

---

## 1. 结论

**用户选 Duel / Megawealth / MeatGrind / NavalWar / Unholy / TeamGame / Cooperative / FreeForAll
这 8 个模式时，规则一条都没生效**——不只是「读不到」，而是整条 `skirmishModeRules` 从来是空的：
`skirmishModeRulesLoaded=false`，所有模式行为退回 `MPBattleMD.ini` 也没加载的默认值（等同普通战斗）。

修完之后模式规则从归档里读出来了。`--skirmish-build-smoke-test`（`CONCORD_SKIRMISH_MODES_ONLY=1`）
的阻塞点从**第一道门**（模式规则没加载）后移到**第二阶段**（AI 开局 MCV 不展开），
后者是全 35 例一致的另一个根因，已登记 M-23，不在本轮硬啃。

## 2. 根因

`resolveRuntimeModeRulesOverridePath`（`RuntimeSessionNavigation.cpp:161`）只查 5 个**松散**路径，
而 9 个 `MP*MD.ini` 在零售版里只存在于 `expandmd01.mix`（`flags=0x30000`，索引加密）。
松散层唯一有的是模式索引 `mpmodesmd.ini`——它是「有哪些模式」，不是「模式规则」。

于是 `loadAndApplyRuntimeSkirmishModeRules` 的第一行守卫就返回：
路径空 → 不加载 → `skirmishModeRulesLoaded` 永远 false。两个消费点同时失效：

| 消费点 | 失效后果 |
|---|---|
| `loadAndApplyRuntimeSkirmishModeRules` | 模式禁令 / `AlliesAllowed` / `MustAlly` 全是默认值 |
| `buildRuntimeStartupReport` 的 rules→mode→map 叠加 | `[X] TechLevel=-1` 这类模式技术禁令从未进过 `RulesDatabase` |

## 3. 改法（一个根因，4 文件 / +122 −11）

新增 `loadRuntimeModeRulesIni(config, ini, label)`（`RuntimeSessionNavigation.cpp`）：

1. **松散命中优先**，语义一字未改——`resolveRuntimeModeRulesOverridePath` 保持原样，
   它的 5 条候选路径和「绝对路径必须存在」的规矩都不动，本地 mod 覆盖仍然有效；
2. miss 时按名在归档层里找：`expandmd01.mix` → `expandmd02.mix` → `ra2md/localmd.mix` →
   `ra2/local.mix` → `localmd.mix`，命中即 `findEntryByName` + `readEntryData`，去尾部 NUL 后
   `IniFile::loadFromString`；
3. 归档命中时 `label` 记**条目名**（`MPUnholyMD.ini`），不是归档路径——三处消费者都对它取
   `filename()` 与 `"MPUNHOLYMD.INI"` 比较（`isUnholyRules`、`runtimeSkirmishModeMatches`、
   economy status 的 `modeRules=`），记归档路径会把这三处一起打坏。

两个调用点都换成它：`RuntimeSessionScenario.cpp`（模式加载）与 `RuntimeSessionWorld.cpp:30600`
（启动报告里的规则叠加）。

## 4. 读数（同一命令、同一数据根，只差这次改动）

```
改前  FreeForAll/Americans: opening failed: skirmish start not applied
       Mode technology cases passed=0 failed=1
改后  FreeForAll/Americans: computer could not deploy its opening MCV
       （全量：Mode technology cases passed=0 failed=35，35/35 同一句）
```

「skirmish start not applied」是**多谓词压成一句**的典型：那句来自
`if (!state.skirmishModeRulesLoaded || !initializeRuntimeSkirmishStart(state))`，
短路口在第一个谓词上，`skirmishStatus` 还停在初始值——所以它读起来像「开局失败」，
实际是「压根没走到开局」。

## 5. 新阻塞 M-23（本轮只登记，不动手）

`deployRuntimeComputerAiMcvs`（`RuntimeSessionScenario.cpp:11398`）返回 false，
全 35 例（7 模式 × 3 阵营 + 7 夹阵营 × 2 模式）**一字不差**，与阵营/模式无关，
说明是单一原因而不是模式内容。

返回值是 `changed`，三个来源各有一种「假」：

| 分支 | 该问什么 |
|---|---|
| `mcvIds` 为空 | AI 阵营开局有没有拿到 MCV？还是 `runtimeComputerAiOwnerMatches` 认不出 owner |
| `findRuntimeMcvDeployCell` 返回 nullopt | 地基格被占 / 地形不可用（与模式无关就应怀疑夹具建图） |
| `requestRuntimeMcvDeployment` 返回 false | 部署请求被规则拒（注意人类那条走的是 `deployRuntimeMcv`，绕过请求门） |

**一次读数即可裁定**：在 `deployRuntimeComputerAiMcvs` 返回前打一行
`aiMcv ids= cell= item= planned= requested= owner=`（默认静默、失败文案带出，不留环境变量）。
判据写在 M-23 的验收条件里，别先猜。

## 6. 质量四数

| 项 | 值 |
|---|---|
| 净增行数 | **+111**（`4 files changed, 122 insertions(+), 11 deletions(-)`） |
| 最大单文件 | `RuntimeShell.cpp` 90,459（未动）/ `RuntimeMapRenderer.cpp` 42,578（未动）/ `RuntimeSessionWorld.cpp` 30,792 → 30,794（+2） |
| 断言 vs 产品代码 | 新增断言 0 / 产品代码 +122（本轮不新增断言：既有冒烟就是验收器） |
| TODO/FIXME/探针 | 0 → 0（本轮没引入任何环境变量开关） |

**成本观察（下一轮要复查）**：`build` 冒烟从 `startup=487ms placementSearch=1707ms`（总 3s）
变成 `startup=2463ms placementSearch=7260ms`（总 11s）。同一台机器、同一进程结构，
最可能是模式规则现在真的往 `economy.catalog` 里加了模式条目（`addRuntimeModeOverrideBuildCatalog`），
候选格搜索空间变大。**尚未定量**，若下轮继续涨，按「目录条目数 × 放置搜索耗时」量一次。

## 7. 清单体检（本轮补清单同步做）

`scripts/ledger-check.sh` 五项全绿：fix-plan 136 行 / queue 53KB / 46 条 / rules 5 类 / 无超长 detail。

体检发现并当场修掉的 5 条（都是「关联报告」字段被当便签用）：
`C-02g` / `S-12` / `C-02h` 的 `report` 填的是 commit hash（`c5d2b6c` / `50d3a85` / `7b9f576`），
`S-15` / `S-16` 少写了仓库前缀。已分别改成 `FIX-24` / `FIX-13` / `FIX-25` / `FIX-28`。
复检：queue 46 条悬空引用 0、重复 id 0、pending 缺字段 0；fix-plan 32 个报告引用悬空 0。

## 8. 本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做 S-17**（把这条冒烟接进 regress）：它现在的状态是「第 1 道门通了、第 2 道门红」，
  接进门禁只能登记 known-red，而 §S-17 的口径明确禁止（一条几乎全红的用例盖合格章等于取消门禁）。
  顺序必须是 M-22 → M-23 → S-17。
- **没做 M-13**（真实遭遇战取证）：同一条链的下游，等 M-23 绿。
- **债 1**：`RuntimeMatchReplayRuntime.inl:50` 仍按**松散文件字节**算兼容性哈希。
  归档命中后这条分支被跳过 → 有松散文件的机器与没有的机器算出的 `runtimeMatchReplayCompatibility`
  不同。本轮没动它（会变更录像兼容哈希语义，需要单独一轮 + 版本号），已记 M-24。
- **债 2**：`resolveRuntimeModeRulesOverridePath` 现在只服务「松散路径」这一件事，
  而实际加载走 `loadRuntimeModeRulesIni`；两个名字容易让人再写一次「只查松散」。
  下轮若碰这块，考虑把前者收进后者内部（纯重命名类改动，不夹行为）。
- **放弃了什么**：放弃「先在 M-22 里顺手把 AI MCV 部署一起修」。它跨
  `deployRuntimeComputerAiMcvs` / `findRuntimeMcvDeployCell` / `requestRuntimeMcvDeployment` 三处，
  且当前只有一句返回值可用——按 §4.4 立刻移出，不做硬啃。

## 9. 提交

| 仓库 | hash | 一句话 |
|---|---|---|
| ConcordRTS | `2c7f1ea` | fix: 游戏模式规则只查松散层，选任何模式都静默退回普通战斗 |
