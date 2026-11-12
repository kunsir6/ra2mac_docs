# FIX-15 框选结案与两栖卸载的真阻塞点

日期：2026-11-12（第 14 轮）
范围：M-02 结案、C-02 阻塞点后移、S-08/M-03 方案（本轮不动手）
回归：`10/1/0` → `10/1/0`，`RED-NEW=0`；产品行为零改动（三条 `test:`）。

---

## 一、M-02 结案：不是缺陷，包围盒 = 画面 ±3px

第 13 轮已经把 `interaction` 的框选断言改成走真实消息循环（`07e6a71`），并量出
`bbox=4 center=3 bboxOnly=1`。本轮补上**画面矩形**这一维，读数把问题彻底定死：

```
Box drag (message loop): band=8,8 513,632 bbox=4 center=3 bboxOnly=1 artOutside=0 artOnly=0 picked=4
Box drag bbox-only units: #9003(503,481 561,523 art=506,484 558,520 artInBand=7px x103,99)
```

三件事同时成立：

1. **命中框就是画面框外扩 3px**：`bounds=(503,481,561,523)`、`art=(506,484,558,520)`，
   四边各差 3。来源在 `RuntimeShell.cpp` 的投影段：
   `screenObject.bounds = screenObject.selectionBounds`，而
   `selectionBounds = runtimeUnitSelectionBoundsForSprite(spriteBounds)` =
   `InflateRect(+3,+3)`。
2. **`spriteBounds` 就是真实画出来的像素框**，不是精灵帧外框：
   `RuntimeUnitSelectionAlignmentSmoke` 对全部步兵/载具/飞行器 × 5 姿势 × 8 朝向 ×
   3 种 tileWidth 断言 `spriteBounds == probe.renderedBounds`，而
   `renderedBounds` 是把对象单独渲进离屏 DIB、逐像素标「哪些点真的变了」得到的。
3. **那个「只擦了 10px」的单位，画面真有 7px 在框里**：`artInBand=7px`。
   它不是透明留白，是坦克车体的左边缘。

所以「框在它旁边却把它选中」= **玩家框线压到了车体边缘**，属于零售同款的擦边容差，
不是坐标错位、也不是幽灵框。台账里那句「框选用世界坐标、投影用表面坐标」从第 13 轮起
就被证伪，本轮补完最后一块。

### 留下什么

一条反向判据（`e7cbfa8`）：

```cpp
if (!boundsExpandedIds.empty()) {
    // 有单位「命中框进框、画面不进框」→ 命中框不再是画面 +3，而是固定尺寸幽灵框
    ... fail("box drag selected units whose artwork is outside the band (phantom hit box)")
}
```

今天它恒为空（`artOutside=0`）。它防的是历史上真出现过的那类缺陷：**固定尺寸的幽灵命中框**
（代码注释里写着 "No fixed-size phantom box remains"）。哪天有人改回固定框，这条立刻红。

## 二、C-02：卸载断言口径错了，真阻塞点后移到装船

`command` 一直红在 `shore unload left tanks aboard`。本轮读完
`unloadRuntimeUnitTransportMotion`（`RuntimeSessionNavigation.cpp:11714`）后定性：

```cpp
// 一趟只放一个人/一辆车
if (!beginRuntimeTransportGroundTransfer(...)) continue;
cargo.erase(std::remove(cargo.begin(), cargo.end(), id), cargo.end());
accepted = true; ++unloaded; break;
...
if (accepted) break;   // "Later cargo waits on real body clearance, not a fixed delay."
```

- 卸载是**逐人推进**的：一次 `executeRuntimeSecondaryAction` 只放一个，剩下的靠
  `advanceRuntimeTransportUnloading` 每拍再调一次，等前一个真让出机身空间。
- 这是有意的设计（注释写了「不靠固定延迟，靠真实机身让位」）。
- 而冒烟在 `executeRuntimeSecondaryAction` 之后**同步**断言 `transportPassengerIds.empty()`——
  一次点击要 4 辆车全下船，结构上不可能成立。这就是那条红了十几轮的 known-red。

改法（`3e51fd0`）：卸载后按拍推进到空仓（上限 `hz*20`），仍以「放不空就失败」保住原意：

```
if (!host->transportPassengerIds.empty())
    return fail("shore unload left tanks aboard after N ticks: <status>");
```

### 推进到哪了

3 条船型（LCRF/SAPC/YHVR）× 30/60Hz 的**坦克段全绿**（含深水拒卸、跨水、save/load、
生命/老兵度保持），失败点落到混编段的装船：

