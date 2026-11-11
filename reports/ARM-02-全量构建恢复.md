# ARM-02 · 全量构建恢复

> 执行时间：2026-11-11
> 起点：`cmake --build build-product-arm` 在 `[182/1823]` 失败，历史上从未绿过
> 终点：`-k 0` 跑完全部目标零 FAILED，再构建 `no work to do`
> 提交：`9106a89`（构建恢复）、`4eb9a32`（顺带修的两处真缺陷）

## 一、为什么这件事值得做

在 ARM-02 之前，"全量构建"不是一个可用信号：它必定失败，于是没人跑，于是没人知道
除了已知那一处之外还坏着多少。判据长期只有 `--target concord_runtime`，等于整个
测试目标集合（占 build.ninja 2878 条 build 语句的绝大多数）无人看管。

修完之后它可以重新作为验收项。这也正是它排在性价比中段而不是末尾的原因。

## 二、五处断裂，逐类定因

用 `-- -k 0` 一次收全（默认在第一个 FAILED 就停，这正是此前只看到一处的原因）。

### ① `concord_mod_history_noop_smoke`：从首次导入起就不可能编译

测试文件按「production stage 是宿主泛化的 .inl」来写：自造一个最小
`RuntimeWindowState`（world / rules / config.fixedTickHz / specialMechanisms / tick），
然后 include `simulation/mod_extensions/RuntimeModExtensionsRuntime.inl` 并调用
`advanceRuntimeModExtensions(optimized)`。

事实是：

| 事实 | 证据 |
|---|---|
| 那个 `.inl` **自 `c8c4d75 Initial source upload` 起就是 0 字节** | `git show <rev>:<path> \| wc -c` |
| 真实实现是具体重载，绑死会话类型 | `RuntimeSessionWorld.cpp:30394` `bool advanceRuntimeModExtensions(RuntimeGameSessionState&)` |
| 唯一声明 | `RuntimeProductionOperations.h:9631`，参数 `RuntimeGameSessionState&` |

非模板函数 + 自造宿主 ⇒ 永远匹配不上。这不是"签名写错"，是**契约本身已经不存在**。

**处置**：不删测试，把能救的一半拆出来。

- 新增 `tests/infrastructure/RuntimeModExtensionsNoopStageSmoke.cpp`，目标
  `concord_mod_noop_stage_smoke`，ctest `runtime_mod_noop_stage_test`。它只依赖生产头
  `RuntimeModExtensions.h` 里的 `RuntimeInactiveModExtensionNoopStage`，跑的是
  **惰性历史跳过证明 + 固定 256 项完整类型缓存**：大小写变体、空类型、非 ASCII、
  512 字节超长类型后缀碰撞、零强度护盾、innate、未注册护盾、存活零血、
  已初始化、默认在线护盾迁移、死亡/载入效应清理、600 次缓存溢出、嵌套 reference 作用域。
  **622 条断言，全过。**
- 需要真实会话的那一半（1 万个惰性残骸对象 × optimized/reference 两条路由 ×
  world hash / mod codec hash / 查询计数器）无法在小宿主上成立，原文件保留为
  **ARM-03 的规格书**，文件头加了显式横幅说明"不参与任何目标、不要在 ARM-03 之前加回去"。

### ② `_dupenv_s`：MSVC 专有（3 个多人 smoke）

`RuntimePlanningFactoryKeyBridgeSmoke` / `RuntimeReferenceCommunicationBridgeSmoke` /
`RuntimeChatTextBridgeSmoke` 各一处，用于读 `CONCORD_*_BRIDGE_OUTPUT` 证据目录。

补 POSIX 分支，语义对齐 MSVC 版本：变量设了给自有副本、没设给 `nullptr`、
两种情况都返回 0（`ENOMEM` 走 12）。**Windows 分支逐字节未动**，只在
`#if defined(_WIN32)` 外新增 `#else`。

### ③ `concord_menu_resource_watch_contract`：在 macOS 从未编出来过

三连问题：

1. `windows.h` 找不到 —— 该契约在 `tests/infrastructure/menu_resource_watch/CMakeLists.txt`
   这个 `add_subdirectory` 里，没有 compat 的 include 路径。
2. 补了头之后链接缺 `FindFirstChangeNotificationW` / `FindCloseChangeNotification` /
   `WaitForSingleObject` —— 缺 compat 实现。
3. 再补实现之后 `FSEvents/FSEvents.h` 找不到 —— 缺嵌套框架搜索路径。

根因不是"漏了三处"，是**配置顺序**：`DevelopmentTargets.cmake` 在
`CompilerAndPlatform.cmake` 之前执行，`add_subdirectory` 发生在那时，
`concord_apple_add_win32_compat_sources()` 与 `CONCORD_APPLE_FSEVENTS_FRAMEWORK_DIR`
都还不存在。项目里已有两处同样的踩坑记录（`MainSystemFontContracts.cmake` 用
`cmake_language(DEFER)` 绕，`concord_multiplayer_two_process_smoke` 挪到平台文件里挂）。

