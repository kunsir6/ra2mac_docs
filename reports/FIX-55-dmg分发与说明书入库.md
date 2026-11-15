# FIX-55 · EVO-07 ④ dmg 分发收口：说明书入库 + 跨机可玩性变成门禁

日期：2026-11-15 17:10
轮型：**修复轮**（无 brake / 无 attempts≥3 在办 / 无腐烂预算 / 距 AUDIT-51 四轮 / EVO 主线用 2 轮）
主目标：**EVO-07 ④「dmg 分发」**（①版本身份 R54 已交、②About 与③数据根对话框仍无解，见 §六）

## 一、为什么是这一段

R54 交付 `--version` 自证后，剩下的两件（About 面板、数据根对话框）都要新开 AppKit
模态面；本项目不调 `[NSApp sendEvent:]`、本机 Accessibility 未授权，交互路径**验证不了**，
做出来是 §八.4 的「未完成」。dmg 不是：它有可观察判据——**挂载后从卷里跑**。
所以本轮拿走它，顺带把「包到了别人机器上会怎样」变成可执行的门禁。

动手前写死的验收条件（§八.1，当轮不许改）：**把挂载卷里的包拷到临时目录、指针改成
不存在的路径、重签，然后 (a) 没有数据树时必须明确报 `data root NOT found`；
(b) 把数据树放成 .app 同级目录后必须 `source=sibling` 命中。**

## 二、改法（两个脚本，一个说明书）

| 文件 | 做了什么 |
|---|---|
| `ra2mac_docs/scripts/make-dmg.sh`（新，185 行） | ditto 进临时卷（保签名 seal）→ `hdiutil create UDZO` → `verify` CRC → 挂载后重验 **7 条**：universal / 两切片 minos == plist / `codesign --verify --strict` / `--version` package 行 == BUILD-INFO / `--smoke-test` rc=0 / 跨机模拟 (a)(b) |
| `pack-dist.sh`（+30 行） | ⑩ 每次打包把 `packaging/README-dist.txt` 覆盖写到 `dist/README.txt`；⑪ `--dmg` 可选调用上者。默认不出 dmg——它是分发动作，不是构建动作 |
| `ConcordRTS/packaging/README-dist.txt`（新，129 行，入库） | 取代手工维护的 `dist/README.txt` |

## 三、真正的缺陷：说明书在撒谎，而且没人量它

`dist/README.txt` 是**未跟踪**的手工文件，停在 2026-11-11，三处都已被后续版本推翻：

| 它写的 | 实际 |
|---|---|
| 标题「macOS **arm64** 产物」 | universal 单包（arm64 + x86_64） |
| 「11 条回归 smoke 当前 **5 绿 6 红**」 | 14 条，13 绿 / 1 known-red |
| 「全屏时画面是把 800×600 放大铺满，像素会有点块」 | U-14 已改成**视口变大**（单位像素不变，一屏看更多地图） |

它还写着数据目录 `/Users/zhenglk/...` 的绝对路径却不说「发给别人怎么办」。
这是交付物里**唯一一份给用户看的文档**，也是清单治理里从未被量过的一项——
和 S-27 同型：写的时候是对的，之后没人回头核对。现在它有了唯一源（入库 + 每次打包覆盖）。

## 四、三条实测读数（都改了一个原先信以为真的说法）

1. **数据根指针的优先级高于环境变量**。`RuntimeConfigPaths.cpp:188` 的注释写「指针放在
   环境变量之后，`CONCORD_DATA_ROOT` 仍最高优先」——与代码相反：⓪ app-resources 段
   在 ① environment 之前且解析成功就 `return`。实测 `CONCORD_DATA_ROOT=/nonexistent`
   仍报 `source=app-resources`。
   **只改注释不改行为**（改优先级是产品决策，「包自带数据位置」会失效），见提交 `b4672b5`。
2. **没有数据树时是静默的**：只打印 `[config] data root NOT found: game assets will not
   resolve at startup.`，而 `--smoke-test` 照样 rc=0。也就是说「包能跑」与「能玩」
   完全是两件事，pack-dist 的 ⑧ 门禁对这条缺口天然无感——这正是 EVO-07 ③ 要补的。
3. **同级目录不限名字**：兄弟目录是「枚举父目录的子目录 + 按内容判定（同时含
   `local_data/` 与 `RedAlert2/`）」，实测把数据树改名成 `GameData` 一样 `source=sibling`。
   原 MEMORY 里「必须叫 ConcordRTS-GameData」的说法是过头了，已按实测改正说明书。

