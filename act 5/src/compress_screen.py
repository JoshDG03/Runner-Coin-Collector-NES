#!/usr/bin/env python3
"""
Compress an NES NEXXT-exported screen.asm into a packed 2-bit metatile map.

Input:
  screen.asm containing something like:
    screen:
      .byte $06,$07,...

Output:
  compressed_screen.asm containing:
    compressed_screen:
      .byte %00000000,%00011001,...

Metatile encoding:
  00 -> 06,07,16,17
  01 -> 0c,0d,1c,1d
  10 -> 04,05,14,15
  11 -> 0a,0b,1a,1b

Usage:
  python compress_screen.py screen.asm
  python compress_screen.py screen.asm compressed_screen.asm
"""

import re
import sys
from pathlib import Path

# 2-bit metatile mapping
METATILES = {
    (0x06, 0x07, 0x16, 0x17): 0b00,
    (0x0C, 0x0D, 0x1C, 0x1D): 0b01,
    (0x04, 0x05, 0x14, 0x15): 0b10,
    (0x0A, 0x0B, 0x1A, 0x1B): 0b11,
}

TILE_WIDTH = 32
TILE_HEIGHT = 30
METATILE_WIDTH = TILE_WIDTH // 2
METATILE_HEIGHT = TILE_HEIGHT // 2


def parse_screen_bytes(text: str) -> list[int]:
    """
    Extract the first 960 nametable tile bytes after 'screen:'.
    Ignores the final 64 attribute bytes.
    """
    match = re.search(r'^\s*screen\s*:\s*$', text, flags=re.MULTILINE)
    if not match:
        raise ValueError("Could not find 'screen:' label in input file.")

    after_screen = text[match.end():]

    # Match hex bytes written like $06 or $c0
    hex_tokens = re.findall(r'\$([0-9A-Fa-f]{2})', after_screen)
    if len(hex_tokens) < TILE_WIDTH * TILE_HEIGHT:
        raise ValueError(
            f"Expected at least 960 tile bytes after 'screen:', found {len(hex_tokens)}."
        )

    # Only keep the nametable (32x30 = 960 bytes), ignore attribute bytes
    return [int(tok, 16) for tok in hex_tokens[: TILE_WIDTH * TILE_HEIGHT]]


def tiles_to_metatile_ids(tiles: list[int]) -> list[list[int]]:
    """
    Convert the 32x30 tile screen into a 16x15 grid of metatile IDs.
    """
    if len(tiles) != TILE_WIDTH * TILE_HEIGHT:
        raise ValueError(f"Expected exactly 960 tile bytes, got {len(tiles)}.")

    metatile_rows: list[list[int]] = []

    for tile_y in range(0, TILE_HEIGHT, 2):
        row_ids: list[int] = []
        for tile_x in range(0, TILE_WIDTH, 2):
            top_left = tiles[tile_y * TILE_WIDTH + tile_x]
            top_right = tiles[tile_y * TILE_WIDTH + tile_x + 1]
            bottom_left = tiles[(tile_y + 1) * TILE_WIDTH + tile_x]
            bottom_right = tiles[(tile_y + 1) * TILE_WIDTH + tile_x + 1]

            key = (top_left, top_right, bottom_left, bottom_right)
            if key not in METATILES:
                raise ValueError(
                    "Unknown metatile at "
                    f"tile ({tile_x},{tile_y}): "
                    f"{top_left:02X},{top_right:02X},{bottom_left:02X},{bottom_right:02X}"
                )

            row_ids.append(METATILES[key])
        metatile_rows.append(row_ids)

    return metatile_rows


def pack_4_metatiles_to_byte(ids: list[int]) -> int:
    """
    Pack 4 two-bit metatile IDs into one byte:
      bits 7-6 = ids[0]
      bits 5-4 = ids[1]
      bits 3-2 = ids[2]
      bits 1-0 = ids[3]
    """
    if len(ids) != 4:
        raise ValueError("Exactly 4 metatile IDs are required to pack one byte.")

    return ((ids[0] & 0b11) << 6) | ((ids[1] & 0b11) << 4) | ((ids[2] & 0b11) << 2) | (ids[3] & 0b11)


def compress_metatile_rows(metatile_rows: list[list[int]]) -> list[list[int]]:
    """
    Compress each 16-metatile row into 4 packed bytes.
    """
    if len(metatile_rows) != METATILE_HEIGHT:
        raise ValueError(f"Expected {METATILE_HEIGHT} metatile rows, got {len(metatile_rows)}.")

    compressed_rows: list[list[int]] = []
    for row in metatile_rows:
        if len(row) != METATILE_WIDTH:
            raise ValueError(f"Expected {METATILE_WIDTH} metatiles per row, got {len(row)}.")

        compressed = []
        for i in range(0, METATILE_WIDTH, 4):
            compressed.append(pack_4_metatiles_to_byte(row[i:i + 4]))
        compressed_rows.append(compressed)

    return compressed_rows


def format_output(compressed_rows: list[list[int]], source_name: str) -> str:
    """
    Format the compressed bytes as an asm file using binary notation.
    """
    lines = []
    lines.append("; Auto-generated from {}".format(source_name))
    lines.append("; 32x30 tiles -> 16x15 metatiles -> 60 packed bytes")
    lines.append(";")
    lines.append("; 2-bit metatile encoding:")
    lines.append(";   00 = 06,07,16,17")
    lines.append(";   01 = 0c,0d,1c,1d")
    lines.append(";   10 = 04,05,14,15")
    lines.append(";   11 = 0a,0b,1a,1b")
    lines.append("")
    lines.append("compressed_screen:")

    for row in compressed_rows:
        binary_bytes = ",".join(f"%{value:08b}" for value in row)
        lines.append(f"  .byte {binary_bytes}")

    lines.append("")
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print("Usage: python compress_screen.py <input_screen.asm> [output_compressed.asm]")
        return 1

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) == 3 else input_path.with_name("compressed_screen.asm")

    if not input_path.exists():
        print(f"Error: input file not found: {input_path}")
        return 1

    try:
        text = input_path.read_text(encoding="utf-8")
        tiles = parse_screen_bytes(text)
        metatile_rows = tiles_to_metatile_ids(tiles)
        compressed_rows = compress_metatile_rows(metatile_rows)
        output_text = format_output(compressed_rows, input_path.name)
        output_path.write_text(output_text, encoding="utf-8")
    except Exception as exc:
        print(f"Error: {exc}")
        return 1

    total_bytes = sum(len(row) for row in compressed_rows)
    print(f"Compressed {input_path} -> {output_path}")
    print(f"Output contains {len(compressed_rows)} rows and {total_bytes} packed bytes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
