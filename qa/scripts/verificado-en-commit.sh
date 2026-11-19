#!/usr/bin/env bash
# La línea `Verificado:` de cada commit (2026-11-17, propuesta P3 de verificación).
#
#   bash qa/scripts/verificado-en-commit.sh sellar --build N --unit N --interfaz N --indice si|no \
#        [--revisor N --hallazgos N --aceptados N]
#   bash qa/scripts/verificado-en-commit.sh resellar      # tras un commit de una tanda: nueva huella, mismo resumen
#   bash qa/scripts/verificado-en-commit.sh linea         # la línea que llevaría el commit ahora
#   bash qa/scripts/verificado-en-commit.sh hook <fichero-del-mensaje> [origen] [sha]
#
# POR QUÉ. El sello del `/gate` era un fichero ignorado por git: del 3 al 17-nov, 13 de 572 commits
# de 2.3 decían algo de cómo se probaron, en texto libre. Sin una marca fija no se puede preguntar
# «qué entró sin interfaz» ni «qué entró sin probar».
#
# EL SELLO (`.claude/sessions/tests-passed`). Línea 1: la huella del árbol (`worktree-stamp.sh`),
# que es lo único que lee `precommit-gate.sh`. Línea 2: el resumen, con formato fijo y contable:
#   Verificado: build 2/2 · unit 14 suites · interfaz 6 clases · índice ✓
# y, si corrió el revisor con checklist del paso 4 bis (P4, en observar), un segmento más:
#   … · índice ✓ · revisor 4 ítems, 2 hallazgos, 1 aceptado
# `--revisor` exige `--hallazgos` y `--aceptados` (aceptados ≤ hallazgos). Sin `--revisor`, sin
# segmento: el revisor no aplicó (nada de lógica cara en el diff) o el gate es anterior.
# Un sello viejo de una sola línea sigue valiendo para el pre-commit y da
# `Verificado: gate ✓ (sin resumen)`.
#
# LA LÍNEA DEL COMMIT (`linea`, y `hook` la escribe como trailer):
#   - sello cuya huella casa con el árbol → su resumen;
#   - sin sello válido y todo lo staged es documentación (`docs/`, `tickets/`, `*.md`, `LICENSE*`)
#     → `Verificado: ninguno (solo docs)`;
#   - sin sello válido en cualquier otro caso → `Verificado: ninguno`.
# La huella incluye HEAD, así que tras un commit deja de casar: por eso existe `resellar`, que
# conserva el resumen para el commit siguiente de la misma tanda (solo si el disco no cambió:
# lo demuestra quien resella, como dice la cabecera de `worktree-stamp.sh`).
#
# EL HOOK. `.githooks/prepare-commit-msg` llama a `hook`. Git lo corre también con `--no-verify`,
# que es justo cuando más falta la marca. Reglas:
#   - origen `merge` o `squash`: no toca nada (mensajes que compone git);
#   - origen `commit` (`--amend`, `-c`, `-C`) con una línea ya escrita y sin sello válido: la
#     respeta, porque la huella se movió con HEAD y no sabe nada nuevo;
#   - en lo demás, añade o REEMPLAZA la línea (`git interpret-trailers --if-exists replace`), de
#     modo que nunca hay dos y una escrita a mano no puede decir más de lo que midió el gate.
# Añade, no bloquea: `hook` sale 0 siempre, pase lo que pase.
#
# Banco: `qa/scripts/verificado-en-commit-test.sh` (corre en el job `coverage-index`).
set -uo pipefail

RAIZ="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "verificado-en-commit: fuera de un repo git" >&2; exit 2; }
cd "$RAIZ" || exit 2
SELLO=".claude/sessions/tests-passed"
STAMP="${VERIFICADO_STAMP:-qa/scripts/worktree-stamp.sh}"

uso() {
  echo "uso: $0 sellar --build N --unit N --interfaz N --indice si|no [--revisor N --hallazgos N --aceptados N] | resellar | linea | hook <fichero> [origen] [sha]" >&2
  exit 2
}
entero() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac; return 0; }
plural() { if [ "$1" = 1 ]; then echo "$1 $2"; else echo "$1 $3"; fi; }

