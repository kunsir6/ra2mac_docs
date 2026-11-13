# 地图预览自带第二份 TMP 解码器（第 33 轮，清偿轮）

**轮型：清偿轮（换赛道）**。三项独立触发：①§八.3 比例闸——近 60 提交 `test:` 33 / `fix:` 16 ≈ 2.06×；
②§六.6 换赛道——`skirmish-option-semantics` 连续 2 轮（31/32）零产品行为变化；
③§六.6 优先级首位即清偿。本轮**不开任何新功能条目**，KPI = 净增 ≤0 且 regress 不退化。

**主目标**：删掉 `MapPreviewExporter.cpp` 里那份与 `RuntimeTmpCodec` 分叉的 TMP 解码器。

---

## 一、账目

| 项 | 值 |
|---|---|
| 单文件改动 | `MapPreviewExporter.cpp` **−647 / +8**（7,479 → 6,840 行） |
| 构建脚本 | `cmake/GameTargets.cmake` +1（给 `concord_rules_dump` 补 `RuntimeTmpCodec.cpp`） |
| 提交 | `b2ebc4c` refactor(preview) |
| 回归 | `10/1/0`（`20261114-044630`），`command` 失败前缀不变，**零新回归** |

---

## 二、为什么可以删（不是"看着像重复"，是逐函数比对过的）

把 `git show HEAD:` 的旧文件与被保留的 `RuntimeTmpCodec.cpp` 按函数配平花括号抽出来，去注释与空白后比对：

| 函数 | 结果 |
|---|---|
| `findNextTmpImageOffset` | **逐字相同** |
| `validateTmpImageOffsets` | **逐字相同** |
| `decodeRawTmpFormat3Pixels` | **逐字相同** |
| `decodeTmpImagePixels` | **已漂出 8 处实质差异** |

主函数已经不是副本而是**分叉**，差异方向是旧副本落后：

- 旧副本按文件头里的 `extraDataOffset(+8) / zDataOffset(+12) / extraZDataOffset(+16)` 三个偏移字段定位数据，
  再逐个做边界校验；codec 按 `flags` 位（`1=extra`、`2=zdata`）+ 紧凑布局推算偏移。
- codec 额外解出 `terrainType / rampType / radarLeft / radarRight`，旧副本这些字段恒为空。
- 旧副本的 `hasBaseZData` 判 `zDataOffset != 0 && != 0xCDCDCDCD`；codec 判 `flags & 2`。

**产品渲染一直用的是 codec**（`RuntimeMapRenderer` 走 `assets/codecs`），所以两份并存的实际后果是
「地图预览（诊断工具）与游戏内渲染可能对同一块瓦片给出不同解码结果」，而且没人会发现——
C-02 那五轮"多谓词压成一句"的教训在这里是同族：**同一语义的第二份实现不会报错，只会慢慢漂**。

## 三、删法与防复发

1. 本地 `struct TmpSubTileImage / TmpTileFile` 改成 codec 类型的别名（`using`），
   **不留第二份结构体**——否则下次又会有人在本地结构体上加字段、再分叉一次。
2. `loadTmpTileFile / loadTmpTileFileFromBytes` 收成两行包装，直接调 `loadRuntimeTmpTileBytes`
   （codec 自带 raw format-3 回退，旧副本是同名函数各写一份）。
3. 只服务旧副本的 `readUInt32 / readInt32 / signExtendUInt16 / checkedAdd / checkedMul` 一并删掉。
4. `cmake/GameTargets.cmake`：`concord_rules_dump` 之前**靠这份副本才链得上**，删掉后链接立刻失败
   （`Undefined symbols: loadRuntimeTmpTileBytes`）——这一条本身就是"它是副本"的铁证：
   该目标从来没链接过 codec。

## 四、代价与未验证面（不假装是纯删除）

- **行为差异**：预览产物里 z-data / extra 数据的解码立场随 codec 变化。方向是"预览向产品看齐"，
  但**这是一次行为变更，不是零行为变更**，按§五.2 口径记在这里而不是藏进"重构"。
- **没做产物级 A/B**：需要 `--theater-dir`（`ra2md/localmd`）+ `--tile-root` + `--palette-dir` 三件套。
  瓦片能从 `--extract-map-tiles` 抽出来（实测 213 块），但 `isotem.pal` 只在归档里、本机无 loose 副本，
  `--export-map-tmp-preview` 因此卡在 "failed to open file: …/isotem.pal"。
  **旧/新 PPM 逐字节对比没做成**，已登记 S-19 并把重开条件写死。
