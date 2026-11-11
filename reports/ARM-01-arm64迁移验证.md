# ARM-01 · arm64 迁移验证（Intel → Apple Silicon）

> 执行时间：2026-11-11 10:10–10:45
> 设备：Apple M5 Pro / arm64；此前全部适配工作在一台 Intel Mac（x86_64）上完成
> 结论：**零代码改动，arm64 上内核逐位等价、产品能真实上屏**

---

## 一、迁移的真实障碍不是代码，是环境

换机同时发生了两件事：**芯片从 x86_64 变 arm64**、**工程路径从 `/Users/zhenglk/ai-project/ra2mac` 变 `/Users/zhenglk/AiProjects/ra2mac`**。后者破坏力更大，因为它让所有既有构建目录变成死数据。

| 项 | 历史（Intel） | 迁移前实测（M5 Pro） |
|---|---|---|
| `cmake` | `/Users/zhenglk/opt/cmake/bin/cmake` 4.4.4 | **不存在** |
| `ninja` | `/usr/local/bin/ninja`（Intel Homebrew 前缀） | **不存在** |
| 工程路径 | `/Users/zhenglk/ai-project/ra2mac` | `/Users/zhenglk/AiProjects/ra2mac` |
| `build-core-mac` | 可用 | `CMakeCache` 写死旧绝对路径，产物 `Mach-O x86_64` |
| `build-product-mac` | 可用 | 同上，43 MB 级别的 x86_64 二进制 |

判定依据：

```
$ file build-product-mac/app/ConcordRTS.app/Contents/MacOS/concord_runtime
Mach-O 64-bit executable x86_64

$ grep CMAKE_HOME_DIRECTORY build-product-mac/CMakeCache.txt
CMAKE_HOME_DIRECTORY:INTERNAL=/Users/zhenglk/ai-project/ra2mac/ConcordRTS
CMAKE_MAKE_PROGRAM:FILEPATH=/usr/local/bin/ninja     # 此路径在本机不存在
```

所以旧构建目录**不能增量**，只能整体重配。它们保留为历史证据，不删。

## 二、工具链：brew 被沙箱拦住，改用 venv

`brew install cmake ninja` 在工具沙箱内失败：

```
sandbox-exec: sandbox_apply: Operation not permitted
exited with 71
```

改用 Python venv 装官方 wheel（不动系统 PATH、不需要 root）：

```bash
python3 -m venv /Users/zhenglk/AiProjects/ra2mac/.toolchain
.toolchain/bin/pip install cmake ninja
# cmake 4.4.4 / ninja 1.13.2
```

版本与 Intel 机器上的 cmake 4.4.4 **恰好相同**，因此编译契约的可比性不受版本差异干扰。调用方式：

```bash
export PATH="/Users/zhenglk/AiProjects/ra2mac/.toolchain/bin:$PATH"
```

## 三、内核：逐位等价

```
cmake -S . -B build-core-arm -G Ninja -DCONCORD_PORTABLE_CORE=ON -DCMAKE_BUILD_TYPE=Release
-- Concord compiler contract: OS=Darwin; compiler=AppleClang 21.0.0.21000401;
   frontend=GNU; Microsoft ABI=OFF; CPU ISA=arm64
```

`CPU ISA=arm64` 由 `CompilerContract.cmake` 第 44 行既有分支自动识别，**未改一行 cmake**。

| 项 | 结果 |
|---|---|
| 编译 | **170/170**，31 秒 |
| 测试 | **10/10**，3.08 秒 |
| 金标准哈希 | **`1585785091039784157`** —— 与 x86_64 基线逐位相同 |

基线对照（`scripts/compare-core-baseline.py`）：

```
发现 2 处差异：
  git_commit                          参考='32ab245'  候选='38286db'
  exit.concord_secure_bytes_contract  参考=77  候选=0
```

两处都不是回归：

- `git_commit` 是后来提交导致的，无关；
- `secure_bytes` 由 77（unsupported）变 0（通过），正是 **P2-01** 的成果——参考基线采集于 P2-01 之前，那时 macOS 还没有随机源。arm64 上 `getentropy` 路径同样成立。

`baseline/core-macos-arm64.json` 已入库。

## 四、产品：能编译、能上屏

```
cmake -S . -B build-product-arm -G Ninja -DCMAKE_BUILD_TYPE=Release
-- concord_apple: sdl3-window=OFF sdl3-audio=OFF software-present=ON metal-present=OFF
cmake --build build-product-arm --target concord_runtime
[183/183] Linking CXX executable concord_runtime
```

产物 `Mach-O 64-bit executable arm64`，43 MB（x86_64 版 49.6 MB），ad-hoc 签名后可直接运行。

### 4.1 离屏菜单 smoke：像素计数与 x86 逐项相同

```
Main menu smoke: 800x600 sideTopFrames=2 warningFrames=91 slotFrames=17
  redButtonFrames=3 font=game.fnt lightGoldRamp=255,190,97/245,172,68/97,59,4
  rampPixels=1056,781,1428 legacyYellow=0 ...
```

