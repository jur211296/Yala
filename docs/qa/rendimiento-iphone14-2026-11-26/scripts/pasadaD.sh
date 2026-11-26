#!/bin/bash
S=/private/tmp/claude-501/-Users-max-jur-Claude-worktrees-Yala-2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14/c5c9629f-e7cd-4dfe-93bd-2fb889928dca/scratchpad
OUT=$S/trazas; N=D_pantallas; U=00008110-001A35A6267A401E
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
echo "[$(ts)] lockState: $(xcrun devicectl device info lockState --device $U 2>&1 | grep passcodeRequired)"
xcrun xctrace record --device $U --output $OUT/$N.trace --time-limit 25m --template "Time Profiler" --instrument "os_signpost" --instrument "Hitches" --instrument "Thermal State" --launch -- com.jurgenschmidt.yala.dev -uitest -uitest-skip-onboarding > $OUT/$N.xctrace.log 2>&1 &
XP=$!
ok=0; for i in $(seq 1 90); do grep -q "Ctrl-C to stop" $OUT/$N.xctrace.log && { ok=1; break; }; kill -0 $XP 2>/dev/null || break; sleep 1; done
[ $ok = 1 ] || { echo "[$(ts)] ABORTADA"; cat $OUT/$N.xctrace.log; exit 1; }
echo "[$(ts)] grabando; 25 s de arranque"; sleep 25
bash $S/pantallas.sh com.jurgenschmidt.yala.dev 3 $OUT/$N.ciclos.csv $S/rutas.txt
echo "[$(ts)] rondas hechas"; sleep 10
kill -INT $XP; wait $XP; echo "[$(ts)] traza cerrada"; tail -2 $OUT/$N.xctrace.log
