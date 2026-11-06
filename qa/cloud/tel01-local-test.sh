#!/usr/bin/env bash
# tel01-local-test.sh — banco local de tel01_stats_counts.sql (molde g25_01-local-test.sh): un Postgres de usar y tirar
# con el DDL de Grupos, unas filas sembradas, la migración, sus conteos y sus permisos, y el rollback.
# Uso: bash qa/cloud/tel01-local-test.sh   (PGBIN=/ruta/bin si no es el de Homebrew)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MIG="$HERE/tel01_stats_counts.sql"
RB="$HERE/tel01_rollback.sql"
DDL="$ROOT/supabase-groups-staging.ddl"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
[ -x "$PGBIN/initdb" ] || { echo "tel01: no encuentro initdb en $PGBIN (exporta PGBIN)"; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/tel01.XXXXXX")"
PORT="${PORT:-55431}"
trap '"$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust -E UTF8 --no-locale >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c listen_addresses=127.0.0.1 -c unix_socket_directories=''" \
  -l "$WORK/log" -w start >/dev/null

q() { "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X -t -A "$@"; }

q <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role authenticator noinherit login;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $f$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $f$;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
create schema extensions;
create extension pgcrypto schema extensions;
grant usage on schema extensions to authenticated;
grant usage on schema public to authenticated, anon;
create table public.profiles (id uuid primary key, kind text not null default 'groups_only');
SQL

q -1 -f "$DDL" >"$WORK/ddl.out" 2>&1 || { echo "tel01: el DDL de Grupos no cargó:"; grep -v NOTICE "$WORK/ddl.out"; exit 1; }

q <<'SQL'
insert into auth.users (id) select ('33333333-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid from generate_series(1, 4) i;
insert into public.profiles (id, kind) values
  ('33333333-0000-0000-0000-000000000001', 'complete'),
  ('33333333-0000-0000-0000-000000000002', 'complete'),
  ('33333333-0000-0000-0000-000000000003', 'groups_only');
-- G1 vivo con un gasto de hoy · G2 vivo y viejo · G3 archivado · G4 borrado (tombstone).
insert into public.split_groups (group_id, hlc, created_at, is_archived, deleted) values
  ('G1', 'h', now() - interval '1 day', false, false),
  ('G2', 'h', now() - interval '40 days', false, false),
  ('G3', 'h', now() - interval '40 days', true, false),
  ('G4', 'h', now() - interval '2 days', false, true);
insert into public.group_members (group_id, member_key, user_id, status, joined_at, hlc, deleted) values
  ('G1', 'a', '33333333-0000-0000-0000-000000000001', 'active', now() - interval '1 day', 'h', false),
  ('G1', 'b', '33333333-0000-0000-0000-000000000002', 'active', now() - interval '30 days', 'h', false),
  ('G1', 'c', null, 'active', now(), 'h', false),
  ('G2', 'd', '33333333-0000-0000-0000-000000000003', 'removed', now(), 'h', false);
insert into public.split_expenses (group_id, sync_id, created_at, hlc, deleted) values
  ('G1', gen_random_uuid(), now(), 'h', false),
  ('G2', gen_random_uuid(), now() - interval '20 days', 'h', false),
  ('G2', gen_random_uuid(), now(), 'h', true);
insert into public.group_invites (token, group_id, created_at, uses) values
  ('t1', 'G1', now(), 1), ('t2', 'G1', now(), 0), ('t3', 'G2', now() - interval '30 days', 3);
insert into public.push_tokens (user_id, device_token) values
  ('33333333-0000-0000-0000-000000000001', 'tok1'), ('33333333-0000-0000-0000-000000000002', 'tok2');
SQL

q -1 -f "$MIG" >/dev/null 2>&1
q -1 -f "$MIG" >/dev/null 2>&1   # idempotente

fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1: esperado «$3», salió «$2»"; fail=1; fi; }

expected='{"expenses_7d": 1, "push_devices": 2, "groups_new_7d": 1, "groups_total": 2, "members_active": 2, "invites_used_7d": 1, "groups_active_7d": 1, "accounts_complete": 2, "members_joined_7d": 1, "invites_created_7d": 2, "accounts_groups_only": 1}'
got="$(q -c "select public.yala_stats_counts() = '$expected'::jsonb")"
check "conteos" "$got" "t"
[ "$got" = "t" ] || q -c "select public.yala_stats_counts()::text"

# yala_stats puede llamar a la función y NO puede leer ninguna tabla.
check "yala_stats ejecuta" "$(q -c "set role yala_stats; select (public.yala_stats_counts()->>'groups_total')")" "2"
if q -c "set role yala_stats; select count(*) from public.split_groups" >/dev/null 2>&1; then
  echo "FAIL yala_stats lee split_groups"; fail=1; else echo "PASS yala_stats no lee tablas"; fi
# Un usuario normal no puede ejecutarla.
if q -c "set role authenticated; select public.yala_stats_counts()" >/dev/null 2>&1; then
  echo "FAIL authenticated ejecuta la función"; fail=1; else echo "PASS authenticated no ejecuta"; fi
if q -c "set role anon; select public.yala_stats_counts()" >/dev/null 2>&1; then
  echo "FAIL anon ejecuta la función"; fail=1; else echo "PASS anon no ejecuta"; fi

q -1 -f "$RB" >/dev/null
check "rollback quita la función" "$(q -c "select count(*) from pg_proc where proname = 'yala_stats_counts'")" "0"
check "rollback quita el rol" "$(q -c "select count(*) from pg_roles where rolname = 'yala_stats'")" "0"

[ "$fail" = 0 ] && echo "tel01: TODO VERDE" || { echo "tel01: HAY ROJOS"; exit 1; }
