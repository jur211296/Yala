#!/bin/bash
# Candados de máquina del CI propio en la Mini (16 GB, compartida con Jürgen y sus sesiones).
#
#   guardia.sh antes     Espera a que la Mini esté libre; si no lo está en GUARDIA_ESPERA_MIN, sale 1.
#   guardia.sh vigia     Bucle de fondo: si la RAM libre o el disco bajan del suelo, para los
#                        xcodebuild de ESTE usuario (solo `ci`) y deja el motivo en el log.
#   guardia.sh despues   Poda: se queda con los últimos xcresult y borra el DerivedData si crece.
#   guardia.sh foto      Una línea con disco, RAM, swap, xcodebuild y simuladores.
#
# Por qué existe (2026-09-30): la suite unitaria en el simulador de `ci`, Time Machine y Spotlight
# a la vez llevaron la carga de la Mini a ~37 y ahogaron las sesiones de Jürgen. Fue CPU, no RAM.
# Regla: en esta máquina hay UNA carga pesada a la vez, y el CI es el que cede. Nunca toca nada
# de otro usuario: `renice` y `pkill` van con `-u` del usuario propio.
#
# Umbrales por variable de entorno (los defaults son el suelo acordado):
#   GUARDIA_DISCO_MIN_GB=15   libre en el volumen de datos para ARRANCAR
#   GUARDIA_RAM_MIN_PCT=35    «System-wide memory free percentage» para ARRANCAR
#   GUARDIA_CARGA_MAX=10      carga media de 1 min para ARRANCAR (la Mini tiene 10 núcleos)
#   GUARDIA_ESPERA_MIN=20     cuánto espera `antes` a que se cumpla todo
#   GUARDIA_VIGIA_CARGA=24    carga de 1 min que, sostenida GUARDIA_VIGIA_CARGA_N muestras (4 = 2 min), para la corrida
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
carga_1m()       { sysctl -n vm.loadavg | awk '{printf "%d", $2}'; }
time_machine()   { tmutil status 2>/dev/null | awk -F' = ' '/Running/ {gsub(";","",$2); print $2+0}'; }

foto() {
  echo "disco=$(disco_libre_gb)GB ram_libre=$(ram_libre_pct)% swap=$(swap_usada_mb)MB carga=$(carga_1m) tm=$(time_machine) xcodebuild=$(xcodebuilds) sims=$(simuladores)"
}

motivos_para_no_arrancar() {
  local m=()
  (( $(disco_libre_gb) >= ${GUARDIA_DISCO_MIN_GB:-15} )) || m+=("disco < ${GUARDIA_DISCO_MIN_GB:-15} GB")
  (( $(ram_libre_pct) >= ${GUARDIA_RAM_MIN_PCT:-35} )) || m+=("RAM libre < ${GUARDIA_RAM_MIN_PCT:-35} %")
  (( $(xcodebuilds) == 0 )) || m+=("hay xcodebuild en marcha (de quien sea)")
  (( $(simuladores) == 0 )) || m+=("hay simuladores arrancados (de quien sea)")
  (( $(carga_1m) <= ${GUARDIA_CARGA_MAX:-10} )) || m+=("carga > ${GUARDIA_CARGA_MAX:-10}")
  (( ${GUARDIA_TM_CUENTA:-$(time_machine)} == 0 )) || m+=("Time Machine está copiando")
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
    # Cada vuelta baja la prioridad de todo lo de este usuario, simulador incluido (sus procesos
    # los lanza CoreSimulatorService, no xcodebuild, así que un `nice` delante no los alcanza).
    # Solo como `ci`: bajar la prioridad «de este usuario» con cualquier otro alcanza sus
    # sesiones enteras (pasó el 2026-09-30 al probarlo como `jur`: 420 procesos a nice 20, y
    # deshacerlo pide root). En seco (`GUARDIA_SECO=1`) no se toca ninguna prioridad.
    if [[ -z "${GUARDIA_SECO:-}" && "$YO" != "${GUARDIA_USUARIO_CI:-ci}" ]]; then
      echo "vigia: solo corre como ${GUARDIA_USUARIO_CI:-ci} (eres $YO). Para probarlo: GUARDIA_SECO=1" >&2
      exit 2
    fi
    n=0; alta=0
    while :; do
      # Valor ABSOLUTO: `renice -n` es un incremento en macOS y suma en cada vuelta.
      [[ -n "${GUARDIA_SECO:-}" ]] || renice 10 -u "$YO" >/dev/null 2>&1
      d="$(disco_libre_gb)"; r="$(ram_libre_pct)"; c="$(carga_1m)"
      if (( c > ${GUARDIA_VIGIA_CARGA:-24} )); then alta=$((alta + 1)); else alta=0; fi
      if (( d < ${GUARDIA_VIGIA_DISCO_GB:-10} || r < ${GUARDIA_VIGIA_RAM_PCT:-12} || alta >= ${GUARDIA_VIGIA_CARGA_N:-4} )); then
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
