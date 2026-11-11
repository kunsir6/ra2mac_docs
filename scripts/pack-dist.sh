#!/bin/bash
# 组装 dist/ 下的可交付 .app：归档旧包 → 组装 → 注销陈旧登记 → 验证名字/图标/冒烟。
#
# 为什么需要脚本（而不是手工 cp 二进制进 .app）：
#   1. 身份三件事必须同时改：bundle 名、CFBundleIconFile、LaunchServices 登记。
#      只换二进制的话，Finder/Dock 仍显示上一次的图标与名字——这就是"没同步"的观感来源。
#   2. 同一 bundle id 一旦被多份拷贝登记（dist / build / .stale / 废纸篓），
#      LaunchServices 会拿任意一份来解析图标，结果不可预测。脚本显式注销旧路径。
#   3. 图标是否真的被系统接受，只有问 IconServices 才知道（.icns 文件存在 ≠ 系统认它）。
#
# 用法：
#   bash ra2mac_docs/scripts/pack-dist.sh
#   bash ra2mac_docs/scripts/pack-dist.sh --app-name "尤里红警" --dry-run
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_REPO="$PROJECT_ROOT/ConcordRTS"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

BIN="$SRC_REPO/build-product-arm/concord_runtime"
DATA_ROOT="$PROJECT_ROOT/ConcordRTS-GameData"
OUT="$PROJECT_ROOT/dist"
APP_NAME="尤里红警"
BUNDLE_ID="org.concord.rts.yuri"
VERSION="0.1.0"
# 必须与二进制 LC_BUILD_VERSION 的 minos 一致（build 时 -DCMAKE_OSX_DEPLOYMENT_TARGET）。
# 声明高于实际 minos：Finder 允许多打开一步，dyld 仍然拒绝；
# 声明低于实际 minos：老系统能装、一启动就崩。两边都错。
MIN_MACOS="12.0"
ICON_SOURCE="$SRC_REPO/packaging/icon-source.png"
DRY_RUN=0

usage() {
    cat <<'EOF'
usage: pack-dist.sh [options]
  --bin <path>        被测二进制（默认 ConcordRTS/build-product-arm/concord_runtime）
  --data-root <dir>   游戏数据根（默认 ConcordRTS-GameData）
  --out <dir>         dist 输出目录（默认 <项目根>/dist）
  --app-name <name>   .app 与 Finder 显示名（默认 尤里红警）
  --bundle-id <id>    CFBundleIdentifier（默认 org.concord.rts.yuri）
  --version <semver>  CFBundleShortVersionString（默认 0.1.0）
  --icon-source <png> 图标源图（默认 ConcordRTS/packaging/icon-source.png）
  --dry-run           只打印将要做的事
EOF
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bin)         BIN="$2"; shift 2 ;;
        --data-root)   DATA_ROOT="$2"; shift 2 ;;
        --out)         OUT="$2"; shift 2 ;;
        --app-name)    APP_NAME="$2"; shift 2 ;;
        --bundle-id)   BUNDLE_ID="$2"; shift 2 ;;
        --version)     VERSION="$2"; shift 2 ;;
        --icon-source) ICON_SOURCE="$2"; shift 2 ;;
        --dry-run)     DRY_RUN=1; shift ;;
        -h|--help)     usage ;;
        *) echo "pack-dist: unknown argument: $1" >&2; usage ;;
    esac
done

APP="$OUT/$APP_NAME.app"
ARCHIVE_ROOT="$OUT/.archive"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '  %s\n' "$*"; }

# 注销一个路径的 LaunchServices 登记（不存在也无所谓）。
unregister() {
    [ -e "$1" ] || return 0
    "$LSREGISTER" -u "$1" >/dev/null 2>&1 || true
}

echo "== 组装 dist =="
say "binary    $BIN"
say "data-root $DATA_ROOT"
say "app       $APP"
say "bundle-id $BUNDLE_ID"

[ -f "$BIN" ] || { echo "pack-dist: 找不到二进制: $BIN" >&2; exit 1; }
[ -d "$DATA_ROOT/local_data" ] || { echo "pack-dist: 数据根缺少 local_data: $DATA_ROOT" >&2; exit 1; }

if [ "$DRY_RUN" = 1 ]; then
    say "dry-run：不做任何写入"
    exit 0
fi

# ① 归档旧包。放在 dist/.archive 下，并且注销它的登记——否则同 id 的旧包
#    会和新的抢图标/名字（本机实测堆积过 18 份）。
mkdir -p "$ARCHIVE_ROOT"
if [ -e "$APP" ]; then
    ARCHIVED="$ARCHIVE_ROOT/$(basename "$APP" .app)-$STAMP.app"
    mv "$APP" "$ARCHIVED"
    unregister "$ARCHIVED"
    say "archived  ${ARCHIVED}（已从 LaunchServices 注销）"
