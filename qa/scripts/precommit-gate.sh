#!/bin/bash
# Gate de pre-commit para archivos Swift. Lo invoca el hook PreToolUse de `git commit`.
#
# Sale 0 = adelante. Sale 1 con mensaje = commit bloqueado.
#
# Comprueba dos cosas:
#   1. Que /gate haya pasado (existe el sello).
#   2. Que el árbol de trabajo NO haya cambiado desde entonces.
#
# La segunda es la que importa: antes el flag era un fichero que existía o no, así que
# bastaba con haber pasado los tests alguna vez — se podía editar código después y
# commitear igual. Ahora el sello es una huella del árbol y aquí se recalcula.
#
# Nota: la huella se toma contra HEAD, así que hacer `git add` entre el gate y el commit
# no la invalida. Solo la invalidan cambios reales en el contenido.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

SELLO=".claude/sessions/tests-passed"

# Sin archivos Swift en staging, este gate no aplica.
git diff --cached --name-only | grep -qE '\.swift$' || exit 0

if [ ! -f "$SELLO" ]; then
    echo "BLOCKED: hay archivos Swift en staging y no consta que haya pasado el gate."
    echo "         Corre /gate antes de commitear."
    exit 1
fi

ESPERADO=$(cat "$SELLO" 2>/dev/null)
ACTUAL=$(bash qa/scripts/worktree-stamp.sh 2>/dev/null)

if [ -z "$ACTUAL" ]; then
    echo "BLOCKED: no se pudo calcular la huella del arbol de trabajo."
    exit 1
fi

if [ "$ESPERADO" != "$ACTUAL" ]; then
    echo "BLOCKED: el codigo cambio desde que paso /gate."
    echo "         El sello guardado no coincide con el arbol actual. Vuelve a correr /gate."
    exit 1
fi

exit 0
