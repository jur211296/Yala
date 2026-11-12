#!/usr/bin/env bash
# =====================================================================================================
# g30_01 · banco LOCAL del autor de un gasto editado desde un teléfono que no lo conoce, sin tocar staging ni prod.
#
# Levanta un Postgres desechable, carga el DDL REAL de Grupos (`supabase-groups-staging.ddl`) con los stubs mínimos de
# Supabase (molde g27_01) y corre una batería que llama a `apply_group_delta` como lo llama el gateway (rol
# `authenticated`, el `sub` en los claims), con las unidades reales del manifest. Pasos:
#   A. SIN la migración: los casos que el trigger cambia salen con el autor VIEJO; los demás, igual (control).
#   B. CON la migración: todos los casos en verde.
#   C. Re-aplicar la migración: no-op, sigue en verde, un trigger, sin EXECUTE para authenticated.
#   D. Rollback: vuelve el comportamiento de A, y es re-ejecutable.
#   E. MUTANTES: copias de la migración con una pieza quitada o cambiada; cada una TIENE que tumbar algún caso.
#
# La batería es un bloque DO que acaba SIEMPRE en `raise exception 'G30_RESULTS:<json>'`: no hace commit de nada.
# Uso:  bash qa/cloud/g30_01-local-test.sh   → «g30_01 banco local: todo en verde», exit 0 solo si todo pasa.
# =====================================================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MIG="$HERE/g30_01_expense_author_from_v2_clients.sql"
RB="$HERE/g30_01_rollback.sql"
DDL="$ROOT/supabase-groups-staging.ddl"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@17/bin}"
[ -x "$PGBIN/initdb" ] || { echo "g30_01: no encuentro initdb en $PGBIN (exporta PGBIN)"; exit 2; }
command -v jq >/dev/null || { echo "g30_01: hace falta jq"; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/g30_01.XXXXXX")"
PORT="${PORT:-55430}"
trap '"$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust -E UTF8 --no-locale >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -c listen_addresses=127.0.0.1 -c unix_socket_directories=''" \
  -l "$WORK/log" -w start >/dev/null

export PGOPTIONS="-c client_min_messages=warning"
q() { "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X "$@"; }

# --- stubs de Supabase (molde g25_01 / g27_01) -------------------------------------------------------------------
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

q -1 -f "$DDL" >"$WORK/ddl.out" 2>&1 || { echo "g30_01: el DDL de Grupos no cargó:"; grep -v NOTICE "$WORK/ddl.out"; exit 1; }
# Las SELECT de contenido vivas piden `is_group_writer` (medido 2026-10-31, molde g27_01).
q <<'SQL'
alter policy split_expenses_select on public.split_expenses using (is_group_writer(group_id));
alter policy split_shares_select on public.split_shares using (is_group_writer(group_id));
alter policy split_settlements_select on public.split_settlements using (is_group_writer(group_id));
SQL

# --- la batería ----------------------------------------------------------------------------------------------------
# Resultado por caso: «<estado del RPC>/<autor>», con el autor como A, B, C o NULL. Las HLC son de febrero de 2026
# (pasado: el tope de hlc01 no las toca) salvo los casos 20-21, que van a 2099 para pasar por `cap_future_hlc`.
cat >"$WORK/battery.sql" <<'SQL'
create function pg_temp.h(p_s int, p_node text) returns text language sql immutable as $f$
  select format('2026-02-01T00:00:%s.000Z-0000-00000000000000%s', lpad(p_s::text, 2, '0'), p_node) $f$;

create function pg_temp.fh(p_units jsonb, p_hlc text) returns jsonb language sql immutable as $f$
  select coalesce(jsonb_object_agg(k, p_hlc), '{}'::jsonb) from jsonb_object_keys(p_units) k $f$;

create function pg_temp.author(p_sid uuid) returns text language sql stable as $f$
  select case last_edited_by_member_key
           when '30300000-0000-4000-8000-00000000000a' then 'A'
           when '30300000-0000-4000-8000-00000000000b' then 'B'
           when '30300000-0000-4000-8000-00000000000c' then 'C'
           else coalesce(last_edited_by_member_key, 'NULL') end
  from public.split_expenses where group_id = 'SplitGroup-g30' and sync_id = p_sid $f$;

create function pg_temp.with_author(p_units jsonb, p_author uuid) returns jsonb language sql immutable as $f$
  select p_units || jsonb_build_object('last_edited_by_member_key',
                                       jsonb_build_object('last_edited_by_member_key', p_author::text)) $f$;

-- El alta completa de un gasto, como la emite la app (todas las unidades del manifest de split_expenses).
create function pg_temp.full_units(p_payer uuid) returns jsonb language sql immutable as $f$
  select jsonb_build_object(
    'gmoney', jsonb_build_object('amount', 40, 'currency_code', 'USD'),
    'expense_description', jsonb_build_object('expense_description', 'Cena'),
    'note', jsonb_build_object('note', 'nota'),
    'date', jsonb_build_object('date', '2026-02-01T00:00:00Z'),
    'created_at', jsonb_build_object('created_at', '2026-02-01T00:00:00Z'),
    'paid_by_member_key', jsonb_build_object('paid_by_member_key', p_payer::text),
    'split_type', jsonb_build_object('split_type', 'equal'),
    'is_settled', jsonb_build_object('is_settled', false),
    'is_opening_balance', jsonb_build_object('is_opening_balance', false),
    'subcategory_name', jsonb_build_object('subcategory_name', 'Comida')) $f$;

-- La edición de UNA unidad, como la subiría un teléfono 2.1 (sin la del autor).
create function pg_temp.unit_edit(p_unit text) returns jsonb language sql immutable as $f$
  select (case p_unit
    when 'gmoney'              then '{"gmoney":{"amount":55,"currency_code":"USD"}}'
    when 'expense_description' then '{"expense_description":{"expense_description":"Cena larga"}}'
    when 'note'                then '{"note":{"note":"otra nota"}}'
    when 'date'                then '{"date":{"date":"2026-02-02T00:00:00Z"}}'
    when 'paid_by_member_key'  then '{"paid_by_member_key":{"paid_by_member_key":"30300000-0000-4000-8000-00000000000b"}}'
    when 'split_type'          then '{"split_type":{"split_type":"exact"}}'
    when 'subcategory_name'    then '{"subcategory_name":{"subcategory_name":"Cine"}}'
    when 'is_settled'          then '{"is_settled":{"is_settled":true}}'
    when 'created_at'          then '{"created_at":{"created_at":"2026-01-31T00:00:00Z"}}'
  end)::jsonb $f$;

-- `apply_group_delta` como lo llama el gateway: rol `authenticated` y el `sub` en los claims.
create function pg_temp.push(p_who uuid, p_sid uuid, p_op text, p_units jsonb, p_fh jsonb, p_row_hlc text default null)
returns text language plpgsql as $f$
declare
  v jsonb;
  v_role text := current_setting('role');
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_who, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    v := public.apply_group_delta('split_expenses', 'SplitGroup-g30', p_sid, p_op, p_units, p_fh, 'k', p_row_hlc);
  exception when others then
    perform set_config('role', v_role, true);
    perform set_config('request.jwt.claims', '', true);
    return 'err:' || sqlerrm;
  end;
  perform set_config('role', v_role, true);
  perform set_config('request.jwt.claims', '', true);
  return case when coalesce((v ->> 'noop')::boolean, false) then 'noop:' || coalesce(v ->> 'reason', '?') else 'applied' end;
end $f$;

-- A (app 2.2) crea el gasto con su autor en t01.
create function pg_temp.seed(p_sid uuid) returns text language sql as $f$
  select pg_temp.push('30300000-0000-4000-8000-00000000000a', p_sid, 'upsert',
                      pg_temp.with_author(pg_temp.full_units('30300000-0000-4000-8000-00000000000a'),
                                          '30300000-0000-4000-8000-00000000000a'),
                      pg_temp.fh(pg_temp.with_author(pg_temp.full_units('30300000-0000-4000-8000-00000000000a'),
                                                     '30300000-0000-4000-8000-00000000000a'), pg_temp.h(1, 'aa'))) $f$;

-- Una fila cuyo autor ya quedó desfasado ANTES de g30_01: el importe en t04 (edición 2.1) y el autor A en t01.
create function pg_temp.seed_stale(p_sid uuid) returns void language sql as $f$
  insert into public.split_expenses (group_id, sync_id, paid_by_member_key, split_type, is_settled, is_opening_balance,
                                     deleted, hlc, field_hlcs, last_edited_by_member_key)
  values ('SplitGroup-g30', p_sid, '30300000-0000-4000-8000-00000000000a', 'equal', false, false, false,
          pg_temp.h(4, 'bb'),
          jsonb_build_object('gmoney', pg_temp.h(4, 'bb'), 'paid_by_member_key', pg_temp.h(1, 'aa'),
                             'split_type', pg_temp.h(1, 'aa'), 'is_settled', pg_temp.h(1, 'aa'),
                             'last_edited_by_member_key', pg_temp.h(1, 'aa')),
          '30300000-0000-4000-8000-00000000000a') $f$;

do $battery$
declare
  g1  text := 'SplitGroup-g30';
  h0  text := '2026-01-01T00:00:00.000Z-0000-0000000000000000';
  u_a uuid := '30300000-0000-4000-8000-00000000000a';
  u_b uuid := '30300000-0000-4000-8000-00000000000b';
  u_c uuid := '30300000-0000-4000-8000-00000000000c';
  fh0 jsonb := jsonb_build_object('profile', '2026-01-01T00:00:00.000Z-0000-0000000000000000',
                                  'membership', '2026-01-01T00:00:00.000Z-0000-0000000000000000');
  form_units text[] := array['gmoney', 'expense_description', 'note', 'date', 'paid_by_member_key', 'split_type',
                             'subcategory_name'];
  res jsonb := '[]'::jsonb;
  e   uuid;
  s0  text;
  st  text;
  got text;
  i   int;
  v_units jsonb;
  hf  text := '2099-01-01T00:00:00.000Z-0000-00000000000000bb';
begin
  insert into auth.users (id) values (u_a), (u_b), (u_c);
  insert into public.split_groups (group_id, owner_user_id, deleted, hlc, field_hlcs) values (g1, u_a, false, h0, fh0);
  insert into public.group_members (group_id, member_key, user_id, role, status, deleted, hlc, field_hlcs) values
    (g1, u_a::text, u_a, 'admin',  'active', false, h0, fh0),
    (g1, u_b::text, u_b, 'member', 'active', false, h0, fh0),
    (g1, u_c::text, u_c, 'member', 'active', false, h0, fh0);

  -- 1-7. B edita desde 2.1 UNA unidad del formulario (sin la del autor) → el autor pasa a NULL.
  for i in 1 .. 7 loop
    e := gen_random_uuid(); s0 := pg_temp.seed(e);
    v_units := pg_temp.unit_edit(form_units[i]);
    st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(2, 'bb')));
    got := case when s0 <> 'applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end;
    res := res || jsonb_build_object('n', i, 'label', 'edición 2.1 de ' || form_units[i] || ' → autor NULL',
                                     'expected', 'applied/NULL', 'got', got);
  end loop;

  -- 8. B edita desde 2.2: importe + su autor, mismo HLC → autor B.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.with_author(pg_temp.unit_edit('gmoney'), u_b);
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(2, 'bb')));
  res := res || jsonb_build_object('n', 8, 'label', 'edición 2.2 (importe + autor B) → autor B',
    'expected', 'applied/B', 'got', case when s0 <> 'applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  -- 9-10. B cambia desde 2.1 algo que no es el formulario → el autor se queda.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.unit_edit('is_settled');
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(2, 'bb')));
  res := res || jsonb_build_object('n', 9, 'label', 'edición 2.1 de solo is_settled → autor A intacto',
    'expected', 'applied/A', 'got', case when s0 <> 'applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.unit_edit('created_at');
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(2, 'bb')));
  res := res || jsonb_build_object('n', 10, 'label', 'edición 2.1 de solo created_at → autor A intacto',
    'expected', 'applied/A', 'got', case when s0 <> 'applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  -- 11. B borra el gasto → el autor se queda (y queda borrado).
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  st := pg_temp.push(u_b, e, 'tombstone', '{}'::jsonb, '{}'::jsonb, pg_temp.h(2, 'bb'));
  res := res || jsonb_build_object('n', 11, 'label', 'tombstone → autor A intacto',
    'expected', 'applied/A/borrado', 'got', case when s0 <> 'applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e)
      || (select case when deleted then '/borrado' else '/vivo' end from public.split_expenses where group_id = g1 and sync_id = e) end);

  -- 12. Un delta 2.1 que PIERDE el LWW entero: A editó el importe en t05; B manda el suyo de t03 → no-op, autor A.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.with_author(pg_temp.unit_edit('gmoney'), u_a);
  s0 := s0 || '+' || pg_temp.push(u_a, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(5, 'aa')));
  v_units := pg_temp.unit_edit('gmoney');
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(3, 'bb')));
  res := res || jsonb_build_object('n', 12, 'label', 'delta 2.1 que pierde el LWW entero → no-op, autor A intacto',
    'expected', 'noop:all_units_stale/A',
    'got', case when s0 <> 'applied+applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  -- 13. El mismo, con una unidad que SÍ gana (is_settled t06) y el importe que pierde (t03) → UPDATE, autor A intacto.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.with_author(pg_temp.unit_edit('gmoney'), u_a);
  s0 := s0 || '+' || pg_temp.push(u_a, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(5, 'aa')));
  v_units := pg_temp.unit_edit('gmoney') || pg_temp.unit_edit('is_settled');
  st := pg_temp.push(u_b, e, 'upsert', v_units,
                     jsonb_build_object('gmoney', pg_temp.h(3, 'bb'), 'is_settled', pg_temp.h(6, 'bb')));
  res := res || jsonb_build_object('n', 13, 'label', 'delta 2.1 con el importe perdedor y is_settled ganador → autor A intacto',
    'expected', 'applied/A',
    'got', case when s0 <> 'applied+applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  -- 14. Reescritura de columnas por el servidor sin tocar field_hlcs (como `groups_forget_user`) → autor A intacto.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  update public.split_expenses set paid_by_member_key = u_c::text, note = null where group_id = g1 and sync_id = e;
  res := res || jsonb_build_object('n', 14, 'label', 'reescritura de columnas sin field_hlcs → autor A intacto',
    'expected', 'patched/A', 'got', case when s0 <> 'applied' then 'alta:' || s0 else 'patched/' || pg_temp.author(e) end);

  -- 15. Dos ediciones 2.2 desordenadas: C (descripción, t07) llega antes que B (importe, t05). El último editor es C.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.with_author(pg_temp.unit_edit('expense_description'), u_c);
  s0 := s0 || '+' || pg_temp.push(u_c, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(7, 'cc')));
  v_units := pg_temp.with_author(pg_temp.unit_edit('gmoney'), u_b);
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(5, 'bb')));
  res := res || jsonb_build_object('n', 15, 'label', 'edición 2.2 de B (t05) tras la 2.2 de C (t07) → autor C intacto',
    'expected', 'applied/C',
    'got', case when s0 <> 'applied+applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  -- 16. Una edición 2.1 que llega tarde (t05) tras una 2.2 posterior (t07): el último editor sigue siendo C.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.with_author(pg_temp.unit_edit('expense_description'), u_c);
  s0 := s0 || '+' || pg_temp.push(u_c, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(7, 'cc')));
  v_units := pg_temp.unit_edit('gmoney');
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(5, 'bb')));
  res := res || jsonb_build_object('n', 16, 'label', 'edición 2.1 de B (t05) tras la 2.2 de C (t07) → autor C intacto',
    'expected', 'applied/C',
    'got', case when s0 <> 'applied+applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  -- 17. Resurrección desde 2.1: A lo borra en t02 y B lo edita en t03 → vuelve vivo y sin autor.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  s0 := s0 || '+' || pg_temp.push(u_a, e, 'tombstone', '{}'::jsonb, '{}'::jsonb, pg_temp.h(2, 'aa'));
  v_units := pg_temp.unit_edit('gmoney');
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(3, 'bb')));
  res := res || jsonb_build_object('n', 17, 'label', 'resurrección por una edición 2.1 → vivo, autor NULL',
    'expected', 'applied/NULL/vivo', 'got', case when s0 <> 'applied+applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e)
      || (select case when deleted then '/borrado' else '/vivo' end from public.split_expenses where group_id = g1 and sync_id = e) end);

  -- 18. El servidor BAJA el HLC de una unidad del formulario (la normalización de hlc01) → no es avanzar, autor intacto.
  e := gen_random_uuid(); perform pg_temp.seed_stale(e);
  update public.split_expenses set field_hlcs = jsonb_set(field_hlcs, '{gmoney}', to_jsonb(pg_temp.h(3, 'bb')))
   where group_id = g1 and sync_id = e;
  res := res || jsonb_build_object('n', 18, 'label', 'el servidor baja el HLC del importe → autor A intacto',
    'expected', 'patched/A', 'got', 'patched/' || pg_temp.author(e));

  -- 19. Fila desfasada de antes de g30_01 (importe t04 > autor t01): un cambio 2.1 de solo is_settled no la juzga.
  e := gen_random_uuid(); perform pg_temp.seed_stale(e);
  v_units := pg_temp.unit_edit('is_settled');
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(5, 'bb')));
  res := res || jsonb_build_object('n', 19, 'label', 'fila ya desfasada + is_settled 2.1 → autor A intacto',
    'expected', 'applied/A', 'got', st || '/' || pg_temp.author(e));

  -- 20-21. HLC del futuro: `cap_future_hlc` acota todas las unidades del delta igual.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.with_author(pg_temp.unit_edit('gmoney'), u_b);
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, hf));
  res := res || jsonb_build_object('n', 20, 'label', 'edición 2.2 con HLC del futuro (acotado) → autor B',
    'expected', 'applied/B', 'got', case when s0 <> 'applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  v_units := pg_temp.unit_edit('gmoney');
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, hf));
  res := res || jsonb_build_object('n', 21, 'label', 'edición 2.1 con HLC del futuro (acotado) → autor NULL',
    'expected', 'applied/NULL', 'got', case when s0 <> 'applied' then 'alta:' || s0 else st || '/' || pg_temp.author(e) end);

  -- 22. Contrato «un borrado no se juzga»: una escritura que borra Y avanza field_hlcs (ningún escritor de hoy lo hace)
  --     no anula el autor.
  e := gen_random_uuid(); s0 := pg_temp.seed(e);
  update public.split_expenses
     set deleted = true, deleted_hlc = pg_temp.h(9, 'bb'),
         field_hlcs = field_hlcs || jsonb_build_object('gmoney', pg_temp.h(9, 'bb'))
   where group_id = g1 and sync_id = e;
  res := res || jsonb_build_object('n', 22, 'label', 'borrado que además avanza field_hlcs → autor A intacto',
    'expected', 'patched/A', 'got', case when s0 <> 'applied' then 'alta:' || s0 else 'patched/' || pg_temp.author(e) end);

  -- 23-24. INSERT: no se juzga. Un alta 2.1 nace sin autor; una 2.2, con el suyo.
  e := gen_random_uuid();
  v_units := pg_temp.full_units(u_b);
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(2, 'bb')));
  res := res || jsonb_build_object('n', 23, 'label', 'alta 2.1 → autor NULL',
    'expected', 'applied/NULL', 'got', st || '/' || pg_temp.author(e));

  e := gen_random_uuid();
  v_units := pg_temp.with_author(pg_temp.full_units(u_c), u_b);
  st := pg_temp.push(u_b, e, 'upsert', v_units, pg_temp.fh(v_units, pg_temp.h(2, 'bb')));
  res := res || jsonb_build_object('n', 24, 'label', 'alta 2.2 de un gasto que pagó C → autor B',
    'expected', 'applied/B', 'got', st || '/' || pg_temp.author(e));

  res := (select jsonb_agg(x || jsonb_build_object('ok', x ->> 'got' = x ->> 'expected')) from jsonb_array_elements(res) x);
  raise exception 'G30_RESULTS:%', res::text;
