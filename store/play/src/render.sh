#!/usr/bin/env bash
# Renders an HTML/SVG file to PNG with headless Chrome at an exact size.
#   src/render.sh <input.html|svg> <output.png> <width> <height>
set -euo pipefail
IN="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; OUT="$2"; W="$3"; H="$4"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PROFILE="$(mktemp -d)"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --user-data-dir="$PROFILE" --allow-file-access-from-files --virtual-time-budget=3000 \
  --window-size="$W,$H" --screenshot="$OUT" "file://$IN" >/dev/null 2>&1
rm -rf "$PROFILE"
python3 - "$OUT" "$W" "$H" <<'PY'
import sys
from PIL import Image
p, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
im = Image.open(p)
if im.size != (w, h): im = im.crop((0, 0, w, h))
im.convert('RGBA').save(p)
PY
