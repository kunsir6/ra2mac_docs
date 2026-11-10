# S5b：窗口 / 输入 / 钩子 / 进程资源族（兼容层第二批）

日期：2026-11-10 03:23–04:35
仓库：`/Users/zhenglk/ai-project/ra2mac/ConcordRTS`（工作区，未提交）
前置：S5a（`windows.h` 69 个标识符 + 9 个类型）已完成，RuntimeShell.cpp 已 0 错误

---

## 1. 一句话结论

**产品构建图里的失败 TU 从 5 个降到 1 个，编译错误从 150 条降到 1 条。**

- 4 个曾失败的 TU 里，`use of undeclared identifier` 与 `unknown type name` 从 116 处降到 0（S5b）；
- 同一轮顺手清完了 T-01（27 处 `max/min/clamp`）与 T-02（4 处 `path::string_type` 宽窄）；
- 只剩 `RuntimeVoiceAudio.cpp`，它的依赖链比预估深一层：`xaudio2.h` → `xapobase.h`。

链接仍未尝试过——缺最后一个 `.o`，`ninja` 直接停在编译阶段。

---

## 2. 这一批到底加了什么

`compat/win32/include/windows.h`：2022 → **2252 行**，新增区块 230 行。

| 类别 | 数量 | 说明 |
|---|---|---|
| 宏（常量） | 52 | 钩子码、`GR_*`、虚拟屏幕、鼠标/键盘事件标志、编辑框样式 |
| 函数声明 | 18 | 其中 **2 个已实现**、16 个仅声明（见 §4） |
| 类型 / 别名 | 15 | `INPUT` 族、`CURSORINFO`、`SYSTEM_POWER_STATUS`、`HHOOK`、`DPI_AWARENESS` |

`compat/win32/src/RuntimeWin32CompatGdi.cpp`：888 → **940 行**（存活对象计数 + 2 个函数实现）。
`compat/win32/selftest/CompatHeaderSelftest.cpp`：321 → **354 行**（+16 条 `static_assert`）。

---

## 3. 四个 TU 的实测账（改前 → 改后）

| TU | 未声明标识符（处/个） | 未知类型（处/个） | 改后 |
|---|---|---|---|
| `RuntimeSkirmishMenu.cpp` | 65 / 32 | 7 / 3 | **0 / 0** |
| `RuntimeMainMenu.cpp` | 15 / 9 | 3 / 1 | **0 / 0** |
| `RuntimeCampaignMenu.cpp` | 4 / 3 | 2 / 1 | **0 / 0** |
| `RuntimeMapRenderer.cpp` | 20 / 4 | 0 / 0 | **0 / 0** |
| **合计** | **104 / 42（去重）** | **12 / 4** | **0 / 0** |

另有 `MsgWaitForMultipleObjectsEx` 5 处，被上游错误遮蔽，补齐后才暴露 —— 所以真实
符号总量是 **42 个标识符 + 4 个类型 = 46 个**，引用 **109 处**。

> 队列 S5a 里记的「50 个标识符 / 130 处引用 + 5 个类型」是当时的估算。实测是 46 个 / 109 处。
> 差的那 4 个里，`JOBOBJECT_EXTENDED_LIMIT_INFORMATION` 在 `src/` 下已完全搜不到
> （并发实例的改动或早期误记），不补；其余为估算误差。**以编译器输出为准，不以估算为准。**

---

## 4. 两个实现选择，与十六个"只声明"

一次性把 46 个符号全声明掉是最省事的，但会让 31 处 `GetGuiResources` 断言变成
**恒真式**——那种"测试通过、其实什么都没测"的假绿，比编译错误危险得多。所以按能力分层。

### 已实现（2 个）

**`GetGuiResources(HANDLE, DWORD)`** —— 返回 compat 层对象表里**真实存活**的 GDI 对象数。
`liveObjectCount` 在 `allocateBitmap` / `CreateSolidBrush` / `CreatePen` 递增，在
`releaseObject` 递减；stock 对象不计入（Win32 也不把它们算进进程计数）。

这条改动把 7 个 diagnostics 文件里 31 处调用从「桩值恒 0、相等断言恒真」变成
**真的泄漏检测**：`RuntimeScreenShakeDrawingContract` 的
`guiWarm != guiInitial` 现在能抓到真实的资源不平衡。

`GR_USEROBJECTS` 恒返回 0，并在代码里写明这是能力缺口而非实现结果——USER 对象要等
窗口后端落地才存在。

