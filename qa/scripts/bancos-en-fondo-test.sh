#!/usr/bin/env bash
# Banco de `bancos-en-fondo.sh`. No corre ningún banco real: usa bancos de juguete en un temporal.
#
#   bash qa/scripts/bancos-en-fondo-test.sh
#
# Lo que tiene que cumplir, porque si se rompe NO da error —el job sigue en verde sin haber visto
# correr los bancos lentos—:
#   1. Dos verdes en segundo plano → `esperar` sale 0, y `lanzar` vuelve enseguida (segundo plano de
#      verdad: no espera a que terminen).
#   2. Un rojo → `esperar` sale 1 y lo nombra.
#   3. `esperar` sin nada lanzado → 1 (falla cerrado).
#   4. Un banco que pasa del tope → 1, y se mata.
#   5. `lanzar --nuevo` borra restos de una corrida anterior; sin `--nuevo`, se acumula.
#   6. `lanzar` dentro de `$(…)` vuelve sin esperar al banco (así lo llama el gate local).
#   7. Un banco que no existe → `lanzar` sale 1.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/bancos-en-fondo.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export BANCOS_EN_FONDO_DIR="$T/estado"

fallos=0
ok()  { echo "  ok  $1"; }
mal() { echo "  MAL $1"; fallos=$((fallos + 1)); }

printf '#!/bin/bash\nsleep 2; echo verde-a\n' > "$T/a.sh"
printf '#!/bin/bash\nsleep 1; echo verde-b\n' > "$T/b.sh"
printf '#!/bin/bash\necho me caigo; exit 3\n' > "$T/rojo.sh"
printf '#!/bin/bash\nsleep 30\n' > "$T/lento.sh"

echo "1. dos verdes"
t0=$(date +%s)
bash "$SCRIPT" lanzar --nuevo "$T/a.sh" "$T/b.sh" > "$T/o1" 2>&1
dt=$(( $(date +%s) - t0 ))
[ "$dt" -lt 2 ] && ok "lanzar vuelve sin esperar ($dt s)" || mal "lanzar tardó $dt s: no está en segundo plano"
bash "$SCRIPT" esperar > "$T/o2" 2>&1; rc=$?
[ "$rc" = 0 ] && ok "esperar sale 0" || mal "esperar salió $rc: $(cat "$T/o2")"
grep -q verde-a "$T/o2" && grep -q verde-b "$T/o2" && ok "imprime los dos logs" || mal "faltan logs: $(cat "$T/o2")"
[ ! -d "$BANCOS_EN_FONDO_DIR" ] && ok "esperar limpia el registro" || mal "el registro sigue ahí"

echo "2. un rojo"
bash "$SCRIPT" lanzar --nuevo "$T/a.sh" "$T/rojo.sh" > /dev/null 2>&1
bash "$SCRIPT" esperar > "$T/o3" 2>&1; rc=$?
[ "$rc" = 1 ] && ok "esperar sale 1" || mal "esperar salió $rc"
grep -q "En rojo: rojo (3)" "$T/o3" && ok "nombra el rojo y su código" || mal "no nombra el rojo: $(cat "$T/o3")"

echo "3. nada lanzado"
bash "$SCRIPT" esperar > "$T/o4" 2>&1; rc=$?
[ "$rc" = 1 ] && ok "esperar sin lanzar sale 1" || mal "esperar sin lanzar salió $rc"

echo "4. tope"
bash "$SCRIPT" lanzar --nuevo "$T/lento.sh" > /dev/null 2>&1
t0=$(date +%s)
bash "$SCRIPT" esperar --tope 2 > "$T/o5" 2>&1; rc=$?
dt=$(( $(date +%s) - t0 ))
[ "$rc" = 1 ] && ok "pasar del tope sale 1" || mal "pasar del tope salió $rc"
[ "$dt" -lt 10 ] && ok "no espera más del tope ($dt s)" || mal "esperó $dt s"
grep -q "tope de 2 s" "$T/o5" && ok "dice que fue el tope" || mal "no dice el tope: $(cat "$T/o5")"

echo "5. --nuevo y acumular"
mkdir -p "$BANCOS_EN_FONDO_DIR"; echo "viejo 999999 0" > "$BANCOS_EN_FONDO_DIR/lanzados"
bash "$SCRIPT" lanzar --nuevo "$T/b.sh" > /dev/null 2>&1
grep -q "^viejo " "$BANCOS_EN_FONDO_DIR/lanzados" && mal "--nuevo no borró el resto viejo" || ok "--nuevo borra lo viejo"
bash "$SCRIPT" lanzar "$T/a.sh" > /dev/null 2>&1
[ "$(wc -l < "$BANCOS_EN_FONDO_DIR/lanzados" | tr -d ' ')" = 2 ] && ok "sin --nuevo acumula" || mal "no acumula"
bash "$SCRIPT" esperar > /dev/null 2>&1 && ok "los dos acumulados en verde" || mal "los acumulados no salen en verde"

echo "6. dentro de \$(…), como el gate"
t0=$(date +%s)
: "$(bash -c "bash '$SCRIPT' lanzar --nuevo '$T/a.sh'" 2>&1 </dev/null)"
dt=$(( $(date +%s) - t0 ))
[ "$dt" -lt 2 ] && ok "vuelve sin esperar ($dt s)" || mal "el \$(…) esperó $dt s al banco"
bash "$SCRIPT" esperar > /dev/null 2>&1 || mal "esperar tras el \$(…) no salió en verde"

echo "7. banco inexistente"
bash "$SCRIPT" lanzar --nuevo "$T/no-existe.sh" > /dev/null 2>&1; rc=$?
[ "$rc" = 1 ] && ok "lanzar sale 1" || mal "lanzar salió $rc"
rm -rf "$BANCOS_EN_FONDO_DIR"

echo
if [ "$fallos" -eq 0 ]; then echo "bancos-en-fondo: todo en orden"; else echo "bancos-en-fondo: $fallos caso(s) MAL"; exit 1; fi
