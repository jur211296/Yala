#!/usr/bin/env bash
# =====================================================================================================
# g29_01 · autor de gastos y liquidaciones de Grupos contra STAGING o PRODUCCIÓN, por la Management API de Supabase.
#
#   bash qa/cloud/g29_01-remote.sh <staging|production> state     → ¿existen las columnas? y los readers
#   bash qa/cloud/g29_01-remote.sh <staging|production> apply     → aplica g29_01_group_change_author.sql
#   bash qa/cloud/g29_01-remote.sh <staging|production> rollback  → aplica g29_01_rollback.sql
#
# La migración ya trae su `begin`/`commit` y aborta entera si algo no es lo esperado (§1 y §4).
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
select (select data_type from information_schema.columns where table_schema = 'public'
         and table_name = 'split_expenses' and column_name = 'last_edited_by_member_key') as gasto,
       (select data_type from information_schema.columns where table_schema = 'public'
         and table_name = 'split_settlements' and column_name = 'recorded_by_member_key') as liquidacion,
       (select pg_get_function_result('public.groups_pull_rows_split_expenses(text, bigint, int, text)'::regprocedure)
         like '%last_edited_by_member_key text)') as reader_gasto,
       (select pg_get_function_result('public.groups_pull_rows_split_settlements(text, bigint, int, text)'::regprocedure)
         like '%recorded_by_member_key text)') as reader_liquidacion
SQL
}

case "$ACTION" in
  state) state ;;
  apply) sql "$HERE/g29_01_group_change_author.sql"; echo; state ;;
  rollback) sql "$HERE/g29_01_rollback.sql"; echo; state ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
