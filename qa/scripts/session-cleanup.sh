#!/bin/bash
# Limpieza de lo EFÍMERO que deja una sesión de desarrollo iOS.
#
# SEGURIDAD — el diseño entero gira alrededor de esto:
#   * Por defecto es DRY-RUN: enumera y mide, no borra nada.
#   * Solo borra con --apply Y con al menos un destino explícito.
#   * Cada ruta pasa por `es_ruta_segura` antes de borrarse: si no encaja con uno de los
#     prefijos permitidos, se aborta la operación entera. No hay comodines sueltos.
#   * NUNCA toca el árbol de trabajo del repo, el vault de Obsidian ni ~/Secrets.
#
# Uso:
#   bash qa/scripts/session-cleanup.sh                      # dry-run de todo
#   bash qa/scripts/session-cleanup.sh --apply --clones --sims-off
#   bash qa/scripts/session-cleanup.sh --apply --derived --scratch --worktrees
#
# Destinos:
#   --clones     Clones de simulador huérfanos ("Clone N of ...") que deja una corrida cortada
#   --sims-off   Apagar todos los simuladores arrancados (no borra datos)
#   --derived    DerivedData de Xcode y el paralelo de XcodeBuildMCP
#   --scratch    Scratchpads de sesiones Claude TERMINADAS (nunca el de la sesión actual)
#   --worktrees  Worktrees de git abandonados bajo .claude/worktrees
#   --all        Todos los anteriores menos --sims-off

set -uo pipefail

APLICAR=0; T_CLONES=0; T_SIMSOFF=0; T_DERIVED=0; T_SCRATCH=0; T_WORKTREES=0
SESION_ACTUAL="${CLAUDE_SESSION_ID:-}"

for arg in "$@"; do
    case "$arg" in
        --apply) APLICAR=1 ;;
        --clones) T_CLONES=1 ;;
        --sims-off) T_SIMSOFF=1 ;;
        --derived) T_DERIVED=1 ;;
        --scratch) T_SCRATCH=1 ;;
        --worktrees) T_WORKTREES=1 ;;
        --all) T_CLONES=1; T_DERIVED=1; T_SCRATCH=1; T_WORKTREES=1 ;;
        *) echo "Argumento desconocido: $arg" >&2; exit 2 ;;
    esac
done

# Sin destinos = dry-run de todo.
if [ $((T_CLONES+T_SIMSOFF+T_DERIVED+T_SCRATCH+T_WORKTREES)) -eq 0 ]; then
    T_CLONES=1; T_DERIVED=1; T_SCRATCH=1; T_WORKTREES=1
    [ $APLICAR -eq 1 ] && { echo "ERROR: --apply exige al menos un destino explícito." >&2; exit 2; }
fi

libre_gb() { df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}'; }
ANTES=$(libre_gb)

