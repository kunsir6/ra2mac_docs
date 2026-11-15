# FIX-57 构建与回归的「自证」：S-30 + S-29

> 轮型：**修复轮**（无 brake、无 attempts≥3 在办、无腐烂预算、距 AUDIT-56 一轮）。
> 主目标：**构建与回归的自证** —— 现有判据只证明「跑了什么」，不证明「跑的是谁」。
> 伴生：`pack-dist.sh` 组装前把构建树状态摊到屏幕上。

---

## 一、S-30 构建状态损坏没有检测

### 现象

`ninja -C build-product-arm -n` 要求重建 **1647/1647** 个目标，同一时刻 `build-product-x86_64` 报
`no work to do`。`-d explain` 首行是：

```
ninja: warning: premature end of file; recovering
ninja explain: stored deps info out of date for '…/IniFile.cpp.o' (1794364742251877435 vs 1794733527296708933)
```

R41~43 连续三轮把这条现象读成「并发改了 cmake 触发重配」，于是三轮都放弃源码修复。

### 根因

`.ninja_deps` 尾部被截断（疑为两个会话同时在同一构建目录跑 ninja，追加写互相踩）。
ninja 启动时会「恢复」到最后一个完整记录，**但恢复只发生在读侧**：丢掉的那些边在它眼里就是
「deps 未知 → 必须重编」。于是整目录全量。

判据必须两条一起看，缺一条就会误判：

1. 本目录出现 `premature end of file; recovering`，且脏因是 `stored deps info out of date`；
2. **另一个构建目录同一刻干净**（真改了编译参数/全局头文件的话两个目录会一起失效）。

### 改法

新增 `ra2mac_docs/scripts/build-health.sh`（只读，只跑 `ninja -n`，不构建、不改文件）：

| 状态 | 触发条件 | 含义 |
|---|---|---|
| `clean` | `no work to do`，或待办 ≤30% | 可以放心增量 |
| `WARN` | 待办 >30% 但没有截断告警 | 可能真改了大范围头文件，也可能是别的怪因 |
| `CORRUPT` | 有截断告警 / `ninja -n` 自身非 0 | 别归因于参数，先修状态 |

退出码 0/1/2 对应三态，脚本把自己也当门禁用。接了两个入口：

- `regress.sh` 预检：报告头多一行 `警告 构建树状态不是 clean`（**退出码不变**，只报不拦）；
- `pack-dist.sh` 组装前：`buildtree clean` / `buildtree WARN —— 构建树不是 clean 状态`。

### 一条被证伪的旧结论（本轮最重要的发现）

R44 写进备忘的「状态坏掉后只能付一次全量把它修回来」**不成立**。实测:

1. 19:19–19:23 跑了完整全量，`1647/1647` 成功（4 分 10 秒）；
2. 重编完 `build-health.sh` 仍报 `CORRUPT`——截断告警照旧；
3. `-d explain` 显示记录里的 mtime 仍是 **11-11** 的（`1794364742…`），而 `.o` 已是 19:19；
   即：**产物重建了，deps 记录没重建**；
4. `ninja -t recompact` 把文件 10.4MB→6.5MB、告警消失，但待办仍是 1647/1647——只消了告警，没修记录；
5. 真修法：删 `.ninja_deps` + `.ninja_log` 再全量重建，之后 deps 记录才重新写出来
   （备份在 `/tmp/ninja_deps_broken_1924.bak`）。

**机制未逐行读 ninja 源码验证**（此处只记实测事实）：我的推断是在被截断的日志上「恢复」后继续追加，
新记录落在旧偏移之外，读侧按键取到的仍是旧记录，于是永远判过期。这条推断可被下一步证伪：
修好后人为截断尾部 → 若「再全量」又能修回来，说明推断错。

教训与 MIN_MACOS、EVO-07 ⑨ 同源：**只查一侧的判据会把另一侧变成永久盲区**。
「全量成功」证明的是产物新鲜，不证明状态健康。

---

## 二、S-29 回归报告不记源码版本

### 现象与根因

`report.md` 头只写二进制路径 + sha256(前 16) + mtime。这三样能证明「两次测的是同一份文件」，
证明不了「这份文件对应哪个提交」。于是 R56 审计要靠**反推**才发现：dist 里的二进制编译于
17:05:54，HEAD 提交时刻 17:05:22 —— 678 行未提交改动被烘进了发行物，而期间每一份回归报告
都「看起来」是在测 HEAD。

### 改法

`regress.sh` 在取指纹处补一段源码指纹，取值只有两步，不需要新工具：

- `git -C ConcordRTS rev-parse --short HEAD` + `git log -1 --format=%cI` + `status --porcelain` 行数；
- 二进制自己报的 `--version` 里 `compiled:` 与 `arch:`（EVO-07 第一步的产物，终于有人用）。

