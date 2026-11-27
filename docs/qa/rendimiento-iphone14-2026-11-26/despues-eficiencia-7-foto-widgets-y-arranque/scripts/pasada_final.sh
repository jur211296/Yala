#!/bin/bash
# Pasada final del plan de eficiencia en el iPhone 14 (lote 6). Graba una traza con Instruments y conduce el escenario del
# informe sobre Yala Dev (almacén de 16 k, `-uitest -uitest-skip-onboarding`).
#
# Uso: pasada_final.sh <modo> <nombre> <dir salida>
#   vuelta  · Time Profiler + os_signpost + Hitches + Thermal State, lanzada por Instruments · 40 s de arranque, 20 s
#             quieta, 10 ciclos «irse 5-30 s y volver» con scroll (ciclos.sh, MODO=swipe SUBE=3), 15 s. Como B2.
#   reposo  · Time Profiler · 40 s de arranque y 30 s quieta en: Panel arriba, Panel con la tendencia a la vista,
#             Registros, Más, Panel. Como E.
#   energia · Power Profiler · 40 s de arranque, 45 s quieta en el Panel y 3 ciclos. Como J1.
#   memoria · Activity Monitor (todos los procesos), con Yala abierta normal · 45 s de arranque y 10 ciclos. Como F.
# El scroll por pantallas (D) usa el guion del lote 5: ../../despues-eficiencia-5-render-del-scroll/scripts/pasadaD.sh.
U=00008110-001A35A6267A401E; Y=com.jurgenschmidt.yala.dev
CLI="/Applications/Device MCP.app/Contents/MacOS/device-mcp-cli"
H=$(cd "$(dirname "$0")" && pwd)
MODO=$1; N=$2; OUT=$3; mkdir -p "$OUT"
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
ms(){ python3 -c 'import time;print(int(time.time()*1000))'; }
tap(){ "$CLI" tap -x "$1" -y "$2" --device $U --no-launch </dev/null >/dev/null 2>&1; }
flick(){ "$CLI" swipe --from "195,$1" --to "195,$2" --duration-ms 90 --device $U --no-launch </dev/null >/dev/null 2>&1; }

echo "[$(ts)] $N: lockState $(xcrun devicectl device info lockState --device $U 2>&1 | grep passcodeRequired)"
case $MODO in
  vuelta)  INS=(--template "Time Profiler" --instrument "os_signpost" --instrument "Hitches" --instrument "Thermal State") ;;
  reposo)  INS=(--template "Time Profiler") ;;
  energia) INS=(--template "Power Profiler") ;;
  memoria) INS=(--template "Activity Monitor" --all-processes) ;;
  *) echo "modo desconocido: $MODO"; exit 64 ;;
esac
if [ "$MODO" = memoria ]; then
  xcrun devicectl device process launch --device $U --terminate-existing $Y -- -uitest -uitest-skip-onboarding >/dev/null 2>&1
  sleep 45
  xcrun xctrace record --device $U "${INS[@]}" --output "$OUT/$N.trace" --time-limit 25m > "$OUT/$N.xctrace.log" 2>&1 &
else
  xcrun xctrace record --device $U "${INS[@]}" --output "$OUT/$N.trace" --time-limit 25m \
    --launch -- $Y -uitest -uitest-skip-onboarding > "$OUT/$N.xctrace.log" 2>&1 &
fi
XP=$!
ok=0; for i in $(seq 1 120); do grep -q "Ctrl-C to stop" "$OUT/$N.xctrace.log" 2>/dev/null && { ok=1; break; }; kill -0 $XP 2>/dev/null || break; sleep 1; done
[ $ok = 1 ] || { echo "[$(ts)] $N: ABORTADA"; cat "$OUT/$N.xctrace.log"; kill -INT $XP 2>/dev/null; exit 1; }
ms > "$OUT/$N.t0_ms"
[ "$MODO" = memoria ] || { echo "[$(ts)] $N: grabando; 40 s de arranque"; sleep 40; }

case $MODO in
  vuelta|memoria)
    sleep 20
    MODO=swipe SUBE=3 bash "$H/ciclos.sh" $Y 10 "$OUT/$N.ciclos.csv" 6
    sleep 15 ;;
  energia)
    echo "ciclo,evento,hora_lima,epoch_ms,detalle" > "$OUT/$N.reposo.csv"
    echo "panel,quieta_inicio,$(ts),$(ms)," >> "$OUT/$N.reposo.csv"; sleep 45
    echo "panel,quieta_fin,$(ts),$(ms)," >> "$OUT/$N.reposo.csv"
    MODO=swipe SUBE=3 bash "$H/ciclos.sh" $Y 3 "$OUT/$N.ciclos.csv" 6
    sleep 10 ;;
  reposo)
    L="$OUT/$N.ciclos.csv"; echo "ciclo,evento,hora_lima,epoch_ms,detalle" > "$L"
    quieta(){ echo "$1,quieta_inicio,$(ts),$(ms)," >> "$L"; sleep 30; echo "$1,quieta_fin,$(ts),$(ms)," >> "$L"; }
    quieta panel_arriba
    flick 700 180; sleep 0.5; flick 700 180; sleep 2
    quieta panel_tendencia
    tap 204 800; sleep 3; quieta registros
    tap 266 800; sleep 3; quieta mas
    tap 64 800; sleep 3; quieta panel_vuelta ;;
esac
kill -INT $XP; wait $XP; echo "[$(ts)] $N: traza cerrada"; tail -1 "$OUT/$N.xctrace.log"
