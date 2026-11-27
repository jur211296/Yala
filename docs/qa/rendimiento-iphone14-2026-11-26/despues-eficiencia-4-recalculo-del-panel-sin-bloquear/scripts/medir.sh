#!/bin/bash
# Arranque en frío con consola en el iPhone 14 (lote 4). Uso: medir.sh <etiqueta> <n> [segundos]
U=00008110-001A35A6267A401E
YALA=com.jurgenschmidt.yala.dev
E=$HOME/Claude/entregas/2026-11-26-eficiencia-4-recalculo-del-panel-sin-bloquear/datos/$1
mkdir -p $E
N=${2:-3}; T=${3:-25}
for ((i=1;i<=N;i++)); do
  ( xcrun devicectl device process launch --device $U --terminate-existing --console \
      --environment-variables '{"OS_ACTIVITY_DT_MODE":"enable"}' $YALA -- -uitest -uitest-skip-onboarding 2>&1 \
      | perl -MTime::HiRes=time -ne 'BEGIN{$|=1} printf "%d %s", time*1000, $_' ) > $E/consola.$i.log &
  CP=$!
  sleep $T
  pkill -P $CP 2>/dev/null; kill $CP 2>/dev/null
  sleep 2
  grep -E "PERF (panel-calculo|arranque)" $E/consola.$i.log | sed "s/^/[$i] /"
done