**处置**：这个嵌套目录写成自包含——`xcrun --show-sdk-path` 取 SDK、目标级
`-F<CoreServices>/Frameworks`、`-framework CoreServices/CoreFoundation`，不依赖 include 顺序。
（`set_source_files_properties` 是目录作用域，父目录设了不管用，所以 `-F` 只能按目标给。）

### ④ 同一个契约里，平台条件与生产代码不一致

生产用 `#if defined(_WIN32) || defined(__APPLE__)` 选变更通知后端；契约只写了
`#ifdef _WIN32`。于是 macOS 落进"没有后端"的 `#else`，断言
`!watch.unchanged(native)`（"没有通知后端所以必须重载"），与 compat 的 FSEvents
实现正好相反。

对齐之后，macOS 第一次真正跑起 FSEvents 那条路：**171 条断言**（此前只有 9 条）。

### ⑤ `concord_window_parent_win32_contract`：链接缺 `_CreateWindowExW`

目标定义在 `SkirmishControllerContracts.cmake`（同属 DevelopmentTargets 阶段），
Windows 靠真 SDK，macOS 要靠 compat。按既有先例在 `CompilerAndPlatform.cmake`
的 APPLE 分支补挂 `concord_apple_add_win32_compat_sources`。

结果：16 条断言全过。

## 三、顺带修的两处真缺陷（`4eb9a32`）

把 macOS 上从没跑过的契约跑起来之后，它当场暴露出两个真问题——这比"构建变绿"更有价值。

### A. `absolutePath()` 残留尾斜杠（共享代码，Windows 同样错）

`lexically_normal()` 在末元素是 `..` 时**保留分隔符**。实测：

```
alias      = [/tmp/mrw/legacy/resource/nested/..]
normalized = [/tmp/mrw/legacy/resource/]      ← 尾部多一个 /
equal to base? no
```

`path` 比较是逐元素比较，尾部空元素也算一个元素，于是 `/a/b/` != `/a/b`，
`sameRoots()` 会把调用方用 `..` 写出来的同一个根判成**不同根** → 每次都当资源变了 →
菜单复用永远不成立。

修法：规范化后剥掉空的末元素，但绝不动根（`/` 与 `C:\`）。
属共享层的"平台无关的正确改进"，不违反方案 §5.2；Windows 侧待有机器时回归一次
（行为只会从"误判不同"变成"正确判同"）。

### B. `FindFirstChangeNotificationW` 未校验目录（compat，Apple 专属文件）

Win32 要求入参是**目录**，传普通文件返回 `INVALID_HANDLE_VALUE`。FSEvents 不挑，
照单全收并"正常"watch 一个文件 —— 调用方于是得到"这棵树是新鲜的"这种**错误认证**。
症状就是契约里 `regular file cannot establish tree freshness` 恒红。

修法：`stat` + `S_ISDIR`，非目录一律 `INVALID_HANDLE_VALUE`
（`ERROR_INVALID_PARAMETER`；消费者只判 `INVALID_HANDLE_VALUE`，不依赖具体错误码）。

## 四、还有一处诚实性修正：ctest 幂等

菜单资源契约**故意**拒绝已存在的 fixture 根（`Use a new fixture directory`, return 2），
而 ctest 入口从不清目录。于是同一 build 目录：第一次绿、第二次 0.00s 红。
这个失败模式极具欺骗性 —— 看着像"刚改坏了"。

用 ctest 的 fixture 机制补：

```cmake
add_test(NAME menu_resource_watch_fixture_reset
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_BINARY_DIR}/menu-resource-watch-contract")
set_tests_properties(menu_resource_watch_fixture_reset PROPERTIES
    FIXTURES_SETUP menu_resource_watch_fixture ...)
```

连跑两次都是绿的（10.7s / 10.7s）。

## 五、验证

| 项 | 结果 |
|---|---|
| 全量构建 `-- -k 0` | 零 FAILED |
| 再构建 | `ninja: no work to do` |
| `concord_mod_noop_stage_smoke` | 622 断言，`EXIT=0` |
| `menu_resource_watch_contract` | 171 断言 `failures=0`，连跑两次均过 |
| `window_parent_win32_contract` | 16 断言 `failures=0` |
| 菜单 smoke | `rampPixels=1056,781,1428`（基线不变） |
| 遭遇战 smoke | `EXIT=0`，`maps=161 allPreviews=161` |
| interaction smoke | 推进点仍为已知 `box selection mismatch`（ON-4-07），无回退 |

## 六、代价与遗留

- **失去的覆盖**：惰性历史（1 万对象）的等价证明暂时为零，已立 **ARM-03**，归属
  `--interaction-smoke-test`（那里才有真实会话与真实查询路由）。规格书与全部断言原文
  留在退役文件里，没有丢。
- **Windows 未回归**：本次改了一处共享代码（路径规范化）。属正确性改进，
  但在有 Windows 机器时应跑一次菜单相关 smoke 确认。
- **构建时间**：全量首次约 1 分 24 秒（arm64，M5 Pro，1440 目标增量）。
  日常仍建议只编 `--target concord_runtime`（约 30 秒），全量留给收口前。
