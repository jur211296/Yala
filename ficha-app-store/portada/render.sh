#!/usr/bin/env bash
# Portada de la ficha: el recurso universal 16:9 (5244×2950, PNG sin alfa) de un idioma, en el set del iPhone y del iPad.
#   portada/render.sh <idioma> [guia]
# Lee las pantallas del molde (<salida>/<idioma>/capturas/{s,i}-{ia,foto}.png, las de capturas/conducir.sh) y deja
#   <salida>/<idioma>/portada/yala-universal-{iphone,ipad}-5244x2950.png
# Con «guia», copias con la zona segura de Apple marcada en <salida>/<idioma>/portada/_revision/ (no se suben).
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
GUIA="${2:-}"
DEST="$SALIDA/portada"; [ -n "$GUIA" ] && DEST="$DEST/_revision"
mkdir -p "$DEST"
for aparato in iphone ipad; do
  p=$([ $aparato = iphone ] && echo s || echo i)
  for f in ia foto; do [ -f "$SALIDA/capturas/$p-$f.png" ] || { echo "✗ falta $SALIDA/capturas/$p-$f.png"; exit 1; }; done
  out="$DEST/yala-universal-$aparato-5244x2950.png"
  "$C" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --virtual-time-budget=6000 --window-size=5244,2950 --screenshot="$out" \
    "file://$MOLDE/portada/portada.html?idioma=$IDIOMA&aparato=$aparato&dir=file://$SALIDA/capturas${GUIA:+&guia=1}" >/dev/null 2>&1
  python3 -c "
from PIL import Image; import sys
im=Image.open(sys.argv[1]).convert('RGB'); im.save(sys.argv[1]); print('✓', sys.argv[1], im.size, im.mode)" "$out"
done
