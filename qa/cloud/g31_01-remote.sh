#!/usr/bin/env bash
# =====================================================================================================
# g31_01 · volver a pasar a la nube con la misma cuenta, contra STAGING o PRODUCCIÓN, por la Management API de Supabase.
#
#   bash qa/cloud/g31_01-remote.sh <staging|production> state     → firma y md5 de claim_account
#   bash qa/cloud/g31_01-remote.sh <staging|production> probe     → el fichero entero en una transacción que se DESHACE
#                                                                    (prueba sin dejar huella: un RAISE final la revierte)
#   bash qa/cloud/g31_01-remote.sh <staging|production> apply     → aplica g31_01_claim_recutover_after_return_to_icloud.sql
#   bash qa/cloud/g31_01-remote.sh <staging|production> rollback  → aplica g31_01_rollback.sql
#
# PRODUCCIÓN solo con el visto bueno de Jürgen (encargo 2026-11-16-nube-bugs-media-2-3). Orden: este SQL → Worker → app.
# Credencial: ~/Secrets/yala-supabase-mgmt/pat (PAT de la Management API; entra como `postgres`). Corre en la Mini.
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
  staging)    REF=fostjbbwstyuunmmefuk ;;
  production) REF=kefvaiymtgytemwbltlz ;;
  *) echo "uso: $0 <staging|production> <state|probe|apply|rollback>"; exit 2 ;;
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
select pg_get_function_identity_arguments(p.oid) as args, md5(p.prosrc) as md5
from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like '%claim_account%'
SQL
}

case "$ACTION" in
  state) state ;;
  probe) { echo "begin;"; echo "set local lock_timeout = '5s';"; cat "$HERE/g31_01_claim_recutover_after_return_to_icloud.sql";
           echo "do \$x\$ begin raise exception 'g31_01_probe_ok (todo deshecho)'; end \$x\$;"; } | sql -; echo; state ;;
  apply) { echo "begin;"; echo "set local lock_timeout = '5s';"; cat "$HERE/g31_01_claim_recutover_after_return_to_icloud.sql"; echo "commit;"; } | sql -; echo; state ;;
  rollback) { echo "begin;"; echo "set local lock_timeout = '5s';"; cat "$HERE/g31_01_rollback.sql"; echo "commit;"; } | sql -; echo; state ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
