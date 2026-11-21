#!/usr/bin/env bash
# Banco de `ci-unit-tandas.sh` y `ci-unit-tiempos.py`. No compila ni toca ningún simulador.
#
#   bash qa/scripts/ci-unit-tandas-test.sh
#
# Si el reparto se rompe NO da error: deja suites sin correr en el PR, o las corre dos veces. Por eso:
#   1. Sobre el árbol REAL: cada suite descubierta va a exactamente una tanda, ninguna context-based
#      va a pure-logic, la última corre el target menos lo de las otras, y `contexto` da las 7.
#   2. Con un árbol de juguete: la tabla de tiempos manda el reparto, la tanda 1 carga context-based,
#      una suite nueva sin tiempo entra por sus `@Test`, y una `extension` suma en su suite.
#   3. Entradas malas → exit 2 sin imprimir argumentos.
#   4. `ci-unit-tiempos.py extraer` saca el TIPO (no el nombre visible) y suma los casos;
#      `generar --dir` hace la mediana entre runs.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
TANDAS="$AQUI/ci-unit-tandas.sh"
TIEMPOS="$AQUI/ci-unit-tiempos.py"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fallos=0
ok()  { echo "  ok  $1"; }
mal() { echo "  MAL $1"; fallos=$((fallos + 1)); }

echo "1. árbol real, 3 tandas"
for k in 1 2 3; do bash "$TANDAS" "$k" 3 > "$T/r$k" 2>/dev/null || mal "tanda $k salió en rojo"; done
bash "$TANDAS" contexto > "$T/ctx" 2>/dev/null || mal "contexto salió en rojo"
sed -n 's|^-only-testing:YalaTests/||p' "$T/r1" "$T/r2" | sort > "$T/explicitas"
[ -s "$T/explicitas" ] && ok "las tandas 1 y 2 traen lista" || mal "tandas 1 y 2 vacías"
dups=$(uniq -d < "$T/explicitas")
[ -z "$dups" ] && ok "ninguna suite en dos tandas" || mal "suites repetidas: $dups"
[ "$(grep -c . "$T/ctx")" = 7 ] && ok "contexto da 7 clases" || mal "contexto da $(grep -c . "$T/ctx")"
sed -n 's|^-only-testing:YalaTests/||p' "$T/ctx" | sort > "$T/ctx-nombres"
comm -12 "$T/explicitas" "$T/ctx-nombres" | grep -q . && mal "una context-based cae en pure-logic" || ok "context-based fuera de pure-logic"
head -1 "$T/r3" | grep -qx -- "-only-testing:YalaTests" && ok "la última corre el target" || mal "la última no empieza por el target"
sed -n 's|^-skip-testing:YalaTests/||p' "$T/r3" | sort > "$T/saltadas"
sort -u "$T/explicitas" "$T/ctx-nombres" > "$T/esperadas"
cmp -s "$T/saltadas" "$T/esperadas" && ok "la última salta exactamente lo de las otras y context-based" \
  || mal "la última salta otra cosa: $(diff "$T/saltadas" "$T/esperadas" | head -5)"
bash "$TANDAS" 2 3 > "$T/r2b" 2>/dev/null; cmp -s "$T/r2" "$T/r2b" && ok "determinista" || mal "dos corridas reparten distinto"

echo "2. árbol de juguete"
mkdir -p "$T/arbol/Sub"
cat > "$T/arbol/A.swift" <<'SW'
import Testing
@Suite("Muy lenta") struct LentaTests {
    @Test func a() {}
}
struct RapidaTests {
    @Test func b() {}
    @Test func c() {}
}
SW
cat > "$T/arbol/Sub/B.swift" <<'SW'
import Testing
struct MediaTests { @Test func d() {} }
extension RapidaTests { @Test func e() {} }
struct NuevaTests {
    @Test func f() {}
    @Test func g() {}
    @Test func h() {}
}
// @Test en un comentario no cuenta
struct CurrencyConverterCacheTests { @Test func ctx() {} }
SW
cat > "$T/tabla.json" <<'JSON'
{"_meta": {"por_caso_s": 1, "contexto_s": 5}, "suites": {"LentaTests": 100, "RapidaTests": 2, "MediaTests": 50}}
JSON
reparto() { UNIT_TESTS_DIR="$T/arbol" UNIT_TIEMPOS="$T/tabla.json" bash "$TANDAS" "$@" 2>"$T/err"; }
# 2 tandas, contexto 5: Lenta(100) va a la 2 (la 1 ya carga 5); Media(50), Nueva(3 @Test × 1) y
# Rapida(2) a la 1.
reparto 1 2 > "$T/j1"; reparto 2 2 > "$T/j2"
grep -q "LentaTests" "$T/j1" && mal "la más pesada no debería ir a la tanda 1, que ya carga context-based" \
  || ok "la más pesada va a la tanda sin context-based"