**`GetProcessHandleCount(HANDLE, LPDWORD)`** —— macOS 上没有"内核对象句柄"这个概念，
最接近且可廉价枚举的对应物是 fd 表，故数 `fcntl(fd, F_GETFD) != -1`。语义不做等价声明：
socket/pipe 都算 fd 而线程不算，用于"这一轮有没有泄漏"的增量判断有效，用于绝对值无效。

### 只声明（16 个）

`SendInput` / `GetAsyncKeyState` / `EnumThreadWindows` / `FindWindowExW` /
`SetWindowsHookExW` / `UnhookWindowsHookEx` / `CallNextHookEx` / `GetMenu` /
`GetForegroundWindow` / `GetDoubleClickTime` / `MsgWaitForMultipleObjectsEx` /
`GetCursorInfo` / `GetSystemPowerStatus` / `SetBrushOrgEx` /
`GetThreadDpiAwarenessContext` / `GetAwarenessFromDpiAwarenessContext`。

前 14 个的共同点：**没有窗口和消息队列就没有语义**。

- `SendInput` 若假返回 `cInputs`，`check(SendInput(...)==1,"inject real wheel input")`
  会变成"注入了但没注入"的假通过。宁可留链接期缺口。
- `MsgWaitForMultipleObjectsEx` 的 5 处调用全是 `(0, nullptr, ms, QS_ALLINPUT,
  MWMO_INPUTAVAILABLE)`，即"带超时泵一次消息"。在没有窗口的平台上它等价于 `Sleep`，
  但那会把消息泵变成忙等。实现在 SDL3 事件后端。
- `SetWindowsHookExW` 是个特例：它**不在**原始错误清单里，因为 `HHOOK hook=...`
  这行先被"未知类型 HHOOK"打断，clang 吞掉了 initializer 的未声明报错。
  补 `HHOOK` 之后才浮出来——**修一个错误会暴露下一个，清单必须重跑**。

剩下 2 个（DPI）单独说：原本打算按"macOS 的 backing scale 本就是 per-display"映射成
`DPI_AWARENESS_PER_MONITOR_AWARE`，写的时候推翻了这个想法。理由是本项目的渲染是把
软件帧缓冲按物理像素输出，既不是 DPI 感知（会跟随缩放重排布局），也不是 DPI 无感
（会被系统位图拉伸）——**它是一个 Win32 里不存在的第三态**。硬映射到 2 会让
"native capture DPI qualification"这条诊断在 macOS 上"通过"，而它验证的契约在这里
根本不成立。所以留空，等 S7 把窗口/缩放模型建起来再定。

---

## 5. 这一轮修正的两处判断

### 5.1 「5 个失败 TU」的第 5 个：清单对了，位置错了

S5a 的清单记的是 `SkirmishMenu / MultiplayerSmoke / MapRenderer / MainMenu / CampaignMenu`。
本轮用 `ninja -k 0` 拿到的 **concord_runtime 图内**真实清单是：

```
RuntimeMainMenu.cpp / RuntimeCampaignMenu.cpp / RuntimeVoiceAudio.cpp
RuntimeSkirmishMenu.cpp / RuntimeMapRenderer.cpp
```

`RuntimeVoiceAudio.cpp` 的唯一错误是 `fatal error: 'xaudio2.h' file not found`。

但普查（`--census`）又翻出一件事：`MultiplayerSmoke` 确实存在，36 条错误一条不差，
只是它在 `tests/multiplayer/RuntimeMultiplayerTwoProcessSmoke.cpp`，属于**独立 target**
`concord_multiplayer_two_process_smoke`，根本不参与 `concord_runtime` 的编译——
所以建 `concord_runtime` 永远不会报它。

**教训**：「这个 TU 是否报错」取决于你建的是哪个 target。只看产品构建图会漏掉测试目标，
只看测试目标又会漏掉产品目标。两个都要看，而且必须记住它们是不同的失败集。
这 36 条已立为 S8（含 Job 对象、共享内存映射、`Interlocked` 原子族）。

### 5.2 所以 P2-04 的 superseded 标错了

上一轮把 P2-04（隔离 Windows 音频依赖）标成 `supersededBy: "S1 + S4（mciSendStringW
等由兼容层覆盖）"`。这个判断只对了一半：`mciSendStringW` 确实被覆盖了，但
**XAudio2 是另一套东西**——不是 Win32 API，是一组 COM 接口（`IXAudio2` /
`IXAudio2MasteringVoice` / `WAVEFORMATEX` + `XAudio2Create`）。S1 的 `windows.h` 覆盖不到它。

