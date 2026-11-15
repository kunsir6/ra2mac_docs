# 第 53 轮：对战 wire 格式两族编解码器收口（S-20）

**轮型：修复轮。** 主目标 S-20（中等 / A）。源码 1 个提交 `6efad17`，文档仓库 2 个提交。

零、轮型判定：无 brake（R52 已结案）、无 attempts≥3 且未结案（M-25 已 blocked 随线收口）、
无腐烂预算（R50/R51/R52 净增 0 / 0 / +215）、距 AUDIT-51 一轮 → 修复轮。

**一处对计划的偏离（写清理由）**：R52 收口写的是「R53 取 EVO-07」。开工按 §七.3 重估后改为 S-20，
EVO-07 降级并附条件（见 §六）。理由不是「EVO-07 难」，而是它**在本环境无法验证**：
数据根缺失提示要新开一个 AppKit 模态面（弹窗 + 选目录），本项目不调 `[NSApp sendEvent:]`、
本机 Accessibility 未授权（合成鼠标/键盘事件被丢），交互路径既做不出可信判据也做不出取证。
50 分钟预算内交付的只会是「未验证的 UI」，正是 §八.4 的未完成。它该单独成轮先写方案。

---

## 一、根因：不是「重复」，是**已分叉**

`snapshots/RuntimeMultiplayerSnapshotTransfer.cpp` 与 `protocol/RuntimeMultiplayerMatchSetup.cpp`
各自在匿名命名空间里定义了一套 `ByteWriter` / `ByteReader`。第 36 轮逐行 diff 的结论本轮复核仍成立：

| 维度 | snapshot 侧 | match setup 侧 |
|---|---|---|
| 错误文案前缀 | `"snapshot "` | `"match setup "` |
| `require()` 下溢守卫 | `offset_ <= size && count <= size - offset_` | 只有 `count <= size - offset_` |
| 写方法集 | `writeByteVector` / `writeArray` | `writeBool` |
| 读方法集 | `readByteVector` / `readArray` | `readBool`（带 `> 1` 校验） |

两条路径对敲同一批字节流。分叉的后果不是编译错误，是联机时「对面拒收」，而且**回归一条也看不见**
——`regress.sh` 的 13 条里没有任何一条走这条路径（本轮为此新增第 14 条，见 §三）。

## 二、改法：一份实现 + 前缀参数化

新头 `src/network/detail/RuntimeBigEndianCodec.h`（`concord::network::detail`）：

- 方法取两侧**并集**，两个 .cpp 里的 `ByteWriter` / `ByteReader` 改成 `using` 别名 →
  所有既有调用点一字不改，diff 只剩删除。
- 错误文案前缀改由读取器构造参数 `label` 提供（`"snapshot "` / `"match setup "`），
  于是 `"snapshot chunk payload is truncated"`、`"match setup … boolean is invalid"` 等
  **每条既有错误字符串逐字节不变**，既有断言文案零改动、也没有断言纠正。
- `require()` 统一取带守卫的那一版。原 match setup 那版靠「`offset_` 恒 ≤ size」这个
  隐含不变量才安全——把不变量换成显式判断，代价是 1 行。

**这条改法同时否掉了 S-20 原估值里的一句话**：「合并必然改错误文案，所以必须先取得允许改文案的窗口」。
不需要那个窗口——把前缀做成参数就绕开了。原成本 中 → **低-中**（实际一次编译即过）。

## 三、DoD：等价性怎么证的（不用「单测绿」）

原来的 DoD 是「同一字节流两边解码结果逐字段相同」。**合并之后这句话自我作废**——两边只剩一份实现。
所以本轮改用**改动前后输出逐字对比**（与 R33 删 647 行时验等价的做法一致）：

```
五条对战冒烟（snapshot-v15 / runtime-binding / house-authority /
gameplay-authority / authoritative-hash）改动前后输出 → diff 为空
```

结果：`IDENTICAL-OUTPUT`。这不是「跑绿了」，是**同一批字节在两条路径上的可观察行为逐字节没变**。

**新增日常门禁（第 14 条）**：`run_case multiplayer 120 "" "--multiplayer-snapshot-v15-smoke-test"`，
实测 0.07 秒。选它的理由：它是唯一一条把 snapshot 编解码走完整往返的冒烟，且不需要窗口。
全量回归随即 `PASS=13 KNOWN-RED=1 RED-NEW=0 共 14 条`。

## 四、质量四数

| 指标 | 本轮 |
|---|---|
| 净增行数 | **−79**（+241 / −320；两个 .cpp 只减不增，新增的 221 行是共享头） |
| 最大单文件（HEAD 口径 `git show HEAD:<f> \| wc -l`） | `RuntimeShell.cpp` 90,715 / `RuntimeMapRenderer.cpp` 42,542 / `RuntimeSessionWorld.cpp` 30,794（三者与 R52 持平） |
| 断言 vs 产品代码 | 断言 **0 组新增**（等价性用前后输出对比，不新增断言）；产品代码净 −79 行 |
| TODO / FIXME | 0 → 0（三个改动文件均为 0） |

`6efad17` 的改动行数 561（+241/−320）超过「单 commit ≤200 行」的字面值。**这是搬移不是新增**：
净 −79，两个 .cpp 里只有删除和两行 `using`。拆成两个 commit 会让中间态编译不过（头文件先落地、
调用点后改则两份实现同时存在，反而更糟），故保持一个 commit，在此说明。

## 五、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：EVO-07（见 §六，降级）；S-24（前置 `RuntimeVehicleInfantryPassThroughSmoke.inl`
  仍是并发会话的未跟踪文件）；任何并发 WIP 文件（`RuntimeShell.cpp` +41、`World.cpp` +282 等 11 项零触碰）。
