-- web3_02_grupos_escritura (2026-11-14, lote 3 de Yala web — SOLO STAGING)
--
-- DECISIÓN. Jürgen eligió la opción A el 14-nov (13:52): la web escribe en Grupos con un permiso PROPIO, por el
-- gateway, solo en staging hasta una revisión. Esto es ese permiso.
--
-- QUÉ HACE.
--   1. Rol nuevo `yala_web`, sin login, MIEMBRO de `yala_mcp_reader`: hereda todo lo que la web ya lee (grants y
--      políticas de mcp0_01, web1_01 y web3_01, que van `to yala_mcp_reader` y Postgres aplica también a sus
--      miembros). PostgREST entra con él porque `authenticator` es miembro.
--   2. El hook de token (`yala_mcp_access_token_hook`, cuerpo de web0_01) da `role = yala_web` a los tokens de la web.
--      Los del conector de Claude siguen en `yala_mcp_reader`: el conector no gana nada.
--   3. Lo que `yala_web` puede y `yala_mcp_reader` no, y nada más: EXECUTE de `web_add_group_expense` (un gasto NUEVO con
--      sus cuotas), `web_add_group_settlement` (un pago NUEVO) y `create_group_invite`. Ver la sección 3. Ningún permiso
--      de tabla nuevo: ni INSERT, ni UPDATE, ni DELETE. Editar y borrar siguen en el iPhone.
--   Las columnas cifradas necesitan la llave de Grupos, que solo tiene el gateway: con el token a solas no se puede
--   escribir un gasto legible. La lista cerrada de operaciones vive en el gateway (`gateway/src/web/groupsWriter.ts`).
--
-- PRODUCCIÓN: NO. Tras la revisión que pidió Jürgen, con los ids de producción. Marcha atrás: web3_02_rollback.sql.
-- Guarda: el hook tiene que ser el de web0_01 (o este mismo).

do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null then
    raise exception 'web3_02: no está el hook de token. No se toca.';
  end if;
  if position('yala_mcp_reader' in (select p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook')) = 0 then
    raise exception 'web3_02: el hook no es el de web0_01 (md5 %). No se toca.', cur;
  end if;
end $$;

-- 1 · El rol -------------------------------------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'yala_web') then
    create role yala_web nologin inherit;
  end if;
end $$;
-- INHERIT (Postgres 17: la pertenencia hereda según el rol miembro): recibe los grants y las políticas del lector.
grant yala_mcp_reader to yala_web;
grant yala_web to authenticator;
grant usage on schema public to yala_web;

-- 2 · El hook ------------------------------------------------------------------------------------------------------
create or replace function public.yala_mcp_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  worker_client constant uuid := '65fb5767-59a5-4f50-b77c-7970e67589c5';
  web_client constant uuid := '03e0f13b-818f-4a93-8e69-701ea6343fda';
  claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  claim_cid text := nullif(claims->>'client_id', '');
  sid text := nullif(claims->>'session_id', '');
  session_cid uuid;
begin
  -- El cliente OAuth persiste en la sesión (mcp0_03): un token reemitido sin el claim client_id sigue siendo del mismo
  -- cliente. Solo se lee si el session_id tiene forma de uuid. Un fallo de la lectura propaga (falla cerrado).
  if sid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select s.oauth_client_id into session_cid from auth.sessions s where s.id = sid::uuid;
  end if;

  -- Ni el claim ni la sesión traen cliente: login normal de la app. Intacto.
  if claim_cid is null and session_cid is null then
    return jsonb_build_object('claims', claims);
  end if;

  -- Yala web: su rol propio (lee como el conector y añade en Grupos; web3_02).
  if claim_cid = web_client::text or session_cid = web_client then
    return jsonb_build_object('claims', jsonb_set(claims, '{role}', to_jsonb('yala_web'::text)));
  end if;

  -- El conector de Claude: solo lectura.
  if claim_cid = worker_client::text or session_cid = worker_client then
    return jsonb_build_object('claims', jsonb_set(claims, '{role}', to_jsonb('yala_mcp_reader'::text)));
  end if;

  -- Cualquier otro cliente OAuth: sin token. GoTrue devuelve este error antes de firmar nada.
  return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', 'Este cliente no puede conectarse a Yala.'));
end;
$$;

grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;

-- 3 · Lo que añade -------------------------------------------------------------------------------------------------
-- Dos funciones SECURITY DEFINER, una por operación: `web_add_group_expense` (un gasto con sus cuotas) y
-- `web_add_group_settlement` (un pago). Por qué así y no INSERT + RLS para el rol: `apply_group_delta` es SECURITY
-- INVOKER y llama a `auth.uid()`, y el esquema `auth` es de `supabase_admin`: `postgres` no puede dar USAGE sobre él a un
-- rol nuevo (medido en staging el 14-nov: el GRANT no hace nada y la llamada da «permission denied for schema auth»).
-- Desde una función del dueño `auth.uid()` sí se lee. Dentro la RLS NO actúa, así que cada función comprueba antes todo
-- lo que haría falta, y lo escribe todo o nada (una llamada = una transacción):
--   - token del cliente web (`yala_is_web_reader`), miembro activo del grupo (`is_group_writer`), grupo vivo y no
--     archivado;
--   - el id es NUEVO en TODOS los grupos, no solo en este. La clave es (group_id, sync_id), pero el iPhone busca gastos y
--     pagos solo por id (`GroupsSyncClient`): un id repetido en otro grupo movería esa fila de grupo en los teléfonos
--     (revisión adversarial del 14-nov). Si ya existe en este grupo, `noop` con motivo `exists` (un reenvío);
--   - un gasto solo nace con sus cuotas, en la misma llamada: cuotas de ese gasto, de miembros activos, que suman su
--     importe; nada de saldo inicial. Así no se pueden colgar cuotas de un gasto que ya existe ni dejar uno a medias;
--   - un pago, entre dos miembros activos distintos y con importe positivo;
--   - el resto lo hace `apply_group_delta`, la misma función que usa el iPhone (cifrado, relojes, triggers).

-- Converge desde las versiones aplicadas antes en staging el 14-nov (INSERT + RLS para el rol, y luego una función
-- genérica `web_add_group_row`), que se retiraron.
drop policy if exists web_writer_insert on public.split_expenses;
drop policy if exists web_writer_insert on public.split_shares;
drop policy if exists web_writer_insert on public.split_settlements;
revoke insert on public.split_expenses, public.split_shares, public.split_settlements from yala_web;
revoke execute on function public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer) from yala_web;
revoke usage on schema auth, extensions from yala_web;
drop function if exists public.web_add_group_row(text, text, uuid, jsonb, jsonb, text, text);

