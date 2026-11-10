# ConcordRTS 多平台方案（Windows 保留 + 增量支持 macOS / Linux）

> 分析对象：`/Users/zhenglk/ai-project/ra2mac/ConcordRTS`（commit `32ab245`，2026-11-05）
> 版本：v2（取代 v1「移植计划」的单向移植思路）
> 许可证：GPLv3

---

## 一、目标修正：三条硬约束

| # | 约束 | 工程含义 |
|---|---|---|
| 1 | **Windows 构建必须零回归** | 任何改动不得改变 WIN32 下的编译命令、链接库、目标集合、运行行为 |
| 2 | **macOS 是新增平台，不是替代品** | 新增 `apple/` 实现目录，共享代码不为某一平台让步 |
| 3 | **多平台编译能力长期保留** | 三平台 CI 常驻；平台差异收敛到「后端目录 + 端口实现」，不散落到业务代码 |

这直接否掉了 v1 里几个可以偷懒的做法，但换来的是**能持续跟进上游**——这一点很重要，上游 `AdrianLuo-X/ConcordRTS` 仍在活跃提交（最近 11-05），如果做成一次性 fork 分支，两三个月后就没法合并了。

---

## 二、好消息：项目已经是「多轴」架构

这是本次分析最重要的发现。作者并不是写死了 Windows，而是**已经把平台当成可替换维度**预留了接口。证据：

### 2.1 编译器契约明确声明轴分离

`cmake/CompilerContract.cmake` 第 23 行原文：

```
# OS, frontend, ABI, CPU ISA, and window/presentation backends are separate axes.
# A pointer width alone cannot distinguish x64 from ARM64.
```

而且已有 `CONCORD_MSVC_FRONTEND` / `CONCORD_MSVC_ABI` / `CONCORD_CLANG_CL` / `CONCORD_CPU_ISA` 四个独立维度。**macOS 上 `CONCORD_MSVC_FRONTEND` 天然为 OFF，所有 MSVC 专属选项会自动跳过**——不需要改一行。

### 2.2 平台专属代码已被守卫包裹

| 事实 | 数值 | 含义 |
|---|---|---|
| `cmake/` 中 `WIN32` 守卫 | **86 处** | 这些 `if(WIN32)` 在 macOS 上**自动失效**，无需修改 |
| 引用 `src/**/win32/` 源的 cmake 文件 | 24 个 | 新增 Apple 源需逐个挂接 |
| Windows 库链接点 | `ws2_32` 22 处、`d3d11` 22 处、`winmm` 10 处、`bcrypt` 9 处 | 全部在 `if(WIN32)` 内 |

### 2.3 已有「不支持」降级实现

这是最省事的一点。音频子系统已经是三段式：

```cmake
# cmake/MenuSoundDeviceContracts.cmake 现有结构
concord_add_profiled_leaf(concord_menu_sound_unsupported ...)   # 总是构建
if(WIN32 AND NOT CONCORD_PORTABLE_CORE)
    concord_add_profiled_leaf(concord_menu_sound_win32 ...)     # 仅 Windows
    target_link_libraries(concord_runtime PRIVATE concord_menu_sound_win32)
endif()
```

对应实现：`src/audio/events/RuntimeUnsupportedMenuSoundDevice.cpp`、`src/audio/backend/RuntimeUnsupportedAsyncSoundDevice.cpp`、`RuntimeUnsupportedLegacyWaveDevice.cpp`。

**结论：macOS 上先「静音可玩」是零成本的**，把 `apple` 实现挂上去就自动替换掉 unsupported。

### 2.4 已经有独立的内核构建 profile

`CONCORD_PORTABLE_CORE` = 只编内核、不建窗口/设备后端，且作者已在 Linux 上验证通过。这是 macOS 的**第一个可交付里程碑**，不需要写任何 Mac 代码就能拿到。

### 2.5 自带编译契约基线报告

`concord_finalize_compiler_contract()` 会为每个目标生成 `compiler-contract-$<CONFIG>.txt`，内含每个目标的 `options=` 和 `definitions=`。

**这就是「Windows 零回归」的现成自动化护栏**——每次提交后 diff 这份文件，逐字节一致即通过。不需要另建回归体系。