## 五、门禁与产物

```
pack-dist ⑩ readme  dist/README.txt ← packaging/README-dist.txt
pack-dist ⑨ version --version package 行与 BUILD-INFO.txt 一致
make-dmg  archs x86_64 arm64 / minos 12.0（两切片）/ codesign --verify --strict ok
make-dmg  foreign (a) 无数据树 → data root NOT found
make-dmg  foreign (b) 同级目录 → source=sibling
rosetta   arch -x86_64 … --smoke-test  rc=0
```

`regress.sh` 收口跑 `PASS=13 KNOWN-RED=1 RED-NEW=0 共 14 条`（20261115-170341），
与本轮基线（20261115-165221，同为 `13/1/0`）一致。本轮**零产品行为改动**，
所以不新增断言、不改 known-red（§八.3 比例闸：近 5 轮 test 0 / fix 1，无需收紧）。

## 六、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做**：
- EVO-07 ②About 面板、③数据根缺失对话框。两者都是新开 AppKit 面（NSAlert +
  NSOpenPanel），本环境验证不了交互，须先回答「交互判据怎么做」——与 C-01 同源。
- `--version` 进 regress 第 15 条。原计划做，本轮改判**不做**：它断言的东西
  （`package:` 行 == BUILD-INFO）pack-dist ⑨ 已经在**每个包上**断过，且那是有意义的
  位置（同一个 bundle 里两个东西必须一致）；塞进 regress 只会重复同一个断言，
  而 regress 跑的是 build 目录的裸二进制，那一侧根本没有 BUILD-INFO。
  宁可空着也不加一条「恒真断言」（§八.4：只加断言不算完成）。

**遗留债**：
- **`dist/` 整个目录不在版本控制内**（README 是其中唯一的文档），现在说明书有源了，
  但「dist 里的东西该不该入库」仍未决。
- make-dmg 的 `hdiutil create -fs HFS+` 是为了把 `/Applications` 符号链接显示成可拖入的
  文件夹别名的经验做法，未在 macOS 26 之外的版本上复核。
- 数据根缺失的**对话框**仍是缺口，跨机模拟现在能把「静默」量成红/绿，但它只能证明
  「会报错」，不能替代「会告诉用户怎么办」。

**放弃**：
- 放弃「dmg 里塞数据树」的念头：1.6GB，且与本机 `ConcordRTS-GameData` 同源，
  打进去等于每轮多拷 1.6GB，收益只是省一步操作。

## 七、清单体检（十项门禁 + 人工两项）

`ledger-check.sh`：fix-plan 347 行 / queue 65KB / 35 条 / rules 5 类 / detail 0 条超 6 行 /
dup-id 0 / entry-fields 0 缺 / RUNLOG 929 行 / refs-head 0 → **十项全绿**。
人工体检（三项，第三项是本轮最像 S-27 的那一条）：
1. `EVO-进化路线图.md:83`「两份 thin 产物各出一个 dmg」已被 universal 单包推翻 → 改口径；
2. EVO-07 的 detail 里 ④ 段从「待做」改成「已交付（R55）」，attempts 1→2，
   ②③ 仍 pending ——**不许把分段交付当整条结案**；
3. **`queue.json` 的 `decisions.note` 写着「只留最近 4 轮决策（51/52/53/54）」，而
   `decisions.recent` 里实际躺着 32/33/34/35——note 描述的数据早就不在那儿了。**
   十项门禁全报不出（它只数字节/条数/字段，不读 note 是否属实）。处置：旧摘录移
   `queue-archive-202611c.json` 的 `decisions_recent_legacy`，note 改成与数据一致的
   「正文在 `decisions_<日期>_r<轮次>` 键里，本数组只放最近 1 轮」。
   教训同 §六：**散文里的口径会漂，而门禁只量形状。**

## 八、质量四数

- 净增：**+134 行**（`10013d1` +129 说明书、`b4672b5` +5/−1 注释）。产品代码净增 **+0**。
- 最大单文件：`RuntimeShell.cpp` **90,715** / `RuntimeMapRenderer.cpp` **42,542** /
  `RuntimeSessionWorld.cpp` **30,794** —— 三者与 R54 完全持平（本轮没碰它们）。
- 断言 0 组新增 / 产品代码 0 行新增 —— 比例 0/0，不构成「靠断言刷绿」。
- TODO/FIXME：**0 → 0**。
