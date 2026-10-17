#!/usr/bin/env bash
# Graba una demo de Yala en el simulador mientras la recorre un XCUITest.
#
#   scripts/grabar-demo-sim.sh [--test <id>] [--salida <dir>] [--udid <udid>]
#                              [--sin-build] [--claro] [--sin-grabar]
#
# Por defecto: DemoIAPizza (registrar una pizza con Yala IA) en el iPhone 17 Pro,
# modo oscuro, barra de estado 9:41, salida en ~/Claude/propuestas/demo-ia-pizza-<fecha>/.
# Deja: crudo.mp4 (lo que graba simctl), demo.mp4 (H.264 60 fps recortado de
# «inicio» a «fin», listo para public/footage/), capturas/<marca>.png y marcas.json.
# --sin-grabar rehace solo el montaje a partir del crudo y las marcas que ya hay.
#
# Escrito para bash 3.2, el de macOS. Comprueba el resultado al final: «grabado»
# no es «hay vídeo».
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$SCRIPTS/../../.." && pwd)"   # raíz del repo Yala
TEST="YalaUITests/DemoIAPizzaUITests/test_registrarPizzaConYalaIA"
SALIDA="$HOME/Claude/propuestas/demo-ia-pizza-$(date +%F)"
UDID=""
CONSTRUIR=1
GRABAR=1
APARIENCIA="dark"
SCHEME="Yala Dev"
MODELO="iPhone 17 Pro"

while [ $# -gt 0 ]; do
  case "$1" in
    --test) TEST="$2"; shift 2 ;;
    --salida) SALIDA="$2"; shift 2 ;;
    --udid) UDID="$2"; shift 2 ;;
    --sin-build) CONSTRUIR=0; shift ;;
    --sin-grabar) GRABAR=0; shift ;;
    --claro) APARIENCIA="light"; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "✗ argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

falla() { echo "✗ $*" >&2; exit 1; }

CRUDO="$SALIDA/crudo.mp4"
DEMO="$SALIDA/demo.mp4"
MARCAS_TSV="$SALIDA/marcas.tsv"
ANCLAS_TSV="$SALIDA/marcas-video.tsv"
LOG="$SALIDA/xcodebuild.log"

grabar() {
  # --- Reglas de la Mini: a cualquier hora, un solo simulador a la vez, carga baja. ---
  local carga otros
  carga=$(sysctl -n vm.loadavg | awk '{print int($2)}')
  [ "$carga" -lt 8 ] || falla "carga ${carga} (≥ 8): espera a que baje"

  if [ -z "$UDID" ]; then
    UDID=$(xcrun simctl list devices available | grep -F "    $MODELO (" | tail -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  fi
  [ -n "$UDID" ] || falla "no hay ningún «$MODELO» disponible; pásalo con --udid"
  otros=$(xcrun simctl list devices booted | grep -E '\([0-9A-F-]{36}\) \(Booted\)' | grep -v "$UDID" || true)
  if [ -n "$otros" ]; then
    echo "$otros" >&2
    falla "hay otro simulador encendido: uno como máximo. Apágalo antes."
  fi

  mkdir -p "$SALIDA/capturas"
  : > "$MARCAS_TSV"
  echo "→ simulador $UDID · $APARIENCIA · $TEST"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl ui "$UDID" appearance "$APARIENCIA"
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --operatorName "" \
    --batteryState charged --batteryLevel 100
  trap limpiar EXIT

  local destino="platform=iOS Simulator,id=$UDID"
  cd "$RAIZ"
  if [ "$CONSTRUIR" -eq 1 ]; then
    echo "→ build-for-testing ($SCHEME) — fuera de la grabación"
    nice -n 10 xcodebuild build-for-testing -project Yala.xcodeproj -scheme "$SCHEME" \
      -destination "$destino" -jobs 2 -quiet > "$SALIDA/build.log" 2>&1 \
      || { tail -30 "$SALIDA/build.log" >&2; falla "el build-for-testing falló (log: $SALIDA/build.log)"; }
  fi

  # --- Grabar. simctl avisa por stderr cuando de verdad empieza. ---
  local err_video="$SALIDA/recordVideo.log"
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$CRUDO" 2> "$err_video" &
  PID_VIDEO=$!
  for _ in $(seq 1 50); do
    grep -q "Recording started" "$err_video" 2>/dev/null && break
    sleep 0.2
  done
  grep -q "Recording started" "$err_video" || falla "recordVideo no arrancó: $(cat "$err_video")"
  local t0
  t0=$(python3 -I -c 'import time; print(time.time())')

  # --- Correr el test. Cada «DEMO-MARCA:<id> t=<epoch>» de la salida es un beat:
  # se apunta su segundo respecto al arranque de la grabación y se saca la captura.
  # La línea llega a la salida ~1,5 s tarde: la captura enseña lo que había ENTONCES,
  # y por eso el segundo sale del t= del test y no de la hora de llegada. ---
  local lector='
import subprocess, sys, time
t0, udid, carpeta, tsv = float(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
with open(tsv, "a") as marcas:
    for linea in sys.stdin:
        sys.stdout.write(linea)
        if "DEMO-MARCA:" not in linea:
            continue
        resto = linea.split("DEMO-MARCA:", 1)[1].split()
        marca = resto[0].strip("\"\x27.,")
        epoch = next((float(x[2:]) for x in resto[1:] if x.startswith("t=")), time.time())
        subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", "--type=png",
                        f"{carpeta}/{marca}.png"], capture_output=True)
        marcas.write(f"{marca}\t{epoch - t0:.3f}\n")
        marcas.flush()
'
  set +e
  nice -n 10 xcodebuild test-without-building -project Yala.xcodeproj -scheme "$SCHEME" \
    -destination "$destino" -only-testing:"$TEST" 2>&1 \
    | python3 -I -u -c "$lector" "$t0" "$UDID" "$SALIDA/capturas" "$MARCAS_TSV" > "$LOG"
  local estado=${PIPESTATUS[0]}
  set -e

  kill -INT "$PID_VIDEO" 2>/dev/null || true
  wait "$PID_VIDEO" 2>/dev/null || true
  PID_VIDEO=""
  [ "$estado" -eq 0 ] || { grep -E "error:|failed|XCTAssert" "$LOG" | tail -15 >&2; falla "el test falló (log: $LOG)"; }
}

