#!/bin/bash
S=/private/tmp/claude-501/-Users-max-jur-Claude-worktrees-Yala-2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14/c5c9629f-e7cd-4dfe-93bd-2fb889928dca/scratchpad
OUT=$S/trazas; N=E_reposo; U=00008110-001A35A6267A401E
CLI="/Applications/Device MCP.app/Contents/MacOS/device-mcp-cli"
ts(){ TZ=America/Lima date '+%H:%M:%S'; }; ms(){ python3 -c 'import time;print(int(time.time()*1000))'; }
tap(){ "$CLI" tap -x "$1" -y "$2" --device $U --no-launch </dev/null >/dev/null 2>&1; }
xcrun xctrace record --device $U --output $OUT/$N.trace --time-limit 10m --template "Time Profiler" --instrument "Hitches" --launch -- com.jurgenschmidt.yala.dev -uitest -uitest-skip-onboarding > $OUT/$N.xctrace.log 2>&1 &
XP=$!
ok=0; for i in $(seq 1 90); do grep -q "Ctrl-C to stop" $OUT/$N.xctrace.log && { ok=1; break; }; kill -0 $XP 2>/dev/null || break; sleep 1; done
[ $ok = 1 ] || { echo "[$(ts)] ABORTADA"; cat $OUT/$N.xctrace.log; exit 1; }
echo "[$(ts)] grabando; 40 s de arranque y cálculo"; sleep 40
L=$OUT/$N.ciclos.csv; echo "ciclo,evento,hora_lima,epoch_ms" > $L
quieta(){ echo "$1,quieta_inicio,$(ts),$(ms)" >> $L; sleep $2; echo "$1,quieta_fin,$(ts),$(ms)" >> $L; }
quieta panel_arriba 30
"$CLI" swipe --from 195,600 --to 195,250 --duration-ms 600 --no-momentum --device $U --no-launch </dev/null >/dev/null 2>&1; sleep 2
quieta panel_tendencia_visible 30
tap 190 790; sleep 4; quieta registros 30
tap 260 790; sleep 3; quieta mas 25
tap 64 790; sleep 3; quieta panel_vuelta 30
kill -INT $XP; wait $XP; echo "[$(ts)] traza cerrada"; tail -1 $OUT/$N.xctrace.log
