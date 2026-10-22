#!/bin/bash
# Banco de pruebas de `.githooks/commit-msg`, el candado que impide que un commit de
# Yala diga que lo escribió una IA.
#
# Por qué existe: hasta el 2026-09-09 ese candado no estaba puesto aquí —
# `core.hooksPath` local sustituye al global, no se suma— y lo único que mantenía el
# historial limpio era que las sesiones se acordaban. El 2026-09-08 una se olvidó. Un
# candado sin banco de pruebas se relaja sin que nadie lo note, así que su
# comportamiento se pinea aquí y lo corre el CI en cada push (job `coverage-index`).
#
#   bash qa/scripts/commit-msg-test.sh            # prueba el hook del repo
#   bash qa/scripts/commit-msg-test.sh <otro>     # prueba una variante
#
# Sale 0 si TODOS los casos pasan. Los casos 11-17 son los que impiden "arreglar" un
# fallo a base de endurecer a lo bruto: `grep -qi claude` los tumbaría, y con ellos el
# derecho a nombrar `CLAUDE.md` o `.claude/rules/…` en un mensaje — que en este repo
# está permitido a propósito (decisión de Jürgen, 2026-09-09; 216 commits lo hacen).
#
# La segunda mitad compara con el hook global de ADR-013 si está en el Mac. No corre
# en el CI, y eso se dice en voz alta en vez de saltárselo en silencio.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${1:-$RAIZ/.githooks/commit-msg}"
GLOBAL="${HOOK_GLOBAL:-${HOME:-/nonexistent}/.claude/git-hooks/commit-msg}"

# Falla CERRADO: sin hook que probar no hay veredicto que dar.
[ -f "$HOOK" ] || { echo "FALLO: no encuentro el hook: $HOOK"; exit 1; }

TMP=$(mktemp -d /tmp/commit-msg-bench.XXXXXX 2>/dev/null)
# Falla CERRADO: sin directorio propio los mensajes se escriben en la raíz y el
# veredicto lo decide el sistema de ficheros, no el hook. Medido: como root salía
# VERDE 17/17 habiendo escrito 18 ficheros en `/`.
if [ -z "$TMP" ] || [ ! -d "$TMP" ] || [ ! -w "$TMP" ]; then
    echo "FALLO: no pude crear un directorio de trabajo (mktemp)."
    exit 1
fi
trap 'rm -rf "$TMP"' EXIT

ok=0; ko=0

# caso <n> <categoria: atribucion|legitimo> <esperado: RECHAZA|PASA> <descripcion>
# El mensaje llega por stdin.
caso() {
    local n="$1" cat="$2" esperado="$3" desc="$4"
    cat > "$TMP/msg-$n.txt"
    local salida rc
    salida=$(bash "$HOOK" "$TMP/msg-$n.txt" 2>&1); rc=$?
    local real="PASA"; [ $rc -ne 0 ] && real="RECHAZA"
    if [ "$real" = "$esperado" ]; then
        ok=$((ok+1)); printf '  ok   %-2s %-10s %s\n' "$n" "[$cat]" "$desc"
    else
        ko=$((ko+1))
        printf '  FALLO %-2s %-10s %s\n' "$n" "[$cat]" "$desc"
        printf '        esperaba %s, obtuve %s\n' "$esperado" "$real"
        [ -n "$salida" ] && printf '        %s\n' "$(printf '%s' "$salida" | grep RECHAZADO)"
    fi
    echo "$n	$cat	$esperado" >> "$TMP/casos.tsv"
}

echo "Banco del commit-msg — hook: ${HOOK#$RAIZ/}"
echo

# ---------- atribución: tiene que rechazar ----------
caso 1 atribucion RECHAZA "Co-Authored-By: Claude, el clásico" <<'EOF'
fix(panel): el hero suma las cuentas filtradas

Co-Authored-By: Claude <noreply@anthropic.com>
EOF

