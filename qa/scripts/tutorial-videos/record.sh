#!/bin/bash
# Graba vídeos de tutorial (Ajustes › Tutoriales) desde sus casos de YalaUITests/Flows/TutorialVideoRecordingUITests.
#
#   bash qa/scripts/tutorial-videos/record.sh test_rec_createAccount_step0 [udid]
#   bash qa/scripts/tutorial-videos/record.sh --lote test_rec_createAccount_step0 test_rec_createAccount_step1 …
#
# Con `--lote` corre todos los casos en UNA corrida de xcodebuild (el arranque del runner se paga una vez) y graba cada
# uno al ver su marca. El simulador: el udid del segundo argumento, `SIMU`, o el primer «iPhone 17 Pro» disponible.
#
# Antes: `xcodebuild build-for-testing -scheme "Yala Dev"` con el mismo -derivedDataPath (DERIVED, por defecto el de
# Xcode). Deja cada clip en qa/scripts/tutorial-videos/out/tutorial-<tutorial>-step<N>.mp4; se copia a Yala/Resources
# a mano, después de mirarlo.
#
# Por qué un apretón de manos y no recortar por reloj (medido el 2026-10-22): `simctl io recordVideo` solo escribe un
# fotograma cuando cambia la pantalla, así que el tiempo del vídeo no casa con el reloj del Mac. El test escribe
# `<caso>.start`, espera a que este script grabe y conteste `.go`; al acabar escribe `.end` y espera `.done`.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../.." && pwd)
if [ "${1:-}" = "--lote" ]; then
  shift; CASOS=("$@"); U=${SIMU:-}
else
  CASOS=("$1"); U=${2:-${SIMU:-}}
fi
[ -n "$U" ] || U=$(xcrun simctl list devices available | grep -m1 "iPhone 17 Pro (" | grep -oE '[0-9A-F-]{36}')
DERIVED=${DERIVED:-}
D=$HERE/marks; mkdir -p "$D" "$HERE/raw" "$HERE/out"
DD=(); [ -n "$DERIVED" ] && DD=(-derivedDataPath "$DERIVED")
ONLY=()
for T in "${CASOS[@]}"; do
  rm -f "$D/$T".{start,end,go,done}
  ONLY+=("-only-testing:YalaUITests/TutorialVideoRecordingUITests/$T")
done
LOG="$HERE/raw/${CASOS[0]}.log"; [ ${#CASOS[@]} -gt 1 ] && LOG="$HERE/raw/lote-$(date +%H%M%S).log"
cd "$REPO" && TEST_RUNNER_YALA_RECORD_DIR="$D" xcodebuild test-without-building -project Yala.xcodeproj -scheme "Yala Dev" \
  -destination "platform=iOS Simulator,id=$U" "${DD[@]}" -parallel-testing-enabled NO "${ONLY[@]}" > "$LOG" 2>&1 &
XP=$!
ahora() { python3 -c 'import time;print(time.time())'; }

# Otro caso del lote ya empezó: el actual murió antes de su marca de fin.
otro_empezo() {
  local c
  for c in "${CASOS[@]}"; do [ "$c" != "$1" ] && [ -f "$D/$c.start" ] && [ ! -f "$D/$c.go" ] && return 0; done
  return 1
}

grabar() {
  local T=$1
  xcrun simctl io "$U" recordVideo --codec=h264 --force "$HERE/raw/$T.mov" >/dev/null 2>&1 &
  local RP=$!; sleep 1.0
  local GO; GO=$(ahora); touch "$D/$T.go"
  while [ ! -f "$D/$T.end" ] && kill -0 $XP 2>/dev/null && ! otro_empezo "$T"; do sleep 0.1; done
  sleep 0.3; local END; END=$(ahora)
  kill -INT $RP; wait $RP 2>/dev/null; touch "$D/$T.done"
  [ -f "$D/$T.end" ] || { echo "$T: sin marca de fin"; return 1; }
  local L; L=$(python3 -c "print(round($END-$GO,2))")
  local name=${T#test_rec_}; local OUT="$HERE/out/tutorial-${name%_step*}-${name##*_}.mp4"
  # Marco del teléfono (frame.png) sobre fondo negro de 1080×1080, como los vídeos de 1.1. `tpad` sostiene el último
  # fotograma hasta el final del tramo: si la pantalla se queda quieta, simctl no escribe nada más.
  ffmpeg -v error -y -i "$HERE/raw/$T.mov" -i "$HERE/frame.png" -f lavfi -i color=c=black:s=1080x1080:r=30 \
   -filter_complex "[0:v]setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=20,fps=30,scale=402:874:flags=lanczos[s];[2:v][s]overlay=339:103:shortest=1[b];[b][1:v]overlay=0:0,format=yuv420p[v]" \
   -map "[v]" -t "$L" -c:v libx264 -preset slow -crf 26 -movflags +faststart -an "$OUT" && echo "$T: ok ($L s) → $OUT"
}

HECHOS=()
while kill -0 $XP 2>/dev/null; do
  T=""
  for c in "${CASOS[@]}"; do [ -f "$D/$c.start" ] && [ ! -f "$D/$c.go" ] && { T=$c; break; }; done
  if [ -z "$T" ]; then sleep 0.1; continue; fi
  grabar "$T" && HECHOS+=("$T")
done
wait $XP; EC=$?
for c in "${CASOS[@]}"; do
  [[ " ${HECHOS[*]:-} " == *" $c "* ]] || echo "$c: sin vídeo (xcodebuild exit $EC; log $LOG)"
done
[ ${#HECHOS[@]} -eq ${#CASOS[@]} ]
