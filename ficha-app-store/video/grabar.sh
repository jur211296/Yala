#!/usr/bin/env bash
# Graba una escena del vídeo en el iPhone del molde, en el idioma de la ficha, y apunta dónde y cuándo se toca.
#   video/grabar.sh <idioma> <ia|foto|voz|grupos|todas>
# Deja <salida>/<idioma>/video/tomas/<escena>.mp4 (30 fps constantes, como las pide tomas.py) y <escena>.marcas.json:
# [{t: segundos desde el primer fotograma, x, y: puntos de pantalla, tipo: "toque"|"marca", que}]. Los cortes de cada
# escena se miden después sobre la grabación y van a video/cortes/<idioma>.json.
# Necesita la app instalada y el iPhone encendido. Siembra una vez (lanzar.sh) y relanza sin sembrar en cada escena.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
ESCENA="${2:?Falta la escena: ia foto voz grupos todas}"
U="$(udid iphone)"
source "$MOLDE/capturas/ui.sh"
L="$MOLDE/capturas/lanzar.sh"
T="$SALIDA/video/tomas"; mkdir -p "$T"
ahora() { python3 -c 'import time; print("%.3f" % time.time())'; }

MARCAS=(); T0=0; GRABADOR=0
marca() { MARCAS+=("{\"t\": $(python3 -c "print(round($(ahora) - $T0, 3))"), \"tipo\": \"marca\", \"que\": \"$1\"}"); }
# toque <id|etiqueta> [otro texto de la misma línea]: apunta el centro del elemento y lo toca ahí.
toque() {
  esperar "$1" 20 || return 1
  local caja xy
  caja=$(arbol | grep -F -- "|$1|" | grep -F -- "${2:-}" | head -1)
  xy=$(echo "$caja" | sed -E 's/.*@(-?[0-9]+),(-?[0-9]+) ([0-9]+)x([0-9]+)$/\1 \2 \3 \4/' | awk '{print $1+$3/2, $2+$4/2}')
  # axe tarda en conectar: el toque llega al final de la llamada, así que la marca va después (medido: ~2 s de retraso
  # si se apunta antes).
  # Medido el 16-oct-2026: el campo del chat solo toma el foco con una pulsación de dedo (abajo, 0,25 s, arriba); con
  # `axe tap` lo tecleado se perdía. Pero esa pulsación, en una tarjeta con menú contextual (la del grupo), abre el menú:
  # el resto va con el toque físico.
  if [ "$1" = chat_input ]; then
    axe touch --udid "$U" -x "${xy% *}" -y "${xy#* }" --down >/dev/null; sleep 0.25
    axe touch --udid "$U" -x "${xy% *}" -y "${xy#* }" --up >/dev/null
  else
    axe tap --tap-style physical --udid "$U" -x "${xy% *}" -y "${xy#* }" >/dev/null
  fi
  MARCAS+=("{\"t\": $(python3 -c "print(round($(ahora) - $T0 - 0.1, 3))"), \"x\": ${xy% *}, \"y\": ${xy#* }, \"tipo\": \"toque\", \"que\": \"$1\"}")
}
graba() {   # graba <escena>: arranca la grabación y espera a que de verdad grabe
  rm -f "$T/$1.mov" "$T/$1.log"
  xcrun simctl io "$U" recordVideo --codec=h264 --force "$T/$1.mov" 2>"$T/$1.log" &
  GRABADOR=$!
  for _ in $(seq 1 100); do grep -q "Recording started" "$T/$1.log" 2>/dev/null && break; sleep 0.05; done
  T0=$(ahora); MARCAS=()
}
corta() {   # corta <escena>: para la grabación, la pasa a 30 fps y escribe sus marcas
  local real; real=$(python3 -c "print(round($(ahora) - $T0, 3))")
  kill -INT "$GRABADOR"; wait "$GRABADOR" 2>/dev/null || true
  # simctl solo escribe fotogramas cuando la pantalla cambia: un final quieto no queda en el fichero. Se congela el último
  # fotograma hasta el tiempo real que duró la grabación.
  local escrito falta
  escrito=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$T/$1.mov")
  falta=$(python3 -c "print(max(0, round($real - $escrito, 3)))")
  ffmpeg -v error -y -i "$T/$1.mov" -vf "fps=30,tpad=stop_mode=clone:stop_duration=$falta,format=yuv420p" \
    -c:v libx264 -crf 14 -g 30 -movflags +faststart "$T/$1.mp4"
  (IFS=,; echo "[${MARCAS[*]}]") | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), ensure_ascii=False, indent=1))' > "$T/$1.marcas.json"
  rm -f "$T/$1.mov" "$T/$1.log"
  echo "✓ $IDIOMA · $1: $(printf %.1f "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$T/$1.mp4")") s, ${#MARCAS[@]} marcas"
}
# Tras `uitest_ready` la app aún termina de arrancar: un toque en los primeros segundos se perdía (medido el 16-oct-2026,
# Yala IA y la tarjeta del grupo no se abrían).
relanza() { "$L" "$IDIOMA" iphone --sin-semilla "$@" >/dev/null; sleep 3; }

