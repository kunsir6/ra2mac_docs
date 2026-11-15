#!/bin/bash
# make-dmg.sh — 把 dist/<AppName>.app 打成可分发 dmg，并且**挂载后逐条验过**才算成功。
#
# 为什么要有这一步（而不是 hdiutil 一行了事）：
#   1. dmg 里的包是「拷贝」，而 ad-hoc 签名的 seal 会因拷贝方式而不完整——用 cp -R 可能丢
#      扩展属性，`codesign --verify --strict` 在别人的机器上才炸。这里用 ditto 并当场验签。
#   2. 打包链已经证明「dist 里的包是对的」，但 dmg 是**另一层容器**：FAT 是否还 FAT、
#      两切片 minos 是否还等于 plist、包内 --version 是否还等于 BUILD-INFO——只有从挂载卷里
#      取出来的那一份能回答。dist 对 ≠ dmg 对。
#   3. 挂载卷里没有同级 ConcordRTS-GameData（1.6GB 不进包），所以「双击能不能玩」取决于
#      数据根搜索；把「找不到数据根时到底发生什么」当场量下来，别靠猜。
#
# 用法：
#   bash ra2mac_docs/scripts/make-dmg.sh                       # 用 dist/尤里红警.app 出包
#   bash ra2mac_docs/scripts/make-dmg.sh --data-root <dir>     # 验 smoke 用的数据根
#   bash ra2mac_docs/scripts/make-dmg.sh --dry-run
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$PROJECT_ROOT/dist"
APP_NAME="尤里红警"
DATA_ROOT="$PROJECT_ROOT/ConcordRTS-GameData"
VOL_NAME=""
DRY_RUN=0

usage() {
    cat <<'EOF'
usage: make-dmg.sh [options]
  --app <path>        .app 路径（默认 <项目根>/dist/尤里红警.app）
  --out <dir>         输出目录（默认 <项目根>/dist）
  --data-root <dir>   验 --smoke-test 用的游戏数据根
  --vol-name <name>   挂载卷名（默认与 app 名相同）
  --dry-run           只打印将要做的事
EOF
    exit 2
}

APP=""
while [ $# -gt 0 ]; do
    case "$1" in
        --app)        APP="$2"; shift 2 ;;
        --out)        OUT="$2"; shift 2 ;;
        --data-root)  DATA_ROOT="$2"; shift 2 ;;
        --vol-name)   VOL_NAME="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=1; shift ;;
        -h|--help)    usage ;;
        *) echo "make-dmg: unknown argument: $1" >&2; usage ;;
    esac
done

say() { printf '  %s\n' "$*"; }
[ -n "$APP" ] || APP="$OUT/$APP_NAME.app"
[ -n "$VOL_NAME" ] || VOL_NAME="$APP_NAME"

[ -d "$APP" ] || { echo "make-dmg: 找不到 .app: ${APP}（先跑 pack-dist.sh）" >&2; exit 1; }
BIN="$APP/Contents/MacOS/concord_runtime"
[ -x "$BIN" ] || { echo "make-dmg: 包里没有可执行文件: $BIN" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || echo 0.0.0)"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP/Contents/Info.plist" 2>/dev/null || echo "")"
BUILD_INFO="$APP/Contents/Resources/BUILD-INFO.txt"
[ -f "$BUILD_INFO" ] || { echo "make-dmg: 包内缺 BUILD-INFO.txt（pack-dist.sh ③b 才写）" >&2; exit 1; }
PACK_LINE="$(head -1 "$BUILD_INFO")"
SHORT_HASH="$(printf '%s' "$PACK_LINE" | awk '{print $1}')"

# 文件名带 hash：拿到 dmg 的人一眼能对上 BUILD-STAMP，不必解包才知道是哪一版。
DMG="$OUT/$APP_NAME-$VERSION-$SHORT_HASH.dmg"

echo "== 出 dmg =="
say "app       $APP"
say "dmg       $DMG"
say "buildinfo $PACK_LINE"

