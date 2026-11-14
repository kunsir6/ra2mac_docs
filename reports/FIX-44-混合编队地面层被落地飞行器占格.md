# FIX-44 — 混合编队：地面单位的目标格被落地飞行器占着（S-23 根因确认）

**轮型：修复轮**（无 brake / 无 attempts≥3 / 无腐烂预算；距 AUDIT-41 三轮）。
**主目标 S-23**：第 43 轮接入的 regress 第 13 条 `compactgroups` 里 `3MTNK_3SHAD` 一直红。
本轮不支持"把问题收窄"——但没有硬把它改成绿：**根因确认 + 取证永久化**，修法二选一留给下一轮
（理由见 §三：分配器不是修点）。

---

## 一、从"收得散"到"谁占了格"

第 43 轮的失败文案只有一句 `ground_final_not_compact`，读数 `groundRadius=2`。
同一个冒烟把每台的起始/目标/落点写进 `units.csv`，重跑一遍就拿到了 1:1 对应关系：

```
3MTNK_3SHAD  地面层 target            空中层 target         最终落点
MTNK#1       (32,28)                 SHAD#4  (32,28)       (30,28)   ← 被 SHAD#4 占着
MTNK#2       (33,28)                 SHAD#5  (33,28)       (32,27)   ← 被 SHAD#5 占着
MTNK#3       (31,29)                 SHAD#6  (31,29)       (31,28)   ← 被 SHAD#6 占着
```

**两层拿到的是同一组格**（这不是 bug，见 §三），而三架 SHAD 的终态是 `airborne=0`——
**落地了**。地面格被落地的飞行器占住，三台 MTNK 只能被兜底逻辑挪到半径 2 的空格。

`settled=1116` 说明它们都停稳了（不是超时），`failures` 里也没有 `ground_cell_overlap`/`air_cell_overlap`
——占位账本身是对的：落地的 SHAD 确实占着格，被挪走的是坦克。

## 二、根因

**分配侧的共享 + 落位侧的独占，两者不冲突但会互相打架。**

1. 分配：地面成员用 `formationReservations`（`assignedTargetCells`），空中成员用独立的
   `reservedAirTargetCells`（`RuntimeSessionWorld.cpp:19499` `findRuntimeAirMoveTarget`）→ 两层可以拿同一格。
2. 落位：飞行器到达目的地后 `airborne` 落回 0，于是重新进入**地面**占位；
   而地面单位的目标格恰好就是这几格，进不去 → 兜底挪到最近空格，且**挪走后不回填**。

实测证据：本轮新增的 `ground_target_reclaimed`（"停到目标格又被挤走"）**一次都没触发**，
说明坦克从未占到过自己的格——冲突发生在它们到达之前，是飞行器先落地占了格。
这条读数顺便否定了一个候选根因（"先停好再被推走"），见 §四。

## 三、为什么分配器不是修点（否决记录）

看似最直接的修法：让空中层避开地面已认领的格。**不能这么做**，因为同一个冒烟的另两条判据把这条路堵死了：

- `ground_target_center_unused`：地面层**必须**用到中心格 (32,28)；
- `air_target_center_unused`：空中层**也必须**用到中心格。

两层注定共享中心。所以"共享格"是**被要求的设计**，冲突只可能出在"落地后按地面占位算"这一步。
把共享改成分离，会先把这两条判据打红——那是把判据改软，不是修缺陷。

## 四、取证永久化（不是临时探针）

改的是冒烟自己的证据层（`RuntimeCompactGroupDensitySmoke.inl`，+69/−1，单 TU）：

| 新增输出 | 回答什么 |
|---|---|
| `ground_target_reclaimed: <type>#<id> (x,y)@<到达拍> -> (x,y)@<被挤拍> by <type>#<id> airborne=<0/1>` | 停好之后被谁挤走（本轮**零触发**，否定了"先停再推"这个候选） |
| `ground_target_unreached: <type>#<id> want(x,y) got(x,y) holder=<type>#<id> airborne=<0/1>` | 压根没到分配格，且该格现在被谁占着 |

两条都**只在 `groundScattered`（地面层真的散到半径外）时才输出**。第一版没有这个闸门，
结果把 `11MTNK` 判红了——它有 7 台没停进分配格，但整体收在半径内、合法。
**"没停进分配格"不是判据**，散到半径外才是。这条闸门是实测撞出来的，已写进注释。

负向验证：全 13 场景 `passed=12 failed=1`，与改动前逐条一致（除 3MTNK_3SHAD 的文案变长）。
known-red 前缀 `Compact groups: 1 failed; 3MTNK_3SHAD: ground_final_not_compact` 仍按"包含"命中，
新增文案追加在其后，不会制造假 `cause-changed`。

## 五、顺手查出的第二个问题：`--command-smoke-test` 首败即断，掩蔽后面 19 步

`command` 这条 regress 用例是**链式**的：`if (!runXxxSmoke(...)) { 打印; return 1; }` 共 60 步。
C-02i（奴隶矿工）在第 54 步，它一红，**后面 19 步全部不执行**：

```
feature-details / factory-exit / air-navigation / missiles / electric-attack / vertical-bomb
/ neutral-garrison / garrison-pip-render / harvester-stability / atomic-save-host
/ object-exit-contract / aircraft-production-host / grinding-host / campaign-restore-initial-buildings
/ timed-bomb-host / parasite-host / bomb-sight-limbo / psychic-status-host / mag-beam-host / airstrike-host
```

而 known-red 的前缀只钉了第一条失败文案（`Command smoke failed: slave miner`）——**它稳得很，所以没人发现尾巴是死的**。
这与第 43 轮的教训同源：前缀只钉一个维度，被掩蔽的东西就永远不报。
两处后果：①这 19 步在 regress 里等于零覆盖；②谁修好 C-02i，这 19 步会**同时**被点亮，
其中若有旧红，会以"修完之后突然红了一片"的形态出现。**登记 S-25，本轮不动代码**（改链式结构要动 60 个分支）。

