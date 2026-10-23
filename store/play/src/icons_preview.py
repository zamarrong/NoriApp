"""Builds icons-preview.png: each icon option at 512, 96 and 48 px, squircle and circle masked."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFont
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = os.path.join(D, 'src', 'fonts')
title = ImageFont.truetype(os.path.join(F, 'PlusJakartaSans.ttf'), 34); title.set_variation_by_name('Bold')
small = ImageFont.truetype(os.path.join(F, 'Inter-Medium.ttf'), 20)

def mask(size, kind):
    k = 4; s = size * k
    m = Image.new('L', (s, s), 0)
    if kind == 'circle':
        ImageDraw.Draw(m).ellipse((0, 0, s - 1, s - 1), fill=255)
    else:  # superellipse, n=5 (launcher squircle)
        n = 5; r = s / 2; pts = []
        for i in range(720):
            t = 2 * math.pi * i / 720; c, si = math.cos(t), math.sin(t)
            pts.append((r + r * math.copysign(abs(c) ** (2 / n), c), r + r * math.copysign(abs(si) ** (2 / n), si)))
        ImageDraw.Draw(m).polygon(pts, fill=255)
    return m.resize((size, size), Image.LANCZOS)

sizes = [(512, 'squircle'), (512, 'circle'), (96, 'squircle'), (96, 'circle'), (48, 'squircle'), (48, 'circle')]
pad, gap = 60, 48
W = pad * 2 + sum(s for s, _ in sizes) + gap * (len(sizes) - 1)
row = 512 + 110
names = {'a': 'A · Nube azul sobre blanco', 'b': 'B · Nube blanca con profundidad', 'c': 'C · La “n” con la nube'}
H = pad + row * 3 + 20
out = Image.new('RGB', (W, H), '#EEF1F6'); d = ImageDraw.Draw(out)
for r, key in enumerate('abc'):
    icon = Image.open(os.path.join(D, f'icon-{key}.png')).convert('RGBA')
    y0 = pad + r * row
    d.text((pad, y0), names[key], font=title, fill='#0F172A')
    x = pad
    for s, kind in sizes:
        im = icon.resize((s, s), Image.LANCZOS)
        y = y0 + 64 + (512 - s) // 2 if s < 512 else y0 + 64
        sh = Image.new('L', (s, s), 0)  # soft shadow so the white icons read on the page
        out.paste(Image.new('RGB', (s, s), '#D5DBE5'), (x, y + max(2, s // 64)), mask(s, kind))
        out.paste(im, (x, y), mask(s, kind))
        if s == 512:
            d.text((x, y + s + 10), f'512 px · {"squircle" if kind == "squircle" else "círculo"}', font=small, fill='#64748B')
        elif kind == 'circle':
            d.text((x - s - gap, y0 + 64 + 256 + 70), f'{s} px', font=small, fill='#64748B')
        x += s + gap
out.save(os.path.join(D, 'icons-preview.png'))
print(out.size)