# Un borrado solo procede si la ruta cae dentro de uno de estos prefijos.
es_ruta_segura() {
    case "$1" in
        "$HOME"/Library/Developer/Xcode/DerivedData/*) return 0 ;;
        "$HOME"/Library/Developer/XcodeBuildMCP/*)     return 0 ;;
        /private/tmp/claude-501/*)                     return 0 ;;
        *) return 1 ;;
    esac
}

borrar() { # borrar <ruta> <etiqueta>
    local ruta="$1" etiqueta="$2"
    if ! es_ruta_segura "$ruta"; then
        echo "  ABORTADO: ruta fuera de la lista segura → $ruta" >&2
        return 1
    fi
    [ -e "$ruta" ] || return 0
    if [ $APLICAR -eq 1 ]; then
        rm -rf -- "$ruta" && echo "  borrado: $etiqueta"
    else
        echo "  [dry-run] borraría: $etiqueta ($(du -sh "$ruta" 2>/dev/null | cut -f1))"
    fi
}

echo "## Limpieza de sesión$([ $APLICAR -eq 0 ] && echo ' — DRY RUN (no se borra nada)')"
echo "Libre antes: ${ANTES:-?} GB"
echo

if [ $T_CLONES -eq 1 ]; then
    echo "### Clones de simulador huérfanos"
    encontrados=0
    while read -r udid; do
        [ -n "$udid" ] || continue
        encontrados=$((encontrados+1))
        if [ $APLICAR -eq 1 ]; then
            xcrun simctl delete "$udid" >/dev/null 2>&1 && echo "  borrado clon $udid"
        else
            echo "  [dry-run] borraría clon $udid"
        fi
    done < <(xcrun simctl list devices 2>/dev/null | grep "Clone " | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}')
    [ $encontrados -eq 0 ] && echo "  (ninguno)"
    echo
fi

if [ $T_SIMSOFF -eq 1 ]; then
    echo "### Apagar simuladores"
    n=$(xcrun simctl list devices booted 2>/dev/null | grep -c "Booted" || true)
    if [ "${n:-0}" -gt 0 ]; then
        [ $APLICAR -eq 1 ] && { xcrun simctl shutdown all >/dev/null 2>&1; echo "  apagados: $n"; } \
                           || echo "  [dry-run] apagaría: $n"
    else
        echo "  (ninguno arrancado)"
    fi
    echo
fi

if [ $T_DERIVED -eq 1 ]; then
    echo "### DerivedData"
    for base in "$HOME/Library/Developer/Xcode/DerivedData" "$HOME/Library/Developer/XcodeBuildMCP"; do
        [ -d "$base" ] || continue
        for d in "$base"/*/; do
            [ -d "$d" ] || continue
            borrar "${d%/}" "$(basename "$base")/$(basename "$d")"
        done
    done
    echo
fi

if [ $T_SCRATCH -eq 1 ]; then
    echo "### Scratchpads de sesiones terminadas"
    # DOS protecciones, porque suele haber sesiones concurrentes sobre el mismo repo:
    #   1. La sesión actual, por CLAUDE_SESSION_ID cuando está disponible.
    #   2. Cualquier scratchpad tocado en los últimos MINUTOS_VIVA minutos — una sesión
    #      viva escribe constantemente, así que la mtime es la señal fiable incluso
    #      cuando no hay variable de entorno. Sin esto, limpiar podría tumbar el trabajo
    #      de otra ventana abierta en paralelo.
    MINUTOS_VIVA=${YALA_SCRATCH_MIN_VIVA:-90}
    hallados=0
    for d in /private/tmp/claude-501/*/*/; do
        [ -d "$d" ] || continue
        sid=$(basename "${d%/}")
        if [ -n "$SESION_ACTUAL" ] && [ "$sid" = "$SESION_ACTUAL" ]; then
            echo "  (conservado: sesión actual ${sid:0:8})"; continue
        fi
        # OJO: hay que mirar CUALQUIER fichero de dentro, no la mtime del directorio.
        # La mtime del directorio solo cambia si se añaden/quitan entradas directas, así
        # que una sesión escribiendo en scratchpad/ dejaba el directorio "viejo" y se
        # marcaba como borrable. Cazado en el primer dry-run.
        if [ -n "$(find "$d" -type f -mmin -"$MINUTOS_VIVA" -print -quit 2>/dev/null)" ]; then
            echo "  (conservado: activo hace <${MINUTOS_VIVA} min — ${sid:0:8})"; continue
        fi
        hallados=$((hallados+1))
        borrar "${d%/}" "scratchpad ${sid:0:8}"
    done
    [ $hallados -eq 0 ] && echo "  (ninguno recuperable)"
    echo
fi

if [ $T_WORKTREES -eq 1 ]; then
    echo "### Worktrees abandonados"
    hallados=0
    while read -r ruta resto; do
        case "$ruta" in
            */.claude/worktrees/*) : ;;
            *) continue ;;
        esac
        case "$resto" in
            *"detached HEAD"*) : ;;
            *) echo "  (conservado, tiene rama: $ruta)"; continue ;;
        esac
        hallados=$((hallados+1))
        if [ $APLICAR -eq 1 ]; then
            git worktree remove --force "$ruta" 2>/dev/null && echo "  borrado worktree $(basename "$ruta")" \
                || echo "  NO se pudo borrar $ruta (¿cambios sin guardar?)"
        else
            echo "  [dry-run] borraría worktree $(basename "$ruta") ($(du -sh "$ruta" 2>/dev/null | cut -f1))"
        fi
    done < <(git worktree list 2>/dev/null)
    [ $hallados -eq 0 ] && echo "  (ninguno abandonado)"
    [ $APLICAR -eq 1 ] && git worktree prune 2>/dev/null
    echo
fi

DESPUES=$(libre_gb)
echo "Libre después: ${DESPUES:-?} GB"
if [ $APLICAR -eq 1 ] && [ -n "${ANTES:-}" ] && [ -n "${DESPUES:-}" ]; then
    echo "Recuperado: $((DESPUES - ANTES)) GB"
fi
