#!/usr/bin/env bash
# compat/win32 兼容层的统一验证入口。
#
# 为什么需要它：这一层的验证方式是"编译通过 + 语义断言"，两者都不在 CTest 里
# ——CTest 的注册数量要跨平台保持一致，否则基线对账每次都会报差异。所以把命令
# 固化在脚本里，避免每轮靠记忆重敲。
#
# 用法:
#   scripts/verify-win32-compat.sh            # 六层自测（约 40 秒）
#   scripts/verify-win32-compat.sh --census   # 额外统计引用 Win32 符号的 TU 编译通过数（约 5 分钟）
#
# 退出码: 0 全部通过；1 有失败。

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${REPO}/ConcordRTS"
COMPAT="${ROOT}/compat/win32"
BUILD="${ROOT}/build-product-mac"
CXX_BIN="${CXX:-/usr/bin/c++}"
TMPDIR_RUN="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_RUN}"' EXIT

failures=0
steps_total=16
steps_done=0

step() {
    steps_done=$((steps_done + 1))
    printf '\n\033[1m%s/%s %s\033[0m\n' "${steps_done}" "${steps_total}" "$1"
}
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf '  ok    %s\n' "$1"; }

# 1) 声明层：只做语法检查。这个 TU 会逐一调用全部声明，因此只要有一个签名写错
#    就会报错；但它没有实现，不能链接。
step "头层声明自测（仅编译）"
if "${CXX_BIN}" -std=c++20 -Wall -Wextra -I "${COMPAT}/include" -fsyntax-only \
        "${COMPAT}/selftest/CompatHeaderSelftest.cpp" 2>"${TMPDIR_RUN}/header.log"; then
    # 声明数量现算，不写死——每加一批声明就手改常量，迟早会变成一句假话。
    declared=$(python3 - "${COMPAT}/include" <<'PY'
import glob, os, sys
total = 0
for path in sorted(glob.glob(os.path.join(sys.argv[1], '*.h'))):
    for line in open(path, encoding='utf-8', errors='replace'):
        t = line.strip()
        if t.startswith(('#', '//', 'struct', 'using', 'enum', 'union', 'class', '}')):
            continue
        if '(' in t and t.endswith(';') and not t.startswith('static_assert'):
            total += 1
print(total)
PY
)
    pass "${declared} 个函数声明与全部常量可编译"
else
    fail "头层声明自测未通过"
    sed -n '1,15p' "${TMPDIR_RUN}/header.log"
fi

# 2) 头层里 inline 实现的几何/环境工具：可运行，断言的是语义值。
step "头层内联语义自测（编译并运行）"
if "${CXX_BIN}" -std=c++20 -Wall -Wextra -I "${COMPAT}/include" \
        "${COMPAT}/selftest/CompatInlineSemantics.cpp" \
        -o "${TMPDIR_RUN}/inline" 2>"${TMPDIR_RUN}/inline_build.log"; then
    if "${TMPDIR_RUN}/inline" > "${TMPDIR_RUN}/inline_run.log" 2>&1; then
        pass "$(tail -1 "${TMPDIR_RUN}/inline_run.log")"
    else
        fail "内联语义自测运行失败"
        tail -12 "${TMPDIR_RUN}/inline_run.log"
    fi
else
    fail "内联语义自测未通过编译"
    sed -n '1,15p' "${TMPDIR_RUN}/inline_build.log"
fi

# 3) 之后的每一步都走 CMake 目标，验证它确实被接进构建图，而不只是能单独编译。
run_cmake_selftest() {
    local target="$1"
    local title="$2"
    local log="${TMPDIR_RUN}/${target}"
    step "${title}"
    if [ ! -d "${BUILD}" ]; then
        fail "缺少 ${BUILD}，先执行 cmake -S ConcordRTS -B build-product-mac"
        return
    fi
    if ! ninja -C "${BUILD}" "${target}" > "${log}_build.log" 2>&1; then
        fail "${target} 构建失败"
        tail -20 "${log}_build.log"
        return
    fi
    if "${BUILD}/${target}" > "${log}_run.log" 2>&1; then
        pass "$(tail -1 "${log}_run.log")"
    else
        fail "${target} 运行失败"
        grep -E '^  FAIL' "${log}_run.log" || tail -12 "${log}_run.log"
    fi
}

