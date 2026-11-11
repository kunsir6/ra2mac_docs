#!/usr/bin/env python3
"""给 GAME.FNT 补简体字形。

繁体中文版的 game.fnt 里，简体专用字全部指向同一个「豆腐块」占位字形（如 #345），
所以 CSF 转简体后这些字会显示成空心方框。本脚本扫描 CSF 实际用到的汉字，找出落在
占位字形上的字，用系统字体按原字体规格（stride*8 宽、bitmapRows 高、1bpp）重新
栅格化，追加到字形表尾部并改写码位索引，同时更新 header 的 glyphCount。

用法: python3 patch_fnt_simplified.py <game.fnt> <csf> [--font PATH] [--size N] [--dry-run]

规格取自 WestwoodFontCodec.cpp：
  header 28 字节 + 65536*2 码表 + glyphCount*recordSize 字形记录
  record = 1 字节宽度 + stride*bitmapRows 字节位图（MSB 优先，行优先）
"""
import argparse
import struct
import sys
from collections import defaultdict

from PIL import Image, ImageDraw, ImageFont

CJK_MIN = 0x2E80


def read_metrics(fnt):
    stride, rows, line_h, count, rec = struct.unpack_from("<5I", fnt, 8)
    return stride, rows, line_h, count, rec


def csf_chars(path):
    data = open(path, "rb").read()

    def decode(raw):
        return "".join(
            chr(struct.unpack_from("<H", raw, i)[0] ^ 0xFFFF)
            for i in range(0, len(raw), 2)
        )

    chars = {}
    pos = 24
    while pos < len(data):
        if data[pos:pos + 4] == b" LBL":
            scount = struct.unpack_from("<I", data, pos + 4)[0]
            ln = struct.unpack_from("<I", data, pos + 8)[0]
            label = data[pos + 12:pos + 12 + ln].decode("ascii", "replace")
            pos += 12 + ln
            for _ in range(scount):
                tag = data[pos:pos + 4]
                ccnt = struct.unpack_from("<I", data, pos + 4)[0]
                for ch in decode(data[pos + 8:pos + 8 + ccnt * 2]):
                    if ord(ch) >= CJK_MIN:
                        chars.setdefault(ch, label)
                pos += 8 + ccnt * 2
                if tag == b"WRTS":
                    el = struct.unpack_from("<I", data, pos)[0]
                    pos += 4 + el
        else:
            pos += 1
    return chars


def rasterize(ch, font_path, size, width_bits, rows, top_offset=1):
    font = ImageFont.truetype(font_path, size, index=0)
    canvas = Image.new("1", (width_bits * 2, rows * 2), 0)
    ImageDraw.Draw(canvas).text((4, 0), ch, font=font, fill=1)
    # "1" 模式下墨迹为 255，getbbox() 直接给出墨迹包围盒
    bbox = canvas.getbbox()
    if not bbox:
        return None
    ink = canvas.crop(bbox)
    if ink.size[0] > width_bits or ink.size[1] > rows - top_offset:
        return None
    bitmap = [[0] * width_bits for _ in range(rows)]
    px = ink.load()
    for y in range(ink.size[1]):
        for x in range(ink.size[0]):
            if px[x, y]:
                bitmap[y + top_offset][x] = 1
    return ink.size[0], bitmap


def pack(bitmap, stride, rows):
    out = bytearray()
    for y in range(rows):
        bits = "".join(str(b) for b in bitmap[y])
        bits = bits.ljust(stride * 8, "0")
        for i in range(stride):
            out.append(int(bits[i * 8:(i + 1) * 8], 2))
    return bytes(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("fnt")
    ap.add_argument("csf")
    ap.add_argument("--font", default="/System/Library/Fonts/Hiragino Sans GB.ttc")
    ap.add_argument("--size", type=int, default=15)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    fnt = open(args.fnt, "rb").read()
    stride, rows, line_h, count, rec = read_metrics(fnt)
    data_off = 0x1C + 65536 * 2
    width_bits = stride * 8
    assert rec == 1 + stride * rows, (rec, stride, rows)
    print(f"font: stride={stride} rows={rows} glyphs={count} rec={rec} size={len(fnt)}")

    chars = csf_chars(args.csf)
    print(f"csf distinct CJK chars: {len(chars)}")

    refs = defaultdict(list)
    for ch in chars:
        refs[struct.unpack_from("<H", fnt, 0x1C + ord(ch) * 2)[0]].append(ch)
    # 多个不同汉字共用同一字形 => 占位字形（正常字形不会共用）
    placeholder = {r for r, v in refs.items() if len(v) > 1}
    placeholder.discard(0)
    targets = sorted(ch for ch in chars
                     if struct.unpack_from("<H", fnt, 0x1C + ord(ch) * 2)[0] in placeholder)
    print(f"placeholder refs={sorted(placeholder)} 需要补字的字符={len(targets)}")
    if not targets:
        print("无缺字，直接退出")
        return 0

    body = bytearray(fnt)
    added = 0
    failed = []
    for ch in targets:
        result = rasterize(ch, args.font, args.size, width_bits, rows)
        if result is None:
            failed.append(ch)
            continue
        ink_w, bitmap = result
        advance = min(ink_w + 1, width_bits)
        record = bytes([advance]) + pack(bitmap, stride, rows)
        body += record
        added += 1
        struct.pack_into("<H", body, 0x1C + ord(ch) * 2, count + added)
    struct.pack_into("<I", body, 20, count + added)
    print(f"补入 {added} 个字形，失败 {len(failed)}: {''.join(failed) if failed else '-'}")
    if args.dry_run:
        print("dry-run 不写文件")
        return 0
    open(args.fnt, "wb").write(bytes(body))
    print(f"写出 {args.fnt} size={len(body)} (原 {len(fnt)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
