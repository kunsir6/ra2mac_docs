# FIX-30 挂机时内存爆炸（37 GB）——光标同步跑在 autoreleasepool 外面

**不是全屏的锅，也不是死锁。**用户报「游戏卡死」，实测是内存线性泄漏把整机 swap 死，
进程本身好好活着。第 28 轮之后的追加修复（同日，用户报障触发）。

## 1. 现场（先证明它没死）

进程还在（PID 92641，从 `dist/尤里红警.app` 启动），主线程采样栈：

```
runRuntimeApplication → runRuntimeWindow → runRuntimeWindowSession
  → runRuntimeSkirmishMenu  (1088/1594 samples)
      → MsgWaitForMultipleObjectsEx  (636)   ← 正常等事件
      → pumpEvents → syncGlobalCursorForPointer  (303)
```

主线程没有死锁，也没有在渲染里打转。但同一次采样里：

| 指标 | 值 |
|---|---|
| Physical footprint | **36.1 G → 37.1 G**（18 秒，≈57 MB/s） |
| DefaultMallocZone | **3,299,536 次活分配 / 37.1 GB** |
| Malloc Small 区域 | 9,589 个，共 37.2 G |
| Writable regions | swapped_out **37.0 G**（几乎全被换到磁盘） |

37 GB 被换出 → 整机每次换页都读盘 → 鼠标、窗口、Dock 全部假死。
**用户看到的是"机器卡死"，不是"程序卡死"。**

## 2. 根因：一行调用在 pool 外面

`compat/win32/src/RuntimeAppleWindowSurface.mm`（修复前 `:1995`）：

```objc
void pumpEvents() {
    if (gInputSink == nullptr || gWindow == nil) return;
    syncGlobalCursorForPointer();     // ← 在 pool 外面
    @autoreleasepool {
        ... nextEventMatchingMask / emit(event) ...
    }
}
```

`syncGlobalCursorForPointer()` 每轮问 AppKit 两件事，两件都产 autoreleased 对象：

- `[NSCursor currentSystemCursor]` → 内部 `SLSCopyRegisteredCursorImages` + `CGBlt_copyBytes`
  （采样里 11 个样本正卡在 `memmove` 拷光标图）；
- `[NSWindow windowNumberAtPoint:belowWindowWithWindowNumber:]` → SkyLight 侧
  `CGSPropertyListCreateWithSerializedBytes` 解析窗口 plist，产出成串 autoreleased 字典/数组。

而**本项目从不跑 `[NSApp run]`**（主循环是 compat 自己的 `GetMessageW`，见 MEMORY），
不存在「run loop 每轮自动 drain 一次 pool」这回事：线程根 pool 永不 drain。
于是每轮 pump 的临时对象只增不减。

菜单里 pump 由「`GetMessageW` 取不到消息」驱动，几毫秒一轮 → 每秒数百轮 × 每轮几十~几百 KB，
正好是实测的 13.6~57 MB/s 量级。

## 3. 改法（一行位置，20 行注释）

把 `syncGlobalCursorForPointer();` 移进 `@autoreleasepool` 内。语义不变：

- pool 只决定临时对象**何时**释放，不影响 `[blank set]` 这种立即生效的全局设置；
- `concordInvisibleCursor()` 是 `static` 自持有（`alloc/init` +1），不参与 autorelease，不会被 drain 掉；
- 系统 `set` 当前光标时会自行 retain，不存在 use-after-free。

顺带核对了同一文件里另外两处疑似泄漏，**结论是没问题**（已配对释放，不重复修）：

- `present()`（`:844`）整体已有 `@autoreleasepool`，`CGImageRelease` / `CGDataProviderRelease` /
  `CGColorSpaceRelease` 在 `:1171-1174` 配对齐全。

## 4. 验证（四组，全部真窗口挂机）

| 场景 | 20s | 60s | 120s | 240s | 斜率 |
|---|---|---|---|---|---|
| 修复前（arm64 build） | 533.8M | 1.1G | — | — | **13.6 MB/s，线性** |
| 修复后（arm64 build） | 321.9M | 397.9M | — | — | 1.8 MB/s |
| 修复后（arm64，4 分钟） | 323.9M | — | 552.8M | 582.3M | 2.3 → **0.25 MB/s，收敛** |
| **修复后（dist/.app 发布包）** | **99.3M** | — | **99.3M** | — | **0** |

- 第二组到第三组说明：修完后前 100 秒的 2.3 MB/s 是启动预热（字体/贴图/音频缓存），
  后 120 秒掉到 0.25 MB/s 且趋于平台——**不是线性泄漏**。
- 第四组是最重要的：**`dist/尤里红警.app` 里那一份二进制，120 秒内存一字不涨**。
- 回归：`bash ra2mac_docs/scripts/regress.sh` → `PASS=10 KNOWN-RED=1 RED-NEW=0`，
  与修复前基线逐条一致（`20261113-232017`）。

## 5. 为什么"感觉全屏更容易"

方向对，因果反了。全屏是**放大器**不是原因：

- 全屏后 surface 变大（像素多几倍），`present()` 每帧重建 CGImage 的开销同比放大；
- 全屏切换期间 `pumpEvents` 的有界超时从 2ms 放宽到 20ms（`:2012` 附近），循环更密。

窗口模式同样漏，只是慢一些、撑得久一些。这一点必须说清楚，否则下次会去查全屏代码。

## 6. 本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：没有在**遭遇战菜单**里做对照挂机（进那个菜单需要人点，没有 CLI 直达路径；
  用户那次的 37 GB 就发生在这里）。改用主菜单 + 同一 `pumpEvents` 路径验证——两者共用同一条
  `GetMessageW → pumpEvents` 链路，机制相同，但严格说这是"同链路"而非"同界面"。
- **遗留债**：`CGImageCreate` 每帧新建（`present()`）是设计选择（DIB 是同一块内存，缓存会冻帧），
  但 CA 侧对每帧新 image 的处理开销没有测过。若后续出现"长时间挂机后仍慢"，先查这条。
- **放弃了什么**：没有顺手把 `present()` 的诊断打印（`CONCORD_PRESENT_DIAG`）与 `[geom]`
  日志也纳入 pool 的显式清理——它们已有 pool 覆盖，且默认关闭，不值得为它增加改动面。
- **没做的另一件事**：没有改 `--skip-skirmish-menu`（那是 M-13/M-22 的线，与本缺陷无关）。

## 7. 留给下一轮的硬约束（已写入 MEMORY）

> **任何在每帧/每轮循环里调 AppKit 或 CoreFoundation 的地方，都必须确认自己在 `@autoreleasepool` 内。**
> 本项目没有 `[NSApp run]`，没有"run loop 帮你 drain"这回事；漏一个调用就是几十 MB/s 的泄漏，
> 而且症状是"整机卡死"，不是"程序崩溃"——极难从现象反推。
