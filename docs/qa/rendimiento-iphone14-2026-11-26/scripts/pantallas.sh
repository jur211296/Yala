#!/bin/bash
# Conductor de la pasada C: rondas de «irse 10 s y volver» + scroll rápido por pantallas, con gestos por coordenadas
# (sin consultar el árbol de accesibilidad). Uso: pantallas.sh <bundle> <rondas> <log.csv> <rutas.txt>
# rutas.txt: una pantalla por línea:  nombre|toques separados por ;   (cada toque x,y; «w» = espera 1 s)
U=00008110-001A35A6267A401E
CLI="/Applications/Device MCP.app/Contents/MacOS/device-mcp-cli"
YALA="$1"; R="${2:-3}"; LOG="$3"; RUTAS="$4"
ts(){ TZ=America/Lima date '+%H:%M:%S'; }
ms(){ python3 -c 'import time;print(int(time.time()*1000))'; }
tap(){ "$CLI" tap -x "$1" -y "$2" --device $U --no-launch </dev/null >/dev/null 2>&1; }
flick(){ "$CLI" swipe --from "195,$1" --to "195,$2" --duration-ms 90 --device $U --no-launch </dev/null >/dev/null 2>&1; }
echo "ciclo,pantalla,evento,hora_lima,epoch_ms" > "$LOG"
OTRAS=(com.apple.mobilesafari com.apple.Preferences com.apple.mobilenotes)
for ((r=1;r<=R;r++)); do
  echo "$r,-,sale,$(ts),$(ms)" >> "$LOG"
  xcrun devicectl device process launch --device $U "${OTRAS[$(( (r-1) % 3 ))]}" </dev/null >/dev/null 2>&1
  sleep 10
  echo "$r,-,vuelve,$(ts),$(ms)" >> "$LOG"
  xcrun devicectl device process launch --device $U "$YALA" </dev/null >/dev/null 2>&1
  sleep 3
  while IFS='|' read -r nombre toques post; do
    [ -z "$nombre" ] && continue
    IFS=';' read -ra T <<< "$toques"
    for t in "${T[@]}"; do
      if [ "$t" = "w" ]; then sleep 1
      elif [ "${t:0:2}" = "t:" ]; then "$CLI" tap --text "${t:2}" --device $U --no-launch </dev/null >/dev/null 2>&1; sleep 0.8
      else tap "${t%,*}" "${t#*,}"; sleep 0.8; fi
    done
    sleep 2
    echo "$r,$nombre,scroll_inicio,$(ts),$(ms)" >> "$LOG"
    for k in 1 2 3 4 5 6; do flick 700 180; done
    for k in 1 2 3 4 5 6; do flick 180 700; done
    echo "$r,$nombre,scroll_fin,$(ts),$(ms)" >> "$LOG"
    sleep 1
    if [ -n "$post" ]; then tap "${post%,*}" "${post#*,}"; sleep 1; fi
  done < <(cat "$RUTAS"; echo)
done
echo "fin,-,fin,$(ts),$(ms)" >> "$LOG"