---

## 三、接入架构

### 3.1 目录约定：并列，不嵌套

```
src/
├── ui/text/
│   ├── win32/RuntimeHudSystemFontWin32.h        ← 保留不动
│   ├── apple/RuntimeHudSystemFontApple.h        ← 新增（CoreText 实现）
│   └── RuntimeHudSystemFont.h                   ← 中立接口（已有则保留）
├── audio/backend/
│   ├── win32/RuntimeAsyncSoundDeviceWin32.cpp   ← 保留不动
│   ├── apple/RuntimeAsyncSoundDeviceApple.cpp   ← 新增（SDL3/CoreAudio）
│   └── RuntimeUnsupportedAsyncSoundDevice.cpp   ← 已有，作为最后兜底
└── core/io/
    └── RuntimeAtomicFile.cpp                    ← 补齐 __APPLE__ 分支（POSIX 共用）
```

规则三条：
1. **平台目录并列**：`win32/` 与 `apple/`（或 `posix/`）同级，命名后缀 `Win32` / `Apple` / `Posix` 保持一致，方便 grep 与批量过滤
2. **共享逻辑只上移、不下沉**：把 Win32 实现里的业务逻辑抽到中立层，两端都调用；禁止把 Mac 逻辑写进 `win32/` 文件
3. **POSIX 共用优先**：文件原子写、随机数、socket 这类，`__linux__` 与 `__APPLE__` 走同一分支，避免三套实现

### 3.2 平台能力矩阵

| 能力 | Win32（现状） | Apple（新增） | Linux |
|---|---|---|---|
| 内核模拟 | 原生 | **0 改动** | 已验证 |
| 文件 / 随机 / 时钟 | Win32 API | POSIX 共用 + `SecRandomCopyBytes` / `mach_absolute_time` | 已验证 |
| 窗口 | `RuntimeWindowHostWin32` | SDL3 或 Cocoa | SDL3（同 Apple） |
| 软件呈现 | GDI `StretchDIBits` | SDL3 texture / Metal blit | SDL3 |
| GPU 呈现 | D3D11（4 文件） | Metal（后期） | 暂缺 |
| 音频 | XAudio2 / MCI | SDL3 Audio 或 CoreAudio | SDL3 Audio |
| 系统字体 | GDI `CreateFont` | CoreText | FreeType |
| 视频 | Bink 外部进程 | AVFoundation（ffmpeg 预转码） | ffmpeg |
| TLS | Schannel | OpenSSL（与 Linux 共用） | OpenSSL |
| 局域网 | Winsock | BSD socket（共用） | 已验证 |

---

## 四、CMake 接入：只改 4 处，全部是新增分支

这是满足「Windows 零回归」的关键。核心思路：**不修改任何既有 `if(WIN32)` 分支的内容，只在它后面追加 `elseif(APPLE)`，并新增一个集中处理文件。**

### 改动 1：新增 `cmake/PlatformApple.cmake`（全新文件，WIN32 下不会被 include）

```cmake
# Apple 平台后端装配。仅在 APPLE 时由顶层 CMakeLists include。
# 不修改任何既有 if(WIN32) 分支，Windows 构建路径完全不变。
include_guard(GLOBAL)

function(concord_strip_win32_sources target)
    if(NOT TARGET "${target}")
        return()
    endif()
    get_target_property(_srcs "${target}" SOURCES)
    if(NOT _srcs)
        return()
    endif()
    list(FILTER _srcs EXCLUDE REGEX "/win32/")
    set_property(TARGET "${target}" PROPERTY SOURCES "${_srcs}")
endfunction()

# 统一剔除本目录下所有目标里的 win32 实现；
# 已在 if(WIN32) 内创建的目标在 macOS 上本就不存在，此处自然为空操作。
get_property(_apple_targets DIRECTORY PROPERTY BUILDSYSTEM_TARGETS)
foreach(_apple_target IN LISTS _apple_targets)
    get_target_property(_apple_type "${_apple_target}" TYPE)
    if(_apple_type STREQUAL "UTILITY" OR _apple_type STREQUAL "INTERFACE_LIBRARY")
        continue()
    endif()
    concord_strip_win32_sources("${_apple_target}")
endforeach()

# 平台后端源（随阶段推进逐步加入）
set(CONCORD_APPLE_RUNTIME_SOURCES
    src/runtime/window/apple/RuntimeWindowHostApple.cpp
)

target_sources(concord_runtime PRIVATE ${CONCORD_APPLE_RUNTIME_SOURCES})
target_compile_definitions(concord_runtime PRIVATE CONCORD_PLATFORM_APPLE=1)
target_link_libraries(concord_runtime PRIVATE
    "-framework Cocoa"
    "-framework CoreText"
    "-framework CoreGraphics"
    "-framework AudioToolbox"
    "-framework AVFoundation"
    "-framework Security"
)

unset(_apple_targets)
unset(_apple_target)
```

