#!/bin/bash
# hlc01-cap-test.sh — banco LOCAL del tope a un HLC futuro (`hlc01_cap_future_hlc.sql`).
#
# Levanta un Postgres desechable, carga el DDL real (`supabase-groups-staging.ddl` + las tablas de
# `supabase-staging.ddl`) con unos stubs mínimos de Supabase (roles, `auth.uid()`, pgcrypto), siembra filas
# «legacy» con HLC del futuro, aplica la migración y corre `hlc01-cap-test.sql`: el trigger en las tablas
# personales y de Grupos, y `apply_group_delta` REAL ejecutado como miembro (`role authenticated`).
# El control negativo corre el mismo escenario de Grupos con la migración retirada (`hlc01_rollback.sql`):
# ahí el teléfono adelantado tiene que seguir ganando, o el banco no está midiendo nada.
#
# No necesita red ni credenciales. Requiere `initdb`/`pg_ctl`/`psql` (Homebrew postgresql@16 o @17).
# El cuerpo de `apply_delta`/`apply_pref` (canal personal) no está en el repo: el trigger se prueba sobre sus
# tablas, y el comportamiento de los RPC personales lo mide `hlc01-cap-staging-probe.sh` tras aplicar en staging.
#
# Uso:  bash qa/cloud/hlc01-cap-test.sh        → «hlc01: N/N PASS», exit 0 solo si todo pasa.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-}"
if [ -z "$PGBIN" ]; then
  for c in /opt/homebrew/opt/postgresql@17/bin /opt/homebrew/opt/postgresql@16/bin /usr/local/opt/postgresql@17/bin; do
    [ -x "$c/initdb" ] && PGBIN="$c" && break
  done
fi
[ -n "$PGBIN" ] && [ -x "$PGBIN/initdb" ] || { echo "hlc01: no encuentro initdb (exporta PGBIN)"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/hlc01.XXXXXX")"
PORT="${HLC01_PORT:-54329}"
cleanup() {
  "$PGBIN/pg_ctl" -D "$TMP/data" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

"$PGBIN/initdb" -D "$TMP/data" -U postgres --auth=trust -E UTF8 >/dev/null
"$PGBIN/pg_ctl" -D "$TMP/data" -o "-k $TMP -p $PORT -c listen_addresses=''" -l "$TMP/log" -w start >/dev/null

MIG="${HLC01_MIGRATION:-$ROOT/qa/cloud/hlc01_cap_future_hlc.sql}"   # override: solo para mutantes
PSQL=("$PGBIN/psql" -h "$TMP" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q -X)

# --- stubs de Supabase (lo mínimo que el DDL referencia)
"${PSQL[@]}" <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role authenticator noinherit login;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claims', true)::json ->> 'sub', '')::uuid $$;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
create schema extensions;
create extension pgcrypto schema extensions;
grant usage on schema extensions to authenticated;
grant usage on schema public to authenticated, anon;
SQL

# --- DDL real
"${PSQL[@]}" -1 -f "$ROOT/supabase-groups-staging.ddl" >/dev/null   # trae `set local check_function_bodies = off`: va en UNA transacción
"${PSQL[@]}" -f "$ROOT/supabase-staging.ddl" >/dev/null

# El .ddl personal declara en su cabecera, sin escribirlo, un trigger stamp_server_seq por tabla: se pone aquí
# para que la normalización se pueda medir por el `server_seq`.
"${PSQL[@]}" <<'SQL'
do $$
declare v_t text;
begin
  foreach v_t in array array['accounts','budgets','cashflow_lines','cashflow_overrides','cashflow_plans','categories',
    'exchange_rates','favorite_payments','group_bridge_prefs','inbox_drafts','merchant_memory','notification_items',
    'scheduled_payments','subcategories','tags','tx_items','user_preferences'] loop
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.stamp_server_seq()',
                   v_t || '_stamp', v_t);
  end loop;
end $$;
SQL

# --- el estado de ANTES de la migración: si el snapshot .ddl ya trae el tope (tras aplicarlo y regenerar el snapshot),
#     se retira aquí para que las filas legacy se siembren sin él y la normalización tenga algo que medir.
"${PSQL[@]}" -f "$ROOT/qa/cloud/hlc01_rollback.sql" >/dev/null

# --- filas legacy: escritas ANTES de la migración, con HLC del futuro
"${PSQL[@]}" -f "$ROOT/qa/cloud/hlc01-cap-test-seed.sql"

# --- la migración, dos veces (idempotencia)
"${PSQL[@]}" -f "$MIG" 2>"$TMP/notice1"
"${PSQL[@]}" -f "$MIG" 2>"$TMP/notice2"
grep -o 'hlc01: [^"]*' "$TMP/notice1" | sed 's/^/  1.ª pasada: /' || true
grep -o 'hlc01: tope aplicado[^"]*' "$TMP/notice2" | sed 's/^/  2.ª pasada: /' || true

# --- las pruebas (con la migración puesta) y el control negativo (sin ella)
"$PGBIN/psql" -h "$TMP" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -X -At \
  -v rollback_file="$ROOT/qa/cloud/hlc01_rollback.sql" \
  -v migration_file="$MIG" \
  -f "$ROOT/qa/cloud/hlc01-cap-test.sql" 2>"$TMP/err" | tee "$TMP/out"
if [ -s "$TMP/err" ] && grep -q ERROR "$TMP/err"; then cat "$TMP/err"; exit 1; fi

TOTAL=$(grep -c '^\(PASS\|FAIL\)' "$TMP/out" || true)
FAILS=$(grep -c '^FAIL' "$TMP/out" || true)
if [ "$TOTAL" -eq 0 ]; then echo "hlc01: CERO casos ejecutados — el banco no midió nada"; exit 1; fi
echo "hlc01: $((TOTAL - FAILS))/$TOTAL PASS"
[ "$FAILS" -eq 0 ]
