"""Draws the launcher icon (3x3 faceted gems on lavender) into the mipmaps.

Run: python tool/gen_icon.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')
SIZES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
GEMS = [(239, 47, 42), (61, 180, 58), (66, 224, 228),
        (255, 201, 37), (140, 82, 242), (239, 47, 42),
        (47, 48, 136), (255, 119, 180), (61, 180, 58)]


def shade(c, k):
    if k >= 0:
        return tuple(int(v + (255 - v) * k) for v in c)
    return tuple(int(v * (1 + k)) for v in c)


def draw(size=1024):
    img = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / size
        top, bot = (206, 214, 250), (190, 160, 236)
        d.line([(0, y), (size, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)))
    cell = size * 0.26
    gap = size * 0.03
    ox = (size - (cell * 3 + gap * 2)) / 2
    for i, c in enumerate(GEMS):
        x = ox + (i % 3) * (cell + gap)
        y = ox + (i // 3) * (cell + gap)
        r = cell * 0.22
        d.rounded_rectangle([x, y + cell * 0.07, x + cell, y + cell * 1.07], r, fill=shade(c, -0.35))
        d.rounded_rectangle([x, y, x + cell, y + cell], r, fill=c)
        inset = cell * 0.22
        tl, tr = (x + inset, y + inset), (x + cell - inset, y + inset)
        bl, br = (x + inset, y + cell - inset), (x + cell - inset, y + cell - inset)
        m = cell * 0.06
        d.polygon([(x + m, y + m), (x + cell - m, y + m), tr, tl], fill=shade(c, 0.3))
        d.polygon([(x + m, y + m), tl, bl, (x + m, y + cell - m)], fill=shade(c, 0.12))
        d.polygon([(x + cell - m, y + m), (x + cell - m, y + cell - m), br, tr], fill=shade(c, -0.12))
        d.polygon([(x + m, y + cell - m), bl, br, (x + cell - m, y + cell - m)], fill=shade(c, -0.25))
        d.ellipse([x + cell * 0.15, y + cell * 0.1, x + cell * 0.45, y + cell * 0.25], fill=(255, 255, 255, 150))
    return img


big = draw()
for name, px in SIZES.items():
    out = os.path.join(ROOT, f'mipmap-{name}', 'ic_launcher.png')
    big.resize((px, px), Image.LANCZOS).save(out)
big.resize((512, 512), Image.LANCZOS).save(os.path.join(os.path.dirname(__file__), 'icon_512.png'))
print('ok')