caso 2 atribucion RECHAZA "el literal que pide la herramienta hoy" <<'EOF'
fix(panel): el hero suma las cuentas filtradas

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF

caso 3 atribucion RECHAZA "trailer Claude-Session (el global NO lo caza)" <<'EOF'
fix(panel): el hero suma las cuentas filtradas

Claude-Session: https://claude.ai/code/session_01ABCdefGHIjklMNOpqrs
EOF

caso 4 atribucion RECHAZA "URL de sesión suelta, sin trailer" <<'EOF'
feat(workflow): add autonomous mode

https://claude.ai/code/session_01ABCdefGHIjklMNOpqrs
EOF

caso 5 atribucion RECHAZA "la firma generada completa, con emoji" <<'EOF'
docs: al día

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF

caso 6 atribucion RECHAZA "Generated with Claude, en prosa y sin URL" <<'EOF'
docs: al día

Generated with Claude Code.
EOF

caso 7 atribucion RECHAZA "minúsculas y espaciado raro en el trailer" <<'EOF'
docs: al día

co-authored-by  :   claude opus <x@y.z>
EOF

caso 8 atribucion RECHAZA "Assisted-By: Anthropic" <<'EOF'
docs: al día

Assisted-By: Anthropic Claude
EOF

caso 9 atribucion RECHAZA "Signed-off-by con Claude" <<'EOF'
docs: al día

Signed-off-by: Claude Code <bot@example.com>
EOF

caso 10 atribucion RECHAZA "solo el emoji de robot" <<'EOF'
docs: al día

🤖
EOF

# ---------- legítimo: tiene que pasar ----------
caso 11 legitimo PASA "mensaje limpio (control negativo)" <<'EOF'
fix(panel): el hero suma las cuentas filtradas
EOF

caso 12 legitimo PASA "nombra CLAUDE.md en el asunto" <<'EOF'
docs: actualiza CLAUDE.md con la sección de hooks
EOF

caso 13 legitimo PASA "cita .claude/rules/ en el cuerpo (216 commits reales)" <<'EOF'
fix(qa): el runner no moría de memoria

- `.claude/rules/testing.md`: la regla, y el criterio que separa las dos familias
- `.claude/agent-memory/frank/`: corregido el método que prescribía
EOF

caso 14 legitimo PASA "coautoría HUMANA no se toca" <<'EOF'
feat(grupos): el tope de gasto avisa

Co-Authored-By: Jürgen Schmidt <jur211296@gmail.com>
EOF

caso 15 legitimo PASA "merge: rutas .claude/ en líneas de comentario" <<'EOF'
Merge remote-tracking branch 'origin/2.1' into encargo/lo-que-sea

# Conflicts:
#	.claude/agent-memory/frank/MEMORY.md
EOF

caso 16 legitimo PASA "un dominio que no es de Anthropic" <<'EOF'
feat(gateway): el cliente apunta a https://api.example.com/v1
EOF

caso 17 legitimo PASA "menciona Claude Code en prosa (permitido aquí)" <<'EOF'
fix(gate): el hook PreToolUse de Claude Code solo ve los commits de la herramienta

Un commit desde la Terminal se lo saltaba entero.
EOF

# ---------- lo que cazó la lente adversarial del 2026-09-09 ----------
#
# 28 evasiones medidas. Se cierran las plausibles —las que saldrían de reformular el
# mensaje, no de querer engañar al hook— y se dejan fuera, a propósito, las de la
# cabecera del hook: «IA»/«AI» a secas, los nombres de modelo sueltos y la ofuscación
# deliberada. Cerrar las primeras rompería este repo, que tiene features de IA.

caso 18 atribucion RECHAZA "el trailer detrás de una viñeta (37 % de los cuerpos las usan)" <<'EOF'
docs: al día

- Co-Authored-By: Claude Opus 5 (1M context)
- Claude-Session: session_01ABCdefGHIjklMNOpqrs
EOF

