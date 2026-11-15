# 第 63 轮（修复轮）：空转重绘的根因假设被实测推翻 → 按 §七 转重排

**轮型：修复轮**（无 brake、无在办 attempts≥3、腐烂预算未触发〔R62 净增 −137〕、距 AUDIT-61 两轮）。
主目标 **M-03 / ON-2-06 世界 idle 空转重绘**。结论是**负结果**：主目标没能修好，
但把「哪处代码在要求每帧重绘」这个假设验掉了，并按 `§七`（根因假设被实测推翻）把剩余时间转成重排。

---

## 一、本轮做了什么

### 1. S-08 结案（读数终于落地）

S-08 的验收条件原文是「`performance/latest.txt` 出现『复用帧 / 重绘帧 / 最长连续复用帧』三行且与实际相符」。
第 56~62 轮一直挂着「出口只被窗口会话收尾调用、`sessionFrames==0` 直接 return」，因此判它要等一次真开局。

本轮在 `ConcordRTS-GameData/local_data/performance/latest.txt`（mtime 2026-11-15 20:42，真会话 226 秒）里
读到这三行，数值自洽：

```
采样帧数 / 无效间隔：7492 / 0
采样时长（秒）：226.421
全会话绘制更新率：33.089 次/秒
复用缓存帧 / 重绘帧：13 / 7479
最长连续复用帧：1
```

判据成立 ⇒ **S-08 done**。同时这份读数就是 M-03 的基线：**7479/7492 = 99.8% 的帧是重画的**，
33 次/秒，慢帧样本里 `renderMs=16.025`、`mapMs=13.410`（`terrainMs=9.062`）。
即「静止也每秒白画 33 次同一张图，每次约 16 ms」。

### 2. 删掉压住细粒度判据的那处兜底（`25b6c53`，+14/−1）

帧循环里本来已经有一处**很细**的判据（`RuntimeShell.cpp:90313`）：

```cpp
if (simulationChanged || waterWakeChanged) { state.repaintRequested = true; }
```

但 100 行之后有一处无条件兜底，把它整体作废：

```cpp
advanceRuntimeUiPresentation(state);
if (tickAdvanced) { state.repaintRequested = true; }     // ← 每拍都置
```

`reuseCachedFrame` 的条件第一项就是 `!state->repaintRequested` —— 只要这处兜底在，
缓存复用永远走不到（读数里的 13 帧复用是开局那几帧）。删掉后保留两处兜底：

- **对战分支保持每拍重绘**：那半边画面由桥接泵提交，改动面在别的 TU，本轮不碰；
- **本机分支每 30 拍强制重绘一次**：万一某类视觉变化没被 `changed` 汇总到，最坏延迟 1/3 秒（满速 92 拍/秒），
  不会冻帧。

### 3. 读数：**没动**

同一探针（`/tmp/ra2_idle_probe.sh`，`--skip-main-menu --skip-skirmish-menu`，起窗后 18 秒采样
`top -l 2 -stats cpu -pid`），改前改后各一次：

| | idle CPU | 两两截图（间隔 2s） |
|---|---|---|
| 改前 `897de11` | **21.1%** | 不同（未冻帧） |
| 改后 `25b6c53` | **20.8%** | 不同（未冻帧） |

差 0.3 个百分点 = 噪声。**这处兜底不是 33 次/秒冗余重绘的来源。**

---

## 二、为什么没动（本轮唯一的实质结论）

`simulationChanged` 是 `advanceRuntimeSimulation` 的返回值，它汇总的是**模拟侧**的变化
（effects / economy / triggers / buildAnimations / guard / movement …），不是**画面侧**的变化。
对战场景里 AI 单位一直在动、动画 tick 一直在走，于是它**每拍都为真**——
兜底删不删都一样，`repaintRequested` 本来就已经被细判据置上了。

因此 M-03 的计划里那句「场景签名门（tick+相机+对象位姿帧号+选中集+资源+遮罩版本）」是对的，
但要补一句：**签名必须建在「画了什么」上，不能建在「模拟变了什么」上**。
现在这条路是「模拟变 → 认为画面变」，冗余就出在这个等号上。空转的真来源在三类里
（本轮**没有**逐一定量，见 §三）：

1. 动画计时器（水面/烟雾/建筑动画）每拍递增，但 SHP 帧号按 `delay` 才变一帧 → 中间那些拍画面是同一张；
2. 单位位姿在亚格内推进，像素落到同一位置；
3. `continuousRuntimeFrame`（`state.world.getSummary().loaded && !IsIconic(window)`）让 paint **每帧都被 Invalidate**，
   即使 `reuseCachedFrame` 为真也要走一次 blit。

---

## 三、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做什么**

- **没拿到「人静置」那一档的读数**。本轮能自动造出来的场景只有 `--skip-skirmish-menu`（带 AI），
  而 AI 在场时模拟每拍都在变——恰恰是最不该省的那一档。人静置（无单位移动）本环境造不出来：
  Accessibility 未授权、合成键鼠被丢（见 MEMORY），不能按键暂停。
  **所以 M-03 现在是「假设被推翻 + 新假设未定量」，不是「已修复」。**
- 没动 `continuousRuntimeFrame`：它是第三条候选来源，但删它要先证明「窗口不会因为不再 Invalidate 而停摆」，
  属另一轮的活。
- 没做 S-36（coverage 白名单 8 型判定）与 S-34（README 生成）：主目标吃掉全部预算。