已在本轮把 P2-04 回退为 `pending`，并落了第一层：`compat/win32/include/xaudio2.h`（130 行）。
结果**依赖链比预估深一层**——错误从 `xaudio2.h not found` 变成 `xapobase.h not found`：

```
RuntimeVoiceAudio.cpp → xaudio2.h   ✅ 已声明（IXAudio2 / IXAudio2SourceVoice / XAUDIO2_BUFFER / 11 个常量）
                      → xapobase.h  ❌ 缺（CXAPOBase / XAPO_LOCKFORPROCESS_PARAMETERS /
                                       XAPO_REGISTRATION_PROPERTIES / XAPO_* 常量）
                      → ks.h / ksmedia.h ❌ 缺（WAVEFORMATEXTENSIBLE / KSDATAFORMAT_SUBTYPE_IEEE_FLOAT）
```

`RuntimeAudioPeakLimiter.h` 是 116 行的真实 DSP 实现（峰值限幅器）。它的数学是平台无关的，
只缺那几个类型的声明——所以第二轮大概率能一次推平。

这属于第四类问题（**非 Win32 的 Windows 专属 SDK**），与兼容层不是同一件事。
另外刻意**不做**的是"实现一个永远失败 `XAudio2Create`"：那会让 `ready()==false` 看起来像
"设备不可用"，而"设备不可用"与"没实现"必须分开记录。

---

## 6. 验证输出

```
1/3 头层声明自测（仅编译）
  ok    375 个函数声明与全部常量可编译
2/3 头层内联语义自测（编译并运行）
  ok    compat header selftest (inline): 67 checks, 0 failures
3/3 GDI 实现语义自测（CMake 目标 + 运行）
  ok    80 checks, 0 failures

全部通过
```

顺带修掉脚本里一个会说谎的常量：`verify-win32-compat.sh` 原来硬写着
`pass "276 个声明与全部常量可编译"`。加了 18 个声明之后这句话就成了假的——现在改成
现算（375），永远不会因为忘记改而变成一句谎话。

### 普查：产品构建图内引用 Win32 符号的 TU

```
普查：产品构建图内 Win32 TU 的编译通过数
  引用 Win32 符号的 TU: 31 / 447
  编译通过 30 / 31
    RuntimeMultiplayerTwoProcessSmoke.cpp
```

**这个 30/31 需要正确解读**：它是按固定 token 表从 `ninja -t commands` 里筛出来的集合，
与上一轮"37 个 TU 中 32 通过"不是同一个快照（总数 37 → 31 是构建图变化所致，不是回归）。
可比的是**具名 TU**：SkirmishMenu / MainMenu / CampaignMenu / MapRenderer 四个从
"全部失败"变成"全部通过"。

唯一失败的 `RuntimeMultiplayerTwoProcessSmoke.cpp` 在 `tests/` 下、属独立 target，
它的 36 条错误见 §5.1，已立为 S8。

新增 16 条 `static_assert`，钉住的是"算错也不报错"的那一类：

```
sizeof(MOUSEINPUT)==32  sizeof(KEYBDINPUT)==24  sizeof(HARDWAREINPUT)==8
sizeof(INPUT)==40       alignof(INPUT)==8
sizeof(CURSORINFO)==24  sizeof(SYSTEM_POWER_STATUS)==12
WH_CBT==5  HCBT_CREATEWND==3  GR_GDIOBJECTS==0  GR_USEROBJECTS==1
MWMO_INPUTAVAILABLE==0x0004  GA_ROOT==2  SM_REMOTESESSION==0x1000
SM_CXVIRTUALSCREEN==78  SM_CYVIRTUALSCREEN==79
INPUT_MOUSE==0  INPUT_KEYBOARD==1
MOUSEEVENTF_VIRTUALDESK==0x4000 && MOUSEEVENTF_ABSOLUTE==0x8000
MOUSEEVENTF_WHEEL==0x0800  KEYEVENTF_SCANCODE==0x0008 && KEYEVENTF_KEYUP==0x0002
DPI_AWARENESS_PER_MONITOR_AWARE==2
decltype(HWND_MESSAGE) is HWND
```

`sizeof(INPUT)==40` 是其中最要紧的一条：它同时是 `SendInput` 的 `cbSize` 参数。
算错不会编译失败，只会让注射的输入被目标窗口当成脏数据。

