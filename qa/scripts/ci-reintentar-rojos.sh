#!/usr/bin/env bash
# Corre una suite de tests UNA vez y, si hay rojos, repite SOLO esos tests (2026-10-06).
#
#   bash qa/scripts/ci-reintentar-rojos.sh [--vueltas N] [--max-rojos M] [--dir DIR] \
#     -- <argumentos comunes de xcodebuild, verbo incluido> \
#     --- <selección de la primera vuelta: -only-testing / -skip-testing>
#
# POR QUÉ NO `-retry-tests-on-failure`. Con Swift Testing, `xcodebuild` no repite el test que
# falló: repite la SUITE ENTERA hasta 3 veces. Medido en el paso pure-logic de `qa.yml`: un solo
# rojo lo llevaba de ~13 a 27-30 min (26 889 tests = 3 × 8 963) y el tope de 45 min del job lo
# cancelaba — y `continue-on-error` no rescata una cancelación, así que un rojo advisory dejaba
# `tests` en rojo y el auto-merge bloqueado. Con XCTest no pasa: en las nocturnas de UI cada caso
# rojo sale 3 veces y ningún verde se repite. Ticket:
# `ci-one-red-in-pure-logic-triples-the-step-and-the-job-ceiling-cancels-it`.
#
# CÓMO. Primera vuelta con la selección completa y sin reintento. Si sale en rojo, se leen del
# `.xcresult` los casos con `result: Failed` (`xcresulttool get test-results tests`) y se repiten
# solos con `-only-testing:<bundle>/<id>`. Cada vuelta repite solo lo que sigue en rojo, hasta
# `--vueltas` en total (3, como el reintento de Xcode).
#
# QUÉ CUENTA COMO RESCATADO. Que el test APAREZCA como `Passed` en el `.xcresult` de la
# repetición — no el exit 0 de `xcodebuild`. Medido: un `-only-testing` que no casa con ningún
# test sale exit 0 con CERO tests ejecutados. Fiarse del exit daría por rescatado un rojo que no
# se volvió a correr.
#
# CAÍDA SEGURA. Si el `.xcresult` de la primera vuelta falta, no se puede leer, tiene un formato
# inesperado o no nombra ningún caso rojo (un fallo de lanzamiento, por ejemplo), o hay más de
# `--max-rojos` (eso ya no es un flaky), NO se repite nada: sale con el código de la primera
# vuelta. Nunca cae a repetir la suite entera.
#
# Formato medido con un paquete sonda (Xcode 27): `nodeIdentifier` vale `Suite/test()` —también
# para un `@Test("nombre visible")`: el identificador es la función, no el nombre—,
# `Suite/Anidada/test()`, `test()` para una función libre, y `Suite/param(n:)` UNA vez aunque
# fallen varios argumentos. Todos sirven tal cual en `-only-testing` con el bundle delante.
#
# UN CRASH NO DEJA TESTS SIN CORRER. Medido con la sonda: si el proceso de test muere,
# `xcodebuild` lo relanza («Restarting after unexpected exit, crash, or test timeout») y sigue con
# los casos de detrás; el `.xcresult` marca `Failed` solo el que estaba corriendo. Por eso basta
# con repetir los rojos: no hay casos «sin ejecutar» que la primera vuelta se haya saltado.
#
# Salida en `$GITHUB_OUTPUT` (si existe): `rojos` (los que siguen en rojo, separados por «; »),
# `rescatados`, `vueltas` (las que corrieron) y `tests_primera` (casos de la primera vuelta).
# Exit: 0 si todo verde o todo rescatado; 1 si queda algún rojo tras repetirlo; el código de la
# primera vuelta en la caída segura; 2 si se llama mal.
#
# Banco: `qa/scripts/ci-reintentar-rojos-test.sh` (corre en el job `coverage-index`).
set -uo pipefail

XCODEBUILD="${XCODEBUILD:-xcodebuild}"
XCRUN="${XCRUN:-xcrun}"
VUELTAS=3
MAX_ROJOS=100
DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/reintentar-rojos"

