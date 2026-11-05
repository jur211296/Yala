#!/bin/bash
# ci-atribucion-commits.sh — pasa el candado anti-atribución por commits YA HECHOS.
#
# **Por qué existe.** `.githooks/commit-msg` solo corre cuando se ESCRIBE un commit. Git no lo
# invoca en `cherry-pick`, `revert` ni `rebase`, y los botones de merge de GitHub (y el
# auto-merge, ADR-054 de casa) crean el commit en el servidor, donde no hay hook. Un trailer,
# el emoji o un `--author` de IA entraban intactos por cualquiera de esas vías (ticket
# `rebase-and-cherry-pick-skip-the-attribution-hook`; Jürgen eligió la opción A el 2026-10-08:
# un check de CI sobre autor y mensaje).
#
# **No copia patrones.** Llama al MISMO hook por cada commit, con su mensaje en un fichero y su
# autor y committer en las variables que lee `git var`. Si el hook se endurece, esto también.
#
# Qué revisa, según dónde corre:
#   · pull_request  → cada commit de `base..head` del PR, y el TÍTULO del PR: es lo que GitHub
#                     escribe en el commit de merge («Merge pull request #N from …» + título) y
#                     en el de squash. El cuerpo del PR no entra en ningún commit con la
#                     configuración del repo (merge: PR_TITLE · squash: COMMIT_MESSAGES).
#   · push          → `before..after` de la rama: la red DESPUÉS del merge, que ve el commit que
#                     creó GitHub y los commits directos del árbol principal a `2.2`.
#   · sin GitHub    → (el `/gate`, que corre este job en local) los commits que aún no están
#                     en ningún remoto: lo que el próximo push subiría, rebases incluidos.
#   · otro evento   → nada que revisar (schedule, workflow_dispatch); sale 0 y lo dice.
#
# Fail-closed: si no puede leer el evento o traer los commits, sale 1. Un verde que no miró
# nada es justo el fallo que vino a quitar.
#
#   bash qa/scripts/ci-atribucion-commits.sh
#
# Exit: 0 = limpio (o nada que revisar) · 1 = algún commit o el título llevan atribución, o no
# se pudo revisar. Banco: `qa/scripts/ci-atribucion-commits-test.sh`.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${ATRIBUCION_HOOK:-$RAIZ/.githooks/commit-msg}"
# El banco apunta esto a su repo de pruebas; por defecto, el árbol del propio script.
REPO="${ATRIBUCION_REPO:-$RAIZ}"
cd "$REPO" || exit 1
[ -f "$HOOK" ] || { echo "::error title=Candado anti-atribución::no encuentro el hook $HOOK"; exit 1; }

CERO="0000000000000000000000000000000000000000"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atribucion.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

evento() { # campo-del-json (ruta con puntos)
    python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1], encoding="utf-8"))
for k in sys.argv[2].split("."):
    d = d.get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$GITHUB_EVENT_PATH" "$1"
}

# Trae los commits que falten. El checkout del CI es superficial (depth 1): se des-superficializa
# SIN árboles ni blobs (`tree:0`), que trae solo los commits — medido el 2026-11-04 sobre este
# repo: 2 s, frente a los 20 s del propio checkout.
traer() {
    local falta=0 c
    for c in "$@"; do git cat-file -e "$c^{commit}" 2>/dev/null || falta=1; done
    if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
        git fetch -q --no-tags --filter=tree:0 --unshallow origin "$@" || return 1
    elif [ "$falta" = 1 ]; then
        git fetch -q --no-tags --filter=tree:0 origin "$@" || return 1
    fi
    for c in "$@"; do git cat-file -e "$c^{commit}" 2>/dev/null || return 1; done
}

malos=0
revisar() { # fichero-de-mensaje  autor  correo  committer  correo-committer  etiqueta
    local salida
    if ! salida=$(GIT_AUTHOR_NAME="$2" GIT_AUTHOR_EMAIL="$3" \
                  GIT_COMMITTER_NAME="$4" GIT_COMMITTER_EMAIL="$5" \
                  bash "$HOOK" "$1" 2>&1); then
        malos=$((malos + 1))
        local motivo
        motivo=$(printf '%s\n' "$salida" | sed -n 's/^COMMIT RECHAZADO — //p' | head -1)
        echo "::error title=Candado anti-atribución::$6 — ${motivo:-el hook lo rechazó}"
    fi
}

revisar_commits() { # rev-list args...
    local lista n=0 c
    lista=$(git rev-list "$@") || { echo "::error title=Candado anti-atribución::no pude listar los commits ($*)"; exit 1; }
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        n=$((n + 1))
        git log -1 --format=%B "$c" > "$TMP/msg"
        revisar "$TMP/msg" \
            "$(git log -1 --format=%an "$c")" "$(git log -1 --format=%ae "$c")" \
            "$(git log -1 --format=%cn "$c")" "$(git log -1 --format=%ce "$c")" \
            "commit ${c:0:9} «$(git log -1 --format=%s "$c")»"
    done <<< "$lista"
    echo "Commits revisados: $n"
}

case "${GITHUB_EVENT_NAME:-}" in
    pull_request)
        base=$(evento pull_request.base.sha); head=$(evento pull_request.head.sha)
        num=$(evento pull_request.number); rama=$(evento pull_request.head.label)
        titulo=$(evento pull_request.title)
        [ -n "$base" ] && [ -n "$head" ] || { echo "::error title=Candado anti-atribución::el evento del PR no trae base y head"; exit 1; }
        traer "$base" "$head" || { echo "::error title=Candado anti-atribución::no pude traer los commits del PR"; exit 1; }
        revisar_commits "$base..$head"
        # Lo que escribirá GitHub al mergear. El committer de ese commit es GitHub.
        printf 'Merge pull request #%s from %s\n\n%s\n' "$num" "$rama" "$titulo" > "$TMP/titulo"
        revisar "$TMP/titulo" "Merge" "merge@github.invalid" "GitHub" "noreply@github.com" "título del PR «$titulo»"
        ;;
    push)
        antes=$(evento before); despues=$(evento after)
        [ -n "$despues" ] || { echo "::error title=Candado anti-atribución::el evento del push no trae el commit"; exit 1; }
        if [ -z "$antes" ] || [ "$antes" = "$CERO" ]; then
            # Rama nueva: no hay base con la que acotar. Se mira el commit empujado.
            traer "$despues" || { echo "::error title=Candado anti-atribución::no pude traer $despues"; exit 1; }
            echo "Push sin base (rama nueva): solo se revisa el último commit."
            revisar_commits -1 "$despues"
        else
            traer "$antes" "$despues" || { echo "::error title=Candado anti-atribución::no pude traer $antes..$despues"; exit 1; }
            revisar_commits "$antes..$despues"
        fi
        ;;
    "")
        # En local (el `/gate`): lo que todavía no está en ningún remoto.
        revisar_commits HEAD --not --remotes
        ;;
    *)
        echo "::notice title=Candado anti-atribución::evento $GITHUB_EVENT_NAME sin commits nuevos que revisar"
        exit 0
        ;;
esac

if [ "$malos" -gt 0 ]; then
    echo ""
    echo "Hay $malos con atribución. Los commits del PR se reescriben (rebase -i + reword, o un"
    echo "--author nuevo) y se vuelve a subir; el título del PR se edita en GitHub."
    exit 1
fi
echo "Sin atribución."
exit 0
