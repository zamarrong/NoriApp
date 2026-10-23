"""Builds the framed Play Store screenshots from the raw app captures in src/screens/.

    python3 src/build_screens.py            # phone + tablets
Each shot: brand background, a short headline and the real screen in a clean device frame.
"""
import os, re, subprocess, sys

SRC = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(SRC)
CLOUD = '<rect x="34.55" y="73.3" width="55.8" height="23.25"/><circle cx="34.55" cy="76.4" r="20.15"/><circle cx="62.45" cy="60.9" r="29.45"/><circle cx="90.35" cy="73.3" r="23.25"/>'

FLIP = {'03-cobro', '04-factura'}  # bottom-sheet screens: headline below, phone from the top
PHONE = [  # (output, capture, icon, headline)
    ('01-ruta', '01_hoy_l', 'route', 'Ruta del día<br>en orden'),
    ('02-venta', '05_captura_rapida_l', 'zap', 'Vende en<br>segundos'),
    ('03-cobro', '07_cobro_l', 'printer', 'Cobra e imprime<br>el ticket'),
    ('04-factura', '08b_factura_l', 'receipt-text', 'Factura CFDI<br>al momento'),
    ('05-sin-senal', '20c_sin_senal_l', 'cloud-off', 'Sigue vendiendo<br>sin señal'),
    ('06-checador', '12_checador_l', 'scan-barcode', 'Precio y existencia<br>al escanear'),
    ('07-clientes', '10_cliente_l', 'wallet', 'Saldo y cobranza<br>de cada cliente'),
    ('08-supervisor', '16_autorizaciones_l', 'badge-check', 'Autoriza desde<br>donde estés'),
]
TABLET = [
    ('tablet-7', 'tab7', '01_hoy_l', 'route', 'Ruta del día en orden', 1200, 1920),
    ('tablet-10', 'tab10', '15_indicadores_l', 'badge-check', 'Tu equipo al momento', 1600, 2560),
]


def icon(name):
    s = open(os.path.join(SRC, 'icons', f'{name}.svg')).read()
    s = re.sub(r'<!--.*?-->', '', s, flags=re.S)
    return s.replace('class="lucide', 'class="ico lucide')


