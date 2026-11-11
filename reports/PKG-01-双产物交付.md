# PKG-01 · 双 thin 产物交付（arm64 / x86_64 各一份）

> 执行时间：2026-11-11 11:25–11:40
> 决策来源：用户明确「最终输出产物，直接两份。intel 下 intel，arm 的下 arm」
> 结论：两份单架构 `.app` 已产出，**渲染输出逐字节相同**；不做 universal

---

## 一、决策与实现

不做 fat binary，改为**一份源码 + 两组编译参数 = 两个 thin 产物**。源码没有分叉，差别只在 `CMAKE_OSX_ARCHITECTURES`。

```bash
# arm64（本机原生）
cmake -S . -B build-product-arm -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-product-arm --target concord_app

# x86_64（本机交叉编译）
cmake -S . -B build-product-x86 -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES=x86_64
cmake --build build-product-x86 --target concord_app
```

`concord_app` 是个显式目标，从已链接的二进制**复制**出 bundle（`packaging/make-app-bundle.sh`），
所以开发形态的二进制路径 `build-product-*/concord_runtime` 不变，既有验证脚本全部继续可用。

## 二、产物清单

| 交付物 | 架构 | 二进制 | `.app` 体积 | 签名 |
|---|---|---|---|---|
| `dist/ConcordRTS-0.1.0-arm64.app` | `arm64` | 45,322,272 B | 45 MB | ad-hoc |
| `dist/ConcordRTS-0.1.0-x86_64.app` | `x86_64` | 52,637,120 B | 52 MB | ad-hoc |

两份都通过 `codesign --verify --deep --strict`，`Info.plist` 均含
`NSHighResolutionCapable=true`、`LSMinimumSystemVersion=11.0`。

### 2.1 标识也要区分，不只是文件名

只改文件名不够：两个 bundle 若共用 `CFBundleName` 和 `CFBundleIdentifier`，Dock 里长得一模一样，
LaunchServices 还会把它们当成同一个应用。所以四个字段全部带架构：

| 字段 | arm64 | x86_64 |
|---|---|---|
| 文件名 | `ConcordRTS-0.1.0-arm64.app` | `ConcordRTS-0.1.0-x86_64.app` |
| `CFBundleName` | `ConcordRTS-0.1.0-arm64` | `ConcordRTS-0.1.0-x86_64` |
| `CFBundleDisplayName` | 同上 | 同上 |
| `CFBundleIdentifier` | `org.concord.rts.arm64` | `org.concord.rts.x86_64` |
| `CFBundleIconFile` | `ConcordRTS-0.1.0-arm64` | `ConcordRTS-0.1.0-x86_64` |
| 可执行文件 | `concord_runtime`（不动） | `concord_runtime`（不动） |

可执行文件名刻意不改：`build-product-*/concord_runtime` 这个开发形态路径被十几套 smoke 与
脚本引用，改它会打断既有验证，而不带来任何收益。

### 2.2 顺带修掉一个「改名就丢图标」的 bug

`packaging/Info.plist.in` 里 `CFBundleIconFile` 原本写死成 `ConcordRTS`，而打包脚本生成的
图标文件名是跟随 `--app-name` 的。也就是说**只要把 app 改名，Dock 里立刻变白纸**——
之前一直没暴露，是因为名字从来没改过。已改为 `@CONCORD_APP_NAME@`，与 icns 文件名保持同步。

验证：两份 `Contents/Resources/` 下的 icns 均为 1024 px，与 `CFBundleIconFile` 一致。

源码提交：`3d7267e PKG-01 打包：Info.plist 的 CFBundleIconFile 跟随 app 名（双产物标识区分）`

## 三、等价性证据

### 3.1 菜单渲染：两份产物导出的位图 SHA-256 完全相同

```
--main-menu-ui-smoke-test（同一台 M5，同一份数据）
arm64  侧: 7f3708c822cdac09e9025e8a2357028d
x86_64 侧: 7f3708c822cdac09e9025e8a2357028d   ← 逐字节相同
```

