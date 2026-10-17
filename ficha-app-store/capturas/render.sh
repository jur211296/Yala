#!/usr/bin/env bash
# Renderiza las láminas de un idioma con Chrome headless. Uso: capturas/render.sh <idioma> [iphone|ipad|todo] [n]
#   iphone → <salida>/<idioma>/6.9/NN.png (1320×2868) y 6.5/NN.png (lienzo 1320×2856 escalado a 1284×2778)
#   ipad   → <salida>/<idioma>/ipad-13/NN.png (2064×2752)
# Lee los textos de textos/<idioma>.js y las pantallas de <salida>/<idioma>/capturas/. Todas en PNG sin alfa (Apple lo exige).
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
cd "$MOLDE/capturas"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
QUE=${2:-todo}; SOLO=${3:-}
[ -d "$SALIDA/capturas" ] || { echo "✗ faltan las pantallas en $SALIDA/capturas (capturas/lanzar.sh + cap.sh)" >&2; exit 1; }
PERFIL="$(mktemp -d)"; trap 'rm -r "$PERFIL"' EXIT
pinta() { # set formato tamaño destino
  "$C" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --user-data-dir="$PERFIL" --virtual-time-budget=5000 --window-size=$3 --screenshot="$4" \
    "file://$PWD/lamina.html?lang=$IDIOMA&set=$1&n=$N&f=$2&cap=file://$SALIDA/capturas/" >/dev/null 2>&1
  python3 - "$4" "$2" <<'PY'
import sys; from PIL import Image
p, f = sys.argv[1], sys.argv[2]
im = Image.open(p).convert("RGB")
if f == "65": im = im.resize((1284, 2778), Image.LANCZOS)
im.save(p)
PY
}
for s in iphone ipad; do
  [ "$QUE" != todo ] && [ "$QUE" != "$s" ] && continue
  n=$(node -e "const {construirSets}=require('./sets.js');
    process.stdout.write(String(construirSets(require('$MOLDE/textos/$IDIOMA.js'),'$IDIOMA').$s.laminas.length))")
  for i in $(seq 1 "$n"); do
    [ -n "$SOLO" ] && [ "$SOLO" != "$i" ] && continue
    N=$i; nn=$(printf %02d "$i")
    if [ "$s" = iphone ]; then
      mkdir -p "$SALIDA/6.9" "$SALIDA/6.5"
      pinta iphone 69 1320,2868 "$SALIDA/6.9/$nn.png"
      pinta iphone 65 1320,2856 "$SALIDA/6.5/$nn.png"
    else
      mkdir -p "$SALIDA/ipad-13"
      pinta ipad ipad 2064,2752 "$SALIDA/ipad-13/$nn.png"
    fi
    echo "✓ $IDIOMA $s $nn"
  done
done
