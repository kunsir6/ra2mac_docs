# ON-2 前排 pending 现状对账（诊断轮，零代码改动）

- 时间：2026-11-11 06:44
- 基线：`ConcordRTS` HEAD = `cdad6ab`
- 性质：并发让路诊断轮。**零源码改动、零构建、零 queue 状态翻转**（只加 note/rule）。
- 目的：队首 pending 是 ON-2-02，但它与前排几条的关系是错位的。先把「已经做过的」「被前置卡住的」
  「文本本身已被更早提交实现掉的」分清，避免下一轮按 detail 盲做。

---

## 0. 本轮为什么不动代码

`.active` 是 `held / manual-continue / task=TBD / start=06:33:38`，pid 34694 已不存在（pid 会被回收，
不能作判据）。硬判据是 mtime：

| 观测 | 值 | 判读 |
|---|---|---|
| `.active` start | 06:33:38 | 对端开工时间 |
| `src/ui/selection/RuntimeSelectedPathRaster.h` | **06:35:20** | 晚于 start |
| `src/ui/selection/diagnostics/RuntimeSelectedPathRasterContract.inl` | **06:35:25** | 晚于 start |
| `build-product-mac/.ninja_log` | **06:44:03**（采样时刻 06:44:01 之后） | 构建仍在写 |
| `build-product-mac/.ninja_lock` | 06:35 出现、06:44 消失又重现 | 构建会话在重启 |

被改的两个文件正是 **S14b** 的 `touches`，对端在做 S14b（`firstDifference()` 取首个差异像素）。
按 `rules.lock`（held 且 mtime < 90min）与 `lock_gap_mtime_after_release`（源码 mtime 晚于 start 即并发），
本轮转 diagnose-only，连 `ninja -n` 都不跑。

---

## 1. 结论摘要

1. **ON-4-01 的代码已经存在于 HEAD**——`82af67d`（S14a）做的就是它 detail 里描述的那件事，
   逐字对应。这条任务的残余价值只有 verify，而 verify 被 S14b 的同一条断言链挡住。
2. **ON-2-02 的两个前提在今天的架构里都不成立**：present 不是「每个 EndPaint 都贴」，而是
   「每个 WM_PAINT 一次」；而「同一帧被贴多次」这件事已经被脏标志在**失效**层面合并掉了。
   唯一真缺的是显示节奏（vsync），而 vsync 需要先有帧循环（ON-4-03）。
3. **ON-2-03 的 ① 已经做完了**（HEAD 里 `contentsScale = backingScaleFactor` 已在，注释就写着 ON-2-03）。
   剩下 ② `Resizable` 与 ③ 「换界面尺寸」/「用户拖出来的尺寸」共用一个状态位——后者是真缺口。
4. **ON-3-01 是前排唯一「越早做越省」的任务**：present 处已有现成的 `CGImageRef`，回读成本接近零；
   而它决定 ON-2/ON-4 全部验收能否自动化。

---

## 2. 逐任务对账

| 任务 | HEAD 里已具备 | 真正剩余 | 判据（file:line @ cdad6ab） |
|---|---|---|---|
| ON-4-01 | **全部代码**：`Rectangle` 在 `pen.style != PS_SOLID` 时走 4 条 `strokeLine`，顺序右上→左上→左下→右下 | 仅 verify（被 S14b 挡） | `compat/win32/src/RuntimeWin32CompatGdi.cpp` 的 4×`strokeLine(corners[i], corners[i+1])` 循环 |
| ON-2-02 | 失效层合并（脏标志，一个窗口一个 bool） | ① 分母不存在（无帧循环）② 无任何显示同步机制 | `RuntimeWin32CompatUser.cpp:1019 InvalidateRect` 只置 `w->dirty`；`popMessage` 合成 WM_PAINT 时逐窗口看 dirty；`git grep CVDisplayLink/CADisplayLink` = **0 命中** |
| ON-2-03 | ① `contentsScale`；`contentsGravity=Resize`；`magnificationFilter=Nearest` | ② `styleMask` 只有 Titled\|Closable\|Miniaturizable（**无 Resizable**）③ 尺寸回写只有「surface 变了就 setContentSize」，没有「谁改的」来源位 | `RuntimeAppleWindowSurface.mm:103-104`（styleMask）、`:129`（contentsScale）、`:143-152`（尺寸回写） |
| ON-2-04 | ③④ 部分：`isMiniaturized → deminiaturize`、`SW_HIDE → orderOut`、Cmd+Q 菜单+键等价物 | ① 红叉：`pumpEvents` 里 `if (event.type == NSEventTypeAppKitDefined) continue;` 把关闭事件整类丢掉 | `RuntimeAppleWindowSurface.mm:429`（丢弃点）、`:265/:270`（最小化/隐藏） |
| ON-3-01 | present 处已有 `CGImageRef`，且已挂到 `layer.contents` | 全部：无 `presentHash`、无 `--onscreen-attest-smoke` | `git grep "onscreen-attest\|presentHash" HEAD` = **0 命中** |
| ON-4-03 | 无 | 全部 | 世界 45s 只有 2 次 present（05:42 实测），根因是没有定时器驱动的失效 |