caso 19 atribucion RECHAZA "el trailer escondido tras un '#' pegado" <<'EOF'
docs: al día

#Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF

caso 20 atribucion RECHAZA "el trailer PLEGADO, que git vuelve a unir" <<'EOF'
docs: al día

Co-Authored-By:
 Claude Opus 5 (1M context) <opus5@users.noreply.github.com>
EOF

caso 21 atribucion RECHAZA "Generated-With: con guion (no estaba en la lista)" <<'EOF'
docs: al día

Generated-With: Claude Opus 5 (1M context)
EOF

caso 22 atribucion RECHAZA "la firma en español" <<'EOF'
docs: al día

Generado con Claude Code (Opus 5).
EOF

caso 23 atribucion RECHAZA "atribución en prosa, en español" <<'EOF'
docs: al día

Escrito por Claude, revisado por Jürgen.
EOF

caso 24 atribucion RECHAZA "la fórmula larga: 47 caracteres hasta el nombre" <<'EOF'
docs: al día

Generated with the official command line coding assistant from Claude.
EOF

caso 25 legitimo PASA "git commit -v: el diff va tras la tijera y no cuenta" <<'EOF'
fix(hooks): endurece el candado

# ------------------------ >8 ------------------------
diff --git a/.githooks/commit-msg b/.githooks/commit-msg
+printf '%s' "$CUERPO" | grep -qiE '(claude|anthropic)\.(ai|com)'
+Co-Authored-By: ejemplo dentro del diff
EOF

caso 26 legitimo PASA "viñeta con dos puntos que NO es un trailer" <<'EOF'
fix(qa): dos cosas

- `.claude/rules/testing.md`: la regla, y el criterio que separa
  las dos familias de test
- CLAUDE.md: la sección de hooks
EOF

# --- el autor del commit, que no viaja en el mensaje ---
# `git commit --author=` no toca `$1`, así que este caso no se puede montar con un
# fichero: se monta con el entorno, que es de donde `git var` saca la identidad.
autor_caso() {
    local n="$1" esperado="$2" desc="$3" nombre="$4" correo="$5"
    printf 'docs: al día\n' > "$TMP/msg-$n.txt"
    local rc
    GIT_AUTHOR_NAME="$nombre" GIT_AUTHOR_EMAIL="$correo" \
    GIT_COMMITTER_NAME="$nombre" GIT_COMMITTER_EMAIL="$correo" \
        bash "$HOOK" "$TMP/msg-$n.txt" >/dev/null 2>&1; rc=$?
    local real="PASA"; [ $rc -ne 0 ] && real="RECHAZA"
    if [ "$real" = "$esperado" ]; then
        ok=$((ok+1)); printf '  ok   %-2s %-10s %s\n' "$n" "[autor]" "$desc"
    else
        ko=$((ko+1)); printf '  FALLO %-2s %-10s %s (esperaba %s, obtuve %s)\n' "$n" "[autor]" "$desc" "$esperado" "$real"
    fi
}

# El caso 27 es además el que vigila que la regla de autor del hook esté VIVA: si
# `git var` no contestara —medido: sobre un directorio que no resuelve su gitdir
# devuelve 128— el hook dejaría pasar el autor falsificado y este caso saldría rojo.
# No hace falta comprobarlo aparte; se intentó y el guard no podía fallar.
autor_caso 27 RECHAZA "--author falsificado: atribución en la cabecera" "Claude Opus 5" "noreply@anthropic.com"
autor_caso 28 PASA    "el autor humano de siempre" "Jürgen Schmidt" "jur211296@gmail.com"

# ---------- lo que cazó la SEGUNDA lente: falsos positivos de las reglas de prosa ----------
#
# Estos cuatro los rechazaba el hook antes de neutralizar las rutas del repo. El tercero
# es el que más duele: el candado tumbaba un commit por atribuir el trabajo A JÜRGEN.

