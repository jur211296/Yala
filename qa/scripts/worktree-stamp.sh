#!/bin/bash
# Huella del estado del árbol de trabajo respecto de HEAD.
#
# Para qué: el flag `.claude/sessions/tests-passed` era un fichero que existía o no.
# Eso convertía el gate del hook `PreToolUse` en un sello de goma — bastaba con haberlo
# creado alguna vez, aunque después se cambiara el código. Ahora el flag GUARDA esta
# huella y el hook la recalcula: si el árbol cambió desde que pasaron los tests, bloquea.
#
# Base = `git diff HEAD` (cubre staged y unstaged a la vez, así que hacer `git add`
# entre el gate y el commit NO invalida el sello — solo invalidan los cambios reales)
# más el contenido de los archivos sin trackear.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 1

{
    git rev-parse HEAD 2>/dev/null
    git diff HEAD 2>/dev/null
    # Sin trackear: nombre y contenido. Excluye lo ignorado por .gitignore.
    git ls-files --others --exclude-standard -z 2>/dev/null \
        | while IFS= read -r -d '' f; do
            printf '%s\n' "$f"
            if [ -f "$f" ]; then shasum -a 256 "$f" 2>/dev/null; fi
          done
} | shasum -a 256 | cut -d' ' -f1

# Salida explícita: con `pipefail`, un `[ -f ]` falso en la última iteración del bucle
# hacía salir con 1 pese a emitir la huella correcta, y cualquier llamador que encadenara
# con `&&` lo leía como fallo. Cazado en la primera corrida real de /gate.
exit 0
