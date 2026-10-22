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
# «Tus finanzas» desplegado: por argumento de arranque (`relanza -panelAccountsCollapsed NO`). Medido el 16-oct-2026:
# tocar la cabecera por su id (el centro) no la despliega; solo el «+» de la derecha.
DESPLEGADO=(-panelAccountsCollapsed NO)
desplegar_cuentas() { esperar "panel_account_card_0"; }
# Por dónde se arrastra el carrusel de cuentas: «x_desde x_hasta y» en puntos, sobre la primera tarjeta (en el iPad el
# carrusel va en la columna derecha). Reintenta: una lectura del árbol puede volver vacía (medido el 16-oct-2026).
carrusel() {
  local r
  for _ in 1 2 3 4 5; do
    # La primera tarjeta que empieza a la derecha del borde de la columna (el de la cabecera «Tus finanzas»): las ya
    # pasadas quedan a su izquierda, y en el iPad, bajo la columna del saldo.
    r=$(arbol | python3 -c 'import re,sys
L=sys.stdin.read().splitlines(); f=lambda l: list(map(int,re.search(r"@(-?\d+),(-?\d+) (\d+)x(\d+)$",l).groups()))
borde=next(f(l)[0] for l in L if "|panel_panorama_header|" in l)
for l in L:
    if "|panel_account_card_" in l:
        x,y,w,h=f(l)
        if x>=borde-2: print(x+int(w*.9), x+int(w*.1), y+h//2); break' 2>/dev/null)
    [ -n "$r" ] && { echo "$r"; return; }; sleep 0.7
  done
  echo "300 60 480"
}

[ "${YALA_FICHA_SIN_SEMBRAR:-}" = 1 ] || preparar "$U"
[ "${YALA_FICHA_SIN_SEMBRAR:-}" = 1 ] || "$L" "$IDIOMA" "$APARATO"     # la siembra, una vez (YALA_FICHA_SIN_SEMBRAR=1 la salta)
for p in "${PANTALLAS[@]}"; do
  case "$p" in
    panel)
      # La 08 habla de efectivo, tarjeta y ahorro: «Tus finanzas» desplegado, con sus tarjetas (efectivo primero).
      relanza "${DESPLEGADO[@]}"; esperar "panel_action_new"; desplegar_cuentas; sleep 1; cap panel ;;
    divisas)
      # La tarjeta de la cuenta extranjera, por su nombre (el orden del carrusel lo fija lanzar.sh). En el iPhone se
      # pasa el carrusel hasta que se vea entera.
      relanza "${DESPLEGADO[@]}"; desplegar_cuentas
      for _ in 1 2 3 4; do
        entera "|panel_account_card_" "$CUENTA_EXTRANJERA" && break
        read -r X1 X2 Y <<<"$(carrusel)"
        axe swipe --udid "$U" --start-x "$X1" --start-y "$Y" --end-x "$X2" --end-y "$Y" --duration 0.3 >/dev/null; sleep 1
      done
      # Por su id, con el carrusel ya quieto: tocar sus coordenadas recién arrastrado no abría la ficha. Y con el toque
      # del simulador: en el iPad el «físico» se leía como pulsación larga y abría el menú contextual (16-oct-2026).
      sleep 1
      CARTA="$(arbol | grep -F "|panel_account_card_" | grep -F "$CUENTA_EXTRANJERA" | head -1 | cut -d'|' -f3)"
      axe tap --tap-style simulator --udid "$U" --id "$CARTA" >/dev/null
      cap divisas 3 ;;
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
