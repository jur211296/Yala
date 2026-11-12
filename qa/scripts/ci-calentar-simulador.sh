#!/usr/bin/env bash
# Arranca el simulador del job `ui` de `.github/workflows/qa.yml` y abre Yala una vez antes de los
# XCUITest. Lo llama el paso «Calentar el simulador», entre el build y la tanda.
#
# Por qué existe (2026-10-29): `ci-simulador.sh` deja el device sin arrancar y lo arrancaba el primer
# test. En iOS 27 la primera corrida tras arrancar un simulador falla de verdad (regla de
# `.claude/rules/testing.md`), y en el runner eso se veía cada noche: el primer caso de la tanda 1
# cayó al menos una vez todas las noches del 23 al 29-oct, el de la tanda 2 cuatro de seis, los dos
# con `Timed out while evaluating UI query` esperando `uitest_ready` (130-290 s por intento).
#
# Qué hace: arranca el device y espera a que termine (`bootstatus -b`), instala la app del build y
# la abre con los argumentos de un XCUITest (`-uitest`, reset, seed `minimal`), le deja
# $CALENTAR_SEGUNDOS para que el primer arranque pague cachés y siembra, y la cierra. No deja datos
# que importen: cada test vuelve a lanzar con `-uitest-reset`.
#
# Nunca falla el job: cada fallo se avisa y se sigue (sale 0). Sin calentar, los tests arrancan el
# simulador ellos mismos, como antes.
#
# Variables (todas con default salvo UDID):
#   UDID              device que deja `ci-simulador.sh`                  (obligatoria)
#   APP               .app a instalar   (.ddp/Build/Products/Debug-Dev-iphonesimulator/Yala.app)
#   BUNDLE_ID         bundle de Yala Dev                    (com.jurgenschmidt.yala.dev)
#   CALENTAR_SEGUNDOS lo que se deja abierta la app                     (60)
#   XCRUN             binario de xcrun; el banco lo sustituye por uno falso
#   DORMIR            binario de sleep; el banco lo sustituye
#
# Banco: qa/scripts/ci-calentar-simulador-test.sh
set -uo pipefail

UDID="${UDID:-}"
APP="${APP:-.ddp/Build/Products/Debug-Dev-iphonesimulator/Yala.app}"
BUNDLE_ID="${BUNDLE_ID:-com.jurgenschmidt.yala.dev}"
CALENTAR_SEGUNDOS="${CALENTAR_SEGUNDOS:-60}"
XCRUN="${XCRUN:-xcrun}"
DORMIR="${DORMIR:-sleep}"

aviso() { echo "::warning title=Calentar el simulador::$1"; }

if [ -z "$UDID" ]; then
  aviso "sin UDID: los tests arrancarán el simulador"
  exit 0
fi

inicio=$(date +%s)
# `bootstatus -b` arranca si hace falta y espera a que el arranque termine: un `boot` a secas vuelve
# antes, con SpringBoard aún subiendo.
if ! "$XCRUN" simctl bootstatus "$UDID" -b; then
  aviso "el simulador ${UDID} no terminó de arrancar"
  exit 0
fi
echo "Simulador arrancado en $(( $(date +%s) - inicio )) s"

if [ ! -d "$APP" ]; then
  aviso "no está ${APP}: arrancado, pero sin abrir la app"
  exit 0
fi
if ! "$XCRUN" simctl install "$UDID" "$APP"; then
  aviso "no se pudo instalar ${APP}: arrancado, pero sin abrir la app"
  exit 0
fi
if ! "$XCRUN" simctl launch "$UDID" "$BUNDLE_ID" \
     -uitest -uitest-reset -uitest-skip-onboarding -uitest-seed minimal; then
  aviso "no se pudo abrir ${BUNDLE_ID}: arrancado, pero sin abrir la app"
  exit 0
fi
"$DORMIR" "$CALENTAR_SEGUNDOS"
"$XCRUN" simctl terminate "$UDID" "$BUNDLE_ID" || true
echo "Simulador caliente en $(( $(date +%s) - inicio )) s"
exit 0
