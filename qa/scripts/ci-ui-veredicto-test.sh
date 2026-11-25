#!/usr/bin/env bash
# Banco de `ci-ui-veredicto.py` (2026-11-25): cuarentena y reintento de cuelgues en las tandas de UI.
# Corre en el job `coverage-index` (Linux): `xcrun` y `xcodebuild` son de mentira. El `xcrun` falso
# devuelve el `tests.json` que haya dentro del `.xcresult`; el `xcodebuild` falso crea el `.xcresult`
# del reintento con el JSON de `$FALSO_REINTENTO` y apunta sus argumentos en `$T/xcodebuild.args`.
#
#   bash qa/scripts/ci-ui-veredicto-test.sh
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-ui-veredicto.py"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fallos=0

cat > "$T/xcrun" <<'SH'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do [ "$1" = "--path" ] && { cat "$2/tests.json" 2>/dev/null || exit 1; exit 0; }; shift; done
exit 1
SH
cat > "$T/xcodebuild" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$(dirname "$0")/xcodebuild.args"
while [ $# -gt 0 ]; do [ "$1" = "-resultBundlePath" ] && { mkdir -p "$2"; cp "$FALSO_REINTENTO" "$2/tests.json"; }; shift; done
exit 0
SH
chmod +x "$T/xcrun" "$T/xcodebuild"
export XCRUN="$T/xcrun" XCODEBUILD="$T/xcodebuild" HOY=2026-11-25 TANDA=9

# json <fichero> <Resultado:Suite/test ...>: un .xcresult de mentira con esos casos de YalaUITests.
json() {
  local f="$1"; shift
  python3 -I - "$f" "$@" <<'PY'
import json, sys
casos = [{"nodeType": "Test Case", "name": c.split(":")[1], "nodeIdentifier": c.split(":")[1] + "()",
          "result": c.split(":")[0]} for c in sys.argv[2:]]
d = {"testNodes": [{"nodeType": "Test Plan", "name": "Yala Dev", "children": [
     {"nodeType": "UI test bundle", "name": "YalaUITests", "children": casos}]}]}
json.dump(d, open(sys.argv[1], "w"))
PY
}
cuarentena() {
  cat > "$T/cuar.json" <<'JS'
{"_meta": {"modo": "observar", "bloquearDesde": "2026-12-01", "caducidadDias": 14},
 "pruebas": [
  {"prueba": "YalaUITests/Lenta/test_a()", "dueno": "frank", "ticket": "t-lenta", "entrada": "2026-11-20", "motivo": "m"},
  {"prueba": "YalaUITests/Entera", "dueno": "frank", "ticket": "t-entera", "entrada": "2026-11-25", "motivo": "m"}]}
JS
}
cuelga() { echo "Test Case '-[YalaUITests.$1 $2]' exceeded execution time allowance of 10 minutes. The test may have hung" >> "$T/tanda.log"; }

# corre <resultado del paso> → deja $T/out (GITHUB_OUTPUT) y $T/stdout
corre() {
  : > "$T/out"; : > "$T/xcodebuild.args"; rm -rf "$T/dir"
  GITHUB_OUTPUT="$T/out" GITHUB_STEP_SUMMARY="$T/resumen" python3 "$SCRIPT" --resultado "$1" \
    --xcresult "$T/tanda.xcresult" --log "$T/tanda.log" --cuarentena "$T/cuar.json" --dir "$T/dir" \
    -- -scheme "Yala Dev" -destination "id=X" > "$T/stdout" 2>&1
}
val() { sed -n "s/^$1=//p" "$T/out" | tail -1; }
es() { # es <descripción> <obtenido> <esperado>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FALLO $1: «$2» ≠ «$3»"; fallos=$((fallos+1)); fi; }
contiene() { case "$2" in *"$3"*) echo "ok   $1" ;; *) echo "FALLO $1: «$2» no contiene «$3»"; fallos=$((fallos+1)) ;; esac; }
nuevo() { rm -rf "$T/tanda.xcresult"; mkdir -p "$T/tanda.xcresult"; : > "$T/tanda.log"; cuarentena; }

# 1. Un paso verde pasa tal cual, sin leer nada.
nuevo; corre success
es "1 verde pasa" "$(val veredicto)" "success"
es "1 sin reintento" "$(wc -c < "$T/xcodebuild.args" | tr -d ' ')" "0"

# 2. Un rojo en cuarentena (caso exacto) no pinta la tanda y sale en el detalle con dueño y días.
nuevo; json "$T/tanda.xcresult/tests.json" Passed:Otra/test_b Failed:Lenta/test_a; corre failure
es "2 cuarentena deja verde" "$(val veredicto)" "success"
contiene "2 detalle con dueño y días" "$(val detalle)" "en cuarentena: YalaUITests/Lenta/test_a() (dueño frank, ticket t-lenta, 5 días)"

# 3. La suite entera en cuarentena cubre cualquiera de sus casos.
nuevo; json "$T/tanda.xcresult/tests.json" Failed:Entera/test_z; corre failure
es "3 suite entera en cuarentena" "$(val veredicto)" "success"