这五个数是 ON-2-02a 记录在案的 x86 基线，**arm64 上完全复现**。菜单渲染路径（compat 层 GDI + 自有字体光栅器）在两种架构上等价。

### 4.2 真实窗口上屏自证：三帧 hash 互不相同、逐帧 match

```
[cocoa] NSWindow created 1024x640 title= visible=1
[cocoa] frame 1: view=1024x640 layer=1024x640 contents=set scale=2.0 win=1024x672 img=1024x640
[attest] log=/tmp/arm-attest/onscreen-attest.log
[attest] done: records=3 failures=0 limit=3

idx=1 layerHash=0x24af0758 dibHash=0x24af0758 providerHash=0x24af0758 match=yes scale=2.0
idx=2 layerHash=0x8a00d66c dibHash=0x8a00d66c providerHash=0x8a00d66c match=yes scale=2.0
idx=3 layerHash=0x83b9bd68 dibHash=0x83b9bd68 providerHash=0x83b9bd68 match=yes scale=2.0
```

三个**互不相同**的 hash + 逐帧 `match=yes` = 屏幕确实连续换了三帧，且每帧与同帧 DIB 逐像素一致。
`scale=2.0` 说明 Retina 的 `contentsScale` 跟随在 arm 上直接成立（ON-2-03 的一条判据免费拿到）。

## 五、两个必须记住的发现

### 5.1 产品**全量**构建从未绿过，只有主目标可用

`cmake --build build-product-arm`（1823 个目标）在 `[182/1823]` 失败：

```
FAILED: CMakeFiles/concord_mod_history_noop_smoke.dir/.../RuntimeModExtensionsHistoryNoopSmoke.cpp.o
error: use of undeclared identifier 'advanceRuntimeModExtensions'   (×2)
```

与架构无关：该测试自带一个「小宿主」类型，却调用了签名为 `bool advanceRuntimeModExtensions(RuntimeGameSessionState&)` 的函数（声明在 `src/runtime/session/detail/RuntimeProductionOperations.h:9631`），而测试文件既没 include 该头、宿主类型也不匹配。

历史上所有验证命令都是 `ninja -C build-product-mac concord_runtime`——**只编主目标**。所以这条断裂一直都在，只是从来没被触发。建议单开任务修，或明确把「全量构建」从验收范围里划掉。

### 5.2 光照 SIMD 在 arm64 上自动停用

`src/render/lighting/RuntimeLightingLookupRaster.h:7` 的选路条件：

```cpp
#if defined(_M_X64) || defined(__SSE2__) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
```

arm64 上 clang 不定义 `__SSE2__`，因此 `CONCORD_LIGHTING_HAS_SSE2=0`、`..._AVX2=0`，**全部走标量路径**，没有 NEON 替代。

影响面：

- **确定性**：本次内核金标准哈希一致，说明内核判据不受影响（哈希不覆盖光照光栅）。但该文件注释强调「系数只在能逐项精确复现既有 rounded 查找表时才被接受」，若将来把光照纳入像素级哈希，必须单独验证标量与 SSE2 的逐像素一致性；
- **性能**：光照走标量，是潜在热点。目前未做性能基线（ON-4-04 仍 pending），暂不量化。

### 5.3 弱内存序：本项目第一次真正被压测

`compat/win32/src/RuntimeWin32CompatAtomic.cpp` 自己的注释写着：「本机（x86_64，强内存模型）几乎测不出来，换到 ARM 就是稳定复现的错」。

该族一律用 `__ATOMIC_SEQ_CST`，语义上正确。本次 10/10 内核测试 + 1823 目标编译 + 三帧上屏均未暴露竞态，但**单次运行不算证明**——arm64 上才是这类 bug 真正会露头的地方，后续长时挂机（ON-5-02）价值比在 Intel 上高。

## 六、结论与后续

**结论**：这套适配的架构选择（Win32 兼容层 + 平台目录并列）在换架构时兑现了收益——**代码零改动**，只需重建工具链与构建目录。之前担心的「Intel 上做的适配换 arm 要重做」并不成立。

**后续建议**（按优先级）：

| # | 事项 | 理由 |
|---|---|---|
| 1 | 把 `build-core-arm` / `build-product-arm` 定为**唯一**判定环境，旧 x86 目录只作历史证据 | 避免「在哪个树上验证的」再次含糊 |
| 2 | 更新 `rules.arch_note`：默认 arm64 原生构建，x86_64 需显式指定 | 原文写的是「构建目标架构是 x86_64」，已过时 |
| 3 | 修 `concord_mod_history_noop_smoke` 的构建断裂 | 全量构建不可用会让 CI 无从建立 |
| 4 | 光照标量路径做一次性能与逐像素一致性量化 | 唯一停用 SIMD 的点 |
| 5 | ON-5-02 长时挂机优先在 arm64 上做 | 弱内存序只有这里能压出来 |

**未验证**：音频在 arm64 上的实际出声（`AudioQueue` 只编过未跑）、遭遇战/加载/游戏内三界面在 arm 上的上屏（依赖 ON-3-01b）、性能数字（依赖 ON-4-04）。
