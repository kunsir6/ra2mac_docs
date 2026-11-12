# BUILD-03 游戏速度阶梯：最快档从"零等待"改成有限 1.5 倍

**日期**：2026-11-12
**背景**：用户回忆"20 年前机器越差游戏越慢"，本次分析确认根因是 retail 的"帧后等待"模型
（一帧周期 = max(算一帧耗时, 档位等待)）。我们的最快档照抄了 retail 的"零等待哨兵"，
于是**只有最高档仍然把速度绑在机器帧率上**。
**决定**：6 档改为**有限值 = 5 档 ×1.5**；不加"掉速提示"。

---

## 1. 改了什么

`src/runtime/timing/RuntimeGameSpeedTiming.h`

```cpp
// 0..5 档：retail 的 N 个 16ms 量子；6 档：把 1 个量子的等待再除以 1.5
const double effectiveQuanta = clamped >= 6 ? 1.0 / 1.5 : double(waitQuanta);
secondsPerTick = effectiveQuanta * 0.016 * 15 / fixedTickHz / 1.5;
```

- `unlimited()` 的语义收窄成"每拍墙钟配额为 0"——现在**没有任何档位**能进入这个状态
  （6 档也有 3.556ms/拍的配额），因此 `accumulate/ready/consume` 全部走有限的墙钟路径。
- `nativeWaitQuanta` 保留 retail 的原始量子数（6 档为 0），但**只作诊断**，不再影响调度。
- 主循环四处特判随之消失：表现预算的"用 5 档速率当无上限参考"、"无上限时余量服务不可用"、
  "无上限推进就不睡"——现在循环可以放心按帧截止时间睡，**这正是速度不再跟机器跑的关键**。

## 2. 新阶梯（30Hz 基）

| 档位 | 拍/秒 | 兵营 500 | 矿场 2000 | 光棱塔 1500 |
|---|---|---|---|---|
| 0 最慢 | 31.25 | 20.16s | 80.64s | 60.48s |
| 1 | 37.50 | 16.80s | 67.20s | 50.40s |
| 2 | 46.88 | 13.44s | 53.76s | 40.32s |
| 3 中 | 62.50 | 10.08s | 40.32s | 30.24s |
| 4 快 | 93.75 | 6.72s | 26.88s | 20.16s |
| 5 更快 | 187.50 | 3.36s | 13.44s | 10.08s |
| **6 最快** | **281.25** | **2.24s** | **8.96s** | **6.72s** |

严格单调，且 6 档恰好是 5 档的 1.5 倍（原来它是一帧顶满 16 拍、60fps 下约 960 拍/秒的悬崖，
且随机器快慢浮动）。

## 3. 契约同步（这一步是必须的：旧契约把 16 档钉死成"哨兵"）

| 文件 | 改动 |
|---|---|
| `tests/gameplay/RuntimeGameSpeedTimingSmoke.cpp` | 期望表扩到 7 列（15/30/60Hz）：最快档 7.111/3.556/1.778ms、141/281/563 拍/秒；新增"最快档 = 5 档 ×1.5""零墙钟批次必须不推进""七档严格单调"三条断言；延迟改用 1/3 量子为单位以表达 2/3 量子 |
| `src/simulation/abilities/chrono/diagnostics/RuntimeTemporalTimingSmoke.inl` | 速度循环 0..5 扩到 0..6；最快档段从"零等待哨兵 + 零墙钟批次"改成"有限 281 拍/秒 + 零批次不推进 + 一秒只给 281 拍" |
| `tests/rendering/RuntimePresentationWorkBudgetSmoke.cpp` | 去掉"6 档必须 maxTicks>1"（那是无上限路径的特征）；6 档的请求速率不再取 5 档的值 |
| `tests/rendering/RuntimePresentationBudgetRemainderSmoke.cpp` | 6 档不再走"无上限时间线必须逐位相同"，改为与其它档同一条"TPS 不得低于 min(requested, old)"契约 |
| `tests/infrastructure/host_loop/HostLoopContract.cpp` | 无需改：它按 `timing.unlimited()` 分支自洽（8864 项检查全过） |

## 4. 验证

- `CONCORD_COMMAND_SMOKE_CHRONO_EFFECTS_ONLY=1 --command-smoke-test`：
  ```
  Temporal speed: speed=0..6 scheduledTicks=31,38,47,63,94,188,281
  Temporal speed: speed=6 unlimited=no ticksPerSecond=281 batchCap=8  advancedTicks=8
  Temporal speed: speed=6 unlimited=no ticksPerSecond=281 batchCap=16 advancedTicks=16
  Temporal timing: passed ... speeds=7 ...
  ```
- `concord_presentation_work_budget_smoke` / `concord_presentation_budget_remainder_smoke`：均 PASS
  （后者 345 组比较、237 组启用余量服务）。
- `concord_host_loop_contract`：checks=8864 failures=0。
- 全量回归：**PASS=8 / KNOWN-RED=3 / RED-NEW=0**。

**没跑成的**：`concord_game_speed_timing_smoke` 需要零售 `gamemd.exe` 做字节级夹具，
本机数据根里没有这个文件（**改前就跑不了**，不是本次引入）。替代验证：
1) 期望值用独立 Python 复算（141/281/563、64/9·32/9·16/9 毫秒全部对上）；
2) 30Hz 那一列由 chrono 冒烟端到端跑出实际调度拍数（281/188），与契约表一致。

## 5. 副作用与注意

- 6 档现在比原来**慢很多**（原来 60fps 下约 960 拍/秒，现在 281）。这是刻意的：
  旧值既不忠于 retail（retail 是每帧 1 拍），也让速度随机器浮动。
- 循环在最快档也会按帧截止时间睡眠，CPU 占用应下降；若有"最快档不够快"的反馈，
  应该调 `pacingMultiplier` 或 6 档倍数，而不是恢复零等待。
