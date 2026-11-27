#!/usr/bin/env bash
# =====================================================================================================
# g38_01 · Compartido lote 3: `create_person_group` y la rama de persona de `join_group`, contra STAGING o PRODUCCIÓN,
# por la Management API.
#
#   bash qa/cloud/g38_01-remote.sh <staging|production> state     → ¿existe create_person_group? ¿join_group con persona?
#   bash qa/cloud/g38_01-remote.sh <staging|production> apply     → aplica g38_01_person_group_and_join.sql
#   bash qa/cloud/g38_01-remote.sh <staging|production> test      → banco en una transacción que se deshace (no deja nada)
#   bash qa/cloud/g38_01-remote.sh <staging|production> rollback  → aplica g38_01_rollback.sql
#
# Producción no se toca sin la decisión de Jürgen (g37_01 tampoco está allí).
# Credencial: ~/Secrets/yala-supabase-mgmt/pat (PAT de la Management API; entra como `postgres`).
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
  staging)    REF=fostjbbwstyuunmmefuk ;;
  production) REF=kefvaiymtgytemwbltlz ;;
  *) echo "uso: $0 <staging|production> <state|apply|test|rollback>"; exit 2 ;;
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
select (select count(*) from pg_proc where proname = 'create_person_group') as create_person_group,
       (select position('g38_01 · PERSONA' in prosrc) > 0 from pg_proc
         where oid = 'public.join_group(text, text, text, text)'::regprocedure) as join_con_persona,
       (select md5(prosrc) from pg_proc where oid = 'public.join_group(text, text, text, text)'::regprocedure) as join_md5
SQL
}

case "$ACTION" in
  state) state ;;
  apply) sql "$HERE/g38_01_person_group_and_join.sql"; echo; state ;;
  test) sql "$HERE/g38_01_bench.sql" | jq -c '.' ;;
  rollback) sql "$HERE/g38_01_rollback.sql"; echo; state ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
