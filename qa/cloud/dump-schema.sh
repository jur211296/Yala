#!/usr/bin/env bash
# Regenerate supabase-staging.ddl — the snapshot-contract of the Modo Nube staging schema.
#
# The committed supabase-staging.ddl (repo root) is the OFFLINE MOLD: it is cross-checked by
# CloudCapabilityManifestParityTests without any network. This script documents how to REGENERATE /
# VERIFY it against the live schema. It needs a direct Postgres connection (network + psql/pg_dump),
# so it does NOT run in CI — run it by hand after any i5_* migration and commit the refreshed .ddl.
#
# Connection: set SUPABASE_DB_URL to the project's Postgres URL (Dashboard > Project Settings >
# Database > Connection string > URI; use the session pooler on port 5432). Password required.
#   export SUPABASE_DB_URL='postgresql://postgres.fostjbbwstyuunmmefuk:<PW>@aws-0-<region>.pooler.supabase.com:5432/postgres'
#
# Authoritative regeneration (schema-only, public schema):
#   pg_dump --schema-only --schema=public --no-owner --no-privileges "$SUPABASE_DB_URL"
#
# The committed .ddl is a HAND-LEGIBLE reduction (CREATE TABLE + PK + CHECK + a header noting the
# uniform index/trigger/RLS/grant tail). To VERIFY the live column contract matches the committed
# snapshot without a full pg_dump, this query returns the compact per-table column map the generator
# consumes (table:col:type, ordinal order):
#
#   SELECT table_name,
#     string_agg(column_name || ':' ||
#       CASE WHEN udt_name='numeric' THEN 'num'||coalesce(numeric_scale::text,'') ELSE udt_name END,
#       ',' ORDER BY ordinal_position) AS cols
#   FROM information_schema.columns
#   WHERE table_schema='public'
#     AND table_name IN ('tx_items','accounts','categories','subcategories','tags','budgets',
#       'scheduled_payments','inbox_drafts','favorite_payments','merchant_memory','exchange_rates',
#       'notification_items','cashflow_plans','cashflow_lines','cashflow_overrides','group_bridge_prefs')
#   GROUP BY table_name ORDER BY table_name;
#
set -euo pipefail
OUT="${1:-$(cd "$(dirname "$0")/../.." && pwd)/supabase-staging.ddl}"

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "SUPABASE_DB_URL not set — see the header of this script. The committed offline mold at:"
  echo "  $OUT"
  echo "is the contract used by CloudCapabilityManifestParityTests (no network needed)."
  exit 0
fi

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump not found. Install postgresql client tools, or use the information_schema query in the header."
  exit 1
fi

echo "Dumping public schema from live staging to ${OUT}.raw ..."
pg_dump --schema-only --schema=public --no-owner --no-privileges "$SUPABASE_DB_URL" > "${OUT}.raw"
echo "Wrote ${OUT}.raw — review against the committed ${OUT} (the committed file is the legible mold)."
echo "If the live schema changed, update the migrations, re-run the generator, and commit the refreshed .ddl."
