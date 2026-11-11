#!/usr/bin/env python3
"""把 ra2md.csf 的文本从繁体中文转换为简体中文。

格式与 ConcordRTS/src/assets/text/CsfCodec.cpp 严格一致：
  " FSC" + ver + labelCount + stringCount + unused + langid (共 24 字节头)
  每条目: " LBL" + stringCount + labelLen + label
          + (" RTS" | "WRTS") + charCount + charCount*2 字节 (每字符 XOR 0xFFFF 的 UTF-16)
          WRTS 另有 extraLength + extra 字节

用法: python3 convert_csf_t2s.py <in.csf> <out.csf> <game.fnt>
转换用 zhconv (zh-hans)，并对照 game.fnt 的字形索引表报告缺字。
"""
import struct
import sys

from zhconv import convert as zh_convert

# zhconv 个别转换产生 Ext A 生僻字（字体缺字形），手工纠偏为常用简体字
OVERRIDES = {"㑩": "猡"}


def t2s(text: str) -> str:
    out = zh_convert(text, "zh-hans")
    for bad, good in OVERRIDES.items():
        out = out.replace(bad, good)
    return out


def decode(raw: bytes) -> str:
    return "".join(
        chr(struct.unpack_from("<H", raw, i)[0] ^ 0xFFFF)
        for i in range(0, len(raw) - len(raw) % 2, 2)
    )


def encode(text: str) -> bytes:
    out = bytearray()
    for ch in text:
        out += struct.pack("<H", ord(ch) ^ 0xFFFF)
    return bytes(out)


def main() -> int:
    src, dst, fnt_path = sys.argv[1], sys.argv[2], sys.argv[3]
    data = open(src, "rb").read()
    fnt = open(fnt_path, "rb").read()
    glyph_count = struct.unpack_from("<I", fnt, 20)[0]

    def has_glyph(ch: str) -> bool:
        ref = struct.unpack_from("<H", fnt, 0x1C + ord(ch) * 2)[0]
        return 0 < ref <= glyph_count

    label_count = struct.unpack_from("<I", data, 8)[0]
    header = data[:24]
    pos = 24
    entries = []  # (stringCount, label, [(tag, text, extra_bytes)])
    while pos < len(data):
        if data[pos:pos + 4] != b" LBL":
            pos += 1
            continue
        scount = struct.unpack_from("<I", data, pos + 4)[0]
        ln = struct.unpack_from("<I", data, pos + 8)[0]
        label = data[pos + 12:pos + 12 + ln].decode("ascii", "replace")
        pos += 12 + ln
        strings = []
        for _ in range(scount):
            tag = data[pos:pos + 4]
            ccnt = struct.unpack_from("<I", data, pos + 4)[0]
            text = decode(data[pos + 8:pos + 8 + ccnt * 2])
            pos += 8 + ccnt * 2
            extra = b""
            if tag == b"WRTS":
                el = struct.unpack_from("<I", data, pos)[0]
                extra = data[pos + 4:pos + 4 + el]
                pos += 4 + el
            strings.append((tag, text, extra))
        entries.append((scount, label, strings))

    print(f"labels={len(entries)} (header={label_count})")

    out = bytearray(header)
    missing = {}
    converted = 0
    for scount, label, strings in entries:
        out += b" LBL"
        out += struct.pack("<I", scount)
        lab = label.encode("ascii")
        out += struct.pack("<I", len(lab)) + lab
        for tag, text, extra in strings:
            body, null = text, ""
            if body.endswith("\u0000"):
                body, null = body[:-1], "\u0000"
            new = t2s(body) + null
            for ch in new:
                if ch.isascii() or ord(ch) < 0x2E80:
                    continue
                if not has_glyph(ch):
                    missing.setdefault(ch, []).append(label)
            enc = encode(new)
            out += tag + struct.pack("<I", len(new)) + enc
            if extra:
                out += struct.pack("<I", len(extra)) + extra
            converted += 1
    print(f"strings converted={converted}")
    if missing:
        print("缺少字形的字符:")
        for ch, labs in sorted(missing.items()):
            print(f"  {ch!r} U+{ord(ch):04X} x{len(labs)} 例:{labs[0]}")
    open(dst, "wb").write(bytes(out))
    print(f"wrote {dst} size={len(out)} (orig={len(data)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
