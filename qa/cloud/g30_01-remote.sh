#!/usr/bin/env bash
# =====================================================================================================
# g30_01 · autor de un gasto editado desde un teléfono 2.1 contra STAGING o PRODUCCIÓN, por la Management API de Supabase.
#
#   bash qa/cloud/g30_01-remote.sh <staging|production> state     → triggers de split_expenses, la función y su md5,
#                                                                    y el md5 de apply_group_delta
#   bash qa/cloud/g30_01-remote.sh <staging|production> apply     → aplica g30_01_expense_author_from_v2_clients.sql
#   bash qa/cloud/g30_01-remote.sh <staging|production> rollback  → aplica g30_01_rollback.sql
#
# La migración va dentro de `begin`/`commit` con `lock_timeout` de 5 s (el CREATE TRIGGER toma un candado de tabla
# sobre split_expenses), y su bloque final aborta la transacción entera si el trigger no quedó como se espera.
# Credencial: ~/Secrets/yala-supabase-mgmt/pat (PAT de la Management API; entra como `postgres`).
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
  staging)    REF=fostjbbwstyuunmmefuk ;;
  production) REF=kefvaiymtgytemwbltlz ;;
  *) echo "uso: $0 <staging|production> <state|apply|rollback>"; exit 2 ;;
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
select (select string_agg(tgname, ',' order by tgname) from pg_trigger
         where tgrelid = 'public.split_expenses'::regclass and not tgisinternal) as triggers_split_expenses,
       (select count(*) from pg_proc where proname = 'expense_author_from_v2_clients'
         and pronamespace = 'public'::regnamespace) as funciones,
       (select md5(prosrc) from pg_proc where proname = 'expense_author_from_v2_clients'
         and pronamespace = 'public'::regnamespace) as md5,
       (select has_function_privilege('authenticated', p.oid, 'EXECUTE') from pg_proc p
         where p.proname = 'expense_author_from_v2_clients' and p.pronamespace = 'public'::regnamespace) as execute_authenticated,
       (select md5(prosrc) from pg_proc where proname = 'apply_group_delta') as apply_group_delta_md5
SQL
}

wrap() {  # $1 = fichero → la transacción entera
  { echo "begin;"; echo "set local lock_timeout = '5s';"; cat "$1"; echo "commit;"; } | sql -
}

case "$ACTION" in
  state) state ;;
  apply) wrap "$HERE/g30_01_expense_author_from_v2_clients.sql"; echo; state ;;
  rollback) wrap "$HERE/g30_01_rollback.sql"; echo; state ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
