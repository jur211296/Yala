#!/bin/bash
# Banco de pruebas de `worktree-stamp.sh`, el sello que /gate deja y que el hook de
# pre-commit recalcula.
#
# Por qué existe: el 2026-09-01 el sello bloqueaba cualquier commit que introdujera un
# fichero NUEVO, diciendo «el codigo cambio desde que paso /gate» cuando no había
# cambiado nada. La cabecera del script prometía justo lo contrario de lo que hacía. Un
# candado que estorba se acaba quitando, así que su comportamiento se pinea aquí.
#
# Monta un repo git desechable en /tmp: no toca Yala ni el árbol de trabajo.
#
#   bash qa/scripts/worktree-stamp-test.sh            # prueba el script del repo
#   bash qa/scripts/worktree-stamp-test.sh <otro.sh>  # prueba una variante
#
# Sale 0 si todos los casos pasan. Cualquier cambio en el sello debe dejarlo en verde: los
# casos B, E, F, H (copiar ≠ mover) e I son los que impiden "arreglar" el A o el H a base de
# dejar de mirar cosas.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="${1:-$RAIZ/qa/scripts/worktree-stamp.sh}"
STAMP="$(cd "$(dirname "$STAMP")" && pwd)/$(basename "$STAMP")"

[ -f "$STAMP" ] || { echo "no encuentro el sello: $STAMP"; exit 1; }

REPO=$(mktemp -d /tmp/stamp-bench.XXXXXX)
trap 'rm -rf "$REPO"' EXIT
cd "$REPO" || exit 1
git init -q .
git config user.email t@t.t; git config user.name t
mkdir -p qa/scripts
cp "$STAMP" qa/scripts/worktree-stamp.sh
echo "base" > tracked.txt
git add -A >/dev/null; git commit -qm base

s() { bash qa/scripts/worktree-stamp.sh; }

ok=0; ko=0
check() { # descripcion  igual|distinto  a  b
    local desc="$1" modo="$2" a="$3" b="$4"
    if { [ "$modo" = igual ] && [ "$a" = "$b" ]; } || { [ "$modo" = distinto ] && [ "$a" != "$b" ]; }; then
        echo "  ✓ $desc"; ok=$((ok+1)); return
    fi
    echo "  ✘ $desc   (esperado: $modo)"; echo "      a=$a"; echo "      b=$b"; ko=$((ko+1))
}

echo "== A · fichero NUEVO: stagearlo NO cambia la huella  (la regresión de 2026-09-01)"
echo "nuevo" > nuevo.txt
A1=$(s); git add nuevo.txt; A2=$(s)
check "untracked vs staged" igual "$A1" "$A2"

echo "== B · editar ese fichero nuevo SÍ la cambia  (no perder sensibilidad)"
echo "editado" >> nuevo.txt; B1=$(s)
check "contenido distinto" distinto "$A2" "$B1"

echo "== C · trackeado modificado: staged y unstaged dan la misma huella"
echo "cambio" >> tracked.txt
C1=$(s); git add tracked.txt; C2=$(s)
check "unstaged vs staged" igual "$C1" "$C2"

echo "== D · árbol limpio: estable entre llamadas"
git reset -q --hard; rm -f nuevo.txt
D1=$(s); D2=$(s)
check "dos llamadas seguidas" igual "$D1" "$D2"

echo "== E · borrar un trackeado SÍ la cambia"
rm -f tracked.txt; E1=$(s)
check "borrado detectado" distinto "$D1" "$E1"
git checkout -q -- tracked.txt

echo "== F · chmod sin tocar el contenido SÍ la cambia"
F1=$(s); chmod +x tracked.txt; F2=$(s)
check "permisos detectados" distinto "$F1" "$F2"
chmod -x tracked.txt

echo "== G · fichero ignorado por .gitignore no influye"
echo "ign/" > .gitignore; git add .gitignore >/dev/null; git commit -qm ign
G1=$(s); mkdir -p ign; echo x > ign/x.txt; G2=$(s)
check "ignorado no cuenta" igual "$G1" "$G2"

echo "== H · fichero MOVIDO: sellar, \`git add\` y la huella no cambia  (lote 12.4, 2026-10)"
# Con el movimiento sin stagear, git lista los dos lados (la ruta vieja borrada y la nueva sin
# trackear). Tras \`git add\`, \`git diff HEAD\` lo detecta como RENOMBRE y solo nombra la nueva: la
# vieja desaparecía de la huella y el pre-commit bloqueaba sin que cambiara un byte.
mkdir -p viejo; echo "ticket" > viejo/t.md; git add -A >/dev/null; git commit -qm mover
mkdir -p nuevo; mv viejo/t.md nuevo/t.md
H1=$(s); git add -A >/dev/null; H2=$(s)
check "movido a mano vs movido y staged" igual "$H1" "$H2"
git reset -q --hard
mkdir -p nuevo   # reset --hard se lleva la carpeta vacía y `git mv` la necesita
git mv viejo/t.md nuevo/t.md
H3=$(s)
check "git mv da la misma huella que mover y stagear" igual "$H2" "$H3"
# El lado viejo cuenta como ausente: sin él, mover y COPIAR darían la misma huella.
git reset -q --hard; mkdir -p nuevo; cp viejo/t.md nuevo/t.md
H4=$(s)
check "copiar (el viejo sigue) no es mover" distinto "$H3" "$H4"
git reset -q --hard; git clean -qfd

echo "== I · movido y además editado: el contenido nuevo SÍ cambia la huella"
mkdir -p nuevo; git mv viejo/t.md nuevo/t.md; echo "editado" >> nuevo/t.md
I1=$(s)
check "mover+editar ≠ mover" distinto "$H3" "$I1"
git reset -q --hard; git clean -qfd

echo
echo "RESULTADO: $ok ok · $ko fallos"
[ "$ko" -eq 0 ]
