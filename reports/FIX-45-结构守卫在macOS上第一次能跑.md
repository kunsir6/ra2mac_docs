# 第 45 轮（修复轮）：结构守卫在 macOS 上第一次能跑，基线死条目清零

> 轮型：**修复轮**（无 brake / attempts≥3 / 腐烂预算；距 AUDIT-41 四轮）。
> 主目标：**S-13**（结构守卫基线列着已删文件）。
> 编号避让：并发会话在同一时段做了**第 44 轮**（S-23 落位侧根因，`114453a` + docs `91a8511`/`8c6c747`/`1456500`，
> 并占用了 `S-25` 这个号）。本轮取第 45 轮，新条目从 `S-26` 起。源码仓库并发 WIP 11 项全程零触碰。

## 一、结论先说

S-13 登记了三轮，一直写着「先查清产物由谁生成，约 30 分钟」。查清了，那句估值是错的：

**完整检查链只有 Windows 版本。** `tools/testing/Run-StructureChecks.ps1` 要求 `pwsh 7` + `clang-cl` +
MSVC 前端 + CTest，`--inventory` 由 `Get-TestInventory.ps1` 生成，`--trace` 是那一轮 configure 的
`configure-trace.jsonl`。这三个产物在 macOS 上不存在，所以守卫在本机**从来没有跑过**——
`API.md` 里写着入口，但那个入口是 `.ps1`。这不是「补两条基线」的问题，是一整条取证链缺席。

但这条链里有一半不需要构建产物：守卫自己的 366 例合成夹具，和「例外表里的路径还在不在」。
本轮把这一半接成 macOS 可跑的入口，并把积下来的死条目清干净。

## 二、关键发现

### 2.1 死条目精确是 16 条 / 3 个文件，其中 1 条是第 39 轮自己造的

`structure-baseline.json` 有 5,267 条例外。按 `path` 形状分三类（这个分法是关键，见 2.2）后：

| 类别 | 条数 | 能否离线验 |
|---|---|---|
| 文件路径 | 3,999 | 能——路径必须存在 |
| `target:<cmake 目标>` | 923 | 不能，要 CMake file-api |
| `test:<ctest 名>` | 345 | 不能，要 CTest 注册表 |

3,999 条文件路径里，**16 条指向已删文件**：

- `src/ui/selection/RuntimeSelectionFrameRaster.h` —— 8 条（U-15 删的）
- `src/ui/selection/diagnostics/RuntimeSelectionFrameRasterContract.inl` —— 7 条（U-15 删的）
- `src/runtime/window/win32/diagnostics/RuntimeScenePaintTrace.inl` —— 1 条 `platform-type: RECT`

第三条值得单独说：那是**第 39 轮**（`77e75e7`）清偿时删掉的一次性阶段探针。删了文件、没删基线条目。
也就是说「删文件要回写基线」这件事，四轮前刚被自己违反过一次，而没有任何东西会因此报警——
这正是本轮要装的闸。

### 2.2 一度把 1,284 条数成「悬空」，那是口径错误

第一次统计时我把所有 `path` 都当文件路径，得到 581 个不存在的「路径」、1,284 条悬空。
其中绝大多数是 `target:` / `test:` 前缀的**名字**，本来就不是路径。审计里吃过同型的亏
（「分组之和 != 总数」说明混进了第二套记账），这次改法是：三类计数必须相加等于总条目数，
对不上就直接报错退出，而不是把差额当「其他」。

改完之后的真实指标：`exceptions 5251 (file 3983 / target 923 / test 345)`，
`offline-unverifiable: 1268 names`。这 1,268 条**本轮一个字没动**——它们需要 Windows 侧产物，
猜不得。以前它们混在「路径」里，既让悬空数虚高 80 倍，也让「离线不可验」这个事实隐身。

## 三、改法

两个新脚本，都在 `ConcordRTS/tools/structure/`：

**`check_baseline_refs.py`（`c84f14b`，+123）** —— 只查不需要构建产物的那一半。
`path` 不以 `target:` / `test:` 开头的例外，其文件必须存在；`protectedModules` 的 35 个模块同理。
三类计数之和与总条目数对不上时退出码 2（基线本身不可用），`--strict` 下发现悬空退出码 1，
`--output` 落一份 JSON 证据。

**`run.sh`（`4e395b5`，+83）** —— macOS 入口，三段：