判定：`compiled > HEAD 提交时刻 + 5s` → 标签写成 `<hash>+WIP`，并在控制台与报告里各打一条 WARN。
阈值取 5 秒是保守的：宁可把「刚编完又刚提交」误标成 WIP，也不要把 WIP 说成干净 HEAD。

### 验证（实跑读数）

```
- 源码 `b4672b5+WIP`（提交时刻 2026-11-15T17:05:22+08:00）工作区 dirty=15
  被测二进制自报 arch=arm64 compiled=Nov 15 2026 19:20:04
- 警告：被测二进制编译于 2026-11-15T19:20:04，晚于 HEAD 提交时刻 … 约 8082s
  —— 它含未提交改动，本报告的结论不能直接归给 b4672b5
```

这条 WARN 不是脚本 bug，就是**当前工作区的真实状态**：678 行并发 WIP 从 R51 挂到现在。
换回旧二进制同样会打 WARN（编译时刻更早、dirty 不变时标 `<hash>+WIP`），符合 DoD。

---

## 三、伴生：打包时不再「盲打包」

`pack-dist.sh` 在 `data-root` 检查之后加了一段：能跑 `build-health.sh` 就报一行
`buildtree clean` / `WARN`，WARN 时把逐目录状态打出来。**只报不拦**——状态坏不等于这份二进制旧
（它可能五分钟前刚编完），但「坏着继续打包」必须出现在屏幕上。

---

## 四、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做什么**

- **678 行未提交 WIP 仍未落地**。这是本轮计划里的另一半（R56：「落地或移出工作区」），
  本轮只做到「让它不再隐形」：dist 的 BUILD-STAMP 有 `wip=concurrent(15)`，现在 regress 也标 `+WIP`。
  为什么不顺手提交：它不是本轮产物，内容是 L10N-04 文字层 + 两个冒烟探针（其中
  `RuntimeVehicleInfantryPassThroughSmoke.inl` 正是 S-24 的前置），归属与完成度都要人来判，
  按 §四.1「无关问题不许拼成一批」也不该塞进本轮。
- EVO-07 ②③、U-19/20/21/23、S-24 均未动。前两项的理由不变（要新开 AppKit 模态面，本环境
  无 `sendEvent`、Accessibility 未授权，交互路径验不了）。

**遗留的债**

1. `build-health.sh` 只认 `build-product-arm` / `build-product-x86_64`，`build-core-*`、`build/`
   未纳入；它们在 `ninja -n` 前不区分会误报 SKIP。
2. S-29 的 `compiled` 粒度到秒、且来自 `RuntimeMain.cpp` 这一个 TU 的 `__DATE__ __TIME__`；
   若改了别的 TU 但没重编 `RuntimeMain.cpp`，编译时刻不会前移——此时靠 `dirty>0` 兜底，
   但反过来「dirty>0 而二进制是干净的」也会被标 WIP。这是**故意保守**的方向。
3. `.ninja_deps` 的截断成因（两会话并发写同一目录）没从机制上消除，只是能检测 + 能修。
   `progress/.active` 心跳 R1 就有，但没有任何脚本真的去抢锁。

**放弃了什么**

- 放弃「把 `ninja -n -d explain` 也塞进 regress」：1647 行 explain 输出在正常轮次是纯噪音，
  只有 CORRUPT 时才需要；`build-health.sh` 的结论行已经写了「加 `-d explain` 可直接看脏因」。

---

## 五、质量四数

| 指标 | 本轮 |
|---|---|
| 净增行数（源码） | **0**（本轮产品代码与测试零改动；改动全在 `ra2mac_docs/scripts/`） |
| 最大文件 | `RuntimeShell.cpp` 90,756（含 WIP +41，本轮 +0）/ `RuntimeMapRenderer.cpp` 42,542 / `RuntimeSessionWorld.cpp` 31,050（含 WIP +256） |
| 断言 vs 产品代码 | 新增断言 0 组，产品代码 0 行（比例闸不适用） |
| TODO/FIXME | 0（Grep 工具复核，非 shell grep） |

脚本侧：新增 `build-health.sh` 约 130 行；`regress.sh` +38；`pack-dist.sh` +17。
`assert` 一个没加是对的——这三个改动是「判据的可见性」，不是产品行为。

---

## 六、清单体检

| 项 | 结果 |
|---|---|
| fix-plan | 358 行 / 400 行 |
| queue | 56KB / 120KB；tasks 35 条 / 120 |
| 悬空引用 | 补本报告前 1 条（`refs-head` 门禁当场照出 `FIX-57` 不存在），补后 0 |
| 状态与报告矛盾 | S-29 原写「待修复」但 DoD 已可验证 → 本轮转已完成并补报告链接；S-30 同 |
| 重复条目 | 0（`dup-ids`） |
| attempts 与收口不符 | S-29/S-30 本轮首次动手，0→1，与收口一致 |
| 十一项门禁 | 全绿 |

本轮**没有新增条目**，因此不触发 §一.6 的等价归档。