-- Lo común: quién llama y a qué grupo. Sin EXECUTE para nadie: solo la llaman las dos de abajo (mismo dueño).
create or replace function public.web_group_write_guard(p_group_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select auth.uid()) is null or not public.yala_is_web_reader() then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  if p_group_id is null
     or not public.is_group_writer(p_group_id)
     or not exists (select 1 from public.split_groups g
                    where g.group_id = p_group_id and g.deleted = false and coalesce(g.is_archived, false) = false) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
end;
$$;
revoke execute on function public.web_group_write_guard(text) from public, anon, authenticated, yala_mcp_reader, yala_web;

-- ¿Es miembro activo del grupo esa clave?
create or replace function public.web_group_active_member(p_group_id text, p_member_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.group_members m
                 where m.group_id = p_group_id and m.member_key = p_member_key and m.deleted = false and m.status = 'active')
$$;
revoke execute on function public.web_group_active_member(text, text) from public, anon, authenticated, yala_mcp_reader, yala_web;

create or replace function public.web_add_group_expense(
  p_group_id text,
  p_expense_id uuid,
  p_fields jsonb,
  p_field_hlcs jsonb,
  p_shares jsonb,
  p_key text,
  p_row_hlc text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_amount numeric;
  v_sum numeric := 0;
  v_share jsonb;
  v_sid uuid;
  v_gshare jsonb;
  v_seen text[] := array[]::text[];
  v_r jsonb;
begin
  perform public.web_group_write_guard(p_group_id);
  if p_expense_id is null or jsonb_typeof(p_shares) is distinct from 'array'
     or jsonb_array_length(p_shares) < 1 or jsonb_array_length(p_shares) > 50 then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('split_expenses|' || p_expense_id::text, 0));
  if exists (select 1 from public.split_expenses e where e.sync_id = p_expense_id) then
    if exists (select 1 from public.split_expenses e where e.sync_id = p_expense_id and e.group_id = p_group_id) then
      return jsonb_build_object('op', 'upsert', 'noop', true, 'reason', 'exists');
    end if;
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  v_amount := (p_fields -> 'gmoney' ->> 'amount')::numeric;
  if v_amount is null or v_amount <= 0
     or coalesce((p_fields -> 'is_opening_balance' ->> 'is_opening_balance')::boolean, false)
     or not public.web_group_active_member(p_group_id, p_fields -> 'paid_by_member_key' ->> 'paid_by_member_key') then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  for v_share in select value from jsonb_array_elements(p_shares) loop
    v_sid := (v_share ->> 'sync_id')::uuid;
    v_gshare := v_share -> 'fields' -> 'gshare';
    if v_sid is null or v_gshare is null
       or (v_gshare ->> 'expense_id')::uuid is distinct from p_expense_id
       or (v_gshare ->> 'member_key') = any (v_seen)
       or not public.web_group_active_member(p_group_id, v_gshare ->> 'member_key')
       or (v_gshare ->> 'amount')::numeric < 0
       or exists (select 1 from public.split_shares s where s.sync_id = v_sid) then
      raise exception 'yala_bad_request' using errcode = 'P0001';
    end if;
    v_seen := array_append(v_seen, v_gshare ->> 'member_key');
    v_sum := v_sum + (v_gshare ->> 'amount')::numeric;
  end loop;
  if abs(v_sum - v_amount) > 0.005 then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  v_r := public.apply_group_delta('split_expenses', p_group_id, p_expense_id, 'upsert', p_fields, p_field_hlcs, p_key, p_row_hlc, 1);
  if coalesce((v_r ->> 'noop')::boolean, false) then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;
  for v_share in select value from jsonb_array_elements(p_shares) loop
    v_r := public.apply_group_delta('split_shares', p_group_id, (v_share ->> 'sync_id')::uuid, 'upsert',
                                    v_share -> 'fields', v_share -> 'field_hlcs', p_key, p_row_hlc, 1);
    if coalesce((v_r ->> 'noop')::boolean, false) then
      raise exception 'yala_bad_request' using errcode = 'P0001';
    end if;
  end loop;
  return jsonb_build_object('op', 'upsert', 'noop', false, 'inserted', true, 'shares', jsonb_array_length(p_shares));
