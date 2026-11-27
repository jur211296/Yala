#!/usr/bin/env bash
# =====================================================================================================
# g37_01 · la marca de persona de Grupos (`split_groups.is_person`) contra STAGING o PRODUCCIÓN, por la Management API.
#
#   bash qa/cloud/g37_01-remote.sh <staging|production> state     → ¿existe la columna? y el reader
#   bash qa/cloud/g37_01-remote.sh <staging|production> apply     → aplica g37_01_group_is_person.sql
#   bash qa/cloud/g37_01-remote.sh <staging|production> rollback  → aplica g37_01_rollback.sql
#
# Producción no se toca sin la decisión de Jürgen (aprobado el 2026-11-26 solo para staging).
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
select (select data_type || '/' || is_nullable || '/' || coalesce(column_default, '')
          from information_schema.columns where table_schema = 'public'
         and table_name = 'split_groups' and column_name = 'is_person') as columna,
       (select pg_get_function_result('public.groups_pull_rows_split_groups(text, bigint, int, text)'::regprocedure)
         like '%is_person boolean)') as reader,
       (select count(*) from public.split_groups where coalesce((to_jsonb(split_groups) ->> 'is_person')::boolean, false))
         as personas_marcadas
SQL
}

case "$ACTION" in
  state) state ;;
  apply) sql "$HERE/g37_01_group_is_person.sql"; echo; state ;;
  rollback) sql "$HERE/g37_01_rollback.sql"; echo; state ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