end
$battery$;
SQL

# Corre la batería y devuelve el JSON de resultados.
battery() {
  local out
  out=$("$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -X -q -f "$WORK/battery.sql" 2>&1 || true)
  if ! grep -q 'G30_RESULTS:' <<<"$out"; then
    echo "g30_01: la batería no devolvió resultados:" >&2; echo "$out" >&2; return 1
  fi
  sed -nE 's/.*G30_RESULTS:(.*)$/\1/p' <<<"$out" | head -1
}

fallos=0
ok()  { echo "  ✓ $1"; }
mal() { echo "  ✗ $1"; fallos=$((fallos + 1)); }

TOTAL=24
# Casos que el trigger cambia: sin él salen con el autor viejo.
CAMBIAN="1 2 3 4 5 6 7 17 21"

antes() {  # $1 = rótulo. Sin el trigger: los de CAMBIAN salen distinto, el resto igual.
  local R n v want
  R=$(battery)
  [ "$(jq 'length' <<<"$R")" = "$TOTAL" ] || mal "$1: la batería tiene $(jq 'length' <<<"$R") casos, no $TOTAL"
  for n in $(jq -r '.[].n' <<<"$R"); do
    v=$(jq -r ".[] | select(.n == $n) | .ok" <<<"$R")
    if [[ " $CAMBIAN " == *" $n "* ]]; then want=false; else want=true; fi
    if [ "$v" = "$want" ]; then
      if [ "$want" = false ]; then ok "$1: caso $n sale con el autor viejo ($(jq -r ".[] | select(.n == $n) | .got" <<<"$R"))"; fi
    else
      mal "$1: caso $n ok=$v, se esperaba $want — $(jq -r ".[] | select(.n == $n) | .got" <<<"$R")"
    fi
  done
}

echo "A. sin la migración: el banco discrimina (control)"
# El DDL ya trae la §12 (g30_01 aplicada en staging): se quita para medir el «antes».
q -1 -f "$RB"
antes "sin trigger"

echo "B. con la migración: todo en verde"
q -1 -f "$MIG"
R=$(battery)
jq -r '.[] | "\(if .ok then "  ✓" else "  ✗" end) \(.n). \(.label) — esperado «\(.expected)», salió «\(.got)»"' <<<"$R"
total=$(jq 'length' <<<"$R")
malos=$(jq '[.[] | select(.ok | not)] | length' <<<"$R")
[ "$total" = "$TOTAL" ] || mal "la batería tiene $total casos, no $TOTAL"
[ "$malos" = "0" ] || fallos=$((fallos + malos))

echo "C. re-aplicar la migración: no-op"
q -1 -f "$MIG"
malos=$(battery | jq '[.[] | select(.ok | not)] | length')
[ "$malos" = "0" ] && ok "sigue en verde tras re-aplicar" || mal "re-aplicar deja $malos casos en rojo"
n_trg=$(q -tA -c "select count(*) from pg_trigger where tgname = 'expense_author_from_v2_clients'")
[ "$n_trg" = "1" ] && ok "un trigger, ni uno más" || mal "hay $n_trg triggers expense_author_from_v2_clients"
grant=$(q -tA -c "select has_function_privilege('authenticated', 'public.expense_author_from_v2_clients()', 'execute')")
[ "$grant" = "f" ] && ok "authenticated no puede llamar a la función del trigger" || mal "authenticated puede ejecutar la función"
orden=$(q -tA -c "select string_agg(tgname, ',' order by tgname) from pg_trigger where tgrelid = 'public.split_expenses'::regclass and not tgisinternal")
[ "$orden" = "cap_future_hlc,expense_author_from_v2_clients,opening_balance_guard,split_expenses_stamp" ] \
  && ok "orden de disparo: después de cap_future_hlc ($orden)" || mal "orden de triggers inesperado: $orden"

echo "D. rollback"
q -1 -f "$RB"
antes "tras el rollback"
n_trg=$(q -tA -c "select count(*) from pg_trigger where tgname = 'expense_author_from_v2_clients'")
n_fn=$(q -tA -c "select count(*) from pg_proc where proname = 'expense_author_from_v2_clients'")
[ "$n_trg$n_fn" = "00" ] && ok "rollback: sin trigger ni función" || mal "rollback deja $n_trg triggers y $n_fn funciones"
q -1 -f "$RB" && ok "rollback re-ejecutable"

echo "E. mutantes: cada uno tumba algún caso"
mutante() {  # $1 nombre · $2 texto a cambiar · $3 nuevo
  local f="$WORK/mut.sql" caidos R
  python3 - "$MIG" "$f" "$2" "$3" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
s = open(src).read()
assert old in s, f"el mutante no encuentra su pieza: {old!r}"
open(dst, "w").write(s.replace(old, new, 1))
PY
  q -1 -f "$RB"
  q -1 -f "$f"
  if R=$(battery 2>/dev/null); then
    caidos=$(jq -r '[.[] | select(.ok | not) | .n] | join(",")' <<<"$R")
  else
    caidos="la batería entera"
  fi
  if [ -n "$caidos" ]; then ok "mutante «$1» cae (casos $caidos)"; else mal "mutante «$1» SOBREVIVE"; fi
}
mutante "regla literal (el autor no avanzó)" \
  "and coalesce(v_new_fh ->> u, '') collate \"C\" > v_author collate \"C\") then" \
  ") and coalesce(v_new_fh ->> 'last_edited_by_member_key', '') collate \"C\" <= coalesce(v_old_fh ->> 'last_edited_by_member_key', '') collate \"C\" then"
mutante "sin gmoney"              "'gmoney', "              ""
mutante "sin expense_description" "'expense_description', " ""
mutante "sin note"                "'note', "                ""
mutante "sin date"                "'date', "                ""
mutante "sin paid_by_member_key"  "'paid_by_member_key',"   ""
mutante "sin split_type"          "'split_type', "          ""
mutante "sin subcategory_name"    ", 'subcategory_name'"    ""
mutante "is_settled también es formulario" "'subcategory_name'];" "'subcategory_name', 'is_settled'];"
mutante "cambiar en vez de avanzar" \
  "coalesce(v_new_fh ->> u, '') collate \"C\" > coalesce(v_old_fh ->> u, '') collate \"C\"" \
  "coalesce(v_new_fh ->> u, '') is distinct from coalesce(v_old_fh ->> u, '')"
mutante "sin comparar con OLD" \
  "coalesce(v_new_fh ->> u, '') collate \"C\" > coalesce(v_old_fh ->> u, '') collate \"C\"
                and " \
  ""
mutante "sin la exención del borrado" "if new.deleted then" "if false then"
q -1 -f "$RB"

echo
if [ "$fallos" = "0" ]; then echo "g30_01 banco local: todo en verde"; else echo "g30_01 banco local: $fallos fallos"; exit 1; fi
