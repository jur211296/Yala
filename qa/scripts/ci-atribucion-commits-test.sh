#!/bin/bash
# Banco de `ci-atribucion-commits.sh`: el candado anti-atribución sobre commits ya hechos.
#
# Por qué existe: ese script solo se pone rojo el día que algo se cuela, y un candado que nunca
# salta se puede romper sin que nadie lo vea. Aquí se fabrican los commits que el hook local NO
# ve —un cherry-pick, un revert, un rebase, un `--author` de IA— y el título de PR que GitHub
# copia al merge, y se comprueba que el script los caza; y que los limpios pasan.
#
# Monta repos git desechables bajo TMPDIR (los commits se crean con `core.hooksPath` vacío, para
# poder fabricar los malos) y simula los eventos de GitHub con un JSON propio. Usa el hook REAL
# del repo: si el hook se endurece, el banco lo sigue.
#
#   bash qa/scripts/ci-atribucion-commits-test.sh            # prueba el script del repo
#   bash qa/scripts/ci-atribucion-commits-test.sh <otro.sh>  # prueba una variante (mutantes)
#
# Sale 0 si todos los casos pasan. Los casos «limpio» son los que impiden «arreglarlo» a base de
# rechazar todo; los de push y local, los que impiden revisar solo el último commit.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${1:-$RAIZ/qa/scripts/ci-atribucion-commits.sh}"
HOOK="$RAIZ/.githooks/commit-msg"
[ -f "$SCRIPT" ] || { echo "no encuentro el script: $SCRIPT"; exit 1; }
[ -f "$HOOK" ] || { echo "no encuentro el hook: $HOOK"; exit 1; }

BASE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/atrib-bench.XXXXXX")
trap 'rm -rf "$BASE_TMP"' EXIT

# Las firmas se arman por trozos: así este fichero no lleva el literal entero en ninguna línea.
NOM="Clau""de"
TRAILER="Co-Authored-By: $NOM Opus <noreply@anthropic"".com>"
ROBOT=$(printf '\xf0\x9f\xa4\x96')

g() { git -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"; }

nuevo_repo() { # nombre → deja el repo en $R con un commit base limpio
    R="$BASE_TMP/$1"
    mkdir -p "$R" && cd "$R" || exit 1
    g init -q -b main .
    git config user.email jurgen@example.com; git config user.name "Jürgen"
    echo base > f.txt; g add f.txt; g commit -qm "base"
}
commit() { # mensaje [args extra de commit]
    local m="$1"; shift
    # Un fichero nuevo por commit: así un cherry-pick o un merge nunca chocan.
    N=$((N + 1)); echo "$m" > "c$N.txt"; g add "c$N.txt"; g commit -q -m "$m" "$@"
}

evento() { # json → fichero de evento
    printf '%s' "$1" > "$BASE_TMP/evento.json"; echo "$BASE_TMP/evento.json"
}

correr() { # evento-nombre evento-fichero → código de salida del script (salida en $OUT)
    OUT=$(cd "$R" && GITHUB_EVENT_NAME="$1" GITHUB_EVENT_PATH="$2" \
          ATRIBUCION_REPO="$R" ATRIBUCION_HOOK="$HOOK" bash "$SCRIPT" 2>&1)
}

N=0
ok=0; ko=0
t() { # salida esperado(0|1) descripcion [motivo] — evalúa el último `correr`
    # Con `motivo`, el rojo tiene que ser POR eso: un rojo por un JSON roto o un fetch fallido
    # también sale 1, y así pasó en la primera versión de este banco (el caso de push «malo» era
    # verde por accidente; lo destapó su control negativo).
    local got=$1 esp=$2 desc=$3 motivo=${4:-}
    if [ -n "$motivo" ] && ! printf '%s' "$OUT" | grep -qF "$motivo"; then got="$got sin «$motivo»"; fi
    if [ "$got" = "$esp" ]; then echo "  ✓ $desc → $got"; ok=$((ok+1))
    else echo "  ✘ $desc → $got (esperado $esp)"; printf '%s\n' "$OUT" | sed 's/^/      /' | tail -6; ko=$((ko+1)); fi
}

pr() { # base head titulo → evento de PR
    evento "{\"pull_request\":{\"number\":7,\"title\":$(python3 -I -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$3"),\"base\":{\"sha\":\"$1\"},\"head\":{\"sha\":\"$2\",\"label\":\"jur:rama\"}}}"
}

ev_push() { # before after → evento de push
    evento "$(printf '{"before":"%s","after":"%s"}' "$1" "$2")"
}

