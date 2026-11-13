# FIX-16 登船互锁：把「转移没开始」拆成四道门

- 轮次：2026-11-13 第 15 轮
- 基线：`PASS=10 KNOWN-RED=1 RED-NEW=0`（`progress/regress/20261113-095359`）
- 收口：`PASS=10 KNOWN-RED=1 RED-NEW=0`（零新回归；本轮只加只读计量，产品行为零改动）
- 源码提交：`94fbc71` test: 两栖登船加拒绝原因位
- 关联条目：C-02（`command`，唯一 remaining known-red）

## 1. 症状与旧口径

`command` 停在：

```
twelve infantry did not board: aboard=10/12 pending=2 status=moved #5 to 15,15
```

计划里对它的定性只有一句「12 名步兵登 LCRF 只上 10 名，2 名停在 15,15 不进舱，原因未定」。
这句话把**四种完全不同的失败**压成了一个数字：

1. 压根没有候选登船格（passability / 地形层 / 子格 / 寻路）；
2. 有候选格但「接近身体不空」（`runtimeTransportBoardingAccessBodyClear`）；
3. 到了最后 1 格，但转移三道门（transition / foundation / bodies）任一不过；
4. 转移时长为空（`runtimeTransportMotionTransferTicks` 返回 0）。

更糟的是，`advanceRuntimeUnitTransportBoarding` 原本把
`beginRuntimeTransportGroundTransfer(...)` 的返回值 **`(void)` 丢掉**（第 11681 行），
于是「转移被拒」与「还没走到」在调用方看来完全相同——单位会保持 Move 行为永远等下去，
日志里只剩下一句 `status=moved`。

## 2. 本轮改法（只读，`CONCORD_TRANSPORT_TRACE=1`）

`src/runtime/session/RuntimeSessionNavigation.cpp`：

- 新增 `runtimeTransportTraceEnabled()` / `traceRuntimeTransportBoarding()`：
  同一个人同一个原因**只打一次**，否则每拍刷屏（12 人 × 每秒 30 拍）。
- `runtimeAmphibiousTransportAccessCell`：五个候选格拒绝点各给一个原因
  （`access:impassable` / `access:level` / `access:subcells` / `access:path` / `access:body`）。
- `beginRuntimeTransportGroundTransfer`：把原来合在一起的
  `A || B || C` 拆成三条独立 `if`，分别报 `transfer:transition` / `transfer:foundation` /
  `transfer:bodies` / `transfer:ticks`。
- `advanceRuntimeUnitTransportBoarding`：把被丢弃的返回值接住，
  另加 `boarding:host-busy` / `boarding:same-cell` / `boarding:transfer-refused`。

零行为改动：全部代码在 `if (!traceEnabled) return;` 之后，关掉环境变量只剩一次
`static bool` 读。

## 3. 读数

```
CONCORD_TRANSPORT_TRACE=1 ... --command-smoke-test
```

21 条首现记录，去掉前面坦克段后的关键段落：

```
[transport-trace] transfer:bodies id=9  at=15,15 hull=16,16 why=another ground body is inside the sweep corridor
[transport-trace] boarding:transfer-refused id=9  at=15,15 hull=16,16
[transport-trace] access:body id=9  at=15,15 hull=16,16 why=approach body not clear
[transport-trace] transfer:bodies id=12 at=15,15 hull=16,16
[transport-trace] boarding:transfer-refused id=12 at=15,15 hull=16,16
[transport-trace] transfer:bodies id=11 at=15,15 hull=16,16
[transport-trace] boarding:transfer-refused id=11 at=15,15 hull=16,16
[transport-trace] transfer:bodies id=10 at=15,15 hull=16,16
[transport-trace] boarding:transfer-refused id=10 at=15,15 hull=16,16
```

四条独立读数，指向同一件事：

- **不是寻路问题、不是地形层、不是子格耗尽**——`access:*` 里跟这四人相关的只有 `access:body`，
  说明格子合法、路径存在、子格也有（否则会是 `access:subcells`）。
- **四个人停在同一个格子 (15,15)**。地面步兵一格四子格，四人同格完全合法。
- 卡住的那道门是 `transfer:bodies`：`runtimeTransportTransferBodiesClear` 的
  foot-to-foot 最小间距是 **0.5**（第 11533 行），而同一格里四个人的子格偏移彼此相距不到 0.5，
  于是**每个人都在别人的扫掠走廊里**——谁也不能先动，互相锁死。
- `access:body` 是同一件事的另一面：退到「按候选格接近」这条路上也过不去，
  因为 `runtimeTransportBoardingAccessBodyClear` 同样把同格的同伴当障碍。

也就是说：**先到的 10 个人是在格子还没挤满时逐个进的；后到的 4 个人同拍到达同一格，
从此互锁**。这不是「12 人上 10 人」的容量问题，是**同格排队没有优先级/没有让位**。

## 4. 为什么本轮不动手

两种改法方向相反，且都要碰模拟层入口排队：

- **A（让位/串行化）**：同格等待者按 id 或到达顺序只放一人进转移，其余等下一拍。
  代价小，但「谁先」需要一条确定规则，否则冒烟会变成非确定性。
- **B（不算障碍）**：`runtimeTransportTransferBodiesClear` 对「同样是这艘船的等待乘客」放行
  （它们本来就是排队者，不是路障）。语义上更贴近零售，但会放宽一条被坦克段依赖的身体互斥规则
  （坦克段 `aboard=4` 正是靠它避免叠车），必须先证明不破坏坦克段的相互间距断言。

C-02 在计划里是「复杂」，按纪律单独成轮、先写方案；本轮把它的根因从一句话拆到这条门，
下一轮起手就有确定入口（不用再猜）。同时本轮已经用掉大部分预算在构建与读数上，
按「T+45 之后不再启动产品逻辑改动」收口。

## 5. 下一轮起手

1. 先在 `runtimeTransportTransferBodiesClear` 加第二个只读位：把
   「被谁挡住」（other id / kind / 与扫掠段的距离）打进同一行 trace，
   确认挡住 id 9 的就是 id 10/11/12（同格同伴），而不是某个还没上船的外部单位。
2. 若确认是同伴互锁，取 **A**：在 `runtimeAmphibiousTransportAccessCell` /
   `beginRuntimeTransportGroundTransfer` 之间加一条「同一 host 的整船转移，每拍只放一人」的准入
   （用 `pendingTransportTargets` 里的 host 分组，按 instanceId 排序取最小者），
   并补一条反向断言：「同格四人必须在有限拍内全部进舱，且不许叠车」。
3. 坦克段（`aboard=4`、`exits` 互不重合）必须跟着跑，任何放宽 `bodiesClear` 的改法都要它先绿。
