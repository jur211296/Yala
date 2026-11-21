#!/usr/bin/env bash
# Prepara el simulador del runner EN SEGUNDO PLANO mientras el job hace otra cosa (restaurar la
# caché, bajar el build), y lo recoge cuando hace falta. Envuelve a `ci-simulador.sh`, que sigue
# siendo quien decide qué simulador y con qué runtime.
#
#   bash qa/scripts/ci-simulador-fondo.sh lanzar [--arrancar]
#   bash qa/scripts/ci-simulador-fondo.sh esperar [--tope SEGUNDOS]
#
# POR QUÉ (2026-11-21, auditoría de tiempos del CI). El paso «Simulador del runner» tardaba de
# segundos a más de 2 min (89-139 s en las tandas de UI del 20-nov: CoreSimulator cargando), y
# luego el primer `xcodebuild test` pagaba además el arranque del device. Los dos esperaban en
# serie delante de los tests. Ahora corren a la vez que la descarga del build o que la caché.
#
# `lanzar` corre `ci-simulador.sh` con sus salidas a ficheros propios y, con `--arrancar`, arranca
# después el device (`simctl boot` + `bootstatus`). Un arranque fallido NO es un error: el primer
# `xcodebuild test` lo arranca él, como antes de este script. `esperar` espera, imprime el log (las
# anotaciones `::warning` de `ci-simulador.sh` salen en este paso), copia sus salidas (`udid`,
# `runtime`) y su resumen a los del paso, y sale con el código de `ci-simulador.sh`.
#
# FALLA CERRADO: `esperar` sin `lanzar`, un `ci-simulador.sh` que muere sin código o que pasa del
# tope, salen en rojo. Sin `udid` no hay nada que probar.
#
# `CI_SIMULADOR` cambia el script envuelto y `SIM_FONDO_DIR` el directorio de estado; los usa el
# banco (`ci-simulador-fondo-test.sh`). Las variables de `ci-simulador.sh` (`SIM_HASTA_SDK`…) pasan.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${CI_SIMULADOR:-$AQUI/ci-simulador.sh}"
DIR="${SIM_FONDO_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/sim-fondo}"

uso() { echo "uso: bash qa/scripts/ci-simulador-fondo.sh lanzar [--arrancar] | esperar [--tope S]" >&2; exit 2; }

lanzar() {
  local arrancar=no
  [ "${1:-}" = "--arrancar" ] && arrancar=si
  rm -rf "$DIR"; mkdir -p "$DIR" || { echo "ci-simulador-fondo: no puedo crear $DIR" >&2; exit 1; }
  (
    GITHUB_OUTPUT="$DIR/salidas" GITHUB_STEP_SUMMARY="$DIR/resumen" bash "$SCRIPT" > "$DIR/log" 2>&1 < /dev/null
    rc=$?
    if [ "$rc" = 0 ] && [ "$arrancar" = si ]; then
      udid=$(sed -n 's/^udid=//p' "$DIR/salidas" | tail -1)
      t0=$(date +%s)
      if [ -n "$udid" ] && xcrun simctl boot "$udid" >> "$DIR/log" 2>&1 \
         && xcrun simctl bootstatus "$udid" >> "$DIR/log" 2>&1; then
        echo "ci-simulador-fondo: device $udid arrancado en $(( $(date +%s) - t0 )) s" >> "$DIR/log"
      else
        echo "::warning title=Simulador sin arrancar::No se pudo arrancar $udid por adelantado; lo arrancará el primer test." >> "$DIR/log"
      fi
    fi
    echo "$rc" > "$DIR/rc"
  ) > /dev/null 2>&1 < /dev/null &
  echo "$!" > "$DIR/pid"
  echo "ci-simulador-fondo: preparando el simulador en segundo plano (pid $!, arrancar: $arrancar)"
}

esperar() {
  local tope=1500 pid desde rc
  [ "${1:-}" = "--tope" ] && tope="${2:?--tope necesita segundos}"
  if [ ! -f "$DIR/pid" ]; then
    echo "::error title=Simulador del runner::No se lanzó la preparación (falta $DIR/pid)."
    exit 1
  fi
  pid=$(cat "$DIR/pid"); desde=$(date +%s)
  while [ ! -f "$DIR/rc" ] && kill -0 "$pid" 2>/dev/null && [ $(( $(date +%s) - desde )) -lt "$tope" ]; do
    sleep 1
  done
  [ -f "$DIR/rc" ] || sleep 1
  cat "$DIR/log" 2>/dev/null
  if [ -f "$DIR/rc" ]; then
    rc=$(tr -dc '0-9' < "$DIR/rc"); rc=${rc:-1}
  elif kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    echo "::error title=Simulador del runner::La preparación pasó del tope de ${tope} s."; exit 1
  else
    echo "::error title=Simulador del runner::La preparación murió sin código de salida."; exit 1
  fi
  echo "ci-simulador-fondo: listo tras esperar $(( $(date +%s) - desde )) s (código $rc)"
  [ -f "$DIR/salidas" ] && [ -n "${GITHUB_OUTPUT:-}" ] && cat "$DIR/salidas" >> "$GITHUB_OUTPUT"
  [ -f "$DIR/resumen" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$DIR/resumen" >> "$GITHUB_STEP_SUMMARY"
  exit "$rc"
}

case "${1:-}" in
  lanzar)  shift; lanzar "$@" ;;
  esperar) shift; esperar "$@" ;;
  *) uso ;;
esac
