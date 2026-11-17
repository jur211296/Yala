#!/usr/bin/env bash
# Banco de la cuarentena de pruebas inestables (`qa/cuarentena.json`, 2026-11-17). Corre en el job
# `coverage-index`.
#
#   bash qa/scripts/cuarentena-test.sh
#
# Dos mitades:
#   1. La cuarentena REAL del árbol tiene que ser válida. El CI la lee de 2.3, así que un fichero
#      roto que entrara en 2.3 dejaría la lista vacía para todos los PR (y en modo bloquear, todo
#      rescate en rojo). Este paso es requerido: un PR no puede meter una cuarentena rota.
#   2. El lector (`ci-reintentar-rojos.sh --validar-cuarentena` / `--informe-cuarentena`) rechaza lo
#      que debe y cuenta bien los días. El juicio de los rescates lo cubre
#      `ci-reintentar-rojos-test.sh`, casos 21-28.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
SCRIPT="$AQUI/ci-reintentar-rojos.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fallos=0

afirma() { # afirma <descripción> <comando...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok   $d"; else echo "FALLO $d"; fallos=$((fallos+1)); fi
}
niega() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "FALLO $d"; fallos=$((fallos+1)); else echo "ok   $d"; fi; }
valida() { HOY="${HOY:-2026-11-17}" bash "$SCRIPT" --validar-cuarentena "$1"; }

# Escribe una cuarentena: `escribe <fichero> <python que devuelve el dict d>`.
escribe() {
  python3 -I - "$1" "$2" <<'PY'
import json, sys
d = {"_meta": {"modo": "observar", "bloquearDesde": "2026-12-01", "caducidadDias": 14},
     "pruebas": [{"prueba": "YalaTests/A/x()", "dueno": "frank", "ticket": "t", "entrada": "2026-11-10", "motivo": "m"}]}
exec(sys.argv[2])
json.dump(d, open(sys.argv[1], "w"))
PY
}

# ── 1. La real ───────────────────────────────────────────────────────────────────────────────
real="$RAIZ/qa/cuarentena.json"
if HOY="$(date -u +%F)" bash "$SCRIPT" --validar-cuarentena "$real"; then
  echo "ok   qa/cuarentena.json es válida"
else
  echo "FALLO qa/cuarentena.json no es válida (arriba, cada MALA)"; fallos=$((fallos+1))
fi

# ── 2. El lector ─────────────────────────────────────────────────────────────────────────────
escribe "$T/buena.json" "pass"
afirma "una lista bien formada pasa" valida "$T/buena.json"
escribe "$T/bloquear.json" "d['_meta']['modo'] = 'bloquear'"
afirma "modo bloquear es válido" valida "$T/bloquear.json"
escribe "$T/vacia.json" "d['pruebas'] = []"
afirma "una lista vacía es válida" valida "$T/vacia.json"
escribe "$T/suite.json" "d['pruebas'][0]['prueba'] = 'YalaTests/Suite'"
afirma "una entrada de suite es válida" valida "$T/suite.json"

escribe "$T/modo.json" "d['_meta']['modo'] = 'avisar'"
niega "rechaza un modo desconocido" valida "$T/modo.json"
escribe "$T/sinmodo.json" "del d['_meta']['modo']"
niega "rechaza un modo ausente" valida "$T/sinmodo.json"
escribe "$T/cad.json" "d['_meta']['caducidadDias'] = 0"
niega "rechaza caducidadDias 0" valida "$T/cad.json"
escribe "$T/desde.json" "d['_meta']['bloquearDesde'] = '1-dic'"
niega "rechaza bloquearDesde sin formato" valida "$T/desde.json"
for k in prueba dueno ticket entrada motivo; do
  escribe "$T/sin-$k.json" "del d['pruebas'][0]['$k']"
  niega "rechaza una entrada sin $k" valida "$T/sin-$k.json"
done
escribe "$T/blanco.json" "d['pruebas'][0]['dueno'] = '  '"
niega "rechaza un dueño en blanco" valida "$T/blanco.json"
escribe "$T/espacios.json" "d['pruebas'][0]['prueba'] = 'YalaTests/Yala encountered an error'"
niega "rechaza una prueba con espacios (el texto de un error no es una prueba)" valida "$T/espacios.json"
escribe "$T/sinbundle.json" "d['pruebas'][0]['prueba'] = 'x()'"
niega "rechaza una prueba sin Bundle/" valida "$T/sinbundle.json"
escribe "$T/fecha.json" "d['pruebas'][0]['entrada'] = '2026-02-30'"
niega "rechaza una entrada que no es fecha" valida "$T/fecha.json"
escribe "$T/futuro.json" "d['pruebas'][0]['entrada'] = '2026-11-18'"
niega "rechaza una entrada posterior a hoy" valida "$T/futuro.json"
escribe "$T/dup.json" "d['pruebas'].append(dict(d['pruebas'][0]))"
niega "rechaza una prueba repetida" valida "$T/dup.json"
escribe "$T/sinlista.json" "del d['pruebas']"
niega "rechaza un fichero sin la lista pruebas" valida "$T/sinlista.json"
printf '{ roto' > "$T/roto.json"
niega "rechaza un JSON roto" valida "$T/roto.json"
niega "rechaza un fichero que no existe" valida "$T/no-existe.json"

# Días: a los 13 no vence, a los 14 sí (entrada 2026-11-10).
informe() { HOY="$1" GITHUB_STEP_SUMMARY="$T/resumen-$1" bash "$SCRIPT" --informe-cuarentena "$2"; }
informe 2026-11-23 "$T/buena.json" > "$T/inf13" 2>&1
afirma "a los 13 días no está vencida" bash -c '! grep -q "Cuarentena vencida" "$0" && grep -q "Ninguna vencida" "$1"' "$T/inf13" "$T/resumen-2026-11-23"
informe 2026-11-24 "$T/buena.json" > "$T/inf14" 2>&1
afirma "a los 14 días está vencida, con aviso y fila en el resumen" \
  bash -c 'grep -q "::warning title=Cuarentena vencida::YalaTests/A/x() lleva 14 días" "$0" && grep -q "| \`YalaTests/A/x()\` | frank | t | 2026-11-10 | 14 |" "$1"' "$T/inf14" "$T/resumen-2026-11-24"
afirma "el resumen dice el modo y cuándo pasa a bloquear" \
  bash -c 'grep -q "Modo \*\*observar\*\* · 1 prueba" "$0" && grep -q "Pasa a bloquear el 2026-12-01" "$0"' "$T/resumen-2026-11-24"
afirma "el informe nunca falla, ni con el fichero roto" informe 2026-11-24 "$T/roto.json"
informe 2026-11-24 "$T/roto.json" > "$T/inf-roto" 2>&1
afirma "con el fichero roto avisa como error visible" grep -q "::error title=Cuarentena ilegible::" "$T/inf-roto"
escribe "$T/mixta.json" "d['pruebas'].append({'prueba': 'YalaTests/B/y()', 'dueno': 'frank'})"
informe 2026-11-24 "$T/mixta.json" > "$T/inf-mixta" 2>&1
afirma "una entrada mala se salta y se dice; las buenas siguen contando" \
  bash -c 'grep -q "title=Cuarentena: entrada mala::" "$0" && grep -q "Cuarentena vencida::YalaTests/A/x()" "$0"' "$T/inf-mixta"

if [ "$fallos" -eq 0 ]; then
  echo "── cuarentena: todos los casos en verde."
else
  echo "── cuarentena: $fallos caso(s) en ROJO."
  exit 1
fi
