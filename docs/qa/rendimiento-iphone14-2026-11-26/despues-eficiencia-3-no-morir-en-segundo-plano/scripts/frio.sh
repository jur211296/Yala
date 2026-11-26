#!/bin/bash
# Arranque en frío y salida rápida, en el iPhone 14 (lote 3 de eficiencia).
# Uso: frio.sh <etiqueta> <n> [frente_s] [fuera_s]
# Cada vuelta: Yala en frío (terminando la anterior) con consola → <frente_s> delante → otra app <fuera_s> → vuelve a
# Yala → 12 s quieta. La consola lleva os_log (OS_ACTIVITY_DT_MODE) con hora del Mac por línea.
U=00008110-001A35A6267A401E
YALA=com.jurgenschmidt.yala.dev
ARGS=(-uitest -uitest-skip-onboarding)
E=$HOME/Claude/entregas/2026-11-26-eficiencia-3-no-morir-en-segundo-plano
TAG=$1; N=${2:-5}; FRENTE=${3:-3}; FUERA=${4:-3}
OTRAS=(com.apple.mobilesafari com.apple.Preferences com.apple.mobilenotes com.apple.calculator com.apple.Maps)
OUT=$E/datos/$TAG; mkdir -p $OUT
ts(){ python3 -c 'import time;print(int(time.time()*1000))'; }
echo "vuelta,evento,epoch_ms,detalle" > $OUT/eventos.csv
for ((i=1;i<=N;i++)); do
  otra=${OTRAS[$(( (i-1) % ${#OTRAS[@]} ))]}
  echo "$i,lanza_frio,$(ts)," >> $OUT/eventos.csv
  ( xcrun devicectl device process launch --device $U --terminate-existing --console \
      --environment-variables '{"OS_ACTIVITY_DT_MODE":"enable"}' $YALA -- "${ARGS[@]}" 2>&1 \
      | perl -MTime::HiRes=time -ne 'BEGIN{$|=1} printf "%d %s", time*1000, $_' ) > $OUT/consola.$i.log &
  CP=$!
  sleep $FRENTE
  echo "$i,sale,$(ts),$otra" >> $OUT/eventos.csv
  xcrun devicectl device process launch --device $U "$otra" >/dev/null 2>&1
  sleep $FUERA
  echo "$i,vuelve,$(ts)," >> $OUT/eventos.csv
  xcrun devicectl device process launch --device $U $YALA -- "${ARGS[@]}" >/dev/null 2>&1
  sleep 12
  echo "$i,fin,$(ts)," >> $OUT/eventos.csv
  pkill -P $CP 2>/dev/null; kill $CP 2>/dev/null
done
