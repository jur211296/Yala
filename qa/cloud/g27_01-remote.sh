#!/usr/bin/env bash
# =====================================================================================================
# g27_01 · la batería del candado de saldos iniciales contra STAGING o PRODUCCIÓN, por la Management API de Supabase.
#
#   bash qa/cloud/g27_01-remote.sh <staging|production> state      → ¿está puesto el candado? (triggers + función)
#   bash qa/cloud/g27_01-remote.sh <staging|production> battery    → los 34 casos, todos en verde
#   bash qa/cloud/g27_01-remote.sh <staging|production> before     → sin el candado: los 17 casos que cambia salen
#                                                                     distinto y el resto igual (control del «antes»)
#   bash qa/cloud/g27_01-remote.sh <staging|production> apply      → aplica g27_01_opening_balance_managers.sql
#   bash qa/cloud/g27_01-remote.sh <staging|production> rollback   → aplica g27_01_rollback.sql
#
# La batería NUNCA hace commit: es un bloque DO que acaba en `raise exception 'G27_RESULTS:…'` (ver su cabecera), así
# que todo lo que siembra muere con la transacción. No usa columnas cifradas: la llave de Grupos no viaja.
# Credencial: ~/Secrets/yala-supabase-mgmt/pat (PAT de la Management API; entra como `postgres`).
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
  staging)    REF=fostjbbwstyuunmmefuk ;;
  production) REF=kefvaiymtgytemwbltlz ;;
  *) echo "uso: $0 <staging|production> <state|battery|before|apply|rollback>"; exit 2 ;;
esac
ACTION="${2:-}"
PAT_FILE="${HOME}/Secrets/yala-supabase-mgmt/pat"
[ -f "$PAT_FILE" ] || { echo "falta $PAT_FILE"; exit 2; }
command -v jq >/dev/null || { echo "hace falta jq"; exit 2; }

sql() {  # $1 = fichero SQL o «-» (stdin) → respuesta JSON cruda de la API
  local body
  if [ "$1" = "-" ]; then body=$(jq -Rs '{query: .}'); else body=$(jq -Rs '{query: .}' <"$1"); fi
  curl -sS -X POST "https://api.supabase.com/v1/projects/$REF/database/query" \
    -H "Authorization: Bearer $(cat "$PAT_FILE")" -H "Content-Type: application/json" -d "$body"
}

state() {
  sql - <<'SQL' | jq -c '.'
select (select count(*) from pg_trigger where tgname = 'opening_balance_guard') as triggers,
       (select count(*) from pg_proc where proname = 'opening_balance_guard' and pronamespace = 'public'::regnamespace) as funciones,
       (select md5(prosrc) from pg_proc where proname = 'opening_balance_guard' and pronamespace = 'public'::regnamespace) as md5,
       (select md5(pg_get_functiondef('public.apply_group_delta(text,text,uuid,text,jsonb,jsonb,text,text,integer)'::regprocedure))) as apply_group_delta_md5
SQL
}

battery_json() {
  local out
  out=$(sql "$HERE/g27_01-battery.sql")
  if ! grep -q 'G27_RESULTS:' <<<"$out"; then
    echo "la batería no devolvió resultados: $out" >&2; return 1
  fi
  jq -r '.message' <<<"$out" | sed -nE 's/.*G27_RESULTS:(\[.*\]).*/\1/p' | head -1
}

CAMBIAN="1 6 7 8 9 10 11 12 13 17 19 20 21 22 23 32 33"

case "$ACTION" in
  state) state ;;
  apply)
    { echo "begin;"; cat "$HERE/g27_01_opening_balance_managers.sql"; echo "commit;"; } | sql - ; echo; state ;;
  rollback)
    { echo "begin;"; cat "$HERE/g27_01_rollback.sql"; echo "commit;"; } | sql - ; echo; state ;;
  battery)
    R=$(battery_json)
    jq -r '.[] | "\(if .ok then "  ✓" else "  ✗" end) \(.n). \(.label) — esperado «\(.expected)», salió «\(.got)»"' <<<"$R"
    total=$(jq 'length' <<<"$R"); malos=$(jq '[.[] | select(.ok | not)] | length' <<<"$R")
    echo "g27_01 $1: $((total - malos))/$total PASS"
    [ "$total" = "34" ] && [ "$malos" = "0" ] ;;
  before)
    R=$(battery_json); fallos=0
    for n in $(jq -r '.[].n' <<<"$R"); do
      v=$(jq -r ".[] | select(.n == $n) | .ok" <<<"$R")
      if [[ " $CAMBIAN " == *" $n "* ]]; then want=false; else want=true; fi
      if [ "$v" = "$want" ]; then echo "  ✓ caso $n ($( [ $want = false ] && echo 'cambia con el candado' || echo 'igual sin el candado'))"
      else echo "  ✗ caso $n: ok=$v, se esperaba $want — $(jq -r ".[] | select(.n == $n) | .got" <<<"$R")"; fallos=$((fallos+1)); fi
    done
    echo "g27_01 $1 (antes): $fallos fallos"; [ "$fallos" = "0" ] ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