fi
# dist 里其它名字的 .app（历史命名 ConcordRTS-0.1.0-<arch>、*.app.stale 等）一并归档：
# 它们仍会被 Finder 当成可双击的应用，留着只会让人点错、并且继续参与图标解析。
for other in "$OUT"/*.app "$OUT"/*.app.stale; do
    [ -e "$other" ] || continue
    [ "$other" = "$APP" ] && continue
    unregister "$other"
    OTHER_ARCHIVED="$ARCHIVE_ROOT/$(basename "$other" | tr ' ' '_')-$STAMP"
    mv "$other" "$OTHER_ARCHIVED"
    say "archived  ${OTHER_ARCHIVED}（旧命名/旧构建，已注销）"
done

# ② 清理历史登记（只注销登记，不动文件）：废纸篓里删过的旧包、build 目录里的开发包，
#    只要还挂在同一个/曾用过的 bundle id 上，就会参与图标与显示名的解析。
#    本机实测同 id 堆过 18 份（Trash 7 / build 4 / dist 2 / AppTranslocation 2 …），
#    这是"改了包但 Finder 还是老样子"的直接原因。
for noise in "$HOME"/.Trash/*ConcordRTS*.app* \
             "$SRC_REPO"/build-product-*/app/*.app \
             "$SRC_REPO"/build-product-*/app/*.app.stale; do
    [ -e "$noise" ] || continue
    unregister "$noise"
done

# ③ 组装（图标、plist、PkgInfo、data-root、ad-hoc 签名都在这一步）。
sh "$SRC_REPO/packaging/make-app-bundle.sh" \
    --binary "$BIN" \
    --output "$OUT" \
    --data-root "$DATA_ROOT" \
    --version "$VERSION" \
    --bundle-id "$BUNDLE_ID" \
    --app-name "$APP_NAME" \
    --min-macos "$MIN_MACOS" \
    --icon-source "$ICON_SOURCE"

# ④ 让系统重新认识这个包。只 -f 注册新包还不够：旧登记会继续服务图标查询，
#    所以先按 id 清一遍，再注册。
"$LSREGISTER" -f "$APP" >/dev/null 2>&1 || true
sleep 1  # IconServices 是一次带缓存的异步解析，立刻查询可能拿到上一份

# ⑤ 验证 A：plist 身份。
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null || echo ""; }
NAME_SHOWN="$(read_plist CFBundleDisplayName)"
ID_SHOWN="$(read_plist CFBundleIdentifier)"
ICON_REF="$(read_plist CFBundleIconFile)"
VC_APP="$(cd "$PROJECT_ROOT" && git -C "$SRC_REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
say "plist     displayName=$NAME_SHOWN id=$ID_SHOWN icon=$ICON_REF source=$VC_APP"
if [ "$NAME_SHOWN" != "$APP_NAME" ] || [ "$ID_SHOWN" != "$BUNDLE_ID" ]; then
    echo "pack-dist: plist 身份与期望不一致" >&2
    exit 1
fi
[ -f "$APP/Contents/Resources/$ICON_REF.icns" ] || {
    echo "pack-dist: CFBundleIconFile 指向的文件不存在: $ICON_REF.icns" >&2
    exit 1
}

# ⑥ 验证 B：图标真的被 IconServices 接受。
#    判据不是"文件存在"，而是"系统渲染出来的图标与空白占位图不同"。
#    空白占位图现场造一份做参照，避免写死哈希（系统图会随版本变）。
VERIFY_DIR="$OUT/.verify"
mkdir -p "$VERIFY_DIR"
GENERIC_BUNDLE=/tmp/concord-generic-ref.app
rm -rf "$GENERIC_BUNDLE"
mkdir -p "$GENERIC_BUNDLE/Contents/MacOS" "$GENERIC_BUNDLE/Contents/Resources"
cp "$APP/Contents/MacOS/concord_runtime" "$GENERIC_BUNDLE/Contents/MacOS/" 2>/dev/null || true
cat > "$GENERIC_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>GenericRef</string>
<key>CFBundleIdentifier</key><string>org.concord.genericref</string>
<key>CFBundleExecutable</key><string>concord_runtime</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
printf 'APPL????' > "$GENERIC_BUNDLE/Contents/PkgInfo"
"$LSREGISTER" -f "$GENERIC_BUNDLE" >/dev/null 2>&1 || true

osascript -l JavaScript -e "
ObjC.import('AppKit');
function dump(p,o){var i=\$.NSWorkspace.sharedWorkspace.iconForFile(p);
var r=\$.NSBitmapImageRep.imageRepWithData(i.TIFFRepresentation);
r.representationUsingTypeProperties(\$.NSBitmapImageFileTypePNG,\$()).writeToFileAtomically(o,true);}
dump('$APP','$VERIFY_DIR/icon.png');
dump('$GENERIC_BUNDLE','$VERIFY_DIR/generic.png');
'ok'" >/dev/null 2>&1 || { echo "pack-dist: 取图标失败（JXA/AppKit 不可用）" >&2; exit 1; }

python3 - "$VERIFY_DIR/icon.png" "$VERIFY_DIR/generic.png" <<'PY'
import sys
from PIL import Image, ImageChops, ImageStat
real, generic = (Image.open(p).convert("RGB").resize((256, 256)) for p in sys.argv[1:3])
diff = ImageStat.Stat(ImageChops.difference(real, generic)).mean
mean = sum(diff) / 3
print(f"  icon      diff-vs-generic={mean:.1f}/255  (阈值 >8 判定系统已采用自定义图标)")
if mean <= 8:
    sys.exit("pack-dist: 系统仍显示通用占位图标（自定义 icns 未被 IconServices 采用）")
PY

# ⑦ 验证 C：最低系统版本「声明 == 实际」。
#
#    Info.plist 的 LSMinimumSystemVersion 只是给 Finder/LaunchServices 看的提示；
#    真正决定"能不能启动"的是 Mach-O 的 LC_BUILD_VERSION.minos——dyld 只看后者。
#    两者不一致时系统按 plist 放行、dyld 按 minos 拒绝，用户看到的就是笼统的
#    「系统版本太低」，没有任何日志指向真正原因。本机实测过 plist=11.0 / minos=27.2
#    这一对（构建时没传 CMAKE_OSX_DEPLOYMENT_TARGET，默认跟本机 SDK 走），
#    拷到 macOS 12 的 Intel 机上直接打不开。所以这里做成硬断言，而不是注释提醒。
#
#    minos 由构建参数决定，脚本改不了；能做的是"不配对就拒绝出包"。
DECLARED_MIN="$(read_plist LSMinimumSystemVersion)"
BINARY="$APP/Contents/MacOS/concord_runtime"
if [ -z "$DECLARED_MIN" ]; then
    echo "pack-dist: Info.plist 缺少 LSMinimumSystemVersion" >&2
    exit 1
fi
if [ "$DECLARED_MIN" != "$MIN_MACOS" ]; then
    echo "pack-dist: plist 声明 ${DECLARED_MIN}，但脚本 MIN_MACOS=$MIN_MACOS" >&2
    exit 1
fi
if ! command -v vtool >/dev/null 2>&1; then
    echo "pack-dist: 找不到 vtool（Xcode Command Line Tools），无法校验 minos" >&2
    exit 1
fi
ARCH_LIST="$(lipo -archs "$BINARY")"
for arch in $ARCH_LIST; do
    ARCH_MIN="$(vtool -arch "$arch" -show-build "$BINARY" 2>/dev/null \
        | awk '/minos/ {print $2; exit}')"
    if [ -z "$ARCH_MIN" ]; then
        echo "pack-dist: 读不到 $arch 切片的 minos" >&2
        exit 1
    fi
    if [ "$ARCH_MIN" != "$MIN_MACOS" ]; then
        cat >&2 <<EOF
pack-dist: $arch 切片的 minos=${ARCH_MIN}，与 MIN_MACOS=$MIN_MACOS 不一致。
  plist 声明的最低版本是 ${DECLARED_MIN}，二进制实际要求 ${ARCH_MIN}。
  两者不等时，系统按 plist 放行、dyld 按 minos 拒绝，用户只会看到笼统的
  「需要更新 macOS」而拿不到真正原因。
  重新构建（两个架构都要）：
    cmake -S "$SRC_REPO" -B <build-dir> -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_MACOS
EOF
        exit 1
    fi
done
say "min-macos ${DECLARED_MIN}（plist 与 $(echo "$ARCH_LIST" | tr ' ' '+') 的 minos 一致）"

# ⑧ 验证 D：包内二进制能跑（core smoke）。
"$APP/Contents/MacOS/concord_runtime" --smoke-test >/dev/null 2>&1 || {
    echo "pack-dist: 包内二进制 --smoke-test 失败" >&2
    exit 1
}
say "smoke     --smoke-test rc=0"

echo "== 完成 =="
say "app       $APP"
say "icon png  $VERIFY_DIR/icon.png（可用于人工核对）"

# 参照用的空壳 bundle 是这次验证的临时产物，运行结束就撤掉（含其登记）。
unregister "$GENERIC_BUNDLE"
rm -rf "$GENERIC_BUNDLE"
