#!/usr/bin/env python3
"""Stamp a TrueType file with the weight class of the slot it fills.

Two of the app's weights have no drawing of their own: Tajawal has no 600 and
Manrope no 900, yet the UI asks for both. `google_fonts` used to answer them by
nearest-weight scoring — 600 landed on Tajawal Medium, 900 on Manrope
ExtraBold — and picking the file itself, so the resolution never depended on
the engine. Bundling the fonts hands that job to font matching, and the engine
may read either the weight declared in `pubspec.yaml` or the one inside the
file. Rather than bet on which, we make both say the same thing: a copy of the
Medium drawing that calls itself 600.

Usage:
    python3 tools/set_font_weight.py <src.ttf> <weight> <dest.ttf>

Regenerate the two the app ships with:
    python3 tools/set_font_weight.py assets/fonts/Tajawal-Medium.ttf 600 \
        assets/fonts/Tajawal-SemiBold.ttf
    python3 tools/set_font_weight.py assets/fonts/Manrope-ExtraBold.ttf 900 \
        assets/fonts/Manrope-Black.ttf
"""

import struct
import sys

_MASK = 0xFFFFFFFF
_MAGIC = 0xB1B0AFBA


def _checksum(data: bytes) -> int:
    """The sfnt checksum: big-endian uint32 words, zero-padded, wrapping."""
    if len(data) % 4:
        data += b"\0" * (4 - len(data) % 4)
    total = 0
    for (word,) in struct.iter_unpack(">I", data):
        total = (total + word) & _MASK
    return total


def _tables(font: bytes) -> dict:
    count = struct.unpack_from(">H", font, 4)[0]
    out = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack_from(">4sIII", font, 12 + i * 16)
        out[tag.decode("latin-1")] = (12 + i * 16, offset, length)
    return out


def set_weight(src: str, weight: int, dest: str) -> None:
    font = bytearray(open(src, "rb").read())
    tables = _tables(font)
    for required in ("OS/2", "head"):
        if required not in tables:
            raise SystemExit(f"{src}: no {required} table")

    # usWeightClass sits after version and xAvgCharWidth.
    _, os2_at, os2_len = tables["OS/2"]
    struct.pack_into(">H", font, os2_at + 4, weight)

    # A table's own checksum, then the file's, which the head table carries.
    entry_at, _, _ = tables["OS/2"]
    struct.pack_into(">I", font, entry_at + 4,
                     _checksum(bytes(font[os2_at:os2_at + os2_len])))

    _, head_at, _ = tables["head"]
    struct.pack_into(">I", font, head_at + 8, 0)
    struct.pack_into(">I", font, head_at + 8,
                     (_MAGIC - _checksum(bytes(font))) & _MASK)

    open(dest, "wb").write(bytes(font))
    print(f"{dest}: usWeightClass={weight} ({len(font)} bytes)")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    set_weight(sys.argv[1], int(sys.argv[2]), sys.argv[3])
