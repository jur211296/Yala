#!/bin/bash
# Candados de máquina del CI propio en la Mini (16 GB, compartida con Jürgen y sus sesiones).
#
#   guardia.sh antes     Espera a que la Mini esté libre; si no lo está en GUARDIA_ESPERA_MIN, sale 1.
#   guardia.sh vigia     Bucle de fondo: si la RAM libre o el disco bajan del suelo, para los
#                        xcodebuild de ESTE usuario (solo `ci`) y deja el motivo en el log.
#   guardia.sh despues   Poda: se queda con los últimos xcresult y borra el DerivedData si crece.
#   guardia.sh foto      Una línea con disco, RAM, swap, xcodebuild y simuladores.
#
# Por qué existe (2026-09-30): una corrida en sombra con la suite unitaria entera coincidió con
# la caída de todas las sesiones de Claude de la Mini. No se probó que fuera memoria, pero la
# regla no cambia: en esta máquina hay UNA carga pesada a la vez, y el CI es el que cede.
# Nunca mata nada de otro usuario: `pkill -u` limita la parada a los procesos propios.
#
# Umbrales por variable de entorno (los defaults son el suelo acordado):
#   GUARDIA_DISCO_MIN_GB=15   libre en el volumen de datos para ARRANCAR
#   GUARDIA_RAM_MIN_PCT=35    «System-wide memory free percentage» para ARRANCAR
#   GUARDIA_ESPERA_MIN=20     cuánto espera `antes` a que se cumpla todo
#   GUARDIA_VIGIA_DISCO_GB=10 suelo de disco DURANTE la corrida
#   GUARDIA_VIGIA_RAM_PCT=12  suelo de RAM libre DURANTE la corrida
#   GUARDIA_DD=/Users/ci/DerivedData/yala   GUARDIA_DD_MAX_GB=20   GUARDIA_XCRESULT_KEEP=3
set -uo pipefail

VOL="/System/Volumes/Data"
[[ -d "$VOL" ]] || VOL="/"
YO="$(whoami)"

disco_libre_gb() { df -g "$VOL" | awk 'NR==2 {print $4}'; }
ram_libre_pct()  { memory_pressure -Q 2>/dev/null | awk -F': ' '/free percentage/ {gsub("%","",$2); print $2+0}'; }
swap_usada_mb()  { sysctl -n vm.swapusage | awk '{for(i=1;i<=NF;i++) if($i=="used") {v=$(i+2); sub("M","",v); print int(v)}}'; }
# xcodebuild y simuladores arrancados de CUALQUIER usuario: la Mini es una sola.
xcodebuilds()    { pgrep -x xcodebuild | wc -l | tr -d ' '; }
simuladores()    { pgrep -x launchd_sim | wc -l | tr -d ' '; }

foto() {
  echo "disco=$(disco_libre_gb)GB ram_libre=$(ram_libre_pct)% swap=$(swap_usada_mb)MB xcodebuild=$(xcodebuilds) sims=$(simuladores)"
}

motivos_para_no_arrancar() {
  local m=()
  (( $(disco_libre_gb) >= ${GUARDIA_DISCO_MIN_GB:-15} )) || m+=("disco < ${GUARDIA_DISCO_MIN_GB:-15} GB")
  (( $(ram_libre_pct) >= ${GUARDIA_RAM_MIN_PCT:-35} )) || m+=("RAM libre < ${GUARDIA_RAM_MIN_PCT:-35} %")
  (( $(xcodebuilds) == 0 )) || m+=("hay xcodebuild en marcha (de quien sea)")
  (( $(simuladores) == 0 )) || m+=("hay simuladores arrancados (de quien sea)")
  (( ${#m[@]} == 0 )) || printf '%s; ' "${m[@]}"
}

case "${1:-}" in
  antes)
    limite=$(( $(date +%s) + ${GUARDIA_ESPERA_MIN:-20} * 60 ))
    while :; do
      motivo="$(motivos_para_no_arrancar)"
      if [[ -z "$motivo" ]]; then echo "Mini libre: $(foto)"; exit 0; fi
      if (( $(date +%s) >= limite )); then
        echo "::error::La Mini no está libre tras ${GUARDIA_ESPERA_MIN:-20} min: $motivo($(foto)). El CI cede; relánzalo luego."
        exit 1
      fi
      echo "Esperando: $motivo($(foto))"
      sleep 60
    done
    ;;

  vigia)
    # Muestra cada 30 s; imprime una foto cada 5 min para que cada corrida deje la medida.
    n=0
    while :; do
      d="$(disco_libre_gb)"; r="$(ram_libre_pct)"
      if (( d < ${GUARDIA_VIGIA_DISCO_GB:-10} || r < ${GUARDIA_VIGIA_RAM_PCT:-12} )); then
        echo "::error::Vigía: la Mini se queda sin margen ($(foto)). Paro los xcodebuild de $YO."
        [[ -n "${GUARDIA_SECO:-}" ]] && exit 0
        pkill -TERM -u "$YO" -x xcodebuild 2>/dev/null
        sleep 20
        pkill -KILL -u "$YO" -x xcodebuild 2>/dev/null
        exit 0
      fi
      (( n % 10 == 0 )) && echo "vigía $(date +%H:%M:%S) $(foto)"
      n=$((n + 1))
      sleep "${GUARDIA_VIGIA_CADA_S:-30}"
    done
    ;;

  despues)
    DD="${GUARDIA_DD:-/Users/ci/DerivedData/yala}"
    if [[ -d "$DD/Logs/Test" ]]; then
      # Los xcresult se apilan en cada corrida; se quedan los últimos N.
      ls -1dt "$DD"/Logs/Test/*.xcresult 2>/dev/null | tail -n +$(( ${GUARDIA_XCRESULT_KEEP:-3} + 1 )) |
        while IFS= read -r x; do rm -rf "$x"; done
    fi
    if [[ -d "$DD" ]]; then
      gb=$(du -sg "$DD" 2>/dev/null | awk '{print $1}')
      if (( ${gb:-0} > ${GUARDIA_DD_MAX_GB:-20} )); then
        echo "DerivedData en ${gb} GB (> ${GUARDIA_DD_MAX_GB:-20}): se borra; la próxima compila en frío."
        rm -rf "$DD"
      fi
    fi
    echo "Tras la corrida: $(foto)"
    ;;

  foto) foto ;;

  *) echo "uso: $0 antes|vigia|despues|foto" >&2; exit 2 ;;
esac
