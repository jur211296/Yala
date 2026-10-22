#!/usr/bin/env bash
# Banco de la promesa «un unit test en rojo pone `tests` en rojo» (2026-10-10). No compila ni toca
# ningún simulador: lee `.github/workflows/qa.yml` y unas copias mutadas en un directorio temporal.
#
#   bash qa/scripts/ci-unit-bloqueante-test.sh
#
# POR QUÉ EXISTE. `tests` es check requerido del ruleset de `2.1`, y el auto-merge (ADR-054 de
# casa) mergea en cuanto sale verde. Hasta el 2026-10-10 los pasos de unit llevaban
# `continue-on-error: true`: GitHub los pinta de verde aunque `xcodebuild` salga con 65, así que un
# PR en cola entraba con un unit en rojo. Volver a ponerlo no da ningún error —el CI sigue verde—,
# y por eso lo vigila este banco. Ticket: `ci-warns-but-does-not-block`.
#
# Lo que comprueba, sobre el job `tests`:
#   1. Ningún paso que corra tests (`test-without-building` o `ci-reintentar-rojos.sh`) lleva
#      `continue-on-error`, en ninguna de sus formas (`true`, una expresión `${{ }}`…). Solo
#      `false` explícito pasa.
#   2. Los dos pasos de unit existen (`id: unit_pure`, `id: unit_context`), corren tests, y en el job
#      hay al menos dos pasos de test: un renombrado no puede dejar el banco mirando un job vacío.
#   3. `unit_context` corre aunque `unit_pure` salga en rojo (`if:` con `!cancelled()`). Sin eso, un
#      rojo de pure-logic lo saltaría y el job `aviso` leería ese `skipped` como «la suite no llegó
#      a correr»: el mismo rojo contado como otro.
#   4. Ningún paso de test repite la suite entera con `-retry-tests-on-failure`. Con Swift Testing
#      ese flag repite TODA la selección hasta 3 veces (ver `ci-reintentar-rojos.sh`), y un rojo
#      triplicado se come el tope del job.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
REAL="$AQUI/../../.github/workflows/qa.yml"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fallos=0
ok()   { echo "  ok  $1"; }
mal()  { echo "  MAL $1"; fallos=$((fallos + 1)); }

# El comprobador. Sale 0 si el fichero cumple las cuatro reglas; 1 con un motivo por línea.
# Python de la biblioteca estándar, por sangría y sin PyYAML: la Mac no lo trae y el runner Linux
# no lo garantiza. El workflow es YAML de bloque con sangría de 2, así que basta.
comprobar() {
  python3 - "$1" <<'PY'
import re, sys

lineas = open(sys.argv[1], encoding="utf-8").read().splitlines()

# Bloque del job `tests`: desde `  tests:` hasta la siguiente clave de job (sangría 2).
ini = next((i for i, l in enumerate(lineas) if l == "  tests:"), None)
if ini is None:
    print("no hay job `tests`"); sys.exit(1)
fin = next((i for i in range(ini + 1, len(lineas))
            if re.match(r"^  [A-Za-z0-9_-]+:\s*$", lineas[i])), len(lineas))
job = lineas[ini:fin]

# Pasos: cada `      - ` (sangría 6) abre uno; sigue mientras haya sangría 8 o líneas vacías.
pasos, actual = [], None
for l in job:
    if re.match(r"^      - ", l):
        actual = [l]; pasos.append(actual)
    elif actual is not None and (l.startswith("        ") or l.strip() == ""):
        actual.append(l)
    elif not l.lstrip().startswith("#"):
        actual = None

def campo(paso, nombre):
    for l in paso:
        if l.lstrip().startswith("#"):
            continue
        m = re.match(r"^      (?:- |  )" + re.escape(nombre) + r":\s*(.*)$", l)
        if m:
            return m.group(1).strip()
    return None

def cuerpo(paso):
    return "\n".join(l for l in paso if not l.lstrip().startswith("#"))

motivos = []
de_test = [p for p in pasos if re.search(r"test-without-building|ci-reintentar-rojos\.sh", cuerpo(p))]
if len(de_test) < 2:
    motivos.append(f"solo {len(de_test)} paso(s) de test en el job `tests` (se esperan al menos 2)")

for p in de_test:
    nombre = campo(p, "id") or campo(p, "name") or "?"
    coe = campo(p, "continue-on-error")
    if coe is not None and coe.lower() != "false":
        motivos.append(f"`{nombre}` lleva continue-on-error: {coe}")
    if "-retry-tests-on-failure" in cuerpo(p):
        motivos.append(f"`{nombre}` repite la suite entera con -retry-tests-on-failure")

ids = {campo(p, "id"): p for p in pasos if campo(p, "id")}
for requerido in ("unit_pure", "unit_context"):
    if requerido not in ids:
        motivos.append(f"falta el paso `id: {requerido}`")
    elif not any(ids[requerido] is p for p in de_test):
        motivos.append(f"`{requerido}` ya no corre tests")

if "unit_context" in ids:
    cond = (campo(ids["unit_context"], "if") or "").replace(" ", "")
    if "!cancelled()" not in cond:
        motivos.append("`unit_context` no lleva `if:` con !cancelled(): un rojo de pure-logic lo saltaría")

for m in motivos:
    print(m)
sys.exit(1 if motivos else 0)
PY
}

