#!/usr/bin/env bash
# Captura la pantalla del simulador del molde. Uso: capturas/cap.sh <idioma> <iphone|ipad> <nombre>
#   → <salida>/<idioma>/capturas/<nombre>.png (s-… para iPhone, i-… para iPad, como las que lee sets.js)
#     y una vista reducida en <salida>/<idioma>/_vistas/<nombre>.jpg para revisarla.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
U="$(udid "$2")"; N="${3:?Falta el nombre}"
mkdir -p "$SALIDA/capturas" "$SALIDA/_vistas"
barra "$U"; sleep 0.8
xcrun simctl io "$U" screenshot --type=png "$SALIDA/capturas/$N.png" >/dev/null 2>&1
sips -s format jpeg --resampleWidth 600 "$SALIDA/capturas/$N.png" --out "$SALIDA/_vistas/$N.jpg" >/dev/null
python3 -c "from PIL import Image; print('✓', '$N', Image.open('$SALIDA/capturas/$N.png').size)"
