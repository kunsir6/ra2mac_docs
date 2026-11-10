#!/usr/bin/env python3
"""
prepare-game-assets.py — 从原始 RA2/YR 游戏目录生成 ConcordRTS 可用的独立资源包。

背景：
  ConcordRTS 运行时的资源根是 local_data/resources/mix_exports/，
  并以「先散文件、后 MIX 归档」的顺序解析资源（见 MapPreviewExporter.cpp
  的 buildMixArchiveIndex / buildOverlayFileIndex）。因此本脚本做三件事：

    1. 把原版 MIX 归档按 <stem>/<stem>.mix 放好 —— 引擎递归扫描即可按 ID 命中条目；
    2. 把代码里以真实路径引用的内层 MIX（local.mix / audio.mix / sidec01.mix …）
       抽成独立文件 —— 这些地方要求真实文件路径，不能再躺在归档里；
    3. 把只接受散文件路径的关键资源（game.fnt / ra2md.csf / thememd.ini / 规则 INI /
       地图 .mmx .yro / missionsmd.pkt 列出的官方地图）抽出来。

MIX 条目只存 32 位文件名哈希、不存名字，所以「按名提取」的前提是能复现哈希。
本脚本实现了与 MixArchive::mixFileIdFromName 完全一致的 Westwood CRC32：
    大写文件名 → 长度补齐到 4 的倍数 → CRC32(0xEDB88320) → 取反
已用 game.fnt / ra2md.csf / keyboardmd.ini / glslmd.shp 四个样本与原版比对通过。

用法：
    python3 scripts/prepare-game-assets.py \
        --source RA2 \
        --out ConcordRTS-GameData \
        --dump ConcordRTS/build-product-mac/concord_rules_dump

    # 带上过场动画（+1.0 GB）
    ... --with-movies

    # 只打印计划，不落盘
    ... --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import zlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# --------------------------------------------------------------------------
# Westwood 文件名哈希
# --------------------------------------------------------------------------


def westwood_id(name: str) -> int:
    """复现 MixArchive::mixFileIdFromName。"""
    upper = name.upper()
    raw = bytearray(upper.encode("ascii", "replace"))
    size = len(raw)
    if size & 3:
        raw.append(size & 3)
        whole = size >> 2
        pad_from = whole << 2
        pad_count = 3 - ((len(raw) - 1) & 3)
        for _ in range(pad_count):
            raw.append(raw[pad_from])
    return zlib.crc32(bytes(raw)) & 0xFFFFFFFF


# --------------------------------------------------------------------------
# 归档布局
# --------------------------------------------------------------------------

# 顶层 MIX → mix_exports 下的目录名。目录名同时是引擎松散层搜索目录名。
TOP_LEVEL_ARCHIVES: dict[str, str] = {
    "ra2.mix": "ra2",
    "ra2md.mix": "ra2md",
    "langmd.mix": "langmd",
    "LANGUAGE.MIX": "language",
    "expand01.mix": "expand01",
    "expandmd01.mix": "expandmd01",
    "multimd.mix": "multimd",
    "mapsmd03.mix": "mapsmd03",
    "MAPS01.MIX": "maps01",
    "MAPS02.MIX": "maps02",
    "MULTI.MIX": "multi",
    "THEME.MIX": "theme",
    "thememd.mix": "thememd",
    "WDT.MIX": "wdt",
    "Ecache01.mix": "ecache01",
}

MOVIE_ARCHIVES: dict[str, str] = {
    "movies01.mix": "movies01",
    "movies02.mix": "movies02",
    "movmd03.mix": "movmd03",
}

# 内层 MIX：代码以真实文件路径引用，必须落成独立文件。
# (父归档, 内层文件名, 文件落位目录, 该内层归档散文件的落位目录)
INNER_MIXES: list[tuple[str, str, str, str]] = [
    ("ra2.mix", "local.mix", "ra2", "ra2/local"),
    ("ra2md.mix", "localmd.mix", "ra2md", "ra2md/localmd"),
    ("ra2.mix", "sidec01.mix", "ra2", "ra2"),
    ("ra2.mix", "sidec02.mix", "ra2", "ra2"),
    ("ra2md.mix", "sidec02md.mix", "ra2md", "ra2md"),
    ("LANGUAGE.MIX", "audio.mix", "language", "language"),
    ("langmd.mix", "audiomd.mix", "langmd", "langmd"),
]

# 顶层文件直接作为「内层引用」搬运的情况（campaign / movie 解析硬编码了这些路径）
FILE_ALIASES: list[tuple[str, str]] = [
    # 战役数据源寻找 mix_exports/ra2/Maps01.mix、Maps02.mix
    ("MAPS01.MIX", "ra2/Maps01.mix"),
    ("MAPS02.MIX", "ra2/Maps02.mix"),
    # 战役影片解析器寻找 mix_exports/ra2md/movmd03.mix
    ("movmd03.mix", "ra2md/movmd03.mix"),
]

# 只接受散文件路径、必须从归档里抽出来的关键资源
# (输出相对 mix_exports 的路径, [(父归档, 归档内名字), ...])
ESSENTIAL_LOOSE: list[tuple[str, list[tuple[str, str]]]] = [
    ("ra2md/localmd/rulesmd.ini", [("ra2md.mix!localmd.mix", "rulesmd.ini")]),
    ("ra2md/localmd/artmd.ini", [("ra2md.mix!localmd.mix", "artmd.ini")]),
    ("ra2md/localmd/soundmd.ini", [("ra2md.mix!localmd.mix", "soundmd.ini")]),
    ("ra2md/localmd/evamd.ini", [("ra2md.mix!localmd.mix", "evamd.ini")]),
    ("ra2md/localmd/thememd.ini", [("ra2md.mix!localmd.mix", "thememd.ini")]),
    ("ra2md/localmd/keyboardmd.ini", [("langmd.mix", "keyboardmd.ini")]),
    ("langmd/ra2md.csf", [("langmd.mix", "ra2md.csf")]),
    ("language/ra2.csf", [("LANGUAGE.MIX", "ra2.csf")]),
    ("langmd/missionsmd.pkt", [("langmd.mix", "missionsmd.pkt")]),
    ("langmd/glslmd.shp", [("langmd.mix", "glslmd.shp")]),
    ("langmd/glsmd.pal", [("langmd.mix", "glsmd.pal")]),
]

# RedAlert2/GameMD 下的散文件（资源根，非 mix_exports）
# 代码里的候选顺序：resourceRoot/GameMD/x 优先，失败才看 mix_exports。
REDALERT2_LOOSE: list[tuple[str, list[tuple[str, str]]]] = [
    ("GameMD/game.fnt", [("ra2.mix!local.mix", "game.fnt"), ("ra2md.mix!localmd.mix", "game.fnt")]),
    ("GameMD/ra2md.csf", [("langmd.mix", "ra2md.csf")]),
    ("GameMD/thememd.ini", [("ra2md.mix!localmd.mix", "thememd.ini")]),
]

# 直接拷贝的松散资源（相对源目录 → 目标 mix_exports 子目录）
LOOSE_GLOB_COPIES: list[tuple[str, str]] = [
    # 玩家自定义/下载的遭遇战地图
    ("*.mmx", "multimd"),
    ("*.yro", "multimd"),
    # 中文版/原版的启动图
    ("launchermd.bmp", "langmd"),
    ("LAUNCHER.BMP", "language"),
]

# 直接拷进资源根（RedAlert2/）的松散资源
RESOURCE_ROOT_COPIES: list[tuple[str, str]] = [
    # 代码在 resourceRoot/Taunts 或 resourceRoot/GameMD/Taunts 下找叫嚣语音
    ("Taunts", "Taunts"),
]

# 需要在 local_data 根再放一份的规则文件（主菜单只查这个位置）
LOCAL_DATA_ROOT_COPIES: list[tuple[tuple[str, str], str]] = [
    (("ra2md.mix!localmd.mix", "rulesmd.ini"), "rulesmd.ini"),
    (("ra2md.mix!localmd.mix", "artmd.ini"), "artmd.ini"),
]

# 从源码里抓资源文件名字面量，用于「按名收割」
SOURCE_LITERAL_RE = re.compile(
    r'"([A-Za-z0-9_\-]{2,24}\.(?:shp|sha|pal|vxl|hva|tmp|fnt|pkt|csf|map|mpr|mmx|yro|yrm|mix|aud|bik|vqa|pcx|bmp))"',
    re.IGNORECASE,
)

# 源码字面量覆盖不到、但运行时明显会找的补充名单
EXTRA_CANDIDATES = """
shell.pal sdbtnanm.pal mainbttn.pal mousepal.pal anim.pal unittem.pal uniturb.pal
unitsno.pal unitubn.pal unitlun.pal unitsed.pal unitdes.pal
isodes.pal isotem.pal isosno.pal isourb.pal isoubn.pal isolun.pal isodes.pal
libtem.pal liburb.pal libsno.pal libubn.pal liblun.pal libdes.pal
mnscrnl.shp lwscrnl.shp sdtp.shp sdwrnanm.shp sdbtnbkgd.shp sdbtnanm.shp
sdbtm.shp mnbttn.shp mouse.shp glslmd.shp ra2ts_l_frame.bmp
mouse.sha sidebar.shp radar.shp
temperat.ini temperatmd.ini snow.ini snowmd.ini urban.ini urbanmd.ini
desert.ini desertmd.ini lunar.ini lunarmd.ini newurban.ini urbann.ini
rules.ini art.ini sound.ini eva.ini theme.ini keyboard.ini ai.ini battle.ini
mpmodesmd.ini mapselmd.ini
ra2.csf ra2md.csf game.fnt score.fnt
""".split()


# --------------------------------------------------------------------------
# Q-01：从 art*.ini 派生单位/建筑美术基名，再按哈希从归档精确抽取
# --------------------------------------------------------------------------

# art 段名派生出的基名，按这些扩展名逐个去归档里查哈希。
# .vxl/.hva 是体素单位；.shp 是步兵/建筑/动画；其余是剧场专用的建筑与覆盖物图。
ART_EXTENSIONS: tuple[str, ...] = (
    ".vxl",
    ".hva",
    ".shp",
    ".tem",
    ".sno",
    ".urb",
    ".ubn",
    ".des",
    ".lun",
)

# 只扫这几个顶层目录下的归档。地图归档（multimd / maps*）与美术无关，跳过。
ART_SCAN_FOLDERS: tuple[str, ...] = ("ra2", "ra2md", "expandmd01", "expand01", "langmd", "language")

# 剧场归档 → 输出分组键。分组名直接取自归档文件名，不去猜剧场后缀，
# 因此同一基名在不同剧场的不同版本不会被压成一份。
THEATER_ARCHIVE_GROUPS: dict[str, str] = {
    "temperat.mix": "temperat",
    "isotemp.mix": "temperat",
    "snow.mix": "snow",
    "isosnow.mix": "snow",
    "snowmd.mix": "snow",
    "isosnomd.mix": "snow",
    "urban.mix": "urban",
    "isourb.mix": "urban",
    "urbann.mix": "urbann",
    "isoubn.mix": "urbann",
    "isoubnmd.mix": "urbann",
    "desert.mix": "desert",
    "isodes.mix": "desert",
    "lunar.mix": "lunar",
    "isolun.mix": "lunar",
}

ART_OUTPUT_ROOT = "art"
ART_INVENTORY_NAME = "art-inventory.json"

# 段名与 Image= 都可能给出资源基名。先读 YR 的 artmd/rulesmd，再读基础版的 art/rules。
ART_INI_SOURCES: tuple[str, ...] = (
    "ra2/local/art.ini",
    "ra2md/localmd/artmd.ini",
    "ra2/local/rules.ini",
    "ra2md/localmd/rulesmd.ini",
)

# 基名只允许这些字符，避免把注释或空值当文件名去算哈希。
ART_NAME_RE = re.compile(r"^[A-Z0-9_\-]{2,24}$")

# NewTheater=yes 的建筑在归档里以「第二个字符 = 剧场字母」的兄弟名存在：
# GAPOWR（雪地）在 snow.mix、GGPOWR（通用/温带默认）在 generic.mix，两者尺寸相同、
# 内容不同（md5 不同，实为同一建筑的两种剧场美术）。字母集取自项目自身
# MapPreviewExporter::newTheaterCharForExtension 的映射，这里按全集合去试，
# 只有真正存在的条目才会落盘。
NEW_THEATER_NAME_RE = re.compile(r"^[GNCY][A-Z0-9]{2,23}$")
NEW_THEATER_CHARS: tuple[str, ...] = ("G", "A", "U", "D", "L", "N", "T")


@dataclass
class ArchiveIndex:
    """一个已被读入索引的 MIX 归档。"""

    label: str          # 诊断名，如 "ra2md.mix!localmd.mix"
    path: Path          # 磁盘上的真实文件
    out_dir: str        # 提取散文件时的落位目录（相对 mix_exports）
    entries: dict[int, tuple[int, int]] = field(default_factory=dict)  # id -> (offset, size)


class Packager:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.source = Path(args.source).resolve()
        self.out = Path(args.out).resolve()
        self.dump = Path(args.dump).resolve()
        self.mix_exports = self.out / "local_data" / "resources" / "mix_exports"
        self.redalert2 = self.out / "RedAlert2"
        self.archives: dict[str, ArchiveIndex] = {}
        self.extracted: list[dict[str, object]] = []
        self.done: set[str] = set()
        self.warnings: list[str] = []
        self.calls = 0

    # -- 基础设施 ---------------------------------------------------------

    def log(self, message: str) -> None:
        print(message, flush=True)

    def run_dump(self, *argv: str) -> str:
        self.calls += 1
        proc = subprocess.run(
            [str(self.dump), *argv],
            capture_output=True,
            text=True,
            check=False,
        )
        return (proc.stdout or "") + (proc.stderr or "")

    @staticmethod
    def replace_file(source: Path, target: Path) -> None:
        """先写临时文件再原子改名，避免「先删后写」的破坏性操作。"""
        target.parent.mkdir(parents=True, exist_ok=True)
        os.replace(source, target)

    def extract_to(self, archive_path: Path, name: str, target: Path) -> bool:
        """从归档提取单个条目到 target，成功返回 True。"""
        target.parent.mkdir(parents=True, exist_ok=True)
        scratch = target.parent / f"{target.name}.{self.calls}.part"
        self.run_dump(
            "--mix", str(archive_path), "--extract-mix-file", name, "--output", str(scratch)
        )
        if not scratch.is_file() or scratch.stat().st_size == 0:
            return False
        self.replace_file(scratch, target)
        return True

    def ensure_dump(self) -> None:
        if not self.dump.is_file():
            raise SystemExit(
                f"找不到 concord_rules_dump: {self.dump}\n"
                "先构建：cmake --build <build-dir> --target concord_rules_dump"
            )
        if not os.access(self.dump, os.X_OK):
            raise SystemExit(f"concord_rules_dump 不可执行: {self.dump}")

    # -- 阶段 1：拷贝归档 -------------------------------------------------

    def copy_archives(self) -> None:
        plans: dict[str, str] = dict(TOP_LEVEL_ARCHIVES)
        if self.args.with_movies:
            plans.update(MOVIE_ARCHIVES)

        for archive_name, folder in plans.items():
            src = self.source / archive_name
            if not src.is_file():
                self.warnings.append(f"缺少归档 {archive_name}，跳过")
                continue
            dst_dir = self.mix_exports / folder
            dst = dst_dir / archive_name
            size = src.stat().st_size
            if self.args.dry_run:
                self.log(f"  [计划] {archive_name} -> mix_exports/{folder}/")
            else:
                dst_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
            self.extracted.append(
                {"kind": "archive", "name": archive_name, "to": str(dst.relative_to(self.out)), "bytes": size}
            )
            self.log(f"  归档 {archive_name:16s} -> mix_exports/{folder}/  {size/1048576:8.1f} MB")

    # -- 阶段 2：索引 + 内层 MIX ------------------------------------------

    def index_archive(self, label: str, path: Path, out_dir: str) -> ArchiveIndex | None:
        if not path.is_file():
            return None
        output = self.run_dump("--mix", str(path), "--list-mix")
        if "Index readable:" in output and "no" in output.split("Index readable:")[1][:12]:
            self.warnings.append(f"{label} 索引不可读")
            return None
        entries: dict[int, tuple[int, int]] = {}
        for line in output.splitlines():
            match = re.match(r"\s*(0x[0-9A-Fa-f]{8})\s+(\d+)\s+(\d+)\s+\d+\s*$", line)
            if match:
                entries[int(match.group(1), 16)] = (int(match.group(2)), int(match.group(3)))
        if not entries:
            self.warnings.append(f"{label} 未解析到条目")
            return None
        index = ArchiveIndex(label=label, path=path, out_dir=out_dir, entries=entries)
        self.archives[label] = index
        self.log(f"  索引 {label:28s} 条目 {len(entries):5d}")
        return index

    def extract_inner_mixes(self) -> None:
        for parent_name, inner_name, folder, _loose_dir in INNER_MIXES:
            parent = self.mix_exports / TOP_LEVEL_ARCHIVES[parent_name] / parent_name
            if not parent.is_file():
                self.warnings.append(f"内层提取跳过：缺少 {parent_name}")
                continue
            dst_dir = self.mix_exports / folder
            dst = dst_dir / inner_name
            if self.args.dry_run:
                self.log(f"  [计划] {parent_name}!{inner_name} -> mix_exports/{folder}/{inner_name}")
                continue
            if not self.extract_to(parent, inner_name, dst):
                self.warnings.append(f"内层提取失败 {parent_name}!{inner_name}")
                continue
            self.done.add(f"{folder}/{inner_name}")
            self.extracted.append(
                {
                    "kind": "inner-mix",
                    "name": inner_name,
                    "from": parent_name,
                    "to": str(dst.relative_to(self.out)),
                    "bytes": dst.stat().st_size,
                }
            )
            self.log(f"  内层 {parent_name}!{inner_name:14s} -> mix_exports/{folder}/  {dst.stat().st_size/1048576:7.1f} MB")

    def index_all(self) -> None:
        """给顶层归档与已抽出的内层归档建索引。"""
        for archive_name, folder in TOP_LEVEL_ARCHIVES.items():
            path = self.mix_exports / folder / archive_name
            self.index_archive(archive_name, path, folder)
        for parent_name, inner_name, folder, loose_dir in INNER_MIXES:
            path = self.mix_exports / folder / inner_name
            self.index_archive(f"{parent_name}!{inner_name}", path, loose_dir)

    # -- 阶段 3：按名提取 -------------------------------------------------

    def extract_named(self, archive_label: str, name: str, out_rel: str) -> bool:
        archive = self.archives.get(archive_label)
        if archive is None:
            return False
        wanted = westwood_id(name)
        if wanted not in archive.entries:
            return False
        dst = self.mix_exports / out_rel
        if out_rel in self.done:
            return True
        if self.args.dry_run:
            self.log(f"  [计划] {archive_label}!{name} -> {out_rel}")
            return True
        if not self.extract_to(archive.path, name, dst):
            return False
        self.done.add(out_rel)
        self.extracted.append(
            {
                "kind": "loose",
                "name": name,
                "from": archive_label,
                "to": str(dst.relative_to(self.out)),
                "bytes": dst.stat().st_size,
            }
        )
        return True

    def extract_essential(self) -> None:
        for out_rel, candidates in ESSENTIAL_LOOSE:
            done = False
            for archive_label, name in candidates:
                if self.extract_named(archive_label, name, out_rel):
                    done = True
                    break
            if not done:
                self.warnings.append(f"关键资源未取到：{out_rel}")

    def harvest_source_literals(self) -> None:
        """把 ConcordRTS 源码里出现过的资源文件名字面量逐个尝试提取。"""
        src_root = Path(self.args.repo).resolve() / "src"
        if not src_root.is_dir():
            self.warnings.append(f"源码目录不存在，跳过字面量收割：{src_root}")
            return
        names: set[str] = set(EXTRA_CANDIDATES)
        for path in src_root.rglob("*"):
            if path.suffix.lower() not in {".cpp", ".h", ".inl"}:
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for match in SOURCE_LITERAL_RE.finditer(text):
                names.add(match.group(1))
        self.log(f"  候选名字 {len(names)} 个")

        # 搜索顺序按引擎的松散层优先级：更可能被优先命中的放前面
        order = [
            "ra2md.mix!localmd.mix",
            "LANGUAGE.MIX",
            "langmd.mix",
            "expandmd01.mix",
            "ra2md.mix",
            "ra2.mix",
            "ra2.mix!local.mix",
            "expand01.mix",
            "ra2md.mix!sidec02md.mix",
            "ra2.mix!sidec01.mix",
            "ra2.mix!sidec02.mix",
        ]
        wanted_ids = {westwood_id(n): n for n in names}
        hits: list[tuple[str, str]] = []
        for label in order:
            archive = self.archives.get(label)
            if archive is None:
                continue
            for entry_id in archive.entries:
                if entry_id in wanted_ids:
                    hits.append((label, wanted_ids[entry_id]))
        self.log(f"  命中 {len(hits)} 个条目")

        extracted = 0
        for label, name in hits:
            archive = self.archives[label]
            out_rel = f"{archive.out_dir}/{name}"
            if self.extract_named(label, name, out_rel):
                extracted += 1
        self.log(f"  已落盘 {extracted} 个散文件")

    def harvest_official_maps(self) -> None:
        """用 missionsmd.pkt 的清单把官方遭遇战地图抽成散文件。"""
        packet = self.mix_exports / "langmd" / "missionsmd.pkt"
        if not packet.is_file():
            self.warnings.append("缺 missionsmd.pkt，跳过官方地图提取")
            return
        names: list[str] = []
        for line in packet.read_text(encoding="latin-1", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith(";") or line.startswith("["):
                continue
            if "=" in line:
                names.append(line.split("=", 1)[1].strip())
        self.log(f"  missionsmd.pkt 地图条目 {len(names)} 个")

        found = 0
        for stem in names:
            for ext in (".map", ".yro", ".mmx", ".mpr", ".yrm"):
                if self.extract_named("multimd.mix", stem + ext, f"multimd/{stem.lower()}{ext}"):
                    found += 1
                    break
        self.log(f"  官方地图落盘 {found} 张")

    def copy_loose_files(self) -> None:
        for pattern, folder in LOOSE_GLOB_COPIES:
            for src in sorted(self.source.glob(pattern)):
                if not src.is_file():
                    continue
                dst = self.mix_exports / folder / src.name.lower()
                if self.args.dry_run:
                    continue
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                self.extracted.append(
                    {
                        "kind": "loose-copy",
                        "name": src.name,
                        "to": str(dst.relative_to(self.out)),
                        "bytes": src.stat().st_size,
                    }
                )
        count = sum(1 for item in self.extracted if item["kind"] == "loose-copy")
        self.log(f"  直接拷贝散文件 {count} 个")

    # -- 阶段 4：RedAlert2 资源根 ----------------------------------------

    def build_resource_root(self) -> None:
        for out_rel, candidates in REDALERT2_LOOSE:
            target = self.redalert2 / out_rel
            source_archive = None
            for archive_label, name in candidates:
                archive = self.archives.get(archive_label)
                if archive is None:
                    continue
                if westwood_id(name) not in archive.entries:
                    continue
                source_archive = (archive, name)
                break
            if source_archive is None:
                self.warnings.append(f"资源根文件未取到：{out_rel}")
                continue
            archive, name = source_archive
            if self.args.dry_run:
                self.log(f"  [计划] {archive.label}!{name} -> RedAlert2/{out_rel}")
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            if self.extract_to(archive.path, name, target):
                self.extracted.append(
                    {
                        "kind": "resource-root",
                        "name": name,
                        "from": archive.label,
                        "to": str(target.relative_to(self.out)),
                        "bytes": target.stat().st_size,
                    }
                )
                self.log(f"  资源根 RedAlert2/{out_rel}  {target.stat().st_size/1024:7.1f} KB")

    # -- 阶段 5：音乐、叫嚣语音、根级规则 ---------------------------------

    def copy_resource_root_extras(self) -> None:
        for rel, target_rel in RESOURCE_ROOT_COPIES:
            src = self.source / rel
            if not src.exists():
                self.warnings.append(f"资源根附加项缺失：{rel}")
                continue
            dst = self.redalert2 / target_rel
            if self.args.dry_run:
                self.log(f"  [计划] {rel}/ -> RedAlert2/{target_rel}/")
                continue
            shutil.copytree(src, dst, dirs_exist_ok=True)
            count = sum(1 for _ in dst.rglob("*") if _.is_file())
            size = sum(f.stat().st_size for f in dst.rglob("*") if f.is_file())
            self.extracted.append(
                {
                    "kind": "loose-copy",
                    "name": f"{rel}/ ({count} 文件)",
                    "to": str(dst.relative_to(self.out)),
                    "bytes": size,
                }
            )
            self.log(f"  资源根 RedAlert2/{target_rel}/  {count} 个 / {size/1048576:.1f} MB")

    def write_local_data_rules(self) -> None:
        """README 记录的布局里 local_data 根还有 rulesmd.ini / artmd.ini。"""
        for (archive_label, name), out_name in LOCAL_DATA_ROOT_COPIES:
            src = self.mix_exports / "ra2md" / "localmd" / name
            if not src.is_file():
                self.warnings.append(f"local_data 根规则缺失：{name}")
                continue
            dst = self.out / "local_data" / out_name
            if self.args.dry_run:
                self.log(f"  [计划] local_data/{out_name}")
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            self.log(f"  规则 local_data/{out_name}  {dst.stat().st_size/1024:.1f} KB")

    def extract_music(self) -> None:
        """按 thememd.ini 的 Sound= 值把音乐轨从主题归档里抽出来。"""
        catalog = self.redalert2 / "GameMD" / "thememd.ini"
        if not catalog.is_file():
            self.warnings.append("缺 thememd.ini，跳过音乐提取")
            return
        sounds: list[str] = []
        for line in catalog.read_text(encoding="latin-1", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith(";"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                if key.strip().lower() == "sound":
                    value = value.strip()
                    if value:
                        sounds.append(value)
        sounds = list(dict.fromkeys(sounds))
        self.log(f"  thememd.ini 音乐轨 {len(sounds)} 条")

        found = 0
        for sound in sounds:
            for archive_label in ("thememd.mix", "THEME.MIX"):
                folder = TOP_LEVEL_ARCHIVES[archive_label]
                hit = False
                # 原版音乐在归档里是 .wav（不是 .aud），两种扩展都试
                for extension in (".wav", ".aud"):
                    if self.extract_named(
                        archive_label,
                        sound.lower() + extension,
                        f"{folder}/{sound.lower()}{extension}",
                    ):
                        found += 1
                        hit = True
                        break
                if hit:
                    break
        self.log(f"  音乐轨落盘 {found} 条")

    # -- 阶段 5b：art 派生美术（Q-01） ------------------------------------
    @staticmethod
    def read_ini_sections(path: Path) -> dict[str, dict[str, str]]:
        """轻量 INI 读取：段名大写、键小写、去掉行尾注释。"""
        sections: dict[str, dict[str, str]] = {}
        try:
            text = path.read_text(encoding="latin-1", errors="ignore")
        except OSError:
            return sections
        current: str | None = None
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith(";"):
                continue
            if stripped.startswith("[") and stripped.endswith("]"):
                current = stripped[1:-1].strip().upper()
                sections.setdefault(current, {})
                continue
            if current is None or "=" not in stripped:
                continue
            key, _, value = stripped.partition("=")
            sections[current][key.strip().lower()] = value.split(";", 1)[0].strip()
        return sections

    def art_candidate_names(self) -> tuple[set[str], list[str]]:
        """把 art*.ini / rules*.ini 的段名与 Image= 值收成候选基名。"""
        names: set[str] = set()
        used: list[str] = []
        for rel in ART_INI_SOURCES:
            path = self.mix_exports / rel
            if not path.is_file():
                continue
            sections = self.read_ini_sections(path)
            if not sections:
                continue
            used.append(rel)
            for section, body in sections.items():
                names.add(section)
                image = body.get("image", "").upper()
                if image:
                    names.add(image)
        return {n for n in names if ART_NAME_RE.match(n)}, used

    def art_archive_plan(self) -> list[tuple[Path, str, str]]:
        """列出要扫的归档：(真实路径, 分组键, 相对 mix_exports 的路径)。"""
        plan: list[tuple[Path, str, str]] = []
        for folder in ART_SCAN_FOLDERS:
            root = self.mix_exports / folder
            if not root.is_dir():
                continue
            for path in sorted(root.rglob("*")):
                if not path.is_file() or path.suffix.lower() != ".mix":
                    continue
                group = THEATER_ARCHIVE_GROUPS.get(path.name.lower(), "base")
                plan.append((path, group, str(path.relative_to(self.mix_exports))))
        return plan

    def harvest_art(self) -> None:
        """从 art*.ini 段名派生 VXL/HVA/SHP 基名，按 Westwood CRC32 精确抽取。

        输出布局 mix_exports/art/<分组>/<基名>.<ext>：
        分组取自已归档名（base / temperat / snow / urban / urbann / desert / lunar），
        同一基名在不同剧场是不同文件，分目录存放才不会互相覆盖。
        另写 local_data/art-inventory.json 作为「段名 → 文件」的可复算清单。
        """
        names, ini_sources = self.art_candidate_names()
        if not names:
            self.warnings.append("art 派生跳过：没有读到任何 art*.ini")
            return
        self.log(f"  art*.ini 来源 {len(ini_sources)} 个，候选基名 {len(names)} 个")

        wanted: dict[int, tuple[str, str, str]] = {}
        for name in names:
            for extension in ART_EXTENSIONS:
                wanted[westwood_id(name + extension)] = (name, extension, "art")
        base_keys = set(wanted)

        # NewTheater 兄弟名：GAPOWR -> GGPOWR / GAPOWR / GUPOWR …
        theater_variants = 0
        for name in names:
            if not NEW_THEATER_NAME_RE.match(name):
                continue
            for char in NEW_THEATER_CHARS:
                sibling = name[0] + char + name[2:]
                key = westwood_id(sibling + ".shp")
                if key in base_keys:
                    continue
                wanted.setdefault(key, (sibling, ".shp", "newtheater"))
                theater_variants += 1
        self.log(f"  NewTheater 兄弟名候选 {theater_variants} 个")

        archives = self.art_archive_plan()
        hits: dict[tuple[str, str, str], tuple[str, int, str]] = {}
        for archive_path, group, rel in archives:
            output = self.run_dump("--mix", str(archive_path), "--list-mix")
            if "Index readable:" in output:
                if "no" in output.split("Index readable:")[1][:12]:
                    continue
            for line in output.splitlines():
                match = re.match(r"\s*(0x[0-9A-Fa-f]{8})\s+(\d+)\s+(\d+)\s+(\d+)\s*$", line)
                if not match:
                    continue
                name_extension = wanted.get(int(match.group(1), 16))
                if name_extension is None:
                    continue
                key = (name_extension[0], name_extension[1], group)
                if key in hits:
                    # 同一分组内先到先得：归档按路径排序遍历，结果可复算。
                    continue
                hits[key] = (rel, int(match.group(3)), name_extension[2])

        self.log(
            f"  归档 {len(archives)} 个，命中 {len(hits)} 项"
            f"（基名 {len({n for (n, _e, _g) in hits})} 个）"
        )

        entries: list[dict[str, object]] = []
        failed = 0
        for name, extension, group in sorted(hits):
            rel, size, derive = hits[(name, extension, group)]
            out_rel = f"{ART_OUTPUT_ROOT}/{group}/{name.lower()}{extension}"
            if self.args.dry_run:
                self.log(f"  [计划] {rel}!{name}{extension} -> {out_rel}")
                continue
            target = self.mix_exports / out_rel
            if out_rel in self.done:
                continue
            source = self.mix_exports / rel
            if not self.extract_to(source, name + extension, target):
                failed += 1
                self.warnings.append(f"美术抽取失败 {rel}!{name}{extension}")
                continue
            self.done.add(out_rel)
            written = target.stat().st_size
            entries.append(
                {
                    "kind": "art",
                    "name": f"{name}{extension}",
                    "from": rel,
                    "group": group,
                    "derive": derive,
                    "to": str(target.relative_to(self.out)),
                    "bytes": written,
                }
            )

        self.extracted.extend(entries)
        total = sum(int(item["bytes"]) for item in entries)
        self.log(f"  美术落盘 {len(entries)} 个 / {total/1048576:.1f} MB（失败 {failed}）")
        if self.args.dry_run:
            return

        group_counts: dict[str, int] = {}
        extension_counts: dict[str, int] = {}
        derive_counts: dict[str, int] = {}
        for item in entries:
            group_counts[str(item["group"])] = group_counts.get(str(item["group"]), 0) + 1
            extension = str(item["name"]).rsplit(".", 1)[-1]
            extension_counts[extension] = extension_counts.get(extension, 0) + 1
            derive_counts[str(item["derive"])] = derive_counts.get(str(item["derive"]), 0) + 1

        inventory = {
            "generatedBy": "scripts/prepare-game-assets.py",
            "artIniSources": ini_sources,
            "candidateNames": len(names),
            "resolvedNames": len({str(item["name"]).rsplit(".", 1)[0] for item in entries}),
            "itemCount": len(entries),
            "totalBytes": total,
            "groups": group_counts,
            "extensions": extension_counts,
            "derive": derive_counts,
            "items": entries,
        }
        path = self.out / "local_data" / ART_INVENTORY_NAME
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(inventory, indent=2, ensure_ascii=False), encoding="utf-8")
        self.log(
            f"  清单 local_data/{ART_INVENTORY_NAME}"
            f"（{len(entries)} 项 / 基名 {inventory['resolvedNames']}）"
        )

    # -- 阶段 6：配置与清单 ----------------------------------------------
    def write_config(self) -> None:
        config = (
            "; ConcordRTS 资源包运行配置\n"
            "; 相对路径按启动工作目录解析，请在资源包根目录下启动程序。\n"
            "[Runtime]\n"
            "ResourceRoot=RedAlert2\n"
            "LocalDataRoot=local_data\n"
            "DefaultMap=local_data/resources/mix_exports/multimd/2peaks.map\n"
            "WindowWidth=1024\n"
            "WindowHeight=640\n"
            "FixedTickHz=30\n"
            "TargetFps=60\n"
            "ShowMainMenu=yes\n"
            "\n"
            "[Skirmish]\n"
            "ShowSetup=yes\n"
        )
        if self.args.dry_run:
            return
        path = self.out / "local_data" / "runtime_config.ini"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(config, encoding="utf-8")
        self.log("  配置 local_data/runtime_config.ini")

    def write_manifest(self) -> None:
        if self.args.dry_run:
            return
        # 同一路径可能被多个阶段重复记录（如内层 MIX 既被抽取又被字面量收割命中），
        # 按 to 去重，只保留最后一次记录。
        deduped: dict[str, dict[str, object]] = {}
        for item in self.extracted:
            key = str(item.get("to") or item.get("name"))
            deduped[key] = item
        items = list(deduped.values())
        total = sum(int(item.get("bytes", 0)) for item in items)
        manifest = {
            "source": str(self.source),
            "output": str(self.out),
            "withMovies": bool(self.args.with_movies),
            "totalBytes": total,
            "itemCount": len(items),
            "archiveCount": len([i for i in items if i["kind"] == "archive"]),
            "looseCount": len([i for i in items if i["kind"] == "loose"]),
            "warnings": self.warnings,
            "items": items,
        }
        path = self.out / "MANIFEST.json"
        path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        self.log(f"  清单 MANIFEST.json（{len(items)} 项 / {total/1048576:.1f} MB）")

    def write_aliases(self) -> None:
        for src_name, rel in FILE_ALIASES:
            if src_name in MOVIE_ARCHIVES and not self.args.with_movies:
                # movmd03.mix 属于动画，未开动画时跳过别名
                continue
            src = self.mix_exports / TOP_LEVEL_ARCHIVES.get(src_name, MOVIE_ARCHIVES.get(src_name, "")) / src_name
            if not src.is_file():
                src = self.mix_exports / MOVIE_ARCHIVES.get(src_name, "") / src_name
            if not src.is_file():
                continue
            dst = self.mix_exports / rel
            if self.args.dry_run:
                self.log(f"  [计划] 别名 {src_name} -> mix_exports/{rel}")
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            self.log(f"  别名 mix_exports/{rel}")

    # -- 主流程 -----------------------------------------------------------

    def run(self) -> int:
        self.ensure_dump()
        if not self.source.is_dir():
            raise SystemExit(f"源目录不存在: {self.source}")
        if not self.args.dry_run:
            self.out.mkdir(parents=True, exist_ok=True)

        self.log("[1/7] 拷贝 MIX 归档")
        self.copy_archives()

        self.log("[2/7] 抽取内层 MIX")
        self.extract_inner_mixes()
        self.write_aliases()

        self.log("[3/7] 建立归档索引")
        self.index_all()

        self.log("[4/7] 提取关键散文件")
        self.extract_essential()
        self.copy_loose_files()

        self.log("[5/7] 按源码字面量收割散文件")
        self.harvest_source_literals()
        self.harvest_official_maps()

        self.log("[5b/7] 按 art*.ini 段名派生并抽取单位/建筑美术")
        self.harvest_art()

        self.log("[6/7] 构建资源根、音乐与根级规则")
        self.build_resource_root()
        self.copy_resource_root_extras()
        self.extract_music()
        self.write_local_data_rules()

        self.log("[7/7] 写配置与清单")
        self.write_config()
        self.write_manifest()

        if self.warnings:
            self.log("")
            self.log(f"警告 {len(self.warnings)} 条：")
            for warning in self.warnings[:40]:
                self.log(f"  - {warning}")
        self.log("")
        self.log(f"完成。调用 concord_rules_dump {self.calls} 次。")
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 ConcordRTS 独立资源包")
    parser.add_argument("--source", required=True, help="原始 RA2/YR 游戏目录")
    parser.add_argument("--out", required=True, help="输出资源包目录")
    parser.add_argument("--dump", required=True, help="concord_rules_dump 可执行文件路径")
    parser.add_argument("--repo", default="ConcordRTS", help="ConcordRTS 源码根（用于收割字面量）")
    parser.add_argument("--with-movies", action="store_true", help="包含过场动画归档（约 +1.0 GB）")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划")
    args = parser.parse_args()
    return Packager(args).run()


if __name__ == "__main__":
    sys.exit(main())
