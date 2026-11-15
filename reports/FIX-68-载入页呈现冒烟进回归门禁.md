# 第 68 轮（修复轮）：载入页呈现冒烟进回归门禁（S-39）

> 日期：2026-11-16 06:00~07:00　｜　轮型：**修复轮**
> 主目标：S-39 —— 第 67 轮打通的取证通道接进 regress，并把它 23MB 的产物挪出源码树

## 一、轮型判定（零、T+0~3min）

| 判据 | 实测 | 结论 |
|---|---|---|
| 主线账（>4 轮要整体收口） | M-03 在办 2 轮 / 2 子项，其余主线 done 或 blocked | 不触发 |
| 诊断轮（brake：上轮 in_progress / 连续两轮无进展） | R67 已收口，regress 基线 `14/2/0` | 不触发 |
| 清偿轮（腐烂预算 / attempts≥3 在办 / test ≥ 2×fix） | 近 5 轮源码提交 fix:2 / test:1 / refactor:2 / chore:1；在办条目无 attempts≥3（M-25=3 已 blocked 出队） | 不触发 |
| 审计轮（距上次满 5 轮） | AUDIT-66 → 只隔 2 轮 | 不触发 |
| 换赛道轮（深水区连续 2 轮无产品行为变化） | M-03 R63 一轮后已换过赛道（R65） | 不触发 |
| **→ 修复轮** | | |

## 二、本轮改了什么

### 2.1 主目标 S-39：门禁 + 产物落点

两件事，一件是世界问题（不在门禁里），一件是同一段代码的副作用（往源码树堆 23MB）。

**门禁侧**：`regress.sh` 新增第 17 条 `loadingpages`：

```bash
run_case loadingpages 300 "CONCORD_LOADING_PRESENTATION_ONLY=1 CONCORD_SMOKE_ARTIFACT_DIR=$ART/loadingpages" "--loading-smoke-test"
```

跑的是**生产窗口**：`runRuntimeCountryLoadingPresentationSmoke` 真建 `RuntimeLoadingWindowState`，
`SendMessageW(WM_PRINTCLIENT)` 抓 11 页 × 800x600/640x480，并在每页断言
「槽位里画出了东西」（非纯黑 ≥50% / 颜色数 ≥24，R67 的 `6cab55d` 加的判据）。实测 **0.56 秒**。

**落点侧**（`f0c8f06`）：那两个冒烟把 12 张 `loading_*.bmp` + 2 张 `issue21_loading_first_frame_*.bmp`
硬编码写到相对路径 `build/`。regress 的 `cd` 是数据根，所以接进门禁后它们会落到
`ConcordRTS-GameData/build/` —— 23MB 一次性判读用的图，每轮一份，且完全绕开 R50 的留存策略。

改法：新增

```cpp
inline std::string runtimeSmokeArtifactPath(const std::string& fileName) {
    const char* directory = std::getenv("CONCORD_SMOKE_ARTIFACT_DIR");
    if (directory == nullptr || *directory == '\0')
        return std::string("build/") + fileName;      // 默认行为不变
    std::error_code ignored;
    std::filesystem::create_directories(directory, ignored);
    return (std::filesystem::path(directory) / fileName).string();
}
```

三处写盘点改用它（首帧两处 + 每国页一处 + Libya 640 一处）。**没有参数化文件名**——
文件名本身是判读时的语义（`loading_yuri.bmp` 一眼知道该看哪页），只把**目录**外置。

### 2.2 验证

| 项 | 改前 | 改后 |
|---|---|---|
| regress 条数 | 16 | **17**（`loadingpages` PASS） |
| 产物落点 | `ConcordRTS/build/`（手工跑时）/ `GameData/build/`（进 regress 后） | 本轮 `progress/regress/<stamp>/artifacts/loadingpages/`（14 个文件 51MB，随本轮产物按策略轮转） |
| 源码树残留 | `ConcordRTS/build/` 31MB / 14 张 | **6.4MB**（`rm` 掉 14 张 25MB，剩下的 `issue22_15_vehicle_terrain_slope/` 是另一条冒烟的，见 §五） |
| 单跑耗时 | — | 0.56s（`/usr/bin/time` 手测，含写 51MB） |

命令与输出：

```
$ bash ra2mac_docs/scripts/regress.sh --only loadingpages
  loadingpages PASS  0s  [country loading] Americans: original art, labels, flag, ...
$ ls ra2mac_docs/progress/regress/20261116-060610/artifacts/loadingpages | wc -l
14
```

## 三、这条门禁到底兜住了什么

**兜住 R67 的产品修复**（`d60b1c7`：缩略图铺满 216x166 槽位）。改前那条产品缺陷的表现是
「亮背景页上两条 18px 黑带」，而旧判据只有「标记两帧差分」——全黑槽位也能过。现在：

- 槽位内容门禁（非纯黑 ≥50% / 颜色 ≥24）在 regress 里每轮跑，槽位再退回等比缩放就会红；
- 取证通道**进了清单**，下一条要用它的条目（U-19 HUD 对账的第一步就是「抓到真实帧」）不必再
  重新发明一次「拿不到真实窗口的载入帧」。