# Lo que se escribe en el chat (la respuesta la finge -uitest-chat-reply pizza: «Pizza · <importe> · Restaurantes», con el
# importe de DevSeedFicha.Cifras.pizza en la divisa de la ficha: 28 dólares, 90 reales). Sin tildes: axe no las escribe.
case "$IDIOMA" in
  en) FRASE="Pizza with friends 28" ;;
  pt-BR) FRASE="Pizza com os amigos 90" ;;
  *) FRASE="Pizza con amigos 280" ;;
esac

# El viaje de la ficha, como se llama en la app en ese idioma (hay otro grupo y el orden de la lista no es fijo).
VIAJE=$(python3 -c 'import re,sys
t=open(sys.argv[1],encoding="utf-8").read()
print(re.search(r"^\"devseed\.ficha\.groupTrip\" = \"(.*)\";", t, re.M).group(1))' "$MOLDE/../Yala/Resources/$LPROJ.lproj/Localizable.strings")

escena() {
  case "$1" in
    ia)
      relanza -uitest-chat-suggestions -uitest-chat-reply pizza -uitest-ai-chat-ready
      id panel_action_ai; esperar "chat_suggestion"; sleep 1
      graba ia; sleep 1.2
      toque chat_input; sleep 1.2; marca escribe
      axe type "$FRASE" --udid "$U" >/dev/null; sleep 0.8
      toque chat_send; esperar "chat_draft_save" 15; marca tarjeta; sleep 2.5
      corta ia ;;
    foto)
      relanza -uitest-image-result one -uitest-image-file "$SALIDA/recibo.png"
      esperar "panel_action_image"; sleep 1
      graba foto; sleep 1.2
      toque panel_action_image; esperar "image_source_photos"; sleep 1.2
      toque image_source_photos; esperar "image_review_title" 15; marca leido; sleep 2.5
      corta foto ;;
    voz)
      relanza -uitest-voice-result one
      esperar "panel_action_voice"; sleep 1
      graba voz; sleep 1.2
      toque panel_action_voice; esperar "voice_done"; marca escucha; sleep 3
      toque voice_done; esperar "voice_draft_row" 15; marca entendido; sleep 2.5
      corta voz ;;
    grupos)
      relanza -uitest-deeplink groups
      esperar "group_card"; sleep 1
      graba grupos; sleep 1.2
      toque group_card "$VIAJE"; esperar "group_header_balance" 10; marca detalle; sleep 3.5
      corta grupos ;;
    *) echo "✗ escena desconocida: $1" >&2; exit 1 ;;
  esac
}

[ -f "$SALIDA/recibo.png" ] || "$MOLDE/capturas/recibo.sh" "$IDIOMA" >/dev/null
[ "${YALA_FICHA_SIN_SEMBRAR:-}" = 1 ] || { preparar "$U"; "$L" "$IDIOMA" iphone >/dev/null; }   # simulador limpio y la siembra, una vez
if [ "$ESCENA" = todas ]; then for e in ia foto voz grupos; do escena "$e"; done; else escena "$ESCENA"; fi