if [ "$DRY_RUN" = 1 ]; then
    say "dry-run：不做任何写入"
    exit 0
fi

STAGE="$(mktemp -d /tmp/concord-dmg-stage.XXXXXX)"
MNT="$(mktemp -d /tmp/concord-dmg-mnt.XXXXXX)"
cleanup() {
    hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || hdiutil detach "$MNT" -force -quiet >/dev/null 2>&1 || true
    rm -rf "$STAGE" "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

# ① 组装卷内容：app + 指向 /Applications 的符号链接 + 说明。
#    ditto 而不是 cp -R：前者保留扩展属性与资源分叉，签名 seal 才不会因拷贝而失效。
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"
if [ -f "$OUT/README.txt" ]; then
    cp "$OUT/README.txt" "$STAGE/使用说明.txt"
else
    say "warn      dist/README.txt 不存在，dmg 里不带说明书"
fi

# ② 压缩出包。UDZO = zlib 压缩只读，双击挂载；-fs HFS+ 是为了让 Applications 符号链接
#    在 Finder 里表现为「可拖入的文件夹别名」（APFS 卷上的符号链接在某些版本会被显示成普通文件）。
rm -f "$DMG"
hdiutil create -quiet -volname "$VOL_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
say "created   $(du -h "$DMG" | awk '{print $1}')"

# ③ 先验容器本身（CRC），再挂载。
hdiutil verify -quiet "$DMG" || { echo "make-dmg: hdiutil verify 失败（dmg 已损坏）" >&2; exit 1; }
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MNT" "$DMG" \
    || { echo "make-dmg: 挂载失败" >&2; exit 1; }

MBIN="$MNT/$(basename "$APP")/Contents/MacOS/concord_runtime"
[ -x "$MBIN" ] || { echo "make-dmg: 挂载卷里没有可执行文件" >&2; exit 1; }

# ④ 验 A：FAT 还在（dist 是 FAT，dmg 是另一层容器，别假设它原样传下来）。
ARCHS="$(lipo -archs "$MBIN")"
case "$ARCHS" in
    *arm64*x86_64*|*x86_64*arm64*) : ;;
    *) echo "make-dmg: 挂载卷里的二进制不是 universal: $ARCHS" >&2; exit 1 ;;
esac
say "archs     $ARCHS"

# ⑤ 验 B：两切片 minos 仍等于 plist 声明（拷贝不会改 Mach-O，但换构建目录会——这条是防呆）。
for arch in $ARCHS; do
    AMIN="$(vtool -arch "$arch" -show-build "$MBIN" 2>/dev/null | awk '/minos/ {print $2; exit}')"
    [ "$AMIN" = "$MIN_MACOS" ] || {
        echo "make-dmg: $arch 切片 minos=${AMIN} 与 plist LSMinimumSystemVersion=${MIN_MACOS} 不一致" >&2
        exit 1
    }
done
say "minos     ${MIN_MACOS}（两切片一致）"

# ⑥ 验 C：签名 seal 在拷贝+挂载后仍完整。这一步在开发机上常常「意外地过」，
#    但在别人机器上失败时表现是「已损坏，无法打开」——所以必须在这里拦。
codesign --verify --strict "$MNT/$(basename "$APP")" >/dev/null 2>&1 \
    || { echo "make-dmg: 挂载卷里的包验签不过（ditto 丢失 seal 或签名被改）" >&2; exit 1; }
say "codesign  --verify --strict ok"

# ⑦ 验 D：包内身份自证仍在。BUILD-INFO 与二进制必须同步搬过来（两份都得对，缺一不可）。
MVERSION="$("$MBIN" --version 2>/dev/null | sed -n 's/^package: //p')"
[ "$MVERSION" = "$PACK_LINE" ] || {
    echo "make-dmg: 挂载卷里 --version 的 package 行与 BUILD-INFO 不一致" >&2
    echo "  --version : ${MVERSION:-<空>}" >&2
    echo "  buildinfo : $PACK_LINE" >&2
    exit 1
}
say "version   package 行与 BUILD-INFO 一致"