## 六、构建增量状态损坏：三轮被误判成"并发改 cmake 重配"

`ninja -C build-product-arm -n` 从第 41 轮起一直报 **1,642 目标全量**，报告里连续三轮写成
"并发会话改 `cmake/PlatformApple.cmake` → cmake 重配使对象全失效"。**这个归因是错的**：

```
$ ninja -C build-product-arm -n -d explain
ninja: warning: premature end of file; recovering
ninja explain: stored deps info out of date for 'CMakeFiles/.../IniFile.cpp.o' (1794364742251877435 vs 1794671252412557699)
```

`build-product-arm/.ninja_deps` 尾部被截断，ninja 只能"恢复"并丢弃整份 deps 记账 → 每个目标都判脏。
反证很清楚：**同一时刻 `ninja -C build-product-x86_64 -n` 报 `no work to do`**。
如果真是 cmake 改了全局编译参数，两个目录会一起失效；一脏一净，只可能是单目录状态坏了。

代价：三轮（42/43/44）都因为"重编要四十分钟"而放弃源码修复，实际上全量只需 **4 分 17 秒**
（实测 `1955s user / 130s system / 810% cpu → 4:17.25 wall`）。**这个误判本身比 bug 贵。**
本轮已把全量重编跑完，增量状态恢复（改一个 `.inl` 后只重编 1 个 TU + 链接）。

## 七、质量四数

| 指标 | 数值 |
|---|---|
| 本轮净增（**仅本轮自有改动**） | **+68**（`.inl` +69/−1，单文件单 TU） |
| 最大文件 | `RuntimeShell.cpp` 90,652（并发 WIP +26，本轮未动）｜`RuntimeMapRenderer.cpp` 42,542（持平）｜`RuntimeSessionWorld.cpp` 30,794（持平） |
| 新增断言 vs 产品代码 | **0 / 0**（本轮只加取证输出，产品行为未改） |
| TODO / FIXME | **0** |

## 八、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做**：S-23 没有变绿。`groundRadius` 仍是 2，known-red 那行原样保留。

**遗留债**：
1. **修法二选一未定稿**（下轮第一件事）：(a) 落位侧——飞行器在目的地静默时保持 `airborne=1`（悬停），
   或落地时避开已被地面单位认领/占用的格；(b) 兜底侧——地面单位被挤开后原格空出时回填。
   实测否掉了"先停再推"，所以 (b) 单独不够；(a) 是主候选。**两条都要先在冒烟里跑 13 场景不退化**。
2. **S-25**：`--command-smoke-test` 首败即断掩蔽 19 步，已登记，未动代码。
3. 并发会话的 11 项 WIP 仍在工作区（本轮零触碰），`dist` 因此仍含未提交改动。

**放弃**：没有硬把 S-23 改绿。改分配器会让 `air_target_center_unused` 变红，那是改软判据而不是修缺陷。

## 九、下轮起手

**第 45 轮 = 修复轮**，主目标 S-23 修法 (a)：先只读确认"飞行器静默时是否该保持 airborne"
（`5SHAD`/`5JUMPJET` 两个场景的 airborne 时间线可当免费读数），再改落位分支。
判据现成：`compactgroups` 13 场景全 PASS（0.7 秒），跑一次就知道有没有连带。
`M-28` 仍未被碰过（本轮没腾出时间），仍是 unit-behavior 最后一个槽位的候选。

## 十、dist 门禁读数（本轮**重编**）

```
f97d1b1 2026-11-15T04:27:19 regress=pass11/known2/new0 arch=arm64+x86_64 minos=12.0 icon=96.2
rosetta=rc0 pack=full-rebuild(arm-full-4m17s+x86-incr-2m51s+relink)
wip=concurrent(11 entries in tree, HEAD moved 114453a->f97d1b1 mid-round)
```

**打包期间 HEAD 被并发会话推进了两次**（`c84f14b`/`4e395b5`/`f97d1b1`，都只动 `tools/structure/`）。
第一次包是 `114453a` 的，为了让 stamp 与 HEAD 严格一致，重跑了两切片 + lipo + pack-dist，
最终包对应 `f97d1b1`。这三条提交不参与 `concord_runtime` 的编译，重打的包内容逐字节同前一次，
但「stamp 与 HEAD 一致」这条门禁只有在重打之后才真的成立。

| 门禁 | 读数 |
|---|---|
| `lipo -archs`（包内二进制） | `x86_64 arm64` ✅ |
| `vtool -show-build` 两切片 minos | arm64 `12.0` / x86_64 `12.0` ✅ |
| `Info.plist:LSMinimumSystemVersion` | `12.0`（三处一致，pack-dist 第 ⑦ 步硬门禁已过）✅ |
| `arch -x86_64 … --smoke-test` | `rc=0` ✅ |
| pack-dist 自身门禁 | `displayName=尤里红警` / `id=org.concord.rts.yuri` / icon `96.2/255` / 包内 `--smoke-test rc=0` / `source=f97d1b1` ✅ |
| 回归（新 arm 二进制） | `PASS=11 KNOWN-RED=2 RED-NEW=0`（`20261115-041711`，13 条） |

**`wip=concurrent(11 entries in tree)` 照旧写着**：并发会话的 11 项未提交改动仍在工作区，
本轮零触碰，所以这个包是「HEAD + 那 11 项」编出来的。这是第 42 轮起就存在的口径，
不是本轮新引入的偏差；本轮至少把「arm 切片落后 16 小时」这层风险消掉了（两切片都是刚编的）。
