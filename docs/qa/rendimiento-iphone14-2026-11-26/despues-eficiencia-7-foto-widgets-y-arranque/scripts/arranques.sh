#!/bin/bash
# Arranques en frío con consola en el iPhone 14 (lote 7). Uso: arranques.sh <etiqueta> <n> [segundos]
# Cuenta los cálculos completos del Panel y la foto de los widgets de cada arranque (líneas PERF de la copia DEBUG).
U=00008110-001A35A6267A401E
YALA=com.jurgenschmidt.yala.dev
O=$HOME/Claude/entregas/2026-11-27-eficiencia-7-foto-widgets-y-arranque/datos/$1
mkdir -p $O
N=${2:-3}; T=${3:-40}
for ((i=1;i<=N;i++)); do
  ( xcrun devicectl device process launch --device $U --terminate-existing --console \
      --environment-variables '{"OS_ACTIVITY_DT_MODE":"enable"}' $YALA -- -uitest -uitest-skip-onboarding 2>&1 \
      | perl -MTime::HiRes=time -ne 'BEGIN{$|=1} printf "%d %s", time*1000, $_' ) > $O/consola.$i.log &
  CP=$!
  sleep $T
  pkill -P $CP 2>/dev/null; kill $CP 2>/dev/null
  sleep 2
  echo "[$i] cálculos del Panel: $(grep -c 'performCalculation #' $O/consola.$i.log)"
  grep -E "PERF (panel-calculo|arranque|widgets-foto)|volver al Panel|tirar para" $O/consola.$i.log | cut -c1-260 | sed "s/^/[$i] /"
done
xcrun devicectl device process launch --device $U com.apple.springboard >/dev/null 2>&1
