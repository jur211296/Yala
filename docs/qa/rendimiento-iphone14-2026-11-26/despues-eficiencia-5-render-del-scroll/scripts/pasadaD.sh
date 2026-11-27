#!/bin/bash
# Pasada D del informe (3 rondas: irse 10 s, volver, scroll rápido por pantalla) con Hitches, sobre la app instalada.
# Uso: pasadaD.sh <nombre> <dir salida> <rutas.txt> [args extra de lanzamiento...]
# Mismo conductor que el informe (../../scripts/pantallas.sh). La traza queda en <dir>/<nombre>.trace.
U=00008110-001A35A6267A401E; N=$1; OUT=$2; RUTAS=$3; shift 3
H=$(cd "$(dirname "$0")/../../scripts" && pwd)
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
mkdir -p $OUT
echo "[$(ts)] lockState: $(xcrun devicectl device info lockState --device $U 2>&1 | grep passcodeRequired)"
xcrun xctrace record --device $U --output $OUT/$N.trace --time-limit 15m --template "Time Profiler" --instrument "Hitches" \
  --launch -- com.jurgenschmidt.yala.dev -uitest -uitest-skip-onboarding "$@" > $OUT/$N.xctrace.log 2>&1 &
XP=$!
ok=0; for i in $(seq 1 90); do grep -q "Ctrl-C to stop" $OUT/$N.xctrace.log && { ok=1; break; }; kill -0 $XP 2>/dev/null || break; sleep 1; done
[ $ok = 1 ] || { echo "[$(ts)] ABORTADA"; cat $OUT/$N.xctrace.log; exit 1; }
echo "[$(ts)] grabando; 40 s de arranque"; sleep 40
bash $H/pantallas.sh com.jurgenschmidt.yala.dev 3 $OUT/$N.ciclos.csv $RUTAS
echo "[$(ts)] rondas hechas"; sleep 5
kill -INT $XP; wait $XP; echo "[$(ts)] traza cerrada"; tail -2 $OUT/$N.xctrace.log
