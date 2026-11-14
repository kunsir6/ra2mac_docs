# FIX-36 — 第 36 轮（2026-11-14）：清偿轮 · 两族克隆实现收口

**轮型：清偿轮**（§0.3 第三条件触发：近 5 轮 `test:`3 / `fix:`0 = **3.0×**，且 §八.3 比例闸同时生效 → 本轮禁止新增断言、只许改产品行为或清偿）。

**主目标**：把审计连续两轮列在「产品侧同构代码」里的两族**逐字克隆**收成单点实现。产品行为零变化（纯 `refactor:`），净增 **−103 行**。

---

## 一、为什么选这两族（估值与排序依据）

AUDIT-35 §4 的口径下，产品侧 7 组同构代码逐个读过之后，只有两族同时满足「改动局部 / 根因明确 / 可独立 revert」：

| 候选 | 判据 | 结论 |
|---|---|---|
| `RuntimeMapRenderer` 炮塔 ↔ 炮管（19921/20001） | 两个函数 78 行，**逐字相同**，只差 4 处常量/accessor；且共用一段「体旋转下的挂载点换算」——两份一旦漂开，炮管会相对炮塔脱开 | **做**（收益 B：视觉正确性的单点；成本低：单文件、调用点 2 处不变） |
| `ArtDatabase` 四个动画层入口（171/201/241/271） | 审计按 25 行窗口只抓到 2 对，实际是**四份**，12 字段解析逐字相同，只有 key 拼法与目标 vector 不同 | **做**（收益 C：解析口径单点；成本低） |
| 多机对战两份 `ByteWriter`/`ByteReader` | 深入比对后**已漂 3 处**：错误文案前缀（`snapshot ` vs `match setup `）、`require()` 下溢写法、方法集（`writeBool`/`writeArray`/`readByteVector`） | **不做**，登记 S-20（见三） |
| `drawRuntimeLowBridgeTmpSpriteToLayer` ↔ `...HighBridge...` | 骨架相同但**三处行为差异**：low 有 `authoredEmpty` 提前返回、high 要 camera 且画完要盖 ownership、子瓦片查找器不同 | **不做**：合并只能靠布尔开关，是拿一种屎山换另一种 |
| `RuntimeShell.cpp:74791 ↔ 85151` | 该文件有并发会话未提交改动 | **不动** |

---

## 二、改法与读数

### 1. 炮塔 / 炮管（`04e366d`，+76 / −112，净 **−36**）

新增两个共享点，两个入口各剩 20 行：

- `runtimeVxlSharedPartCenter(...)`：`runtimeVoxelTurretOffset` → 体旋转下的 mount 换算 → 叠加 `CONCORD_VXL_{TURRET,BARREL}_PIXEL_OFFSET_{X,Y}`。**数学逐字保留**（含 `bodyFitScale > 0 ? : 0.50` 的默认 0.5 与 `lround` 的两轴投影式）。
- `drawRuntimeVxlPart(...)`：候选帧遍历 + owner remap + `drawRuntimeVoxelImageSprite` 调用。`drawRuntimeVoxelImageSprite` 的实参**序列不变**（含末尾 `opacity, 0.0, bodyRotation`）。

两个入口现在只差：像素偏移环境变量名、相对缩放 accessor（`runtimeVxlTurretRelativeScale` / `...Barrel...`）、候选列表（`metadata->turretCandidates` / `barrelCandidates`）、cache key 后缀（`|turret` / `|barrel`）。

**行为等价性依据**：`runtimeVxlPixelOffset` 是纯函数（`runtimeEnvDouble` 读环境变量，`RuntimeMapRenderer.cpp:695`），无副作用、无缓存；X 先于 Y 的求值顺序保持原样。

### 2. 动画层解析（`1563d7a`，+18 / −85，净 **−67**）

`addAnimationLayer(ini, art, id, key, target)` 承接 12 字段解析（`image / damagedImage / offsetX / offsetY / ySort / zAdjust / powered / poweredLight / poweredSpecial / poweredEffect`，共 10 个读点 + key + image 早退）；四个原入口退化成一行转发（`"ActiveAnim" + suffix` 只出现在 `addActiveAnimationLayer`）。

覆盖：`core`（rules/art 载入）、`build`（建造栏按 art 取图标）、`render`（动画帧）。

---

## 三、被否决的两项（负面信息）

### S-20 登记：同一条线上两套字节编解码器，已漂 3 处

`src/network/snapshots/RuntimeMultiplayerSnapshotTransfer.cpp:17` 与
`src/network/protocol/RuntimeMultiplayerMatchSetup.cpp:13` 各自在匿名命名空间里定义
`ByteWriter`/`ByteReader`（同为**大端**）。逐行 diff 后确认不是复制品而是分叉：

