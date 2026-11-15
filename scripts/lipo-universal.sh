#!/bin/bash
# 把两个单架构切片合成通用二进制，ad-hoc 重签，并逐条验证门禁。
# 这是「dist 永远是最新版本」链路的第 (c)(d) 两步，第 50 轮从人工口令固化成脚本：
# 之前每轮手敲 cp -lipo -codesign，.bak 备份无保留策略，5 天堆到 14 份 / 1.4GB。
#
# 用法：
#   bash ra2mac_docs/scripts/lipo-universal.sh                 # 合成并校验
#   bash ra2mac_docs/scripts/lipo-universal.sh --check         # 只校验现有产物，不写
#
# 门禁（任一失败即 exit 1，不许出包）：
#   ① lipo -archs 同时含 arm64 与 x86_64
#   ② 两个切片的 vtool minos 都等于 $MIN_MACOS
#   ③ (--check 之外) 重签成功，codesign -v 通过
#
# 注意：本脚本只做 lipo + 签名 + 校验。装进 .app 必须走 pack-dist.sh，
# 不要手工 cp 二进制进 bundle（名字/图标/LaunchServices 登记是一次整体动作）。

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOCS=$(dirname "$SCRIPT_DIR")
ROOT=$(dirname "$DOCS")

ARM=${ARM_BIN:-$ROOT/ConcordRTS/build-product-arm/concord_runtime}
X86=${X86_BIN:-$ROOT/ConcordRTS/build-product-x86_64/concord_runtime}
OUT=${UNIVERSAL_BIN:-$ROOT/ConcordRTS/build-universal/concord_runtime}
MIN_MACOS=${MIN_MACOS:-12.0}
KEEP_BAK=${KEEP_BAK:-1}
CHECK_ONLY=0

for a in "$@"; do
    case "$a" in
        --check) CHECK_ONLY=1 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) echo "lipo-universal: unknown argument: $a" >&2; exit 2 ;;
    esac
done

say() { printf '  %s\n' "$*"; }

minos_of() {
    vtool -arch "$2" -show-build "$1" 2>/dev/null | awk '/minos/{print $2; exit}'
}

echo "== 通用二进制 =="

if [ "$CHECK_ONLY" = 0 ]; then
    [ -f "$ARM" ] || { echo "lipo-universal: 找不到 arm64 切片: $ARM" >&2; exit 1; }
    [ -f "$X86" ] || { echo "lipo-universal: 找不到 x86_64 切片: $X86" >&2; exit 1; }
    mkdir -p "$(dirname "$OUT")"

    # 备份：只保留最近 $KEEP_BAK 份，其余删除（.archive 里还有 5 个完整包可回退）
    if [ -f "$OUT" ]; then
        BAK="$OUT.bak-$(date +%H%M%S)"
        cp "$OUT" "$BAK"
        say "backup    $(basename "$BAK")"
        old=$(ls -1t "$OUT".bak-* 2>/dev/null | tail -n +"$((KEEP_BAK + 1))" || true)
        if [ -n "$old" ]; then
            n=0
            while IFS= read -r f; do
                [ -n "$f" ] || continue
                rm -f -- "$f"
                n=$((n + 1))
            done <<< "$old"
            say "pruned    $n 份旧备份（保留最近 $KEEP_BAK 份）"
        fi
    fi

    lipo -create "$ARM" "$X86" -output "$OUT"
    codesign --force -s - "$OUT" >/dev/null 2>&1
    say "lipo+sig  $(basename "$OUT")  $(stat -f %z "$OUT") bytes"
fi

[ -f "$OUT" ] || { echo "lipo-universal: 找不到通用二进制: $OUT" >&2; exit 1; }

archs=$(lipo -archs "$OUT")
say "archs     $archs"
case "$archs" in
    *arm64*) ;;
    *) echo "lipo-universal: 缺少 arm64 切片" >&2; exit 1 ;;
esac
case "$archs" in
    *x86_64*) ;;
    *) echo "lipo-universal: 缺少 x86_64 切片" >&2; exit 1 ;;
esac

for a in arm64 x86_64; do
    m=$(minos_of "$OUT" "$a")
    say "minos     $a = ${m:-<none>}（要求 ${MIN_MACOS}）"
    if [ "$m" != "$MIN_MACOS" ]; then
        echo "lipo-universal: $a 切片的 minos 是 ${m:-<none>}，与 $MIN_MACOS 不符——老系统会打不开" >&2
        echo "（新建构建目录会退回本机 SDK 版本；CMAKE_OSX_DEPLOYMENT_TARGET 只活在 CMakeCache.txt 里）" >&2
        exit 1
    fi
done

if [ "$CHECK_ONLY" = 0 ]; then
    codesign --verify --deep --strict "$OUT" >/dev/null 2>&1 \
        || { echo "lipo-universal: 签名校验失败" >&2; exit 1; }
    say "signature adhoc 校验通过"
fi

echo "== 通过 =="
