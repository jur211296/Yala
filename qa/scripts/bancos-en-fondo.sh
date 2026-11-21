#!/usr/bin/env bash
# Corre bancos lentos del job `coverage-index` en SEGUNDO PLANO mientras los demás pasos siguen, y
# recoge su resultado al final. Lo usa `.github/workflows/qa.yml` y, a través de
# `gate-ci-checks.sh`, el paso 5 del `/gate` en local.
#
#   bash qa/scripts/bancos-en-fondo.sh lanzar [--nuevo] <banco.sh> [<banco.sh> …]
#   bash qa/scripts/bancos-en-fondo.sh esperar [--tope SEGUNDOS]
#
# POR QUÉ (2026-11-21, auditoría de tiempos del CI). El job `coverage-index` tardaba ~3,7 min y la
# mitad eran dos bancos: `interfaz-de-lo-tocado-test.sh` (~100 s, trae commits con `git fetch`) y
# `sim-lock-test.sh` (~82 s, casi todo siestas a propósito). Los dos esperan; no gastan CPU. En
# segundo plano el job baja a lo que tarde el más lento, no a la suma.
#
# QUIÉN PUEDE IR A LA VEZ, Y POR QUÉ EL ORDEN DEL JOB IMPORTA. No todo banco convive con otro:
#   · `sim-lock-test.sh` cuenta procesos llamados `xcodebuild` (`pgrep -x`). Los bancos que crean un
#     `xcodebuild` de mentira (`ci-simulador-test.sh`, `ci-reintentar-rojos-test.sh`) tienen que
#     haber terminado antes de lanzarlo, o le cantan un intruso que no existe.
#   · `interfaz-de-lo-tocado-test.sh` hace `git fetch` en el repo real. `ci-atribucion-commits.sh`
#     también: dos `fetch` a la vez chocan en los candados de `.git`. Va después de él.
# Por eso cada banco se lanza en su propio paso y en su sitio del job. Un banco nuevo que se meta
# aquí tiene que pasar las mismas dos preguntas.
#
# CÓMO. `lanzar` arranca cada banco con su salida a un log y apunta su PID; `esperar` espera a
# todos, imprime cada log en un grupo plegable y sale con 1 si alguno salió distinto de 0. Los
# procesos sobreviven entre pasos del mismo job (el runner solo limpia los huérfanos al acabarlo).
# `--nuevo` vacía el registro antes de lanzar: lo lleva el PRIMER `lanzar` del job, para que un
# resto de una corrida local anterior no se cuele en esta.
#
# FALLA CERRADO. `esperar` sin nada lanzado, un banco sin código de salida (murió sin escribirlo) o
# uno que pasa del tope cuentan como rojo. Un verde que no ha visto correr el banco es justo lo que
# no puede salir de aquí.
#
# El registro vive en `BANCOS_EN_FONDO_DIR`; por defecto, un directorio por repo bajo RUNNER_TEMP
# (CI) o TMPDIR (local). Banco: `qa/scripts/bancos-en-fondo-test.sh`.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
huella=$(printf '%s' "$RAIZ" | cksum | cut -d' ' -f1)
DIR="${BANCOS_EN_FONDO_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/bancos-en-fondo-$huella}"
DIR="${DIR%/}"

uso() { echo "uso: bash qa/scripts/bancos-en-fondo.sh lanzar [--nuevo] <banco.sh>… | esperar [--tope S]" >&2; exit 2; }

lanzar() {
  if [ "${1:-}" = "--nuevo" ]; then rm -rf "$DIR"; shift; fi
  [ $# -gt 0 ] || uso
  mkdir -p "$DIR" || { echo "bancos-en-fondo: no puedo crear $DIR" >&2; exit 1; }
  local banco nombre
  for banco in "$@"; do
    if [ ! -f "$RAIZ/$banco" ] && [ ! -f "$banco" ]; then
      echo "bancos-en-fondo: no existe $banco" >&2; exit 1
    fi
    nombre=$(basename "$banco" .sh)
    rm -f "$DIR/$nombre.rc" "$DIR/$nombre.log"
    # stdin, stdout y stderr fuera del paso: si el banco heredara la tubería del paso, el runner (y
    # el `$(…)` del gate local) esperarían a que terminara y no habría segundo plano.
    ( cd "$RAIZ" && bash "$banco" > "$DIR/$nombre.log" 2>&1 < /dev/null; echo $? > "$DIR/$nombre.rc" ) \
      > /dev/null 2>&1 < /dev/null &
    echo "$nombre $! $(date +%s)" >> "$DIR/lanzados"
    echo "bancos-en-fondo: $banco en segundo plano (pid $!)"
  done
}

esperar() {
  local tope=600
  if [ "${1:-}" = "--tope" ]; then tope="${2:?--tope necesita segundos}"; shift 2; fi
  if [ ! -s "$DIR/lanzados" ]; then
    echo "::error title=Bancos en segundo plano::No se lanzó ninguno (falta $DIR/lanzados). Sin ellos no hay verde."
    exit 1
  fi
  local rojos=() nombre pid desde rc limite
  while read -r nombre pid desde; do
    limite=$((desde + tope))
    while [ ! -f "$DIR/$nombre.rc" ] && kill -0 "$pid" 2>/dev/null && [ "$(date +%s)" -lt "$limite" ]; do
      sleep 1
    done
    # El subshell escribe el .rc justo antes de salir: si acaba de terminar, un respiro.
    [ -f "$DIR/$nombre.rc" ] || sleep 1
    if [ -f "$DIR/$nombre.rc" ]; then
      rc=$(tr -dc '0-9' < "$DIR/$nombre.rc"); rc=${rc:-1}
    elif kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null; rc="tope de ${tope} s"
    else
      rc="murió sin código de salida"
    fi
    if [ "$rc" = 0 ]; then estado=verde; else estado="ROJO ($rc)"; fi
    echo "::group::$nombre — $estado, $(( $(date +%s) - desde )) s"
    cat "$DIR/$nombre.log" 2>/dev/null || echo "(sin log)"
    echo "::endgroup::"
    [ "$rc" = 0 ] || rojos+=("$nombre ($rc)")
  done < "$DIR/lanzados"
  rm -rf "$DIR"
  if [ ${#rojos[@]} -gt 0 ]; then
    echo "::error title=Bancos en segundo plano::En rojo: ${rojos[*]}"
    exit 1
  fi
  echo "bancos-en-fondo: todos en verde"
}

case "${1:-}" in
  lanzar)  shift; lanzar "$@" ;;
  esperar) shift; esperar "$@" ;;
  *) uso ;;
esac
