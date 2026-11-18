# PLAT-01 · 在 Intel x86_64 机器上第一次跑通

> 结论先行：能在 Intel 上跑。旧结论「Intel 上还没跑成功过」的成因不是架构不支持，
> 而是**打包链的最低系统版本口径**（minos 26.0 vs plist 12.0）与**两条冒烟探针用错时钟**
> （墙钟 `GetTickCount64()` vs 呈现时钟 `presentationClock/uiClock`）。
> 三处都钉死之后：Intel 本机回归 16 绿 / 2 已知红 / 0 新红，`dist/尤里红警.app` 打出
> thin x86_64 包、双击出主菜单。

## 一、本机身份（先钉事实，后面所有判据都挂在这上面）

| 项 | 值 |
|---|---|
| CPU | Intel Core i7-9750H（x86_64） |
| macOS | 26.7.3（25G342） |
| 代码 | `ac45ada`（2026-11-17 22:57 快进拉取，79 提交） |
| 构建目录 | `ConcordRTS/build-product-x86`（cache 里的源码路径是本机路径，可增量） |
| 配方 | `-DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 -DCONCORD_APPLE_SOFTWARE_PRESENT=ON -DCONCORD_APPLE_METAL_PRESENT=OFF -DCMAKE_BUILD_TYPE=Release` |
| 工具 | `/usr/local/bin/cmake` 4.4.4、`/usr/local/bin/ninja` 1.13.2 |

## 二、两个真因

### 1）`min os 26.0` vs plist 声明的 12.0 —— 这才是不敢双击的根

`build-product-x86` 的缓存里 `CMAKE_OSX_DEPLOYMENT_TARGET` **是空的**（历史配置漏了），
于是 ld 用 SDK 的默认值写进 `LC_BUILD_VERSION`：

```
minos 26.0   sdk 26.5
```

而 `pack-dist.sh` 的 `MIN_MACOS=12.0` 会写进 Info.plist 的 `LSMinimumSystemVersion`。
两者不等时：**系统按 plist 放行、dyld 按 minos 拒绝**，用户只会看到笼统的
「需要更新 macOS」，拿不到真正原因。`pack-dist.sh` 的第 ⑪ 步门禁正确拦下了这一版
（"x86_64 切片的 minos=26.0，与 MIN_MACOS=12.0 不一致"），所以之前每一次打包都停在这里，
包里躺着的永远是上一次的二进制——表现为「这台机器上从没跑起来过」。

修法：重配 `-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0` 后全量重编（改这个变量会让所有 TU 失效）。

### 2）两条冒烟探针用错时钟（这是「同一条坑」的第二次、第三次）

#### 2a 交互冒烟：tooltip 探针（恒红）

`interaction` 在 Intel 上第一次跑就是 RED-NEW：

```
gameplay tooltip toggle did not control hovered-object help.
point=yes hit=yes enabled=no disabled=no menu=no
[obj=yes imm=no txtEq=no noNl=yes color=no ...]
```

测点与对象都对（`hitId=2 reHitId=2 postHoverId=2`），是「悬停满 3000ms」这一步没过。
探针把起点写成墙钟，而判定读的是另一只钟：

| 读数 | 值 |
|---|---|
| `GetTickCount64()`（探针写起点用） | 283706130 |
| `runtimeUiClockNow()`（判定读的时间） | 283705124 |
| `started = gtc - 3000` | 283703130 |
| 判定：`now - start >= 3000` | `283705124 - 283703130 = 1994` → **没到** |

`runtimeUiHoverDelayElapsed` 是无符号减法，两只钟只要差一点，结果就会在两个极端之间跳：
差值为负时绕回成天文数字（看着是绿的），差值为正且小于 delay 时永远判「还没到时间」（恒红）。
arm64 上落进了前者，所以这条断言一直是**假绿**。

修法（`src/runtime/host/RuntimeShell.cpp`，两处探针：对象 tooltip + 建造按钮 tooltip）：
起点改用 `runtimeUiClockNow(state)`，与判定同源。产品逻辑无改动——产品侧两端本来就都读 uiClock。

#### 2b 菜单冒烟：滑入动画起点（换了个编译口径才露头）

改完 minos 重编（代码没动）后，`menu` 转 RED-NEW：

```
Main menu smoke failed: skirmish pending contract changed (pending=18 statusEmpty=1 transitionMs=0).
```

`pending=18` 就是 `MenuAction::Skirmish`（枚举第 18 项），没变；错的是 `pageStatus` 空。
链路：`updateDynamicState()` 用 `presentationClock->nowMs()` 算 elapsed →
`updateAnimation()` 里 elapsed 不够一个滑入动画（`(8-1+6)×42 = 546ms`）就一直停在 `SlideIn`，
「正在准备遭遇战…」这句状态永远写不进去。而冒烟里写起点用的是**墙钟**：

