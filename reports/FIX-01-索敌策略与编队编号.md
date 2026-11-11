# FIX-01 被动索敌策略与编队编号显示

> 日期：2026-11-12
> 计划条目：fix-plan.md 的 S-01 / S-02 / S-03
> 源码提交：`a2b2c78`（索敌 + 反击）、`8e6b6e5`（编队编号）
> 承接：上一轮被截断的 WIP（`progress/.active` 记 `auto-acquire-policy+team-number`）

本轮把上一轮遗留的三处未提交改动定性、补测、收口。三处都属于「玩家不下命令时，游戏自己决定做什么」，
也是本项目判定纪律里最难靠单测证明的一类——断言必须落到真实模拟推进与真实光栅结果上。

---

## S-01 被动索敌会锁定建筑

**现象**：空闲（Guard）或攻击移动中的单位，在没有任何玩家命令的情况下，会越过前线去追敌方建筑，
包括武装防御塔。零售语义是被动索敌只挑可移动目标，建筑只能通过玩家命令或受伤反击进入攻击列表。

**根因**：`advanceRuntimeGuardBehavior`（`RuntimeSessionWorld.cpp`）按空间桶遍历候选目标，
命中判定只有 `instanceId` 自比、`runtimePlayerGuardDestinationAllowsTarget`、敌对性、可见性等条件，
**没有按 `WorldObjectKind` 过滤建筑**。建筑和可移动单位同桶，于是建筑作为普通候选被选中，
单位沿着寻路走过去打它——看起来就是「AI 自己越线拆塔」。

**改法**：在候选过滤里加一条 `target->kind == WorldObjectKind::Structure` 跳过。
之所以是「跳过」而不是「只在特定模式跳过」，是因为零售里连武装防御塔也不该被被动索敌锁定：
防御塔打你是它主动，你要打它必须自己点，或者被它打伤后走反击（即 S-02 的通道）。

**收益**：直接改变对战手感。此前的表现是「开局摆好防线，坦克自己跑光」，属于玩家第一分钟就能察觉的错误。

**成本**：1 行判定 + 注释，`RuntimeSessionWorld.cpp` 内自足。

---

## S-02 单位受伤不还手

**现象**：坦克被光棱塔/电场命中后只在原地挨打，必须玩家下命令才开火。

**根因**：`applyRuntimeProjectileImpact`（`RuntimeSessionCombat.cpp`）在伤害结算后只调
`beginRuntimePanic`（平民逃跑），返回值还被 `(void)` 丢弃，完全没有 `CanRetaliate` 这条分支。
零售里 CanRetaliate 是「受伤的单位对攻击者开火」，与被动索敌是两条独立通道——
这也是 S-01 敢把建筑整体挡在被动索敌之外的底气：建筑打你，你仍然会还手。

**改法**：新增 `runtimeBeginDamageRetaliation`，在 panic 不成立时调用。准入条件逐条对齐零售语义：

| 条件 | 理由 |
|---|---|
| 受害者存活、凶手存活 | 死单位不还手、不打尸体 |
| 受害者是步兵或车辆 | 建筑/装饰物不走这条路径 |
| 非空中、非战斗碉堡内、非被奴役的奴隶矿工、非部署/展开中 | 这些状态下单位不能自主开火 |
| 己方不是 Neutral、AI 未被暂停、有可用电力 | 与被动索敌共用同一套「能不能自动行动」的闸 |
| 当前无行为（或允许行进中索敌） | 有命令在身的单位不抢命令，这是「空闲才自动」的边界 |
| `canRetaliate` 规则位为真、武器有伤害与射程 | 数据驱动，不硬编码 |
| 敌方敌对、对己方可见、未被间谍伪装 | 与索敌同一套可见性判定 |
| 距离 ≤ 有效射程 | 打不到就不入队，避免原地卡住 |

入队时 `autoAcquired=true`（便于断言区分「玩家命令」与「自动」），部署态单位回落 `DeployedFire`。

**收益**：战场反馈最直观的一条。此前「坦克被电场打」是纯挨打，玩家会认为单位坏了。

**成本**：一个新函数 + 伤害点 2 行接线，`RuntimeSessionCombat.cpp` 内自足。

---

## S-03 选中单位不显示编队编号

**现象**：U-07 让 Ctrl+数字编队真正生效后，画面上仍看不出选中单位属于第几队。

**根因**：只有编队写入（`playerLocalCommands.teams`），**没有绘制路径**；
`RuntimeWindowState` 也没有对应计数器，因此连「这一帧画了几个编号」都无从断言。

**改法**：
- `runtimeTeamGroupIndexForObject`：按 `teams` 顺序返回最小的已分配队号（一个单位可属多队，取最小保证确定性）。
- `drawRuntimeTeamNumberBadge`：在选中框左上角画 `1..9`/`0`，1px 暗色投影 + 浅色字，
  深色地表与浅色地表都读得出来；`lastTeamNumberBadges` 每帧重置并自增，供断言使用。
