#!/usr/bin/env bash
# Saca las 10 pantallas de un idioma en un aparato, sin manos: siembra una vez y relanza para cada pantalla.
#   capturas/conducir.sh <idioma> <iphone|ipad> [pantalla…]
# Pantallas: panel divisas estadisticas presupuestos programados grupo ia yape foto voz (por defecto, todas).
# Deja <salida>/<idioma>/capturas/{s|i}-<pantalla>.png con los nombres que lee sets.js. Usa axe (brew install axe):
# toca por accessibilityIdentifier o por etiqueta, que son las de la app en ese idioma.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
APARATO="${2:?Falta iphone o ipad}"; shift 2
U="$(udid "$APARATO")"
P=$([ "$APARATO" = iphone ] && echo s || echo i)
TODAS=(panel divisas estadisticas presupuestos programados grupo ia yape foto voz)
PANTALLAS=("$@"); [ ${#PANTALLAS[@]} -eq 0 ] && PANTALLAS=("${TODAS[@]}")
L="$MOLDE/capturas/lanzar.sh"; CAP="$MOLDE/capturas/cap.sh"

source "$MOLDE/capturas/ui.sh"
cap() { sleep "${2:-1.5}"; "$CAP" "$IDIOMA" "$APARATO" "$P-$1"; }
relanza() { "$L" "$IDIOMA" "$APARATO" --sin-semilla "$@" >/dev/null; }
# «Este mes» del selector de período, como lo dice la app en ese idioma (`period.thisMonth` de su .lproj).
ESTE_MES=$(python3 -c 'import re,sys
t=open(sys.argv[1],encoding="utf-8").read()
print(re.search(r"^\"period\.thisMonth\" = \"(.*)\";", t, re.M).group(1))' "$MOLDE/../Yala/Resources/$LPROJ.lproj/Localizable.strings")
HECHA_FOTO=0

[ "${YALA_FICHA_SIN_SEMBRAR:-}" = 1 ] || preparar "$U"
[ "${YALA_FICHA_SIN_SEMBRAR:-}" = 1 ] || "$L" "$IDIOMA" "$APARATO"     # la siembra, una vez (YALA_FICHA_SIN_SEMBRAR=1 la salta)
for p in "${PANTALLAS[@]}"; do
  case "$p" in
    panel)
      relanza; esperar "panel_action_new"; cap panel ;;
    divisas)
      # «Tus finanzas» recuerda si estaba desplegado: se toca solo si las tarjetas no están.
      relanza; esperar "panel_panorama_header"
      arbol | grep -qF "|panel_account_card_1|" || id panel_panorama_header
      esperar "panel_account_card_1"
      [ "$APARATO" = iphone ] && axe swipe --udid "$U" --start-x 300 --start-y 480 --end-x 60 --end-y 480 --duration 0.3 >/dev/null && sleep 1
      tocar_linea "|panel_account_card_1|"; cap divisas 2.5 ;;
    estadisticas)
      relanza -uitest-deeplink statistics
      id "detail_chip_categorías"; sleep 1
      # El selector de período: el primer PopUpButton de la pantalla; luego «este mes» en el idioma de la app.
      tocar "$(arbol | grep '^PopUpButton|' | head -1 | cut -d'|' -f2)"; sleep 1
      tocar "$ESTE_MES"; cap "$([ "$APARATO" = iphone ] && echo estadisticas-grafica || echo estadisticas)" 2.5 ;;
    presupuestos)
      # En el iPad, lista y detalle a la vez: se abre el primero (Comer fuera / Eating Out), como en el set en español.
      relanza -uitest-deeplink planning; esperar "|budget_row_"
      [ "$APARATO" = ipad ] && tocar_linea "|budget_row_"
      cap presupuestos 3 ;;
    programados)
      relanza -uitest-deeplink scheduledPayments; esperar "scheduled_payment_row"
      [ "$APARATO" = ipad ] && tocar_linea "|scheduled_payment_row|"
      cap programados 2.5 ;;
    grupo)
      relanza -uitest-deeplink-url "yala://groups/seeded-first"; cap grupo 4 ;;
    ia)
      relanza -uitest-chat-draft -uitest-ai-chat-ready; id panel_action_ai; esperar "chat_draft_save"; cap ia 2 ;;
    yape|foto)
      # La hoja de origen (04) y lo que lee (02) salen del mismo recorrido: si se piden las dos, una sola vez.
      [ "$HECHA_FOTO" = 1 ] && continue
      [ -f "$SALIDA/recibo.png" ] || "$MOLDE/capturas/recibo.sh" "$IDIOMA" >/dev/null
      relanza -uitest-image-result one -uitest-image-file "$SALIDA/recibo.png"
      id panel_action_image; esperar "image_source_photos"
      [[ " ${PANTALLAS[*]} " == *" yape "* ]] && cap yape-origen 1.5
      if [[ " ${PANTALLAS[*]} " == *" foto "* ]]; then id image_source_photos; esperar "image_review_title" 15; cap foto 1.5; fi
      HECHA_FOTO=1 ;;
    voz)
      relanza -uitest-voice-result one; id panel_action_voice; id voice_done; esperar "voice_draft_row" 15; cap "$([ "$APARATO" = iphone ] && echo voz-uno || echo voz)" 1.5 ;;
    *) echo "✗ pantalla desconocida: $p" >&2; exit 1 ;;
  esac
done
echo "✓ $IDIOMA · $APARATO: ${PANTALLAS[*]}"