1. `test_structure_guard.py` 合成夹具（**366 例，1.4 秒**）——守卫的判据本身还准不准。
   这段一直是能跑的，只是没人知道它能单独跑。
2. 上面那个引用完整性检查。
3. `--inventory` / `--trace` 都给了才跑完整 scan；缺产物时**打印跳过原因**，不假装跑过。

`--baseline <json>` 是为负向验证加的：能指向另一份基线，负向测试因此可以驱动整条脚本，
而不是只测那个 Python。

**`structure-baseline.json`（`f97d1b1`，−176/+7）** —— 删掉那 16 条，并在 `reviewedUpdates`
里记一个 `R44/S-13` 批次（date / owner_step / batch / reason / evidence），写明删了哪三个路径、
分别是谁删的、只删死条目不放宽任何现存预算。基线 `policy` 写明「永不自动重生成」，
所以这次是人工复核后手写批次记录，不是脚本重算。

### 3.1 一个 bash 3.2 的坑（当场踩到）

第一版 `run.sh` 用数组承载 `--strict`：

```bash
refs=(); if [ "$STRICT" -eq 1 ]; then refs+=(--strict); fi
... "${refs[@]}"
```

macOS 自带 bash 3.2，`set -u` 下空数组展开 `${refs[@]}` 直接 `unbound variable`。
改成空字符串承载（`refs=""` → `${refs}` 不加引号）后正常。这个坑与本项目记过的
「`set -u` 下 `$VAR` 后接全角字符被吞进变量名」是同一族：**bash 3.2 + `set -u` 的空值展开**。

## 四、验证

**正向**：`bash tools/structure/run.sh --strict` → `RC=0`，

```
exceptions         5251  (file 3983 / target 923 / test 345)
protectedModules     35  missing 0
stale file paths      0  distinct 0
offline-unverifiable: target 923 + test 345 = 1268 names
```

夹具 366 例 `OK`（1.37~1.47 秒，跑了四次，稳定）。

**负向**：往一份基线副本里塞 `src/this/file/was/deleted.h`（`/tmp/baseline-bogus.json`，不动真台账）：

```
stale file paths      1  distinct 1
    1 entries  src/this/file/was/deleted.h
FAIL  基线仍有指向已删文件的例外
NEG_RC=1
```

改前（真基线，未删条目时）同一命令报 `stale file paths 16 / distinct 3` 且列出三个路径，
改后 0。所以这个闸既能点名，也确实被删干净了。

## 五、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做**：

- **完整 scan 一次都没跑**。它要 `--inventory`（CMake file-api codemodel + CTest 注册表）与
  `--trace`，两者都得 Windows 侧生成。所以「守卫真的在守分层」这句话本轮**仍然不成立**，
  成立的只是「守卫的判据没坏，且它的例外表没指向空气」。
- **1,268 条 `target:`/`test:` 例外没验**。它们是目标名和用例名，离线无从判断，宁可显式标
  「不可验」也不猜。
- 没动任何 C++、没新增断言、没改产品行为——本轮 `test:` 与 `fix:` 都是 0。

**遗留的债**：

- 登记 **S-26**：把 inventory/trace 生产者搬上 macOS。可行路径是 CMake 在本机本来就能生成
  file-api codemodel，`ctest --show-only=json-v1` 能给用例注册表，所以不必照搬 PowerShell；
  但这是中等偏复杂的一条，要单独成轮。**在这条落地前，结构守卫的日常价值只有本轮装的两段。**
- S-13 的 DoD 原文是「守卫能跑通且 baseline 与当前源码树一致」。前半句只做到离线那一半，
  已按实情标注，不改成「已完成」就完事。

**放弃了**：

- **没有把 `run.sh` 接进 `regress.sh`**。它 1.4 秒、纯静态、零构建依赖，看起来很适合当第 14 条；
  但 `regress.sh` 的退出码语义是「RED-NEW 条数」，把一条工具自检塞进去会让「红了几条」这个
  数字失去含义（第 25 轮 `ledger-check.sh` 就因为这个没接）。正确做法是并列成独立入口，
  或者等 S-26 落地后一次性接「完整 scan 才是门禁」。本轮先不制造一个语义混乱的门禁。
- 没有顺手去数另一个方向的漂移（基线里 `maxOccurrences` 是否高于实际出现次数）——
  那要真正扫描，属完整 scan 的职责，不在本轮假装做了。

## 六、质量四数