end;
$$;

create or replace function public.web_add_group_settlement(
  p_group_id text,
  p_sync_id uuid,
  p_fields jsonb,
  p_field_hlcs jsonb,
  p_key text,
  p_row_hlc text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_from text := p_fields -> 'from_member_key' ->> 'from_member_key';
  v_to text := p_fields -> 'to_member_key' ->> 'to_member_key';
  v_r jsonb;
begin
  perform public.web_group_write_guard(p_group_id);
  if p_sync_id is null then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('split_settlements|' || p_sync_id::text, 0));
  if exists (select 1 from public.split_settlements s where s.sync_id = p_sync_id) then
    if exists (select 1 from public.split_settlements s where s.sync_id = p_sync_id and s.group_id = p_group_id) then
      return jsonb_build_object('op', 'upsert', 'noop', true, 'reason', 'exists');
    end if;
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  if v_from is null or v_to is null or v_from = v_to
     or not public.web_group_active_member(p_group_id, v_from)
     or not public.web_group_active_member(p_group_id, v_to)
     or coalesce((p_fields -> 'smoney' ->> 'amount')::numeric, 0) <= 0 then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  v_r := public.apply_group_delta('split_settlements', p_group_id, p_sync_id, 'upsert', p_fields, p_field_hlcs, p_key, p_row_hlc, 1);
  if coalesce((v_r ->> 'noop')::boolean, false) then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;
  return jsonb_build_object('op', 'upsert', 'noop', false, 'inserted', true);
end;
$$;

revoke execute on function public.web_add_group_expense(text, uuid, jsonb, jsonb, jsonb, text, text) from public, anon, authenticated, yala_mcp_reader;
revoke execute on function public.web_add_group_settlement(text, uuid, jsonb, jsonb, text, text) from public, anon, authenticated, yala_mcp_reader;
grant execute on function public.web_add_group_expense(text, uuid, jsonb, jsonb, jsonb, text, text) to yala_web;
grant execute on function public.web_add_group_settlement(text, uuid, jsonb, jsonb, text, text) to yala_web;

-- Invitar: `create_group_invite` ya es SECURITY DEFINER y decide quién puede (admin, o «miembros pueden invitar»).
grant execute on function public.create_group_invite(text, integer, integer) to yala_web;
