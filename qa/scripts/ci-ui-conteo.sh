#!/usr/bin/env bash
# ¿Ejecutó tests de verdad esta tanda de UI? Lo llama el paso «¿Ejecutó tests la tanda?» del job
# `ui` de `.github/workflows/qa.yml`, justo después de `xcodebuild test-without-building`.
#
#   bash qa/scripts/ci-ui-conteo.sh <ruta.xcresult> <log de xcodebuild>
#
# POR QUÉ EXISTE (2026-11-07). Del 5 al 7-nov las nueve tandas de la nocturna corrieron CERO tests:
# el paquete `YalaUITests` no cargaba en el simulador («Failed to load the test bundle», runtime iOS
# 27.2 con Xcode 27.1; ver la cabecera de `ci-simulador.sh`). El paso de UI es advisory
# (`continue-on-error`), así que salía `failure` pintado de verde, y el aviso decía «hay tests de UI
# en rojo»: lo mismo que una noche con un rojo de verdad. Nadie distinguía «un test falló» de «no se
# probó nada». Este paso lee el `.xcresult` y el log y dice cuál de las dos fue.
#
# Qué contesta (`estado=` en $GITHUB_OUTPUT, más `ejecutados`, `pasados`, `fallados`, `omitidos`,
# `runtime`):
#   con_tests     corrió al menos un test (pasara o fallara). Los rojos siguen siendo advisory.
#   no_cargo      el paquete no cargó y no corrió ninguno. Sale con 1: la tanda se pone en rojo.
#   sin_tests     el `.xcresult` se lee y no corrió ninguno, sin error de carga a la vista. Sale con 1.
#   solo_omitidos todos los casos se saltaron (`XCTSkip`). Aviso, sale con 0: no es un fallo de entorno.
#   ilegible      no hay `.xcresult` legible (p. ej. el tope del paso lo cortó). Aviso, sale con 0:
#                 el paso de tests ya salió `failure` y el aviso lo cuenta.
#
# Sale con 1 SOLO en `no_cargo` y `sin_tests`. Es la única forma en que la UI pone su job en rojo:
# un test en rojo sigue sin hacerlo (la UI sigue advisory); una tanda que no probó nada, sí, porque
# un verde ahí miente.
#
# Variables: TANDA (para los textos) · XCRUN (el banco pone uno falso) · GITHUB_OUTPUT ·
# GITHUB_STEP_SUMMARY.
# Banco: qa/scripts/ci-ui-conteo-test.sh
set -uo pipefail

RB="${1:?falta la ruta del .xcresult}"
LOG="${2:?falta el log de xcodebuild}"
TANDA="${TANDA:-?}"
XCRUN="${XCRUN:-xcrun}"

# Los comandos de flujo de GitHub cortan en `%`, CR y LF.
anota() { local s="${2//'%'/%25}"; s="${s//$'\r'/%0D}"; s="${s//$'\n'/%0A}"; echo "::$1 title=$3::$s"; }
sal() { [ -z "${GITHUB_OUTPUT:-}" ] || echo "$1=$2" >> "$GITHUB_OUTPUT"; echo "  → $1=$2"; }

json=""
if [ -d "$RB" ]; then
  json="$("$XCRUN" xcresulttool get test-results summary --path "$RB" --compact 2>/dev/null)" || json=""
fi

# Una línea: pasados fallados esperados omitidos total carga runtime  ·  o nada si no se lee.
cifras="$(printf '%s' "$json" | python3 -I -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except ValueError:
    sys.exit()
if not isinstance(d, dict) or "totalTestCount" not in d:
    sys.exit()
n = lambda k: int(d.get(k) or 0)
rt = "?"
for dc in d.get("devicesAndConfigurations") or []:
    dev = dc.get("device") or {}
    if dev.get("osVersion"):
        rt = "iOS %s (%s)" % (dev["osVersion"], dev.get("osBuildNumber") or "?")
        break
carga = any("Failed to load the test bundle" in (f.get("failureText") or "")
            for f in d.get("testFailures") or [])
print(n("passedTests"), n("failedTests"), n("expectedFailures"), n("skippedTests"),
      n("totalTestCount"), "si" if carga else "no", rt.replace(" ", "_"))
')"

no_cargo_log=no
grep -q "Failed to load the test bundle" "$LOG" 2>/dev/null && no_cargo_log=si
# La causa que da dyld (`Symbol not found…`, `Library not loaded…`), si la hay: la primera basta.
causa="$(grep -m1 -oE "(Symbol not found|Library not loaded)[^)]{0,200}" "$LOG" 2>/dev/null || true)"

total=0
if [ -z "$cifras" ]; then
  if [ "$no_cargo_log" != si ]; then
    sal estado ilegible
    anota warning "Tanda $TANDA: no hay un .xcresult legible en $RB; no se puede contar qué corrió. Si el paso de tests agotó su tope, el aviso ya lo cuenta como rojo." "Tanda $TANDA sin conteo"
    exit 0
  fi
  estado=no_cargo; ejecutados=0; pasados=0; fallados=0; omitidos=0; runtime="?"
else
  read -r pasados fallados esperados omitidos total carga_rb runtime <<< "$cifras"
  runtime="${runtime//_/ }"
  ejecutados=$((pasados + fallados + esperados))
  if [ "$ejecutados" -gt 0 ]; then estado=con_tests
  elif [ "$no_cargo_log" = si ] || [ "$carga_rb" = si ]; then estado=no_cargo
  elif [ "$total" -gt 0 ] && [ "$omitidos" -eq "$total" ]; then estado=solo_omitidos
  else estado=sin_tests
  fi
fi

sal estado "$estado"
sal ejecutados "$ejecutados"
sal pasados "$pasados"
sal fallados "$fallados"
sal omitidos "$omitidos"
sal runtime "$runtime"
linea="Tanda $TANDA: $ejecutados tests ejecutados ($pasados pasaron, $fallados fallaron, $omitidos omitidos) en $runtime."
[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "**$linea** Estado: \`$estado\`." >> "$GITHUB_STEP_SUMMARY"

case "$estado" in
  con_tests)
    anota notice "$linea" "Tanda $TANDA" ;;
  solo_omitidos)
    anota warning "$linea Todos los casos se saltaron: no es un fallo de entorno, pero esta tanda no probó nada." "Tanda $TANDA solo omitidos" ;;
  no_cargo)
    anota error "Tanda $TANDA: el paquete YalaUITests NO CARGÓ y no se ejecutó ningún test (runtime $runtime). No es un rojo de test ni un verde: es el entorno. ${causa:+Causa de dyld: $causa. }Si el runtime es más nuevo que el SDK del Xcode, mira qa/scripts/ci-simulador.sh." "Tanda $TANDA sin tests: el paquete no cargó"
    exit 1 ;;
  sin_tests)
    anota error "Tanda $TANDA: el .xcresult no registra ningún test ejecutado (total $total, runtime $runtime). La selección quedó vacía o el runner murió antes del primero: esta tanda no probó nada." "Tanda $TANDA sin tests"
    exit 1 ;;
esac
exit 0