两边的 smoke 计数也逐项相同：

```
sideTopFrames=2 warningFrames=91 slotFrames=17 redButtonFrames=3
lightGoldRamp=255,190,97/245,172,68/97,59,4  rampPixels=1056,781,1428
```

这条比「计数相同」强得多：计数只证明统计口径一致，**BMP 逐字节相同证明每一个像素都一致**。
说明 compat 层的 GDI 光栅、字体光栅器、调色板路径在两架构上完全等价。

### 3.2 上屏自证：两份都三帧 match=yes

```
arm64  裸二进制 : idx=1..3  layerHash==dibHash==providerHash  match=yes  scale=2.0  failures=0
x86_64 .app 内  : idx=1..3  layerHash==dibHash==providerHash  match=yes  scale=1.0  failures=0
```

（`scale` 的差异见下一节，属测量假象，不是缺陷。）

## 四、一个必须记住的测量陷阱：scale 不可在 bundle 内直接 exec 取

第一轮测得 `arm scale=2.0`、`x86 scale=1.0`，看起来像「x86 产物 Retina 坏了」。做对照后发现不是：

| 执行方式 | arm64 | x86_64 |
|---|---|---|
| **裸二进制**（`build-product-*/concord_runtime`） | **2.0** | 未单测 |
| **`.app` 内二进制直接 exec** | **1.0** | **1.0** |

arm 的 `.app` 内二进制直接 exec 同样是 `1.0`，所以差异只来自**启动方式**，与架构无关：
高分辨率能力由 LaunchServices 在启动时决定，绕过它直接 exec bundle 内二进制会退回 legacy 1x。

**推论**：`scale` 判据只在裸二进制方式下可信；`.app` 的真实 Retina 行为必须在真机上以双击验证。
本次无法用 `open --args` 自动取证（参数没有生效），`launchctl setenv` 又被沙箱拒绝，故 Retina 未闭环。
这不影响交付，但**Intel 用户拿到 x86 产物后，Retina 那一项仍属未验证**。

## 五、交付时必须知道的一件事：`data-root` 是指针，不是数据

`.app` 里 `Contents/Resources/data-root` 是一个 134 字节的**文本文件**，内容是指向
`ConcordRTS-GameData` 的绝对路径。所以：

- 本机双击即玩（数据树在旁边）；
- **发给别人不能只发 `.app`**——对方机器上没有那个路径。要么同时给数据树，要么改这个指针文件，
  要么将来把数据打进 bundle（会把 45 MB 变成 1.6 GB，且与 GPLv3/素材分发的约束冲突，不建议）。

## 六、为什么不做 universal

| | 双 thin（本次选择） | universal fat |
|---|---|---|
| 单次分发 | 需按架构选下载项 | 一个文件通吃 |
| 体积 | 45 / 52 MB 各一份 | 约 97 MB（两者相加） |
| 构建时间 | 各约 3 分钟 | 约 6 分钟（两遍编译） |
| 失败定位 | 产物即架构，一目了然 | fat 出问题要 `lipo -thin` 才能拆 |
| 与项目判据的契合 | **契约/哈希本就按构建目录对账，天然对齐** | 一份产物两种行为，对账反而更难 |

用户选择双 thin 是合理的：这个项目的全部判据（`compiler-contract-*.txt`、金标准哈希、像素基线）
都是**按构建目录**组织的，thin 产物与之一一对应；fat binary 会把两种行为塞进一个文件，
反而和现有对账机制错位。

## 七、未验证

- x86_64 产物在**真 Intel 机器**上的行为（本次只有 Rosetta）：Retina 尺度、音频设备、窗口行为；
- 两份产物的音频实际出声（`AudioQueue`，两架构都只编未跑）；
- 遭遇战 / 加载 / 游戏内三界面的上屏（依赖 ON-3-01b 的合成输入）。
