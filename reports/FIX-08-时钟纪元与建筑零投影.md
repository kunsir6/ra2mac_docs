# FIX-08 时钟纪元与建筑零投影：两条「一句判红」的拆解（第 7 轮）

> 2026-11-12 · 自动化第 7 轮
> 主题：`known-red.tsv` 里还剩两条标着 `code-red:needs-metering` 的条目（`result` / `render`），
> 它们的共同特征是「只红一句话，元凶未定」——本轮先拆输出再定性，产品逻辑零改动。
> 结果：**`result` 转 PASS**，回归 `PASS=7 KNOWN-RED=4` → **`PASS=8 KNOWN-RED=3`**，`RED-NEW=0`。
> `render` 仍红，但红的原因第一次被钉死为**产品缺陷**（建筑不投影），并拆出 M-18 单独跟进。

---

## 一、M-17 `result` 记分动画「卡在暂停帧缓存」—— 其实是两个时钟纪元

### 现象

```
Result presentation smoke failed: original score animation stalled behind paused-frame cache
  score probe Americans changed=0(need>=1000) tick=300/300 frames=6/6 saved=yes
```

三个子条件（tick 未推进、帧计数 +1、截图已落盘）全部正常，只有**画面没变**。
上一轮的判断是「要么没重绘，要么时间源冻结」，并已排除前者（缓存门里带着
`&& !runtimeResultScoreIsAnimated(*state)`，此刻该谓词为真）。

### 根因

记分页取动画进度用的是 `runtimeUiClockNow(state)`：

```cpp
// RuntimeShell.cpp（记分页绘制）
const ULONGLONG now = runtimeUiClockNow(state);
const ULONGLONG elapsedMs = runtimeUiScoreElapsed(
    now, state.campaignScore.presentationStartedAtMs, 3000ULL);
```

`runtimeUiClockNow` 在 macOS 上取 `CLOCK_MONOTONIC`（开机以来的毫秒）。
而探针是用 `GetTickCount64()` 写「650ms 之前」这个起点的：

```cpp
// 旧探针
state.campaignScore.presentationStartedAtMs = GetTickCount64() - 650;
...
state.campaignScore.presentationStartedAtMs = GetTickCount64() - 1600;
```

两个调用**在 macOS 上不是同一个纪元**（`GetTickCount64` 由 compat 层另行实现）。
于是 `now - presentationStartedAtMs` 在两次绘制里都是一个巨大的正值：

```cpp
constexpr RuntimeUiTimeMs runtimeUiScoreElapsed(now, start, fallback) {
    return start == 0 || now < start ? fallback : now - start;
}
```

`start` 远小于 `now` → 走 `now - start` → 两次都远超动画时长 → **两次都钳在末帧** →
两张位图逐像素相同 → `changed=0`。这不是「缓存冻帧」，是「两次都画了同一张最后一帧」。

### 改法

探针改用渲染侧所读的那个时钟构造起点，产品侧零改动：

```cpp
const RuntimeUiTimeMs scoreClockNow = runtimeUiClockNow(state);
state.campaignScore.presentationStartedAtMs = scoreClockNow - 650;
...
state.campaignScore.presentationStartedAtMs = scoreClockNow - 1600;
```

### 验证

```
Paused score animation Americans: changedPixels=23872 tick=300
Paused score animation Russians: changedPixels=24486 tick=300
Paused score animation YuriCountry: changedPixels=34795 tick=300
```

阈值 1000，实测两万以上；`tick` 仍冻结在 300（暂停态没有推进模拟）。
`result` 整条转 PASS → `4cdc891`（`test:`，因为改动全在冒烟侧）。

---

## 二、S-06 `render` 阴影 `structures=0` —— 拆开后才看出是「建筑零投影」

### 现象与一处自相矛盾

```
Shadows: candidates=7 drawn=5 pixels=2966 shp=5 structures=0 units=0 infantry=0 aircraft=0
Render smoke test failed: natural-map shadow pipeline did not draw its visible SHP/structure coverage.
```

`drawn=5` 却四个 kind 计数器全是 0 —— 这在只看一行的口径下是**不可能**的读数。
原因是地形树木（`WorldTerrainObject`）的软阴影也记进 `shadowsDrawn`，
但树木不属于 `Structure/Unit/Infantry` 三态枚举，**没有任何 kind 计数器接住它**。
所以 `structures=0` 只能证明「没有建筑阴影」，不能说明建筑是「没进候选」还是「进了但没画」。

### 计量

在 `recordRuntimeWorldObjectShadowResult` 里补两个只读计数：

- `structureShadowCandidates`：该结构是否进过地面阴影通道（`result.candidate`）；
- `structureShadowEmptyMasks`：掩码解析成功（`result.shpMask`）却压暗 0 像素。

```
Shadows: candidates=7 drawn=5 pixels=2966 shp=5 ... structures=0
         structureCand=2 structureEmpty=2
```

### 定性

`structureCand=2` → 两栋可见建筑**都进了**通道（不在视口外、没被可见性/伪装/桥上判定挡掉）；
`structureEmpty=2` → 两栋的**授权阴影掩码都「解析成功」**，却一个像素都没压暗。

而 `structureEmpty==0` 本来是不会发生的：`validMask` 为假时会退到
`drawRuntimeObjectSoftShadow` 软阴影兜底，那条路径必然压暗像素。所以走到
「`shpMask=true` 且 `darkenedPixels==0`」只有一种可能——**掩码本身是空的**
（`drawRuntimeShpShadowFrame` 返回真但一个 span 都没落，例如该帧像素全是 0 / 落在裁剪外）。

结论：**建筑根本没有影子**，这是产品缺陷，不是相机可见性、不是候选被前置挡掉、
也不是断言口径错。已登记为 **M-18（中等）**，修法要先在掩码侧再拆一层
（`shadowImage` 的宽高 / 像素非零数 / span 数 / 阴影中心与 viewport 的关系），
按「先量再改」的纪律不在本轮动手。计量代码 → `06c8ea2`。

---

## 三、回归

| 项 | 开工基线 | 收工 |
|---|---|---|
| PASS | 7 | **8** |
| KNOWN-RED | 4 | **3** |
| RED-NEW | 0 | **0** |

剩余 3 条 known-red：`interaction`(M-12 可见性门) / `render`(M-18 建筑零投影) / `command`(C-02 两栖)。

---

## 四、教训

1. **「两个时钟相减」是最隐蔽的一类假红。** 只要有 `X - Y`，先确认 X 和 Y 出自同一个 provider；
   `GetTickCount64()` 与 `runtimeUiClockNow()` 在 macOS 上纪元不同，相减不报错、只给巨大值，
   再被 `runtimeUiScoreElapsed` 的钳位吃掉，症状与「缓存冻帧」一模一样。
2. **一处 `drawn=5 但 kinds 全 0` 就该立刻停下。** 分类计数器之和必须能对上总数，
   对不上说明有第二套记账口径混进来了（本次是地形树木），此时那一行的
   「`structures=0`」是**算术上无法解释**的，不能拿它当证据。
3. 连续两轮都是「先拆输出比先动手值钱」：M-14/M-12（第 5 轮）、本轮 M-17/S-06。
   一句 `stalled` 或 `structures=0` 压掉了七八个谓词，拆开才知道原描述是错的。
