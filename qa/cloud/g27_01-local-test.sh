#!/usr/bin/env bash
# =====================================================================================================
# g27_01 · banco LOCAL del candado de saldos iniciales (solo el dueño o un admin activo), sin tocar staging ni prod.
#
# Levanta un Postgres desechable, carga el DDL REAL de Grupos (`supabase-groups-staging.ddl`) con los stubs mínimos de
# Supabase (molde g25_01) y corre `g27_01-battery.sql`, la MISMA batería que `g27_01-remote.sh` corre en staging y en
# producción. Pasos:
#   A. SIN la migración: los casos que el candado cambia tienen que salir distinto (el banco discrimina).
#   B. CON la migración: los 34 casos en verde.
#   C. Re-aplicar la migración: no-op, sigue en verde.
#   D. Rollback: vuelve el comportamiento de A, y es re-ejecutable.
#   E. MUTANTES: copias de la migración con una pieza quitada; cada una TIENE que tumbar algún caso.
#
# Uso:  bash qa/cloud/g27_01-local-test.sh   → «g27_01 banco local: todo en verde», exit 0 solo si todo pasa.
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MIG="$HERE/g27_01_opening_balance_managers.sql"
RB="$HERE/g27_01_rollback.sql"
BAT="$HERE/g27_01-battery.sql"
DDL="$ROOT/supabase-groups-staging.ddl"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
[ -x "$PGBIN/initdb" ] || { echo "g27_01: no encuentro initdb en $PGBIN (exporta PGBIN)"; exit 2; }
command -v jq >/dev/null || { echo "g27_01: hace falta jq"; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/g27_01.XXXXXX")"
PORT="${PORT:-55427}"
trap '"$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust -E UTF8 --no-locale >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c listen_addresses=127.0.0.1 -c unix_socket_directories=''" \
  -l "$WORK/log" -w start >/dev/null

export PGOPTIONS="-c client_min_messages=warning"
q() { "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X "$@"; }

# --- stubs de Supabase (molde g25_01) ------------------------------------------------------------------------------
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
create table public.profiles (id uuid primary key);
SQL

q -1 -f "$DDL" >"$WORK/ddl.out" 2>&1 || { echo "g27_01: el DDL de Grupos no cargó:"; grep -v NOTICE "$WORK/ddl.out"; exit 1; }
# El DDL deja las SELECT de contenido en `is_group_member`; las vivas (staging y prod, medido 2026-10-31) piden
# `is_group_writer`. El banco usa las vivas: es lo que decide qué ve `apply_group_delta` de un ex-miembro.
q <<'SQL'
alter policy split_expenses_select on public.split_expenses using (is_group_writer(group_id));
alter policy split_shares_select on public.split_shares using (is_group_writer(group_id));
alter policy split_settlements_select on public.split_settlements using (is_group_writer(group_id));
SQL

# Corre la batería y devuelve el JSON de resultados (la batería siempre aborta con G27_RESULTS:<json>).
battery() {
  local out
  out=$("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -X -q -f "$BAT" 2>&1 || true)
  if ! grep -q 'G27_RESULTS:' <<<"$out"; then
    echo "g27_01: la batería no devolvió resultados:" >&2; echo "$out" >&2; return 1
  fi
  sed -nE 's/.*G27_RESULTS:(.*)$/\1/p' <<<"$out" | head -1
}

fallos=0
ok()  { echo "  ✓ $1"; }
mal() { echo "  ✗ $1"; fallos=$((fallos + 1)); }

# Casos que el candado cambia: sin él tienen que salir distinto de lo esperado.
CAMBIAN="1 6 7 8 9 10 11 12 13 17 19 20 21 22 23 32 33"

echo "A. sin la migración: el banco discrimina"
# El molde ya trae §11 (g27_01 aplicada en los dos entornos): se quita para medir el «antes».
q -1 -f "$RB"
R=$(battery)
for n in $CAMBIAN; do
  v=$(jq -r ".[] | select(.n == $n) | .ok" <<<"$R")
  if [ "$v" = "false" ]; then ok "caso $n sale distinto sin el candado"; else mal "caso $n pasa sin el candado: no discrimina"; fi
done

echo "B. con la migración: todo en verde"
q -1 -f "$MIG"
R=$(battery)
total=$(jq 'length' <<<"$R")
jq -r '.[] | "\(if .ok then "  ✓" else "  ✗" end) \(.n). \(.label) — esperado «\(.expected)», salió «\(.got)»"' <<<"$R"
malos=$(jq '[.[] | select(.ok | not)] | length' <<<"$R")
[ "$total" = "34" ] || mal "la batería tiene $total casos, no 34"
[ "$malos" = "0" ] || fallos=$((fallos + malos))

echo "C. re-aplicar la migración: no-op"
q -1 -f "$MIG"
malos=$(battery | jq '[.[] | select(.ok | not)] | length')
[ "$malos" = "0" ] && ok "sigue en verde tras re-aplicar" || mal "re-aplicar deja $malos casos en rojo"
n_trg=$(q -tA -c "select count(*) from pg_trigger where tgname = 'opening_balance_guard'")
[ "$n_trg" = "2" ] && ok "dos triggers, ni uno más" || mal "hay $n_trg triggers opening_balance_guard"
grant=$(q -tA -c "select has_function_privilege('authenticated', 'public.opening_balance_guard()', 'execute')")
[ "$grant" = "f" ] && ok "authenticated no puede llamar a la función del trigger" || mal "authenticated puede ejecutar la función"

echo "D. rollback"
q -1 -f "$RB"
R=$(battery)
for n in $CAMBIAN; do
  v=$(jq -r ".[] | select(.n == $n) | .ok" <<<"$R")
  [ "$v" = "false" ] || mal "tras el rollback el caso $n sigue con el candado"
done
n_trg=$(q -tA -c "select count(*) from pg_trigger where tgname = 'opening_balance_guard'")
n_fn=$(q -tA -c "select count(*) from pg_proc where proname = 'opening_balance_guard'")
[ "$n_trg$n_fn" = "00" ] && ok "rollback: sin triggers ni función, comportamiento de antes" || mal "rollback deja $n_trg triggers y $n_fn funciones"
q -1 -f "$RB" && ok "rollback re-ejecutable"

echo "E. mutantes: cada uno tumba algún caso"
mutante() {  # $1 nombre · $2 texto a quitar/cambiar (python: viejo) · $3 nuevo
  local f="$WORK/mut.sql"
  python3 - "$MIG" "$f" "$2" "$3" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
s = open(src).read()
assert old in s, f"el mutante no encuentra su pieza: {old!r}"
open(dst, "w").write(s.replace(old, new, 1))
PY
  q -1 -f "$RB"
  q -1 -f "$f"
  local caidos
  local R
  if R=$(battery 2>/dev/null); then
    caidos=$(jq -r '[.[] | select(.ok | not) | .n] | join(",")' <<<"$R")
  else
    caidos="la siembra entera"  # el mutante juzga hasta al dueño de la BD sin sesión
  fi
  if [ -n "$caidos" ]; then ok "mutante «$1» cae (casos $caidos)"; else mal "mutante «$1» SOBREVIVE"; fi
}
mutante "sin el dueño"                 "v_owner is not distinct from v_uid or " ""
mutante "sin el admin"                 " or is_group_admin(v_gid)" ""
mutante "sin el grupo cerrado"         "if not found or v_gdeleted then" "if false then"
mutante "sin el bloqueo por pago"      "foreach v_exp in array v_lock_exps loop" "foreach v_exp in array array[]::uuid[] loop"
mutante "sin la exención del 1.er reparto" "and (tg_op = 'UPDATE'" "and (true or tg_op = 'UPDATE'"
mutante "sin el OLD del gasto"         "or (tg_op = 'UPDATE' and coalesce(old.is_opening_balance, false))" ""
mutante "sin el gasto de origen del reparto" "v_is_ob := coalesce(v_new_ob, false) or coalesce(v_old_ob, false);" "v_is_ob := coalesce(v_new_ob, false);"
mutante "sin juzgar el saldo de origen" "      v_lock_exps := v_lock_exps || old.expense_id;" ""
mutante "sin la exención del reenvío" "if tg_op = 'UPDATE' and old.deleted and new.deleted then" "if false then"
mutante "con la arista NUEVA del gasto" "      v_lock_exps := array[new.sync_id];" "      v_lock_exps := array[new.sync_id]; v_extra := array[new.paid_by_member_key];"
mutante "sin el paso de quien no es miembro" "if not is_group_writer(v_gid) then" "if false then"
mutante "pagos borrados también bloquean" "st.deleted = false and " ""
mutante "pagos sin confirmar también bloquean" "and st.is_confirmed is true" ""
q -1 -f "$RB"

echo
if [ "$fallos" = "0" ]; then echo "g27_01 banco local: todo en verde"; else echo "g27_01 banco local: $fallos fallos"; exit 1; fi