### 改动 2：`CMakeLists.txt` 末尾追加一行（`if(APPLE)` 守卫）

```cmake
include(cmake/TestsAdditionalRegression.cmake)
if(APPLE)
    include(cmake/PlatformApple.cmake)   # 新增
endif()
```

### 改动 3：`cmake/CompilerAndPlatform.cmake` 追加 `elseif`（不动 `if(WIN32)` 内部）

```cmake
if (WIN32)
    # ...... 原有 30 行完全不动 ......
elseif (APPLE)
    # 新增分支，Windows 下永不进入
    target_link_libraries(concord_runtime PRIVATE
        "-framework Foundation" "-framework AppKit")
endif()
```

### 改动 4：`cmake/CompilerContract.cmake` 的 backend 状态输出追加分支

```cmake
elseif(WIN32)
    message(STATUS "Concord current product backends: window=Win32; presentation=GDI/software ...")
elseif(APPLE)
    message(STATUS "Concord product backends: window=Apple; presentation=software")
endif()
```

这四处改动在 WIN32 下的**展开结果与现在完全一致**，可以直接用 `compiler-contract-Release.txt` 的 diff 验证。

### 顺带：解除 SDL3 的 Windows 硬限制

`cmake/Sdl3Window.cmake` 现有：

```cmake
if(NOT WIN32)
    message(FATAL_ERROR "P11 SDL3 loader is currently verified on Windows only")
endif()
```

改为 `if(NOT WIN32 AND NOT APPLE)`，并在 APPLE 分支提供 brew 安装的 SDL3 路径。这条改动只在 Windows 之外生效。

---

## 五、共享层去 Win32：「移动不改逻辑」规程

这是整个方案**唯一的真实风险点**，必须立规矩。

### 5.1 问题规模

| 文件 | 现状 | 问题 |
|---|---|---|
| `src/runtime/host/RuntimeShell.cpp` | **89,114 行 / 3.4 MB**，一次 include **23 个 win32 头** + **422 个 `diagnostics/*.inl`** | 无法条件编译，Mac 上必然崩 |
| `src/runtime/host/RuntimeMain.cpp` | 直接 `#include <windows.h>` 并调用 `SetProcessDpiAwarenessContext` | 入口文件 |
| `src/ui/main_menu/RuntimeMainMenu.cpp` | 41 处 `std::wstring`，内联 `CreateWindowEx` | 菜单窗口创建散落 |
| `src/ui/skirmish/RuntimeSkirmishMenu.cpp` | 46 处 `std::wstring` | 同上 |
| 全项目 | **53 个文件** `#include <windows.h>`、**111 个文件** 用 `std::wstring` | 污染面广 |

### 5.2 三条铁律

1. **只做「移动」，不做「改动」**：Win32 实现代码从 `RuntimeShell.cpp` 搬到 `RuntimeShellWin32.cpp` 时，**函数体逐字节不变**，只改 `#include` 与命名空间。任何顺手优化都必须单独提交、单独验证。
2. **每次移动后立刻跑 Windows 回归**：Release 构建 + `ctest` 全绿 + 确定性哈希一致 + `compiler-contract-Release.txt` diff 为空。不满足就不许进入下一步。
3. **共享层只允许出现「平台中立」的 C++20**：`std::filesystem::path`、`std::string`（UTF-8）、`std::chrono`。**禁止**再往共享层新增 `std::wstring`、`HWND`、`HDC`、`LPCWSTR`。

