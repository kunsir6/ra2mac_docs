# FIX-32 电脑开局 MCV 不是没展开，是「转向之后才落地」

- 轮次：第 31 轮（2026-11-14）
- 轮型：**修复轮**（主线未超 4 轮、无 brake、无腐烂预算、距上次 AUDIT 仅 1 轮）
- 主目标：M-23（skirmish-mode-rules 第 3 轮）
- 回归：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`20261114-021900`），`command` 失败前缀一字不变
- 结论：**M-23 是断言错误，不是产品缺陷**。产品一直能把电脑的 MCV 展开，冒烟要求「一次请求就出基地」。

## 一、读数（一行定性）

给 `deployRuntimeComputerAiMcvs` 加可选 `reason` 出参（默认 `nullptr`，调用者行为不变），
一次运行即打出：

```
Battle/Americans: computer could not deploy its opening MCV:
mcvs=1 owner=SkirmishPlayer2 #18 AMCV->GACNST item=GACNST planned=91,128
status=MCV turning to deploy yard=no
```

四项同时为真：**有 MCV（mcvs=1）**、**类型认得（AMCV->GACNST）**、**目录项在（item=GACNST）**、
**落点找得到（planned=91,128）**。计划里列的三个候选成因（没 MCV / 没落点 / 请求被拒）**全部被否**。
`status` 说明请求已被接受，只是停在「转向」阶段；`yard=no` 说明基地还没落地。

## 二、根因

`requestRuntimeMcvDeployment`（`RuntimeSessionCombat.cpp:7839`）在车体朝向 `desired`（MCV 为 160）之前
**不会**调 `deployRuntimeMcv`，而是挂一条 `RuntimeBehaviorKind::Move` 的 pending 行为、把 mission 置为
`McvDeployTurning`，返回 `true`；真正的换算落在 `advanceRuntimeMcvDeployTurns`（`RuntimeSessionTick.cpp:189`
每拍调用）。也就是说「请求被接受」与「基地存在」之间隔着一段转向时间。

冒烟写的是：

```cpp
if (!deployRuntimeComputerAiMcvs(state, enemy)
    || !runtimeOwnerHasConstructionYard(state, enemy.owner))
```

短路求值下第一条为真，就轮到第二条同步判定 —— 而此时一帧都还没推进，`yard=no` 是**必然**结果，
与模式、阵营无关，所以 7 模式 × 3 阵营 + 7 夹阵营 × 2 模式共 35 例一字不差。

同仓 `RuntimeUnholyStartSmoke.inl:74-85` 早就写过同一情形的正确形态（注释原文：
"an AI deployment request may first turn the mobile base before creating its yard"），
用「按拍推进 + `advanceRuntimeMcvDeployTurns` + `advanceRuntimeComputerAi` + 有界等待」。
这条冒烟没跟上。

## 三、改法（两个 commit，均为 test:）

| commit | 内容 |
|---|---|
| `4abfee7` | `deployRuntimeComputerAiMcvs` 加可选 `reason` 出参（`mcvs/owner/#id type->deploysInto/item/planned/status/yard`），冒烟失败时打出来。默认 `nullptr`，三个调用点行为不变。 |
| `cc53d95` | 请求通过后按 `max(30, runtimeRuleFramesToTicks(32, fixedTickHz))` 有界等待，每拍 `++tick; advanceRuntimeMcvDeployTurns(state)`；等不到才判红，失败文案保留读数。 |

## 四、验证

- 单例：`CONCORD_SKIRMISH_MODES_ONLY=1 CONCORD_SKIRMISH_MODE_FILTER=Battle CONCORD_SKIRMISH_COUNTRY_FILTER=Americans`
  → `Mode technology passed: Battle/Americans`（改前同一条红）。
- 全矩阵：`CONCORD_SKIRMISH_MODES_ONLY=1 --skirmish-build-smoke-test` → **`cases passed=35 failed=0`**（22 秒）。
  这是模式矩阵第一次整条跑到尾：之前每一档都停在开局那一行。
- 全量回归：`10/1/0`，`command` 前缀不变。

## 五、为什么这轮不算「已修复」

按八.2/八.4 的口径，这是**断言纠正**：产品代码零改动（`reason` 出参是纯观测，默认不改变任何行为）。
报告与计划里一律标「断言纠正：原断言错在把『请求被接受』当『基地已存在』」，**不计入已修复**。
真实产出是「一道假门被拆掉」+「模式矩阵第一次全绿」，不是「修好了一个产品 bug」。

## 六、新发现：完整链路的第一个失败点比我们一直跟的还早（登记 M-29）

顺手把 `--skirmish-build-smoke-test`（不带 `MODES_ONLY`，即 S-17 要接的那条）跑了一遍，0.2 秒就退出：

```
option semantics modeRules=yes alliesAllowed=yes mustAlly=yes ownerFactory=no unholy=no
megawealth=yes startingPools=yes duelStart=yes megawealthStart=yes modStart=yes …
```

