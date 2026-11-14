# 第 38 轮（2026-11-14，修复轮）：legacy 存档降版本，要连记录形状一起降

**轮型：修复轮**（主线 `persistence-roundtrip` 第 2 轮；无 brake、无 attempts≥3、上轮非 in_progress、
距 AUDIT-35 仅 3 轮，未触发审计轮）。

主目标 **M-31**。第 37 轮登记时给了两个解释（夹具侧 / 产品侧）并写明「不许猜」，
本轮用一次运行 + 一份遗留产物把方向定死：**夹具侧**。

---

## 一、结论先说

`--skirmish-build-smoke-test` 整条链路**首次 rc=0**（第 37 轮停在 legacy 段）。
`Skirmish build result … objects 14 -> 38 credits=195571`、
`slaveMiner=0->11 cargo3/4/$625/b363->335@96,56/mobile=yes` —— 奴隶矿工在真遭遇战里挖、装、卸、
进账全通。S-17 随之落地：regress 从 11 条变 **12 条**，`PASS=11 KNOWN-RED=1 RED-NEW=0`。

## 二、根因：不是载入太严，是夹具在撒谎

`parseRuntimeSavedBehaviorRecord`（`RuntimeSessionWorld.cpp:9016`）的字段数闸门：

```
tokens.size() < 7  → 拒绝
saveVersion >= 9   → 必须恰好 12 个字段
                      （14 / 16 / 17 只在 saveVersion >= 14 时接受）
```

而 legacy 段的做法是把 v14 的**文本**改成 `Version=10` 就当地 v10 存档用。上一轮留下的
`ConcordRTS-GameData/runtime_skirmish_legacy_transient_save_smoke.ini`（17:13 那次失败的产物）
直接给出证据：

```
[Behaviors]
Count=4
0=38|move|-1|87|61|0|71|no|-1|-1|-1|26721|no|no|88|60     ← 16 字段
1=39|move|-1|102|59|0|30|no|-1|-1|-1|7710|no|no|101|59    ← 16 字段
2=17|move|-1|98|55|0|0|no|-1|-1|16|0                      ← 12 字段（合法）
3=23|move|-1|99|128|0|16|no|-1|-1|-1|9751|no|no|106|122   ← 16 字段
```

三条 16 字段的记录在 `Version=10` 下必然落到 `tokens.size()!=12`，
于是 `invalid behavior record`。**换句话说：它们是「自称 v10 的 v14 记录」，
载入拒绝是对的。**（第 14/15 字段是 `moveSegmentFrom`，16 字段形态还隐含清场宿主。）

## 三、改法：降版本时把记录也截成旧形状

`RuntimeShell.cpp` 的冒烟夹具内新增 `truncateSaveSectionFields(text, section, keepFields)`：
在指定段内逐行取 `key=value`（只认数字 key，`Schema`/`Count` 不动），按 `|` 切分，
超过 `keepFields` 的截到前 N 个字段再写回。legacy 段在改完版本号后调用它把
`[Behaviors]` 截到 12 字段。

- 只动夹具，**不碰 `parseRuntimeSavedBehaviorRecord`**：产品侧的行为没变，
  它照样拒绝「版本与记录形状不符」的存档。
- 截掉的 `forceFire/attackGround`（这份存档里都是 `no`）、`moveSegmentFrom`、清场宿主，
  在 v10 语义里本来就不存在，截断等于把记录还原成它那个版本该有的样子。
- 为什么不能拆出 `RuntimeShell.cpp`：65 行纯字符串手术，唯一的调用点在
  `runRuntimeSkirmishBuildSmokeTest` 内部，依赖同函数里的 `removeSaveSection` 与存档文本。
  拆成独立 TU 需要先抽出「按段改写 INI 文本」这一层（目前全仓没有），
  收益不抵本轮成本；记在遗留债里。

## 四、S-17 落地：regress 第 12 条

`regress.sh` 新增 `skirmishbuild`（`--skirmish-build-smoke-test`，5 秒）。
它才是「遭遇战能不能开起来」的门——原来的 `skirmish` 只验 UI 菜单。
`known-red.tsv` 未动（这一条首次接入即真绿，**没有**登记成 known-red）。

回归 `20261114-214655`：12 条 `PASS=11 KNOWN-RED=1 RED-NEW=0`，
唯一红仍是 `command` 的 `slave miner: workers did not dig…`，前缀未变。

## 五、一条值得下一轮追的线索（本轮不动）

`command` 那条 known-red 说奴隶矿工「挖得动、装得满、交不进去」（`cargo=4 credits=0`），
但同一份二进制在**真遭遇战**里打出 `slaveMiner=0->11/cargo3/4/$625` —— 交付与进账都真的发生了。
两个读数互相矛盾，说明那条 known-red 大概率也是夹具侧（`runRuntimeSlaveMinerSmokeProbe`
自己搭的场景与真实开局不同，例如没有炼油厂存储容量/没有 dock 绑定）。
**C-02i 曾以「不产生收入」为由判 blocked**，这条线索直接动摇那个判定。
本轮没时间做，登记为下一轮起手（不新开条目，挂在 `command` 已知红那一条上改证据）。

## 六、本轮没做什么 / 遗留什么债 / 放弃了什么

- **没做**：没有把 `runRuntimeSlaveMinerSmokeProbe` 与真开局对齐（见 §五）。
  U-19/20/21/23 四条 UI 取证虽已解锁，本轮一条都没做（时间被会话中断吃掉约 3.5 小时）。
- **遗留债**：①「按段改写 INI 文本」的工具函数仍是冒烟内私有，第二次要用时会复制；
  ②`invalid behavior record` 的文案仍分不清「版本不符」与「记录损坏」——本轮证明后者才是常态，
  但按纪律不在夹具轮顺手改产品文案；③`skirmishbuild` 未加失败前缀门禁（它现在不红，不需要）。
- **放弃了**：没去构造一份「真·v10 全量夹具」（从 v10 时代的字段布局重建整份存档）。
  截断法用 65 行拿到同等的判定力：它验证的仍是「缺段 → 回基线」这条产品性质，
  而且顺带证明了记录形状闸门是有效的。真夹具的额外价值只在「跨大版本迁移」，
  那件事已经有 psychic 段（v14→v10，`RuntimeShell.cpp:57133`）覆盖。