# 4. Un rojo fuera de la lista sigue rojo, y no se reintenta nada.
nuevo; json "$T/tanda.xcresult/tests.json" Failed:Otra/test_b Failed:Lenta/test_a; corre failure
es "4 rojo fuera sigue rojo" "$(val veredicto)" "failure"
contiene "4 detalle nombra el rojo" "$(val detalle)" "rojos: YalaUITests/Otra/test_b()"
contiene "4 y la cuarentena aparte" "$(val detalle)" "en cuarentena: YalaUITests/Lenta/test_a()"

# 5. Un cuelgue que pasa al repetirlo: verde, y el reintento pide solo ese caso.
nuevo; json "$T/tanda.xcresult/tests.json" Passed:Otra/test_b Failed:Guiado/test_cuenta; cuelga Guiado test_cuenta
json "$T/reintento.json" Passed:Guiado/test_cuenta; export FALSO_REINTENTO="$T/reintento.json"; corre failure
es "5 cuelgue rescatado" "$(val veredicto)" "success"
contiene "5 detalle del rescate" "$(val detalle)" "cuelgue rescatado al repetirlo: YalaUITests/Guiado/test_cuenta()"
contiene "5 reintento solo del caso" "$(cat "$T/xcodebuild.args")" "-only-testing:YalaUITests/Guiado/test_cuenta -resultBundlePath"
contiene "5 reintento con los comunes" "$(cat "$T/xcodebuild.args")" "test-without-building -scheme Yala Dev -destination id=X"

# 6. Un cuelgue que vuelve a fallar sigue rojo.
nuevo; json "$T/tanda.xcresult/tests.json" Failed:Guiado/test_cuenta; cuelga Guiado test_cuenta
json "$T/reintento.json" Failed:Guiado/test_cuenta; corre failure
es "6 cuelgue repetido sigue rojo" "$(val veredicto)" "failure"
contiene "6 detalle sin rescate" "$(val detalle)" "cuelgue sin rescatar: YalaUITests/Guiado/test_cuenta()"

# 7. Un exit 0 del reintento SIN el caso en el .xcresult no rescata (un -only-testing que no casa).
nuevo; json "$T/tanda.xcresult/tests.json" Failed:Guiado/test_cuenta; cuelga Guiado test_cuenta
json "$T/reintento.json"; corre failure
es "7 reintento vacío no rescata" "$(val veredicto)" "failure"

# 8. Cuelgue + otro rojo: no se reintenta (la tanda ya está roja).
nuevo; json "$T/tanda.xcresult/tests.json" Failed:Guiado/test_cuenta Failed:Otra/test_b; cuelga Guiado test_cuenta
json "$T/reintento.json" Passed:Guiado/test_cuenta; corre failure
es "8 con otro rojo, rojo" "$(val veredicto)" "failure"
es "8 sin reintento" "$(wc -c < "$T/xcodebuild.args" | tr -d ' ')" "0"

# 9. Más de 3 cuelgues: es el entorno, no se reintenta.
nuevo; json "$T/tanda.xcresult/tests.json" Failed:A/test_1 Failed:A/test_2 Failed:A/test_3 Failed:A/test_4
for k in 1 2 3 4; do cuelga A test_$k; done; corre failure
es "9 cuatro cuelgues, rojo" "$(val veredicto)" "failure"
es "9 sin reintento" "$(wc -c < "$T/xcodebuild.args" | tr -d ' ')" "0"

# 10. Caída segura: sin .xcresult legible, el rojo queda.
nuevo; rm -rf "$T/tanda.xcresult"; corre failure
es "10 sin xcresult queda rojo" "$(val veredicto)" "failure"

# 11. Rojo sin ningún caso rojo en el .xcresult: queda rojo.
nuevo; json "$T/tanda.xcresult/tests.json" Passed:Otra/test_b; corre failure
es "11 rojo sin casos queda rojo" "$(val veredicto)" "failure"

# 12. Cuarentena ilegible: cuenta como vacía y el rojo queda.
nuevo; echo "no es json" > "$T/cuar.json"; json "$T/tanda.xcresult/tests.json" Failed:Lenta/test_a; corre failure
es "12 cuarentena ilegible no salva" "$(val veredicto)" "failure"

# 13. Otros resultados (skipped, cancelled, vacío) pasan tal cual.
nuevo; corre skipped; es "13 skipped pasa" "$(val veredicto)" "skipped"

# 14. La cuarentena real del árbol admite el formato de UI (el lector ya lo validaba).
nuevo; cuarentena; es "14 lector acepta YalaUITests" \
  "$(bash "$AQUI/ci-reintentar-rojos.sh" --juzgar-cuarentena "$T/cuar.json" -- 'YalaUITests/Lenta/test_a()' | awk -F'\t' '$1=="DENTRO"{print $2}')" \
  "YalaUITests/Lenta/test_a()"

echo
if [ "$fallos" -eq 0 ]; then echo "ci-ui-veredicto-test: todo ok"; exit 0; fi
echo "ci-ui-veredicto-test: $fallos fallo(s)"; exit 1
