#!/bin/bash
# Uso: pasada.sh <nombre> <bundle_yala> <n_ciclos> <flicks> <xctrace args...>
# Graba una traza mientras corre ciclos.sh; reposo de 20 s antes y 15 s después.
S=/private/tmp/claude-501/-Users-max-jur-Claude-worktrees-Yala-2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14/c5c9629f-e7cd-4dfe-93bd-2fb889928dca/scratchpad
OUT=$S/trazas; mkdir -p $OUT
NOMBRE=$1; YALA=$2; N=$3; FL=$4; shift 4
U=00008110-001A35A6267A401E
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
echo "[$(ts)] $NOMBRE: lockState"; xcrun devicectl device info lockState --device $U 2>&1 | grep -E "passcodeRequired"
xcrun devicectl device process launch --device $U "$YALA" >/dev/null 2>&1
sleep 3
echo "[$(ts)] $NOMBRE: xctrace $*"
xcrun xctrace record --device $U --output $OUT/$NOMBRE.trace --time-limit 25m "$@" > $OUT/$NOMBRE.xctrace.log 2>&1 &
XP=$!
# espera a que la grabación arranque de verdad
ok=0; for i in $(seq 1 90); do grep -q "Ctrl-C to stop" $OUT/$NOMBRE.xctrace.log 2>/dev/null && { ok=1; break; }; kill -0 $XP 2>/dev/null || break; sleep 1; done
if [ $ok != 1 ]; then echo "[$(ts)] $NOMBRE: ABORTADA, xctrace no arrancó"; cat $OUT/$NOMBRE.xctrace.log; kill -INT $XP 2>/dev/null; exit 1; fi
echo "[$(ts)] $NOMBRE: grabando (pid $XP); reposo 20 s"; date +%s000 > $OUT/$NOMBRE.t0_ms
sleep 20
bash $S/ciclos.sh "$YALA" "$N" $OUT/$NOMBRE.ciclos.csv "$FL"
echo "[$(ts)] $NOMBRE: ciclos hechos; reposo 15 s"
sleep 15
kill -INT $XP; wait $XP
echo "[$(ts)] $NOMBRE: traza cerrada"; tail -3 $OUT/$NOMBRE.xctrace.log