### 5.3 `std::wstring` 的处理策略（最容易埋雷）

Windows 的 `wchar_t` 是 **2 字节（UTF-16）**，macOS/Linux 是 **4 字节（UTF-32）**。这意味着：
- 编译能过
- **运行时行为不同**，尤其是 `std::filesystem::path` 构造、字符串截断、`%ls` 格式化

策略：**端口边界统一转 UTF-8 `std::string`**，内部一律用 `std::filesystem::path`。111 个文件分批转，按子系统提交，每批都跑回归。

> 这条是 v1 方案里低估的部分。它不会阻塞「能启动」，但会阻塞「中文/特殊字符路径可用」。建议安排在菜单解耦阶段一起做，而不是单独一轮。

### 5.4 拆分优先级

不要按文件大小拆，按**依赖方向**拆：

```
第 1 批（低风险，收益大）
  RuntimeMain.cpp        入口与命令行解析
  core/io/*             原子文件、可执行目录（已有 POSIX 分支，只需补 __APPLE__）
  core/security/*       随机源

第 2 批（中风险）
  runtime/host/RuntimeShell.cpp 的平台部分 → RuntimeShellWin32.cpp / RuntimeShellApple.cpp
  先把 23 个 win32 include 与 422 个 diagnostics 抽成独立 TU

第 3 批（高风险，工作量最大）
  ui/*/RuntimeXxxMenu.cpp 的窗口创建与 GDI 绘制
  
第 4 批（可选）
  render 的 GDI 路径 → 纯 BGRA 缓冲绘制
```

---

## 六、验收门禁：Windows 零回归怎么证明

### 6.1 每次提交的四项检查

| # | 检查项 | 通过标准 | 现成工具 |
|---|---|---|---|
| 1 | 编译契约 diff | `compiler-contract-Release.txt` 与基线**逐字节一致** | 项目已自动生成 |
| 2 | 测试全绿 | `ctest` 通过数与基线一致，零新增失败 | CTest |
| 3 | 确定性一致 | 权威哈希 / 存档 / 回放输出与基线一致 | 已有 smoke |
| 4 | 改动位置合规 | `git diff` 只出现在 `if(APPLE)` 分支内或新增文件 | 人工 + CI 脚本 |

第 1 项是最强的护栏，也是这个项目独有的资产——**它把「编译参数级的回归」变成了可 diff 的文件**。

### 6.2 CI 矩阵

| 平台 | Runner | 构建 profile | 阻断策略 |
|---|---|---|---|
| Windows x64 | `windows-latest` + clang-cl（现有 `Build-Game.ps1`） | product + portable-core | **阻断**（回归即红） |
| macOS arm64 | `macos-14` | portable-core → product | 分阶段：P1 前 advisory，P4 后阻断 |
| macOS x86_64 | `macos-13`（或本机 Intel） | 同上 | advisory |
| Ubuntu 24.04 | `ubuntu-24.04` | portable-core | advisory（作者已验证） |

建议 macOS 先做 **advisory（不阻断合并）**，等 product 构建稳定后再转阻断——否则早期每天都是红的，团队会习惯性忽略告警。

---

## 七、分阶段计划（重排：先立护栏，再加平台）

与 v1 相比，最大变化是**把「基线保护」提到最前面**。先能证明「我没弄坏 Windows」，再动手加 Mac。

### P0 · 基线固化（3–5 天）— ✅ 已在 macOS 侧执行完成

**不写任何 Mac 代码。**

- 装工具链：`brew install cmake ninja`（本机当前两者都缺，只有 Apple clang 21）
- 在 Windows 侧（或 CI）跑一次完整 Release，留存：
  - `compiler-contract-Release.txt`（全部目标）
  - `ctest` 结果清单与通过数
  - 确定性哈希 smoke 输出
- 把这三份存进 `baseline/` 并写好对比脚本
- 本机跑 `CONCORD_PORTABLE_CORE=ON` 的 macOS 构建，**只记录报错清单，不修**

**交付**：一份可 diff 的 Windows 基线 + 一份 macOS 报错全景图。

