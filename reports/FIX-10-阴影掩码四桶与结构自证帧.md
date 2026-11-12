# FIX-10 阴影掩码四桶与结构自证帧

**日期**：2026-11-12（第 9 轮）
**批次**：S-10（零售重复 id 日志分级）+ M-20（掩码返回值语义拆分）+ M-18（建筑零投影定性收口）
**一句话结论**：**建筑投影从来不是产品缺陷，是门禁在自己的帧里看不见建筑。** 掩码返回值拆出
离屏/裁剪两种结局后，读数从 `structureEmpty=2` 变成 `structureOff=2 / empty=0`——上一轮
「掩码在但画不出」的判断被自己的新桶否掉；再起一帧对准真实建筑，第一栋 `CAAIRP` 就压暗了
13551 像素。`render` 仍红，但阻塞点后移到矿喷发动画（M-21，改前日志逐字相同，非本轮引入）。

---

## 一、M-20：把「掩码有效」与「真的画了」分开

### 现象

`drawRuntimeVoxelShadowMask` 返回 `bool`，同时承担两种语义：

| 路径 | 返回 | `darkenedPixels` | 调用方读到的意思 |
|---|---|---|---|
| 掩码全 0 / 帧 0x0 | `false` | 0 | 掩码无效 → 走软阴影兜底 |
| 帧矩形与视口不相交 | `true` | 0 | 「掩码有效，但没压暗」 |
| 表面裁剪后无列 | `true` | 0 | 同上 |
| 正常绘制 | `true` | N | 画了 N 像素 |

中间两行与「真的空掩码」在统计上不可区分，`structureShadowEmptyMasks` 因此同时收了两类事实。

### 改法

新增 `RuntimeShadowMaskOutcome{None, Empty, OffScreen, ClippedOut, Drawn}` 作为可选 out 参数
（`drawRuntimeVoxelShadowMask` / `drawRuntimeShpShadowFrame` 各加一个末位默认参数，既有调用点
零改动）。四个 `return` 前分别置位；`drawRuntimeWorldObjectShadow` 把它带进
`RuntimeWorldObjectShadowResult.maskOutcome`；记录侧结构阴影从 3 桶改 4 桶：

```
structureCand / structureNoArt（0x0 帧）/ structureOff（离屏）/ structureClip（裁剪）/ structureEmpty（真空掩码）
```

同时在 `recordRuntimeWorldObjectShadowResult` 加了一条 `[shadow-record]` 追踪（**独立预算 16 条**，
不与绘制侧的 12 条共享）。原因见 §四。

### 读数

| | 改前 | 改后 |
|---|---|---|
| 自然地图帧 | `structureCand=2 structureEmpty=2 structureNoArt=0` | `structureCand=2 structureOff=2 structureClip=0 structureEmpty=0 structureNoArt=0` |

`structureEmpty=2` 整体迁到了 `structureOff`。**「掩码解析成功却没压暗」这一类在这张图上不存在。**

---

## 二、M-18：建筑零投影的定性 —— 门禁的取景与断言互斥

### 根因

`render` 冒烟的自然地图帧有两件事同时要求，而它们互斥：

1. **ore 探针**要把相机重新居中到一排资源格上，`findProbeLine` 挑格的判据是
   `mapFactBlocksProbeCell` —— 也就是**没有 overlay 的地基**，等价于「这里什么都没有盖」；
2. **阴影门禁**要求 `structureShadowsDrawn > 0`，即这同一帧里必须看得见建筑。

探针刚把镜头挪到空地上，建筑就必然在视口外。这不是偶发，是构造性冲突：只要 ore 探针存在，
这条断言就不可能满足。第 8 轮读到的 `structureEmpty=2`、以及更早的「资产缺口」，
都是在给一个**取景问题**找产品解释。

### 为什么之前没发现

- 第 7 轮把 `drawn=5 而四个 kind 全 0` 拆开，补了 `structureCand/structureEmpty`——桶对了，但
  两个成因压在同一桶里；
- 第 8 轮加第三桶 `structureNoArt`，`structureNoArt=0` 被读成「候选不是空体建筑」，于是
  「资产缺口」被否，剩下唯一解释就成了「掩码在但画不出」；
- 真相是**两个都不是**：候选确实不是空体建筑（NATBNK 那条追踪来自另一帧），它们的影子确实
  没画——因为影子矩形整块在视口外。

### 改法：给这条性质一帧自证

主帧的门禁只保留「阴影管线在跑」：`shadowCandidates / shadowsDrawn / shadowPixelsDarkened /
shpShadowsDrawn` 四项（去掉 `structureShadowsDrawn`）。建筑投影单起一帧：