limpiar() {
  if [ -n "${PID_VIDEO:-}" ] && kill -0 "$PID_VIDEO" 2>/dev/null; then
    kill -INT "$PID_VIDEO" 2>/dev/null || true
    wait "$PID_VIDEO" 2>/dev/null || true
  fi
  xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
}

montar() {
  [ -s "$CRUDO" ] || falla "no hay vídeo en $CRUDO"
  [ -s "$MARCAS_TSV" ] || falla "no hay marcas en $MARCAS_TSV: el test no imprimió ninguna DEMO-MARCA"

  # --- Pasar las marcas a segundos del vídeo. Los pts de simctl no siguen el
  # reloj del Mac, así que cada estado quieto se ancla a su primer fotograma
  # visible (anclar-marcas.py). Sin numpy, se queda el reloj. ---
  if ! python3 -I "$SCRIPTS/anclar-marcas.py" "$CRUDO" "$MARCAS_TSV" "$SALIDA/capturas" "$ANCLAS_TSV"; then
    echo "⚠ sin anclaje por contenido: las marcas van por reloj y pueden caer hasta ~2 s tarde" >&2
    awk -F'\t' '{print $1"\t"$2"\treloj"}' "$MARCAS_TSV" > "$ANCLAS_TSV"
  fi

  # --- A 60 fps constantes y recortado de «inicio» a «fin» con medio segundo de
  # aire. OJO: el H.264 de simctl trae DTS que no casan con los PTS, y ffmpeg
  # (8.1) los usa para reordenar: sin -fflags +igndts, -ss, fps y select caen
  # hasta 4 s antes de lo que dice el fichero. ffprobe sí lee bien los PTS. ---
  local desde hasta
  desde=$(awk -F'\t' '$1=="inicio"{s=$2-0.5; if (s<0) s=0; print s; exit}' "$ANCLAS_TSV")
  hasta=$(awk -F'\t' '$1=="fin"{print $2+0.5; exit}' "$ANCLAS_TSV")
  desde=${desde:-0}
  hasta=${hasta:-$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$CRUDO")}
  ffmpeg -v error -y -fflags +igndts -i "$CRUDO" -an \
    -vf "trim=start=${desde}:end=${hasta},setpts=PTS-STARTPTS,fps=60,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 60 -movflags +faststart "$DEMO"

  python3 -I - "$MARCAS_TSV" "$ANCLAS_TSV" "$desde" "$DEMO" "$SALIDA/marcas.json" <<'PY'
import json, subprocess, sys
reloj_tsv, video_tsv, desde, demo, salida = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4], sys.argv[5]
def probe(campo, flujo=True):
    args = ["ffprobe", "-v", "error"] + (["-select_streams", "v:0"] if flujo else []) + [
        "-show_entries", campo, "-of", "csv=p=0", demo]
    return subprocess.run(args, capture_output=True, text=True).stdout.strip()
reloj = dict(l.rstrip("\n").split("\t")[:2] for l in open(reloj_tsv) if l.strip())
marcas = []
for linea in open(video_tsv):
    marca, seg, origen = linea.rstrip("\n").split("\t")
    marcas.append({"marca": marca, "segDemo": round(max(0.0, float(seg) - desde), 3),
                   "segCrudo": float(seg), "segReloj": float(reloj[marca]), "origen": origen})
w, h = probe("stream=width,height").split(",")
info = {"demo": demo, "codec": probe("stream=codec_name"), "w": int(w), "h": int(h),
        "durSec": float(probe("format=duration", flujo=False)), "fps": probe("stream=r_frame_rate"),
        "marcas": marcas}
json.dump(info, open(salida, "w"), indent=2, ensure_ascii=False)
print(json.dumps({k: v for k, v in info.items() if k != "marcas"}, ensure_ascii=False))
PY

  local codec
  codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$DEMO")
  [ "$codec" = "h264" ] || falla "demo.mp4 salió en $codec, no en h264"
  echo "✓ $DEMO · $(wc -l < "$ANCLAS_TSV" | tr -d ' ') marcas · capturas en $SALIDA/capturas"
}

if [ "$GRABAR" -eq 1 ]; then
  grabar
fi
montar
