#!/usr/bin/env bash
# Banco de qa/scripts/ci-reintentar-rojos.sh. No compila ni toca ningún simulador: sustituye
# `xcodebuild` y `xcrun` por falsos que leen el escenario de un directorio temporal.
#
#   bash qa/scripts/ci-reintentar-rojos-test.sh
#
# Cada escenario da, por vuelta k, un exit (`exit.k`) y el árbol de casos que el `.xcresult`
# de esa vuelta devolvería (`casos.k`: líneas «Resultado<TAB>Suite/test()»; `ILEGIBLE` si
# xcresulttool debe fallar, `RARO` si debe devolver un JSON sin `testNodes`).
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-reintentar-rojos.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# xcodebuild falso: apunta los argumentos de cada llamada, crea el bundle en -resultBundlePath
# con el JSON que toca y sale con el exit de esa vuelta.
cat > "$T/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
D="$ESCENARIO"
n=$(cat "$D/n" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$D/n"
printf '%s\n' "$@" > "$D/args.$n"
rb=""; prev=""
for a in "$@"; do [ "$prev" = "-resultBundlePath" ] && rb="$a"; prev="$a"; done
[ -n "$rb" ] || { echo "falso: sin -resultBundlePath" >&2; exit 9; }
[ -e "$rb" ] && { echo "falso: el bundle ya existe" >&2; exit 9; }
mkdir -p "$rb"
c="$D/casos.$n"
if [ -f "$c" ] && [ "$(cat "$c")" = "ILEGIBLE" ]; then :
elif [ -f "$c" ] && [ "$(cat "$c")" = "RARO" ]; then echo '{"devices":[]}' > "$rb/tests.json"
else
  python3 -I - "$c" > "$rb/tests.json" <<'PY'
import json, sys, os
casos = []
p = sys.argv[1]
if os.path.exists(p):
    for l in open(p):
        l = l.rstrip("\n")
        if not l: continue
        res, ident = l.split("\t", 1)
        casos.append({"nodeType": "Test Case", "name": ident.split("/")[-1],
                      "nodeIdentifier": ident, "result": res, "children": []})
print(json.dumps({"testNodes": [{"nodeType": "Test Plan", "name": "Yala Dev", "children": [
    {"nodeType": "Unit test bundle", "name": "YalaTests", "children": casos}]}]}))
PY
fi
exit "$(cat "$D/exit.$n" 2>/dev/null || echo 0)"
FAKE
# xcrun falso: solo sabe `xcresulttool get test-results tests --path P --compact`.
cat > "$T/xcrun" <<'FAKE'
#!/usr/bin/env bash
[ "$1 $2 $3 $4 $5" = "xcresulttool get test-results tests --path" ] || { echo "xcrun falso: $*" >&2; exit 9; }
[ -f "$6/tests.json" ] || { echo "xcresulttool falso: ilegible" >&2; exit 1; }
cat "$6/tests.json"
FAKE
chmod +x "$T/xcodebuild" "$T/xcrun"

fallos=0
TAB=$'\t'
# caso <nombre> <exit esperado> <llamadas esperadas> <rojos esperados> <rescatados esperados> [-- opciones extra]
# Antes de llamarlo, prepara el escenario con `vuelta <k> <exit> <casos...>`.
prepara() { E="$T/$1"; mkdir -p "$E"; }
vuelta() { local k="$1" ex="$2"; shift 2; echo "$ex" > "$E/exit.$k"; printf '%s\n' "$@" > "$E/casos.$k"; }
caso() {
  local nombre="$1" ex_esp="$2" llam_esp="$3" rojos_esp="$4" resc_esp="$5"; shift 5
  : > "$E/out"
  ESCENARIO="$E" XCODEBUILD="$T/xcodebuild" XCRUN="$T/xcrun" GITHUB_OUTPUT="$E/out" \
    bash "$SCRIPT" --dir "$E/rb" "$@" -- test-without-building -scheme "Yala Dev" -parallel-testing-enabled NO \
      --- -only-testing:YalaTests -skip-testing:YalaTests/Ctx > "$E/log" 2>&1
  local ex=$? llam rojos resc
  llam=$(cat "$E/n" 2>/dev/null || echo 0)
  # En `$GITHUB_OUTPUT` gana la última línea de cada clave: el script publica dos veces.
  rojos="$(sed -n 's/^rojos=//p' "$E/out" | tail -n 1)"; resc="$(sed -n 's/^rescatados=//p' "$E/out" | tail -n 1)"
  if [ "$ex" = "$ex_esp" ] && [ "$llam" = "$llam_esp" ] && [ "$rojos" = "$rojos_esp" ] && [ "$resc" = "$resc_esp" ]; then
    echo "ok   $nombre"
  else
    echo "FALLO $nombre: exit $ex (esp $ex_esp), llamadas $llam (esp $llam_esp)"
    # Llaves obligatorias: bash 3.2 lee los bytes de «»" pegados a un $nombre como parte del nombre.
    echo "      rojos «${rojos}» (esp «${rojos_esp}»), rescatados «${resc}» (esp «${resc_esp}»)"
    sed 's/^/      | /' "$E/log" | tail -15
    fallos=$((fallos+1))
  fi
}
args_de() { cat "$T/$1/args.$2"; }
afirma() { # afirma <descripción> <comando...>
  local d="$1"; shift
  if "$@"; then echo "ok   $d"; else echo "FALLO $d"; fallos=$((fallos+1)); fi
}

# 1. Verde a la primera: una sola vuelta, nada que repetir.
prepara verde
vuelta 1 0 "Passed${TAB}A/a()" "Passed${TAB}A/b()"
caso verde 0 1 "" ""
afirma "verde: la primera vuelta lleva la selección y no -retry" \
  bash -c 'grep -qx -- "-only-testing:YalaTests" "$0" && grep -qx -- "-skip-testing:YalaTests/Ctx" "$0" && ! grep -q -- "-retry-tests-on-failure" "$0"' "$T/verde/args.1"
afirma "verde: cuenta los casos de la primera vuelta" grep -qx "tests_primera=2" "$T/verde/out"

# 2. El flaky: rojo en la primera, verde al repetirlo solo.
prepara flaky
vuelta 1 65 "Passed${TAB}A/a()" "Failed${TAB}Spike/eje4b()" "Passed${TAB}B/c()"
vuelta 2 0 "Passed${TAB}Spike/eje4b()"
caso flaky 0 2 "" "YalaTests/Spike/eje4b()"
afirma "flaky: la repetición pide SOLO el rojo, sin la selección de la primera" \
  bash -c 'grep -qx -- "-only-testing:YalaTests/Spike/eje4b()" "$0" && ! grep -qx -- "-only-testing:YalaTests" "$0" && ! grep -q -- "-skip-testing" "$0" && [ "$(grep -c -- "-only-testing" "$0")" = 1 ]' "$T/flaky/args.2"
afirma "flaky: la repetición conserva los argumentos comunes" \
  bash -c 'grep -qx -- "-parallel-testing-enabled" "$0" && grep -qx -- "test-without-building" "$0"' "$T/flaky/args.2"
afirma "flaky: lo anota como rescatado" grep -q "::warning title=Rescatado al repetirlo::YalaTests/Spike/eje4b()" "$T/flaky/log"

# 3. Rojo determinista: tres vueltas, y la tercera sigue siendo solo ese test.
prepara determinista
vuelta 1 65 "Passed${TAB}A/a()" "Failed${TAB}Copy/idioma()"
vuelta 2 65 "Failed${TAB}Copy/idioma()"
vuelta 3 65 "Failed${TAB}Copy/idioma()"
caso determinista 1 3 "YalaTests/Copy/idioma()" ""
afirma "determinista: el error nombra el test" grep -q "::error title=Test en rojo::YalaTests/Copy/idioma()" "$T/determinista/log"

# 4. Dos rojos: uno se rescata en la 2.ª y la 3.ª repite solo el otro.
prepara dos
vuelta 1 65 "Failed${TAB}A/x()" "Failed${TAB}B/y(n:)" "Passed${TAB}C/z()"
vuelta 2 65 "Passed${TAB}A/x()" "Failed${TAB}B/y(n:)"
vuelta 3 65 "Failed${TAB}B/y(n:)"
caso dos 1 3 "YalaTests/B/y(n:)" "YalaTests/A/x()"
afirma "dos: los rojos de la 1.ª vuelta se publican ANTES de repetir (por si se corta)" \
  bash -c '[ "$(sed -n "s/^rojos=//p" "$0" | head -n 1)" = "YalaTests/A/x(); YalaTests/B/y(n:)" ]' "$T/dos/out"
afirma "dos: la 3.ª vuelta repite solo el que seguía rojo" \
  bash -c '[ "$(grep -c -- "-only-testing" "$0")" = 1 ] && grep -qx -- "-only-testing:YalaTests/B/y(n:)" "$0"' "$T/dos/args.3"

# 5. La repetición sale exit 0 pero NO ejecutó el test (medido: un -only-testing que no casa da
#    exit 0 con cero tests). Eso no es un rescate.
prepara fantasma
vuelta 1 65 "Failed${TAB}A/x()"
vuelta 2 0
vuelta 3 0
caso fantasma 1 3 "YalaTests/A/x()" ""

# 6. Caída segura: el .xcresult de la primera vuelta no se puede leer → sin reintento.
prepara ilegible
vuelta 1 65 "ILEGIBLE"
caso ilegible 65 1 "(sin identificar: xcodebuild salió con 65 y el .xcresult no nombra ningún caso rojo — mira el log)" ""

# 7. Caída segura: formato inesperado (sin testNodes) → sin reintento.
prepara raro
vuelta 1 65 "RARO"
caso raro 65 1 "(sin identificar: xcodebuild salió con 65 y el .xcresult no nombra ningún caso rojo — mira el log)" ""

# 8. Caída segura: exit ≠ 0 sin ningún caso rojo (fallo de lanzamiento) → sin reintento.
prepara sin_casos_rojos
vuelta 1 70 "Passed${TAB}A/a()"
caso sin_casos_rojos 70 1 "(sin identificar: xcodebuild salió con 70 y el .xcresult no nombra ningún caso rojo — mira el log)" ""

# 9. Caída segura: más rojos que el tope → sin reintento, pero nombrados.
prepara demasiados
vuelta 1 65 "Failed${TAB}A/a()" "Failed${TAB}A/b()" "Failed${TAB}A/c()"
caso demasiados 65 1 "YalaTests/A/a(); YalaTests/A/b(); YalaTests/A/c() … (3 en total)" "" --max-rojos 2

# 10. La repetición no se puede leer: lo pendiente se queda en rojo y no se sigue.
prepara repeticion_ilegible
vuelta 1 65 "Failed${TAB}A/x()"
vuelta 2 0 "ILEGIBLE"
caso repeticion_ilegible 1 2 "YalaTests/A/x()" ""

# 11. --vueltas 1: un rojo es un rojo, sin repetir.
prepara una_vuelta
vuelta 1 65 "Failed${TAB}A/x()"
caso una_vuelta 1 1 "YalaTests/A/x()" "" --vueltas 1

# 12. Un --dir reusado (otra corrida en la misma máquina) trae los bundles de antes, y xcodebuild
#     se niega a escribir sobre un -resultBundlePath que ya existe: el script los aparta él.
prepara reusado
mkdir -p "$E/rb/vuelta-1.xcresult" "$E/rb/vuelta-2.xcresult"
vuelta 1 65 "Failed${TAB}A/x()"
vuelta 2 0 "Passed${TAB}A/x()"
caso reusado 0 2 "" "YalaTests/A/x()"

# 13. Llamada mal formada.
prepara mal
caso mal 2 0 "" "" --vueltas x

if [ "$fallos" -eq 0 ]; then
  echo "── ci-reintentar-rojos: todos los casos en verde."
else
  echo "── ci-reintentar-rojos: $fallos caso(s) en ROJO."
  exit 1
fi