> **执行结果（2026-11-10，详见 `P0-执行报告.md`）**
> - 内核在 macOS 上 **170/170 编译成功、10/10 测试通过、零源码改动**
> - 权威哈希 `1585785091039784157`，两个独立 smoke 输出一致
> - 产品级 configure 通过；编译失败 **12 个 TU / 共 120 个**
> - 阻塞面比预估小：`win32/` 下 25 个 `.cpp` 只有 4 个进入编译图
> - 工具已落库：`scripts/capture-core-baseline.sh`、`scripts/compare-core-baseline.py`、`baseline/core-macos-x86_64.json`
> - **仍缺**：Windows 侧基线（`core-windows-x64.json`），这是 P1 开工的前置条件

### P1 · 平台轴接入（1 周）

- 新增 `cmake/PlatformApple.cmake`（第四章改动 1）
- 三处 `elseif(APPLE)` 追加（改动 2–4）
- 新增 `cmake/toolchains/macos-native.cmake`
- 解除 SDL3 Windows 限制

**验收**：Windows 契约 diff 为空（P0 基线逐字节一致）；macOS 上 `CONCORD_PORTABLE_CORE=ON` 全绿、`OFF` 能 configure 成功。

> 走到这一步，**「多平台构建能力」就已经建立了**——即使还没写一行 Mac 后端代码。这是本方案对「保留多平台能力」这个诉求最直接的回应。

### P2 · 底座补齐（1–2 周）

- `core/io/RuntimeAtomicFile.cpp`、`RuntimeExecutableDirectory.cpp`、`core/security/RuntimeSecureBytes.cpp` 补 `__APPLE__` 分支（与 Linux 共用 POSIX 实现）
- 注意：**macOS 没有 `getrandom`**，用 `SecRandomCopyBytes` 或 `arc4random_buf`
- `mach_absolute_time` 替 `QueryPerformanceCounter`

**验收**：portable core 在 macOS 上确定性哈希与 Windows 基线**完全一致**。这一条通过 = 内核 50 万行在 Mac 上可信。

### P3 · 窗口与软件呈现（2–3 周）

- `src/runtime/window/apple/RuntimeWindowHostApple.cpp`：实现 `SoftwareWindowEvents` 事件源
- SDL3 呈现后端：`SoftwareFrameView`（BGRA8 顶朝下）→ `SDL_UpdateTexture` → `SDL_RenderPresent`
- 输入映射、Retina 缩放（`NSHighResolutionCapable`）、全屏
- 注意 macOS 没有 HWND 父子窗口概念：菜单父窗口需改为「单窗口内切换视图」

**验收**：主菜单静态画面能显示、鼠标有响应；Windows 侧回归仍绿。

### P4 · 音频（1–2 周）

- 新增 `src/audio/*/apple/` 实现，挂到现有三段式结构里（`unsupported` 自动被替换）
- 优先 SDL3 Audio（与 P3 共用依赖），需要低延迟再上 CoreAudio

**验收**：菜单音效 + 单位语音 + 背景音乐正常；Windows 侧 `concord_menu_sound_win32` 完全未受影响。

### P5 · 共享层解耦（4–6 周，主体工作量）

按 5.4 的四批推进，每批独立提交、独立回归。重点是 `RuntimeShell.cpp` 的 `RuntimeShellWin32.cpp` 拆分。

**验收**：`RuntimeShell.cpp` 不再包含任何 `win32/` 头；Windows 契约 diff 仍为空。

### P6 · 菜单与 UI 全量（3–5 周）

`ui/*/RuntimeXxxMenu.cpp` 的窗口创建与 GDI 绘制迁移到端口；系统字体换 CoreText。

**验收**：macOS 上能完整走完「主菜单 → 遭遇战设置 → 进入地图」。

### P7 · 网络与视频（2–4 周）

- TLS：OpenSSL（与 Linux 共用），替 Schannel
- 局域网：BSD socket，基本白拿
- 视频：ffmpeg 预转码 `.bik` → H.264，AVFoundation 播放（绕开 Bink 商业授权）

### P8 · 打包分发（1 周）

