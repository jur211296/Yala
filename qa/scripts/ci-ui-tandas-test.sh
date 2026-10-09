#!/usr/bin/env bash
# Banco de qa/scripts/ci-ui-tandas.sh. No compila ni toca ningún simulador: lee el árbol real de
# `YalaUITests/` y unos árboles falsos en un directorio temporal.
#
#   bash qa/scripts/ci-ui-tandas-test.sh
#
# Lo que importa que no se rompa sin avisar: que entre todas las tandas corran TODAS las suites, que
# ninguna corra dos veces, y que la última tanda sea el complemento — la red para la suite que el
# descubrimiento no vea.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-ui-tandas.sh"
REAL="$AQUI/../../YalaUITests"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fallos=0
ok()   { echo "  ok  $1"; }
mal()  { echo "  MAL $1"; fallos=$((fallos + 1)); }

# Suites que una persona contaría a mano: toda `class X: XCTestCase` del árbol.
suites_de() { grep -rhoE "class [A-Za-z0-9_]+ *: *XCTestCase" "$1" | sed -E 's/class ([A-Za-z0-9_]+).*/\1/' | sort -u; }

# Comprueba el reparto de un árbol en N tandas. Reconstruye lo que correría cada tanda y exige
# que la unión sea el conjunto entero y que no se pisen.
reparto() {
  local dir="$1" n="$2" etiqueta="$3" k corridas todas
  todas="$(suites_de "$dir")"
  : > "$T/corren"
  : > "$T/explicitas"
  for k in $(seq 1 "$n"); do
    if ! UI_TESTS_DIR="$dir" bash "$SCRIPT" "$k" "$n" > "$T/args.$k" 2>/dev/null; then
      mal "$etiqueta: la tanda $k de $n falla"; return
    fi
    if [ "$k" -lt "$n" ]; then
      grep -q -- '-skip-testing' "$T/args.$k" && mal "$etiqueta: la tanda $k lleva -skip-testing"
      sed -n 's|^-only-testing:YalaUITests/||p' "$T/args.$k" | tee -a "$T/explicitas" >> "$T/corren"
    else
      [ "$(head -1 "$T/args.$k")" = "-only-testing:YalaUITests" ] \
        || mal "$etiqueta: la última tanda no abre con el target entero"
      sed -n 's|^-skip-testing:YalaUITests/||p' "$T/args.$k" | sort > "$T/saltadas"
      # Lo que salta la última tiene que ser EXACTAMENTE lo de las otras: ni más (se perdería
      # una suite) ni menos (correría dos veces).
      if [ "$(sort "$T/explicitas")" = "$(cat "$T/saltadas")" ]; then ok "$etiqueta: la última salta justo lo de las otras"
      else mal "$etiqueta: la última no salta justo lo de las otras"; fi
      comm -23 <(printf '%s\n' "$todas") "$T/saltadas" >> "$T/corren"
    fi
  done
  corridas="$(sort "$T/corren")"
  if [ "$corridas" = "$todas" ]; then ok "$etiqueta: corren las $(grep -c . <<<"$todas") suites, cada una una vez"
  else
    mal "$etiqueta: el reparto no cubre el árbol una vez por suite"
    diff <(printf '%s\n' "$todas") <(printf '%s\n' "$corridas") | sed 's/^/        /' | head -10
  fi
}

echo "Árbol real ($REAL)"
reparto "$REAL" 2 "real en 2"
reparto "$REAL" 3 "real en 3"
n1=$(UI_TESTS_DIR="$REAL" bash "$SCRIPT" 1 2 2>/dev/null | grep -c .)
if [ "$n1" -gt 0 ]; then ok "real: la tanda 1 lleva $n1 suites"; else mal "real: la tanda 1 sale vacía"; fi

