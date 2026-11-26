#!/bin/bash
# Ciclos «volver y salir rápido» en el iPhone 14 (lote 3 de eficiencia).
# Uso: ciclos3.sh <etiqueta> <n_ciclos>
# Arranca Yala en frío con consola, la deja asentarse 40 s y luego, en cada ciclo: vuelve a Yala → 1 s → tira para
# actualizar (un gesto real que pide trabajo) → sale a los 2-5 s de volver → 3 s fuera.
U=00008110-001A35A6267A401E
CLI="/Applications/Device MCP.app/Contents/MacOS/device-mcp-cli"
YALA=com.jurgenschmidt.yala.dev
ARGS=(-uitest -uitest-skip-onboarding)
E=$HOME/Claude/entregas/2026-11-26-eficiencia-3-no-morir-en-segundo-plano
TAG=$1; N=${2:-10}
OTRAS=(com.apple.mobilesafari com.apple.Preferences com.apple.mobilenotes com.apple.calculator com.apple.Maps)
QUEDA=(2 3 4 5 2 3 4 5 2 3)
OUT=$E/datos/$TAG; mkdir -p $OUT
ts(){ python3 -c 'import time;print(int(time.time()*1000))'; }
echo "ciclo,evento,epoch_ms,detalle" > $OUT/eventos.csv
echo "0,lanza_frio,$(ts)," >> $OUT/eventos.csv
( xcrun devicectl device process launch --device $U --terminate-existing --console \
    --environment-variables '{"OS_ACTIVITY_DT_MODE":"enable"}' $YALA -- "${ARGS[@]}" 2>&1 \
    | perl -MTime::HiRes=time -ne 'BEGIN{$|=1} printf "%d %s", time*1000, $_' ) > $OUT/consola.log &
CP=$!
sleep 40
for ((i=1;i<=N;i++)); do
  otra=${OTRAS[$(( (i-1) % ${#OTRAS[@]} ))]}; q=${QUEDA[$(( (i-1) % ${#QUEDA[@]} ))]}
  echo "$i,vuelve,$(ts)," >> $OUT/eventos.csv
  xcrun devicectl device process launch --device $U $YALA -- "${ARGS[@]}" >/dev/null 2>&1
  sleep 1
  echo "$i,tira,$(ts)," >> $OUT/eventos.csv
  "$CLI" swipe --from 195,260 --to 195,760 --duration-ms 300 --device $U --no-launch >/dev/null 2>&1
  sleep $((q - 1))
  echo "$i,sale,$(ts),$otra queda=${q}s" >> $OUT/eventos.csv
  xcrun devicectl device process launch --device $U "$otra" >/dev/null 2>&1
  sleep 3
done
echo "$N,vuelve_final,$(ts)," >> $OUT/eventos.csv
xcrun devicectl device process launch --device $U $YALA -- "${ARGS[@]}" >/dev/null 2>&1
sleep 15
echo "fin,fin,$(ts)," >> $OUT/eventos.csv
pkill -P $CP 2>/dev/null; kill $CP 2>/dev/null