# GDI 对象管理 + 位图传输：断言的是像素值，不是返回值。
run_cmake_selftest concord_win32_compat_gdi_selftest "GDI 实现语义自测（对象/位图传输）"

# DC 状态与查询：断言的是初值与常量的**字面量**。三条快路径靠逐项比对 DC 状态
# 决定是否走快路，初值给错 = 快路永远关闭，而所有"快慢两路一致"的契约照样全绿。
run_cmake_selftest concord_win32_compat_dcstate_selftest "DC 状态与查询自测（快路径前提条件）"

# XAPO：项目自己的峰值限幅器（真实 DSP）跑在本层的 CXAPOBase 上。测的是
# "编译通过看不见的东西"——Release() 有没有真的销毁对象（基类虚析构负责）。
run_cmake_selftest concord_win32_compat_xapo_selftest "XAPO / CXAPOBase 语义自测（项目真实限幅器）"

# EMF：录制 → 回放 → 审计。关键不是"能回放"，而是"多录一帧时审计真的会报错"，
# 否则产品侧那句 copies != 1 是空断言。
run_cmake_selftest concord_win32_compat_metafile_selftest "EMF 录制与回放自测（帧稳定性审计的基础）"

# 小族（COM / 定时器 / MCI / MSVC _s）：风险在"表层等价物静默改变行为"。
run_cmake_selftest concord_win32_compat_misc_selftest "小族语义自测（CRT _s / COM / 定时器 / MCI）"

# 区域与裁剪：三条快路径靠 GetClipBox 的复杂度决定让不让；恒答 SIMPLEREGION
# 就等于宣布"复杂裁剪不存在"。同时钉住"选中后删除区域仍有效"（深拷贝）。
run_cmake_selftest concord_win32_compat_region_selftest "区域与裁剪自测（复杂度三态 / 布尔组合 / 深拷贝）"

# 图元光栅：半开边界 / LineTo 不含终点 / 裁剪真生效 / 映射真生效 / XOR 两遍还原。
# 这一层是全项目唯一用**硬编码像素**断言的地方——raster 契约两侧共用同一套
# GDI，边界差一像素、裁剪被忽略在两侧同时发生，断言看不出来。
run_cmake_selftest concord_win32_compat_draw_selftest "图元光栅自测（半开边界 / 裁剪 / 映射 / ROP2）"
run_cmake_selftest concord_win32_compat_file_selftest "文件/进程自测（错误码 / 句柄类型 / 码点 / 时钟）"

# 输入 / 光标 / 捕获 / 定时器（P5-05）：无窗口宿主时，返回什么才是诚实默认。
# 关键不是"返回值像不像 Windows"，而是"不撒谎"——LoadCursorW 标准 ID 必须非 NULL
# （NULL 会被 SetCursor 读成"隐藏光标"），DrawFrameControl 必须真画（不是 no-op 还
# 返回 TRUE）。
run_cmake_selftest concord_win32_compat_input_selftest "输入/光标/捕获/定时器自测（诚实默认）"

# S11：定时器派发。判据是**真实消息循环里的计数**（1 秒 ≥50 条 WM_TIMER），
# 不是返回值——上一版 SetTimer 返回 TRUE 而一条消息都不产生，产品照样进菜单、
# 只是永远不动。这一层是唯一能抓住"登记即成功"的桩的地方。
run_cmake_selftest concord_win32_compat_timer_selftest "定时器派发自测（WM_TIMER 计数 / 合成重绘 / 销毁清理）"

# T-03：宽字符运行期语义。判据是**码元/字节个数**，不是"能不能显示"：
# 4 字节 UTF-8 在本平台只产出 1 个 wchar_t（Windows 上是 2 个 UTF-16 码元），
# 任何按 UTF-16 长度做的假设都会在这里现形。
run_cmake_selftest concord_apple_chat_text_encoding_selftest "宽字符运行期语义（emoji / 孤立代理 / 路径往返）"



# 文本 / 字体（P5-06 度量 + S4-2 真字形）：度量仍钉"先量后画一致"（含东亚宽字符
# 1:1 单元格）；字形改钉**字形语义**——'T'/'e' 共用基线、'g' 有降部、'L' 的横杠在
# 底部（挡整体翻转）、同一调用两次逐字节相同、XOR 画两遍逐字节还原。
# 真字没法硬编码像素（随系统字体版本变），但上面每一条都是任何真实字体必须满足的。
run_cmake_selftest concord_win32_compat_text_selftest "文本/字体自测（基线对齐 / 度量一致 / XOR 还原）"

