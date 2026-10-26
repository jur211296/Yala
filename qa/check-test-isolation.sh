#!/usr/bin/env bash
#
# check-test-isolation.sh — anti-drift guard para el aislamiento de tests.
#
# `makeTestContext()` (YalaTests/TestHelpers.swift) REUSA un ModelContainer por archivo
# (`_testContainersByFile`). El reset entre tests (rollback + wipeAllModels) solo es seguro
# si la suite corre en SERIE. Una suite NO `.serialized` corre sus @Test en paralelo → se
# pisan el store compartido → falsos rojos order-dependent (p.ej. el incidente de
# CategoryDeduplicationServiceTests / LocaleResolutionTests, 2026-07-06).
#
# Este check FALLA si algún archivo que llama `makeTestContext(` no declara `.serialized`.
# Correr en CI junto a los tests.
#
# SOLO CUENTA EL CÓDIGO, NO LOS COMENTARIOS (2026-10-26). Antes buscaba con `grep` en el
# fichero entero: una cabecera que solo NOMBRABA `makeTestContext()` en un comentario tumbó
# `coverage-index` y dejó el PR #634 en cola de auto-merge toda la noche del 26-oct. Ahora se
# quitan los comentarios (`//`, `///`, `/* */`) y se vacían los literales de cadena antes de
# buscar la llamada y `.serialized`, y la definición `func makeTestContext(` no cuenta como
# llamada. Lo de `.serialized` también: uno que solo vive en un comentario no serializa nada.
# Medido al cambiarlo: `TestHelpers.swift` (la define) y `WipeAllModelsCoverageTests.swift` (la
# nombra en el texto de un `#expect`) solo pasaban por un `.serialized` de sus comentarios.
# Banco: `qa/check-test-isolation-test.sh`.
#
#   bash qa/check-test-isolation.sh [DIR]     # DIR = YalaTests por defecto (el banco pasa otro)

set -euo pipefail
cd "$(dirname "$0")/.."
DIR="${1:-YalaTests}"

# Imprime, por cada .swift de DIR, «<0|1 llama>\t<0|1 serialized>\t<ruta>», mirando solo código.
informe="$(python3 -I - "$DIR" <<'PY'
import os, re, sys

def sin_comentarios(src):
    """Quita // y /* */ (anidables, como en Swift) y vacía los literales de cadena, crudos incluidos.

    Las cadenas se vacían (quedan las comillas) porque tampoco son código: el mensaje de un
    `#expect` que nombra `makeTestContext()` no lo llama. Límite asumido: una llamada dentro de
    una interpolación `\\(…)` no se ve; nadie construye un contexto ahí.
    """
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        crudo = re.match(r'(#+)("""|")', src[i:i + 64]) if c == '#' else None
        if crudo:                                         # cadena cruda: #"…"#, #"""…"""#
            fin = crudo.group(2) + crudo.group(1)
            j = src.find(fin, i + crudo.end())
            j = n if j < 0 else j + len(fin)
            out.append('""' + '\n' * src.count('\n', i, j)); i = j
        elif src.startswith('"""', i):                    # cadena multilínea
            j = src.find('"""', i + 3)
            j = n if j < 0 else j + 3
            out.append('""' + '\n' * src.count('\n', i, j)); i = j
        elif c == '"':                                    # cadena de una línea
            j = i + 1
            while j < n and src[j] not in '"\n':
                j += 2 if src[j] == '\\' else 1
            j = min(j + 1, n)
            out.append('""'); i = j
        elif src.startswith('//', i):                     # comentario de línea (también ///)
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif src.startswith('/*', i):                     # comentario de bloque, anidable
            prof, j = 1, i + 2
            while j < n and prof:
                if src.startswith('/*', j): prof += 1; j += 2
                elif src.startswith('*/', j): prof -= 1; j += 2
                else: j += 1
            out.append('\n' * src.count('\n', i, j)); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)

for raiz, _, ficheros in os.walk(sys.argv[1]):
    for f in sorted(ficheros):
        if not f.endswith('.swift'):
            continue
        ruta = os.path.join(raiz, f)
        codigo = sin_comentarios(open(ruta, encoding='utf-8', errors='replace').read())
        # La DEFINICIÓN (`func makeTestContext(`, en TestHelpers.swift) no es una llamada.
        llama = re.search(r'(?<![\w.])(?<!func )makeTestContext\s*\(', codigo) is not None
        serial = re.search(r'\.serialized', codigo) is not None
        print(f"{int(llama)}\t{int(serial)}\t{ruta}")
PY
)"

missing=()
count=0
while IFS=$'\t' read -r llama serial file; do
    [ -n "${file:-}" ] || continue
    [ "$llama" = 1 ] || continue
    count=$((count + 1))
    [ "$serial" = 1 ] || missing+=("$file")
done <<< "$informe"

if [ ${#missing[@]} -ne 0 ]; then
    echo "❌ Aislamiento de tests roto: estos archivos llaman makeTestContext( pero NO son @Suite(.serialized):"
    for f in "${missing[@]}"; do echo "   - $f"; done
    echo ""
    echo "Fix: añade @Suite(.serialized) a la struct de la suite (ver YalaTests/TestHelpers.swift:makeTestContext)."
    exit 1
fi

echo "✅ Aislamiento de tests OK: los $count archivos que usan makeTestContext( son .serialized"
