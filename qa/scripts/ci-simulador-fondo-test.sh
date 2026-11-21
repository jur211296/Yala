#!/usr/bin/env bash
# Banco de `ci-simulador-fondo.sh`. No toca ningún simulador: un `ci-simulador.sh` y un `xcrun` de
# mentira en un temporal.
#
#   bash qa/scripts/ci-simulador-fondo-test.sh
#
# Lo que tiene que cumplir:
#   1. `lanzar` vuelve enseguida; `esperar` deja `udid` y `runtime` en el GITHUB_OUTPUT del paso.
#   2. Con `--arrancar`, arranca el device que eligió `ci-simulador.sh` (boot + bootstatus).
#   3. Si el arranque falla, avisa y sale en verde: lo arrancará el primer test.
#   4. Si `ci-simulador.sh` sale en rojo, `esperar` sale con su código y no lo arranca.
#   5. `esperar` sin `lanzar` → 1. Una preparación que pasa del tope → 1.
#   6. Las anotaciones de `ci-simulador.sh` salen en el paso de `esperar`.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-simulador-fondo.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export SIM_FONDO_DIR="$T/estado" CI_SIMULADOR="$T/ci-simulador.sh" PATH="$T/bin:$PATH"
mkdir -p "$T/bin"

fallos=0
ok()  { echo "  ok  $1"; }
mal() { echo "  MAL $1"; fallos=$((fallos + 1)); }

# ci-simulador.sh de mentira: MODO_SIM=verde|rojo|lento
cat > "$CI_SIMULADOR" <<'FAKE'
#!/bin/bash
case "${MODO_SIM:-verde}" in
  rojo)  echo "::error title=Simulador::no hay runtime"; exit 1 ;;
  lento) sleep 30 ;;
esac
echo "::warning title=Runtime::aviso de prueba"
echo "udid=AAAA-1111" >> "$GITHUB_OUTPUT"
echo "runtime=iOS 27.0 (24A0)" >> "$GITHUB_OUTPUT"
echo "**Entorno de test:** de prueba" >> "$GITHUB_STEP_SUMMARY"
FAKE
# xcrun de mentira: apunta lo que le piden; FALLA_BOOT=si hace fallar el boot.
cat > "$T/bin/xcrun" <<FAKE
#!/bin/bash
echo "\$*" >> "$T/xcrun.log"
[ "\$2" = boot ] && [ "\${FALLA_BOOT:-no}" = si ] && exit 149
exit 0
FAKE
chmod +x "$CI_SIMULADOR" "$T/bin/xcrun"

paso() {  # corre `esperar` con salidas del paso en ficheros nuevos
  : > "$T/out"; : > "$T/sum"
  GITHUB_OUTPUT="$T/out" GITHUB_STEP_SUMMARY="$T/sum" bash "$SCRIPT" esperar "$@" > "$T/log" 2>&1
}

echo "1. verde sin arrancar"
rm -f "$T/xcrun.log"
t0=$(date +%s); bash "$SCRIPT" lanzar > /dev/null 2>&1; dt=$(( $(date +%s) - t0 ))
[ "$dt" -lt 2 ] && ok "lanzar vuelve enseguida" || mal "lanzar tardó $dt s"
paso; rc=$?
[ "$rc" = 0 ] && ok "esperar sale 0" || mal "esperar salió $rc: $(cat "$T/log")"
grep -qx "udid=AAAA-1111" "$T/out" && grep -q "^runtime=" "$T/out" && ok "copia udid y runtime" || mal "salidas: $(cat "$T/out")"
grep -q "Entorno de test" "$T/sum" && ok "copia el resumen" || mal "sin resumen"
grep -q "::warning title=Runtime" "$T/log" && ok "las anotaciones salen en el paso" || mal "anotación perdida"
[ ! -f "$T/xcrun.log" ] && ok "sin --arrancar no arranca nada" || mal "arrancó sin pedirlo"

echo "2. verde con --arrancar"
rm -f "$T/xcrun.log"
bash "$SCRIPT" lanzar --arrancar > /dev/null 2>&1; paso; rc=$?
[ "$rc" = 0 ] && ok "esperar sale 0" || mal "esperar salió $rc"
grep -qx "simctl boot AAAA-1111" "$T/xcrun.log" && grep -qx "simctl bootstatus AAAA-1111" "$T/xcrun.log" \
  && ok "arranca el device elegido" || mal "xcrun recibió: $(cat "$T/xcrun.log" 2>/dev/null)"

echo "3. arranque fallido"
FALLA_BOOT=si bash "$SCRIPT" lanzar --arrancar > /dev/null 2>&1; paso; rc=$?
[ "$rc" = 0 ] && ok "sigue en verde" || mal "salió $rc"
grep -q "Simulador sin arrancar" "$T/log" && ok "lo avisa" || mal "no avisa"

echo "4. ci-simulador.sh en rojo"
rm -f "$T/xcrun.log"
MODO_SIM=rojo bash "$SCRIPT" lanzar --arrancar > /dev/null 2>&1; paso; rc=$?
[ "$rc" = 1 ] && ok "esperar sale 1" || mal "esperar salió $rc"
[ ! -f "$T/xcrun.log" ] && ok "no intenta arrancar" || mal "intentó arrancar"
[ ! -s "$T/out" ] && ok "sin udid" || mal "dejó salidas: $(cat "$T/out")"

echo "5. sin lanzar y tope"
rm -rf "$SIM_FONDO_DIR"; paso; rc=$?
[ "$rc" = 1 ] && ok "esperar sin lanzar sale 1" || mal "salió $rc"
MODO_SIM=lento bash "$SCRIPT" lanzar > /dev/null 2>&1
t0=$(date +%s); paso --tope 2; rc=$?; dt=$(( $(date +%s) - t0 ))
[ "$rc" = 1 ] && [ "$dt" -lt 10 ] && ok "pasar del tope sale 1 a tiempo ($dt s)" || mal "tope: rc $rc, $dt s"
grep -q "pasó del tope" "$T/log" && ok "dice que fue el tope" || mal "no dice el tope"

echo
if [ "$fallos" -eq 0 ]; then echo "ci-simulador-fondo: todo en orden"; else echo "ci-simulador-fondo: $fallos caso(s) MAL"; exit 1; fi