uso() { echo "uso: $0 [--vueltas N] [--max-rojos M] [--dir DIR] -- <comunes> --- <selección>" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --vueltas) VUELTAS="${2:-}"; shift 2 ;;
    --max-rojos) MAX_ROJOS="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    --) shift; break ;;
    *) uso ;;
  esac
done
case "$VUELTAS" in ''|*[!0-9]*) uso ;; esac
case "$MAX_ROJOS" in ''|*[!0-9]*) uso ;; esac
[ "$VUELTAS" -ge 1 ] || uso

comunes=()
while [ $# -gt 0 ] && [ "$1" != "---" ]; do comunes+=("$1"); shift; done
[ "${1:-}" = "---" ] && shift
seleccion=("$@")
[ "${#comunes[@]}" -gt 0 ] || uso

mkdir -p "$DIR" || { echo "no puedo crear $DIR" >&2; exit 2; }

# Una línea por caso: «<resultado>\t<bundle>/<nodeIdentifier>». Exit ≠ 0 si el JSON no tiene la
# forma esperada: mejor caer a la salida segura que repetir algo mal leído.
PY='
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(3)
nodos = d.get("testNodes") if isinstance(d, dict) else None
if not isinstance(nodos, list):
    sys.exit(3)
casos = []
def recorre(n, bundle):
    if not isinstance(n, dict):
        sys.exit(4)
    tipo = n.get("nodeType") or ""
    if tipo.endswith("test bundle"):
        bundle = n.get("name")
    if tipo == "Test Case":
        nid, res = n.get("nodeIdentifier"), n.get("result")
        if not bundle or not nid or not res:
            sys.exit(4)
        ident = bundle + "/" + nid
        if "\t" in ident or "\n" in ident:
            sys.exit(5)
        casos.append(res + "\t" + ident)
        return
    for c in n.get("children") or []:
        recorre(c, bundle)
for n in nodos:
    recorre(n, None)
print("\n".join(casos))
'

leer_casos() {
  local json
  json="$("$XCRUN" xcresulttool get test-results tests --path "$1" --compact 2>/dev/null)" || return 1
  printf '%s' "$json" | python3 -I -c "$PY"
}

# Los comandos de flujo de GitHub cortan en `%`, CR y LF.
anota() { local s="${2//'%'/%25}"; s="${s//$'\r'/%0D}"; s="${s//$'\n'/%0A}"; echo "::$1 title=$3::$s"; }

rojos_txt="" rescatados_txt="" tests_primera="" vuelta=0
publica() {
  [ -n "${GITHUB_OUTPUT:-}" ] || return 0
  {
    echo "rojos=$rojos_txt"
    echo "rescatados=$rescatados_txt"
    echo "vueltas=$vuelta"
    echo "tests_primera=$tests_primera"
  } >> "$GITHUB_OUTPUT"
}
une() { local IFS=$'\n'; printf '%s\n' "$*" | awk 'NF' | paste -sd ';' - | sed 's/;/; /g'; }

corre() { # $1 = número de vuelta; resto = selección
  local k="$1"; shift
  local rb="$DIR/vuelta-$k.xcresult"
  rm -rf "$rb"   # xcodebuild se niega a escribir sobre un -resultBundlePath que ya existe
  local t0=$SECONDS
  "$XCODEBUILD" "${comunes[@]}" "$@" -resultBundlePath "$rb"
  local ex=$?
  echo "── vuelta $k/$VUELTAS: exit $ex en $(( (SECONDS - t0) / 60 )) min $(( (SECONDS - t0) % 60 )) s"
  return "$ex"
}

# ── Vuelta 1: la selección entera, sin reintento ─────────────────────────────────────────────
vuelta=1
corre 1 "${seleccion[@]+"${seleccion[@]}"}"
ex1=$?
casos="$(leer_casos "$DIR/vuelta-1.xcresult")"; leido=$?
[ "$leido" -eq 0 ] && tests_primera="$(printf '%s\n' "$casos" | awk 'NF' | wc -l | tr -d ' ')"

if [ "$ex1" -eq 0 ]; then
  echo "── en verde a la primera (${tests_primera:-?} casos). Nada que repetir."
  publica; exit 0
fi

pendientes=()
if [ "$leido" -eq 0 ]; then
  while IFS=$'\t' read -r res id; do
    [ "$res" = "Failed" ] && pendientes+=("$id")
  done <<< "$casos"
fi

if [ "$leido" -ne 0 ] || [ "${#pendientes[@]}" -eq 0 ]; then
  rojos_txt="(sin identificar: xcodebuild salió con $ex1 y el .xcresult no nombra ningún caso rojo — mira el log)"
  anota error "xcodebuild salió con $ex1 y no pude leer del .xcresult qué tests fallaron. No repito nada: un rojo es un rojo." "Rojo sin identificar"
  publica; exit "$ex1"
fi

if [ "${#pendientes[@]}" -gt "$MAX_ROJOS" ]; then
  rojos_txt="$(une "${pendientes[@]:0:20}") … (${#pendientes[@]} en total)"
  anota error "${#pendientes[@]} tests en rojo, más del tope de $MAX_ROJOS: eso no es un flaky. No repito nada." "Demasiados rojos para repetir"
  publica; exit "$ex1"
fi

# Los nombres salen ya, antes de repetir: si algo corta la repetición (el tope del paso, una
# cancelación), el aviso sabe al menos qué falló en la primera vuelta. `publica` vuelve a escribir
# las mismas claves al final, y en `$GITHUB_OUTPUT` gana la última.
rojos_txt="$(une "${pendientes[@]}")"
publica

# ── Vueltas 2..N: solo lo que sigue en rojo ──────────────────────────────────────────────────
rescatados=()
while [ "${#pendientes[@]}" -gt 0 ] && [ "$vuelta" -lt "$VUELTAS" ]; do
  vuelta=$((vuelta + 1))
  echo "── vuelta $vuelta/$VUELTAS: repito SOLO ${#pendientes[@]} test(s): $(une "${pendientes[@]}")"
  args=(); for id in "${pendientes[@]}"; do args+=("-only-testing:$id"); done
  corre "$vuelta" "${args[@]}"
  if ! casos="$(leer_casos "$DIR/vuelta-$vuelta.xcresult")"; then
    anota warning "No pude leer el .xcresult de la vuelta $vuelta: lo que quedaba en rojo se queda en rojo." "Repetición ilegible"
    break
  fi
  siguen=()
  for id in "${pendientes[@]}"; do
    res="$(printf '%s\n' "$casos" | awk -F'\t' -v id="$id" '$2 == id { print $1; exit }')"
    case "$res" in
      Passed|"Expected Failure") rescatados+=("$id") ;;
      *) siguen+=("$id") ;;   # Failed, Skipped o ausente: no se volvió a ver en verde
    esac
  done
  pendientes=("${siguen[@]+"${siguen[@]}"}")
done

for id in "${rescatados[@]+"${rescatados[@]}"}"; do
  anota warning "$id falló y pasó al repetirlo solo: flaky, o depende del orden de la suite." "Rescatado al repetirlo"
done
for id in "${pendientes[@]+"${pendientes[@]}"}"; do
  anota error "$id sigue en rojo tras $vuelta vuelta(s)." "Test en rojo"
done
rescatados_txt="$(une "${rescatados[@]+"${rescatados[@]}"}")"
rojos_txt="$(une "${pendientes[@]+"${pendientes[@]}"}")"
publica

if [ "${#pendientes[@]}" -eq 0 ]; then
  echo "── todo rescatado en $vuelta vuelta(s)."
  exit 0
fi
echo "── quedan ${#pendientes[@]} rojo(s) tras $vuelta vuelta(s)."
exit 1