- `.app` bundle、Info.plist、universal binary（arm64 + x86_64）
- 代码签名 + 公证（需 Apple Developer 账号，$99/年）
- **GPLv3 合规**：分发二进制须同时提供完整对应源码；游戏素材（`.mix`/`.shp`）不在仓库内，**不可打包**

### 总工期（依据 P0 实测修正）

| 里程碑 | 累计 |
|---|---|
| 多平台构建骨架可用（P1 完成） | **~1 周** |
| 内核在 Mac 上可信（P2 完成） | ~2–3 周 |
| Mac 上能看到画面（P3 完成） | ~3–5 周 |
| Mac 上能打一局（P6 完成，含音频） | **~7–10 周** |
| 功能完整（P8 完成） | ~12–16 周 |

> P0 实测把 P5 从 4–6 周下调到 2–4 周、P6 从 3–5 周下调到 2–3 周：产品级只有 3 个菜单 TU 编译失败、`RuntimeShell.cpp` 是唯一的重活。编译面缩小不等于运行时一定顺利（字体、输入映射、Retina 缩放仍需实测），所以下限没有压太多。

---

## 八、上游同步策略

用户约束 3 要求长期保留多平台能力，这实际上也是**上游合并能力**的要求。

| 做法 | 说明 |
|---|---|
| 平台代码放新增文件 | 上游改动 `RuntimeShell.cpp` 时，Mac 侧冲突面最小 |
| 现有文件只加 `elseif(APPLE)` | 上游若也加了分支，冲突容易手工解决 |
| 每个阶段结束打 tag | `mac/p1-multiplatform-skeleton` 等，便于回退与追溯 |
| 拆分类改动先提上游 | `RuntimeShell.cpp` 拆分对上游同样有益，若能合入主线，后续同步成本归零 |
| 禁止 `git merge` 后直接改 | 先合并、跑基线、确认全绿，再叠加 Mac 改动 |

建议 remote 命名：`origin` = 自己的 fork，`upstream` = `AdrianLuo-X/ConcordRTS`，定期 `git fetch upstream` 后以「合并 + 基线验证」为一次提交。

---

## 九、与 v1 方案的差异

| 维度 | v1（单向移植） | v2（多平台并存） |
|---|---|---|
| 起点 | 直接改代码让 Mac 能编 | **先立 Windows 基线**，证明没弄坏 |
| CMake 改动 | 把 `if(WIN32)` 改成三态 | **保留 `if(WIN32)` 原样**，只追加 `elseif(APPLE)` + 新文件 |
| 目录 | 未约定 | `win32/` 与 `apple/` 并列，后缀规范 |
| 验收 | 功能可用即可 | **契约 diff 逐字节一致**（项目自带工具） |
| 上游 | 未考虑 | 明确同步策略与 tag 节奏 |
| Linux | 顺带 | 与 Apple 共用 POSIX 分支，成为一等公民 |
| 首个里程碑 | Mac 能跑核心 | **多平台构建骨架 + Windows 零回归证明**（1 周内） |

---

## 十、立刻要做的三件事

1. `brew install cmake ninja`（本机缺）
2. **P0：先固化 Windows 基线。** 这一步没有任何 Mac 代码，但它是后面所有工作的判定依据。
3. 确认一件非技术事：**Apple Developer 账号**。不影响开发，只决定 P8 能不能正式分发（ad-hoc 签名在别人机器上会被 Gatekeeper 拦）。

---

## 十一、明确不做的事

- ❌ **不把 `if(WIN32)` 改写成 `if(WIN32) … else()`。** 追加 `elseif(APPLE)`，让 Linux 未来也能走自己的分支。
- ❌ **不在共享代码里加 `#ifdef __APPLE__`。** 平台差异只能出现在平台目录或端口实现里；共享层出现 `#ifdef` 就是设计错误。
- ❌ **不用 Wine / CrossOver 兜底。** 内核已被证明可原生编译，绕路只会把问题推到看不见的地方。
- ❌ **不一上来做 Metal。** 默认路径本来就是软件渲染，先把 BGRA 帧贴到屏幕上，帧率问题量化后再议。
- ❌ **不在 Windows 基线没建立时动手改共享层。** 没有基线，就无法区分「本来就这样」和「我改坏了」。
