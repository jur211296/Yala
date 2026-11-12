#!/usr/bin/env bash
# Banco de qa/scripts/ci-calentar-simulador.sh. No toca ningún simulador: sustituye `xcrun` y
# `sleep` por guiones que apuntan cada llamada.
#
#   bash qa/scripts/ci-calentar-simulador-test.sh
#
# Lo que importa que no se rompa sin avisar: que arranque, instale, abra con `-uitest` y cierre, en
# ese orden; y que ningún fallo tumbe el paso (siempre sale 0, con aviso).
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-calentar-simulador.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fallos=0
ok()  { echo "  ok  $1"; }
mal() { echo "  MAL $1"; fallos=$((fallos + 1)); }

# xcrun falso: apunta «simctl <verbo> …» y falla en el verbo de $FALLA.
cat > "$T/xcrun" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$LLAMADAS"
[ "${2:-}" = "${FALLA:-ninguno}" ] && exit 1
exit 0
SH
cat > "$T/dormir" <<'SH'
#!/usr/bin/env bash
echo "sleep $*" >> "$LLAMADAS"
SH
chmod +x "$T/xcrun" "$T/dormir"
mkdir -p "$T/Yala.app"

correr() {
  : > "$T/llamadas"
  LLAMADAS="$T/llamadas" XCRUN="$T/xcrun" DORMIR="$T/dormir" APP="$T/Yala.app" \
    CALENTAR_SEGUNDOS=7 "$@" bash "$SCRIPT" > "$T/salida" 2>&1
}

echo "Camino feliz"
correr env UDID=ABC
codigo=$?
[ "$codigo" -eq 0 ] && ok "sale 0" || mal "sale $codigo"
orden=$(awk '{ if ($1 == "simctl") print $2; else print $1 }' "$T/llamadas" | tr '\n' ' ')
if [ "$orden" = "bootstatus install launch sleep terminate " ]; then ok "arranca, instala, abre, espera y cierra"
else mal "orden inesperado: $orden"; fi
grep -q "^simctl bootstatus ABC -b$" "$T/llamadas" && ok "espera al arranque con -b" || mal "no usa bootstatus -b"
grep -q "^simctl launch ABC com.jurgenschmidt.yala.dev -uitest -uitest-reset -uitest-skip-onboarding -uitest-seed minimal$" "$T/llamadas" \
  && ok "abre Yala Dev con los argumentos de un XCUITest" || mal "abre con otros argumentos: $(grep launch "$T/llamadas")"
grep -q "^sleep 7$" "$T/llamadas" && ok "respeta CALENTAR_SEGUNDOS" || mal "no espera lo pedido"

echo "Fallos que no tumban el paso"
for verbo in bootstatus install launch; do
  correr env UDID=ABC FALLA="$verbo"
  codigo=$?
  if [ "$codigo" -eq 0 ] && grep -q "::warning" "$T/salida"; then ok "si falla $verbo: aviso y sale 0"
  else mal "si falla $verbo: sale $codigo sin aviso"; fi
  if grep -q "^sleep" "$T/llamadas"; then mal "si falla $verbo sigue esperando"; else ok "si falla $verbo no espera"; fi
done
correr env UDID=
codigo=$?
if [ "$codigo" -eq 0 ] && [ ! -s "$T/llamadas" ]; then ok "sin UDID no llama a nada y sale 0"
else mal "sin UDID: sale $codigo o llama a algo"; fi
: > "$T/llamadas"
LLAMADAS="$T/llamadas" XCRUN="$T/xcrun" DORMIR="$T/dormir" APP="$T/no-existe.app" UDID=ABC \
  bash "$SCRIPT" > "$T/salida" 2>&1
codigo=$?
if [ "$codigo" -eq 0 ] && ! grep -q "install" "$T/llamadas"; then ok "sin .app arranca pero no instala"
else mal "sin .app: sale $codigo o intenta instalar"; fi

echo
if [ "$fallos" -eq 0 ]; then echo "ci-calentar-simulador: todo en verde"; exit 0; fi
echo "ci-calentar-simulador: $fallos fallo(s)"; exit 1
