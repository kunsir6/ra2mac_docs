# queue.rules 历史键归档（168 键）

> 来源：`progress/queue.json` 的 `rules` 段（2026-11-13 第 25 轮清单治理时迁出）。
> 主清单的 `rules` 已收敛为 5 类 × ≤3 行；需要原始叙述时查本文件。
> 归档不代表作废：这里每一条都曾是一条踩过的坑，只是不该每轮都进上下文。

## 索引（键 → 首句）

- `unit` — 每轮推进 1 个主目标（可含同一主目标下 0~N 个伴生小项），单个主目标控制在 1 小时内可完成可验证；禁止把无关问题拼成一批。
- `iron` — ["绝不修改任何既有 if(WIN32) 分支内部的行，只在它后面追加 elseif(APPLE)。", "绝不删除文件，一律用临时文件 + os.replac
- `brake` — 若上一轮 status 仍为 in_progress 或连续两轮无实质进展，本轮只做诊断并输出结论，不改代码。
- `blocked_policy` — 任务缺前置条件（如需 Windows 机器）时标 blocked 并写清原因，立刻跳到下一个 pending。
- `verify_required` — 任务标 done 前必须贴出验证命令的真实输出，输出不符则保持 in_progress。
- `note_grep` — 本机 grep/sed 是被代理的 shim，多模式与 -c 会静默返回空，一律用 Grep 工具或 python3 替代。
- `verification_ceiling` — P2-02 之后，剩余失败 TU 只能做到『编译通过』，做不到『链接通过』——concord_runtime 是整体可执行文件，RuntimeShell.cpp
- `strategy_revision` — 2026-11-10 P2-08a 诊断推翻了两条原始假设：① RuntimeShell.cpp 零条件编译、42.5% 的行直接用 Win32 类型，『把 i
- `supersede_note` — status=superseded 表示该任务被兼容层方案覆盖，不再单独执行；保留条目以便追溯，不删除。
- `brake_clarification` — 熔断只看『上一轮所选任务的最终结果』是否为 partial/diagnose-only，或是否出现了上一轮遗留的未完成工作；执行 S 系列期间不要把 P2-08
- `b0_finding` — 2026-11-10 修正版定量结论：根因是单行 `#include <list>` —— RuntimeSelectedPathRaster.h 的 7 个 
- `concurrency_warning` — 2026-11-10 03:00-03:10 实测存在第二个进程并发修改本仓库（windows.h 1617→1961 行、mmsystem.h、Runtime
- `b1_judgement_fix` — 原 b1 的判据（把这个 TU 的错误消掉）不成立。5 个 CLI smoke 入口只覆盖 23,972 行里的一部分，真正报错的是散在 68 个 diagno
- `scope_note` — S5b 实测：『修一个错误会暴露下一个』是常态——HHOOK 补齐后 SetWindowsHookExW 才浮出来，MWMO_INPUTAVAILABLE 补齐
- `product_build_ceiling` — 产品构建图的编译错误被 clang 默认 -ferror-limit=20 截断：build1 报的 79 条（20/18/1/20/20）是截断值，真实值是 
- `target_split` — 2026-11-10 教训：『某个 TU 是否报错』取决于你建的是哪个 target。tests/multiplayer/RuntimeMultiplayerT
- `lock` — 轮次锁改用 progress/.active 心跳文件（原 mkdir progress/.lock 的做法在沙箱里无法释放——rm/rmdir 被拒，下一轮会
- `link_is_the_authority` — 2026-11-10：链接是唯一权威的"还差什么"清单。编译干净≠能跑，编译只证明头层对上了；ld 才告诉你实现还差多少。280 这个数字比"5 个失败 TU"
- `arch_note` — 【2026-11-11 更新】当前判定环境是 **arm64 原生**：build-core-arm / build-product-arm，工具链来自 ven
- `gdi_partition` — 2026-11-10 实测：undefined-symbols.txt 里「GDI 绘制 / DC 状态 (67)」这一段混了三个族，正确归属是 S3 42 /
- `dc_query_load_bearing` — 2026-11-10 发现：项目有三条 raster 快路径（RuntimeSelectedPathRaster::supported、RuntimeSelec
- `selfconsistency_ceiling` — 2026-11-10：现有 raster 契约都是 optimized-vs-reference 自洽比较（两边共用同一套 GDI），只能证明快慢路径一致，不能
- `honest_success_vs_fake_success` — 2026-11-10 S9：判断一个 no-op 是否诚实的标准不是"它做了什么"，而是"调用方要的效果是否已经成立"。timeBeginPeriod(1) 可
- `surface_equivalence_trap` — 2026-11-10 S9：MSVC 的 _s 系列有自己的语义细节，"用 POSIX 同名功能顶替"会静默改行为。已确认三处：_putenv_s(name,"
- `region_representation` — 2026-11-10 S3-2：区域用**横向条带表**（每项 = 连续行 × 同一列区间）表示，多边形在 CreatePolygonRgn 里一次光栅化后就再
- `clip_not_enforced_in_pixels_yet` — 2026-11-10 S3-2 边界：裁剪区现在是**真状态**（可建、可组合、GetClipBox 三态正确），但 BitBlt/StretchBlt/Pat
- `clip_state_after_s3_3` — 2026-11-10 S3-3 更新：**图元光栅已真应用裁剪**（FillRect/FrameRect/Rectangle/Ellipse/RoundRect
- `draw_primitives_semantics` — 2026-11-10 S3-3：GDI 图元的四条语义约定（每条都有硬编码断言，改实现前先看 CompatDrawSemantics.cpp）：① 矩形类图元的
- `ellipse_is_complex_region` — 2026-11-10 S3-3：CreateEllipticRgn 兑现后 GetRgnBox 返回 **COMPLEXREGION(3)** 而不是 SIMP
- `clip_complexity_contract` — 2026-11-10 S3-2：GetClipBox 的返回值从'恒 SIMPLEREGION'改成三态。这是三条快路径的硬门槛——RuntimeRadarPi
- `gap_split_measurement` — 2026-11-10 S4-1：undefined-symbols.txt 的『C-linkage / 项目 C++』分段列曾经是错的（写 138=75+63，
- `header_change_cost` — 2026-11-10 S4-1：改 compat/win32/include/windows.h 两个宏导致 43 个 TU 全量重编、7m45s。这是预期而非
- `cg_bitmap_row_zero_is_top` — 2026-11-10 S4-2：CGBitmapContext 的数据缓冲**第 0 行是顶行**，而 CoreGraphics 的用户空间 y 轴向上（CG 
- `text_assertion_strategy` — 2026-11-10 S4-2：真字形**不能**用硬编码像素断言——字形随系统字体版本变，写死会变成脆测试。替代品是"任何真实字体都必须满足的字形语义"：'T
- `glyph_coverage_vs_notdef` — 2026-11-10 S4-2：CTFontGetGlyphsForCharacters 对**未分配码位**也会返回成功——cmap 把它们映射到 .notd
- `fixed_grid_vs_proportional_advance` — 2026-11-10 S4-2：前进宽度仍是**固定栅格**（窄字符 5:7 = 0.71em，东亚宽字符 1:1），不是字体的真实 advance。这是刻意的
- `framework_link_travels_with_source_list` — 2026-11-10 S4-2：compat 层的源清单被 11 个目标（产品 + 10 个自测）共用，所以它引入的框架依赖不能靠"记得在每个 target 上
- `gap_metric_has_a_floor` — 2026-11-10 S4-2：链接缺口不是永远有效的进度指标。S4-2 把字形从占位换成真渲染，缺口 109 → 109（零新增零消失），因为缺的从来不是符号
- `commit` — {"anchor": "族收口提交：族 = 任务 ID 去掉尾部「-数字」后的前缀（P1-01→P1、S3→S3、P5-06→P5、T-01→T、V-01→V）
- `recording_dc_text_is_silent` — 2026-11-10 14:30 实测纠正：录制型 DC 上的文本不是『显式失败』而是『静默丢弃』。drawTextRun 的首行守卫是 device->bit
- `lock_gap_mtime_after_release` — 2026-11-10 14:30：rules.lock 只判 state=held 不够——对端不写 .active 也能改仓库（实测 .active rele
- `symbol_reference_reconcile` — 符号引用点判定必须对账到 .o 级：`nm -u build-product-mac/CMakeFiles/concord_runtime.dir/**/*.o
- `lldb_wedges_process_spawn` — 2026-11-10 S4-3 实测（代价很大）：本机 `lldb` 调试会话被强杀后，整台机器的『非 Apple 签名二进制启动』全部卡死在 ps 的 `U`
- `test_must_bail_out_on_missing_resource` — 2026-11-10 S4-3：测试里 `check(x.create(), ...)` 之后若照常往下用 x 的成员，资源没建成就会变成空指针段错误——而段错
- `unsigned_exec_gate` — 2026-11-10 17:26 实测（重要，取代 rules.lldb_wedges_process_spawn 的结论）：本机当时的分界**不是**'是否 
- `getobject_dc_is_not_a_win32_call` — 2026-11-10 17:26：`GetObject(dc, sizeof(DIBSECTION), &dib)` **在真 Windows 上也返回 0**
- `compatible_dc_needs_initial_bitmap` — 2026-11-10 17:26：本层 CreateCompatibleDC（Gdi.cpp:1606-1615）只设 pen/brush/font，`devi
- `brake_is_about_new_facts` — 2026-11-10 17:26：熔断的判据是**上一轮是否留下待回答的未知**，不是记录的类型标签。规则字面上的'连续两条 partial/diagnose-
- `initial_state_changes_expose_masked_deviations` — 2026-11-10 18:31 S4-3：给 CreateCompatibleDC 补上 1×1 初值位图后，dcstate 自测里"未选位图的 DC 的 G
- `census_include_scope` — 2026-11-10 18:31：--census 用固定 include 集（compat/include + src）逐 TU 做 -fsyntax-onl
- `audio_backend_decision` — P4 后端选 AudioToolbox/AudioQueue，不选 SDL3：本机无 SDL3 安装亦无源码（build/dependencies/sdl3-3
- `ima_adpcm_is_the_real_format` — 实测 RA2/Taunts/*.WAV(72) + GameData/**/*.WAV(90) 共 152 个散装素材**全部**是 IMA ADPCM（tag
- `ima_stereo_nibble_is_four_byte_grouped` — IMA ADPCM 立体声的 nibble 数据**不是按帧交错**，而是按声道每 4 字节（8 个 nibble）为一组交错：先 ch0 的 4 字节、再 c
- `wav_cross_check_with_afconvert` — ADPCM/WAVE 解码的验收必须用系统自带解码器交叉核对：`afconvert -f WAVE -d LEI16 in.wav ref.wav` 后逐样本比
- `play_must_be_timed` — 『真的在播』的判据是墙钟下界，不是 play() 返回 true：300ms 素材从 play() 到 isPlaying() 转 false 必须 ≥250m
- `ninja_unsigned_blocks_cmake_regenerate` — cmake --regenerate-during-build 会 fork `ninja --version`；/usr/local/bin/ninja 是指
- `audio_selftest_entry` — macOS 音频底座自测 = build-product-mac/concord_apple_audio_output_selftest，参数为任意真实 .wa
- `audio_alias_is_process_global` — 2026-11-10 P4-01b：MCI 的 alias 是**进程级命名**的，所以两个设备实例其实共用同一个槽。macOS 侧必须把槽位表做成进程级静态共
- `cmake_source_list_split` — 2026-11-10 P4-01b：把 P4-01a 的 core 源与 P4-01b 的 device 源合成一个 CMake 变量，会让 output 自测
- `signed_python3_wrapper` — 2026-11-10 P4-01b 复现：本机默认 python3（~/.workbuddy/binaries/python/...）未签名，spawn 后停在
- `link_gap_zero_is_not_feature_done` — 2026-11-10 P4-01b：缺口 0 只说明 ld 不再抱怨。本项目在缺口 0 的同一时刻仍有三件未验证：① 产品从未运行（菜单音效可播无第一手证据）；
- `audio_single_slot_tables_must_be_per_family` — 2026-11-10 P4-01c 实测：槽位表原先只按容量做模板参数（table<1>()），于是 AsyncSound / MainMenuMusic / 
- `wm_timer_never_delivered` — 2026-11-10 P4-01c 实测：产品进菜单后 WM_TIMER 一次都不投递。主循环是阻塞 GetMessageW，SetTimer(window,1
- `product_asset_root_is_cwd` — 2026-11-10 P4-01c：RuntimeConfig 的 RedAlert2 / local_data 两个根都按**工作目录**解析，所以必须 cd
- `audio_trace_is_env_gated` — 2026-11-10 P4-01c：产品路径的音频取证开关 = CONCORD_AUDIO_TRACE=1。devices 层打 open/play/stop（
- `commit_milestone_exception` — 提交锚点有两个维度，不止族边界：(1) 里程碑例外——子步(ID 带字母后缀，如 P4-01b)达成可复算的量化效果(链接缺口归零/产品首次运行/首次出声/族符
- `limiter_scales_the_sum_not_a_voice` — 主声部效果器（peak limiter）乘的是**混音后的和**，不是单条 voice。两条 0.8 叠加的期望值是 0.999/1.6×1.6 = 0.999
- `audio_queue_stop_needs_a_flag_before_the_lock` — AudioQueueStop(synchronous) 会等回调返回；回调在等混音锁；若停设备的一方正持着混音锁 → 死锁。正确顺序：先置 stopping_ 
- `samples_played_is_source_frames` — XAUDIO2_VOICE_STATE::SamplesPlayed 是**源采样帧数**，不是输出帧数：22050 素材播 1 秒，输出 48000 帧而 S
- `compat_selftest_source_list_is_shared` — compat 的 12 个自测目标编译**同一份** CONCORD_APPLE_WIN32_COMPAT_SOURCES，框架清单也在同一个 set 里。把 
- `art_theater_naming` — {"finding": "RA2 建筑的剧场美术不是加后缀，而是换基名第 2 个字符：GAPOWR.SHP(16416B, snow.mix) / GGPOWR
- `wm_timer_was_never_registered` — S11 定位：问题不是"入库了但取消息不看定时器"，而是 **SetTimer 本身就是空桩**（return TRUE，什么都不记）。所以任何只改 GetMe
- `synthesized_messages_are_not_queued` — WM_TIMER 与 WM_PAINT 都是**取消息时合成**的，不进队列：入队会让它们压在真实输入前面并攒一堆；而且 PM_NOREMOVE 必须看不见它们
- `range_filter_zero_zero_means_no_filter` — GetMessage/PeekMessage 的 wMsgFilterMin=wMsgFilterMax=0 表示**不过滤**，产品的取消息调用正是 (0,0
- `blocking_getmessage_cannot_test_absence` — "应当没有消息"这类断言**不能**用 GetMessageW 驱动：它按定义会阻塞到有消息为止，于是判据本身变成死锁。用 PeekMessage 轮询固定时长
- `timer_table_is_process_wide` — 定时器表是进程级静态（与本层 messageQueue 一致），不是 Win32 的每线程队列。产品只有一条 UI 线程所以成立；若将来出现第二条 UI 线程，
- `idle_menu_cpu_is_a_probe` — S11 前后同一产品跑 12s：CPU 0.66s/11s(6%) → 1.17s/12s(9.8%)，"每秒该被调用一次"的 main-menu-music 
- `theater_char_differs_between_structures_and_overlays` — 同一批 RA2 素材里并存两套剧场字符约定，同一函数服务两边必错一边：**建筑**温带在 art/base/gg*.shp（28 个）→ 温带字符是 'G'；*
- `fallback_candidates_mask_a_wrong_first_candidate` — 候选列表里的兜底项会让"第一个候选名写错"变成完全不可见的缺陷：Q-02 里旧映射把每个温带建筑的首选名写成不存在的 gt*/nt*/yt*（362/769），
- `map_preview_coverage_needs_complete_tiles` — map-preview 的结构精灵覆盖统计不是独立入口：它挂在 --export-map-tmp-html 里，而那条路径先要求瓦片齐全（本机抽取缺 194 个
- `edit_race_sweeps_into_peer_commit` — 共享文件上的 Edit 是整文件读-改-写：对端若在你读完之后提交了整份文件，你的一次小改会把你的行卷进对方 commit，而对方 commit 的正文不会提这
- `clean_worktree_is_not_proof_of_no_peer` — git status 干净只证明'这一刻没有未提交改动'，不证明'没有别的实例在干活'：对端在自己 turn 内改完-编译-提交，中间任何一次采样都可能落在干净
- `git_add_stages_whole_file` — 并发时 `git add <file>` 提交的是**整个文件**，会把别人往同一文件里写的行一起带走。1dc77df 就把对端一条 `#include "da
- `wchar_t_width_divergence_is_the_t03_point` — 本机 wchar_t=4 字节、POSIX 的 std::filesystem::path 是 char 原生，所以：4 字节 UTF-8 只产出 **1 个*
- `manual_round_must_take_the_lock` — 人工接续轮（用户说"继续"）也必须先占锁：读 `.active`=released 之后**立刻写 held**，再读任务定义。本轮撞车就是跳过这一步——00:
- `theater_letter_is_per_family_not_per_position` — **温带字符取决于建筑家族，不取决于文件名落在哪个目录**：玩家建筑（G/N/Y 前缀）在温带用通用图 `ggtech.shp`（art/base），民用建筑（
- `first_candidate_hit_rate_needs_an_unfiltered_denominator` — Q-02 我报的"362/769 首候选不存在"是**在能解析的段里**统计的，而且把"先试剧场字母再试通用图"这个正确设计里的第一次尝试当成了缺陷。全量不筛的
- `temperate_letter_is_T_not_G` — 温带的**剧场字母**是 'T'（art/temperat/ct* 203 个；cthosp/ctoild/ctairp 都存在），'G' 只是**通用兜底**
- `first_candidate_metric_must_split_by_category` — 统计'首个候选是否命中'必须按首字母分组（C/G/N/Y）：G 类建筑的温带图确实只有 GG（gt* 从未出图），所以 G 类靠兜底命中是正常的；C 类有 CT
- `no_real_window_yet` — macOS 侧没有真窗口：ShowWindow 只翻 CompatWindow::visible，UpdateWindow 只派发 WM_PAINT，全仓库唯一
- `menu_frame_dump_hook` — 诊断入口：CONCORD_MENU_DUMP=/tmp/frame.bmp [CONCORD_MENU_DUMP_FRAME=6] 启动产品，EndPaint 
- `pointer_nav_selftest_registers_its_own_class` — 自测里建父窗口不要用 L"STATIC"：compat 的 CreateWindowExW 在 2026-11-11 01:50 前没有预定义窗口类表，返回 n
- `wait_for_state_not_for_a_fixed_delay` — 投递/发送窗口消息后必须「等到状态变化」（有界轮询 predicate），不能等固定时长：第一版 pump(60) 就断言 page 已改变，5 条断言里有 4
- `stock_window_classes_were_missing` — `--main-menu-ui-smoke-test` 在本机失败的根因不是导航：compat 的 CreateWindowExW 不认识 STATIC/BUT
- `mix_has_no_filenames` — MIX 档案不存文件名，索引表只有 CRC32 id。任何“MIX 里有没有 X”的判断必须用 MixArchive::findEntryByName / mi
- `presentation_single_window` — 本层只有一个 NSWindow，所以呈现必须"唯一化"：第一个画完的窗口成为可见窗口，之后只有严格更大的窗口才接管，小控件（EDIT/STATIC）一律拒绝。反
- `handle_table_outlives_process` — compat 的句柄表（handleMutex/handleTable）故意永不析构：它会被产品的**静态对象**在析构期访问（如 prewarmedMenuS
- `fsevents_nested_framework` — FSEvents 是嵌套框架（CoreServices.framework/Frameworks/FSEvents.framework）：不能 include 
- `modal_loop_bounded_wait` — 产品里"模态菜单循环"不能用 GetMessageW 做主循环：窗口可能在一次派发里被销毁，之后队列再不来消息，GetMessageW 会无限阻塞，while(
- `presentation_owner_area` — compat 的可见窗口规则要记住"历史面积"（gPresentedArea），不能只比当前 owner：owner 句柄一失效就查不到尺寸，会无门槛接受任意窗
- `diagnostic_must_curate_the_probe_list` — 诊断输出不能直接倒探测序列：兄弟枚举会一路枚举到 home（本机 179 条候选），逐条打印等于刷屏。只列「锚点（self 三条）+ near-miss（有 l
- `source_root_is_never_the_data_root` — 选取最近候选要按 stageRank 平票破局：环境变量(4) > 兄弟(3) > 祖先(2) > 自身(1)。源码树里常有一个自污染留下的空 local_da
- `pkill_f_kills_the_calling_shell` — pkill -f <pattern> 会匹配到**自己这条命令行**：命令串里含同一个路径时，pkill 把发起它的 zsh 一起 SIGTERM 掉，表现为「
- `iconutil_needs_real_extensions` — 生成 .icns 有两处扩展名硬约束，都不给有用的报错：① iconset **目录**必须以 .iconset 结尾且不能是隐藏名——用 `".iconset
- `app_bundle_screen_is_black_but_dib_has_content` — 2026-11-11 05:10 实测：screencapture 抓到游戏窗口为纯黑矩形（同机 WorkBuddy 窗口内容正常，排除录屏权限），而同一进程 
- `peer_swept_worktree_into_family_commit` — 2026-11-11 05:07:45 事故：本轮 ON-1-03 正在收尾（工作树 8 文件未提交）时，另一实例按族收口直接 `git add` 并提交了 5
- `external_input_policy` — 等待外部输入的任务绝不用 in_progress。三种情形与对应标记：① 交付物已经产出、只等第三方执行/回报（人眼验收、真人点击、需要授权屏幕录制）→ 标 d
- `mark_status_within_round` — 本轮结束前必须让 queue.json 里 in_progress 的数量回到 0（全部落到 done / blocked / partial 对应态），除非确
- `cgimage_cache_freezes_screen` — 呈现层**不能**缓存 CGImage：CompatWindow 的 DIB 是同一块内存、GDI 每帧覆盖写，而复用的 CGImage 被上传一次后 CA 不
- `cgimagecreate_cost_is_microseconds` — CGImageCreate 不是瓶颈：provider 是 no-copy，图像对象不分配像素缓冲。1024x640 实测（/tmp/pc/bench.mm，2
- `present_rate_is_degenerate_today` — 当前产品的提交频率接近 0：主菜单挂机 20s 内 present < 10 次（只在交互时重绘）；--skip-main-menu --skip-skirmi
- `window_capture_by_window_number` — 窗口级取证可行：`screencapture -x -o -l <NSWindow.windowNumber> out.png` 对自建窗口全部成功（18KB、
- `doc_repo` — 项目管理文档自 2026-11-11 起在独立仓库 /Users/zhenglk/ai-project/ra2mac/ra2mac_docs（main 分支）做
- `present_is_per_paint_not_per_endpaint` — 2026-11-11 06:44：ON-2-02 的文本假设「每个 EndPaint 都直接 present，同一帧可能被贴多次」。实测架构不是这样：prese
- `detail_text_may_already_be_implemented` — 2026-11-11 06:44：ON-4-01 的 detail 与 82af67d(S14a) 的改动逐字相同——任务文本在继承/搬运过程中可能与更早的提交
- `bi_rgb_stamp_must_preserve_dst_alpha` — 32bpp BI_RGB 的高 8 位不参与 GDI 语义：compat 所有像素写入经 PixelSink::fillSpan -> applyRop2，只替
- `contract_background_high_byte_is_load_bearing` — 像素契约里 reset() 的背景填充不是随便选的：RuntimeSelectedPathRasterContract.inl 的 0x91293874U ^ 
- `smoke_is_a_chain_of_contracts` — --interaction-smoke-test 是一串串行契约，修完一条必然暴露下一条（本轮：selected path raster → selection
- `lock_respect_diagnose_round` — 2026-11-11 06:33 人工轮写 .active=held 后，06:45 自动化轮检测到持锁，自动转 diagnose-only：未取锁、未碰源码、
- `existing_smokes_are_offscreen` — 2026-11-11 ON-3-01 实测：--main-menu-ui-smoke-test / --skirmish-ui-smoke-test / --i
- `cgimage_draw_into_bitmap_context_no_flip` — 把 CGImage 画进 CGBitmapContext 时**不要翻转 CTM**：CGImage 的数据第 0 行是图像顶行，DrawImage 到 (0,
- `attest_exit_must_happen_in_present` — 取证/自证模式要自己退出时，退出点必须在 present 内（写完记录、fflush 之后 _Exit），且退出码要带失败数（_Exit(failures==0
- `takeover_rule_blocked_the_owner` — 2026-11-11 ON-2-02a 实测：maybePresentClientFrame 的抢位规则只有"严格更大者接管"，而当前呈现主人与自己面积相等 →
- `world_paint_path_is_updatewindow` — 呈现路径按场景不同：主菜单 200/200 次 WM_PAINT 来自队列合成（popMessage），世界 887/888 来自 UpdateWindow 同
- `present_layer_dedup_is_not_the_cost_centre` — ON-2-02a：菜单 submits=200 且 redundant=0（present 层无重复可合并）；世界 redundant=881/888 但每帧 
- `commit_must_be_verified` — 每次提交后必须跑 git fsck --no-progress 与 git status --short，不能只看 git log。2026-11-11 实证：
- `product_full_build_is_broken` — 产品级 `cmake --build build-product-arm`（1823 目标）在 [182/1823] 失败于 concord_mod_histo
- `lighting_simd_off_on_arm64` — src/render/lighting/RuntimeLightingLookupRaster.h 用 __SSE2__ 选路，arm64 上该宏未定义 → S
- `delivery_two_thin_binaries` — 交付形态 = 两份 thin 产物，不做 universal（用户 2026-11-11 决策）。arm64: cmake -B build-product-a
- `retina_scale_measurement_trap` — 2026-11-11 实测陷阱：attest 里的 scale 只在**裸二进制**（不在 .app 内）直接执行时可信——arm 裸二进制得到 scale=2
- `system_fullscreen_needs_nsapp_run` — 系统全屏（进入独立 Space）在「不跑 [NSApp run]」的架构下不可用，已实测确认：willEnter 触发、didEnter 永不到；放宽 pump
- `selftest_must_wait_for_sink` — 2026-11-11 实证：present 里注入的自测必须等 gInputSink 就绪。setInputSink 是在 present **返回之后**才调
- `contents_scale_must_follow_backing` — gView.layer.contentsScale 不能只在建窗口时从 backingScaleFactor 抓一次。2026-11-11 实测：同一进程里 l
- `ground_rubble_excluded_from_scene_z` — scene-Z depth replay 的参与者在 RuntimeStructureSpriteGeometry.inl:361 就把 runtimeObje
- `playable_today` — 2026-11-11 实测：产品**已经可以手动玩**，两条路径都已验证到画面：① `--skip-main-menu` → 遭遇战大厅（1024x640，玩家
- `world_paint_10s_reference` — 世界视图的帧率基线（2026-11-11 arm64 实测）：10 秒 524 次 present，paints 全部走 update（UpdateWindow
- `priority_2026_11_11` — 2026-11-11 按「影响效果 ÷ 修改难度」重排（用户要求先高性价比）。判断依据：① 不改代码就能拿到信息的排最前（ON-4-04 性能基线、ON-5-0
- `priority_2026_11_11_revised` — 2026-11-11 晚间修正：ON-2-06（空转重绘）从第 3 位下调到 ON-5-01 之前。原因是实测后确认它「不做也不影响玩」——已 59.9fps、
- `full_build_is_green_now` — 2026-11-11 起：`cmake --build build-product-arm`（全量）是绿的，可以重新作为验收项。旧规则「产品全量构建从来没绿过」
- `nested_cmake_runs_before_platformapple` — DevelopmentTargets.cmake（CMakeLists 第 30 行）早于 CompilerAndPlatform.cmake（第 32 行），
- `ctest_fixture_must_be_idempotent` — 契约若拒绝已存在的 fixture 根（如菜单资源契约的 Use a new fixture directory），add_test 必须自带清理，否则同一 b
- `win32_requires_directory_for_change_notification` — Win32 的 FindFirstChangeNotification 要求入参是目录，传普通文件返回 INVALID_HANDLE_VALUE。compat 
- `any_wait_loop_must_pump_appkit` — macOS 上「拿不到输入 / 彩虹圈」的判定链（已两次踩同一族问题）：① GetMessageW 内置 pumpEvents；② MsgWaitForMult
- `autostart_regression_entry` — 【2026-11-11 已移除】曾有 CONCORD_SKIRMISH_AUTOSTART=<n>：真实窗口大厅里自动点「開始遊戲」，用于无人值守回归"大厅→加
- `input_target_must_follow_presented_window` — compat 的输入目标（setInputSink 的 context）必须跟随**当前呈现窗口**，不能只绑第一次。U-03 实测：主菜单→大厅→加载→世界每
- `hwnd_direct_smoke_cannot_cover_input_binding` — 直接用 PostMessageW / SendMessageW 投到自己手里 HWND 的 smoke（交互 smoke、大厅 flow smoke）证明不了"
- `macos_game_window_input_defaults` — macOS 上有三个默认行为会让游戏"点不动/点不准"，建窗口时必须显式处理：① NSView.acceptsFirstMouse 默认 NO → 激活窗口的那
- `stale_app_bundle_trap` — 2026-11-11 实测踩坑：用户复测"又彩虹圈"，采样发现它跑的是 build-product-arm/app/ConcordRTS.app（11:29）—
- `system_cursor_hidden_by_cursor_rect` — macOS 上游戏自绘指针，因此窗口区域内必须隐藏系统指针：view 的 resetCursorRects 里 addCursorRect(self.bound
- `debug_scaffolding_policy` — 调试脚手架（追踪日志、合成事件注入、自动点击钩子）在问题定位后必须收回：① 定位阶段可以加，但一律 env 开关 + 默认零开销，且一次只加一处；② 收口时按"
- `regress_baseline_2026_11_11` — 2026-11-11 EVO-01：回归不再靠人记命令。`bash ra2mac_docs/scripts/regress.sh` 跑 11 条用例（core/
- `smoke_suite_is_mostly_red` — 2026-11-11 首次全量实测：11 条 smoke 里只有 5 条绿（core/menu/loading/skirmish/attest），6 条红且其中
- `dist_app_hash_is_not_comparable` — 2026-11-11 实测：不能拿 .app 里 concord_runtime 的 sha256 与 build 产物对账——ad-hoc 重签名会改写文件，
- `priority_2026_11_11_evolution` — 2026-11-11 傍晚用户定调：游戏已能运行，暂不方便做大量人工验证，后续按「无人值守可自证」排序。新顺序：EVO-01 回归编排器（done）→ EVO-
- `triage_2026_11_11` — 2026-11-11 EVO-02 分诊结论（6 条 KNOWN-RED 全部落定）：build=code-red（compat 未实现 CP1252，零售 T
- `system_cursor_hidden_needs_full_coverage` — 2026-11-11 U-06：隐藏系统指针的前提是「每个区域都有游戏自绘指针」，而这个前提必须逐区域验证，不能只看地图区。实测反例：世界页面右侧栏（HUD）此
- `get_key_state_units` — GetKeyState 与 GetKeyboardState 共用一张字节表但位布局不同：表里按下=字节 bit7(0x80)，GetKeyState 返回 S
- `compat_headers_no_windows_in_objcxx` — Objective-C++(.mm) 里禁止 include 带 <windows.h> 的 compat 头：会与 AppKit 的 Polygon/GetC
- `bundle_identity_is_atomic` — .app 的身份 = 名字 + 图标 + LaunchServices 登记，三者必须一次改完：只换二进制/Finder 仍显示旧图标旧名。交付一律走 ra2m
- `icns_exists_is_not_enough` — 判断图标是否生效，不能看 .icns 是否存在、也不能只跑 iconutil，必须向 IconServices 取渲染结果并与「无图标空壳 bundle」的空白
- `fullscreen_needs_primary_and_real_click` — 全屏能力有两位：collectionBehavior=NSWindowCollectionBehaviorFullScreenPrimary（决定绿灯是「展开箭
- `view_coords_are_not_surface_coords` — 鼠标坐标必须先按「表面尺寸/view 尺寸」反算回呈现表面空间再交给游戏。view 坐标只在 view==表面时等于客户区坐标；全屏或拉伸窗口之后直接用 vie
- `fullscreen_criteria_no_hash` — 全屏自测的判据不能用「前后帧 hash 不变」：全屏期间界面本来就在动（光标闪烁、动画），hash 必变。判据应是 contents 未丢 + CGImage 
- `nscursor_set_is_global` — -[NSCursor set] 设的是**全局**当前游标，不会因为指针离开窗口自动撤销：只要有一条路径 set 了空图，指针在别的应用/桌面上也会看不见。区域
- `cursor_rect_needs_send_event` — 本项目只 nextEventMatchingMask 出队、不调 [NSApp sendEvent:]，实测这种循环里 cursor rect（addCurso
- `cursor_state_needs_truth_not_flag` — 判断「光标现在是不是被我们藏了」要读 +[NSCursor currentSystemCursor]（系统此刻真正在显示什么），不要用自己的标志位：AppKit
- `pointer_capture_is_association_off` — macOS 没有把光标裁剪在窗口内的 API。所谓「抓住鼠标」= CGAssociateMouseAndMouseCursorPosition(false)：硬
- `warp_bypasses_capture` — CGWarpMouseCursorPosition 是显式定位，会绕过 CGAssociateMouseAndMouseCursorPosition(false

## 全文

### unit

```
每轮推进 1 个主目标（可含同一主目标下 0~N 个伴生小项），单个主目标控制在 1 小时内可完成可验证；禁止把无关问题拼成一批。
```

### iron

```
[
 "绝不修改任何既有 if(WIN32) 分支内部的行，只在它后面追加 elseif(APPLE)。",
 "绝不删除文件，一律用临时文件 + os.replace / mv 原子替换。",
 "提交按 rules.commit 的颗粒度与文案执行；绝不 git push / reset / force / amend，只 commit 不改历史。",
 "每轮结束必须更新本文件 tasks[].status 与 progress/RUNLOG.md。"
]
```

### brake

```
若上一轮 status 仍为 in_progress 或连续两轮无实质进展，本轮只做诊断并输出结论，不改代码。
```

### blocked_policy

```
任务缺前置条件（如需 Windows 机器）时标 blocked 并写清原因，立刻跳到下一个 pending。
```

### verify_required

```
任务标 done 前必须贴出验证命令的真实输出，输出不符则保持 in_progress。
```

### note_grep

```
本机 grep/sed 是被代理的 shim，多模式与 -c 会静默返回空，一律用 Grep 工具或 python3 替代。
```

### verification_ceiling

```
P2-02 之后，剩余失败 TU 只能做到『编译通过』，做不到『链接通过』——concord_runtime 是整体可执行文件，RuntimeShell.cpp 未解决前没有端到端验证。因此优先做 P2-08 以提前建立『能链接』这个门槛，避免把风险后置到某一轮集中引爆。
```

### strategy_revision

```
2026-11-10 P2-08a 诊断推翻了两条原始假设：① RuntimeShell.cpp 零条件编译、42.5% 的行直接用 Win32 类型，『把 include 包进 #ifdef』只会把每行都变成错误；② 逐文件 port 要动 42 个 TU，而全产品构建图只需要 74 个 Win32 API + 25 个类型。故 P2-04/05/06/07/09 与 P3-01 标记 superseded，改走 Win32 兼容层（S1–S5）。证据见 P2-08a-诊断报告.md。
```

### supersede_note

```
status=superseded 表示该任务被兼容层方案覆盖，不再单独执行；保留条目以便追溯，不删除。
```

### brake_clarification

```
熔断只看『上一轮所选任务的最终结果』是否为 partial/diagnose-only，或是否出现了上一轮遗留的未完成工作；执行 S 系列期间不要把 P2-08 的续作桶状态当作熔断信号，否则会形成每轮只诊断的死锁。2026-11-10 已把 P2-08 回退为 pending 以消除歧义。
```

### b0_finding

```
2026-11-10 修正版定量结论：根因是单行 `#include <list>` —— RuntimeSelectedPathRaster.h 的 7 个 std 头里，只有 <list> 从未在 RuntimeShell.cpp 文件顶部出现过，所以在 L21848 被引入时把 `namespace std` 开进了匿名命名空间（L243..L29263，29,021 行）。隔离实验（同一 shim，只差这一行）：有=7 条错误 / 无=72,652 条，即单行值 72,645 条。此前记的『146 条』是 clang 默认 -ferror-limit=20 的上限假象，真实值 73,291。修法 = 文件顶部加 1 行，零删除。
```

### concurrency_warning

```
2026-11-10 03:00-03:10 实测存在第二个进程并发修改本仓库（windows.h 1617→1961 行、mmsystem.h、RuntimeShell.cpp 的 <list> 与 6 处 std::max<LONG>、RuntimePlayerHotkeysUi.inl 的 wchar_t 分支）。后果：①跨轮次错误数对比失真（同一小时内测得 385/22/0 三个值都真）；②build-product-mac 是共享目录，并发构建会互相踩 .o 与 .ninja_deps；③同文件原子替换后写者赢、先写者静默消失。对策：轮次开始先 mkdir progress/.lock，成功才继续，失败立即转 diagnose-only 并在 RUNLOG 记录『检测到并发实例』；对比类结论必须同时记录被测文件的 mtime。
```

### b1_judgement_fix

```
原 b1 的判据（把这个 TU 的错误消掉）不成立。5 个 CLI smoke 入口只覆盖 23,972 行里的一部分，真正报错的是散在 68 个 diagnostics/*.inl 的缺声明，而 b0 之后这些本该由 S5 补声明解决。摘 TU 只适用于『该 Win32 API 只被 diagnostics 调用』的场合（CreateEnhMetaFileW / HANDLETABLE / GR_GDIOBJECTS 这类），不是通用解法。
```

### scope_note

```
S5b 实测：『修一个错误会暴露下一个』是常态——HHOOK 补齐后 SetWindowsHookExW 才浮出来，MWMO_INPUTAVAILABLE 补齐后 MsgWaitForMultipleObjectsEx 才浮出来；xaudio2.h 补齐后 xapobase.h 才浮出来。所以每轮结尾必须重跑 -ferror-limit=0 的全量诊断，不能用上一轮的清单安排下一轮。
```

### product_build_ceiling

```
产品构建图的编译错误被 clang 默认 -ferror-limit=20 截断：build1 报的 79 条（20/18/1/20/20）是截断值，真实值是 150。对比错误数时必须用 -ferror-limit=0 的单 TU 诊断，不能用 ninja 日志的分块计数——除非每块都未触顶。
```

### target_split

```
2026-11-10 教训：『某个 TU 是否报错』取决于你建的是哪个 target。tests/multiplayer/RuntimeMultiplayerTwoProcessSmoke.cpp 有 36 条错误，但它属独立 target concord_multiplayer_two_process_smoke，ninja concord_runtime 永远不报它。每轮收尾必须同时跑 ① ninja -C build-product-mac -k 0 concord_runtime ② scripts/verify-win32-compat.sh --census，两个失败集都记录。另外 --census 的 TU 总数会随构建图变化（本轮 31，上一轮 37），所以只能比**具名 TU**，不能比通过率。
```

### lock

```
轮次锁改用 progress/.active 心跳文件（原 mkdir progress/.lock 的做法在沙箱里无法释放——rm/rmdir 被拒，下一轮会误判『检测到并发实例』而死锁）。约定：开始前读 .active，若 state=held 且 mtime 距今 <90min 则转 diagnose-only；否则写入 state=held + pid + 起始时间并继续。收尾写 state=released。仓库里那个空的 progress/.lock/ 目录是旧约定的遗留物，忽略即可。
```

### link_is_the_authority

```
2026-11-10：链接是唯一权威的"还差什么"清单。编译干净≠能跑，编译只证明头层对上了；ld 才告诉你实现还差多少。280 这个数字比"5 个失败 TU"有用得多——因为它可分区、可排期、可对账。以后每轮收尾除 ninja 与 --census，还要看链接缺口数是否单调下降。
```

### arch_note

```
【2026-11-11 更新】当前判定环境是 **arm64 原生**：build-core-arm / build-product-arm，工具链来自 venv /Users/zhenglk/AiProjects/ra2mac/.toolchain（cmake 4.4.4 + ninja 1.13.2，brew 被沙箱拦故改用 pip wheel），调用时把该 bin 前置到 PATH。旧的 build-core-mac / build-product-mac 是 x86_64 且 CMakeCache 写死已不存在的 /Users/zhenglk/ai-project/... 路径，只能作历史证据，不可增量构建。要出 x86_64 产物必须显式给 CMAKE_OSX_ARCHITECTURES=x86_64，不再默认。实测：arm64 上内核 170/170 + 10/10、金标准哈希 1585785091039784157 与 x86 逐位相同（零代码改动）。
```

### gdi_partition

```
2026-11-10 实测：undefined-symbols.txt 里「GDI 绘制 / DC 状态 (67)」这一段混了三个族，正确归属是 S3 42 / S7 14 / S4 11（脚本校验无遗漏无重叠）。S3 内部再分 A 段 DC 状态与查询 25、B 段区域裁剪 5、C 段图元光栅 12。排期以 A→B→C 为序，因为 C 段的光栅器在 A 段完成前没有观测点。
```

### dc_query_load_bearing

```
2026-11-10 发现：项目有三条 raster 快路径（RuntimeSelectedPathRaster::supported、RuntimeSelectionFrameRaster 构造函数、beginTrustedRestoredDcStateBatch）先精确校验 DC 状态再直接写 DIB 像素。它们要求 GetArcDirection==AD_COUNTERCLOCKWISE(2)、GetClipBox 返回 SIMPLEREGION(2)/NULLREGION(1)、GetGraphicsMode==GM_COMPATIBLE(1)、GetROP2==R2_COPYPEN(13)、GetLayout==0、Get*/SetViewportOrgEx 为 (0,0)，并且 GetObject(dc, sizeof(DIBSECTION))==sizeof(DIBSECTION) 且 bmBits==像素指针。所以「查询函数随手 return 0」是错的：它会静默关闭快路径，让所有 raster 契约退化成只跑 reference 路径，看起来还在跑其实什么都没验证。查询必须如实返回。
```

### selfconsistency_ceiling

```
2026-11-10：现有 raster 契约都是 optimized-vs-reference 自洽比较（两边共用同一套 GDI），只能证明快慢路径一致，不能证明与 Windows GDI 一致——LineTo 差一像素、FillRect 边界画成闭区间，这些契约照样全绿。S3/S4 的 done 判据必须补一层「硬编码期望像素」的文档语义断言，且 B-01 的 Windows 基线只覆盖 core，没有产品级像素金标准可对拍。
```

### honest_success_vs_fake_success

```
2026-11-10 S9：判断一个 no-op 是否诚实的标准不是"它做了什么"，而是"调用方要的效果是否已经成立"。timeBeginPeriod(1) 可以返回成功，因为 macOS 的 1ms 睡眠粒度是真的；CoInitializeEx 可以返回 S_OK，因为"成功⇒配对 CoUninitialize"这条契约能守。但 mciSendStringW 必须失败，因为它要的效果（出声）在 mac 上一点都没有。判据落在效果上，不落在 API 名上。
```

### surface_equivalence_trap

```
2026-11-10 S9：MSVC 的 _s 系列有自己的语义细节，"用 POSIX 同名功能顶替"会静默改行为。已确认三处：_putenv_s(name,"") 是删除变量（setenv 顶替会让 getenv 返回非空 ""，所有"是否开启"的判据翻转）；_wgetenv_s 两段式必须两次同 count、未定义返回 0、不足返回 ERANGE；gmtime_s 参数顺序与 gmtime_r 相反（双指针写反照样编译）。以后接任何 MSVC 专有 CRT 函数，先查文档里的边界语义，再写代码。
```

### region_representation

```
2026-11-10 S3-2：区域用**横向条带表**（每项 = 连续行 × 同一列区间）表示，多边形在 CreatePolygonRgn 里一次光栅化后就再也没有曲线概念。选它的理由不是性能，是四件必须精确的事：判点、求外接框、区分 SIMPLE/COMPLEX、给裁剪光栅器逐行取区间——条带表让它们全部变成整数区间运算且顺序无关（确定性）。代价：丢了 Win32 区域'边界含点'的亚像素细节；项目里所有区域都是整数坐标，裁剪要的也是像素格，故一致。规范化不变量：条带互不重叠 → '多于一条' 就必然是 COMPLEXREGION，这是复杂度判定的唯一依据，compressRows 必须保证它。行数上限 16384，超限**返回失败**而不是截断（截断会得到'看起来对、少了一块'的区域）。
```

### clip_not_enforced_in_pixels_yet

```
2026-11-10 S3-2 边界：裁剪区现在是**真状态**（可建、可组合、GetClipBox 三态正确），但 BitBlt/StretchBlt/PatBlt/StretchDIBits 仍然忽略它，S3-3 的图元光栅器也必须显式应用 (x-windowOrg)*viewportExt/windowExt+viewportOrg 与裁剪。后果要说清：RuntimeShell 的进度时钟遮罩（SelectClipRgn + FillRect）在 mac 上会画成整块方形；所有'快慢两路一致'的契约仍会全绿，因为它们两边用的是同一套忽略裁剪的 GDI。S3-3 的 done 判据必须包含'硬编码期望像素 + 裁剪生效'两条，不能只看契约自洽。
```

### clip_state_after_s3_3

```
2026-11-10 S3-3 更新：**图元光栅已真应用裁剪**（FillRect/FrameRect/Rectangle/Ellipse/RoundRect/Polygon/Polyline/PolyPolyline/GdiAlphaBlend 全走 PixelSink，逐行取 spansAtRow(clip) 与表面求交），进度时钟遮罩从此不再画成方块。**位图传输族仍未应用**：BitBlt/StretchBlt/PatBlt/StretchDIBits/SetDIBitsToDevice 仍只裁到表面边界。下一轮若碰到遮罩类视觉缺陷，先查这一族而不是图元族。
```

### draw_primitives_semantics

```
2026-11-10 S3-3：GDI 图元的四条语义约定（每条都有硬编码断言，改实现前先看 CompatDrawSemantics.cpp）：① 矩形类图元的右/下边界**不属于**该矩形，Rectangle 的边框画在 right-1/bottom-1 上；② LineTo 与 Polyline **不画终点**（否则连续线段会在每个拐点写两次，XOR 下变空洞），Polygon 的闭合边则必须包含起点；③ 当前位置是**逻辑坐标**，MoveToEx 回传的是移动前的值；④ 形状的填充区=内缩 penWidth，描边区=形状减内缩区，两者严格不相交——RuntimeSelectedPathRasterContract/SelectionFrameRasterContract 用 XOR 画两遍来擦除，重叠处会留残影。另：录制型 DC 上所有图元一律显式失败（EMR_RECTANGLE/LINETO/ELLIPSE/POLYLINE/ALPHABLEND 均未实现），因为静默不记录会让帧稳定性审计漏报'出现中间帧'。
```

### ellipse_is_complex_region

```
2026-11-10 S3-3：CreateEllipticRgn 兑现后 GetRgnBox 返回 **COMPLEXREGION(3)** 而不是 SIMPLEREGION——这不是 bug，Windows 的椭圆区域本来就是复杂区域。写断言时别按'单个凸区域=简单区域'的直觉。同理，椭圆区域的条带表逐行不同宽，compressRows 只能合并等宽相邻行。
```

### clip_complexity_contract

```
2026-11-10 S3-2：GetClipBox 的返回值从'恒 SIMPLEREGION'改成三态。这是三条快路径的硬门槛——RuntimeRadarPixelStoreWin32.cpp:40 与 RuntimeTerrainViewportFill.h:79 判 `!= SIMPLEREGION` 就退让。以前恒答 2，复杂裁剪下它们继续直接写像素、绕过裁剪，而所有自洽契约照样全绿。另：SelectClipRgn 返回的是 clip∩surface 的复杂度，与 GetClipBox 一致（两处不一致会让调用点按返回值选路、按 GetClipBox 判状态，自相矛盾）。
```

### gap_split_measurement

```
2026-11-10 S4-1：undefined-symbols.txt 的『C-linkage / 项目 C++』分段列曾经是错的（写 138=75+63，按 ld 原始清单逐条判定真值是 83+55；总数对、分段错）。判据只有一条：符号名含 `concord::` 即项目 C++。以后每轮重跑清单时必须从这个判据现算，不能沿用上一版的分段数字——否则『本轮降了 N 个』会归因到错的族上。
```

### header_change_cost

```
2026-11-10 S4-1：改 compat/win32/include/windows.h 两个宏导致 43 个 TU 全量重编、7m45s。这是预期而非回归。凡是动该头的轮次，要么预留这段时间，要么把它与需要观测链接缺口的改动放同一轮，避免白跑一趟。
```

### cg_bitmap_row_zero_is_top

```
2026-11-10 S4-2：CGBitmapContext 的数据缓冲**第 0 行是顶行**，而 CoreGraphics 的用户空间 y 轴向上（CG y=0 落在最后一行）。用"y=0 的填充矩形"做对照实验可以一分钟确认，别猜。踩过的坑：按底行读缓冲，整幅字形上下翻转——依旧"有墨迹"、宽度也对、'H'/'T' 看起来还是 'H'/'T'（竖轴对称），只是 'e' 变形、'.' 跑到顶部、'g' 的降部在上方。所有基于墨迹包围盒的定位随之全错，而错误表现是"字有点丑"而不是"崩溃"。
```

### text_assertion_strategy

```
2026-11-10 S4-2：真字形**不能**用硬编码像素断言——字形随系统字体版本变，写死会变成脆测试。替代品是"任何真实字体都必须满足的字形语义"：'T' 与 'e' 共用基线（底边相同、顶边 'T' 更低）、'g' 有降部、'L' 的横杠在底部（这条专门挡整体上下翻转，翻转后 'T' 仍像 'T'）、空格无墨迹但 OPAQUE 下铺满背景、同一次调用两次逐字节相同（确定性）、XOR 画两遍整块表面还原（只有 1bit mask 才成立）。另有一条假通过的教训：XOR 用例用黑色笔在白底上画，white ^ black == white，等于没画，"两遍还原"在"什么都没发生"上照样成立。XOR 断言必须配一条"第一遍确实改了像素"。
```

### glyph_coverage_vs_notdef

```
2026-11-10 S4-2：CTFontGetGlyphsForCharacters 对**未分配码位**也会返回成功——cmap 把它们映射到 .notdef（实测 Helvetica 是字形 4）。所以"cmap 查到了"不等于"字体有这个字"。正确判据是 CTFontCopyCharacterSet 的成员测试；还要再挡一层兜底字体（LastResort 一类）：它以"覆盖全部码位"的方式工作，成员测试也会通过。判据取 U+0378——Unicode 里未分配，任何真实文字字体都不该有它，声称有的就是兜底字体。没有这两层，GetGlyphIndicesW 会对任何乱码都报一个"真实"索引，RuntimePlayerDefeatNoticeSmoke 的'字体是否覆盖所需汉字'判据彻底失效（永远通过），而屏幕上是 CoreText 自己的空心框。
```

### fixed_grid_vs_proportional_advance

```
2026-11-10 S4-2：前进宽度仍是**固定栅格**（窄字符 5:7 = 0.71em，东亚宽字符 1:1），不是字体的真实 advance。这是刻意的：P5-06 的度量断言、5 个字体 TU 的居中逻辑都建在"measure == draw"上，换比例度量会一起动。代价写在明处：英文显得偏宽（Helvetica 的 'i' 只有 0.22em 也占 0.71em），密集区偏挤；换行/省略号也因此没法只靠度量做。要改必须整轮只做这一件事，并且同步重算所有依赖宽度的手工断言。另：CJK 必须走 1:1，否则汉字互相压住——这是 S4-2 之前按 c*width 算宽度的真实后果（ASCII 全绿）。
```

### framework_link_travels_with_source_list

```
2026-11-10 S4-2：compat 层的源清单被 11 个目标（产品 + 10 个自测）共用，所以它引入的框架依赖不能靠"记得在每个 target 上加一次"。做法：框架清单与源清单定义在一起，concord_apple_add_win32_compat_sources() 内部直接链接；自测侧用目录级 BUILDSYSTEM_TARGETS 正则 `^concord_win32_compat_.*_selftest$` 统一补，新加自测自动带上。漏一个的症状是"编译全过、链接报 CoreText 符号未定义"，与源码无关，很容易查错方向。
```

### gap_metric_has_a_floor

```
2026-11-10 S4-2：链接缺口不是永远有效的进度指标。S4-2 把字形从占位换成真渲染，缺口 109 → 109（零新增零消失），因为缺的从来不是符号，是行为。S4/S7 这类轮次验收要看各自的语义断言，不能因为"数字没降"就判定没进展，也不能为了让数字下降去补无关符号。
```

### commit

```
{
 "anchor": "族收口提交：族 = 任务 ID 去掉尾部「-数字」后的前缀（P1-01→P1、S3→S3、P5-06→P5、T-01→T、V-01→V）。某族全部任务 status ∈ {done,superseded} 时该族收口，提交一次。单成员族（S1~S10、V-01、Q-01、B-01、P4-01 等）自身 done 即收口。",
 "forbidden": "partial / diagnose-only / in_progress / blocked 轮次不提交；只编译通过、链接未通过 的半成品态不提交。",
 "add": "收口提交时 git add：① 该族任务 touches 字段列出的仓库内文件；② 该族新产生的未跟踪源文件；③ 相关 cmake 变更。注意：报告 .md 与 progress/ 在 git 仓库外，不纳入提交。",
 "message": "单行 subject ≤60 字：`<族ID> <成果一句话>（<关键对账数字>）`；无对账数字则省略括号；需要时用 - 列表补 body。对账数字按优先级取：链接缺口 N→M > 编译 TU X/Y > 测试/断言通过数。示例：`S3 GDI 区域与图元：42 符号清零（缺口 236→225）`。",
 "never": "绝不 git push / reset / force / amend；push、远程同步、存量未提交改动的归位由人执行。",
 "legacy": "存量未提交改动已于 2026-11-10 由人按族切分为 7 个提交（P1 / P2 / S1 / S2-S10 / P5 / P5-06 / P5-T），main 领先 origin 7 个提交，待人 push。"
}
```

### recording_dc_text_is_silent

```
2026-11-10 14:30 实测纠正：录制型 DC 上的文本不是『显式失败』而是『静默丢弃』。drawTextRun 的首行守卫是 device->bitmap == nullptr → return（RuntimeWin32CompatGdi.cpp:1545），而 CreateEnhMetaFileW 造的 device 没有 bitmap（L1759-1768 只挂 recording）。于是 TextOutW/DrawTextW/DrawTextA/ExtTextOutA 在录制 DC 上返回 TRUE、不画、不记录、不打日志；图元族则有 10 处显式 reportUnsupported。三个产品录制点目前都先合成到 memory DC 再 BitBlt，故未爆；但 campaign 的 completeFrameOnly 与 loading 的 unexpectedRecord 都把『除 blit 外不许有记录』写成硬断言，一旦真有路径把文本画进录制 DC，审计会静默通过而文本消失。处置：3 行 reportUnsupported，不改行为。
```

### lock_gap_mtime_after_release

```
2026-11-10 14:30：rules.lock 只判 state=held 不够——对端不写 .active 也能改仓库（实测 .active released @13:54，源码 14:09-14:20 继续被写，ninja pid 50620 在跑）。判据补充为：仓库源码 mtime 晚于 .active 的 released/start 时间 ⇒ 视为并发，转 diagnose-only。另：build-product-mac/.ninja_lock 被持有期间连 ninja -n 都不要跑。
```

### symbol_reference_reconcile

```
符号引用点判定必须对账到 .o 级：`nm -u build-product-mac/CMakeFiles/concord_runtime.dir/**/*.o | grep <符号>` 逐 .o 穷尽，不能只靠 ld 输出的 tail（会被截断漏掉第 3 个引用文件）。2026-11-10 P5-07 教训：D3D11 引用点实为 3 个 .o（Shell 13 / SkirmishMenu 11 / MapRenderer 4），前 2 个之外还有 RuntimeMapRenderer.cpp.o。
```

### lldb_wedges_process_spawn

```
2026-11-10 S4-3 实测（代价很大）：本机 `lldb` 调试会话被强杀后，整台机器的『非 Apple 签名二进制启动』全部卡死在 ps 的 `U` 状态——之后 /tmp 下自建的 clang、python3、测试可执行一律无任何输出挂起，而 /bin/ps、/bin/echo、/bin/cat 这些系统常驻程序照常工作。表现极易误判成『测试死锁』或『编译卡住』。结论：以后这台机器上不要用 lldb 定位崩溃（连 `lldb -b -o run -o bt` 都会挂）；改用 ① 程序内 setvbuf + 分段落日志，② clang -fsanitize=address 独立构建，③ 只读代码推演。恢复只能重启，重启前不要指望能再编译任何东西。（**2026-11-10 17:26 更正：这条结论错了两半**——① 不是『整机不可用』，clang / ld / codesign / git 一直正常，『连编译都不行』是误判；② 不需要重启，见 rules.unsigned_exec_gate。保留原文以便追溯当时的判断过程。）
```

### test_must_bail_out_on_missing_resource

```
2026-11-10 S4-3：测试里 `check(x.create(), ...)` 之后若照常往下用 x 的成员，资源没建成就会变成空指针段错误——而段错误会把真正的失败原因完全掩盖（本轮 exit 139 就是这个形状，看起来像绘制/字形崩了）。规矩：所有 create()/GetDC() 类断言后面必须紧跟 `if (!ready) { 收尾打印; return; }`，让失败是『一句话说清原因』而不是一个 signal。另：主程序开头必须 `setvbuf(stdout, nullptr, _IONBF, 0)`，否则崩溃时块缓冲把全部进度日志一起丢掉。
```

### unsigned_exec_gate

```
2026-11-10 17:26 实测（重要，取代 rules.lldb_wedges_process_spawn 的结论）：本机当时的分界**不是**'是否 Apple 签名'，而是**'Mach-O 里有没有 embed 的签名'**。未签名的可执行文件 exec 会卡在 ps 的 U 状态且 kill -9 无效；签名过的（哪怕是 ad-hoc）立刻正常。判据用对照组钉死：同一个 /tmp/hello2 未签名→卡死，`codesign -s - --force` 之后立刻输出 hello-exec-ok（EXIT=0），唯一变量是签名。而 Apple 平台签名的 clang/ld/codesign/git 一直可用——所以'整机不可用'是误判，编译链路其实没坏，坏的是**启动未签名二进制**这一步（Homebrew 的 ninja、workbuddy 的 python3、clang 现编出来的测试程序全都是未签名）。三条绕过命令：① `cp /usr/local/bin/ninja /tmp/ninja_signed && codesign -s - --force /tmp/ninja_signed`（`/usr/local/bin/ninja` 是指向 ~/opt/ninja/ninja 的符号链接且 `code object is not signed at all`）；② 链接产物跑之前 `codesign -s - --force <目标二进制>`；③ python3 用签名副本 + `DYLD_LIBRARY_PATH=~/.workbuddy/binaries/python/versions/3.13.12/lib`（签名必须作用在**实体二进制**上，直接 cp 符号链接会 dyld 报 `@rpath/libpython3.13.dylib` 缺失、EXIT=134）；④ 若 ninja 需要重跑 cmake，cmake 也在 ~/opt/cmake/bin 且未签名，同样要签名副本（本轮 build.ninja 未失效，故未触发）。
```

### getobject_dc_is_not_a_win32_call

```
2026-11-10 17:26：`GetObject(dc, sizeof(DIBSECTION), &dib)` **在真 Windows 上也返回 0**——Win32 的 GetObject 只接受 GDI 对象句柄，不接受 HDC。兼容层 GetObjectW（Gdi.cpp:2387）第一行 `asObject(h)` 就把 HDC 判成 nullptr，行为与 Windows 一致，**不要为此给 GetObjectW 加 DC 分支**（那会让本层比 Windows 更宽松，掩盖调用点错误）。正确写法是 `GetObject(GetCurrentObject(dc, OBJ_BITMAP), sizeof(DIBSECTION), &dib)`，产品侧四处 raster 快路径（RuntimeSelectedPathRaster.h:209 / RuntimeSelectionFrameRaster.h:160 / RuntimeRadarPixelStoreWin32.cpp:44 / RuntimeTerrainViewportFill.h:84）本来就这么写，错的只有 S4-3 的测试。这条也一并更正 rules.dc_query_load_bearing 里 `GetObject(dc, ...)` 的表述。
```

### compatible_dc_needs_initial_bitmap

```
2026-11-10 17:26：本层 CreateCompatibleDC（Gdi.cpp:1606-1615）只设 pen/brush/font，`device->bitmap` 留空，于是新建 DC 上第一次 `SelectObject(dc, bitmap)` 返回 `toHandle(nullptr)` = **nullptr**（toHandle 见 717 行）。Win32 语义里新建兼容 DC 自带 1×1 单色位图，SelectObject 必返回非空旧对象。后果：任何 `HGDIOBJ old = SelectObject(...); if (!old) 失败` 的写法都会把'选中成功'判成失败（S4-3 的 OwnedDib::create 就是这么踩的，直接导致回读 DIB 没建成、无 PNG）。现产品代码没有这个判据（全库 grep `SelectObject(...) == nullptr` 无匹配），所以还没爆，但这是最常见的 Win32 习惯写法，属定时炸弹，应在 S4-3 收口时一并补上初始位图。 2026-11-10 18:31 **已修复**：CreateCompatibleDC 末尾造 1×1 单色位图（CompatDevice::ownedBitmap 拥有、DeleteDC 释放、CompatObject::monochrome 让 GetObject 如实报 bmBitsPixel=1）。副作用：新建 DC 的 GetClipBox 由 ERROR(0) 变成 SIMPLEREGION(2)+{0,0,1,1}（这才是 Win32 语义），dcstate 自测里钉旧偏离的那条断言已更正。
```

### brake_is_about_new_facts

```
2026-11-10 17:26：熔断的判据是**上一轮是否留下待回答的未知**，不是记录的类型标签。规则字面上的'连续两条 partial/diagnose-only 即熔断'若机械执行会形成永久死锁：partial 之后必然诊断一轮，诊断一轮之后又是'连续两条'。正确读法：诊断轮只要产出了**新的可验证事实**（真实运行输出、定位到行号的根因、可复现的绕过命令），熔断即解除，下一轮直接执行修复；只有当诊断轮只能重复上一轮的结论（没有新事实可产出）时，才继续熔断并交由人判断。本轮按此读法标记为 diagnose-only，但下一轮（S4-3 收口）不再做诊断。
```

### initial_state_changes_expose_masked_deviations

```
2026-11-10 18:31 S4-3：给 CreateCompatibleDC 补上 1×1 初值位图后，dcstate 自测里"未选位图的 DC 的 GetClipBox 返回 ERROR(0)"立刻变红。判断关键：这条断言钉的是**本层的偏离**而不是 Win32 语义（真 Windows 新建 DC 也有 1×1 表面），所以正确处置是改断言、并把新语义钉细（含 {0,0,1,1} 四个数值），不是回退实现。同一处偏离当年还顺带掩盖了"首次 SelectObject 返回 nullptr"——两个 bug 一条根因。经验：改初始状态/初值时，先区分"哪些断言是我的错"与"哪些断言是旧实现的错"，否则会为了保住绿而把 bug 保回来。
```

### census_include_scope

```
2026-11-10 18:31：--census 用固定 include 集（compat/include + src）逐 TU 做 -fsyntax-only，但 compat/win32/selftest/CompatUserSemantics.cpp 会 include "RuntimeWin32CompatInternal.h"（在 compat/win32/src），于是它必然失败。判据：这类失败补 -I compat/win32/src 后 EXIT=0 即为普查口径缺口，不是产品 TU 回归。另：TU 分母随构建图变化（本轮 479，因新增自测目标），只能比具名 TU，与本轮一致的结论仍是"S8 的多进程 smoke 是唯一真失败"。
```

### audio_backend_decision

```
P4 后端选 AudioToolbox/AudioQueue，不选 SDL3：本机无 SDL3 安装亦无源码（build/dependencies/sdl3-3.4.16 不存在），cmake/Sdl3Window.cmake 明写 'verified on Windows only' 且'no automatic dependency installation is performed'；P3-01(SDL3 窗口) 已 superseded，SDL3 不再是共享依赖；多平台方案 §P4 原文允许 CoreAudio。要换回 SDL3 只需替换 src/audio/apple/RuntimeAppleAudioOutput.cpp 一个文件。
```

### ima_adpcm_is_the_real_format

```
实测 RA2/Taunts/*.WAV(72) + GameData/**/*.WAV(90) 共 152 个散装素材**全部**是 IMA ADPCM（tag 0x11），22050Hz；Taunts 72 个是单声道，另外 10 个菜单音乐是 22050Hz 立体声 blockAlign=1024/samplesPerBlock=1017。只做 PCM 解码等于『接口通了但一句都听不到』。音频客户端若再遇到 tag 0x02(真 MS ADPCM) 仍需单独实现。
```

### ima_stereo_nibble_is_four_byte_grouped

```
IMA ADPCM 立体声的 nibble 数据**不是按帧交错**，而是按声道每 4 字节（8 个 nibble）为一组交错：先 ch0 的 4 字节、再 ch1 的 4 字节，循环。单声道时两种写法结果完全相同，所以只测单声道永远发现不了——错了会让右声道从第 1 帧起全体错位（10 个菜单音乐全中）。
```

### wav_cross_check_with_afconvert

```
ADPCM/WAVE 解码的验收必须用系统自带解码器交叉核对：`afconvert -f WAVE -d LEI16 in.wav ref.wav` 后逐样本比。自造样本 + 自洽断言只能证明『按我理解的表算』，证明不了『和别人算的一样』。本轮的立体声布局错误就是这么掉出来的（72 文件全绿的单声道测试完全没报）。当前基线：144 文件 / 8,095,320 样本 / 0 差异。
```

### play_must_be_timed

```
『真的在播』的判据是墙钟下界，不是 play() 返回 true：300ms 素材从 play() 到 isPlaying() 转 false 必须 ≥250ms（实测 394–421ms，其中约 100ms 是 AudioQueue 启动+USB 耳机延迟）。若实现只把指针交给设备就返回，或根本没建队列，这个下界立刻掉下来。另：空缓冲必须显式拒绝，否则『播完了』和『从来没数据』看起来一模一样。
```

### ninja_unsigned_blocks_cmake_regenerate

```
cmake --regenerate-during-build 会 fork `ninja --version`；/usr/local/bin/ninja 是指向 ~/opt/ninja 的**未签名**符号链接 → 子进程卡在 U 状态，configure 永远不返回（表现为『ninja 卡住 3 分钟无输出』，cpu 0%）。处置：codesign -s - --force ~/opt/ninja/ninja（备份在 /tmp/ninja.unsigned.bak）。注意 cmake 自身是已签名的，只有 ninja 需要签。
```

### audio_selftest_entry

```
macOS 音频底座自测 = build-product-mac/concord_apple_audio_output_selftest，参数为任意真实 .wav 路径；`--dump <in> <out.pcm>` 用于与 afconvert 交叉核对。跑之前必须先 codesign -s - --force（未签名二进制在本机会卡在 U 状态）。
```

### audio_alias_is_process_global

```
2026-11-10 P4-01b：MCI 的 alias 是**进程级命名**的，所以两个设备实例其实共用同一个槽。macOS 侧必须把槽位表做成进程级静态共享 + lease（被顶掉的旧实例不许关新会话），而不是每个实例各持一路输出流——后者会让'第二个实例 open 同一个通道'变成两路同时出声，那是 Windows 永远不会有的行为。AsyncSoundDevice 更极端：PlaySound 是进程级单路，只有 1 个槽、无租约、任何实例析构都不许停别人。
```

### cmake_source_list_split

```
2026-11-10 P4-01b：把 P4-01a 的 core 源与 P4-01b 的 device 源合成一个 CMake 变量，会让 output 自测连带需要 device TU 的 vtable 与 makeUnsupportedXxx 桩，链接期冒出一串未定义符号。cmake 不会为此报警——'一个目标编了它不该编的文件'只在链接期显形。源清单按'自测该覆盖的层'拆开。
```

### signed_python3_wrapper

```
2026-11-10 P4-01b 复现：本机默认 python3（~/.workbuddy/binaries/python/...）未签名，spawn 后停在 U 状态且 kill -9 无效。后果不是报错而是**静默挂死**：scripts/verify-win32-compat.sh 第 1 层用 python3 算声明数，日志停在『1/14』五分钟毫无输出。绕过：/tmp/signedbin/python3（签过的实体二进制 + DYLD_LIBRARY_PATH 指向 lib）。跑共享验证脚本前必须把脚本里的 python3 换成它，否则会误判为'脚本很慢'。
```

### link_gap_zero_is_not_feature_done

```
2026-11-10 P4-01b：缺口 0 只说明 ld 不再抱怨。本项目在缺口 0 的同一时刻仍有三件未验证：① 产品从未运行（菜单音效可播无第一手证据）；② XAudio2Create 是 E_NOTIMPL（多路语音不出声）；③ 无 Windows 听感基线。判据必须落在效果上，不落在符号表上。
```

### audio_single_slot_tables_must_be_per_family

```
2026-11-10 P4-01c 实测：槽位表原先只按容量做模板参数（table<1>()），于是 AsyncSound / MainMenuMusic / SkirmishMusic 三族拿到同一个静态实例、同一个 slot 0——播一声菜单音效就把菜单音乐顶掉，音乐此后永久消失。Windows 侧这三族是彼此独立的 MCI 设备，共用槽位是纯偏离。修法：族用空 tag 类型做模板参数（SlotTable<Family,N>），让类型系统保证不撞车。判据不能是"音效播完前音乐仍在播"：那 300ms 的音效自己还在播，isPlaying() 问的是共享槽，答案照样是"在播"（本轮第一次写就假绿）——等待时间必须超过被顶掉素材的时长。
```

### wm_timer_never_delivered

```
2026-11-10 P4-01c 实测：产品进菜单后 WM_TIMER 一次都不投递。主循环是阻塞 GetMessageW，SetTimer(window,1,16) 注册的定时器从不触发，于是菜单动画 / updateDynamicState / ensureMusicPlaying / EOF 重启全部静止。识别方法（三种，互相独立）：① 把观测点放进任何"每秒该被调用一次"的函数，一条都不打印；② 采样 ps 的 TIME，11 秒只用 0.66s CPU = 阻塞而非跑帧；③ 只有"进循环前直接调用"的那一次动作生效。看到"程序活着但什么都不动"时先查这条，不要先怀疑业务逻辑。
```

### product_asset_root_is_cwd

```
2026-11-10 P4-01c：RuntimeConfig 的 RedAlert2 / local_data 两个根都按**工作目录**解析，所以必须 cd 到 ConcordRTS-GameData 再启动（那里才有 local_data/runtime_config.ini 与 mix_exports）。从 /tmp 启动的表现是 "palette resource not found: shell.pal" + "original shell assets are incomplete"，看起来像素材缺失，其实是 cwd 错。不要为此改配置或写死路径。
```

### audio_trace_is_env_gated

```
2026-11-10 P4-01c：产品路径的音频取证开关 = CONCORD_AUDIO_TRACE=1。devices 层打 open/play/stop（带路径、帧数、采样率、声道），output 层每秒打 consumed/playedSec/wallMs。默认零开销零输出（实测不设变量时 [audio] 行数 0，stdout 不变）。之所以观测线程必须由输出流自己持有：菜单的定时器是死的（见 wm_timer_never_delivered），任何依赖产品回调的采样点都不会被调用。对账判据：playedSec 与 wallMs 同步增长且比值≈1（本轮 10.03/10.07 = 0.996）。
```

### commit_milestone_exception

```
提交锚点有两个维度，不止族边界：(1) 里程碑例外——子步(ID 带字母后缀，如 P4-01b)达成可复算的量化效果(链接缺口归零/产品首次运行/首次出声/族符号清零)即独立提交，不必等整族收口；仅'编译通过'不算里程碑。(2) 族收口——族内全部任务 done/superseded。反向澄清：链接已通过且效果可复算的不属于半成品，走里程碑例外。已按(a)提交的内容在(b)收口时不重复提交。2026-11-10 P4-01a/b/c 教训：三轮扛了全项目最大三个里程碑却因 P4-02 pending 一直未提交，最贵的东西暴露在工作树里最久。已破例提交 c301d95。
```

### limiter_scales_the_sum_not_a_voice

```
主声部效果器（peak limiter）乘的是**混音后的和**，不是单条 voice。两条 0.8 叠加的期望值是 0.999/1.6×1.6 = 0.999 → 32735，不是 0.8×0.6244 = 0.4995 → 16368。第一版断言按后者写，50/52 通过、两条红——红的是期望值而不是实现。判据要落在"效果链被调用"这句上：调用了就是 32735，没调用就是硬削 32767，差 32 个 LSB。
```

### audio_queue_stop_needs_a_flag_before_the_lock

```
AudioQueueStop(synchronous) 会等回调返回；回调在等混音锁；若停设备的一方正持着混音锁 → 死锁。正确顺序：先置 stopping_ 原子位（回调看到就立刻 return，不拿锁、不入队），**不持锁**停队列并 dispose，最后才拿锁摘声部。反过来写在本机表现是"退出时整个进程卡住"，没有任何报错。
```

### samples_played_is_source_frames

```
XAUDIO2_VOICE_STATE::SamplesPlayed 是**源采样帧数**，不是输出帧数：22050 素材播 1 秒，输出 48000 帧而 SamplesPlayed 只涨 22050。用它做"播了多久"的对账必须除以**源**采样率，用主声部 48k 去除会差 2.18 倍。另外 XAUDIO2_VOICE_NOSAMPLESPLAYED 时不要把它填 0（那等于"一个都没播"），应当不更新。
```

### compat_selftest_source_list_is_shared

```
compat 的 12 个自测目标编译**同一份** CONCORD_APPLE_WIN32_COMPAT_SOURCES，框架清单也在同一个 set 里。把 XAudio2 引擎放进 compat 源清单（而不是 src/audio/apple）的收益就在这里：零个 add_executable 要改，只加一行 AudioToolbox 就全网生效。代价是每个 compat 自测都多编一个 ~1200 行的 TU。
```

### art_theater_naming

```
{
 "finding": "RA2 建筑的剧场美术不是加后缀，而是换基名第 2 个字符：GAPOWR.SHP(16416B, snow.mix) / GGPOWR.SHP(16416B, generic.mix)，同尺寸不同 md5。对 GAPOWR 枚举全部 36 个字符，数据里只存在 A(雪地) 与 G(通用/温带默认) 两种。",
 "impact": "MapPreviewExporter::newTheaterCharForExtension 把 .tem→'t'、.sno→'a'，会去找 GTPOWR.SHP —— 数据里不存在；温带默认图实际是 GG*。窗口渲染接美术时必须按 'G' 兜底，否则温带建筑全部命中不了。",
 "verify": "python3 用 westwood_id 枚举 + --list-mix 逐归档比对；md5 与 --inspect-asset 双证"
}
```

### wm_timer_was_never_registered

```
S11 定位：问题不是"入库了但取消息不看定时器"，而是 **SetTimer 本身就是空桩**（return TRUE，什么都不记）。所以任何只改 GetMessageW 的修法都无效。P4-01c 的三条识别法（观测点不打印 / CPU 停在 6% / 只有进循环前那次生效）全部指向"没有消息源"，但真正的原因是登记表不存在。
```

### synthesized_messages_are_not_queued

```
WM_TIMER 与 WM_PAINT 都是**取消息时合成**的，不进队列：入队会让它们压在真实输入前面并攒一堆；而且 PM_NOREMOVE 必须看不见它们（合成消息没有队列位置），否则 `while(PeekMessage(PM_NOREMOVE))` 变成死循环。
```

### range_filter_zero_zero_means_no_filter

```
GetMessage/PeekMessage 的 wMsgFilterMin=wMsgFilterMax=0 表示**不过滤**，产品的取消息调用正是 (0,0)。把合成消息的判定写成 `min<=msg && msg<=max` 会让 0..0 把 WM_TIMER/WM_PAINT 全挡在门外，症状是 GetMessageW 永久阻塞、一行日志都没有——第一版就是踩了这个（自测直接挂死）。
```

### blocking_getmessage_cannot_test_absence

```
"应当没有消息"这类断言**不能**用 GetMessageW 驱动：它按定义会阻塞到有消息为止，于是判据本身变成死锁。用 PeekMessage 轮询固定时长。本轮自测第一版在 KillTimer 之后永久挂住、零输出。
```

### timer_table_is_process_wide

```
定时器表是进程级静态（与本层 messageQueue 一致），不是 Win32 的每线程队列。产品只有一条 UI 线程所以成立；若将来出现第二条 UI 线程，SetTimer 必须改成 thread_local，否则 A 线程的定时器会派发到 B 线程的循环里。
```

### idle_menu_cpu_is_a_probe

```
S11 前后同一产品跑 12s：CPU 0.66s/11s(6%) → 1.17s/12s(9.8%)，"每秒该被调用一次"的 main-menu-music probe 从 0 条变 11 条。空闲 CPU 与周期日志是最便宜的两个"定时器到底有没有在跑"的判据——比看屏幕可靠，因为 S7 的窗口是纯离屏的，屏幕上本来就什么都看不见。
```

### theater_char_differs_between_structures_and_overlays

```
同一批 RA2 素材里并存两套剧场字符约定，同一函数服务两边必错一边：**建筑**温带在 art/base/gg*.shp（28 个）→ 温带字符是 'G'；**地表 overlay** 温带在 art/temperat/gt*.shp（gtsand/gtwall/ntwall）→ 温带字符是 'T'。证据可复算：ls art/base/gg* 28 个、ls art/snow/ga* 65 个、gt*powr 在全部归档里 0 个。
```

### fallback_candidates_mask_a_wrong_first_candidate

```
候选列表里的兜底项会让"第一个候选名写错"变成完全不可见的缺陷：Q-02 里旧映射把每个温带建筑的首选名写成不存在的 gt*/nt*/yt*（362/769），但后面跟着 'g' 兜底，于是 Missing SHP 一直是 0、所有"是否缺图"的统计都绿。要发现这类错，必须统计**首个候选的命中率**，而不是最终命中率。
```

### map_preview_coverage_needs_complete_tiles

```
map-preview 的结构精灵覆盖统计不是独立入口：它挂在 --export-map-tmp-html 里，而那条路径先要求瓦片齐全（本机抽取缺 194 个瓦片 → 直接中止）。而 --map-object-art-report 不加载 theater，所以它根本不触发替代候选生成（改动前后都 Missing 0，不能拿它当验证）。这类"统计挂在别的功能后面"的验证点要先确认入口可达。
```

### edit_race_sweeps_into_peer_commit

```
共享文件上的 Edit 是整文件读-改-写：对端若在你读完之后提交了整份文件，你的一次小改会把你的行卷进对方 commit，而对方 commit 的正文不会提这件事。本轮实证：#include "data/art/TheaterResourceLetters.h" 被 1dc77df 一并提交，该头并不在树里 → HEAD 构建断裂。后果是'别人的提交里有一个你造成的洞'，排查时极难归因。判据：开工前记目标文件 mtime；若动手时 mtime 已变，先 git log -1 --stat 看是否刚提交过。
```

### clean_worktree_is_not_proof_of_no_peer

```
git status 干净只证明'这一刻没有未提交改动'，不证明'没有别的实例在干活'：对端在自己 turn 内改完-编译-提交，中间任何一次采样都可能落在干净窗口。本轮实证：00:06 工作树干净，00:14 同一文件已出现完整 Q-02 实现+新提交。
```

### git_add_stages_whole_file

```
并发时 `git add <file>` 提交的是**整个文件**，会把别人往同一文件里写的行一起带走。1dc77df 就把对端一条 `#include "data/art/TheaterResourceLetters.h"`（该头从未入树）带进了提交，那一提交单独检出会构建断裂，靠对端 fd9c88c 修掉。**铁律：提交前逐 hunk 复核 `git diff`**——"我只 add 了我的文件"不等于"我只提交了我的行"。
```

### wchar_t_width_divergence_is_the_t03_point

```
本机 wchar_t=4 字节、POSIX 的 std::filesystem::path 是 char 原生，所以：4 字节 UTF-8 只产出 **1 个** wchar_t（Windows 是 2 个 UTF-16 码元）；`path.wstring()` 对 "/tmp/中文/😀.wav" 得到 **13** 个码点，不是 15 个 UTF-16 码元。任何"wstring.size() == UTF-16 长度"的假设在 mac 上都错，而它不会报错、只会让长度断言/哈希/截断判据静默偏移。
```

### manual_round_must_take_the_lock

```
人工接续轮（用户说"继续"）也必须先占锁：读 `.active`=released 之后**立刻写 held**，再读任务定义。本轮撞车就是跳过这一步——00:06:30 读到 released，00:06:58 对端 claim 同一个 Q-02，双方各改一次同一文件。
```

### theater_letter_is_per_family_not_per_position

```
**温带字符取决于建筑家族，不取决于文件名落在哪个目录**：玩家建筑（G/N/Y 前缀）在温带用通用图 `ggtech.shp`（art/base），民用建筑（C 前缀）在温带用剧场图 `cthosp.shp`（art/temperat）。769 个 NewTheater 段的交叉统计：两者都有 23 / 只有 g 120 / 只有 t 213 / 都没有 413。所以唯一正确的序列是 **[剧场字母, 通用 'G', 字面名]**——先试本剧场，再退通用，最后退回 ART 里写死的名字。任何"只在两个字母里选一个"的实现都会让其中一族画错图。
```

### first_candidate_hit_rate_needs_an_unfiltered_denominator

```
Q-02 我报的"362/769 首候选不存在"是**在能解析的段里**统计的，而且把"先试剧场字母再试通用图"这个正确设计里的第一次尝试当成了缺陷。全量不筛的真实数字：旧规则 `[t,g]` 首候选命中 **242**（temperat 202 / base 40），`[g]` 只有 **149**（base 143 / temperat 6）。教训：分母必须是全量，且"首候选落空"本身不是缺陷——要看**落空之后的那一步退到哪里**。这条是对 rules.fallback_candidates_mask_a_wrong_first_candidate 的更正：兜底不是掩盖错误，而是这条命名约定本来就需要两步。
```

### temperate_letter_is_T_not_G

```
温带的**剧场字母**是 'T'（art/temperat/ct* 203 个；cthosp/ctoild/ctairp 都存在），'G' 只是**通用兜底**（art/base/gg*）。实证：cghosp/cgoild/cgairp 在任何目录都不存在。所以候选序列必须是 [剧场字母, 通用 G, 字面名]；把温带字母写成 'G' 会让民用建筑（C 类，只有 CT 没有 CG）静默回落到 art/snow/ca*——温带地图整片画成雪地图。1dc77df 就是这么错的，Q-04 正在改回。
```

### first_candidate_metric_must_split_by_category

```
统计'首个候选是否命中'必须按首字母分组（C/G/N/Y）：G 类建筑的温带图确实只有 GG（gt* 从未出图），所以 G 类靠兜底命中是正常的；C 类有 CT 却没有 CG，靠兜底命中就是错的。把两类混成一个百分比，会得到'温带=G'这种看着对、实际错杀 234 条 ct* 的结论。
```

### no_real_window_yet

```
macOS 侧没有真窗口：ShowWindow 只翻 CompatWindow::visible，UpdateWindow 只派发 WM_PAINT，全仓库唯一的 NSWindow 出现处是两行注释。产品能跑、有声音、画面完整（可用 CONCORD_MENU_DUMP=<bmp> 导出客户区帧自证），但屏幕上永远什么都没有。在 Q-05（Cocoa 呈现层）落地前，任何画面问题的排查都必须先看导出帧，而不是看屏幕。
```

### menu_frame_dump_hook

```
诊断入口：CONCORD_MENU_DUMP=/tmp/frame.bmp [CONCORD_MENU_DUMP_FRAME=6] 启动产品，EndPaint 后把客户区位图写成 24bpp BMP（未设变量时零开销）。这是当前唯一能看见到底画了什么的手段，也是将来 Cocoa 贴图的取像素路径。
```

### pointer_nav_selftest_registers_its_own_class

```
自测里建父窗口不要用 L"STATIC"：compat 的 CreateWindowExW 在 2026-11-11 01:50 前没有预定义窗口类表，返回 nullptr，现象是 require 报「父窗口建不出来」，看起来像导航实现坏了。用 RegisterClassExW 自注册一个类，成败就只取决于本自测自己。
```

### wait_for_state_not_for_a_fixed_delay

```
投递/发送窗口消息后必须「等到状态变化」（有界轮询 predicate），不能等固定时长：第一版 pump(60) 就断言 page 已改变，5 条断言里有 4 条是这种假失败。另一条同源：SetWindowPos 的 WM_SIZE 是**排队**投递的，紧接着读 viewLeft/viewTop 还是建窗时的旧值 0,0；用旧偏置算出的点击坐标在新偏置下整体偏 112 像素、落到 sidebar 之外，表现成「按下有态、抬起无反应」。
```

### stock_window_classes_were_missing

```
`--main-menu-ui-smoke-test` 在本机失败的根因不是导航：compat 的 CreateWindowExW 不认识 STATIC/BUTTON/EDIT/LISTBOX/COMBOBOX/SCROLLBAR/MDICLIENT 这些**预定义**类，产品建宿主子窗口直接拿到 nullptr，报出来是「hosted child page did not preserve its top-level shell」+ credits=0/1/0。修复方式（另一实例 2026-11-11 01:50 已在 RuntimeWin32CompatUser.cpp 落地，未提交）：局部填 DefWindowProcW，**不写进 classTable**，否则产品之后 RegisterClassExW(L"STATIC") 会撞「类已存在」。
```

### mix_has_no_filenames

```
MIX 档案不存文件名，索引表只有 CRC32 id。任何“MIX 里有没有 X”的判断必须用 MixArchive::findEntryByName / mixFileIdFromName 算 id 去查，strings / grep 永远找不到。2026-11-11 Q-09 踩过：先用 strings 判定“creditsmd.txt 不存在”，实际它在 RA2/langmd.mix 里（16180 字节）。
```

### presentation_single_window

```
本层只有一个 NSWindow，所以呈现必须"唯一化"：第一个画完的窗口成为可见窗口，之后只有严格更大的窗口才接管，小控件（EDIT/STATIC）一律拒绝。反之会让 10×10 的输入框把整屏顶掉（2026-11-11 Q-12 实测）。窗口尺寸跟随"上次呈现的尺寸"，不跟随"窗口当前尺寸"——后者会把用户手动缩放掰回去。
```

### handle_table_outlives_process

```
compat 的句柄表（handleMutex/handleTable）故意永不析构：它会被产品的**静态对象**在析构期访问（如 prewarmedMenuState 析构里调 FindCloseChangeNotification），静态析构顺序不确定会导致"mutex lock failed: Invalid argument" → SIGABRT，而所有断言都过、只在收尾崩。Windows 的 HANDLE 表本来就活到进程结束，所以这是正确语义。2026-11-11 S12 踩过一次。
```

### fsevents_nested_framework

```
FSEvents 是嵌套框架（CoreServices.framework/Frameworks/FSEvents.framework）：不能 include CoreServices 伞头（会拉进 CarbonCore/Threads.h，GetCurrentThread 与本层冲突）；必须 <FSEvents/FSEvents.h> + 按**文件属性**加 -F（按目标加会漏掉同源清单的其他目标）；且 CMAKE_OSX_SYSROOT 在用默认 SDK 时是空串，要用 xcrun --show-sdk-path。
```

### modal_loop_bounded_wait

```
产品里"模态菜单循环"不能用 GetMessageW 做主循环：窗口可能在一次派发里被销毁，之后队列再不来消息，GetMessageW 会无限阻塞，while(IsWindow) 的退出条件永远没机会重判。用 PeekMessage + MsgWaitForMultipleObjectsEx(5ms) 有界等待。2026-11-11 S13 实测：遭遇战 preload 的 4 次进出就是卡死在这里（采样栈落在 GetMessageW）。
```

### presentation_owner_area

```
compat 的可见窗口规则要记住"历史面积"（gPresentedArea），不能只比当前 owner：owner 句柄一失效就查不到尺寸，会无门槛接受任意窗口——实测 800x600 壳销毁后 10x10 的 EDIT 把整屏 resize 成 10x10。当前规则：owner 在→严格更大者接管；owner 已销毁→门槛为历史面积的一半。
```

### diagnostic_must_curate_the_probe_list

```
诊断输出不能直接倒探测序列：兄弟枚举会一路枚举到 home（本机 179 条候选），逐条打印等于刷屏。只列「锚点（self 三条）+ near-miss（有 local_data 没 RedAlert2 或反之）」，不足 8 条按原顺序补齐，索引保留真实位置，全量走 TRACE 环境变量。判据：默认输出 ≤16 行，且 near-miss 一条不漏。
```

### source_root_is_never_the_data_root

```
选取最近候选要按 stageRank 平票破局：环境变量(4) > 兄弟(3) > 祖先(2) > 自身(1)。源码树里常有一个自污染留下的空 local_data（resolveRuntimePath 的 cwd 优先语义 + 进程写 runtime_map_cache 造成），于是源码根与真数据根同为「有 local_data、缺 RedAlert2」。按序列顺序取第一条会把源码树报成答案（本轮实测踩到），必须让 sibling 赢。
```

### pkill_f_kills_the_calling_shell

```
pkill -f <pattern> 会匹配到**自己这条命令行**：命令串里含同一个路径时，pkill 把发起它的 zsh 一起 SIGTERM 掉，表现为「命令无输出、Exit Code 空、Signal SIGTERM」，且后续进程采样看起来像『应用自己退出了』（本轮据此误判过一次）。查/杀本机进程一律用 pkill -x concord_runtime / pgrep -x <进程名>，不要用 -f 加路径。
```

### iconutil_needs_real_extensions

```
生成 .icns 有两处扩展名硬约束，都不给有用的报错：① iconset **目录**必须以 .iconset 结尾且不能是隐藏名——用 `".iconset"` 会被当成『没有扩展名』，报 Invalid arguments, --output argument. The file extension must equal icns；② `iconutil -o` 的输出文件扩展名必须真的是 .icns，写 `.icns.tmp` 同样被拒。正确做法：iconset 用 concord-icon.iconset，输出先落 <build>/ConcordRTS.icns 再 mv 进 Resources。
```

### app_bundle_screen_is_black_but_dib_has_content

```
2026-11-11 05:10 实测：screencapture 抓到游戏窗口为纯黑矩形（同机 WorkBuddy 窗口内容正常，排除录屏权限），而同一进程 CONCORD_MENU_DUMP 导出的 1024x640 DIB 帧完整（美术+中文按钮+侧栏）。即 GDI 渲染与帧导出都对，断点在 present() → layer.contents → 合成。判据要用『回读 layer 像素 hash 与同帧 BMP 对账』（ON-3-01），不要用『进程没崩 + 日志有 first frame attached』当上屏证据——那两句在纯黑窗口下同样会打印。
```

### peer_swept_worktree_into_family_commit

```
2026-11-11 05:07:45 事故：本轮 ON-1-03 正在收尾（工作树 8 文件未提交）时，另一实例按族收口直接 `git add` 并提交了 5b1eb50，把我的在制品一并入库，同时把 ON-1-03 标 done、queue 升 v59，但没写 RUNLOG；我持有的 .active 未挡住它。两个后果必须检查：① 被 *.gitignore 规则吞掉的文件（本轮 packaging/icon-source.png 被 *.png 吞）不会进那个提交，clone 后打出的 bundle 无图标；② 缺 RUNLOG 等于该轮无记录。处置模式：先 git log/find 校验『提交是否含有我全部改动 + 是否有被忽略文件漏网』，再补提交 + 补 RUNLOG，不要重做工作。
```

### external_input_policy

```
等待外部输入的任务绝不用 in_progress。三种情形与对应标记：① 交付物已经产出、只等第三方执行/回报（人眼验收、真人点击、需要授权屏幕录制）→ 标 done，把『结论待回报』写进 note；回报后若发现偏差，另立一条新任务挂到同族末尾，不要回滚原任务状态。② 任务本体无法继续、必须等人提供东西（Windows 机器、完整资产包、账号授权）→ 标 blocked 并写 blockedReason，注明等什么、拿到之后第一步做什么。③ 任务还在自己做、下一轮会接着做 → 才标 in_progress，且必须在 RUNLOG 写清『卡在哪一步、下一轮从哪继续』。为什么这条重要：自动化的熔断规则是『存在任何 in_progress 即本轮只诊断不改码』，所以一个等外部输入的 in_progress 会让整队每小时空转一次，而且看起来像『没有任务在跑』。2026-11-11 的 ON-3-03 踩过这个坑。
```

### mark_status_within_round

```
本轮结束前必须让 queue.json 里 in_progress 的数量回到 0（全部落到 done / blocked / partial 对应态），除非确实是『下一轮接着做』且 RUNLOG 已写明续点。
```

### cgimage_cache_freezes_screen

```
呈现层**不能**缓存 CGImage：CompatWindow 的 DIB 是同一块内存、GDI 每帧覆盖写，而复用的 CGImage 被上传一次后 CA 不再重读它。2026-11-11 ON-2-01 决定性实验（/tmp/pc/probe3.mm，每阶段自抓窗口图）：每帧新建 → 红/绿/蓝/黄四帧四色；两个对象轮挂 → 四帧全红且 PNG 字节数完全相同；单对象 → 同样全红。**交替挂两个对象救不了**，去重不是按 contents 指针。判据必须落在屏幕像素上：DIB 每帧都在变，任何 DIB 级断言都看不出这个冻结。
```

### cgimagecreate_cost_is_microseconds

```
CGImageCreate 不是瓶颈：provider 是 no-copy，图像对象不分配像素缓冲。1024x640 实测（/tmp/pc/bench.mm，20000 次）：provider+image 每帧新建 1.3µs/帧；只缓存 provider 0.7µs/帧；全缓存 0µs 但会冻结。60fps 下能省的上限是 0.04ms/s。凡是以"每秒上百 MB 分配"为理由优化呈现路径的，先按这个基准复算。
```

### present_rate_is_degenerate_today

```
当前产品的提交频率接近 0：主菜单挂机 20s 内 present < 10 次（只在交互时重绘）；--skip-main-menu --skip-skirmish-menu 进世界 45s 只有 **2** 次（首帧 + resize 后那帧），因为游戏内帧循环还没做（ON-4-03）。所以"每帧开销"类优化现在没有可测收益，要做就先做帧循环，再看 ON-2-02 的提交合并。
```

### window_capture_by_window_number

```
窗口级取证可行：`screencapture -x -o -l <NSWindow.windowNumber> out.png` 对自建窗口全部成功（18KB、内容正确），不需要屏幕录制授权。抓图前必须自己 activateIgnoringOtherApps + makeKeyAndOrderFront，否则抓到的是上一张合成快照（被遮挡窗口不更新合成）——这正是"屏幕冻住"与"窗口被挡住"无法区分的原因。产品窗口（windowNumber=1836）试过一次could not create image from window，差异未查清，ON-3-01 开工先复测。
```

### doc_repo

```
项目管理文档自 2026-11-11 起在独立仓库 /Users/zhenglk/ai-project/ra2mac/ra2mac_docs（main 分支）做版本管理：reports/ 放各轮报告，progress/ 放 queue.json、RUNLOG.md 与取证截图，report/ baseline/ scripts/ 原样收纳。项目根目录的 progress 是指向 ra2mac_docs/progress 的**软链**，所以所有写死的 progress/... 路径不变，**不要**把软链换成真目录。每轮收尾必须在该仓库提交一次（即使本轮不是 done），文案 `docs:` / `queue:`，绝不 push。新报告写入 ra2mac_docs/reports/，不要再写项目根。 远程：origin = https://github.com/kunsir6/ra2mac_docs（**public**，2026-11-11 关联并已推送 main，默认分支 main）。自动化**只在本地提交、绝不 push**；本地会领先 origin，推送由人执行。
```

### present_is_per_paint_not_per_endpaint

```
2026-11-11 06:44：ON-2-02 的文本假设「每个 EndPaint 都直接 present，同一帧可能被贴多次」。实测架构不是这样：present() 全仓只有一个调用点（RuntimeWin32CompatUser.cpp:999，位于 WM_PAINT 的绘制路径），而失效层已有合并——InvalidateRect 只置 w->dirty，popMessage 合成 WM_PAINT 时逐窗口看 dirty，BeginPaint 清位。所以同一次失效不会被贴两遍；RedrawWindow(RDW_UPDATENOW) / UpdateWindow 是仅有的同步旁路，它们也先看 dirty。要论证「贴了多次」必须给出计数证据（submits vs paints），不能用「每帧都贴」当默认前提。真正的缺口是反方向的：世界 45s 只有 2 次 present，因为没有定时器驱动的失效（见 ON-4-03）。
```

### detail_text_may_already_be_implemented

```
2026-11-11 06:44：ON-4-01 的 detail 与 82af67d(S14a) 的改动逐字相同——任务文本在继承/搬运过程中可能与更早的提交重复（S14 的修复被拆进 ON-4-01 时没有回看提交）。开工前先按 verify 的失败点定位到具体断言，再决定要不要动 detail 描述的那个函数；否则会把已存在的实现重写一遍，或误判成「没做」。判据示例：git show HEAD:<file> | grep <关键调用>，比读报告快且不会被 stale 描述骗。
```

### bi_rgb_stamp_must_preserve_dst_alpha

```
32bpp BI_RGB 的高 8 位不参与 GDI 语义：compat 所有像素写入经 PixelSink::fillSpan -> applyRop2，只替换 RGB 24 位、保留目标原有高 8 位（DSTINVERT 同理）。任何绕过 PixelSink 直接写 DIB 的 CPU 快路径都必须复刻 (dst & 0xFF000000) | (color & 0x00FFFFFF)。S14b 实测症状：两处 stamp 来自每帧清零的 scratch DIB、整 32 位赋值，契约报 ref=0x9269e6be / optimized=0x0069e6be（RGB 相同、只有 alpha 不同），与包围盒/裁剪/当前位置全无关系。supported() 已限定 R2_COPYPEN，故等价于 applyRop2 的复制分支。
```

### contract_background_high_byte_is_load_bearing

```
像素契约里 reset() 的背景填充不是随便选的：RuntimeSelectedPathRasterContract.inl 的 0x91293874U ^ (index * 13397U) 让高 8 位非零且逐像素变化，是唯一能观测「快路径抹掉目标 alpha」的判据；RuntimeSelectionFrameRasterContract.inl 用随机 32 位种子同理。把它们简化成 0 / 纯黑 / 纯 RGB，测试会全绿而缺陷依旧。改测试背景前先问它挡的是哪条语义。
```

### smoke_is_a_chain_of_contracts

```
--interaction-smoke-test 是一串串行契约，修完一条必然暴露下一条（本轮：selected path raster → selection frame raster → projection history）。因此单条任务的 verify 必须绑定到「自己那条断言的输出」，EXIT=0 这种整链终点要单独挂任务，否则永远无法归因、也无法诚实标 done。2026-11-11 据此把 S14b 的 verify 收窄为两条 raster 契约输出，把总目标转 ON-4-05，并把重复条目 ON-4-01 标 superseded。这是修正被事实推翻的验收假设，不是放宽标准。
```

### lock_respect_diagnose_round

```
2026-11-11 06:33 人工轮写 .active=held 后，06:45 自动化轮检测到持锁，自动转 diagnose-only：未取锁、未碰源码、只写文档（queue v67 加注 + 报告），并独立复算出 ON-4-01 的实现已在 82af67d。判据沿用 rules.lock：pid 会消失不可作证，看 .active state 与源码 mtime。人工接续轮同样必须先写 held 再读任务定义（rules.manual_round_must_take_the_lock）。
```

### existing_smokes_are_offscreen

```
2026-11-11 ON-3-01 实测：--main-menu-ui-smoke-test / --skirmish-ui-smoke-test / --interaction-smoke-test 三条 smoke **全部只画到 DIB**，日志里没有 [cocoa] NSWindow created，present() 一次都不被调用（runRuntimeMainMenuSmokeTest 的注释也写了 without creating a window）。凡是要证明「屏幕上」的事，先确认 present 被调用；拿离屏 smoke 做上屏取证只会得到 0 条记录。唯一例外是加 CONCORD_MAIN_MENU_POINTER_NAV_ONLY=1 的宿主窗口路径，它会真建 NSWindow。
```

### cgimage_draw_into_bitmap_context_no_flip

```
把 CGImage 画进 CGBitmapContext 时**不要翻转 CTM**：CGImage 的数据第 0 行是图像顶行，DrawImage 到 (0,0,w,h) 时顶行对齐 rect 顶部，而缓冲第 0 行正是顶行，两者本来就对齐。2026-11-11 ON-3-01 实测：不翻转 hash == 同帧 DIB（0x674d476c），翻转后 0x890043ac（整幅颠倒）。别与 rules.cg_bitmap_row_zero_is_top 混淆：那条讲的是按底行**解释**缓冲会得到翻转字形，这条讲的是画进缓冲时不要额外翻转。
```

### attest_exit_must_happen_in_present

```
取证/自证模式要自己退出时，退出点必须在 present 内（写完记录、fflush 之后 _Exit），且退出码要带失败数（_Exit(failures==0?0:1)，否则 match=no 会被掩盖成成功）。两条常规路径都不通：① 世界视图的窗口不是 key window，合成 Cmd+Q 收不到；② 本项目从不跑 [NSApp run]，[NSApp terminate:nil] 只是排队，且在 pumpEvents 里发也无效——世界主循环根本不经过 pumpEvents。用 _Exit 而不是 exit，避免触发退出期静态析构（rules.handle_table_outlives_process）。
```

### takeover_rule_blocked_the_owner

```
2026-11-11 ON-2-02a 实测：maybePresentClientFrame 的抢位规则只有"严格更大者接管"，而当前呈现主人与自己面积相等 → area>gPresentedArea 恒假 → 主人自己的**每一次**后续重绘都被丢弃。表现是屏幕永久停在第 1 帧，而 DIB 正确、attest(默认 LIMIT=1) match=yes、进程不崩、CPU 还在动。判据：CONCORD_PRESENT_STATS=1 时 takeover{self} 必须为 0；任何"只允许更大者接管"的门都得给主人自己开绿灯。
```

### world_paint_path_is_updatewindow

```
呈现路径按场景不同：主菜单 200/200 次 WM_PAINT 来自队列合成（popMessage），世界 887/888 来自 UpdateWindow 同步旁路、队列合成为 0。任何"每帧一次 present"或"每个 EndPaint 都贴"的推断都必须按场景分开量，不能用一个场景代表全部。
```

### present_layer_dedup_is_not_the_cost_centre

```
ON-2-02a：菜单 submits=200 且 redundant=0（present 层无重复可合并）；世界 redundant=881/888 但每帧 CGImage 建造成本只有 1.3µs（ON-2-01 已测），真正的浪费是**空转重绘**（44 次/秒画同一画面），应在帧循环解决（ON-2-06/ON-4-03），不要在 present 层加去重门——那需要全帧 hash（>1ms/帧）才安全，比它省下的还贵。
```

### commit_must_be_verified

```
每次提交后必须跑 git fsck --no-progress 与 git status --short，不能只看 git log。2026-11-11 实证：179c84e 的 commit 对象与 message 都在、git log 读起来正常，只有 compat/ 子树对象没落盘，git status/diff 全部 fatal；而下一轮自动化第一件事就是 git add/diff，不校验就会以"莫名其妙的 fatal"炸开且无法归因到上一轮。
```

### product_full_build_is_broken

```
产品级 `cmake --build build-product-arm`（1823 目标）在 [182/1823] 失败于 concord_mod_history_noop_smoke：RuntimeModExtensionsHistoryNoopSmoke.cpp 调用 advanceRuntimeModExtensions(宿主自造类型)，而唯一声明是 src/runtime/session/detail/RuntimeProductionOperations.h:9631 的 advanceRuntimeModExtensions(RuntimeGameSessionState&)，测试既没 include 该头、类型也不匹配。与架构无关，历史上一直存在——过去所有验证都只编 concord_runtime 主目标，从没触发。因此：判据命令沿用 `cmake --build <dir> --target concord_runtime`；要恢复全量构建见 ARM-02。
```

### lighting_simd_off_on_arm64

```
src/render/lighting/RuntimeLightingLookupRaster.h 用 __SSE2__ 选路，arm64 上该宏未定义 → SSE2/AVX2 全关、走标量，无 NEON 替代。内核哈希不含光照光栅，故金标准哈希不受影响；但该文件的系数是「只在能逐项精确复现 rounded 查找表时才被接受」，若将来把光照纳入像素级判据，必须单独验证标量与 SSE2 逐像素一致。性能影响待 ON-4-04 量化。
```

### delivery_two_thin_binaries

```
交付形态 = 两份 thin 产物，不做 universal（用户 2026-11-11 决策）。arm64: cmake -B build-product-arm -DCONCORD_MACOS_APP_NAME=ConcordRTS-0.1.0-arm64 -DCONCORD_MACOS_BUNDLE_ID=org.concord.rts.arm64 → --target concord_app；x86_64: 同上再加 -DCMAKE_OSX_ARCHITECTURES=x86_64，APP_NAME/BUNDLE_ID 换 x86_64。出口目录 /Users/zhenglk/AiProjects/ra2mac/dist/，文件名=APP_NAME。不入库。【标识必须一起区分】CFBundleName / DisplayName / Identifier / IconFile 四项都随 APP_NAME 走；只改文件名不改 bundle id，会让 LaunchServices 把两个产物当同一个应用。CFBundleIconFile 已由 packaging/Info.plist.in 的 @CONCORD_APP_NAME@ 驱动（原写死 ConcordRTS，改名即丢图标，2026-11-11 已修，源码 3d7267e）。可执行文件名保持 concord_runtime 不变——开发形态路径被十几套 smoke 引用，改它只会打断验证。注意 .app 内的 Contents/Resources/data-root 是**文本指针**（指向 ConcordRTS-GameData 绝对路径），不是数据副本；把 app 发给别人必须同时给数据树或改这个指针。
```

### retina_scale_measurement_trap

```
2026-11-11 实测陷阱：attest 里的 scale 只在**裸二进制**（不在 .app 内）直接执行时可信——arm 裸二进制得到 scale=2.0，而 arm/x86 的 .app 内二进制直接 exec 都得到 scale=1.0。原因是高分辨率由 LaunchServices 启动时决定，直接 exec bundle 内二进制会退回 legacy 1x。故「x86 切片在 Rosetta 下 scale=1.0」不能证明产物有 Retina 缺陷，也不能证明没有——Retina 判据必须在真 Intel 机器上以裸二进制方式复验。
```

### system_fullscreen_needs_nsapp_run

```
系统全屏（进入独立 Space）在「不跑 [NSApp run]」的架构下不可用，已实测确认：willEnter 触发、didEnter 永不到；放宽 pumpEvents 的 run loop 时间无效。因此窗口设为 NSWindowCollectionBehaviorFullScreenNone **显式禁用**——实测 Default 挡不住，全屏照样开始（willEnter 仍触发）而后卡死，比没有该功能更糟。约束：任何"需要 AppKit 生命周期推进"的能力（全屏、Space 切换、系统对话框）都要先假设不可用，并用自测确认，不要按"应该能行"直接依赖。
```

### selftest_must_wait_for_sink

```
2026-11-11 实证：present 里注入的自测必须等 gInputSink 就绪。setInputSink 是在 present **返回之后**才调用的（它要用刚呈现的窗口做 context），所以第一次 present 时 sink 为空，delegate 会走"没人接就放行"的分支。症状极具欺骗性：日志里 close self-test 已经打出来了，窗口也确实关了，但进程继续跑到第 30 帧——看着像"注入成功但链路不通"，实际是自测根本没进被测分支。口径：自测打日志 ≠ 走到被测分支；注入前先断言前置条件（sink/window/attest）。
```

### contents_scale_must_follow_backing

```
gView.layer.contentsScale 不能只在建窗口时从 backingScaleFactor 抓一次。2026-11-11 实测：同一进程里 layer=2.0 而 window.backingScaleFactor=1.0，ON-2-03 的 scale-test 因此报 fail。改为每帧同步（变化时才提交 CATransaction，disableActions）。注意 pass 只说明「layer 跟随 backing」，不说明「Retina 正确」——无人值守运行时 backing 可能为 1.0（见 rules.retina_scale_measurement_trap），Retina 最终验收仍需人工双击 .app。
```

### ground_rubble_excluded_from_scene_z

```
scene-Z depth replay 的参与者在 RuntimeStructureSpriteGeometry.inl:361 就把 runtimeObjectIsGroundRubble 的对象筛掉（`|| runtimeObjectIsGroundRubble(object, context)` → continue）。这是**正确行为**：地面残骸没有立体遮挡体，让它参与 replay 会凭空产生遮挡，挡住本该被看见的像素。所以任何"rubble 也应参与 depth/遮挡"的断言都是错的，要先核对这条筛选。2026-11-11 ON-4-05 就是因为一条断言同时覆盖 rubble=false/true 两种状态而误红。
```

### playable_today

```
2026-11-11 实测：产品**已经可以手动玩**，两条路径都已验证到画面：① `--skip-main-menu` → 遭遇战大厅（1024x640，玩家列表/国家/颜色/队伍/速度/资金/部队数/地图预览全部渲染正确，中文标签正常），attest idx=1 match=yes；② `--skip-main-menu --skip-skirmish-menu` → 加载页（盟军/苏联/尤里标志 + 載入中… 进度条）→ 800x600 世界视图，10s 524 次 present（52fps），三帧 attest 全 match=yes。也就是说「大厅→加载→世界」这条链在代码里是完整的，--skip-skirmish-menu 等价于"替用户点了载入"。未验证的只剩一步：在**真窗口**里手动点大厅的「載入」是否同样进入加载页（自建窗口的 smoke 已证明该点击能发起 closing 并交回结果，见 ON-4-02c）。
```

### world_paint_10s_reference

```
世界视图的帧率基线（2026-11-11 arm64 实测）：10 秒 524 次 present，paints 全部走 update（UpdateWindow 同步旁路，queue=0），52fps。这是"画面在动"的证据，但 ON-2-06 指出其中大量是空转重绘（每 tick 无条件 Invalidate+UpdateWindow），真正的脏区驱动还没做。判断"卡不卡"要用这个数字对比，不要凭感觉。
```

### priority_2026_11_11

```
2026-11-11 按「影响效果 ÷ 修改难度」重排（用户要求先高性价比）。判断依据：① 不改代码就能拿到信息的排最前（ON-4-04 性能基线、ON-5-02 长时存活）；② 直接影响"玩起来爽不爽"的其次（ON-2-06 世界空转重绘，当前 52fps 全量重绘 800x600×4 = 1.9MB/帧）；③ 一条断言就能清的顺手清（ON-4-06 tooltip）；④ 工程健康类（ARM-02 全量构建）在中段；⑤ 跨 TU、依赖未验证前置、或需要架构级改动的全部靠后（ON-4-02d、ON-3-01b、ON-2-02b、ON-2-04b）。blocked 一律排末尾，不参与优先级。口径：性价比 = 对"能玩/好玩"的贡献 ÷ 改动风险；不要因为"看起来该做"就提前。
```

### priority_2026_11_11_revised

```
2026-11-11 晚间修正：ON-2-06（空转重绘）从第 3 位下调到 ON-5-01 之前。原因是实测后确认它「不做也不影响玩」——已 59.9fps、CPU 16.5%，修法却要动模拟层 changed 语义（共享代码、影响 Windows、本机无法回归）。教训：性价比排序必须**在摸清修法之后**再定，而不是只看现象严重程度。现象（52fps 全量重绘）看起来最像大头，实际它是"能玩"之后的优化项。
```

### full_build_is_green_now

```
2026-11-11 起：`cmake --build build-product-arm`（全量）是绿的，可以重新作为验收项。旧规则「产品全量构建从来没绿过」作废。注意仍要用 `-- -k 0` 才能一次看到全部失败点，默认在第一个 FAILED 就停。
```

### nested_cmake_runs_before_platformapple

```
DevelopmentTargets.cmake（CMakeLists 第 30 行）早于 CompilerAndPlatform.cmake（第 32 行），所以 tests/infrastructure/*/CMakeLists.txt 这类 add_subdirectory 里不能调用 concord_apple_add_win32_compat_sources，也读不到 CONCORD_APPLE_FSEVENTS_FRAMEWORK_DIR —— 函数与变量那时都还不存在，if(COMMAND)/if(DEFINED) 会静默跳过，症状是「某些自测链接报一堆 FSEvent 未定义」。两条出路：① 在 CompilerAndPlatform.cmake 的 APPLE 分支里补挂（既有先例：concord_multiplayer_two_process_smoke、concord_window_parent_win32_contract）；② 嵌套目录里写成自包含（xcrun --show-sdk-path + 目标级 -F），不依赖 include 顺序。另：set_source_files_properties 是目录作用域，父目录设了不管用。
```

### ctest_fixture_must_be_idempotent

```
契约若拒绝已存在的 fixture 根（如菜单资源契约的 Use a new fixture directory），add_test 必须自带清理，否则同一 build 目录第二次跑必然 0.00s 失败而第一次是绿的——极具欺骗性（看着像「刚改坏了」）。做法：FIXTURES_SETUP 挂 `${CMAKE_COMMAND} -E rm -rf <dir>`，被依赖测试加 FIXTURES_REQUIRED；ctest -R 会自动带上 setup。
```

### win32_requires_directory_for_change_notification

```
Win32 的 FindFirstChangeNotification 要求入参是目录，传普通文件返回 INVALID_HANDLE_VALUE。compat 层早期只查存在性，FSEvents 会照单全收一个文件并「正常」watch，调用方于是得到「这棵树是新鲜的」这种错误认证（菜单资源契约恒红）。已在 RuntimeWin32CompatChangeNotify.cpp 用 stat + S_ISDIR 对齐；任何「照收下再说」的 compat 实现都要先核对 Win32 的参数前置条件。
```

### any_wait_loop_must_pump_appkit

```
macOS 上「拿不到输入 / 彩虹圈」的判定链（已两次踩同一族问题）：① GetMessageW 内置 pumpEvents；② MsgWaitForMultipleObjectsEx / WaitMessage 自 U-01（a863d9e）起内置；③ PeekMessageW 自 U-02（e142ccb）起在队列为空时内置（4ms 节流）。所以现在只要循环里调了这三个原语中的任意一个就会排空 AppKit。反过来：**只睡不取消息**的循环（裸 sleep_for / std::this_thread::sleep_for 轮询、或纯计时等待）一定拿不到输入，且画面会停在第一帧、看着完全正常。见到彩虹圈先 sample 主线程：落在 nanosleep 且栈里没有 pumpEvents 就是这一类，不要去查渲染、死锁或资产加载。
```

### autostart_regression_entry

```
【2026-11-11 已移除】曾有 CONCORD_SKIRMISH_AUTOSTART=<n>：真实窗口大厅里自动点「開始遊戲」，用于无人值守回归"大厅→加载→世界"。按用户要求清理调试脚手架，该钩子已从 RuntimeSkirmishMenu.cpp 删除（产品代码恢复原样）。代价：这条链路现在只能人工验证（双击 .app → 点开始）。若将来要恢复自动化，正确做法是放在独立 diagnostics .inl 里并只在 smoke 入口调用，不要塞回产品主循环。
```

### input_target_must_follow_presented_window

```
compat 的输入目标（setInputSink 的 context）必须跟随**当前呈现窗口**，不能只绑第一次。U-03 实测：主菜单→大厅→加载→世界每跳都换 HWND，只绑第一次会让 present 正常（画面对）而输入全部 PostMessageW 到已退场窗口被丢弃——不报错、日志无异常，表现为"画面在动但点哪儿都没反应"。现在每次 present 比对 toHwnd(w)，变化即重绑并打 [cocoa] input target -> %p。
```

### hwnd_direct_smoke_cannot_cover_input_binding

```
直接用 PostMessageW / SendMessageW 投到自己手里 HWND 的 smoke（交互 smoke、大厅 flow smoke）证明不了"AppKit 事件有没有送对窗口"——它们绕过了输入绑定这一层，所以 U-03 那三类问题在它们全绿的情况下依然存在。要覆盖输入链路必须走 AppKit → 翻译 → gInputSink → 队列 → 窗口过程 的完整路径，或至少断言 [cocoa] input target 与当前呈现窗口一致。
```

### macos_game_window_input_defaults

```
macOS 上有三个默认行为会让游戏"点不动/点不准"，建窗口时必须显式处理：① NSView.acceptsFirstMouse 默认 NO → 激活窗口的那一次点击被系统吃掉（"第二下才行"）；② window.acceptsMouseMovedEvents 默认 NO → 平时没有 mouseMoved，产品的 WM_MOUSEMOVE 永远不来，命中判定用旧坐标（"每一下都错位"）；③ 输入目标要随呈现窗口重绑（见上条）。症状都像"输入没接通"，但实际是三个不同层次。
```

### stale_app_bundle_trap

```
2026-11-11 实测踩坑：用户复测"又彩虹圈"，采样发现它跑的是 build-product-arm/app/ConcordRTS.app（11:29）——加架构后缀之前残留的旧包，与新包（dist 16:32）哈希不同。这不是修复失效，是根本没跑到修复后的二进制。一次排查因此绕了一整轮。处置：把 build-product-{arm,x86,mac}/app/ConcordRTS.app 全部改名为 *.app.stale；构建目录现在只会产出带架构后缀的 ConcordRTS-<ver>-<arch>.app。判定"用户跑的是哪个包"最快的方法：sample 头部的 Path 字段；其次是比对 Contents/MacOS/concord_runtime 的 mtime 与哈希。以后让用户复测时，必须给出**唯一绝对路径**，不要只说"双击 .app"。
```

### system_cursor_hidden_by_cursor_rect

```
macOS 上游戏自绘指针，因此窗口区域内必须隐藏系统指针：view 的 resetCursorRects 里 addCursorRect(self.bounds, 不可见光标)。默认开启，CONCORD_HIDE_SYSTEM_CURSOR=0 可关。三条实证要点：① 不要镜像 Win32 的 SetCursor：世界里产品每秒几十次请求 StockArrow，而游戏同时自绘箭头，   镜像会让系统箭头回来（像素 A/B：hide=0 出现白+灰两个箭头，hide=1 只剩灰色）。② 不要用 [NSCursor hide]：全局计数，漏一次 unhide 指针永久消失。③ cursor rect 会被窗口激活/失焦/orderFront 丢掉，必须 windowDidBecomeKey 重新 invalidateCursorRectsForView，并在每个输入事件里补一次 [invisibleCursor set]。另：本 SDK 无 +[NSCursor invisibleCursor]，用 1×1 空图 initWithImage:hotSpot: 自建。
```

### debug_scaffolding_policy

```
调试脚手架（追踪日志、合成事件注入、自动点击钩子）在问题定位后必须收回：① 定位阶段可以加，但一律 env 开关 + 默认零开销，且一次只加一处；② 收口时按"是否修行为"逐条判断——pumpEvents、输入重绑、cursor rect 这类是修复，保留；③ 打印、自测注入、自动点击属于脚手架，删掉，别留在产品代码里；④ 若某能力对回归有价值（如大厅自动开局），改为独立 diagnostics 入口，不侵入主循环。本轮实践：U-01~U-05 期间加了 5 处钩子，收口时全部移除，只留行为修复 + CONCORD_HIDE_SYSTEM_CURSOR（受支持的逃生口）。
```

### regress_baseline_2026_11_11

```
2026-11-11 EVO-01：回归不再靠人记命令。`bash ra2mac_docs/scripts/regress.sh` 跑 11 条用例（core/menu/loading/skirmish/attest/render/interaction/command/build/campaign/result），约 20 秒，输出三态：PASS / KNOWN-RED（已登记在 progress/regress/known-red.tsv）/ RED-NEW（未登记，退出码=其条数）。首次基线：PASS=5 KNOWN-RED=6 RED-NEW=0。规矩：① 每轮收尾先跑它；② 出现 RED-NEW 先看日志确认是不是自己弄坏的，确认无关才可登记进 known-red.tsv（必须带一句原因）；③ 不许把红改判成绿来收口。报告在 progress/regress/<时间戳>/report.md。
```

### smoke_suite_is_mostly_red

```
2026-11-11 首次全量实测：11 条 smoke 里只有 5 条绿（core/menu/loading/skirmish/attest），6 条红且其中 5 条从未被记录（render/interaction/command/build/campaign/result）。结论：过去「回归全绿」的说法只对少数几条成立，别把个别 smoke 的绿当成整体健康证明。这 6 条不是本轮引入，已登记 known-red.tsv 待 EVO-02 分诊。
```

### dist_app_hash_is_not_comparable

```
2026-11-11 实测：不能拿 .app 里 concord_runtime 的 sha256 与 build 产物对账——ad-hoc 重签名会改写文件，哈希必然不同（两份 thin 产物分别签名）。判定 dist 是否为旧包要按 mtime：app 内二进制早于 build 产物 60s 以上即为旧包。repo 里残留的 build-product-*/app/*.app.stale 一律不要用（rules.stale_app_bundle_trap）。
```

### priority_2026_11_11_evolution

```
2026-11-11 傍晚用户定调：游戏已能运行，暂不方便做大量人工验证，后续按「无人值守可自证」排序。新顺序：EVO-01 回归编排器（done）→ EVO-02 红基线分诊 → EVO-03 diagnostics 驱动入口（解锁 ON-5-01/ON-3-01b/ON-4-02d）→ EVO-04 日志与崩溃现场 → EVO-05 存档读档往返 → EVO-06 世界重绘只读计量 → EVO-07 首次启动引导+dmg。判据变更：凡是「必须人眼看一眼」的任务一律降级，凡是能变成断言/计量的任务优先。ON-5-02b 仍是纯测量，可随时后台插跑。
```

### triage_2026_11_11

```
2026-11-11 EVO-02 分诊结论（6 条 KNOWN-RED 全部落定）：build=code-red（compat 未实现 CP1252，零售 Text= 里的 0x85 省略号被逐字节 widen 成 U+0085；日志有 'only UTF-8 is supported here' 为直接证据）；command=code-red（两栖船靠岸卸不下坦克，纯合成夹具、两次同点失败、与平台无关）；interaction=fixture-gap（建筑全 Neutral）；campaign=env-gap（13/40 无地图 + Bink 缺失，该 gate 在 macOS 按现定义永远不会绿，应改白名单而不是修）；render / result=code-red:needs-metering（未定因，先加只读计量）。教训：红基线必须先分诊再修，否则会把夹具缺口当产品缺陷修，或把上游绿过的断言当自己的锅。分诊表 reports/EVO-02-红基线分诊.md。
```

### system_cursor_hidden_needs_full_coverage

```
2026-11-11 U-06：隐藏系统指针的前提是「每个区域都有游戏自绘指针」，而这个前提必须逐区域验证，不能只看地图区。实测反例：世界页面右侧栏（HUD）此前根本不是自绘——runtimeMouseCursorFrameForPoint 对视口外一律返回 nullopt，Windows 上被系统箭头遮住，macOS 隐藏系统指针后指针整体消失。以后新增「原生页面/浮层」时的检查项：该区域内 runtimeMouseCursorFrameForPoint 是否返回帧；不返回就必须显式回落标准箭头。
```

### get_key_state_units

```
GetKeyState 与 GetKeyboardState 共用一张字节表但位布局不同：表里按下=字节 bit7(0x80)，GetKeyState 返回 SHORT 的按下=bit15(0x8000)、bit0 是锁存位。搬运必须显式做，直接强转会让所有 `& 0x8000` 判据恒假，症状与『没人写表』完全一样。
```

### compat_headers_no_windows_in_objcxx

```
Objective-C++(.mm) 里禁止 include 带 <windows.h> 的 compat 头：会与 AppKit 的 Polygon/GetCurrentProcess/GetProcessInformation 互撞而编译失败（调换包含顺序治标不治本）。需要什么就拆一个不含 windows.h 的小头（如 RuntimeWin32CompatKeyState.h），平台常量翻译留在 .cpp。
```

### bundle_identity_is_atomic

```
.app 的身份 = 名字 + 图标 + LaunchServices 登记，三者必须一次改完：只换二进制/Finder 仍显示旧图标旧名。交付一律走 ra2mac_docs/scripts/pack-dist.sh，不要手工 cp 进 .app。
```

### icns_exists_is_not_enough

```
判断图标是否生效，不能看 .icns 是否存在、也不能只跑 iconutil，必须向 IconServices 取渲染结果并与「无图标空壳 bundle」的空白占位图比对。macOS 图标要求 1024 画布/824 内容/半径185/透明边距；源图无 alpha 的方块图会被静默丢弃。
```

### fullscreen_needs_primary_and_real_click

```
全屏能力有两位：collectionBehavior=NSWindowCollectionBehaviorFullScreenPrimary（决定绿灯是「展开箭头」还是「+」）+ 窗口可缩放。自测必须点真绿灯（standardWindowButton:NSWindowZoomButton 的 performClick）而不是直接 toggleFullScreen:，且退回要从主循环栈发起——在 windowDidEnterFullScreen 通知栈里再调 toggleFullScreen 会被 AppKit 静默丢掉。
```

### view_coords_are_not_surface_coords

```
鼠标坐标必须先按「表面尺寸/view 尺寸」反算回呈现表面空间再交给游戏。view 坐标只在 view==表面时等于客户区坐标；全屏或拉伸窗口之后直接用 view 坐标会让点击整体偏移到打空（而且不报任何错）。
```

### fullscreen_criteria_no_hash

```
全屏自测的判据不能用「前后帧 hash 不变」：全屏期间界面本来就在动（光标闪烁、动画），hash 必变。判据应是 contents 未丢 + CGImage 尺寸等于呈现尺寸 + 全屏期间确实呈现过帧。
```

### nscursor_set_is_global

```
-[NSCursor set] 设的是**全局**当前游标，不会因为指针离开窗口自动撤销：只要有一条路径 set 了空图，指针在别的应用/桌面上也会看不见。区域限定的隐藏必须自己做往返（进入设、离开撤销），或真接 [NSApp sendEvent:] 让 cursor rect 生效。
```

### cursor_rect_needs_send_event

```
本项目只 nextEventMatchingMask 出队、不调 [NSApp sendEvent:]，实测这种循环里 cursor rect（addCursorRect/resetCursorRects）完全不生效，NSApp.isActive 与 window.isKeyWindow 也恒为 0。任何依赖「窗口级 cursor 状态」的代码在本项目里都是死代码，除非先接 sendEvent（见 EVO-15）。
```

### cursor_state_needs_truth_not_flag

```
判断「光标现在是不是被我们藏了」要读 +[NSCursor currentSystemCursor]（系统此刻真正在显示什么），不要用自己的标志位：AppKit 会在激活变化时把游标改回箭头，标志位一旦脱节就再也收敛不回来。
```

### pointer_capture_is_association_off

```
macOS 没有把光标裁剪在窗口内的 API。所谓「抓住鼠标」= CGAssociateMouseAndMouseCursorPosition(false)：硬件指针完全不动，游戏用 NSEvent.deltaX/deltaY 推虚拟指针（y 要翻转、要夹在表面内）。这是进程级开关，任何退出路径漏恢复都会让整机鼠标动不了，必须有 shutdown + atexit + _Exit 路径三重兜底；失焦要自动释放。
```

### warp_bypasses_capture

```
CGWarpMouseCursorPosition 是显式定位，会绕过 CGAssociateMouseAndMouseCursorPosition(false)——所以「捕获期间指针不动」不能用 warp 来自动验证（推得动才是正常的）。这条只能人工确认。
```