echo "Árbol falso"
mkdir -p "$T/a/Flows" "$T/a/Support"
for s in Uno Dos Tres Cuatro Cinco; do
  { echo "import XCTest"; echo "final class ${s}UITests: XCTestCase {"
    for i in $(seq 1 ${#s}); do echo "    func test_$i() {}"; done; echo "}"; } > "$T/a/Flows/${s}UITests.swift"
done
# Dos clases en un fichero: van a la misma tanda.
printf 'import XCTest\nclass ParAUITests: XCTestCase { func test_a() {} }\nclass ParBUITests: XCTestCase { func test_b() {} }\n' > "$T/a/Flows/Par.swift"
# Una base propia: el descubrimiento no ve a su hija y la última tanda la corre igual.
printf 'import XCTest\nclass BaseUITestCase: XCTestCase {}\n' > "$T/a/Support/Base.swift"
printf 'import XCTest\nfinal class HijaUITests: BaseUITestCase { func test_x() {} }\n' > "$T/a/Flows/Hija.swift"
reparto "$T/a" 2 "falso en 2"
reparto "$T/a" 4 "falso en 4"

par=""
for k in 1 2 3; do
  a=$(UI_TESTS_DIR="$T/a" bash "$SCRIPT" "$k" 3 2>/dev/null)
  if [ "$k" -lt 3 ]; then
    if grep -q 'ParAUITests' <<<"$a"; then par="$par$k"; fi
    if grep -q 'ParBUITests' <<<"$a"; then par="$par$k"; fi
  fi
done
case "$par" in 11|22|"") ok "falso: las dos clases de un fichero caen juntas" ;; *) mal "falso: las clases de Par.swift se separan ($par)" ;; esac

hija=""
for k in 1 2 3; do
  if UI_TESTS_DIR="$T/a" bash "$SCRIPT" "$k" 3 2>/dev/null | grep -q 'HijaUITests'; then hija="$hija$k"; fi
done
# Ni en una lista explícita ni saltada por la última: la corre el complemento.
if [ -z "$hija" ] && [ "$(UI_TESTS_DIR="$T/a" bash "$SCRIPT" 3 3 2>/dev/null | head -1)" = "-only-testing:YalaUITests" ]; then
  ok "falso: la hija de una base propia la corre el complemento"
else
  mal "falso: la hija de una base propia aparece en los argumentos ($hija)"
fi

# Equilibrio: la diferencia entre tandas no pasa del grupo más pesado.
pesos=$(for k in 1 2; do UI_TESTS_DIR="$REAL" bash "$SCRIPT" "$k" 2 2>&1 >/dev/null | sed -nE 's/.* ([0-9]+) casos:.*/\1/p'; done | tr '\n' ' ')
# Dos números separados por espacio: el troceo es el buscado.
# shellcheck disable=SC2086
set -- $pesos
max=$(for f in "$REAL"/Flows/*.swift; do grep -cE '^\s*func test' "$f"; done | sort -n | tail -1)
d=$(( $1 > $2 ? $1 - $2 : $2 - $1 ))
if [ "$d" -le "$max" ]; then ok "real: tandas de $1 y $2 casos (diferencia $d ≤ $max)"
else mal "real: tandas descompensadas ($1 y $2 casos, más que el fichero más pesado: $max)"; fi

echo "Entrada que no cuadra"
for malo in "0 2" "3 2" "1 0" "x 2" "1"; do
  # shellcheck disable=SC2086
  if out=$(bash "$SCRIPT" $malo 2>/dev/null); then mal "acepta «${malo}»"
  elif [ -n "$out" ]; then mal "«${malo}» falla pero imprime argumentos"
  else ok "rechaza «${malo}» sin imprimir argumentos"; fi
done
mkdir -p "$T/vacio"
if UI_TESTS_DIR="$T/vacio" bash "$SCRIPT" 1 2 >/dev/null 2>&1; then mal "un árbol sin suites no falla"
else ok "un árbol sin suites falla"; fi
mkdir -p "$T/uno/Flows"
printf 'import XCTest\nfinal class SolaUITests: XCTestCase { func test_a() {} }\n' > "$T/uno/Flows/Sola.swift"
if UI_TESTS_DIR="$T/uno" bash "$SCRIPT" 1 2 >/dev/null 2>&1; then mal "2 tandas para 1 fichero no falla (dejaría una vacía)"
else ok "2 tandas para 1 fichero falla"; fi
if [ "$(UI_TESTS_DIR="$T/uno" bash "$SCRIPT" 1 1 2>/dev/null)" = "-only-testing:YalaUITests" ]; then ok "1 tanda = el target entero"
else mal "1 tanda no es el target entero"; fi

echo
if [ "$fallos" -eq 0 ]; then echo "ci-ui-tandas: todo en verde"; exit 0; fi
echo "ci-ui-tandas: $fallos fallo(s)"; exit 1