- 逐栋遍历地图上的 `WorldObjectKind::Structure`，把相机居中到该建筑（`runtimeProjectCellXY`
  取投影点，`worldOffset` **赋值**，不是累加）；
- 画进独立 DIB、独立 `RuntimeMapRenderCache`，不污染主帧像素；
- **逐栋搜索到第一栋真的压暗像素为止**（上限 12 栋），每栋打印自己的四桶读数。

逐栋而不是「取一栋」的理由：`NATBNK` 这类缺 temperate 美术的建筑（M-19）合法地投不出影子，
用「第一栋」会把资产缺口重新混进管线判据。

### 读数（改后）

```
Natural-map structure shadow frame: focus=CAAIRP instance=1
  candidates=7 drawn=4 pixels=13551 noArt=0 off=3 clip=0 empty=0
```

第一栋就成：7 个候选、4 个画出来、压暗 13551 像素。**建筑投影在产品层是好的**，此前 6 轮
（M-18 / M-20 / S-06）判红的对象是断言本身。

---

## 三、S-10：零售重复建筑 id 降级为一条 data-note

`rulesmd.ini` 的 `[BuildingTypes]` 里 `NAPSYA` 确实出现两次（item 239 与 183，指向同一
section），「先到先得」是零售语义。原实现按「重复即告警」逐条 push，把真正的 `Corrupt`
（id 长度 > 256）埋在噪声里。

改为循环内收集、循环后聚合成**一条**：

```
rules: data-note: duplicate building id in retail data (first occurrence wins): NAPSYA (item 239 repeats item 183)
```

带首次出现的下标、超过 8 条折叠成 `+N more`；`Corrupt ... at item N` 仍单独报警。

---

## 四、两条流程教训

### 1. 计量必须打在「与汇总同一个点」

第 8 轮的 `[shadow-trace]` 打在 `drawRuntimeWorldObjectShadow` 里，预算 12 条、跨帧共享。
自然地图帧的汇总读数与追踪打印**不是同一批对象**：追踪已经被前面的合同检查帧用光，
最后剩的几条全落在 NATBNK 上，而汇总帧里根本没有 NATBNK。于是出现
「追踪说 `authoredEmpty=1`，汇总说 `structureNoArt=0`」这种自相矛盾的读数。

本轮把追踪移到 `recordRuntimeWorldObjectShadowResult`（与计数同一个函数、同一批对象），
并给了独立预算。判据：**逐对象打印与汇总读数必须能互相验算**，做不到就说明计量点选错了。

### 2. 相机偏移是赋值，不是累加

首版写 `structureCamera.worldOffsetX += projected.x - width/2`，结果十栋建筑全部
`candidates=0`——整张图被推出视口，连粗剔除都过不了，且不报任何错。
`runtimeProjectCellXY` 返回的是**未减偏移**的投影点，既有两个调用点（33487、33621）都是赋值。
判据：**新写的相机代码要跟既有调用点逐字对齐**，改了语义就得有一个「图在不在视口里」的自检。

---

## 五、回归与收口

| 项 | 结果 |
|---|---|
| 开工基线 `20261112-095823` | `PASS=8 KNOWN-RED=3 RED-NEW=0` |
| 收口 `20261112-101458` | `PASS=8 KNOWN-RED=3 RED-NEW=0` |
| `core` 输出 | 告警变为一条 `data-note`（S-10 生效） |
| `render` | 仍 KNOWN-RED，但**阻塞点从阴影门禁后移到矿喷发动画** |

`render` 新阻塞点（M-21）：`oreGrowthSpawnerAnimationDrawn=false frames=11`，
其余子条件（ran/changed/ring/overlay）全绿。**改前基线日志逐字相同**（同为 `anim=no/frames=11`），
即它是被阴影门禁屏蔽了 6 轮的前置失败，不是本轮引入。

源码提交：

- `5ce280b` fix: S-10
- `dd6eb31` test: M-20 四桶 + 记录点追踪
- `8b14b61` test: 阴影门禁拆出自证帧

---

## 六、下一轮起手

**M-21（中等，优先）**：`render` 停在矿喷发动画。已知 `frames=11` 但 `drawn=false`，
说明帧号在推进、绘制判定没成立。先看 `oreGrowthSpawnerAnimationDrawn` 的置位处
（`RuntimeShell.cpp` ~34960 附近的上游），分辨是「动画层数为 0」还是「层在但像素为 0」；
同轮可一并复核本轮新增的 `structureOff/Clip` 桶在其它图上是否恒 0。

**M-12（中等）**：interaction 右键命中，仍需先钉死「谁挡住谁」。
**C-02（复杂）**：command 两栖卸载，单独成轮。
