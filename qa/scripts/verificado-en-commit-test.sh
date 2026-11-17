#!/usr/bin/env bash
# Banco de qa/scripts/verificado-en-commit.sh y del hook `.githooks/prepare-commit-msg`
# (2026-11-17, propuesta P3 de verificación). Corre en el job `coverage-index`.
#
#   bash qa/scripts/verificado-en-commit-test.sh
#
# Monta un repo de juguete con copias de los scripts y de los dos hooks (`pre-commit` y
# `prepare-commit-msg`), y commitea DE VERDAD: lo que se mira es el mensaje que queda en git.
# No compila ni toca ningún simulador.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fallos=0

# Aislado de la configuración de la máquina: un `core.hooksPath` global o un template cambiarían
# lo que se mide.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig"
: > "$GIT_CONFIG_GLOBAL"

R="$T/repo"
mkdir -p "$R/qa/scripts" "$R/.githooks" "$R/docs" "$R/App"
cp "$AQUI/verificado-en-commit.sh" "$AQUI/worktree-stamp.sh" "$AQUI/precommit-gate.sh" "$R/qa/scripts/"
cp "$RAIZ/.githooks/pre-commit" "$RAIZ/.githooks/prepare-commit-msg" "$R/.githooks/"
chmod +x "$R/.githooks/"*
cd "$R" || exit 1
git init -q -b principal .
git config user.name "Banco"; git config user.email "banco@example.com"
git config core.hooksPath .githooks
printf '.claude/sessions/\n' > .gitignore
echo "a" > App/A.swift; echo "doc" > docs/x.md
git add -A && git commit -q --no-verify -m "base" || { echo "FALLO no pude montar el repo"; exit 1; }

