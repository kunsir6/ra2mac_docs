# FIX-19 卸载终态：不是「有人卡住」，是「先出来的人把环占满」

- 轮次：2026-11-13 第 18 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-124323`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-125134`，产品行为零改动）
- 源码提交：`ff5cad2`（test: 卸载遮挡读数补「挡住者自身状态」与时间桶）
- 关联条目：C-02c（唯一 remaining known-red 的唯一阻塞点）
- 关系：**推翻并更正 `reports/FIX-18-整仓卸载的八格拒绝表.md` §3 的结论**

## 1. 上一轮错在哪

FIX-18 读到

```
unload:bodies id=7 other=13 ticks=66/66 cooldown=66 path=0 render=15.75,16.25
```

就下结论「第一具出舱者停在船体原点没走开」。**这是把首次命中时刻当成了终态。**
`ticks=66/66` 不是「冻住」，是「还没跑第一拍」——egress 刚被创建的那一瞬间。
去重键只含「人 + 格子 + 原因」，所以这一行永远只代表 egress 的第一拍。

## 2. 改法（仍是只读）

`ff5cad2` 两处：

1. `noteBlocker` 里补出**挡住者自己**的状态：
   `bstate / bkind / transfer / ticks=remaining/total / path / target / cooldown / blocked / render`。
2. `traceRuntimeTransportUnload` 的去重键加 **120 拍时间桶**，行首打 `tick=`。
   只按「人+格子+原因」去重，读到的是首拍；加了时间桶才能看出「原地不动」还是「在推进」。

## 3. 修正后的读数（tick=1680，600 拍等待的末尾）

```
unload:bodies tick=1680 id=7 cell=17,16 other=2  kind=infantry cell=17,16 dist²=0.0096 moving=0 bstate=none render=17,16
unload:bodies tick=1680 id=7 cell=16,17 other=4  kind=infantry cell=16,17 dist²=0.1538 moving=0 bstate=none render=16,17
unload:bodies tick=1680 id=7 cell=16,15 other=12 kind=infantry cell=16,15 dist²=0.0294 moving=0 bstate=none render=16,15
unload:bodies tick=1680 id=7 cell=17,15 other=3  kind=infantry cell=17,15 dist²=0.0662 moving=0 bstate=none render=17,15
unload:bodies tick=1680 id=7 cell=15,17 other=9  kind=infantry cell=15,16 dist²=0.1250 moving=0 bstate=none render=15,16
```

三件事一次看清：

1. **挡住者全是已经出舱的自己人**（id 2/3/4/9/12），`moving=0`、`bstate=none`
   —— 它们没有行为了，就站在那儿。
2. **它们是「每个邻格一个」**：`cell` 与 `render` 逐格对应（17,16 / 16,17 / 16,15 / 17,15 / 15,16 …）。
   8 个邻格全被占 → 最后一个 `id=7` 找不到任何一条起点干净的走廊。
3. 位置是**格子中心**（`render=17.000000,16.000000`），不是子格偏移点。
   而走廊的终点就是格子中心 → 0.5 的 foot-to-foot 判定一定命中。

也就是说：**11 个人出去了，第 12 个出不去**。这不是「谁卡住了」，是「先出来的站满了环」。

## 4. 为什么会站满（结构性原因）

`unloadRuntimeUnitTransportMotion` 里，外侧终点只在**非两栖**船上才规划：

```cpp
std::vector<RuntimeCellPoint> remainingPath;
if (!runtimeAmphibiousTransport(state, host)) {
    … 半径 2 搜一个可走外侧终点 …
}
```

两栖船 `remainingPath` 永远为空，代码注释也写明了这个取舍：

> The first physical exit is reserved immediately; its later outer goal is not.

于是两栖卸载 = 「从船舱跨一格到环上，然后停住」。8 个邻格、每格又只有 0.5 间距的身体互斥
（子格是 0.5 一格，斜向 0.35 < 0.5），实际能站下的人远少于 8×4 个子格的名义容量。
12 人满仓卸载必然在这里撞墙。

## 5. 两条候选改法与取舍

| 方案 | 做法 | 代价 / 风险 |
|---|---|---|
| **A（外侧终点，推荐）** | 让两栖卸载也规划半径 2 的外侧终点（下船后走开），环自然会被腾空 | 需要处理「船停在纯水面时半径 2 全是水」的情形：先搜陆地方向，全水就退回现在的就地停靠。零售语义就是下船后跑开，改对了行为才像原版 |
| **B（放宽出舱走廊）** | 出舱方向对「站着不动的自己人」放宽 0.5 判定（与 C-02a 同族，角色反过来） | 代价小，但只是把「站满」的临界点推后：12 人能下，13 人又会撞。且会让两个步兵在环上视觉重叠 |

倾向 A。理由：B 治的是阈值，A 治的是「出来之后该走开」这件产品语义。
而且本夹具的船停在陆地（16,16 一圈都是可走地），A 会直接转绿；真实场景里船靠岸时
也总有一侧是岸。

## 6. 下一轮起手（C-02c 第三步）

取 A，动手前先补两个只读位（不要直接改逻辑）：

1. 两栖卸载时，把半径 2 的 16 个外侧格里「不可走 / 已被占 / 可用」各计数打一行
   —— 确认本夹具里可用格子数 ≥ 12（若不足，说明夹具把船停在纯水里，A 也得配保底策略）；
2. `bstate=none` 的站定者，`subCell` 是多少（`-1` 还是真子格）。若是 `-1`，
   说明出舱挑不到子格时退化成格子中心，这才是「一站就封掉整格」的直接原因，
   A 之后仍要修这一处。

判红口径不变：12 名步兵在有限拍内全部下船，且 `infantrySlots`（格子 + 子格）互不重合。

## 7. 纪律复盘

- **「首次命中」不是终态**。任何「同 id 同原因只打一次」的去重，都会把第一次读数
  伪装成结论；凡是要判「卡住/冻住」，去重键里必须有时间维度。
- 同一段冒烟有「堵住 / 放开」两个阶段（FIX-18 已踩过一次），这次又在同一段栽在时间维度上。
  教训合并成一句：**读数必须能回答「这是第几拍」**。
- 上一条结论写进报告后就带着报告的可信度传播了，所以这次在 FIX-18 顶部加了更正横幅，
  而不是只在本文里说「上一轮错了」。
