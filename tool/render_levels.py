"""Renders the output of tool/dump_levels.dart into a contact sheet PNG.

Run: python tool/render_levels.py levels.txt sheet.png
"""
import sys

from PIL import Image, ImageDraw

COLORS = {
    'R': (239, 47, 42), 'G': (61, 180, 58), 'C': (240, 221, 164), 'M': (124, 34, 57),
    'T': (66, 224, 228), 'N': (47, 48, 136), 'W': (243, 243, 243), 'K': (59, 59, 63),
    'Y': (255, 201, 37), 'O': (255, 138, 34), 'P': (255, 119, 180), 'B': (47, 125, 244),
    'A': (147, 214, 255), 'L': (147, 221, 62), 'S': (147, 96, 47), 'E': (162, 167, 176),
    'V': (140, 82, 242),
}

levels = []
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.rstrip('\n')
    if line.startswith('#'):
        levels.append((line[2:], []))
    elif line and levels:
        levels[-1][1].append(line)

CELL, PAD, COLS = 12, 24, 7
tile = CELL * 14 + PAD
rows_n = (len(levels) + COLS - 1) // COLS
img = Image.new('RGB', (COLS * tile, rows_n * (tile + 14)), (224, 224, 224))
d = ImageDraw.Draw(img)
for k, (title, grid) in enumerate(levels):
    ox, oy = (k % COLS) * tile + PAD // 2, (k // COLS) * (tile + 14) + 16
    d.text((ox, oy - 14), title, fill=(60, 60, 90))
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            c = COLORS[ch]
            d.rectangle([ox + x * CELL, oy + y * CELL, ox + x * CELL + CELL - 2, oy + y * CELL + CELL - 2], fill=c)
img.save(sys.argv[2])
print('ok', len(levels))
