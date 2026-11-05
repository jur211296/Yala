#!/bin/bash
# Banco de pruebas de `suites-de-fichero.py`.
#
#   bash qa/scripts/suites-de-fichero-test.sh
#
# **Por qué existe.** El ayudante decide qué suites pide el `/gate` y `/l10n-check`. Si se
# equivoca, no da error: deja una suite sin correr y el conteo cuadra con lo pedido. Cada caso
# es un fichero Swift de mentira con la salida exacta que se espera; el último caso es el árbol
# real (`LocalizationParityTests.swift`, el que motivó el script).
#
# No compila nada ni toca el simulador: corre en Linux, en el job `coverage-index`.
#
# Exit: 0 = todos los casos pasan · 1 = alguno falla
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PY="$RAIZ/qa/scripts/suites-de-fichero.py"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/suites-de-fichero-test.XXXXXX")" || { echo "no se pudo crear el temporal" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

fallos=0
n=0

# caso <nombre> <exit esperado> <salida esperada (líneas con \n)> — el fichero va por stdin.
caso() {
  local nombre="$1" exit_esperado="$2" esperada="$3"
  n=$((n + 1))
  local f="$TMP/caso$n.swift"
  cat > "$f"
  local salida rc
  salida="$(python3 -I "$PY" "$f" 2>/dev/null)"; rc=$?
  if [ "$rc" = "$exit_esperado" ] && [ "$salida" = "$(printf '%b' "$esperada")" ]; then
    echo "  ✓ ${n}. ${nombre}"
  else
    echo "  ✗ ${n}. ${nombre} — exit ${rc} (esperado ${exit_esperado}); salida:"
    printf '%s\n' "$salida" | sed 's/^/        /'
    fallos=$((fallos + 1))
  fi
}

echo "── suites-de-fichero"

caso "un struct con @Test, sin @Suite" 0 'Uno' <<'SWIFT'
import Testing
struct Uno {
    @Test func a() {}
}
SWIFT

caso "tres suites en un fichero, ninguna con el nombre del fichero" 0 'A\nB\nC' <<'SWIFT'
struct A {
    @Test func a() {}
}
@Suite("Segunda")
struct B {
    @Test func b() {}
}
@MainActor
struct C {
    @Test(.enabled(if: true)) func c() {}
}
SWIFT

caso "@Suite multilínea y atributos en líneas aparte" 0 'Larga' <<'SWIFT'
@Suite(
    "Con nombre largo",
    .serialized
)
@MainActor
final class Larga {
    @Test func a() {}
}
SWIFT

caso "@Suite sin @Test propio (solo anidadas) cuenta; la anidada no sale" 0 'Fuera' <<'SWIFT'
@Suite struct Fuera {
    struct Dentro {
        @Test func a() {}
    }
}
SWIFT

# Sus @Test viven en una extension de otro fichero: solo el @Suite de arriba dice que es suite.
caso "@Suite en su propia línea, sobre un tipo sin ningún @Test aquí" 0 'Padre' <<'SWIFT'
@Suite("Los casos están en otra extension")
@MainActor
struct Padre {
    let x = 1
}
SWIFT

caso "un helper sin tests no es suite" 0 'Real' <<'SWIFT'
enum Ayudante {
    static func x() -> Int { 1 }
}
struct Real {
    @Test func a() {}
}
SWIFT

caso "@Test en un comentario o en una cadena no fabrica suite" 1 '' <<'SWIFT'
// @Test func no() {}
/* @Test
   @Suite */
struct Nada {
    let s = "@Test func tampoco()"
    let t = """
    @Test
    """
}
SWIFT

caso "una extension cuenta por el tipo que extiende" 0 'Base' <<'SWIFT'
extension Base {
    @Test func masCasos() {}
}
SWIFT

caso "#if DEBUG delante del @Suite" 0 'Debug' <<'SWIFT'
#if DEBUG
@Suite("Solo en debug", .serialized)
struct Debug {
    @Test func a() {}
}
#endif
SWIFT

caso "dos extensiones del mismo tipo salen una vez" 0 'Rep' <<'SWIFT'
extension Rep {
    @Test func a() {}
}
extension Rep {
    @Test func b() {}
}
SWIFT

# El árbol real: el fichero que motivó el script declara tres suites.
n=$((n + 1))
real="$(python3 -I "$PY" "$RAIZ/YalaTests/LocalizationParityTests.swift" 2>/dev/null)"
if [ "$real" = "$(printf 'LocalizationParityTests\nBundleLocaleDriftTests\nStringsdictParityTests')" ]; then
  echo "  ✓ ${n}. árbol real: LocalizationParityTests.swift declara sus tres suites"
else
  echo "  ✗ ${n}. árbol real: LocalizationParityTests.swift dio:"; printf '%s\n' "$real" | sed 's/^/        /'
  fallos=$((fallos + 1))
fi

# --only-testing y el exit 2 de uso.
n=$((n + 1))
printf 'struct X {\n    @Test func a() {}\n}\n' > "$TMP/x.swift"
if [ "$(python3 -I "$PY" --only-testing YalaTests "$TMP/x.swift")" = "-only-testing:YalaTests/X" ] \
   && { python3 -I "$PY" >/dev/null 2>&1; [ $? = 2 ]; } \
   && { python3 -I "$PY" "$TMP/no-existe.swift" >/dev/null 2>&1; [ $? = 2 ]; }; then
  echo "  ✓ ${n}. --only-testing da el filtro; sin ficheros o con uno ilegible, exit 2"
else
  echo "  ✗ ${n}. --only-testing o el exit 2 de uso"
  fallos=$((fallos + 1))
fi

if [ "$fallos" -ne 0 ]; then
  echo "── suites-de-fichero: ${fallos} de ${n} casos en rojo."
  exit 1
fi
echo "── suites-de-fichero: ${n}/${n} casos en verde."