| 指标 | 数值 |
|---|---|
| 本轮净增行数 | **+206**（源码仓库两个脚本；基线收紧 −176/+7 另计 → 全轮 **+37**） |
| 最大单文件行数 | `RuntimeShell.cpp` 90,652（并发 WIP +26，本轮零改动）/ `RuntimeMapRenderer.cpp` 42,542（0）/ `RuntimeSessionWorld.cpp` 30,794（0） |
| 断言 vs 产品代码 | 新增断言 **0** / 新增产品代码 **0** |
| TODO / FIXME / 探针 | **0**（`tools/structure/` 下 `git grep` 无命中；本轮未植入任何临时探针） |

## 七、清单体检

- `ledger-check.sh` **九项全绿**：fix-plan 238 行 / queue 62KB / 35 条 / rules 5 类 /
  detail 0 条超 6 行 / dup-ids 0 / entry-fields 0 / RUNLOG 679 行 / 46KB。
- 主语料零悬空：本轮引用的 `reports/FIX-45-…` 与三个源码路径都存在；`structure-baseline.json`
  自身的 16 条悬空已在本轮清掉（这算「关联产物」层面的体检，顺手做了）。
- 状态与报告矛盾：修 1 处——S-13 的 `cost` 写「约 30 分钟」与实测不符，改「中高」；
  `complexity` 简单→中等（拆分后剩 S-26）。
- 1:1 替换：新增 **S-26** ↔ 归档 **S-18**（菜单挂机 37GB，done，正文早就在归档里，
  本轮只是把它从「最近 10 条」窗口挤出去）。
- **编号冲突一次**：并发会话本轮占了 `S-25`，我原打算用的号撞上，改用 `S-26`、轮次取第 45
  （他们已用掉第 44）。这是第 31 轮同一坑的第二次，说明**并发会话的编号必须在开工时先读一次
  queue 的最新版本**，不能沿用上一轮的记忆。

## 八、两级计数

- **条目级**：S-13 attempts 0 → **结案**；S-26 attempts 0（新登记）；C-02i/EVO-06 仍 blocked（2/1，不动）。
  没有任何条目到 3。
- **主线级**：`S-结构守卫` **1 轮 / 1 子项**（S-13 done）+ 新开 1 子项（S-26）= 2 子项 / 2 轮，
  窗口还剩 2 子项 / 2 轮。其余主线（unit-behavior 3/4、S-回归门禁 3/4、sidebar-veterancy 1/4）
  本轮零触碰。
- 深水区连续轮次：无（S-13 是简单/中等，不是深水区）。

## 九、dist

`BUILD-STAMP.txt`：

```
f97d1b1 2026-11-15T04:21:52 regress=pass11/known2/new0 arch=arm64+x86_64 minos=12.0 icon=96.2
rosetta=rc0 pack=repacked(bin=114453a,full-rebuild-0418) delta=tooling-only wip=concurrent(11)
```

- 本轮**没有重编**：三个 commit 全是 Python/JSON 工具与基线数据，不进任何编译单元，
  重编只会产出逐字节相同的二进制，而 `build-product-arm` 现在是并发会话 04:18 全量编出来的树
  （含 11 项未提交 WIP）。重编等于把别人的在飞改动烤进用户的包，属 §十二.3 的「最新但可能坏」。
- 因此 dist 的二进制是 `114453a`（并发会话 04:18 全量重编：arm 4m17s + x86_64 增量 2m51s → lipo → pack），
  与当前 HEAD `f97d1b1` 的差异**只有本轮三个工具/数据 commit**，产品代码逐行相同。
  `pack=repacked(bin=114453a)` + `delta=tooling-only` 就是写这件事，不许含糊成「最新」。
- 门禁逐条过：`lipo -archs` = `x86_64 arm64`；两切片 `minos 12.0`；plist `LSMinimumSystemVersion=12.0`；
  包内 `--smoke-test` rc=0；`arch -x86_64 … --smoke-test` rc=0；icon `diff-vs-generic=96.2/255`；
  plist `source=f97d1b1`（pack-dist 自己读的 HEAD）。
- 回归：`PASS=11 KNOWN-RED=2 RED-NEW=0`（`20261115-041915`，13 条）。
  `compactgroups` 的前缀**在新文案下仍命中**——并发会话加的取证是追加在分号后面的，
  前缀只钉「计数 + 首个失败场景」，这正是第 43 轮把两个维度都钉住的设计意图。