- **遗留债 1**：第 14 条的「证据列」取到的是 `Failed to open INI file: snapshot-smoke.map`
  （冒烟在地图缺 INI 时的无害告警）。PASS 时无所谓，但它不是这条冒烟的主判据行；
  真红时 `pick_evidence` 会不会取到同一行**没验过**，第一次变红时要人看一眼。
- **遗留债 2**：`RuntimeMultiplayerMatchSetup.cpp` 那侧的解码路径仍只有
  `--skirmish-build-smoke-test` / 对战冒烟覆盖，而它们都不在 regress 里。第 14 条只兜住 snapshot 半边。
- **放弃了**：给共享 codec 加「金样字节」固定断言（防止将来无意改 wire format）。
  原因是它得挂在 `RuntimeShell.cpp`（WIP 文件）里的某个冒烟上，本轮不碰；已写进下轮候选。
- **放弃了**：把 `fail(std::string&, std::string)` 这个小助手也搬进头文件。两个 .cpp 各留一份，
  5 行重复，收益不抵一次额外改动面——记在这里而不是偷偷留着。

## 六、EVO-07 重估（§七.3 要求：调顺序必须同时调估值）

| 项 | 原估值 | 本轮重估 | 依据 |
|---|---|---|---|
| 收益 | S（双击是用户第一触点，数据根缺失现在是静默失败） | **S 不变** | 静默退出确实是首触点问题，`runtimeDataRootDiagnosticText` 已写好但只进 stderr，GUI 启动看不到 |
| 成本 | 未估（queue-only 条目） | **高（复杂）** | 需要新开一个 AppKit 模态面（NSAlert / NSOpenPanel）+ 选目录后回写 `Contents/Resources/data-root` + 一条不依赖用户点击的上屏自证；触及呈现层 |
| 可验证性 | 未评 | **本环境不可验证** | 不调 `sendEvent`、Accessibility 未授权 → 按钮点击无法走真实事件队列；`performClick` 类自测按 §八.4 不算通过 |
| 结论 | 下轮起手 | **单独成轮先写方案**，方案需先回答「交互判据怎么做」 | 与 C-01（sendEvent）同源，可能互为前置 |

它的 `About`（版本/架构/构建时间）与 `dmg` 分发是另外两件、与弹窗无依赖的小事，
可以在一轮里做（都能用「读出二进制内嵌常量 + hdiutil 挂载后跑一次 smoke」验证），不必等方案。

## 七、清单体检（§一.7）

`ledger-check.sh` 十项门禁全绿：fix-plan 341 行 / queue 64KB / 35 条 / rules 5 类 /
detail 超 6 行 0 条 / 重复 id 0 条 / 缺估值字段 0 条 / RUNLOG 884 行 69KB / refs-head 0 条。

人工复查（门禁查不出的那一类，AUDIT-51 的教训）：

1. **状态与报告矛盾 1 处**：S-20 的 `report` 字段指向 `FIX-36-清偿轮-两族克隆实现收口.md`
   （登记时的出处），而结案报告是本文件。已在本轮把 `report` 改成本文件、并保留 FIX-36 作为
   「首次登记」的第二链接。
2. **attempts 与收口记录**：S-20 attempts 一直是 0（从未动手），本轮一次过，不需要 +1。
3. **等价替换**：本轮没有新增条目（第 14 条是门禁不是条目），故不需要归档换出；
   已完成段按「最近 10 条」口径把最旧的 M-23 压回归档指针行。
4. **门禁数量口径**：队列/计划里若有「回归 11 条 / 13 条」的旧说法，本轮起以 **14 条** 为准。

## 八、两级计数

- 条目级：S-20 0 → **已完成**。其余无变动；M-25 = 3（blocked，随 unit-behavior 线收口）、
  S-28 = 1（blocked，deferred）、M-29/S-23 attempts=1 均已结案。
- 主线级：`preview-dedupe`（S-20 原挂在此线）本轮**用满收口**——R36（两族克隆收口）+ R53（wire 编解码）
  共 2 轮 2 个子项，判 **done**。`unit-behavior` 已 blocked，禁开第 5 子项。

## 九、构建与交付

- arm64：`ninja -C build-product-arm concord_runtime` 60 目标（含 2 个改动 TU），一次过。
  （首次替换按行号切多了、编不过，`git checkout` 重做改为按标记切，见下「操作记」）
- x86_64：增量 5 目标，1.2 秒。
- `lipo-universal.sh`：`archs x86_64 arm64`，两切片 minos 均 12.0，ad-hoc 重签通过。
- `pack-dist.sh --bin build-universal/concord_runtime`：icon diff-vs-generic **96.2/255**、
  plist 身份 `org.concord.rts.yuri` / `尤里红警` / `source=6efad17`、包内 `--smoke-test rc=0`。
- Rosetta 交叉切片：`arch -x86_64 dist/尤里红警.app/... --smoke-test` → **rc=0**（只跑本机原生架构是盲区）。
- `dist/BUILD-STAMP.txt`：
  `6efad17 2026-11-15T14:37:49 regress=pass13/known1/new0 arch=arm64+x86_64 minos=12.0 icon=96.2 rosetta=rc0 pack=incremental+lipo-universal wip=concurrent(11)`

**操作记（下轮别再踩）**：按行号切代码块时，`sed -n '19,200p'` 的第一行**不是** `class` 那一行
（`class` 在 18、`public:` 在 19），于是切出来一个孤立的 `class ByteWriter {` 留在原地，
报错是「member 'ByteWriter' has the same name as its class」——**这个报错的真因是残留了半截类头，
不是名字冲突**。改成按文本标记切（`text.index('class ByteWriter {')` 到下一个 helper 的定义）一次过。
