#!/usr/bin/env bash
# Imágenes del evento dentro de la app (lanzamiento 2.2) de un idioma: tarjeta 16:9 y detalle 9:16, PNG sin alfa.
#   evento/render.sh <idioma>
# Lee <salida>/<idioma>/capturas/s-{programados,panel}.png (capturas/conducir.sh) y deja
#   <salida>/<idioma>/evento/yala-evento-tarjeta-3840x2160.png y yala-evento-detalle-2160x3840.png
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DEST="$SALIDA/evento"; mkdir -p "$DEST"
for f in programados panel; do [ -f "$SALIDA/capturas/s-$f.png" ] || { echo "✗ falta $SALIDA/capturas/s-$f.png"; exit 1; }; done
PERFIL="$(mktemp -d)"; trap 'rm -r "$PERFIL"' EXIT
for formato in tarjeta:3840,2160 detalle:2160,3840; do
  nombre=${formato%%:*}; tam=${formato#*:}
  out="$DEST/yala-evento-$nombre-${tam/,/x}.png"
  "$C" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --user-data-dir="$PERFIL" --virtual-time-budget=6000 --window-size=$tam --screenshot="$out" \
    "file://$MOLDE/evento/evento.html?formato=$nombre&dir=file://$SALIDA/capturas" >/dev/null 2>&1
  python3 -c "
from PIL import Image; import sys
im=Image.open(sys.argv[1]).convert('RGB'); im.save(sys.argv[1]); print('✓', sys.argv[1], im.size, im.mode)" "$out"
done