pasa() {
  local f="$1" etiqueta="$2" salida
  if salida="$(comprobar "$f" 2>&1)"; then ok "$etiqueta"; else mal "$etiqueta — $salida"; fi
}
# Tiene que fallar, y por el motivo esperado: caer por otro dejaría vivo al mutante sin saberlo.
cae() {
  local f="$1" etiqueta="$2" esperado="$3" salida
  if salida="$(comprobar "$f" 2>&1)"; then
    mal "$etiqueta — el comprobador lo dio por bueno"
  elif ! grep -qF -- "$esperado" <<< "$salida"; then
    mal "$etiqueta — cayó por otro motivo: $salida"
  else
    ok "$etiqueta"
  fi
}

# Copia del qa.yml real con una línea insertada tras, borrada o cambiada en la primera que case.
# Si el patrón no casa, el mutante no existe: eso es un MAL, no un verde.
mutar() {
  local destino="$1" modo="$2" patron="$3" texto="${4:-}"
  python3 - "$REAL" "$T/$destino" "$modo" "$patron" "$texto" <<'PY'
import re, sys
src, dst, modo, patron, texto = sys.argv[1:]
lineas = open(src, encoding="utf-8").read().split("\n")
i = next((i for i, l in enumerate(lineas) if re.search(patron, l)), None)
if i is None:
    sys.exit(3)
if modo == "tras":
    lineas.insert(i + 1, texto)
elif modo == "borra":
    del lineas[i]
else:
    lineas[i] = texto
open(dst, "w", encoding="utf-8").write("\n".join(lineas))
PY
}

echo "qa.yml real"
pasa "$REAL" "los pasos de unit del job tests bloquean"

echo "mutantes"
caso() {  # caso <etiqueta> <motivo esperado | PASA> <args de mutar…>
  local etiqueta="$1" esperado="$2"; shift 2
  if ! mutar "m.yml" "$@"; then mal "$etiqueta — el patrón del mutante ya no casa en qa.yml"; return; fi
  if [ "$esperado" = "PASA" ]; then pasa "$T/m.yml" "$etiqueta"; else cae "$T/m.yml" "$etiqueta" "$esperado"; fi
}

caso "continue-on-error en pure-logic"    "continue-on-error: true" \
  tras '^        id: unit_pure$' '        continue-on-error: true'
caso "continue-on-error en context-based" "continue-on-error: true" \
  tras '^        id: unit_context$' '        continue-on-error: true'
caso "continue-on-error como expresión"   'continue-on-error: ${{' \
  tras '^        id: unit_pure$' "        continue-on-error: \${{ github.event_name == 'pull_request' }}"
caso "continue-on-error: false explícito sigue valiendo" PASA \
  tras '^        id: unit_pure$' '        continue-on-error: false'
caso "context-based sin if: !cancelled()" 'no lleva `if:` con !cancelled()' \
  borra '^        if: .*steps\.build\.outcome'
caso "-retry-tests-on-failure en un paso de test" "-retry-tests-on-failure" \
  tras '^            -collect-test-diagnostics never \\$' '            -retry-tests-on-failure \\'
caso "renombrar el id de context-based"   'falta el paso `id: unit_context`' \
  cambia '^        id: unit_context$' '        id: unit_otro'

echo
if [ "$fallos" -eq 0 ]; then
  echo "ci-unit-bloqueante: todo en orden"
else
  echo "ci-unit-bloqueante: $fallos caso(s) MAL"
  exit 1
fi