# 窗口 / 消息 / 钩子（S7，纯离屏）：断言逻辑窗口对象模型闭环——注册类→建窗口→
# WM_NCCREATE 存 GWLP_USERDATA→PostMessage/GetMessage/DispatchMessage 到窗口过程→
# WH_CBT 在 HCBT_CREATEWND 读到类名→DestroyWindow 后句柄计数归零。不开真窗口。
run_cmake_selftest concord_win32_compat_user_selftest "窗口/消息/钩子自测（纯离屏对象模型闭环）"

# S6: GDI+ PNG 导出。断言 startup/codec 枚举 + Bitmap::Save 真写出 PNG 且解码后
# R/G/B 通道次序不换色（用 ImageIO 解回验证）。
run_cmake_selftest concord_win32_compat_gdiplus_selftest "GDI+ PNG 导出自测（编码器枚举 / 颜色保真）"

# 6) 可选普查：产品构建图里引用过 Win32 符号的 TU，现在有多少能编译。
if [ "${1:-}" = "--census" ]; then
    steps_total=$((steps_total + 1))
    step "普查：产品构建图内 Win32 TU 的编译通过数"
    list="${TMPDIR_RUN}/tu.txt"
    ninja -C "${BUILD}" -t commands 2>/dev/null \
        | grep -oE '\-c [^ ]+\.(cpp|cc|c|mm)' | sed 's/^-c //' | sort -u > "${TMPDIR_RUN}/all_srcs.txt"
    python3 - "${TMPDIR_RUN}/all_srcs.txt" "${list}" <<'PY'
import re, sys
srcs = [l.strip() for l in open(sys.argv[1]) if l.strip()]
tokens = """HWND HDC HGDIOBJ HBITMAP HBRUSH HPEN HFONT HICON HCURSOR HINSTANCE HMODULE HANDLE
WPARAM LPARAM LRESULT RECT POINT MSG BITMAPINFO BITMAPINFOHEADER PAINTSTRUCT WNDCLASSEXW
CreateWindowExW SelectObject BitBlt StretchDIBits SetDIBitsToDevice GetStockObject DeleteObject
BeginPaint EndPaint GetDC ReleaseDC FillRect DrawTextW EnumThreadWindows""".split()
rx = re.compile(r'(?<![A-Za-z0-9_])(' + '|'.join(tokens) + r')(?![A-Za-z0-9_])')
kept = []
for path in srcs:
    try:
        if rx.search(open(path, encoding='utf-8', errors='replace').read()):
            kept.append(path)
    except OSError:
        pass
open(sys.argv[2], 'w').write('\n'.join(kept) + ('\n' if kept else ''))
print(f"  引用 Win32 符号的 TU: {len(kept)} / {len(srcs)}")
PY
    total=0; ok=0; bad=""
    while read -r src; do
        [ -n "${src}" ] || continue
        total=$((total + 1))
        # S8：补上 -I "${COMPAT}/src"。少这一条时，任何 include 了
        # RuntimeWin32CompatInternal.h 的 TU（CompatUserSemantics / CompatTimerDeliverySemantics）
        # 都会被判成"编译失败"——那是**口径缺口**，不是代码坏了，会一直污染这个数字。
        if "${CXX_BIN}" -DCONCORD_RULES_ABI_REVISION=2026092202 -I "${COMPAT}/include" -I "${COMPAT}/src" -I "${ROOT}/src" \
                -std=c++20 -fsyntax-only "${src}" >/dev/null 2>&1; then
            ok=$((ok + 1))
        else
            bad="${bad}    $(basename "${src}")\n"
        fi
    done < "${list}"
    printf '  编译通过 %d / %d\n' "${ok}" "${total}"
    [ -n "${bad}" ] && printf "${bad}"
fi

printf '\n'
if [ "${failures}" -eq 0 ]; then
    printf '\033[32m全部通过\033[0m\n'
    exit 0
fi
printf '\033[31m%d 项失败\033[0m\n' "${failures}"
exit 1