caso 29 legitimo PASA "«generado con» + una ruta .claude cerca" <<'EOF'
docs: el índice

El índice está generado con `qa/validate-coverage.py`, que lee `.claude/rules/testing.md`.
EOF

caso 30 legitimo PASA "«generated with» + CLAUDE.md en la misma frase" <<'EOF'
docs: la tabla

The table is generated with the script documented in CLAUDE.md.
EOF

caso 31 legitimo PASA "atribución explícita a un HUMANO, con rutas al lado" <<'EOF'
docs: el índice

Escrito por Jürgen; el índice vive en CLAUDE.md y en `.claude/rules/`.
EOF

caso 32 legitimo PASA "«creado con» una herramienta, con rutas al lado" <<'EOF'
chore: xcode

Creado con Xcode 26; sus reglas quedan en `.claude/rules/testing.md`.
EOF

TOTAL=$((ok+ko))
echo
# Falla CERRADO: una lista de casos vacía no es un banco en verde.
if [ "$TOTAL" -lt 32 ]; then
    echo "FALLO: se esperaban 32 casos y solo corrieron $TOTAL."
    exit 1
fi
echo "casos del hook de Yala: $ok/$TOTAL"

# ---------- divergencia con el hook global de ADR-013 ----------
#
# Qué mide: que el hook de Yala no sea MÁS LAXO que el global en atribución. El riesgo
# real es futuro — que el global gane un patrón y este repo no lo herede.
#
# Por qué el corpus son los mensajes REALES del repo y no los 17 casos de arriba:
# porque en esos 17 Yala ya rechaza por su cuenta, así que compararlos no puede dar
# señal propia. Sobre la historia sí: si el global caza algo que aquí pasa, sale.
#
# Su límite, dicho en voz alta: un patrón nuevo del global que no toque ningún mensaje
# del historial no se detecta. Y en el CI esto NO corre — allí no hay ~/.claude.
#
# `mapfile` no se usa a propósito: no existe en el bash 3.2 de macOS, y la primera
# versión de este bloque reventaba ahí y el banco salía VERDE igual. De ahí que el
# veredicto sea una variable explícita: si el bloque no llega a decidir, es ROJO.

DIV="no-ejecutado"

echo
if [ ! -f "$GLOBAL" ]; then
    DIV="saltado"
    echo "Divergencia con el hook global: NO EJECUTADA — no existe $GLOBAL."
    echo "  (normal en el CI; en el Mac de Jürgen sí debe correr)"
elif ! git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1; then
    DIV="saltado"
    echo "Divergencia con el hook global: NO EJECUTADA — $RAIZ no es un repo git."
