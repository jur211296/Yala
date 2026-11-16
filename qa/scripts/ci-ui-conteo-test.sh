#!/usr/bin/env bash
# Banco de qa/scripts/ci-ui-conteo.sh. No compila ni toca ningún simulador: sustituye `xcrun` por
# uno falso que devuelve el resumen de `.xcresult` del escenario.
#
#   bash qa/scripts/ci-ui-conteo-test.sh
#
# Lo que importa que no se rompa sin avisar: que una tanda que no ejecutó ningún test NUNCA salga con
# 0 (el verde que mintió del 5 al 7-nov), y que un rojo de test NUNCA salga con 1 (la UI es advisory).
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-ui-conteo.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

cat > "$T/xcrun" <<'FAKE'
#!/usr/bin/env bash
case "$*" in
  "xcresulttool get test-results summary --path "*" --compact")
    [ -f "$ESCENARIO/resumen" ] || { echo "Error: no se puede abrir" >&2; exit 1; }
    cat "$ESCENARIO/resumen" ;;
  *) echo "xcrun falso: llamada inesperada: $*" >&2; exit 9 ;;
esac
FAKE
chmod +x "$T/xcrun"

# El log real de la tanda 1 del run 42383702440 (7-nov), recortado a las líneas que importan.
# Literal a propósito: el `$s18…` es el símbolo de Swift y las comillas tipográficas son las de Xcode.
# shellcheck disable=SC2016,SC1112
LOG_NO_CARGA='YalaUITests-Runner[62594:152482] [loading] Error loading …/YalaUITests.xctest/YalaUITests (224):  dlopen(…): Symbol not found: _$s18AppIntentsServices23RunnerXYZ
  Referenced from: <E67ED66E-2AB7-3576-BE3D-94B99130F87A> /Applications/Xcode_27.1.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks/AppIntentsTesting.framework/AppIntentsTesting
  Expected in:     <B1E617BC-A8CB-35E4-8DCD-BD574E5B56D2> …/iOS 27.2.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/AppIntentsServices.framework/AppIntentsServices)
Testing failed:
	YalaUITests-Runner (62594) encountered an error (Failed to load the test bundle. (Underlying Error: The bundle “YalaUITests” couldn’t be loaded.))
** TEST EXECUTE FAILED **'
LOG_NORMAL="Test Suite 'Selected tests' passed at 2026-11-04 10:00:00.000.
** TEST EXECUTE SUCCEEDED **"
DISP='"devicesAndConfigurations":[{"device":{"osVersion":"27.0","osBuildNumber":"24A335","deviceName":"iPhone 17 Pro"}}]'
resumen() { # pasados fallados esperados omitidos total [testFailures]
  echo "{$DISP,\"passedTests\":$1,\"failedTests\":$2,\"expectedFailures\":$3,\"skippedTests\":$4,\"totalTestCount\":$5,\"testFailures\":[${6:-}],\"result\":\"x\"}"
}

fallos=0
# caso <nombre> <exit esperado> <estado esperado> <ejecutados esperados|-> <log> [resumen|SIN] [texto que debe salir]
caso() {
  local nombre="$1" ex_esp="$2" est_esp="$3" eje_esp="$4" log="$5" res="${6:-SIN}" texto="${7:-}"
  local d="$T/$nombre"; mkdir -p "$d/rb.xcresult"; printf '%s\n' "$log" > "$d/log"; : > "$d/out"
  [ "$res" = SIN ] || printf '%s' "$res" > "$d/resumen"
  ESCENARIO="$d" XCRUN="$T/xcrun" GITHUB_OUTPUT="$d/out" GITHUB_STEP_SUMMARY="$d/resumen-paso" TANDA=7 \
    bash "$SCRIPT" "$d/rb.xcresult" "$d/log" > "$d/salida" 2>&1
  local ex=$? est eje
  est="$(sed -n 's/^estado=//p' "$d/out")"; eje="$(sed -n 's/^ejecutados=//p' "$d/out")"; [ -n "$eje" ] || eje="-"
  local extra=ok
  if [ -n "$texto" ] && ! grep -qF -- "$texto" "$d/salida"; then extra="falta «$texto»"; fi
  if [ "$ex" = "$ex_esp" ] && [ "$est" = "$est_esp" ] && [ "$eje" = "$eje_esp" ] && [ "$extra" = ok ]; then
    echo "ok   $nombre"
  else
    echo "FALLA $nombre: exit $ex/$ex_esp estado $est/$est_esp ejecutados $eje/$eje_esp ($extra)"
    sed 's/^/      /' "$d/salida"; fallos=$((fallos+1))
  fi
}

# 1. Noche normal: todo verde.
caso verde 0 con_tests 42 "$LOG_NORMAL" "$(resumen 42 0 0 0 42)" "Tanda 7: 42 tests ejecutados (42 pasaron, 0 fallaron, 0 omitidos) en iOS 27.0 (24A335)."
# 2. Un rojo de test: sigue advisory, sale con 0.
caso rojo-de-test-sigue-advisory 0 con_tests 40 "$LOG_NORMAL" "$(resumen 38 2 0 1 41)"
# 3. El incidente del 5 al 7-nov: el paquete no carga, el .xcresult da 0 de 0. Rojo, con la causa.
caso incidente-no-carga 1 no_cargo 0 "$LOG_NO_CARGA" "$(resumen 0 0 0 0 0)" "Causa de dyld: Symbol not found"
# 4. Lo mismo sin .xcresult legible: el log basta para saberlo.
caso no-carga-sin-xcresult 1 no_cargo 0 "$LOG_NO_CARGA" SIN "NO CARGÓ"
# 5. El error de carga solo en el .xcresult (log sin la frase): también no_cargo.
caso no-carga-solo-en-xcresult 1 no_cargo 0 "$LOG_NORMAL" \
  "$(resumen 0 0 0 0 0 '{"testName":"YalaUITests-Runner encountered an error","failureText":"Failed to load the test bundle. (Underlying Error: …)"}')"
# 6. Cero tests sin error de carga (selección vacía): rojo.
caso cero-sin-motivo 1 sin_tests 0 "$LOG_NORMAL" "$(resumen 0 0 0 0 0)" "no registra ningún test"
# 7. Todos omitidos: aviso, no rojo.
caso solo-omitidos 0 solo_omitidos 0 "$LOG_NORMAL" "$(resumen 0 0 0 5 5)" "Todos los casos se saltaron"
# 8. Sin .xcresult y sin error de carga (el tope cortó el paso): aviso, no rojo; el aviso ya lo cuenta.
caso ilegible 0 ilegible - "$LOG_NORMAL" SIN "sin conteo"
# 9. JSON roto: igual que ilegible.
caso json-roto 0 ilegible - "$LOG_NORMAL" "esto no es json"
# 10. Si algún test corrió, una frase de carga suelta en el log no lo convierte en no_cargo.
caso corrio-aunque-el-log-diga-carga 0 con_tests 3 "$LOG_NO_CARGA" "$(resumen 3 0 0 0 3)"

echo
if [ "$fallos" -eq 0 ]; then echo "ci-ui-conteo: 10/10 verdes"; else echo "ci-ui-conteo: $fallos en rojo"; exit 1; fi
