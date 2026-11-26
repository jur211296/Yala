#!/bin/bash
# Uso: pasadaJ.sh <nombre> [args extra de la app]
S=/private/tmp/claude-501/-Users-max-jur-Claude-worktrees-Yala-2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14/c5c9629f-e7cd-4dfe-93bd-2fb889928dca/scratchpad
OUT=$S/trazas; N=$1; shift; U=00008110-001A35A6267A401E
ts(){ TZ=America/Lima date '+%H:%M:%S'; }; ms(){ python3 -c 'import time;print(int(time.time()*1000))'; }
xcrun xctrace record --device $U --output $OUT/$N.trace --time-limit 8m --template "Power Profiler" --launch -- com.jurgenschmidt.yala.dev -uitest -uitest-skip-onboarding "$@" > $OUT/$N.xctrace.log 2>&1 &
XP=$!
ok=0; for i in $(seq 1 90); do grep -q "Ctrl-C to stop" $OUT/$N.xctrace.log && { ok=1; break; }; kill -0 $XP 2>/dev/null || break; sleep 1; done
[ $ok = 1 ] || { echo "[$(ts)] ABORTADA"; cat $OUT/$N.xctrace.log; exit 1; }
echo "[$(ts)] $N grabando; 40 s de arranque"; sleep 40
L=$OUT/$N.reposo.csv; echo "ciclo,evento,hora_lima,epoch_ms" > $L
echo "panel_quieta,quieta_inicio,$(ts),$(ms)" >> $L; sleep 45; echo "panel_quieta,quieta_fin,$(ts),$(ms)" >> $L
MODO=swipe bash $S/ciclos.sh com.jurgenschmidt.yala.dev 3 $OUT/$N.ciclos.csv 6
kill -INT $XP; wait $XP; echo "[$(ts)] $N traza cerrada"; tail -1 $OUT/$N.xctrace.log
