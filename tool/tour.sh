#!/usr/bin/env bash
# Recorrido visual en el simulador de iOS: corre integration_test/tour_test.dart
# y guarda una captura por pantalla en el directorio dado.
#   tool/tour.sh <id-del-simulador> <directorio> [pantallas,separadas] [light,dark]
set -euo pipefail
DEVICE="$1"; OUT="$2"; ONLY="${3:-}"; THEMES="${4:-light,dark}"
FLUTTER="${FLUTTER:-flutter}"
mkdir -p "$OUT"
"$FLUTTER" test integration_test/tour_test.dart -d "$DEVICE" \
  --dart-define=TOUR_ONLY="$ONLY" --dart-define=TOUR_THEMES="$THEMES" 2>&1 |
while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *SHOT:*) name="${line##*SHOT:}"; xcrun simctl io "$DEVICE" screenshot "$OUT/${name}.png" >/dev/null 2>&1 || true ;;
  esac
done
