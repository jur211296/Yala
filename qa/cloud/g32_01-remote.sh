#!/usr/bin/env bash
# =====================================================================================================
# g32_01 · `scheduled_payments.custom_logo_ref` + bucket `scheduled-payment-logos` contra STAGING o PRODUCCIÓN, por la Management API de Supabase.
#
#   bash qa/cloud/g32_01-remote.sh <staging|production> state     → ¿existe la columna? tipo, nullable, bucket y políticas
#   bash qa/cloud/g32_01-remote.sh <staging|production> apply     → aplica g32_01_scheduled_payment_custom_logo.sql
#   bash qa/cloud/g32_01-remote.sh <staging|production> rollback  → aplica g32_01_rollback.sql
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
select (select data_type from information_schema.columns
         where table_schema = 'public' and table_name = 'scheduled_payments' and column_name = 'custom_logo_ref') as tipo,
       (select is_nullable from information_schema.columns
         where table_schema = 'public' and table_name = 'scheduled_payments' and column_name = 'custom_logo_ref') as nullable,
       (select public from storage.buckets where id = 'scheduled-payment-logos') as bucket_publico,
       (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects'
         and policyname like 'scheduled_payment_logos_%') as politicas,
       (select count(*) from storage.objects where bucket_id = 'scheduled-payment-logos') as archivos
SQL
}

case "$ACTION" in
  state) state ;;
  apply) sql "$HERE/g32_01_scheduled_payment_custom_logo.sql"; echo; state ;;
  rollback) sql "$HERE/g32_01_rollback.sql"; echo; state ;;
  *) echo "acción desconocida: $ACTION"; exit 2 ;;
esac
