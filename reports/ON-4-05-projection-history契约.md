# ON-4-05 · projection history 契约：rubble 与 selling 的期望不一致

> 执行时间：2026-11-11 12:55–13:15（arm64）
> 结论：**断言写错了，不是渲染错了**。按状态分开后转绿，并暴露下一条（ON-4-06）

---

## 一、原始失败

```
Interaction smoke test failed: projection history contract:
  actual rubble/selling structure did not participate in scene-Z replay
```

前面三条像素契约（Selected path batch / Selected path raster / Selection frame raster）全绿，
卡在第四条。

## 二、先拿数字，不猜缓存

按任务要求加了临时观测，把「解析是否成功 / 有哪些 instanceId」带进失败消息：

```
resolved=1 rubble=1 id=810502 type=GAPOWR mission=Destroyed spans=1 entries=[810002:139 ]
```

三个事实：

1. 解析**成功**（`resolved=1`）——不是缓存失效、不是资源缺失；
2. spans 里只有 `810002:139`，**不含**要找的 `810502`；
3. 只在 `rubble=1` 那次失败（循环里 `for (bool rubble : {false, true})`，`rubble=false` 已通过）。

## 三、根因：replay 显式排除地面残骸

`RuntimeStructureSpriteGeometry.inl:359-365` 的参与者筛选：

```cpp
for (const auto& object : world.getObjects()) {
    if (object.kind != WorldObjectKind::Structure || !runtimeWorldObjectBodyShouldRender(object)
        || runtimeObjectIsGroundRubble(object, context)     // ← 就是这一条
        || runtimeSpecialObjectIsHidden(context, object)
        || ...) continue;
```

`runtimeObjectIsGroundRubble` 为真的对象**根本不进** depth replay 的候选表。
这是**正确行为**：地面残骸没有立体遮挡体，让它参与 replay 会凭空产生遮挡，
把本该被看见的像素挡掉。

所以这条断言的问题在于：它用一句话同时覆盖了两种状态，而这两种状态的正确期望**相反**。

| 状态 | 含义 | replay 里的正确行为 |
|---|---|---|
| `rubble=false`（Mission=Sold） | 建筑还立着，只是被卖掉了 | **必须参与**，否则选中它算不到遮挡 |
| `rubble=true`（Mission=Destroyed） | 已塌成地面残骸 | **必须不参与**（第 361 行的筛选） |

## 四、修法

按状态分开断言，并在失败消息里保留 spans 明细：

```cpp
if (!spansResolved) return fail("... did not resolve");
if (rubble) {
    if (actualSpans.contains(base.instanceId))
        return fail("ground rubble must be excluded from scene-Z replay");
} else if (!actualSpans.contains(base.instanceId)) {
    // 带 spans 明细的失败消息，下次不用再加诊断
}
```

**为什么不是改 `runtimeObjectIsGroundRubble` 的筛选**：那会让残骸挡住它后面的东西，
是渲染缺陷而不是修测试。

## 五、结果

```
Projection history contract: complete geometry/order and map+overlay pixels match;
  dead pose cache hit, identity/revival/order and all live signature fields verified;
  all original dead-structure fields and 14 same-tick rubble/selling paint and
  visible-hit cases verified.
Idle overlay contract: 10 RGB-identical cases; ... world hashes unchanged.
```

两条契约同时转绿，14 个同 tick 的 rubble/selling 案例全过。
改动仅 1 文件 **+29/−3**（诊断打印已全部移除），源码提交 `ba49ef2`。

## 六、新暴露的下一条（另立 ON-4-06）

```
Interaction smoke test failed: gameplay tooltip toggle did not control hovered-object help.
  point=yes hit=yes enabled=yes disabled=no menu=no.
```

`enabled=yes` 但 `disabled=no`：开关打开时行为对，**关掉开关后仍然弹出了帮助**；
`menu=no` 说明与菜单路径无关。所以查的是"关闭开关后 hover 帮助的抑制条件"，
不是命中判定。已按任务要求另立 `ON-4-06`，不把 EXIT=0 绑回本条。

`--interaction-smoke-test` 整体仍是 `EXIT=1`——这是逐条推进的正常形态，
每转绿一条就往前走一条，直到它真的 0。
