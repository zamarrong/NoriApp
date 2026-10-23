"""Builds feature-graphic.png (blue) and feature-graphic-b.png (light), 1024x500.
Key content stays inside the central safe area (about 80 px from each side)."""
import os, subprocess
from PIL import Image
from build_screens import statusbar, SB_ICONS, SRC, OUT, CLOUD

WORD = 'M0,100 V50 A50,50 0 0 1 100,50 V100 H72 V50 A22,22 0 0 0 28,50 V100 Z M114,50 A50,50 0 1 1 214,50 A50,50 0 1 1 114,50 Z M142,50 A22,22 0 1 0 186,50 A22,22 0 1 0 142,50 Z M228,100 V50 A50,50 0 0 1 278,0 H294 V28 H278 A22,22 0 0 0 256,50 V100 Z M306,0 H334 V100 H306 Z'
WCLOUD = '<rect x="301.0" y="-29.0" width="36.0" height="15.0"/><circle cx="301.0" cy="-27.0" r="13.0"/><circle cx="319.0" cy="-37.0" r="19.0"/><circle cx="337.0" cy="-29.0" r="15.0"/>'


def wordmark(ink, cloud, h):
    return f'<svg viewBox="-4 -60 360 164" style="height:{h}px;width:{h * 360 / 164:.1f}px;display:block;align-self:flex-start;margin-left:-4px"><path fill="{ink}" fill-rule="evenodd" d="{WORD}"/><g fill="{cloud}">{WCLOUD}</g></svg>'


def phone(shot, w, x, y, rot=0):
    sb_c, sb_raw, dark, cap_w = statusbar(shot)
    bez, rad = w * 0.022, w * 0.13
    k = (w - 2 * bez) / cap_w
    sbh = max(sb_raw * k, 14)
    fs = w * 0.03
    return f'''<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;transform:rotate({rot}deg);background:#0B1220;border-radius:{rad}px;padding:{bez}px;box-sizing:border-box;box-shadow:0 30px 70px rgba(7,22,70,.40), inset 0 0 0 1.5px #2A3345">
<div style="position:relative;border-radius:{rad - bez}px;overflow:hidden"><img src="{shot}" style="display:block;width:100%">
<div style="position:absolute;left:0;right:0;top:0;height:{sbh}px;background:{sb_c};color:#111827;display:flex;align-items:center;justify-content:space-between;padding:0 {rad * .7}px;box-sizing:border-box;font:600 {fs}px Jakarta">
<span>9:41</span><span style="display:flex;gap:{fs * .3}px;align-items:center">{SB_ICONS.replace('class="sbi"', f'style="width:{fs}px;height:{fs}px"').replace('class="sbb"', f'style="width:{fs * .5}px;height:{fs * .85}px"')}</span></div></div>
<div style="position:absolute;top:{bez + sbh / 2 - w * .014}px;left:50%;width:{w * .028}px;height:{w * .028}px;margin-left:{-w * .014}px;border-radius:50%;background:#05080F"></div></div>'''


def html(bg, ink, cloud, accent, headline, sub, phones, deco):
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: Jakarta; src: url(fonts/PlusJakartaSans.ttf); font-weight: 200 800; }}
@font-face {{ font-family: Inter; src: url(fonts/Inter-Medium.ttf); font-weight: 500; }}
html, body {{ margin:0; width:1024px; height:500px; overflow:hidden; }}
body {{ background:{bg}; position:relative; font-family: Jakarta, sans-serif; }}
.txt {{ position:absolute; left:96px; top:0; bottom:0; width:470px; display:flex; flex-direction:column; justify-content:center; }}
h1 {{ margin:34px 0 0; font-weight:800; font-size:54px; line-height:1.04; letter-spacing:-0.03em; color:{ink}; }}
h1 em {{ font-style:normal; color:{accent}; }}
p {{ margin:18px 0 0; font: 500 21px Inter, sans-serif; color:{ink}; opacity:.78; letter-spacing:-0.005em; }}
</style></head><body>{deco}
<div class="txt">{wordmark(ink, cloud, 50)}<h1>{headline}</h1><p>{sub}</p></div>
{''.join(phones)}</body></html>'''


def render(doc, name):
    path = os.path.join(SRC, '_tmp.html')
    open(path, 'w').write(doc)
    out = os.path.join(OUT, name)
    subprocess.run([os.path.join(SRC, 'render.sh'), path, out, '1024', '500'], check=True)
    os.remove(path)
    Image.open(out).convert('RGB').save(out)


big_cloud = lambda fill, x, y, w: f'<svg viewBox="10 28 108 72" style="position:absolute;left:{x}px;top:{y}px;width:{w}px" fill="{fill}">{CLOUD}</svg>'

# Chosen design (owner): the light version with two phones.
render(html('#F3F6FD', '#0F172A', '#2563EB', '#2563EB', 'Cobra y <em>factura</em><br>desde la ruta',
            'La app de Nori para tu equipo de ventas.',
            [phone('screens/phone/05_captura_rapida_l.png', 236, 745, 96, 0), phone('screens/phone/01_hoy_l.png', 252, 598, 58, 0)],
            big_cloud('#E3EBFC', 500, 30, 640)), 'feature-graphic.png')
print('ok')
