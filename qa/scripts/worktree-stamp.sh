#!/bin/bash
# Huella del estado del ÁRBOL DE TRABAJO respecto de HEAD.
#
# Para qué: el flag `.claude/sessions/tests-passed` era un fichero que existía o no.
# Eso convertía el gate del hook `PreToolUse` en un sello de goma — bastaba con haberlo
# creado alguna vez, aunque después se cambiara el código. Ahora el flag GUARDA esta
# huella y el hook la recalcula: si el árbol cambió desde que pasaron los tests, bloquea.
#
# INVARIANTE, y es lo único que hay que entender para no romperlo: la huella describe
# **lo que hay en disco**, nunca cómo está repartido entre el índice y el árbol. Mover un
# fichero al índice con `git add` no cambia lo que se probó, así que no puede cambiar la
# huella. Solo la cambian el contenido, los permisos, las altas y las bajas.
#
# Por eso NO se usa el texto de `git diff HEAD`: un fichero NUEVO aporta al diff solo
# cuando está staged, y mientras es untracked aporta por la otra rama. Las dos formas
# describen el mismo disco pero producen textos distintos ⇒ `git add` de un fichero nuevo
# cambiaba la huella y bloqueaba el commit con «el codigo cambio desde que paso /gate»,
# que era falso. Costó un gate re-corrido y un rato de diagnóstico el 2026-09-01; la
# cabecera anterior llegó a PROMETER lo contrario de lo que hacía. Banco de pruebas de
# los 7 casos (incluido ése): `qa/scripts/worktree-stamp-test.sh`.
#
# Composición: HEAD + una línea por fichero que difiere de HEAD o está sin trackear,
# con la MISMA forma para todos —ruta, permisos y sha256 del contenido en disco—, o
# `ausente` si ya no está. Ordenado, para que no dependa del orden en que git los liste.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 1

{
    git rev-parse HEAD 2>/dev/null

    {
        # Difieren de HEAD: modificados, añadidos, borrados y los dos lados de un rename.
        # Cubre staged y unstaged a la vez.
        git diff HEAD --name-only -z 2>/dev/null
        # Sin trackear. Excluye lo ignorado por .gitignore.
        git ls-files --others --exclude-standard -z 2>/dev/null
    } | sort -z -u | while IFS= read -r -d '' f; do
        if [ -e "$f" ]; then
            printf '%s\t%s\t%s\n' \
                "$f" \
                "$(stat -f '%Lp' "$f" 2>/dev/null)" \
                "$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)"
        else
            printf '%s\tausente\n' "$f"
        fi
    done
} | shasum -a 256 | cut -d' ' -f1

# Salida explícita: con `pipefail`, un `[ -e ]` falso en la última iteración del bucle
# hacía salir con 1 pese a emitir la huella correcta, y cualquier llamador que encadenara
# con `&&` lo leía como fallo. Cazado en la primera corrida real de /gate.
exit 0