---

## 3. present 的真实调用链（本轮最重要的一张事实）

```
app: InvalidateRect(hwnd)          → 只置 w->dirty = true，不画、不贴
app: GetMessageW 队列空            → popMessage 合成 WM_PAINT（逐窗口看 dirty）
DispatchMessageW → wndProc(WM_PAINT)
   └ BeginPaint → 产品绘制进 DIB
      └ EndPaint 路径 → present(surface)
            └ CGDataProviderCreateWithData(nullptr,...) + CGImageCreate + layer.contents = image
```

整条链只有**一个** `present()` 调用点：`RuntimeWin32CompatUser.cpp:999`。
`RedrawWindow(RDW_UPDATENOW)` 与 `UpdateWindow` 是仅有的两条「同步多贴一次」的旁路，
而且它们贴之前都看 `w->dirty`，`BeginPaint` 会清位——**同一次失效不会被贴两遍**。

推论：ON-2-02 detail 里「同一帧可能被贴多次」在当前实现下不发生；它描述的是**将来有帧循环之后**
才会出现的风险。当下真实问题是反过来的：**贴得太少**（世界 45s 两次）。

---

## 4. ON-3-01 的最小实现路径（省一轮的关键）

present 里已经算出了 `CGImageRef image`，但**不要**去 hash 这个局部变量——
那只是「我打算贴什么」。真正的自证对象是 `gView.layer.contents`，它是同一个 CGImage 的
`__bridge` 持有者：

```objc
CGImageRef attached = (CGImageRef)gView.layer.contents;   // 贴上去的那一张
```

把它 `CGContextDrawImage` 到一个 8bpp/32bpp 的 `CGBitmapContext`（bitmapInfo 必须与
`kSurfaceBitmapInfo` 一致，否则 R/B 互换，hash 永远不等），再算 FNV-1a，与同帧导出的 BMP
（`CONCORD_MENU_DUMP`，注意 BMP 是自上而下还是自下而上）对账。

这样断言的语义是「**屏幕上将显示的这一张** == 产品这一帧画出来的那一张」，
比「我创建的那张 == 产品画的那张」强一档，而且不需要屏幕录制权限。

两个已知坑（写进实现里以免踩第二次）：
- `layer.contents` 在 `[CATransaction commit]` 之后才稳定；commit 前读可能拿到旧对象。
- 同一帧的 BMP 导出点（`RuntimeWin32CompatUser.cpp:793` 的 `CONCORD_MENU_DUMP`）取的是 DIB 内容，
  与 readback 之间若隔了一次 present，帧号必须对齐，否则对不上的是帧不是像素。

---

## 5. ON-2-02 该怎么重写（下一轮若被选中，按这个做）

原 verify「游戏内 30fps 场景 submits/renderedFrames = 1.0±0.05」在**没有 30fps 场景**时不可测。
拆成两步，前一步无前置：

- **ON-2-02a（可立即做）**：`present()` 里一个计数器 + `atexit` 打印
  `presentSubmits=<n> paints=<m> elapsed=<ms>`；同时把「谁触发」分类（合成 WM_PAINT /
  UpdateWindow / RedrawWindow-UPDATENOW）。产出是**分母**，也是 ON-3-01 的输入。
- **ON-2-02b（必须排在 ON-4-03 之后）**：脏帧合并 + 与显示节奏对齐。
  目前 `git grep CVDisplayLink|CADisplayLink` = 0 命中，说明这块是全新代码，
  且 CVDisplayLink 在 macOS 15 已 deprecated，要走 SDK 条件分支。

---

## 6. 下一轮建议顺序（可直接照抄）

1. **ON-3-01**（上屏自证）。它不改行为、只加取证，冲突面最小，且是 ON-2-02a / ON-2-04 的验收工具。
2. **ON-2-03 + ON-2-04 合并一轮**（同一个文件 `RuntimeAppleWindowSurface.mm`）：
   加 `Resizable` + 把「换界面尺寸」与「用户拖动」拆成两个状态位 + 红叉走 WM_CLOSE→WM_DESTROY。
   验收用窗口级抓图（`screencapture -l <windowNumber>`，本机可用、不需屏幕录制授权）。
3. **ON-4-03** 帧循环，然后才轮到 **ON-2-02** 真做节流。

不建议下一轮直接做 ON-2-02：会花一轮去量一个分母为 2 的比值。

---

## 7. 本轮没有做的事（明说，免得下一轮误以为已做）

- 没有改任何源码；`git status` 仍是 S14b 的两个文件（对端在制）。
- 没有跑构建、没有跑产品、没有抓图（对端正在用共享 build 目录 + 窗口）。
- 没有翻转任何任务 status；只给 ON-4-01 / ON-2-02 补了 note，避免下一轮重做已存在的代码。
- 没有复核 S14b 的 `firstDifference()` 数字——那是下一个拿到独占构建的轮次的事。