`ownerFactory=no` 与 `unholy=no` 在 `validateRuntimeSkirmishOptionSemantics`（`RuntimeShell.cpp:16543`）里，
位置在模式矩阵**之前** —— 也就是说这条用例从来没有真正跑到过我们跟了 3 轮的那一段。
`ownerFactoryApplied` 由三条谓词合成（`RuntimeShell.cpp:15654`）：
`sovietPower 存在` / `GACNST 不兼容 NAPOWR` / `NACNST 兼容 NAPOWR`，`unholy` 又是它的下游。
**三条里哪一条假，本轮没有读数，不猜**。两种解释改法相反：
① 探针状态没拿到模式规则（`unholyProbe` 是新建 `RuntimeWindowState`，只补了 rules/economy）→ 夹具侧；
② `runtimeFactoryOwnerCompatibleWithBuildItem` 没被 UnholyAlliance 的允许清单放宽 → 产品侧。
登记为 **M-29**（新主线 `skirmish-option-semantics`，第 1 子项），第一步是给这三条谓词各打一个布尔。

## 七、skirmish-mode-rules 主线收口判定（§六.3，本轮为第 3 轮，窗口用尽）

| 子项 | 结果 |
|---|---|
| M-22 模式规则从归档读取 | **done**（`2c7f1ea`，S 级用户可见：9 个模式的规则从静默无效变为生效） |
| M-23 电脑开局 MCV | **done**（断言纠正，本轮；模式矩阵 35/35） |
| M-24 录像兼容哈希漏算归档侧规则 | **移出主线 → `progress/deferred.md`** |
| S-17 把这条冒烟接进 regress | **blocked**，阻塞改为 M-29（另一条主线） |

**判 done**，不再开第 5 个子项。未做的行为差异与代价，写清如下：

1. **录像兼容哈希**：`RuntimeMatchReplayRuntime.inl:47-49` 仍是「松散路径非空才 `mixFile`」，
   归档命中后模式规则文本不进哈希 → 有/无松散 `MP*MD.ini` 的两台机器算出不同 `matchReplayCompatibility`。
   **代价**：跨机录像兼容判定会误判（把可回放的判成不兼容）。单人本地回放不受影响，
   所以按 B 级挂着；重开条件 = 多人联机或录像跨机分享实装。
2. **S-17（真遭遇战链路进不了门禁）**：不是没价值，而是被上游 M-29 挡着。
   按「不许登记 known-red 给一条几乎全红的用例盖合格章」的既定口径，它继续 blocked。
   **代价**：遭遇战链路继续没有日常门禁，回归仍是 11 条。

## 八、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：M-29 的任何修改（只登记 + 一条失败行原文）；S-17 的接入（被 M-29 挡）；
  M-24 的哈希改造（移出主线，见 deferred）。
- **遗留债**：`deployRuntimeComputerAiMcvs` 的 `reason` 出参是「按需传指针」的 C 风格接口，
  与仓里 `std::string& error` 的写法不一致；下一次动这个函数时应统一成出参引用或返回结构。
- **放弃了**：不再追「AI 开局还有没有别的同步假设」——本轮只拆掉断言的那一处，
  模式矩阵 35/35 已覆盖到「建完一整套基地」，再往下挖属于另一条线。
- **并发边界**：源码仓库仍有他人未提交的 text layer 改动（7 文件 +324 行），本轮只 `git add` 自己的 3 个文件，
  未触碰；`build-product-arm` 的构建因此包含了对方 WIP，若对方后续改动导致回归变化，与本轮两提交无关。
- **队列也是共享文件**：`queue.json` / `queue-archive-202611b.json` 里有并发会话未提交的 v136 改动
  （归档 11 条 + 新增 M-25~M-28）。本轮在这些改动**之上**做 v137，原样保留，`queue:` 提交正文注明来源。

## 九、质量四数 / 清单体检

- 净增行数：**+34 −5 = +29**（3 文件，全在测试/观测面）；产品行为净增 **0**。
- 最大单文件：`RuntimeShell.cpp` 90,459（不变）/ `RuntimeMapRenderer.cpp` 42,578（不变）/
  `RuntimeSessionWorld.cpp` 30,794（不变）。
- 新增断言 **0** / 新产品代码行 **0**（`reason` 出参算观测，不算产品行为）。
- TODO/FIXME：**0 → 0**。
- 清单体检（`ledger-check.sh` **六项**全绿）：fix-plan 162 行 / queue 44 KB / 35 条 /
  rules 5 类 / detail 无超 6 行 / **dup-ids 0**。本轮新增 M-29 1 条，同时把 M-24 移出主清单
  （本体进 `queue-archive-202611b.json`），tasks 35 → 35，满足「新增 N 条要归档 N 条」。

## 十、清单体检抓到的一件事：两本账撞了 id

新增条目时先写成 `M-25`，写盘后发现队列里**已经有并发会话（L10N-04）昨晚 01:20 加的 M-25~M-28**
（`M-25` 步兵密集站位、`M-26` 伞兵落地前点不中、`M-27` 偷星后兵营不显示等级星、`M-28` 工程师原地晃动），
于是出现两条 `M-25`。处置：本条改为 **M-29**，五处引用（fix-plan 摘要与两行表格、报告、queue 的
S-17/M-13 detail）全部改完，复检 0 重复。

**根因不是手滑，是门禁缺口**：`ledger-check.sh` 量了行数/体积/条数/规则类数/单条行宽，
**没有量 id 唯一性**。本轮补第 6 项 `dup-ids`（重复直接 BREACH）。这类「量了体量但没量结构」的门禁，
和 `fix-plan` 曾长到 743 行是同一类问题：**规则写了，但没有任何东西去数它**。

## 十一、本轮没做什么 / 遗留什么债 / 放弃了什么