这是本项目的**第四次**同型：S-08（读数一直在 `latest.txt` 里）、M-13（通道一直在）、
S-38（脚本手上已有全部数值）、S-39（取证入口一直在）。共同形态是
**「事实的生产者存在，但入口不在清单/门禁里，于是每轮重新论证一次它不存在」**。
下轮起遇到「拿不到 X」，先搜一遍 `CONCORD_*` 开关与冒烟入口，再谈不可得。

## 四、质量四数（五、1）

| 指标 | 本轮 | 变化 |
|---|---|---|
| ① 净增行数（源码，`git diff --shortstat 6cab55d..HEAD`） | **+19 / −5**（1 个文件） | 全部在 diagnostics |
| ② 最大文件行数 | `RuntimeShell.cpp` **90,633** / `RuntimeMapRenderer.cpp` 42,542 / `RuntimeSessionWorld.cpp` 31,056 | 三者**零变化**（helper 落在 `.inl` 里，没进 90k 那个文件） |
| ③ 断言 vs 产品代码 | 新增断言 **0**，新增门禁 1 条（`run_case`）；产品行为改动 **0 行** | 本轮不改行为，只加门禁 + 改产物落点 |
| ④ TODO/FIXME | **0**（`RuntimeShell.cpp`） | 无增减 |

单次改动没有让任何 >8,000 行的文件净增 >50 行——`RuntimeShell.cpp` 一行没动。

## 五、本轮没做什么 / 遗留什么债 / 放弃了什么

**没做**
- U-19（HUD 逐项对账）：它的前置（真实开局帧）本轮只打通了「载入页」这一段，**不是 HUD 帧**。
  `loadingpages` 给的是载入页，HUD 要的是世界帧 + 侧栏，两者不同源。下一轮要先确认
  `--skirmish-build-smoke-test`（R38 起能到 `objects=14`）能不能出帧。
- M-03（空转重绘，第 3 轮机会）：计划里写明「只许先补画面签名 vs 实际像素逐帧对账」，
  这是一次中等量级的计量改动，本轮剩余时间不够把它做到「读数可信」，**没有开工比开一半好**。

**遗留债**
- **S-40（本轮新登记）**：其余冒烟仍在往树里写产物。实测 `ConcordRTS-GameData/build/` 里有
  `result_mission_victory.bmp` / `result_mission_defeat.bmp` / `result_players_allied.bmp`，
  `ConcordRTS/build/issue22_15_vehicle_terrain_slope/` 也在。它们与 S-39 同型，
  但**不在本轮主目标里**——按 §四.1「一个主目标」，只做了载入那一段，剩下的登记成条目。
- `regress.sh` 的 `pick_evidence` 在第 17 条上抓到的是第一行 per-country 输出而不是末行汇总
  （三态判定不受影响，红绿来自退出码；只是证据列可读性差）。**没改**：本机 `sed`/`grep` 是 shim，
  改取证据逻辑要连带重验 17 条的证据列，收益不抵风险。

**放弃**
- 不把 `runtimeSmokeArtifactPath` 做成通用工具（`RuntimeCountryLoadingSmoke.inl` 之外还有两处
  写盘：frame-stability 用注入的 `directory`、result 冒烟直接写 `build/`）。抽公共头会牵连
  frame-stability 的注入契约，S-40 一并做更划算。
- 不顺手把 `GameData/build/` 里的 result 产物删掉：它们不是本轮 `rm` 的对象（没有刷新机制，
  下一轮还会重生成），删了只是让账更难看。

## 六、清单体检（一、7）

| 项 | 结果 |
|---|---|
| 行数 | fix-plan **234 → 236** 行 / 400 |
| 条目数 | queue **41 → 41**（S-39 → done；S-40 登记，等价替换）；plan 表格行数不变 |
| queue 体积 | 68KB / 120KB |
| rules | 5 类 ✓ |
| `ledger-check.sh` | **十三项全绿**（开轮与收口各跑一次） |
| 悬空引用 | 0（`refs-head` + `refs-in-queue`） |
| 状态与报告矛盾 | 0：S-39 的 `verify` 逐条对上（17 条 / PASS / 落点） |
| 重复条目 | 0 |
| attempts 与收口记录 | S-39 attempts=0 → done（一次做成）；M-03 仍 2；M-25 3 但已 blocked 出队 |

## 七、两级计数

- 条目级：M-03 **attempts=2**（下一次若仍无产品行为变化 → `§六.3` 整体收口）；C-02i=2（blocked）；M-25=3（blocked，已收口）。
- 主线级：`取证门禁` **1/4 子项、1 轮 → done**（S-39 已交付）；`M-03 空转重绘` 2/4 子项、2 轮（在办，剩 2 轮）；
  `清单治理` / `交付` / `UI 对账` / `unit-behavior` 等均已满额或 done。

## 八、dist（十二）

见 `dist/BUILD-STAMP.txt`，收口时由 `pack-dist.sh` 第 ⑫ 步自己写。本轮有 C++ 改动（诊断侧），
两架构都要重编，arm64 与 x86_64 各一次 + lipo + adhoc 重签。