- 挂在 `drawRuntimeInteractionOverlay` 的选中分支上，与被选中框同源，不额外算一遍选择。

**收益**：编队可用性的最后一公里。没有编号时玩家只能靠记忆确认编队内容。

**成本**：`RuntimeShell.cpp` 内两个函数 + 一个计数器，约 50 行。

---

## 断言（test 部分）

两个场景组挂在既有的 `--command-smoke-test` 上（`RuntimeShell.cpp` 的 `runRuntimeCommandSmokeTest`），
既有环境变量单跑入口，也在常规路径上无条件执行：

- `CONCORD_COMMAND_SMOKE_GUARD_POLICY_ONLY=1` → 只跑索敌策略
- `CONCORD_COMMAND_SMOKE_TEAM_NUMBER_ONLY=1` → 只跑编队编号
- 不带变量 → 两者在 start-up 计时前依次执行，失败分别打印
  `command smoke failed: guard acquisition policy:` / `team number badge:`

**`RuntimeGuardAcquisitionPolicySmoke.inl`（4 个场景）**
1. 空闲坦克主动索敌敌方坦克 → 必须有 `autoAcquired` 的 Attack 行为，且目标正确。
2. 空闲坦克面对敌方发电厂 → 必须**不**产生任何行为（S-01 的反向断言）。
3. 磁暴线圈主动锁坦克、坦克在受伤前不锁线圈；线圈命中后坦克必须还手且目标是线圈（S-02 主断言）。
4. 无武器建筑（兵工厂）永不自动攻击 → 建筑与对方单位都不得入队。

**第 5 个场景从「5」降到「4」的原因（实测推翻，不是偷懒）**：
原本还写了「被敌方坦克打伤的空闲坦克会还手」，跑出来是
`retaliation scenario produced no damage: health 300->300 projectilesSeen=0
enemyBehaviorState=6 status=guard acquired #4 -> #5`。
两件事同时成立：① 该夹具 15 秒内一个弹丸都没产生，压根没有伤害可以触发还手；
② 敌方坦克进射程后被动索敌**先**给了受害者一条 `autoAcquired` 攻击行为，
于是「伤害触发的还手」和「被动索敌」在这个夹具里无法区分。
真正**只能**靠伤害触发的场景是「建筑打你」——建筑被 S-01 挡在被动索敌之外，
已由第 3 个场景（磁暴线圈）覆盖。所以删掉这条自相矛盾的用例，不保留一条靠运气过的断言。

**`RuntimeTeamNumberBadgeSmoke.inl`（3 个场景）**
1. 选中属于第 1 队的单位 → `lastTeamNumberBadges == 1`。
2. 不选中任何单位 → 计数为 0（不误画）。
3. 单位同时在 1 队与 3 队 → 光栅结果必须等于 1 队那张图（最小队号生效）。

两条断言都落在「模拟真推进」与「overlay 真光栅」上，不是绑定层或单测层面的绿灯。

**注意（本轮踩到的坑）**：上一轮其实已经把这套接线写进 `RuntimeShell.cpp` 了，只是 .inl 文件本身
是 untracked，`git status` 里看着像「只写了一半」。本轮一开始用 `bash grep` 查调用点返回空，
误判为未接线，重复接了一遍导致 redefinition 编译失败，`git checkout` 撤回后恢复。
`bash grep`/`sed` 在本机是 shim，多模式静默返回空——查符号一律用 Grep 工具，已再次记入 MEMORY。

---

## 判定纪律对照

- **输入/交互类必须在消息循环断言**：本轮不涉及按键路径，但 `--policy-smoke-test` 走的是真实
  `advanceRuntimeGuardBehavior` / `advanceRuntimeCombatBursts` / `drawRuntimeInteractionOverlay`，
  不是绕过链路的桩。
- **呈现层不能缓存 CGImage**：编队编号画在每帧重建的 DIB 上，未引入任何帧缓存。
- **全屏语义是视口变大**：本轮不涉及；编号位置用 `selectionBounds`（表面坐标），
  与 U-14 的「客户区交给游戏、1:1 绘制」一致，全屏下不随缩放漂移。

## 未做 / 留给后续

- 编队编号目前不画在「不在屏内的编队成员」上（零售也不画），未做额外处理。
- 回归条数仍是 11 条（`command` 这条承载新断言），没有新增 id，`known-red.tsv` 无需改动。
  代价是：`command` 本来就是 KNOWN-RED（两栖卸载），若新断言将来变红，
  会被「已登记」吞掉，只能从日志文本区分。下轮可考虑把索敌/编队拆成独立 id。
