# EVO-17 建造完成后侧边栏页签与按钮闪烁

## 需求（对齐原版红警2）

建造完成后——
1. 对应侧边栏页签（建筑/防御）闪烁，提示有东西造好了可放置；
2. 打开该页签后，对应的建造栏位（按钮）本身闪烁。

## 实现

数据侧零改动：建造完成已是 `RuntimeProductionLaneState.ready` 置位
（Structures/Armory lane，requiresPlacement）。改动全在
`src/runtime/host/RuntimeShell.cpp`：

- **页签闪烁**：新增 `runtimeBuildReadySidebarTabShouldFlash(state, kind)`
  （`runtimeDefenseSidebarTabShouldFlash` 旁）——遍历 Structures/Armory
  lane 的 `ready`，经 `runtimeProductionCatalogLookup` 映射到
  Building/Defense 页签；页签已打开时不闪（让位给按钮闪烁）。
  相位复用 `runtimeSuperWeaponFlashHighlightPhase`（tick / ¼ 秒取模），
  与既有超武 Defense 页签闪烁 OR 组合进 tab 循环的 `highlighted`。
- **按钮红白交替**：`placementReady` 的边框色由静态青
  (120,242,220) 改为 `runtimeUiReadyBlinkOn`（500ms 墙钟相位）驱动的
  红(240,24,16) ↔ 白交替；保留原「就绪」文字闪烁。
- 重绘泵 `advanceRuntimeUiPresentation` 已在 ready 存在时每 500ms
  强制 repaint（暂停下也工作），无需改动。

## 相位语义（与既有先例一致）

- 页签用 sim tick 相位：游戏暂停时冻结；
- 按钮用墙钟相位：暂停时仍交替。

## 验证

- `ninja concord_runtime` 通过。
- 回归 `PASS=5 KNOWN-RED=6 RED-NEW=0`（含徽章像素级对比 smoke）。
- 人眼验收剧本：造一个建筑等完成 → 建筑/防御页签开始闪烁；点开页签 →
  对应按钮红白交替 +「就绪」闪字；放置后全部停止。
