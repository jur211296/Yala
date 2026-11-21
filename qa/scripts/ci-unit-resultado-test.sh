#!/usr/bin/env bash
# Banco de `ci-unit-resultado.sh`, el veredicto del check `tests`. Si se rompe hacia el verde, el
# auto-merge mergea un PR con unit en rojo o sin correr: el fallo que el ruleset existe para parar.
#
#   bash qa/scripts/ci-unit-resultado-test.sh
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-unit-resultado.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fallos=0
ok()  { echo "  ok  $1"; }
mal() { echo "  MAL $1"; fallos=$((fallos + 1)); }

# caso <etiqueta> <exit esperado> <unit_pure esperado> <unit_context esperado> VAR=valor…
caso() {
  local etiqueta="$1" rc_esp="$2" pure_esp="$3" ctx_esp="$4"; shift 4
  : > "$T/out"
  env -i PATH="$PATH" GITHUB_OUTPUT="$T/out" GITHUB_STEP_SUMMARY="$T/sum" TANDAS="1 2 3" "$@" \
    bash "$SCRIPT" > "$T/log" 2>&1
  local rc=$? pure ctx
  pure=$(sed -n 's/^unit_pure=//p' "$T/out"); ctx=$(sed -n 's/^unit_context=//p' "$T/out")
  if [ "$rc" = "$rc_esp" ] && [ "$pure" = "$pure_esp" ] && [ "$ctx" = "$ctx_esp" ]; then
    ok "$etiqueta"
  else
    mal "$etiqueta — rc $rc (esperado $rc_esp), unit_pure «$pure» («$pure_esp»), unit_context «$ctx» («$ctx_esp»)"
  fi
}

V="BUILD=success UNIT=success PURE_1=success PURE_2=success PURE_3=success CONTEXTO=success"
# shellcheck disable=SC2086
caso "todo verde → 0" 0 success success $V
# shellcheck disable=SC2086
caso "una tanda en rojo → 1 y failure" 1 failure success $V UNIT=failure PURE_2=failure ROJOS_2="YalaTests/X/a()"
grep -q "unit_pure_rojos=YalaTests/X/a()" "$T/out" && ok "nombra los rojos" || mal "no pasa los rojos: $(cat "$T/out")"
# shellcheck disable=SC2086
caso "context-based en rojo → 1" 1 success failure $V UNIT=failure CONTEXTO=failure
# shellcheck disable=SC2086
caso "una tanda sin resultado (cancelada) → 1 y vacío" 1 "" success $V UNIT=cancelled PURE_3=
# shellcheck disable=SC2086
caso "rojo y además una sin resultado → vacío (no llegó a correr manda)" 1 "" success $V UNIT=failure PURE_1=failure PURE_3=
caso "build caído, tandas saltadas → 1 y vacío" 1 "" "" BUILD=failure UNIT=skipped
# shellcheck disable=SC2086
caso "UNIT no success aunque los pasos digan success → 1" 1 success success $V UNIT=cancelled
# shellcheck disable=SC2086
caso "context-based sin resultado → 1" 1 success "" $V CONTEXTO=
# shellcheck disable=SC2086
caso "un valor raro cuenta como sin resultado" 1 "" success $V PURE_2=skipped
caso "sin TANDAS → 1" 1 "" "" BUILD=success UNIT=success TANDAS=
grep -q "Siguen en rojo" "$T/sum" 2>/dev/null && ok "escribe el resumen del job" || mal "sin resumen"

echo
if [ "$fallos" -eq 0 ]; then echo "ci-unit-resultado: todo en orden"; else echo "ci-unit-resultado: $fallos caso(s) MAL"; exit 1; fi
