#!/usr/bin/env bash
# Banco de qa/scripts/ci-simulador.sh. No toca ningún simulador: sustituye `xcrun` y
# `killall` por falsos que leen el escenario de un directorio temporal.
#
#   bash qa/scripts/ci-simulador-test.sh
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-simulador.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# xcrun falso. Cada llamada a `simctl list -j` consume el siguiente fichero `lista.N`;
# cuando se acaban, repite el último. `create` deja constancia y devuelve un UDID fijo.
cat > "$T/xcrun" <<'FAKE'
#!/usr/bin/env bash
D="$ESCENARIO"
case "$*" in
  "--sdk iphonesimulator --show-sdk-version") cat "$D/sdk" ;;
  "simctl list -j")
    n=$(cat "$D/n" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$D/n"
    f="$D/lista.$n"; [ -f "$f" ] || f="$(ls "$D"/lista.* | sort -t. -k2 -n | tail -1)"
    cat "$f" ;;
  simctl\ create*) echo "$*" >> "$D/creados"; echo "CREADO-0000" ;;
  "simctl list runtimes") echo "(sin runtimes)" ;;
  "simctl list devices") echo "lista de devices" ;;
  *) echo "xcrun falso: llamada inesperada: $*" >&2; exit 9 ;;
esac
FAKE
cat > "$T/killall" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$ESCENARIO/reinicios"
FAKE
cat > "$T/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$ESCENARIO/descargas"
FAKE
chmod +x "$T/xcrun" "$T/killall" "$T/xcodebuild"

RT26_5='{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-5","version":"26.5","platform":"iOS","isAvailable":true}'
RT26_4='{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-4","version":"26.4","platform":"iOS","isAvailable":true}'
RT27_0='{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-27-0","version":"27.0","platform":"iOS","isAvailable":true}'
dev() { echo "{\"name\":\"$1\",\"udid\":\"$2\",\"isAvailable\":${3:-true}}"; }
VACIO='{"devicetypes":[],"runtimes":[],"devices":{}}'

fallos=0
# caso <nombre> <sdk> <exit> <udid|-> <reinicios> <creados> <descargas> lista...
caso() {
  local nombre="$1" sdk="$2" exit_esp="$3" udid_esp="$4" rein_esp="$5" crea_esp="$6" desc_esp="$7"; shift 7
  local d="$T/$nombre"; mkdir -p "$d"; echo "$sdk" > "$d/sdk"
  local i=0; for l in "$@"; do i=$((i+1)); echo "$l" > "$d/lista.$i"; done
  : > "$d/out"; : > "$d/reinicios"; : > "$d/creados"; : > "$d/descargas"
  ESCENARIO="$d" XCRUN="$T/xcrun" KILLALL="$T/killall" XCODEBUILD="$T/xcodebuild" GITHUB_OUTPUT="$d/out" \
    SIM_INTENTOS=4 SIM_DESCARGA_TRAS=2 SIM_ESPERA=0 bash "$SCRIPT" > "$d/log" 2>&1
  local ex=$? udid; udid="$(sed -n 's/^udid=//p' "$d/out")"; [ -n "$udid" ] || udid="-"
  local rein crea; rein=$(wc -l < "$d/reinicios" 2>/dev/null || echo 0); rein=$((rein+0))
  crea=$(wc -l < "$d/creados" 2>/dev/null || echo 0); crea=$((crea+0)); local desc; desc=$(wc -l < "$d/descargas"); desc=$((desc+0))
  if [ "$ex" = "$exit_esp" ] && [ "$udid" = "$udid_esp" ] && [ "$rein" = "$rein_esp" ] && [ "$crea" = "$crea_esp" ] && [ "$desc" = "$desc_esp" ]; then
    echo "ok   $nombre"
  else
    echo "FALLA $nombre: exit $ex/$exit_esp udid $udid/$udid_esp reinicios $rein/$rein_esp creados $crea/$crea_esp descargas $desc/$desc_esp"
    sed 's/^/      /' "$d/log"; fallos=$((fallos+1))
  fi
}

# 1. El caso de siempre: el device está y casa con el SDK.
caso encontrado 26.5 0 AAA 0 0 0 \
  "{\"runtimes\":[$RT26_5],\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-26-5\":[$(dev 'iPhone 17 Pro' AAA)]}}"
# 2. El nombre en dos runtimes: gana el del SDK aunque haya uno más nuevo.
caso gana-el-del-sdk 26.5 0 SDK 0 0 0 \
  "{\"runtimes\":[$RT27_0,$RT26_5],\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-27-0\":[$(dev 'iPhone 17 Pro' NUEVO)],\"com.apple.CoreSimulator.SimRuntime.iOS-26-5\":[$(dev 'iPhone 17 Pro' SDK)]}}"
# 3. Ningún runtime casa con el SDK: el más nuevo.
caso sin-sdk-el-mas-nuevo 26.5 0 NUEVO 0 0 0 \
  "{\"runtimes\":[$RT26_4,$RT27_0],\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-26-4\":[$(dev 'iPhone 17 Pro' VIEJO)],\"com.apple.CoreSimulator.SimRuntime.iOS-27-0\":[$(dev 'iPhone 17 Pro' NUEVO)]}}"
# 4. Hay runtime pero no device (o solo uno no disponible, u otro modelo): se crea.
caso crea-por-tipo 26.5 0 CREADO-0000 0 1 0 \
  "{\"runtimes\":[$RT26_5],\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-26-5\":[$(dev 'iPhone 17 Pro' ROTO false),$(dev 'iPhone 17' OTRO)]}}"
# 5. La caída real: CoreSimulator vacío dos veces y luego responde. Dos reinicios, y
#    a la segunda vacía (SIM_DESCARGA_TRAS=2) descarga la plataforma una vez.
caso vacio-y-se-recupera 26.5 0 TARDE 2 0 1 \
  "$VACIO" "$VACIO" \
  "{\"runtimes\":[$RT26_5],\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-26-5\":[$(dev 'iPhone 17 Pro' TARDE)]}}"
# 6. Nunca responde: falla con exit 1, sin udid, no reinicia tras la última vuelta y
#    descarga UNA sola vez aunque sigan llegando vueltas vacías.
caso vacio-siempre 26.5 1 - 3 0 1 "$VACIO"
# 8. Un solo vacío y luego responde: no llega al umbral, no descarga.
caso un-vacio-no-descarga 26.5 0 PRONTO 1 0 0 \
  "$VACIO" \
  "{\"runtimes\":[$RT26_5],\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-26-5\":[$(dev 'iPhone 17 Pro' PRONTO)]}}"
# 7. Salida rota de simctl (no JSON): cuenta como vacío, no revienta el script.
caso json-roto 26.5 1 - 3 0 1 "esto no es json"

echo
if [ "$fallos" -eq 0 ]; then echo "ci-simulador: 8/8 verdes"; else echo "ci-simulador: $fallos en rojo"; exit 1; fi
