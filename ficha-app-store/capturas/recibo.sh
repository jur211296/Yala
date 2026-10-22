#!/usr/bin/env bash
# Renderiza la foto del recibo de un idioma → <salida>/<idioma>/recibo.png. Uso: capturas/recibo.sh <idioma>
# lanzar.sh se la pasa a la app con `-uitest-image-file` para que la foto que se «lee» sea la boleta de OBJ.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
mkdir -p "$SALIDA"
PERFIL="$(mktemp -d)"; trap 'rm -r "$PERFIL"' EXIT
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --allow-file-access-from-files --user-data-dir="$PERFIL" --virtual-time-budget=3000 \
  --window-size=1500,2000 --screenshot="$SALIDA/recibo.png" "file://$MOLDE/capturas/recibo.html?lang=$IDIOMA" >/dev/null 2>&1
python3 -c "from PIL import Image; im=Image.open('$SALIDA/recibo.png').convert('RGB'); im.save('$SALIDA/recibo.png'); print('✓', '$SALIDA/recibo.png', im.size)"
