# FIX-54 版本身份自证：`--version` + 包内构建戳 + 打包链第 ⑨ 门禁

> 轮型：**修复轮**（无 brake / 无 attempts≥3 待结 / 无腐烂预算 / 距 AUDIT-51 两轮 / 比例闸已解除）。
> 主目标：**EVO-07 第一步（版本身份）**。源码 1 提交 `9477056`（+73 行）。

## 一、为什么这轮做 EVO-07 的「版本身份」而不是完整 EVO-07

EVO-07 原始形态是三件：①数据根缺失给 AppKit 对话框 ②About 面板 ③dmg 分发。
①和②都要新开 AppKit 模态面，而本项目**不调 `[NSApp sendEvent:]`**、本机 Accessibility 未授权
→ 交互路径在这个环境里**验证不了**，做出来只是「未验证的 UI」，按 §八.4 属未完成。
所以本轮取的是同一目标里**能自证**的那一段：让二进制和包自己说出「我是哪一版」。
③dmg 未做（见 §六），①下一步单独出方案。

## 二、现象与根因

现象：`dist/尤里红警.app` 拷到别人的机器上之后，「这是哪一版」无法回答。
`CFBundleShortVersionString` 是 `pack-dist.sh` 里写死的 `0.1.0`，二进制**没有任何版本出口**；
唯一的身份记录是 `dist/BUILD-STAMP.txt`，它是**包外**的旁挂文件——包一被拷走就断了。

根因两条，都不是「忘了加功能」：

1. **身份只存在于包外**。判「dist 是不是最新」的历史判据一直是「`BUILD-STAMP.txt` 里的 hash
   是否等于 `git rev-parse HEAD`」，这个判据默认「stamp 与包待在一起」。一旦分发出去就不成立。
2. **plist 与二进制之间没有任何一致性断言**。`pack-dist.sh` 查了 displayName / bundle id /
   icon / minos / 包内 smoke，唯独没有一条能发现「plist 是这一版、里面装的二进制是上一版」。
   （这一条与 `MIN_MACOS` 那课同源：判据只查了一侧，另一侧是盲区。）

## 三、改法

### 3.1 `--version`（`src/runtime/host/RuntimeMain.cpp`，+73）

打印四行，前两行是编译期常量，第四行读包内文件：

```
ConcordRTS runtime 0.1.0
arch: arm64
compiled: Nov 15 2026 15:44:17
package: 9477056 0.1.0 2026-11-15T15:47:47 arch=x86_64+arm64 wip
```

- `arch` 用 `__aarch64__` / `__x86_64__` 判，**通用二进制必须自己报对**
  （历史上 `arch -x86_64` 那半边是盲区，见 MEMORY「交叉切片的冒烟要单独跑」）。
- `compiled` 是 `__DATE__ " " __TIME__`，即**本 TU 的编译时刻**。它不是构建时刻的精确值
  （只改别的文件时它不更新），注释里写死了这一点——**不写清就会被当成「构建时间」引用**。
  真正的构建序号由第四行给。
- `package` 行读 `foo.app/Contents/Resources/BUILD-INFO.txt`；直接跑 build 产物时打印
  `(不在 .app 内，未打包)`，**明说没有而不是留空**——空白会被读成「最新」。
- 不动 CMake：传 git hash 要加编译定义，1652 目标全量重编（实测 4:17），与收益不对称。

### 3.2 `pack-dist.sh` 两处（③b 写入 / ⑨ 断言）

- ③b：组装完写 `Contents/Resources/BUILD-INFO.txt`，单行
  `<hash> <version> <打包时刻> arch=<archs>[ wip]`，然后 **重签**（写文件会让 ad-hoc seal 失效，
  不重签别的机器上 `codesign --verify --strict` 会报 "a sealed resource is missing or invalid"）。
- ⑨：拿包内二进制 `--version` 的 `package:` 行与 `BUILD-INFO.txt` **逐字比对**，不等就 `exit 1`。
  这条专防两类静默错配：包换了二进制没换 / plist 与二进制不是同一版。

## 四、DoD（动手前写进计划，本轮未改判）

1. `concord_runtime --version` rc=0，不开窗口，四行齐全；
2. `dist/尤里红警.app/Contents/Resources/BUILD-INFO.txt` 首行 = `<HEAD短hash> ... arch=...`；
3. 包内二进制 `--version` 的 `package:` 行与 ②逐字相同（pack-dist 第 ⑨ 步断言，不过即不出包）；
4. `codesign --verify --strict` 在重签后通过；
5. 两架构各自报对 `arch:`（`arch -x86_64 … --version` 必须打印 `x86_64`）。

实测五条全过（证据见 §五）。

## 五、证据

```
$ ./build-product-arm/concord_runtime --version        # 直接跑构建产物
ConcordRTS runtime 0.1.0
arch: arm64
compiled: Nov 15 2026 15:44:17
package: (不在 .app 内，未打包)

$ "dist/尤里红警.app/Contents/MacOS/concord_runtime" --version
package: 9477056 0.1.0 2026-11-15T15:47:47 arch=x86_64+arm64 wip

$ arch -x86_64 "dist/尤里红警.app/Contents/MacOS/concord_runtime" --version
arch: x86_64
package: 9477056 0.1.0 2026-11-15T15:47:47 arch=x86_64+arm64 wip   # 同包同戳，切片各报各的架构
```