---

## 7. 边界（必须和结论一起读）

1. **只有"编译通过"，没有"链接通过"**。16 个仅声明的函数是 16 个链接期未定义符号，
   和已有的缺口并列。`concord_runtime` 是整体可执行文件，缺一个都不能链接。
2. `liveObjectCount` 未做线程安全——与本层"调用方负责串行化"的既有约定一致
   （项目渲染是单线程），但如果将来有并发绘制，这个计数会漂。
3. `GetProcessHandleCount` 数的是 fd，不是 Win32 的句柄。数值不可与 Windows 对拍，
   只有"增量是否为 0"这一个用途可靠。
4. DPI 两件**没有**实现，理由见 §4——不是遗漏，是明确判断"这个契约在 macOS 上不成立"。
5. 没有 Windows 机器复核这批常量的实际取用行为；数值来自 Win32 头文件定义，不是实测。
6. T-01 改了两处冻结 oracle（`.original.inl`）。语义论证成立（同一模板实例化），
   但**没有 Windows 侧跑一遍 oracle 来证明输出不变**——这是本轮最大的未经证实的假设。

---

## 8. 同一轮顺带清掉的存量：T-01 与 T-02

### T-01：27 处 `max` / `min` / `clamp` 的类型冲突

S5b 之后残留的 33 条错误里有 32 条是这个。全部同一形态：`std::max(1L, LONG运算)`。

- 在 Windows 上 `LONG` 就是 `long`，两个字面量推导出同一个 `T`，编译通过；
- 在 macOS 上 `LONG` 是 `int32_t`，`1L` 是 64 位 `long`，推导冲突。

19 处改 `std::max<LONG>` / `std::min<LONG>`，1 处 `std::clamp<LONG>`，分布在 10 个文件
（含两处冻结的 Windows oracle：`Methods.original.inl`、`MenuAudio.original.inl`）。

**为什么敢改 oracle**：`std::max<LONG>` 在 Windows 上就是 `std::max<long>`，与原推导是
**同一个模板实例化**，生成代码逐位相同。不改反而要为 macOS 单独包一层 `#ifdef`，
让 oracle 与产品代码分叉——那才是真风险。

`clamp` 那处值得单说：原始调用在 Windows 上能过，是因为 `bounds.right - bounds.left`
是 `LONG`（=long），除完仍是 `long`，与 `1L/16L` 三个实参同型。macOS 上 `LONG` 变 `int`，
第一个实参退化成 `int`，才与另两个冲突。这是**同一个根因的另一种表现**，不是新问题。

### T-02：4 处 `fs::path::string_type` 宽窄

不是 `wchar_t` 宽度本身，是 `path::natural()` 的平台差异：Windows 返回 `wstring`，
POSIX 返回 `string`。四处都是拿它去拼宽字符：

```
MenuAudio.original.inl:70   L"open \"" + path.native() + ...
MusicClockSmoke.inl:46      wide(audio.assetRoot.native()) × 3
MusicClockSmoke.inl:96      lexically_normal().native() + L"\\"  及 starts_with
SkirmishMenu.cpp:529        +[](const fs::path& p){ return p.native(); }  // 返回类型是 wstring
```

统一改成 `path.wstring()`：Windows 上 `wstring()` 与 `native()` 是同一个东西，
POSIX 上是 UTF-8 → `wchar_t` 的转换，正是需要的语义。

---

## 9. 下一步

| 顺序 | 任务 | 现状与依据 |
|---|---|---|
| 1 | **P2-04**：`xapobase.h` + `ks.h` + `ksmedia.h` 声明层 | `xaudio2.h` 已落地，错误推进到 `xapobase.h not found`。这是唯一剩下的编译阻塞 |
| 2 | **V-01**：首次链接 `concord_runtime` | 前置是第 1 项。链接跑通才能拿到完整的 undefined symbol 清单 |
| 3 | **S7**：SDL3 窗口/事件后端 | 兑现 16 个仅声明函数 + `XAudio2Create` |
| 4 | **T-03**：`std::wstring` 运行期语义 | 编译面已清零，运行面一条路径都没跑过 |

`RuntimeAudioPeakLimiter.h` 是 116 行的真实 DSP 实现（峰值限幅器），数学部分平台无关，
只缺那几个类型的声明——所以 P2-04 的第二轮大概率能一次推平。

链接之前不要谈"能跑"。目前所有结论的上限仍然是**编译通过**。