# ⑧ 验 E：真跑一次（带数据根）。挂载卷里没有同级 GameData，所以显式给数据根；
#    不给的话这台上会命中「data-root 指针指向的绝对路径」，验不出别人的处境。
[ -d "$DATA_ROOT/local_data" ] || { echo "make-dmg: 数据根不可用: $DATA_ROOT" >&2; exit 1; }
CONCORD_DATA_ROOT="$DATA_ROOT" "$MBIN" --smoke-test >/dev/null 2>&1 \
    || { echo "make-dmg: 挂载卷里的二进制 --smoke-test 失败" >&2; exit 1; }
say "smoke     --smoke-test rc=0（CONCORD_DATA_ROOT=${DATA_ROOT}）"

# ⑨ 跨机模拟——dmg 的真正意义就在这一步。
#
#    挂载卷里跑通只能证明「在这台机器上能跑」：包内 data-root 指针写的是构建机的绝对
#    路径，本机上它当然解析得到（所以本机 `CONCORD_DATA_ROOT=/nonexistent` 也压不掉它，
#    指针优先级高于环境变量）。要让 dmg 的说明书对**别人**成立，必须造出「别人机器」
#    的样子：把包拷到临时目录，指针改成不存在的路径，重签，再判两件事——
#      (a) 没有数据树时，必须**明确说找不到**（`data root NOT found`），不许静默成功；
#      (b) 把数据树放成 .app 同级目录后，必须 `source=sibling` 命中。
#    (b) 成立，「拖进 Applications + 旁边放数据树就能玩」才是被验过的说法，而不是一句承诺。
SIM="$(mktemp -d /tmp/concord-dmg-foreign.XXXXXX)"
trap 'cleanup; rm -rf "$SIM" 2>/dev/null || true' EXIT
SIM_APP="$SIM/$(basename "$APP")"
ditto "$MNT/$(basename "$APP")" "$SIM_APP"
printf '/nonexistent/concord-data-root\n' > "$SIM_APP/Contents/Resources/data-root"
codesign --force -s - "$SIM_APP" >/dev/null 2>&1 || {
    echo "make-dmg: 模拟包重签失败（跨机模拟做不下去）" >&2; exit 1
}
SIM_BIN="$SIM_APP/Contents/MacOS/concord_runtime"

NODATA_LINE="$(cd "$SIM" && "$SIM_BIN" --smoke-test 2>&1 | grep -m1 'data root NOT found' || true)"
[ -n "$NODATA_LINE" ] || {
    echo "make-dmg: 没有数据树时没有报 'data root NOT found'（静默成功比报错更糟）" >&2
    exit 1
}
say "foreign   (a) 无数据树 → $(printf '%s' "$NODATA_LINE" | cut -c1-90)"

# 数据树目录名不限：兄弟目录是「枚举父目录下的子目录再按内容判定」，
# 判据是同时含 local_data/ 与 RedAlert2/（第 55 轮实测：改名成 GameData 一样命中）。
ln -s "$(cd "$DATA_ROOT" && pwd)" "$SIM/ConcordRTS-GameData"
SIB_LINE="$(cd "$SIM" && "$SIM_BIN" --smoke-test 2>&1 | grep -m1 'data root.*source=' || true)"
case "$SIB_LINE" in
    *source=sibling*) say "foreign   (b) 同级目录 → $(printf '%s' "$SIB_LINE" | cut -c1-96)" ;;
    *) echo "make-dmg: 数据树放成 .app 同级目录后没有 source=sibling 命中；实际：${SIB_LINE:-<无输出>}" >&2
       exit 1 ;;
esac

hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true

printf '%s\n' "dmg: $(basename "$DMG") $(du -h "$DMG" | awk '{print $1}') arch=$(printf '%s' "$ARCHS" | tr ' ' '+') minos=$MIN_MACOS smoke=rc0 version=ok foreign=ok hash=$SHORT_HASH"
