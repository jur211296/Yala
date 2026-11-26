#!/bin/bash
S=/private/tmp/claude-501/-Users-max-jur-Claude-worktrees-Yala-2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14/c5c9629f-e7cd-4dfe-93bd-2fb889928dca/scratchpad
OUT=$S/trazas; U=00008110-001A35A6267A401E
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
xcrun devicectl device process launch --console --terminate-existing --device $U com.jurgenschmidt.yala.dev -- -uitest -uitest-skip-onboarding -perfTempSinPulso YES -perfTempSinRecargaAlVolver YES > $OUT/H_consola.log 2>&1 &
CP=$!
echo "[$(ts)] consola enganchada (pid $CP); 45 s de arranque"; sleep 45
MODO=swipe bash $S/ciclos.sh com.jurgenschmidt.yala.dev 6 $OUT/H_consola.ciclos.csv 6
sleep 10; kill -INT $CP 2>/dev/null; sleep 2; kill $CP 2>/dev/null
echo "[$(ts)] fin H"; grep -c "^PERF" $OUT/H_consola.log
