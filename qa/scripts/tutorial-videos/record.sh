#!/bin/bash
# Graba UN vídeo de tutorial (Ajustes › Tutoriales) desde su caso de YalaUITests/Flows/TutorialVideoRecordingUITests.
#
#   bash qa/scripts/tutorial-videos/record.sh test_rec_createAccount_step0 [udid]
#
# Antes: `xcodebuild build-for-testing -scheme "Yala Dev"` con el mismo -derivedDataPath (DERIVED, por defecto el de
# Xcode). Deja el clip en qa/scripts/tutorial-videos/out/tutorial-<tutorial>-step<N>.mp4; se copia a Yala/Resources a mano.
#
# Por qué un apretón de manos y no recortar por reloj (medido el 2026-10-22): `simctl io recordVideo` solo escribe un
# fotograma cuando cambia la pantalla, así que el tiempo del vídeo no casa con el reloj del Mac. El test escribe
# `<caso>.start`, espera a que este script grabe y conteste `.go`; al acabar escribe `.end` y espera `.done`.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../.." && pwd)
T=$1; U=${2:-${SIMU:-386CA5C3-9CA1-4FBB-B780-606135DE7C2A}}
DERIVED=${DERIVED:-}
D=$HERE/marks; mkdir -p "$D" "$HERE/raw" "$HERE/out"
rm -f "$D/$T".{start,end,go,done}
DD=(); [ -n "$DERIVED" ] && DD=(-derivedDataPath "$DERIVED")
cd "$REPO" && TEST_RUNNER_YALA_RECORD_DIR="$D" xcodebuild test-without-building -project Yala.xcodeproj -scheme "Yala Dev" \
  -destination "platform=iOS Simulator,id=$U" "${DD[@]}" -parallel-testing-enabled NO \
  -only-testing:YalaUITests/TutorialVideoRecordingUITests/$T > "$HERE/raw/$T.log" 2>&1 &
XP=$!
while [ ! -f "$D/$T.start" ] && kill -0 $XP 2>/dev/null; do sleep 0.1; done
if [ ! -f "$D/$T.start" ]; then wait $XP; echo "$T: sin marca de inicio"; exit 1; fi
xcrun simctl io "$U" recordVideo --codec=h264 --force "$HERE/raw/$T.mov" >/dev/null 2>&1 &
RP=$!; sleep 1.0
GO=$(python3 -c 'import time;print(time.time())'); touch "$D/$T.go"
while [ ! -f "$D/$T.end" ] && kill -0 $XP 2>/dev/null; do sleep 0.1; done
sleep 0.3; END=$(python3 -c 'import time;print(time.time())')
kill -INT $RP; wait $RP 2>/dev/null; touch "$D/$T.done"
wait $XP; EC=$?
[ -f "$D/$T.end" ] || { echo "$T: sin marca de fin (exit $EC)"; exit 1; }
L=$(python3 -c "print(round($END-$GO,2))")
name=${T#test_rec_}; OUT="$HERE/out/tutorial-${name%_step*}-${name##*_}.mp4"
# Marco del teléfono (frame.png) sobre fondo negro de 1080×1080, como los vídeos de 1.1. `tpad` sostiene el último
# fotograma hasta el final del tramo: si la pantalla se queda quieta, simctl no escribe nada más.
ffmpeg -v error -y -i "$HERE/raw/$T.mov" -i "$HERE/frame.png" -f lavfi -i color=c=black:s=1080x1080:r=30 \
 -filter_complex "[0:v]setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=20,fps=30,scale=402:874:flags=lanczos[s];[2:v][s]overlay=339:103:shortest=1[b];[b][1:v]overlay=0:0,format=yuv420p[v]" \
 -map "[v]" -t "$L" -c:v libx264 -preset slow -crf 26 -movflags +faststart -an "$OUT" && echo "$T: ok ($L s) → $OUT"
