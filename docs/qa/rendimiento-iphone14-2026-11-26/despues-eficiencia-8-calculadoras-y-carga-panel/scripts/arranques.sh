#!/bin/bash
# Arranques en frío con consola en el iPhone 14 (molde del lote 7). Uso: arranques.sh <dir salida> <etiqueta> <n> [segundos]
# Deja las líneas PERF (copia DEBUG): Panel listo (`PERF arranque`), cálculos del Panel y la foto de los widgets.
U=00008110-001A35A6267A401E
YALA=com.jurgenschmidt.yala.dev
O=$1/$2; mkdir -p $O
N=${3:-3}; T=${4:-40}
for ((i=1;i<=N;i++)); do
  ( xcrun devicectl device process launch --device $U --terminate-existing --console \
      --environment-variables '{"OS_ACTIVITY_DT_MODE":"enable"}' $YALA -- -uitest -uitest-skip-onboarding 2>&1 \
      | LC_ALL=C perl -MTime::HiRes=time -ne 'BEGIN{$|=1} printf "%d %s", time*1000, $_' ) > $O/consola.$i.log &
  CP=$!
  sleep $T
  pkill -P $CP 2>/dev/null; kill $CP 2>/dev/null
  sleep 2
  echo "[$i] cálculos del Panel: $(grep -c 'performCalculation #' $O/consola.$i.log)"
  grep -E "PERF (panel-calculo|arranque|widgets-foto|panel-carga)" $O/consola.$i.log | cut -c1-260 | sed "s/^/[$i] /"
done
xcrun devicectl device process launch --device $U com.apple.springboard >/dev/null 2>&1