`pack-dist.sh` 输出：`buildinfo 9477056 0.1.0 2026-11-15T15:47:47 arch=x86_64+arm64 wip` /
`version --version package 行与 BUILD-INFO.txt 一致`；`icon diff-vs-generic=96.2`；
`min-macos 12.0（plist 与 x86_64+arm64 的 minos 一致）`；`smoke --smoke-test rc=0`。
Rosetta：`arch -x86_64 … --smoke-test` rc=0。

## 六、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做**：
- EVO-07 的 AppKit 数据根对话框（①）：要新开模态面，本环境验证不了交互（不调 sendEvent + 无 Accessibility 授权）。
- EVO-07 的 About 面板（②）：现在有了可读的三字段，但把它**画到屏幕上**仍属未验证 UI。
- EVO-07 的 dmg（③）：时间只够到打包，dmg 要 `hdiutil` + 挂载验证（挂载卷里没有同级 GameData，
  验法要单独设计：从挂载卷取出二进制配 `CONCORD_DATA_ROOT` 跑 smoke）。留到下一轮第一件。

**遗留债**：
- `compiled:` 是 TU 编译时刻，不是构建号码（注释已写明，但界面上没有「构建序号」这个概念）。
- 版本号 `0.1.0` 现在是**两处**常量（`RuntimeMain.cpp` 的 `kRuntimeVersion` 与 `pack-dist.sh` 的 `VERSION`），
  改版本号必须同改两处；没有门禁能发现漏改一处。**这是本轮新引入的重复**，写在这里不装作没有。
- `--version` 未进 regress（14 条里没有它）。低风险，但「新加的出口没人常跑」是本项目反复踩过的形状。

**放弃**：
- 放弃「用 CMake 传 git hash 进二进制」：全量重编代价（4:17）与收益（少读一个文件）不对称。

## 七、质量四数

| 项 | 值 |
|---|---|
| 本轮净增 | **+73**（1 文件，`RuntimeMain.cpp` 1,091 → 1,164） |
| 最大单文件 | `RuntimeShell.cpp` 90,715（持平）／`RuntimeMapRenderer.cpp` 42,542（持平）／`RuntimeSessionWorld.cpp` 30,794（持平） |
| 断言 vs 产品代码 | 新增断言 **0** 组 / 产品代码 **+73**（本轮无 test:，不占断言额度） |
| TODO/FIXME | +0（diff 里 0 条） |

90k 文件零改动（`RuntimeShell.cpp` 有并发 WIP，按 hunk 不碰）；本轮改的是 1,164 行的小文件，
不触「大文件准入」红线。

## 八、清单体检（每轮必做）

`ledger-check.sh` 十项全绿（341 行 / 64KB / 35 条 / 5 类）。人工体检查出 **1 处矛盾 + 1 处结构问题**：

1. **S-25 状态矛盾（真错）**：`fix-plan` §二 表里写「待修复（第 44 轮登记）」，
   但同一份计划的附三与 `progress/deferred.md` 都写「第 47 轮已移出 deferred」。
   十项门禁**一条都报不出来**（形状对、内容错——正是附六写的那条代价）。
   本轮处理：从 §二 表删掉 S-25 整行，改在 §七 留一行指针。
2. **EVO-07 是一条三件事揉成的条目**（`detail` 里三个交付物、`verify` 里三条判据），
   本轮只推进了其中一段，按原样留在 `pending` 会让「推进了一轮」不可见。
   本轮处理：条目 `attempts` 0→1、`detail` 改成三段式并标出哪段已交付，状态仍 `pending`。

## 九、两级计数

- 条目级：**EVO-07 attempts=1**（本轮推进一段未结案）。其余无变化。
- 主线级：EVO 主线（`EVO 进化`）子项 EVO-01~07 已 7 个——**注意**：EVO 是「能玩之后」的总桶，
  本轮起把它按 §六.2 视作一条主线计数，已用轮数从本条起算 **1 轮**。
  继续在 EVO 桶里开第 8 个子项前必须先做整体收口判定，**下轮起手要回答这条线还剩什么**。
- 无到限必须收口的主线（unit-behavior 已 blocked、S-回归门禁 / preview-dedupe / 清单治理已 done）。

## 十、下轮起手

1. **EVO-07 的 dmg**（同一目标内，改动局部、可独立 revert）：`scripts/make-dmg.sh`，
   挂载卷验法 = 取出二进制 + `CONCORD_DATA_ROOT` 跑 smoke。
2. **`--version` 进 regress**（第 15 条，0.1s）：本轮新增的出口没有日常门禁，这正是 S-25 那类「加了没人跑」的形状。
3. EVO 主线整体收口判定：先答「还剩什么」，再决定是否继续开子项。
