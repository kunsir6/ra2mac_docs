# EVO-16 遭遇战 AI 默认开启且勾选持久化

## 症状

用户报告：遭遇战敌军完全不动、不建造、被打也不还手。

## 根因

AI 逻辑本身是完整接线的（`advanceRuntimeComputerAi` 每 tick → MCV 部署 / 采矿 /
生产 / 防御 / 战术进攻 / 攻击波），问题在总开关：

- `RuntimeConfig.h` 里 `computerAiEnabled` 默认 **false**；
- 遭遇战菜单的「AI」勾选从不写回 `runtime_config.ini`
  （`preferenceSections` 的 `[Skirmish]` 段只有 GameSpeed）；
- 开关关闭时不止 AI 不主动行动：`runtimeComputerAiPausedForOwner` 把电脑
  slot 从被动 guard / `runtimeCombatCanAct` / 行为入队三处全部排除——
  「不动、不建造、不还手」三条症状一次解释。

战役路径一直强制 `computerAiEnabled=true`（CampaignProgress 默认 yes），
只有遭遇战受这个默认关闭且不持久化的开关支配。所有 AI 冒烟都自己开开关，
所以默认关的问题在 CI 里不可见。

## 修复

1. `RuntimeConfig.h`：默认值改 `true`（对齐原版遭遇战行为）。
2. `RuntimeSettings.cpp`：新增 `saveRuntimeSkirmishAiPreference`
   （写 `[Skirmish] ComputerAI`），仿 Crates/NoCooldown 模式。
3. `RuntimeSkirmishController.h`：services 接口加 `saveAiPreference`；
   `RuntimeSkirmishMenu.cpp` 实现转发；`completeMenu` 在接受开局且非联机时
   与 NoCooldown 同位置保存。

## 验证

- `ninja concord_runtime` 通过。
- 11 条回归 `PASS=5 KNOWN-RED=6 RED-NEW=0`，与基线一致。
- `--computer-ai-smoke-test`：economy/base/army/defense 全 yes，
  `waves=6 orders=50`（AI 确实发动攻击波）。
- `concord_skirmish_controller_contract`：77 检查 0 失败。
- 本机 `runtime_config.ini` 无 `ComputerAI` 键，新默认直接生效。

## 遗留（另立案）

AI 冒烟自身断言失败且为**预先存在**（HEAD 复现逐字节一致）：

- `attack=no`：`attackWaves=6` 但 `lastTargetObjectId` 未记录；
- `triggerTeamIsolation=no`：遭遇战仍创建了 trigger team
  （smoke 预期 legacy bootstrap 关闭后为 0）。

这两条属于 AI 侧遗留，待分诊。
