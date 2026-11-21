#!/usr/bin/env bash
# =====================================================================================================
# g33_01 · las cuatro columnas de `cashflow_lines` de los límites con pagos y en otra moneda (manifest v8) contra STAGING o PRODUCCIÓN, por la Management API de Supabase.
#
#   bash qa/cloud/g33_01-remote.sh <staging|production> state     → ¿existen las cuatro columnas? tipo y nullable
#   bash qa/cloud/g33_01-remote.sh <staging|production> apply     → aplica g33_01_cashflow_limits_payments_and_currency.sql
#   bash qa/cloud/g33_01-remote.sh <staging|production> rollback  → aplica g33_01_rollback.sql
#
# La migración ya trae su `begin`/`commit` y aborta entera si algo no es lo esperado (§2).
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
select column_name, data_type, is_nullable from information_schema.columns
 where table_schema = 'public' and table_name = 'cashflow_lines'
   and column_name in ('scheduled_payment_ids_raw', 'limit_extra_amount', 'limit_currency_code', 'limit_foreign_amount')
 order by column_name
SQL
}

case "$ACTION" in
  state) state ;;
  apply) sql "$HERE/g33_01_cashflow_limits_payments_and_currency.sql"; echo; state ;;
  rollback) sql "$HERE/g33_01_rollback.sql"; echo; state ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
