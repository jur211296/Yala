#!/usr/bin/env bash
# Capturas de la App Store para el iPhone Duo, sin componer: exterior (cerrado, 1398×2034) e interior (abierto en
# horizontal, 2853×2007), las dos medidas que pide App Store Connect. Mismas condiciones que el resto de la ficha:
# semilla `ficha` de casa (YALA_FICHA_MARKETING=1), reloj al 13-oct, 9:41, tema oscuro y Pro.
#   duo/capturas.sh <idioma>   → <salida>/<idioma>/duo/{exterior,interior}/NN-<pantalla>.png (PNG sin alfa)
# Requisitos: el simulador `duo` de idiomas.json, Device Hub abierto con él a la vista (ver duo/comun.sh) y la app de
# YALA_FICHA_APP (scheme Yala, Debug). YALA_FICHA_SIN_SEMBRAR=1 repite sin borrar ni sembrar.
set -uo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
export YALA_FICHA_MARKETING="${YALA_FICHA_MARKETING:-1}"
source "$MOLDE/duo/comun.sh"
OUT="$SALIDA/duo"
L="$MOLDE/capturas/lanzar.sh"
rel() { "$L" "$IDIOMA" duo --sin-semilla "$@" >/dev/null; }
cap() { # cap <nombre> <interior|exterior>
  mkdir -p "$OUT/$2"; barra "$U"; sleep 1.2
  local disp=$([ "$2" = interior ] && echo $INNER || echo $OUTER)
  xcrun simctl io "$U" screenshot --display=$disp "$OUT/$2/$1.png" >/dev/null 2>&1
  python3 -c "from PIL import Image; im=Image.open('$OUT/$2/$1.png').convert('RGB'); im.save('$OUT/$2/$1.png'); print('✓', '$2/$1', im.size)"
}
ronda() { # ronda <interior|exterior>: en el interior, lista y detalle a la vez, así que se abre el primero.
  local D=$1
  rel -panelAccountsCollapsed NO; esperar "panel_action_new"; sleep 1.5; cap 01-panel "$D"
  rel -uitest-deeplink statistics; sleep 3; cap 02-estadisticas "$D"
  rel -uitest-deeplink planning; esperar "|budget_row_"; sleep 1
  [ "$D" = interior ] && { toca_id "|budget_row_" interior; sleep 2.5; }
  cap 03-presupuestos "$D"
  rel -uitest-deeplink scheduledPayments; esperar "scheduled_payment_row"; sleep 1
  [ "$D" = interior ] && { toca_id "|scheduled_payment_row|" interior; sleep 2.5; }
  cap 04-pagos-planificados "$D"
  rel -uitest-deeplink-url "yala://groups/seeded-first"; sleep 4; cap 05-grupo "$D"
  rel -uitest-chat-draft -uitest-ai-chat-ready; esperar "|panel_action_ai|"; sleep 1
  toca_id "|panel_action_ai|" "$D"; esperar "chat_draft_save" 15; sleep 1.5; cap 06-yala-ia "$D"
}
if [ "${YALA_FICHA_SIN_SEMBRAR:-}" != 1 ]; then
  preparar "$U"; INNER=$(pantalla 2007); OUTER=$(pantalla 1398)
  pose cerrado; "$L" "$IDIOMA" duo >/dev/null
fi
pose cerrado; ronda exterior
pose abierto 6; ronda interior
echo "✓ $IDIOMA · duo → $OUT"