- 影响面仅限 CLI 诊断产物（`concord_rules_dump`），没有用户可见路径依赖这两条导出。

## 五、质量四数

| 指标 | 值 |
|---|---|
| 本轮净增 | **−638**（−647 / +9） |
| 最大单文件 | `RuntimeShell.cpp` 90,476（**不变**）／`RuntimeMapRenderer.cpp` 42,578／`RuntimeSessionWorld.cpp` 30,794 |
| 新增断言 vs 新增产品代码 | **0 : 0**（比例闸生效中，本轮只许删） |
| TODO/FIXME 增减 | 0 → 0；`CONCORD_*_TRACE` 探针 31 处（未新增、未清理） |

## 六、清单体检

| 项 | 结果 |
|---|---|
| fix-plan | 162 行 / 400（本轮 +2 索引行 +1 条目） |
| queue | 45 KB / 120 KB、35 → 34 条、rules 5 类 |
| `ledger-check.sh` | 六项全绿（含 `dup-ids`） |
| 悬空报告引用 | 0（新条目指向本报告，路径真实存在） |
| 状态与报告矛盾 | 0 新增 |
| 等价替换 | 新增 S-19（1 条）↔ 移出 ON-3-02 至 `deferred.md`（1 条） |

**第 30 轮审计遗留的 12 条未估值条目**：本轮只处置 1 条（`ON-3-02` → deferred，理由见该文件），
其余 11 条**窗口顺延到第 34 轮**。原因写在这里：本轮 50 分钟全部给了代码清偿，
逐条写死因 + 补 5 字段至少还要 20 分钟，硬塞会把两边都做成半成品。

## 七、两级计数

- 条目级：无 attempts ≥2 的活跃条目（C-02i 仍 blocked=2、M-13=2 均未重开）。新增 S-19 attempts=0。
- 主线级：`skirmish-option-semantics` 2 轮 / 1 子项 → 本轮**未动**，按§六.6 换赛道；
  `skirmish-mode-rules` 已判 done（第 31 轮）；`C-02` 已判 blocked（第 25 轮）。
- 比例闸：近 60 提交 `test:33 / fix:16`。本轮 **0 断言 0 行为修复**，是清偿轮应然形态；
  下轮仍是"只许改产品行为或继续清偿"，不解除闸门。

## 八、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做什么**
- 没碰 `skirmish-option-semantics` 的 `unholy` 段（§六.6 强制换赛道）。
- 没做第二条清偿对象（三份键盘冒烟的 WndProc 骨架）：那是 smoke 侧，改动面 3 文件 × 25 行，
  与主目标不同根因，本轮余量不够就不打包——按§四.1"禁止把无关问题拼成一批"。

**遗留什么债**
- **S-19**（新登记，简单）：地图预览产物级 A/B 没做。重开条件 = 先把 `isotem.pal` 从归档抽到
  tile-root 旁的 palette-dir，然后 `git show b2ebc4c^:src/assets/preview/MapPreviewExporter.cpp`
  单独编一份旧二进制，两次 `--export-map-tmp-preview` 出 PPM 比 sha256。**不许在没做之前把这条改判 done。**
- 11 条未估值 queue 条目仍在"永远排不上"状态（见§六）。

**放弃了什么**
- 放弃了"把 `MapPreviewExporter` 整体改成 `RuntimeTmpTileFile` 命名"：会有 40+ 处符号改名，
  diff 从 647 行涨到 700+ 行且全是噪声，收益为零。留别名是更好的取舍，注释已写在类型别名上方。

## 九、下轮起手（第 34 轮）

1. **S-19（简单，优先，30 分钟够）**：抽 `isotem.pal` → 编旧二进制 → PPM 逐字节比。
   这一条不做完，"删了 647 行且行为不变"这句话就一直是不成立的。
2. **11 条未估值条目的处置**：逐条给根因/成本或移 deferred。别再顺延第三次。
3. **不许**开 `skirmish-option-semantics` 子项；**不许**新增断言。
4. 开工前先看源码仓库 `git status`——并发 compat 文本层 WIP（6 改 + 2 新增）仍在，不是本轮产物。