V() { bash qa/scripts/verificado-en-commit.sh "$@"; }
ultimo() { git log -1 --format=%B; }
cuenta() { ultimo | grep -c '^Verificado: '; }
ok() { echo "ok   $1"; }
mal() { echo "FALLO $1"; shift; [ $# -gt 0 ] && printf '      %s\n' "$@"; fallos=$((fallos+1)); }
espera_linea() { # espera_linea <descripción> <línea esperada>
  local l n
  l="$(ultimo | grep '^Verificado: ')"; n="$(cuenta)"
  if [ "$l" = "$2" ] && [ "$n" = 1 ]; then ok "$1"; else mal "$1" "tengo «$l» ($n línea(s)), esperaba «$2»"; fi
}
COMPLETA="Verificado: build 2/2 · unit 14 suites · interfaz 6 clases · índice ✓"

# 1. sellar: huella en la línea 1 y el resumen con formato fijo en la 2.
echo "b" >> App/A.swift
salida="$(V sellar --build 2 --unit 14 --interfaz 6 --indice si)"
if [ "$(sed -n 1p .claude/sessions/tests-passed)" = "$(bash qa/scripts/worktree-stamp.sh)" ] \
   && [ "$(sed -n 2p .claude/sessions/tests-passed)" = "$COMPLETA" ] && [ "$salida" = "$COMPLETA" ]; then
  ok "sellar: huella + resumen"
else mal "sellar: huella + resumen" "$(cat .claude/sessions/tests-passed)"; fi

# 2. El pre-commit sigue leyendo solo la huella: un sello de dos líneas deja commitear .swift.
git add App/A.swift
if bash qa/scripts/precommit-gate.sh >/dev/null; then ok "pre-commit acepta el sello de dos líneas"; else mal "pre-commit acepta el sello de dos líneas"; fi

# 3. Commit real con sello válido: la línea del sello, una sola vez.
git commit -q -m "feat: cambio verificado" && espera_linea "commit con gate: la línea del sello" "$COMPLETA"

# 4. Tras el commit la huella ya no casa (incluye HEAD): solo docs sin resellar → «solo docs».
echo "más" >> docs/x.md; echo "nuevo" > NOTAS.md
git add docs/x.md NOTAS.md
git commit -q -m "docs: nota" && espera_linea "sin sello válido y solo docs" "Verificado: ninguno (solo docs)"

# 5. Sin sello válido y algo que no es documentación → «ninguno».
echo "x" > qa/scripts/otro.sh; git add qa/scripts/otro.sh
git commit -q -m "chore: script" && espera_linea "sin sello válido y no solo docs" "Verificado: ninguno"

# 6. --no-verify salta el pre-commit, pero no la marca: un .swift sin gate queda como «ninguno».
echo "c" >> App/A.swift; git add App/A.swift
if git commit -q -m "fix: sin gate" 2>/dev/null; then mal "el pre-commit bloquea un .swift sin gate"; else ok "el pre-commit bloquea un .swift sin gate"; fi
git commit -q --no-verify -m "fix: sin gate" && espera_linea "--no-verify queda marcado como ninguno" "Verificado: ninguno"

# 7. Una tanda: gate, primer commit, resellar sin tocar el disco → el segundo lleva el mismo resumen.
echo "d" >> App/A.swift; echo "e" > App/B.swift
V sellar --build 2 --unit 1 --interfaz 1 --indice si >/dev/null
UNO="Verificado: build 2/2 · unit 1 suite · interfaz 1 clase · índice ✓"
git add App/A.swift && git commit -q -m "feat: primero" && espera_linea "singular: 1 suite, 1 clase" "$UNO"
salida="$(V resellar)"
git add App/B.swift && git commit -q -m "feat: segundo" && espera_linea "resellar conserva el resumen" "$UNO"
[ "$salida" = "$UNO" ] && ok "resellar enseña el resumen" || mal "resellar enseña el resumen" "$salida"

# 8. Un sello viejo de una línea vale para el pre-commit y dice que no trae resumen.
echo "f" >> App/A.swift
bash qa/scripts/worktree-stamp.sh > .claude/sessions/tests-passed
git add App/A.swift && git commit -q -m "feat: sello viejo" && espera_linea "sello viejo de una línea" "Verificado: gate ✓ (sin resumen)"

# 9. --amend --no-edit sin sello válido respeta la línea que ya había.
git commit -q --amend --no-edit --allow-empty && espera_linea "amend sin gate nuevo respeta la línea" "Verificado: gate ✓ (sin resumen)"

# 10. --amend con un gate nuevo la REEMPLAZA: nunca dos líneas.
V sellar --build 2 --unit 3 --interfaz 0 --indice si >/dev/null
git commit -q --amend --no-edit --allow-empty \
  && espera_linea "amend con gate nuevo reemplaza la línea" "Verificado: build 2/2 · unit 3 suites · interfaz 0 clases · índice ✓"

# 11. Una línea escrita a mano no puede decir más de lo que midió el gate.
echo "g" > docs/y.md; git add docs/y.md
git commit -q -m "docs: algo" -m "Verificado: build 2/2 · todo" && espera_linea "la línea a mano se reemplaza" "Verificado: ninguno (solo docs)"

# 12. Un gate sobre solo docs: manda el sello, no «solo docs».
echo "h" >> docs/y.md
V sellar --build 0 --unit 0 --interfaz 0 --indice si >/dev/null
git add docs/y.md && git commit -q -m "docs: con gate" \
  && espera_linea "gate de solo docs: la línea del sello" "Verificado: build 0/2 · unit 0 suites · interfaz 0 clases · índice ✓"

# 13. Con comentarios y la línea de tijera (git commit -v), la línea va antes de ellos.
M="$T/msg"
printf 'feat: asunto\n\ncuerpo\n\n# Comentario de git\n# ------------------------ >8 ------------------------\ndiff --git a/x b/x\n' > "$M"
V hook "$M" message >/dev/null
lv="$(grep -n '^Verificado: ' "$M" | cut -d: -f1)"; lc="$(grep -n '^# Comentario' "$M" | cut -d: -f1)"
if [ -n "$lv" ] && [ -n "$lc" ] && [ "$lv" -lt "$lc" ] && [ "$(grep -c '^Verificado: ' "$M")" = 1 ]; then
  ok "con comentarios y tijera, la línea va antes"
else mal "con comentarios y tijera, la línea va antes" "$(cat "$M")"; fi

# 14. Merge y squash no se tocan; el hook nunca falla.
printf 'Merge branch x\n' > "$M"; V hook "$M" merge
[ "$(cat "$M")" = "Merge branch x" ] && ok "merge: no toca el mensaje" || mal "merge: no toca el mensaje" "$(cat "$M")"
printf 'squash\n' > "$M"; V hook "$M" squash
[ "$(cat "$M")" = "squash" ] && ok "squash: no toca el mensaje" || mal "squash: no toca el mensaje"
if V hook "$T/no-existe" message && V hook && bash .githooks/prepare-commit-msg "$T/no-existe"; then
  ok "el hook sale 0 aunque no tenga nada que hacer"
else mal "el hook sale 0 aunque no tenga nada que hacer"; fi
if VERIFICADO_STAMP="$T/no-existe.sh" V hook "$M" message; then
  ok "el hook sale 0 aunque la huella falle"
else mal "el hook sale 0 aunque la huella falle"; fi

# 15. sellar mal llamado no escribe nada a medias.
cp .claude/sessions/tests-passed "$T/antes"
for args in "--build 3 --unit 1 --interfaz 1 --indice si" "--build 2 --unit x --interfaz 1 --indice si" \
            "--build 2 --unit 1 --interfaz 1" "--build 2 --unit 1 --interfaz 1 --indice quizas" \
            "--build 2 --unit 1 --interfaz 1 --indice si --revisor 3" \
            "--build 2 --unit 1 --interfaz 1 --indice si --revisor 3 --hallazgos 1 --aceptados 2" \
            "--build 2 --unit 1 --interfaz 1 --indice si --hallazgos 1 --aceptados 0"; do
  # shellcheck disable=SC2086
  V sellar $args 2>/dev/null; ex=$?
  if [ "$ex" = 2 ] && cmp -s .claude/sessions/tests-passed "$T/antes"; then ok "sellar rechaza: $args"; else mal "sellar rechaza: $args" "exit $ex"; fi
done

# 16. Con el revisor con checklist (P4, paso 4 bis del gate): un segmento más, con singular y plural.
REV="$(V sellar --build 2 --unit 14 --interfaz 6 --indice si --revisor 4 --hallazgos 2 --aceptados 1)"
[ "$REV" = "$COMPLETA · revisor 4 ítems, 2 hallazgos, 1 aceptado" ] && ok "sellar con revisor: segmento" \
  || mal "sellar con revisor: segmento" "$REV"
REV="$(V sellar --build 2 --unit 14 --interfaz 6 --indice si --revisor 1 --hallazgos 0 --aceptados 0)"
[ "$REV" = "$COMPLETA · revisor 1 ítem, 0 hallazgos, 0 aceptados" ] && ok "sellar con revisor: singular" \
  || mal "sellar con revisor: singular" "$REV"

if [ "$fallos" -eq 0 ]; then
  echo "── verificado-en-commit: todos los casos en verde."
else
  echo "── verificado-en-commit: $fallos caso(s) en ROJO."
  exit 1
fi