def statusbar(shot_path):
    """The capture's own status bar sits flush with the screen corner; it is covered with the app's
    background color and redrawn with room for the rounded corners. Returns (color, height px, dark)."""
    from PIL import Image
    im = Image.open(os.path.join(SRC, shot_path)).convert('RGB')
    bg = im.getpixel((im.width // 4, 4))
    last, empty = 0, 0
    for y in range(0, 120):  # the band ends at the first run of 10 plain rows
        if any(sum(abs(a - b) for a, b in zip(im.getpixel((x, y)), bg)) > 30 for x in range(0, im.width, 3)):
            last, empty = y, 0
        else:
            empty += 1
            if empty >= 10 and last: break
    dark = sum(bg) / 3 < 110
    return '#%02x%02x%02x' % bg, last + 8, dark, im.width


SB_ICONS = """<svg viewBox="0 0 24 24" class="sbi"><path fill="currentColor" d="M12 20.5 1.2 9.2a15.5 15.5 0 0 1 21.6 0z"/></svg>
<svg viewBox="0 0 24 24" class="sbi"><path fill="currentColor" d="M2 21h20V1z"/></svg>
<svg viewBox="0 0 14 24" class="sbb"><rect x="4" y="0" width="6" height="3" rx="1" fill="currentColor"/><rect x="0" y="2" width="14" height="22" rx="2.5" fill="currentColor"/></svg>"""


def page(w, h, shot, ico, headline, *, tablet=False, flip=False):
    # Proportions scale with the canvas width; the phone bleeds off the bottom edge.
    u = w / 1080
    dev_w = (1220 if tablet else 860) * u if not tablet else w * 0.80
    bez = 16 * u
    rad = (100 if not tablet else 70) * u
    top = 470 * u if not tablet else 560 * (w / 1200)
    hl = 84 * u if not tablet else 92 * (w / 1200)
    sb_c, sb_raw, dark, cap_w = statusbar(shot)
    k = (dev_w - 2 * bez) / cap_w  # capture px -> page px
    sb_h = max(sb_raw * k, 44 * u)
    sb_fg = '#FFFFFF' if dark else '#111827'
    sb_fs = 24 * u if not tablet else 20 * (w / 1200)
    sb_pad = (rad - bez) * 0.62 + 10 * u
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: Jakarta; src: url(fonts/PlusJakartaSans.ttf); font-weight: 200 800; }}
html, body {{ margin: 0; width: {w}px; height: {h}px; overflow: hidden; }}
body {{ background: #2563EB; position: relative; font-family: Jakarta, sans-serif; }}
.cloud {{ position: absolute; left: 50%; {'bottom' if flip else 'top'}: {top + 120 * u}px; width: {w * 1.25}px; transform: translateX(-50%); }}
.head {{ position: absolute; {'bottom' if flip else 'top'}: {(130 if flip else 118) * u}px; left: 0; right: 0; text-align: center; color: #fff; }}
.badge {{ width: {92 * u}px; height: {92 * u}px; border-radius: {28 * u}px; background: #FFFFFF; margin: 0 auto {34 * u}px;
  display: flex; align-items: center; justify-content: center; box-shadow: 0 {10 * u}px {30 * u}px rgba(10, 30, 90, .25); }}
.ico {{ width: {48 * u}px; height: {48 * u}px; color: #2563EB; stroke-width: 2.1; }}
h1 {{ margin: 0; font-weight: 800; font-size: {hl}px; line-height: 1.06; letter-spacing: -0.025em; }}
.dev {{ position: absolute; left: 50%; transform: translateX(-50%); top: {top}px; width: {dev_w}px;
  background: #0B1220; border-radius: {rad}px; padding: {bez}px; box-sizing: border-box;
  box-shadow: 0 {50 * u}px {110 * u}px rgba(7, 22, 70, .45), inset 0 0 0 {2 * u}px #2A3345; }}
.dev img {{ display: block; width: 100%; border-radius: {rad - bez}px; }}
.screen {{ position: relative; border-radius: {rad - bez}px; overflow: hidden; }}
.sb {{ position: absolute; left: 0; right: 0; top: 0; height: {sb_h}px; background: {sb_c}; color: {sb_fg};
  display: flex; align-items: center; justify-content: space-between; padding: 0 {sb_pad}px; box-sizing: border-box;
  font: 600 {sb_fs}px Jakarta, sans-serif; }}
.sb span.r {{ display: flex; gap: {sb_fs * .3}px; align-items: center; }}
.sbi {{ width: {sb_fs * .95}px; height: {sb_fs * .95}px; }} .sbb {{ width: {sb_fs * .5}px; height: {sb_fs * .85}px; }}
.hole {{ position: absolute; top: {bez + sb_h / 2 - 12 * u}px; left: 50%; width: {24 * u}px; height: {24 * u}px; margin-left: {-12 * u}px; border-radius: 50%; background: #05080F; }}
</style></head><body>
<svg class="cloud" viewBox="10 28 108 72" fill="#2D6CF0">{CLOUD}</svg>
<div class="head"><div class="badge">{icon(ico)}</div><h1>{headline}</h1></div>
<div class="dev"{' style="top:auto;bottom:%spx"' % (top + 60 * u) if flip else ''}><div class="screen"><img src="{shot}"><div class="sb"><span>9:41</span><span class="r">{SB_ICONS if 'sin_senal' not in shot else SB_ICONS.split(chr(10))[-1]}</span></div></div><div class="hole"></div></div>
</body></html>'''


def render(html, out, w, h):
    path = os.path.join(SRC, '_tmp.html')
    open(path, 'w').write(html)
    subprocess.run([os.path.join(SRC, 'render.sh'), path, out, str(w), str(h)], check=True)
    os.remove(path)
    # Play wants no alpha channel issues: flatten to RGB
    from PIL import Image
    Image.open(out).convert('RGB').save(out)


if __name__ == '__main__':
    only = sys.argv[1:]
    for name, cap, ico, hl in PHONE:
        if only and name not in only: continue
        render(page(1080, 1920, f'screens/phone/{cap}.png', ico, hl, flip=name in FLIP), os.path.join(OUT, f'phone-{name}.png'), 1080, 1920)
        print('phone', name)
    for name, folder, cap, ico, hl, w, h in TABLET:
        if only and name not in only: continue
        if not os.path.exists(os.path.join(SRC, 'screens', folder, f'{cap}.png')): continue
        render(page(w, h, f'screens/{folder}/{cap}.png', ico, hl, tablet=True), os.path.join(OUT, f'{name}.png'), w, h)
        print('tablet', name)