**遗留的债**

- M-03 attempts 1 → **2**，估值不变（收益 B / 成本复杂），但**下一轮不许再猜第三处代码**：
  要么先补一个「画面签名」的只读计量（把 `simulationChanged` 与真实像素变化逐帧对账），要么移 deferred。
- 比例闸：R57~63 七轮里只有 R58/R60 动过产品代码，本轮又落成 `refactor:`。
  fix: 分母继续缺，**下轮起手必须挑一条能产出用户可观察行为的条目**。
- 本轮净增 +13（产品代码 +13），断言 +0。

**放弃了什么**

- 放弃「一次把签名门写完」：签名门要碰对象位姿与动画帧号两套数据，落在 90,633 行的
  `RuntimeShell.cpp` 里会超 `§五.3` 的单次 +50 行红线，而且没有读数兜着写等于赌。
- 放弃在本轮验证「30 拍兜底够不够」：它需要一段真实人静置录像逐帧比对，环境做不到。

---

## 四、质量四数（`§五.1`）

| 项 | 数值 |
|---|---|
| 本轮净增行数 | 源码 **+14 / −1 = +13**（唯一 src 提交 `25b6c53`；docs/scripts 另计） |
| 最大单文件行数 | `RuntimeShell.cpp` 90,633（+13，R62 后 90,620）；`RuntimeMapRenderer.cpp` 42,542（持平）；`RuntimeSessionWorld.cpp` 31,056（持平） |
| 新增断言 vs 产品代码 | 断言 **0** vs 产品 **+13** |
| TODO/FIXME/临时探针增减 | 0 → 0（全树 grep 计数 0）；探针 `/tmp/ra2_idle_probe.sh` 在 `/tmp`，未入库 |

---

## 五、清单体检（`§一.7`）

- `fix-plan.md` **201 → 213 行**（≤400 ✓）；`queue.json` 64KB（≤120KB ✓）；tasks 39 条（≤120 ✓）；
  rules 5 类（✓）；`ledger-check.sh` 十三项全绿。
- 状态与报告矛盾检查：S-08 本轮由「待修复」改「已完成」——**这是本轮第二次「门开了很久没人回写」**
  （第 56 轮审计点过 6 条同形态）。它的 DoD 早就能满足，卡的是「等一次真开局」这句话，
  而真开局读数 2026-11-15 20:42 就已经在 `latest.txt` 里了（第 62 轮打包时甚至读过该目录）。
  **教训：DoD 里写「等一次 X」的条目，必须同时写明「X 的产物落在哪个路径、谁去看」**，否则等于没有判据。
- 悬空引用：本轮新增 `reports/FIX-63-...md` 与 queue 的 `report` 字段同批入库，`refs-in-queue` 通过。
- 重复条目：M-03 与 ON-2-06 是 fix-plan / queue 两侧镜像（既有口径，非新增重复）。

---

## 六、两级计数（`§六`）

- **条目级**：M-03 attempts **2**（本轮 +1，未结案）；S-08 attempts 1 → **done**；
  M-25 attempts 3（blocked，未动）；S-28 attempts 1（blocked，未动）；C-02i attempts 2（blocked，未动）。
  **无新增 attempts≥3 的在办条目。**
- **主线级**：`M-03 空转重绘` 这条线本轮是**第 1 轮**（此前只有 S-08 计量，算同一线：1 子项 + 本轮 = 2 轮）。
  `## 四、主线账目` 表中「仍在办的主线：无」需改成一条：**M-03（2 轮 / 2 子项，未到限）**。

---

## 七、提交清单

| 仓库 | hash | 一句话 |
|---|---|---|
| ConcordRTS | `25b6c53` | refactor: tick 推进不再无条件置重绘，删掉压住细粒度判据的兜底 |
| ra2mac_docs | 见 `git log` | `docs:` 本报告 + fix-plan（S-08 done / M-03 attempts 2 / 主线账目补行 + 本轮索引） |
| ra2mac_docs | 见 `git log` | `queue:` v168（S-08 done、M-03 读数与新假设、decision r63） |

## 八、dist

```
25b6c53 2026-11-16T00:22:41 regress=pass14/known2/new0 arch=arm64+x86_64 minos=12.0 icon=96.2
  rosetta=rc0 pack=incremental+lipo-universal buildtree=clean wip=none round=R63
```

门禁逐条：`lipo -archs` = x86_64+arm64 ✓；两切片 minos 都 12.0 且与 plist 一致 ✓；
`arch -x86_64 …--smoke-test` rc=0 ✓；pack-dist 自身（icon 96.2、plist 身份、包内 smoke、`--version` 对账）✓。
arm 重编 2:36、x86_64 2:28、lipo+签名+pack 约 1 分钟。

---

## 九、下轮起手（R64）

1. **优先挑一条能产出用户可观察行为的条目**（比例闸的债）：候选 `U-20` 载入画面地图预览为空、
   `U-21` 主菜单右侧小屏、`U-23` shroud 羽化——三条都是「看得到但没对过」的。
2. M-03 只允许走一条路：**先补「画面签名 vs 实际像素」的只读对账**（把 `simulationChanged` 与
   `frameDiagnostics` 的 reused/redrawn 逐帧配成对），拿到「模拟变了但画面没变」的比例再动手；
   不许直接改 `continuousRuntimeFrame`。
3. S-36（campaign coverage 8 型 grep 判定）仍是现成的一条中等项，适合当伴生项。