```
twelve infantry did not board: aboard=10/12 pending=2 status=moved #5 to 15,15
```

同一个病根在装船侧：`board()` 的退出条件是 `pendingTransportTargets.empty()`，
而它只代表**订单已受理**，不代表人已进舱。改成等「每个人都在乘客表里」（`3e51fd0`，
同一条 commit）后，读数变成 10/12 卡住——这不是断言口径，是**真有两个人停在舱门口进不去**：
一个在 `15,15`（贴着 (16,16) 的船），另一个排在它后面。

`known-red.tsv` 已按新事实改行（第 4 列前缀同步改成 `twelve infantry did not board`，
否则会被判 `RED-NEW(cause-changed)`）：

| 列 | 新值 |
|---|---|
| 原因 | 原阻塞已修；现阻塞后移到混编段，12 名步兵登 LCRF 只上 10 名，2 名停在 15,15 不进舱，原因未定 |
| status | `code-red:needs-metering` |
| 前缀 | `twelve infantry did not board` |

**下一轮第一件事**：在 `runtimeTransportBoardingAccessBodyClear` /
`beginRuntimeTransportGroundTransfer` 的拒绝分支上按 id 记「第一个人为什么被拒」——
是舱门口 subcell 被同伴占了（容量 12 但门口只有 2 格），还是 `hullClearance` 把
1.0 的邻格判成「太近」。这两者改法相反：前者是入口排队策略，后者是几何阈值。

## 三、S-08 / M-03：只写方案，理由写在下面

既然要动的是**呈现层的重绘提交条件**，按纪律先给方案、单独成轮。本轮已把机制钉到行：

`RuntimeShell.cpp` 主循环（~90245）：

```cpp
advanceRuntimeUiPresentation(state);
if (tickAdvanced) state.repaintRequested = true;          // ← 只要模拟推进就要求重绘

const bool continuousRuntimeFrame =
    state.world.getSummary().loaded && !IsIconic(window);  // ← 进图后无条件
if (state.repaintRequested || continuousRuntimeFrame) {
    paintQueued = InvalidateRect(window, nullptr, FALSE) != FALSE;   // 全窗口脏区
}
```

也就是说：**进图后每一帧都整窗重绘**，与「画面有没有变」无关。`reuseCachedFrame`
只在 `!repaintRequested` 时成立，而 `tickAdvanced` 每帧都为真，于是那条缓存永远走不到。

### 两条候选路线与各自的坑

**A. 场景签名门（推荐先试）**
每拍算一个廉价签名（tick + 相机 + 每个对象的位置/朝向/帧号 + 选中集 + 资源数 + 遮罩版本），
签名不变就不置 `repaintRequested`。坑：
- 漏一个字段就是**冻帧**（本项目有前科：呈现层缓存 CGImage 被去重，屏幕冻在第一帧）；
- 必须留「每 N 帧强制重绘一次」的兜底，N≈30（半秒），把漏字段的后果从「永久冻」降到「半秒延迟」。

**B. 像素差量门（保守）**
画完一帧后对后台缓冲采样哈希，连续 K 帧相同就暂停 `InvalidateRect`，靠输入事件
（`repaintRequested` 由输入处理器置位）与 N 帧兜底唤醒。坑：
- 它有**自抑制**风险：推动画的是重绘本身，一旦停就不再产生新像素，永远等不到「不同」；
  所以只能用于「模拟仍在跑但画面已静止」的判定，且必须同时看 `tickAdvanced`；
- 哈希要采样（每 97 个 dword 取一个），否则 1024×640 全量哈希本身就把省下来的 CPU 吃掉。

**C. 只做计量（本轮实际建议的落点）**
把「本帧是否 reuse」「连续相同帧数」「每秒 Invalidate 次数」打进已有的
`RuntimeFrameDiagnostics` 周期输出，先拿到 idle 下的真实比例，再决定 A/B。
理由：本项目已经因为「先改后量」翻车过多次（M-18 六轮、M-10 负数预留），
而这条改动的失败形态是**屏幕冻住**，代价最高。

结论：本轮**不动产品**；下一轮按 C → A 的顺序做，先出读数再动提交条件。

## 四、本轮提交

| hash | 说明 |
|---|---|
| `e7cbfa8` | test: 框选补反向断言——被选中的单位画面矩形必须真进框 |
| `3e51fd0` | test: 两栖冒烟按拍等待装船/卸载——两者都是逐人推进 |

回归 `10/1/0` → `10/1/0`（`20261112-203839`），`RED-NEW=0`。
