#!/bin/bash
# Conductor de ciclos «irse a otra app y volver» en el iPhone 14.
# Uso: ciclos.sh <bundle_yala> <n_ciclos> <log.csv> [flicks_por_vuelta]
# Cada ciclo: otra app (rota) → espera N s (5–30) → vuelve a Yala (sin relanzar) → 2 s → flicks de scroll → 4 s quieta.
U=00008110-001A35A6267A401E
CLI="/Applications/Device MCP.app/Contents/MacOS/device-mcp-cli"
YALA="$1"; N="${2:-10}"; LOG="$3"; FLICKS="${4:-6}"; SUBE="${SUBE:-$FLICKS}"
OTRAS=(com.apple.mobilesafari com.apple.Preferences com.apple.mobilenotes com.apple.calculator com.apple.Maps)
FUERA=(8 22 12 30 5 18 25 10 15 28 9 20 14 26 6 17 24 11 16 29)
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
ms(){ python3 -c 'import time;print(int(time.time()*1000))'; }
echo "ciclo,evento,hora_lima,epoch_ms,detalle" > "$LOG"
for ((i=1;i<=N;i++)); do
  otra=${OTRAS[$(( (i-1) % ${#OTRAS[@]} ))]}; f=${FUERA[$(( (i-1) % ${#FUERA[@]} ))]}
  echo "$i,sale,$(ts),$(ms),$otra" >> "$LOG"
  xcrun devicectl device process launch --device $U "$otra" >/dev/null 2>&1
  sleep "$f"
  echo "$i,vuelve,$(ts),$(ms),fuera=${f}s" >> "$LOG"
  xcrun devicectl device process launch --device $U "$YALA" >/dev/null 2>&1
  sleep 2
  echo "$i,scroll_inicio,$(ts),$(ms),flicks=$FLICKS" >> "$LOG"
  if [ "${MODO:-scroll}" = swipe ]; then
    for ((k=1;k<=FLICKS;k++)); do "$CLI" swipe --from 195,700 --to 195,180 --duration-ms 90 --device $U --no-launch >/dev/null 2>&1; done
    for ((k=1;k<=SUBE;k++)); do "$CLI" swipe --from 195,180 --to 195,700 --duration-ms 90 --device $U --no-launch >/dev/null 2>&1; done
  else
    for ((k=1;k<=FLICKS;k++)); do "$CLI" scroll down --device $U --no-launch >/dev/null 2>&1; done
    for ((k=1;k<=FLICKS;k++)); do "$CLI" scroll up --device $U --no-launch >/dev/null 2>&1; done
  fi
  echo "$i,scroll_fin,$(ts),$(ms)," >> "$LOG"
  sleep 4
done
echo "fin,fin,$(ts),$(ms)," >> "$LOG"