huella() { bash "$STAMP" 2>/dev/null; }

# El resumen guardado si la huella casa con el árbol; nada si no hay sello válido.
resumen_valido() {
  [ -f "$SELLO" ] || return 1
  local esperado actual
  esperado="$(head -n 1 "$SELLO")"
  actual="$(huella)"
  [ -n "$actual" ] && [ "$esperado" = "$actual" ] || return 1
  local r
  r="$(sed -n '2p' "$SELLO")"
  case "$r" in
    "Verificado: "*) printf '%s\n' "$r" ;;
    *) echo "Verificado: gate ✓ (sin resumen)" ;;
  esac
}

solo_docs() { # 0 si hay algo staged y TODO es documentación
  local f n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    case "$f" in
      docs/*|tickets/*|*.md|LICENSE*) ;;
      *) return 1 ;;
    esac
  done < <(git diff --cached --name-only --no-renames 2>/dev/null)
  [ "$n" -gt 0 ]
}

linea() {
  resumen_valido && return 0
  if solo_docs; then echo "Verificado: ninguno (solo docs)"; else echo "Verificado: ninguno"; fi
}

case "${1:-}" in
  sellar)
    shift
    build="" unit="" interfaz="" indice="" revisor="" hallazgos="" aceptados=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --build) build="${2:-}"; shift 2 ;;
        --unit) unit="${2:-}"; shift 2 ;;
        --interfaz) interfaz="${2:-}"; shift 2 ;;
        --indice) indice="${2:-}"; shift 2 ;;
        --revisor) revisor="${2:-}"; shift 2 ;;
        --hallazgos) hallazgos="${2:-}"; shift 2 ;;
        --aceptados) aceptados="${2:-}"; shift 2 ;;
        *) uso ;;
      esac
    done
    entero "$build" && entero "$unit" && entero "$interfaz" || uso
    [ "$build" -le 2 ] || uso
    case "$indice" in si) ind="✓" ;; no) ind="✗" ;; *) uso ;; esac
    rev=""
    if [ -n "$revisor$hallazgos$aceptados" ]; then
      entero "$revisor" && entero "$hallazgos" && entero "$aceptados" || uso
      [ "$aceptados" -le "$hallazgos" ] || uso
      rev=" · revisor $(plural "$revisor" ítem ítems), $(plural "$hallazgos" hallazgo hallazgos), $(plural "$aceptados" aceptado aceptados)"
    fi
    h="$(huella)"
    [ -n "$h" ] || { echo "verificado-en-commit: no pude calcular la huella del árbol" >&2; exit 1; }
    mkdir -p "$(dirname "$SELLO")"
    printf '%s\nVerificado: build %s/2 · unit %s · interfaz %s · índice %s%s\n' \
      "$h" "$build" "$(plural "$unit" suite suites)" "$(plural "$interfaz" clase clases)" "$ind" "$rev" > "$SELLO"
    sed -n '2p' "$SELLO"
    ;;
  resellar)
    [ -f "$SELLO" ] || { echo "verificado-en-commit: no hay sello que resellar; corre /gate" >&2; exit 1; }
    r="$(sed -n '2p' "$SELLO")"
    h="$(huella)"
    [ -n "$h" ] || { echo "verificado-en-commit: no pude calcular la huella del árbol" >&2; exit 1; }
    { printf '%s\n' "$h"; case "$r" in "Verificado: "*) printf '%s\n' "$r" ;; esac; } > "$SELLO"
    echo "${r:-Verificado: gate ✓ (sin resumen)}"
    ;;
  linea)
    linea
    ;;
  hook)
    msg="${2:-}"; origen="${3:-}"
    {
      [ -n "$msg" ] && [ -f "$msg" ] || exit 0
      case "$origen" in merge|squash) exit 0 ;; esac
      if [ "$origen" = "commit" ] && ! resumen_valido >/dev/null \
         && grep -q '^Verificado: ' "$msg"; then
        exit 0
      fi
      l="$(linea)"
      git interpret-trailers --in-place --if-exists replace --trailer "$l" "$msg"
    } || true
    exit 0
    ;;
  *) uso ;;
esac
