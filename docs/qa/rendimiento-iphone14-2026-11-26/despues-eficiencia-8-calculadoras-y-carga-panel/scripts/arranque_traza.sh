#!/bin/bash
# Arranque en frío con Instruments en el iPhone 14 (lote 8): Time Profiler + os_signpost, 60 s desde el lanzamiento.
# Uso: arranque_traza.sh <nombre> <dir salida>
# Mismo almacén que los lotes 1-7: Yala Dev con `-uitest -uitest-skip-onboarding` (YalaModel-UITest, 16.004 movimientos).
U=00008110-001A35A6267A401E; Y=com.jurgenschmidt.yala.dev
N=$1; OUT=$2; mkdir -p "$OUT"
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
echo "[$(ts)] $N: $(xcrun devicectl device info lockState --device $U 2>&1 | grep passcodeRequired)"
xcrun devicectl device process launch --device $U com.apple.springboard >/dev/null 2>&1
xcrun xctrace record --device $U --template "Time Profiler" --instrument "os_signpost" --output "$OUT/$N.trace" \
  --time-limit 60s --launch -- $Y -uitest -uitest-skip-onboarding > "$OUT/$N.xctrace.log" 2>&1
echo "[$(ts)] $N: traza cerrada · $(tail -1 "$OUT/$N.xctrace.log")"