echo "== pull_request: los commits del PR y el título que GitHub copia al merge"
nuevo_repo pr-limpio; B=$(git rev-parse HEAD)
commit "feat: algo"; commit "fix: otra cosa

Cuerpo que nombra CLAUDE.md y .claude/rules/ci-qa.md, que está permitido."
correr pull_request "$(pr "$B" "$(git rev-parse HEAD)" "Un PR limpio")"; t $? 0 "PR limpio (control negativo)"

nuevo_repo pr-trailer; B=$(git rev-parse HEAD)
commit "feat: limpio"; commit "fix: con firma

$TRAILER"; commit "chore: limpio otra vez"
correr pull_request "$(pr "$B" "$(git rev-parse HEAD)" "Un PR")"; t $? 1 "un trailer en un commit de en medio" "Hay 1 con atribución"

nuevo_repo pr-autor; B=$(git rev-parse HEAD)
commit "feat: autor raro" --author="$NOM <noreply@anthropic.com>"
correr pull_request "$(pr "$B" "$(git rev-parse HEAD)" "Un PR")"; t $? 1 "--author de IA (no viaja en el mensaje)" "Hay 1 con atribución"

nuevo_repo pr-titulo; B=$(git rev-parse HEAD)
commit "feat: limpio"
correr pull_request "$(pr "$B" "$(git rev-parse HEAD)" "$ROBOT Un PR con el robot")"; t $? 1 "título del PR con el emoji (va al merge de GitHub)" "Hay 1 con atribución"

echo "== Las vías que el hook local no ve"
nuevo_repo cherry; B=$(git rev-parse HEAD)
g checkout -q -b otra; commit "fix: en otra rama

$TRAILER"; MALO=$(git rev-parse HEAD)
g checkout -q main; commit "feat: limpio"; g cherry-pick "$MALO" >/dev/null
correr pull_request "$(pr "$B" "$(git rev-parse HEAD)" "Un PR")"; t $? 1 "cherry-pick de un commit con trailer" "Hay 1 con atribución"

nuevo_repo revert; B=$(git rev-parse HEAD)
commit "feat: limpio"; g revert --no-edit HEAD >/dev/null
g commit -q --amend -m "Revert de lo anterior

$TRAILER"
correr pull_request "$(pr "$B" "$(git rev-parse HEAD)" "Un PR")"; t $? 1 "revert con la firma en el mensaje" "Hay 1 con atribución"

nuevo_repo merge; B=$(git rev-parse HEAD)
g checkout -q -b rama; commit "feat: limpio en rama"
g checkout -q main; commit "feat: limpio en main"
g merge -q --no-ff rama -m "Merge de rama

Generated with $NOM Code" >/dev/null
correr pull_request "$(pr "$B" "$(git rev-parse HEAD)" "Un PR")"; t $? 1 "commit de merge con la firma generada" "Hay 1 con atribución"

echo "== push: todo before..after, no solo el último"
nuevo_repo push; A=$(git rev-parse HEAD)
commit "fix: con firma

$TRAILER"; commit "feat: limpio y el último"
correr push "$(ev_push "$A" "$(git rev-parse HEAD)")"; t $? 1 "push con el commit malo antes del último" "Hay 1 con atribución"
nuevo_repo push-limpio; A=$(git rev-parse HEAD)
commit "feat: limpio"; commit "fix: limpio"
correr push "$(ev_push "$A" "$(git rev-parse HEAD)")"; t $? 0 "push limpio (control negativo)"

echo "== local (el /gate): lo que aún no está en ningún remoto"
nuevo_repo local-remoto
g clone -q --bare . "$BASE_TMP/remoto.git"; g remote add origin "$BASE_TMP/remoto.git"
g fetch -q origin
commit "fix: sin subir

$TRAILER"; commit "feat: limpio sin subir"
correr "" "/no/existe"; t $? 1 "commit sin subir con trailer, tapado por uno limpio" "Hay 1 con atribución"
g reset -q --hard origin/main
commit "feat: limpio sin subir"
correr "" "/no/existe"; t $? 0 "solo commits limpios sin subir"

echo "== Fail-closed y eventos sin commits"
nuevo_repo raros
correr pull_request "$(evento '{"pull_request":{"number":7}}')"; t $? 1 "evento de PR sin base ni head" "no trae base y head"
correr pull_request "$(pr "1111111111111111111111111111111111111111" "$(git rev-parse HEAD)" "x")"; t $? 1 "base que no existe ni se puede traer" "no pude traer"
correr schedule "/no/existe"; t $? 0 "schedule: nada que revisar"

echo
echo "RESULTADO: $ok ok · $ko fallos"
[ "$ko" -eq 0 ]