```cpp
state.phaseStarted = GetTickCount64() - 1000;   // 想「把动画快进掉」
```

两只钟的差值直接变成了 elapsed：x86_64 上实测≈0（<546）→ 恒红；arm64 上差值够大 → 一直是假绿。
产品侧所有 `phaseStarted` 赋值都读 `presentationClock`（`RuntimeMainMenu.cpp:1093/2403`、
`RuntimeMainMenuController.cpp:391/497`），只有这条冒烟漏了。

修法（`src/ui/main_menu/RuntimeMainMenu.cpp:3249`）：起点改用 `state.presentationClock->nowMs()`；
30 秒超时仍用墙钟（它自己前后一致，与动画无关）。

> 判定纪律（第三次重申）：**探针写时间戳，必须和被测代码读的是同一只钟**。
> 本项目现有两只钟——`GetTickCount64()`（墙钟）与 `presentationClock/uiClock`（呈现时钟），
> 两者在本机差约 1 秒，且差值正负会随构建/机器变。凡是「差值为负 → 无符号绕回 → 假绿」的地方，
> 都只会在一台机器上露出来，另一台永远是绿的。result 记分动画那次（`RuntimeShell.cpp:36978` 的注释）是第一次。


## 三、验收读数

| 项 | 值 |
|---|---|
| 二进制 | `build-product-x86/concord_runtime`，x86_64，`minos 12.0`，`--version` 报 `arch: x86_64` / built 01:04 |
| 全量回归 | **PASS=16 KNOWN-RED=2 RED-NEW=0**（18 条），退出码 0 |
| 已知红 | `command`（奴隶矿工夹具段）、`vehiclepass`（M-25 产品缺陷本身），两条都与本轮无关 |
| 打包 | `pack-dist.sh --bin …/build-product-x86/concord_runtime` rc=0：minos 门禁一致、图标 diff 95.1/255、`--smoke-test` rc=0 |
| 包身份 | `dist/尤里红警.app`｜`lipo -archs` = `x86_64`｜id `org.concord.rts.yuri`｜`LSMinimumSystemVersion=12.0` |
| 双击启动 | `open dist/尤里红警.app` → 窗口标题 `Command & Conquer: Yuri's Revenge`，内容区完整渲染（YR 片头图、Westwood 标、七个中文按钮、右下「版本 1.001」）；证据 `progress/plat-01/menu-intel.png`（2184×1480，Retina 2x 抓图） |

## 四、本机跑回归/打包必须显式传参（脚本默认值仍指 arm）

`regress.sh` / `pack-dist.sh` 的默认二进制都钉在 `build-product-arm/...`，
`lipo-universal.sh` 找的是 `build-product-x86_64/...`，本机建的是 `build-product-x86`。
在 Intel 机上：

```bash
PATH=/tmp/concord-shim:$PATH bash ra2mac_docs/scripts/regress.sh \
    --bin "$PWD/ConcordRTS/build-product-x86/concord_runtime"

bash ra2mac_docs/scripts/pack-dist.sh \
    --bin "$PWD/ConcordRTS/build-product-x86/concord_runtime"
```

另：本机没有 `timeout`（无 coreutils），`/tmp/concord-shim/timeout` 是必需的垫片，
否则 regress 会全红，且理由是 `env: timeout: No such file or directory`。

## 五、还差什么（不假装做完了）

- **universal 包在本机出不来**：没有 arm64 切片（本机编不了 arm64，也没有可复用的
  `build-product-x86_64` 目录）。跨机一致性仍要在 M5 上跑 `lipo-universal.sh`。
  本机的 `pack-dist` 打出的是 **thin x86_64** 包，`dist/BUILD-STAMP.txt` 里 `arch=x86_64` 已如实记录。
- `lipo-universal.sh` 的目录名（`build-product-x86_64`）与本机实际目录（`build-product-x86`）
  不一致，脚本默认参数在本机直接停摆——留作 S 线登记项，本轮不改脚本。
- Rosetta 交叉切片那条门禁（`arch -x86_64 --smoke-test`）在本机是「原生跑自己」，
  证明不了 arm64 那半；它仍然只能在 Apple Silicon 上才有意义。
- **GUI 交互只验到「主菜单渲染 + 窗口响应」**：本机 Accessibility 未授权，
  合成点击/按键会被系统丢弃，所以「点进遭遇战」这一步走不了真鼠标；
  游戏侧链路靠 `skirmish/build/command` 等冒烟覆盖（本机全绿）。
- 两处探针修复已随本轮提交（源码 `367d56a`）。`dist/BUILD-STAMP.txt` 里仍是提交前那次打包
  写下的 `regress=stale@ac45ada+WIP`——二进制与回归结果同属这份源码，只是 stamp 记的是旧口径；
  重跑一次 `pack-dist.sh` 即可消掉这个 WARN。