else
    # El corpus se elige por CONTENIDO, no por recencia: los últimos 400 commits de
    # este repo tienen CERO atribución —el más reciente con trailer está en la
    # posición 408— así que un corpus "los últimos N" no mide nada y sale verde
    # siempre. Se filtra por los mensajes que mencionan a Claude o Anthropic, que es
    # un superconjunto de lo que cualquiera de los dos hooks puede rechazar.
    CORPUS="${CORPUS_N:-992}"
    git -C "$RAIZ" log --format='%H' --regexp-ignore-case \
        --grep='claude\|anthropic\|🤖' -n "$CORPUS" HEAD > "$TMP/shas.txt" 2>/dev/null
    N=$(grep -c . < "$TMP/shas.txt")
    # `saltado` es un estado legítimo y no suma fallos, así que un error interno no
    # puede acabar disfrazado de saltado: si el conteo no es un número, es ROJO. La
    # primera versión de este bloque reventaba con `mapfile` en el bash 3.2 de macOS
    # y salía «saltado», o sea verde.
    case "$N" in
        ''|*[!0-9]*)
            DIV="error"
            echo "Divergencia con el hook global: FALLO — no pude contar el corpus (N='$N')."
            ko=$((ko+1))
            N=-1
            ;;
    esac
    if [ "$N" -eq -1 ]; then
        :
    elif [ "$N" -lt 50 ]; then
        # Aquí ya sabemos que existe el hook global y que esto es un repo git, o sea
        # que estamos en el Mac y no en el CI. Con 992 mensajes en la historia, un
        # corpus de $N es anómalo, no "superficial": lo más probable es que algo haya
        # reventado arriba. Un `mapfile` en bash 3.2 dejaba N=0 y esto salía verde por
        # la puerta de "saltado". Se pierde la tolerancia a un clon --depth 1 en una
        # máquina con el hook global; a cambio no queda ningún estado ambiguo.
        DIV="corpus-anomalo"
        echo "Divergencia con el hook global: FALLO — corpus de solo $N mensajes."
        echo "  Con el hook global presente esto debería traer cientos. ¿Clon superficial,"
        echo "  o un error en el bloque de arriba?"
        ko=$((ko+1))
    else
        echo "Divergencia con el hook global sobre $N mensajes reales del repo:"
        div=0; n2=0; atrib=0
        while read -r sha; do
            [ -n "$sha" ] || continue
            git -C "$RAIZ" log -1 --format='%B' "$sha" > "$TMP/corpus.txt"
            gsal=$(bash "$GLOBAL" "$TMP/corpus.txt" 2>&1); grc=$?
            gmotivo=$(printf '%s' "$gsal" | sed -n 's/.*RECHAZADO — //p')
            gn2=no
            printf '%s' "$gsal" | grep -q 'menciona a Claude o Anthropic, y este no es un repo del sistema' && gn2=si
            # Cuenta cuántos casos de ATRIBUCIÓN trae el corpus: si son 0, esta
            # comparación no está midiendo nada y hay que decirlo, no salir verde.
            [ $grc -ne 0 ] && [ "$gn2" = "no" ] && atrib=$((atrib+1))
            bash "$HOOK" "$TMP/corpus.txt" >/dev/null 2>&1 || continue   # aquí ya se bloquea
            [ $grc -eq 0 ] && continue                                   # el global también pasa
            if [ "$gn2" = "si" ]; then n2=$((n2+1)); continue; fi         # nivel 2: deliberado
            echo "  DIVERGE $(git -C "$RAIZ" log -1 --format='%h %s' "$sha")"
            printf '    motivo del global: %s\n' "$gmotivo"
            div=$((div+1))
        done < "$TMP/shas.txt"
        echo "  casos de atribución en el corpus: $atrib"
        echo "  menciones que el global rechaza y aquí se permiten a propósito: $n2"
        if [ "$atrib" -eq 0 ]; then
            DIV="corpus-sin-atribucion"
            echo "  FALLO: el corpus no trae ni un caso de atribución, así que esta"
            echo "         comparación no puede fallar. Sube CORPUS_N."
            ko=$((ko+1))
        elif [ "$div" -eq 0 ]; then
            DIV="ok"
            echo "  sin divergencias de atribución."
        else
            DIV="diverge"
            echo "  $div divergencia(s): el global caza atribución que este hook deja pasar."
            echo "  Copia ese patrón a .githooks/commit-msg y vuelve a correr el banco."
            ko=$((ko+div))
        fi
    fi
fi

# Falla CERRADO: si el bloque de arriba no llegó a dar veredicto, algo revento dentro.
if [ "$DIV" = "no-ejecutado" ]; then
    echo "  FALLO: el bloque de divergencia no llegó a decidir (¿error dentro?)."
    ko=$((ko+1))
fi

echo
if [ "$ko" -eq 0 ]; then echo "VERDE — $ok/$TOTAL (divergencia: $DIV)"; exit 0; fi
echo "ROJO — $ko fallo(s) de $TOTAL (divergencia: $DIV)"; exit 1