1. 错误文案前缀不同（`"snapshot "` / `"match setup "`）→ 合并会改用户可见文案，可能撞既有断言；
2. `require()`：snapshot 侧写 `offset_ <= size && count <= size - offset_`，setup 侧直接 `count <= size - offset_`
   —— 后者在 `offset_ > size` 时下溢成巨值（当前不可达，因为每次推进都被 `require` 守过，属**防御性漂移**）；
3. 方法集不同：setup 多 `writeBool`/`readBool`，snapshot 多 `writeByteVector`/`readByteVector`/`readArray`。

**结论：合并必然改行为，清偿轮不许做**（§五.2 禁止顺手改行为）。成本估「中」：新头文件 + 统一错误文案 + 同步任何断言文案；
收益 A（这条协议是两边对敲的 wire format，漂开与分叉同等级的风险）。

### low/high 桥面精灵：三处行为差异，拒绝用布尔开关合并

`26804` 与 `26863` 各 59 行、骨架 ~90% 相同，但合并需要 `bool highBridge` 控制「authoredEmpty 提前返回 / 是否盖 ownership / 用哪个子瓦片查找器」。
一个函数靠开关分叉两个语义，比两份 59 行更难读，也更难在下次改动时判断影响面。**不合并，理由记在此处防下一轮误删。**

### 顺手看过、决定不动的

- `progress/undefined-symbols.txt`（49KB，2026-11-10）：RUNLOG 有 5 处按路径引用它作复核依据，删了会让历史结论失去可核对性 → **保留**。
- 项目根 `runtime_amphibious_transport_smoke.ini`（7KB，C-02 期间的冒烟落盘）：两份仓库都不跟踪、任何脚本都不读它，删不删都不影响构建与回归 → **保留**（无收益，且它是 C-02 已结案现场的实物）。

---

## 四、验证强度（凭什么说「行为不变」）

| 验证 | 结果 |
|---|---|
| 回归 `regress.sh` | `PASS=10 / KNOWN-RED=1 / RED-NEW=0`（`20261114-081543`），与基线 `20261114-080824` **逐条一致**；`command` 失败前缀逐字未变 |
| `CONCORD_COMMAND_SMOKE_VEHICLE_TERRAIN_SLOPE_ONLY=1` | 原生坡度 16 例全 PASS（ROBO/MTNK/FV/SAPC 四车体）；随后卡在 `local_data/rulesmd.ini`（原始 retail 规则不在本机，属既有环境缺口，与本次改动无关） |
| `CONCORD_COMMAND_SMOKE_VEHICLE_BODY_ONLY=1` | `... independent turret yaw ... =ok`，车体/炮塔分轴、缓存与命中面全过 —— 这是本轮渲染改动的**直接**覆盖 |
| 构建 | `concord_runtime` 两次增量链接通过（55/55、56/56，无新增 warning 类别） |

未做：没有做「旧二进制 vs 新二进制逐像素对比」。理由——本次是同一 TU 内的算式搬移，字符级保留了公式与实参序列，
像素差异只可能来自我改错；而 `VEHICLE_BODY` 那条冒烟已经在 `turret yaw` 上把「画在哪」判过。

---

## 五、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：不动 `RuntimeShell.cpp`（并发会话正在改：`compat/win32/src/RuntimeWin32CompatText*` 等 7 文件 +324 行，以及新增的
  `RuntimeVehicleInfantryPassThroughSmoke.inl`——那是 M-25 的在飞工作）；不做 `ByteWriter/ByteReader` 合并（会改行为）；
  不给 `low/high` 桥面加开关合并；不删 `undefined-symbols.txt`。
- **遗留的债**：①S-20（两套 wire 编解码器）已登记，等一条「允许改错误文案」的窗口；②产品侧同构代码本轮清掉 2 族，
  AUDIT-35 的 7 组里还剩 5 组，其中 3 组已判「不合并」（见三），真正待办只剩 S-20；③比例闸仍在（近 60 提交 `test:`33 / `fix:`14），
  第 37 轮仍禁新增断言。
- **放弃了什么**：放弃「顺带修掉 setup 侧 `require()` 的下溢写法」。它是防御性漂移、当前不可达，按「清偿轮不改行为」原样记录在 S-20 里，
  不做静默修正——静默修正会让下一轮审计拿不到「两套实现到底差在哪」的清单。

---

## 六、质量四数

| 指标 | 值 |
|---|---|
| 本轮净增 | **−103**（`04e366d` −36 / `1563d7a` −67） |
| 最大文件 | `RuntimeShell.cpp` 90,482（我 **+0**，其中 +6 是并发会话 WIP）｜`RuntimeMapRenderer.cpp` 42,578 → **42,542（−36）**｜`RuntimeSessionWorld.cpp` 30,794（+0） |
| 断言 vs 产品代码 | 新增断言 **0** / 产品行为净变 **0**（纯重构，净 **−103** 行） |
| TODO / FIXME / HACK | **0 / 0 / 0**（改动前后一致） |
