# duo/comun.sh — conducir el simulador del iPhone Duo. Uso: source duo/comun.sh (después de source comun.sh <idioma>).
# Deja: U (el Duo de idiomas.json), INNER/OUTER (sus dos pantallas), y las funciones pose, toca, toca_id, arrastra.
#
# Por qué así (medido el 2026-10-24, Xcode 27.1, runtime iOS 27.1):
# - Las posturas (cerrado, medio plegado, abierto, girar) son botones de Device Hub; `simctl` no las tiene.
# - Los toques de `axe` y de XcodeBuildMCP no llegan a la app del Duo (ni cerrado ni girado); `axe` sí lee el árbol.
#   Lo que funciona es hacer clic en la pantalla del Duo DENTRO de Device Hub: se localiza comparando la captura del
#   simulador con la del Mac (hubmap.py, que prueba las cuatro rotaciones) y se convierten los puntos (mappt.py).
# - Hace falta la ventana de Device Hub con el Duo seleccionado y a la vista, y que la Terminal tenga Accesibilidad.
DUO="$MOLDE/duo"
U="$(udid duo)"
CACHE="${YALA_FICHA_CACHE:-$HOME/Library/Caches/Yala/ficha}"; mkdir -p "$CACHE"
CLIC="$CACHE/clic"
[ -x "$CLIC" ] && [ "$CLIC" -nt "$DUO/clic.swift" ] || swiftc -O "$DUO/clic.swift" -o "$CLIC"
source "$MOLDE/capturas/ui.sh"
# Las pantallas, por su ancho nativo (cambian de id al borrar el simulador): interior 2007, exterior 1398.
pantalla() { xcrun simctl io "$U" enumerate 2>/dev/null | python3 -c "
import sys,re
for b in sys.stdin.read().split('Port:'):
    u=re.search(r'UUID: (\S+)',b); w=re.search(r'Default width: (\d+)',b)
    if u and w and w.group(1)=='$1': print(u.group(1)); break"; }
INNER=$(pantalla 2007); OUTER=$(pantalla 1398)
hub() { osascript -e 'tell application "DeviceHub" to activate' >/dev/null; sleep 0.5; }
# Dónde están los botones de postura en la pantalla del Mac (puntos). Dependen de dónde esté la ventana de Device
# Hub: los de 2026-10-24 son para la ventana tal como abre en la Mini (1920×1080). Si se movió, se pasan por entorno.
POSE_CERRADO="${YALA_DUO_POSE_CERRADO:-1094 784}"; POSE_MEDIO="${YALA_DUO_POSE_MEDIO:-1129 784}"
POSE_ABIERTO="${YALA_DUO_POSE_ABIERTO:-1163 784}"; POSE_GIRAR="${YALA_DUO_POSE_GIRAR:-1057 784}"
# pose <cerrado|medio|abierto|girar> [espera]. «medio» es medio plegado: el único en que el sistema da el pliegue activo.
pose() { hub; local xy; case "$1" in cerrado) xy=$POSE_CERRADO;; medio) xy=$POSE_MEDIO;; abierto) xy=$POSE_ABIERTO;; girar) xy=$POSE_GIRAR;; esac
  "$CLIC" ${xy% *} ${xy#* }; sleep "${2:-4}"; }
# mapa <interior|exterior>: deja MAP="X0 Y0 ancho alto rotación", dónde se ve esa pantalla dentro de Device Hub.
mapa() {
  local disp=$([ "$1" = interior ] && echo $INNER || echo $OUTER)
  xcrun simctl io "$U" screenshot --display=$disp "$CACHE/duo-sim.png" >/dev/null 2>&1
  hub; screencapture -x "$CACHE/duo-mac.png"
  MAP=$(python3 "$DUO/hubmap.py" "$CACHE/duo-mac.png" "$CACHE/duo-sim.png" | cut -d' ' -f1-5)
}
# toca <x> <y> <interior|exterior>: toque en puntos de la app.
toca() { mapa "$3"; local xy; xy=$(python3 "$DUO/mappt.py" "$CACHE/duo-sim.png" "$MAP" "$1" "$2"); "$CLIC" ${xy% *} ${xy#* }; }
# toca_id <texto de su línea en el árbol, p. ej. «|panel_action_ai|»> <interior|exterior>: toca su centro.
toca_id() {
  local xy; xy=$(arbol | grep -F -- "$1" | head -1 | sed -E 's/.*@(-?[0-9]+),(-?[0-9]+) ([0-9]+)x([0-9]+)$/\1 \2 \3 \4/' | awk '{print $1+$3/2, $2+$4/2}')
  [ -n "$xy" ] || { echo "✗ no está «$1»" >&2; return 1; }
  toca ${xy% *} ${xy#* } "$2"
}
# arrastra <x1> <y1> <x2> <y2> <interior|exterior>
arrastra() { mapa "$5"; local r a b c d; r=$(python3 "$DUO/mappt.py" "$CACHE/duo-sim.png" "$MAP" "$1" "$2" "$3" "$4"); read -r a b c d <<<"$r"; "$CLIC" "$a" "$b" drag "$c" "$d"; }