grep -qx -- "-skip-testing:YalaTests/LentaTests" "$T/j2" && mal "la última no debería saltar LentaTests" || ok "y la última la corre"
grep -qx -- "-skip-testing:YalaTests/CurrencyConverterCacheTests" "$T/j2" && ok "la última salta context-based" || mal "la última no salta context-based"
grep -q "CurrencyConverterCacheTests" "$T/j1" && mal "context-based en la tanda 1 de pure-logic" || ok "context-based no va en pure-logic"
grep -qx -- "-only-testing:YalaTests/NuevaTests" "$T/j1" && ok "la suite sin tiempo entra por sus @Test" || mal "NuevaTests: $(cat "$T/j1")"
grep -q "@Test" "$T/err" && ok "resume la tanda" || mal "sin resumen"
# 3 tandas: Lenta→2, Media→3, Nueva y Rapida→1.
reparto 2 3 > "$T/k2"
[ "$(cat "$T/k2")" = "-only-testing:YalaTests/LentaTests" ] && ok "la segunda tanda, solo la lenta" || mal "tanda 2 de 3: $(cat "$T/k2")"
printf '{"_meta": {"por_caso_s": 1, "contexto_s": 1000}, "suites": {"LentaTests": 100, "RapidaTests": 2, "MediaTests": 50}}' > "$T/tabla.json"
reparto 1 2 > "$T/c1"
grep -q "LentaTests" "$T/c1" && mal "con context-based pesado, la tanda 1 no debería llevarse la lenta" || ok "la tanda 1 descuenta context-based"
printf 'no es json' > "$T/tabla.json"
reparto 1 1 > "$T/rota"; rc=$?
[ "$rc" = 0 ] && grep -q "ilegible" "$T/err" && ok "tabla rota: avisa y sigue" || mal "tabla rota: rc $rc, $(cat "$T/err")"

echo "3. entradas malas"
for a in "" "0 3" "4 3" "x 3" "1"; do
  # shellcheck disable=SC2086
  salida=$(bash "$TANDAS" $a 2>/dev/null); rc=$?
  [ "$rc" = 2 ] && [ -z "$salida" ] && ok "«$a» → exit 2 sin argumentos" || mal "«$a» → rc $rc, salida «$salida»"
done
mkdir -p "$T/vacio"
UNIT_TESTS_DIR="$T/vacio" bash "$TANDAS" 1 3 > /dev/null 2>&1; [ $? = 2 ] && ok "sin suites → exit 2" || mal "sin suites no sale 2"

echo "4. ci-unit-tiempos.py"
mkdir -p "$T/bin"
cat > "$T/xcresult.json" <<'JSON'
{"testNodes": [{"nodeType": "Test Plan", "name": "Yala Dev", "children": [{"nodeType": "Unit test bundle", "name": "YalaTests", "children": [
 {"nodeType": "Test Suite", "name": "Nombre visible", "nodeIdentifierURL": "test://com.apple.xcode/Yala/YalaTests/VisibleTests", "children": [
   {"nodeType": "Test Case", "name": "a()", "durationInSeconds": 1.5},
   {"nodeType": "Test Suite", "name": "Anidada", "children": [{"nodeType": "Test Case", "name": "b()", "durationInSeconds": 2.0}]}]},
 {"nodeType": "Test Case", "name": "suelta()", "durationInSeconds": 9}]}]}]}
JSON
printf '#!/bin/bash\ncat "%s"\n' "$T/xcresult.json" > "$T/bin/xcrun"; chmod +x "$T/bin/xcrun"
PATH="$T/bin:$PATH" python3 "$TIEMPOS" extraer falso.xcresult "$T/ext.json" > /dev/null 2>&1 || mal "extraer salió en rojo"
python3 - "$T/ext.json" <<'PY' && ok "extraer: tipo, casos anidados sumados, la suelta fuera" || mal "extraer: $(cat "$T/ext.json")"
import json, sys
s = json.load(open(sys.argv[1]))["suites"]
assert list(s) == ["VisibleTests"], s
assert s["VisibleTests"] == {"s": 3.5, "casos": 2}, s
PY
mkdir -p "$T/runs/11/a" "$T/runs/22/b" "$T/runs/33/c"
echo '{"suites": {"X": {"s": 10, "casos": 0}, "Y": {"s": 1, "casos": 0}}}' > "$T/runs/11/a/t.json"
echo '{"suites": {"X": {"s": 20, "casos": 0}}}' > "$T/runs/22/b/t.json"
echo '{"suites": {"X": {"s": 90, "casos": 0}, "Y": {"s": 3, "casos": 0}}}' > "$T/runs/33/c/t.json"
python3 "$TIEMPOS" generar 11 22 33 --dir "$T/runs" --salida "$T/gen.json" > /dev/null 2>&1 || mal "generar salió en rojo"
python3 - "$T/gen.json" <<'PY' && ok "generar: mediana entre runs y meta" || mal "generar: $(cat "$T/gen.json")"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["suites"] == {"X": 20.0, "Y": 2.0}, d["suites"]
assert d["_meta"]["runs"] == [11, 22, 33] and "por_caso_s" in d["_meta"] and "contexto_s" in d["_meta"], d["_meta"]
PY
python3 "$TIEMPOS" generar 44 --dir "$T/runs" --salida "$T/gen2.json" > /dev/null 2>&1
[ $? = 1 ] && ok "un run sin tiempos → exit 1" || mal "un run sin tiempos no sale 1"
python3 - "$AQUI/../ci-unit-tiempos.json" <<'PY' 2>/dev/null && ok "la tabla del repo se lee" || mal "qa/ci-unit-tiempos.json ilegible o sin suites"
import json, sys
d = json.load(open(sys.argv[1]))
assert isinstance(d["suites"], dict) and all(isinstance(v, (int, float)) for v in d["suites"].values())
assert d["_meta"]["contexto_s"] > 0 and d["_meta"]["por_caso_s"] > 0
PY

echo
if [ "$fallos" -eq 0 ]; then echo "ci-unit-tandas: todo en orden"; else echo "ci-unit-tandas: $fallos caso(s) MAL"; exit 1; fi
