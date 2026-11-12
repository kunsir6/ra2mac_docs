# FIX-09 建筑零投影：一次被自己的计数器否决的定性（M-18）

日期：2026-11-12（第 8 轮）
关联：`reports/fix-plan.md` M-18 / M-19 / M-20、`reports/FIX-08-时钟纪元与建筑零投影.md` §2
回归：`PASS=8 KNOWN-RED=3` → **`PASS=8 KNOWN-RED=3`**，`RED-NEW=0`（本轮未改变判定，只加了计量）

## 一、开工时的假设

第 7 轮把 `render` 的建筑零投影定性为「**掩码解析成功、但压暗 0 像素**」的产品缺陷（M-18），
理由链是：`shpMask` 为假会退软阴影兜底、而兜底必然压暗像素；既然没退，那只能是掩码本身为空。

本轮先拆掩码侧四元组（`shadowImage` 宽高 / 非零像素数 / span / 阴影中心与 viewport 的关系），
预期看到「有尺寸、有非零、但 span 生成空」，从而定位到 span 生成。

## 二、计量：加了一个环境变量门控的只读追踪

在 `drawRuntimeWorldObjectShadow` 的 SHP 分支、`validMask` 成立且压暗 0 像素处打印
`CONCORD_SHADOW_TRACE=1`（12 行预算）。实跑 `--render-smoke-test`：

```
[shadow-trace] structure type=NATBNK instance=940002 hasFrame=1 authoredEmpty=1
               body=0x0 frame=0x0 globalH=126 nonzero=0
               center=290,223 rect=221,112,221,112 viewport=0,0,640,480 intersects=1
[shadow-trace] structure type=CAOILD instance=5 authoredEmpty=0
               body=76x106 frame=27x99 nonzero=24
               center=-410,661 rect=-415,573,-388,672 viewport=0,0,320,240 intersects=0
```

两条都很有意思：

1. **`NATBNK`（Tank Bunker）整张 sprite 是 0×0**。`artmd.ini` 里 `NewTheater=yes`，而导出集只有
   `art/snow/natbnk.shp`；`2peaks.map` 是 TEMPERATE。加载器给出「loaded=yes、帧 0×0」的条目，
   于是 `authoredEmpty` 短路成立、`shpMask=true`、压暗 0 像素——**这正是 M-18 那个读数的形状，
   但成因是缺美术**，不是阴影缺陷。
2. **`CAOILD` 在 320×240 视口外**（`intersects=0`）。此时 `drawRuntimeVoxelShadowMask` 也是
   `return true` + 0 像素（`if (!rectIntersects(imageRect, viewport)) return true;`），
   同样长得像「掩码解析成功但不压暗」。

## 三、否决：第三条计数对上不总数

差点就此写成「资产缺口」。为此加了第三个桶 `structureShadowEmptyBodies`（`authoredEmptyBody`），
把「整张 sprite 空」与「掩码在但画不出」分开计。跑完发现：

```
structureCand=2 structureEmpty=2 structureNoArt=0
```

**`structureNoArt=0`**。也就是说：被计入 `structureEmpty` 的那 2 个候选，`authoredEmptyBody` 全是 false，
**不是** trace 里那栋 0×0 的 NATBNK。追踪打印的那批绘制调用，与统计记录的候选不是同一批
（`drawRuntimeWorldObjectShadow` 另有直接调用者，各自带自己的 stats）。

于是结论回到原点并更精确了：**M-18 仍是「掩码解析成功、压暗 0 像素」，没有被资产缺口解释掉。**
本轮新增的是两条可执行的线索，不是结论：

- 线索 A：自然地图上确实存在 0×0 的 `NATBNK`（temperate art 缺失），它们会让任何「建筑投影覆盖」
  断言变成不可满足——这是独立的资产缺口，已登记 **M-19**。
- 线索 B：`intersects=0` 时 `drawRuntimeVoxelShadowMask` 返回 true + 0 像素。若被记录的那 2 个候选
  正是离屏或裁剪到零宽，那 M-18 就不是「掩码空」而是「**离屏被记成空掩码**」——已登记 **M-20**，
  下一轮第一件事是在 `recordRuntimeWorldObjectShadowResult` 里打印身份（type/instance/rect/intersects），
  把记录侧的调用集钉死。

## 四、为什么最后没有让 `render` 转绿

中途实现过一版门禁分级（`candidates>0 && drawn==0 && emptyBodies==candidates` 时判资产缺口、
打印计数后放行）。它能立刻把 `render` 变绿，但**逻辑依赖的正是被 `structureNoArt=0` 否掉的前提**：
记录侧没有空体结构，这条分支永远不会命中，绿只是把红色换了个位置。已回退该门禁改动，
只保留计量与第三个计数桶。判据纪律：**门禁转绿必须能说清它验证了什么**；说不清就不要动门禁。

## 五、本轮留下的东西

| 内容 | 落点 |
|---|---|
| `CONCORD_SHADOW_TRACE` 只读追踪（含 12 行预算） | `RuntimeMapRenderer.cpp`（`test:` 提交） |
| `structureShadowEmptyBodies` / `authoredEmptyBody` 第三桶 | 同上，统计行同时打印 `structureNoArt=` |
| M-19 资产缺口：temperate `NATBNK` art 缺失 | fix-plan（简单，资产侧） |
| M-20 离屏帧被记成空掩码 | fix-plan（中等，先补 record 侧身份打印） |

回归：`PASS=8 KNOWN-RED=3 RED-NEW=0`，与开工基线一致，零新回归。

## 六、教训

1. **一句「掩码解析成功但不压暗」至少有三种成因**：整张 sprite 空、帧矩形离屏/裁剪到零宽、
   span 生成空。三者在计数器上原本共用一个桶，谁都能套进去，谁都能被误判。
2. **加了新计数桶之后，第一件事是看它对不对得上总数**。`structureNoArt=0` 这一个数字
   否掉了整段「资产缺口」推理——如果只加了桶不打出来看，这轮就会把一个真缺陷写成 env-gap 关掉。
3. **追踪打印与统计计数可能不是同一批调用**。`drawRuntimeWorldObjectShadow` 有多个直接调用者，
   各自持 stats；计量必须打在 `record*` 里才能和汇总对上。
