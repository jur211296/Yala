#!/bin/bash
# Banco de qa/scripts/guion-tanda-check.py. Repos de juguete bajo TMPDIR; no toca el real.
#   bash qa/scripts/guion-tanda-check-test.sh
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$AQUI/guion-tanda-check.py"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fallos=0; n=0

repo() {  # repo <nombre> <ids en qa> <ids en done> <texto del guion>
  local r="$TMP/$1"; mkdir -p "$r/tickets/qa" "$r/tickets/done" "$r/qa"
  for t in $2; do echo "x" > "$r/tickets/qa/$t.md"; done
  for t in $3; do echo "x" > "$r/tickets/done/$t.md"; done
  printf '%s\n' "$4" > "$r/qa/guion-tanda.md"
  echo "$r"
}
caso() {  # caso <nombre> <exit esperado> <exit real> [condición extra 0/1]
  n=$((n+1))
  if [ "$2" = "$3" ] && [ "${4:-0}" = 0 ]; then echo "  ok  $1"
  else echo "  ROJO $1 (exit esperado $2, salió $3; extra ${4:-0})"; fallos=$((fallos+1)); fi
}

# 1. Cuadra: todos los de qa nombrados, nada de done.
r=$(repo cuadra "aa-uno bb-dos" "cc-tres" $'# Guion\n| A1 | `aa-uno` |\n| A2 | `bb-dos` |')
python3 -I "$CHECK" --raiz "$r" >/dev/null; caso "cuadra → 0" 0 $?

# 2. Uno de qa sin nombrar → 1 y lo lista.
r=$(repo fuera "aa-uno bb-dos" "" $'# Guion\n`aa-uno`')
out=$(python3 -I "$CHECK" --raiz "$r"); e=$?
echo "$out" | grep -q -- "- bb-dos"; caso "fuera → 1 y lo nombra" 1 $e $?

# 3. Nombra uno que ya está en done → sobra, exit 1.
r=$(repo sobra "aa-uno" "cc-tres" $'# Guion\n`aa-uno` `cc-tres`')
out=$(python3 -I "$CHECK" --raiz "$r"); e=$?
echo "$out" | grep -q "SOBRAN (1)"; caso "sobra se informa, no falla → 0" 0 $e $?

# 4. Un nombre entre comillas que no es ticket (comando, encargo) no cuenta como sobra.
r=$(repo ajeno "aa-uno" "" $'# Guion\n`aa-uno` `sim-lock-sh` `2026-10-04-barrido`')
python3 -I "$CHECK" --raiz "$r" >/dev/null; caso "id ajeno no es sobra → 0" 0 $?

# 5. --escribir crea el bloque bajo el título y nombra el de fuera.
r=$(repo escribe "aa-uno bb-dos" "" $'# Guion\n\ncuerpo `aa-uno`')
python3 -I "$CHECK" --raiz "$r" --escribir >/dev/null; e=$?
sed -n 2,4p "$r/qa/guion-tanda.md" | grep -q "guion-check:inicio" && grep -q '> - `bb-dos`' "$r/qa/guion-tanda.md"
caso "--escribir crea el bloque" 1 $e $?

# 6. El bloque NO cuenta como montaje: tras escribirlo, bb-dos sigue fuera (control negativo
#    del recorte: sin él, el aviso se «arreglaría» a sí mismo en la segunda pasada).
python3 -I "$CHECK" --raiz "$r" >/dev/null; caso "el aviso no cuenta como montaje" 1 $?

# 7. Reescribir es idempotente (un solo bloque) y, cuadrado, dice que cuadra.
printf '\n`bb-dos`\n' >> "$r/qa/guion-tanda.md"
python3 -I "$CHECK" --raiz "$r" --escribir >/dev/null; e=$?
c=$(grep -c "guion-check:inicio" "$r/qa/guion-tanda.md"); grep -q "Nada fuera" "$r/qa/guion-tanda.md"
caso "reescribe un solo bloque y cuadra" 0 $e $(( $? + (c != 1) ))

# 8. Sin guion → 2.
r=$(repo singuion "aa-uno" "" "x"); rm "$r/qa/guion-tanda.md"
python3 -I "$CHECK" --raiz "$r" >/dev/null 2>&1; caso "sin guion → 2" 2 $?

# 9. Argumento desconocido → 2.
python3 -I "$CHECK" --nada >/dev/null 2>&1; caso "argumento desconocido → 2" 2 $?

# 10. Tablero: una card nombrada por su sufijo cuenta; otra sin nombrar queda fuera; Lola no cuenta.
r=$(repo tablero "aa-uno" "" $'# Tanda\n`aa-uno` · `k2up`')
cat > "$TMP/cards.json" <<'J'
[{"id":"tablero-algo-largo-k2up","column":"in qa","assignee":"frank"},
 {"id":"tablero-otra-cosa-zz9x","column":"in qa","assignee":"jurgen"},
 {"id":"tablero-de-lola-ll00","column":"in qa","assignee":"lola"},
 {"id":"tablero-en-backlog-bb11","column":"backlog","assignee":"frank"}]
J
out=$(python3 -I "$CHECK" --raiz "$r" --tablero-json "$TMP/cards.json"); e=$?
echo "$out" | grep -q -- "- tablero-otra-cosa-zz9x" && ! echo "$out" | grep -q "k2up\|ll00\|bb11"
caso "tablero: sufijo cuenta, Lola y backlog no" 1 $e $?

# 11. Varios guiones: basta con salir en uno; el aviso va al primero.
mkdir -p "$r/docs"; printf '# Vieja\n`zz9x`\n' > "$r/docs/vieja.md"
python3 -I "$CHECK" --raiz "$r" --tablero-json "$TMP/cards.json" --guion qa/guion-tanda.md --guion docs/vieja.md --escribir >/dev/null; e=$?
grep -q "Nada fuera" "$r/qa/guion-tanda.md" && ! grep -q "guion-check" "$r/docs/vieja.md"
caso "varios guiones: unión, y aviso en el primero" 0 $e $?

# 12. Tablero ilegible → 2 (fail-closed: «nada fuera» sin mirar sería el silencio de siempre).
echo "no es json" > "$TMP/roto.json"
python3 -I "$CHECK" --raiz "$r" --tablero-json "$TMP/roto.json" >/dev/null 2>&1; caso "tablero ilegible → 2" 2 $?

echo "guion-tanda-check: $((n-fallos))/$n"
[ "$fallos" -eq 0 ]
