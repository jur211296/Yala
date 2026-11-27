-- GENERADO por g38_01-remote.sh desde la migración + g38_01_bench_cases.sql. No editar a mano.
begin;
-- =====================================================================================================
-- g38_01 · Compartido (lote 3): crear una persona con su sitio reservado, y entrar por su enlace sin aprobación
--
-- QUÉ GANA EL USUARIO. En Compartido se apunta un gasto con una persona sin crear un grupo. Por dentro una persona es un
-- grupo de dos (`split_groups.is_person`, g37_01). Hasta hoy ese grupo no podía tener DOS miembros antes de que la otra
-- persona entrara: `group_members` es solo de bajada para la app (el manifest lo declara `pull_only` y
-- `apply_group_delta` lo rechaza). Sin el segundo miembro no se puede repartir un gasto con «Marta» ni deberle nada.
--
-- DECISIÓN. Jürgen aprobó la maqueta v2 el 2026-11-26 (13:18 Lima): «invitar: Sí» (el servidor distingue persona de
-- grupo y salta la aprobación) y la entrada sin grupo obligatorio. El cómo (esta migración) lo decidió la sesión del
-- lote 3 porque es la única forma que respeta las reglas del canal: los miembros solo nacen en el servidor.
--
-- QUÉ ES.
--   §2 `create_person_group`: espejo de `create_group` (mismas validaciones, mismo cifrado, mismo dueño admin activo)
--      con dos diferencias: `is_person = true` desde el primer instante (ningún `join_group` la lee como grupo normal
--      mientras sube la meta) y una SEGUNDA fila en `group_members`: el sitio reservado, con la clave que acuña el
--      teléfono (`p_person_member_key`, para que el gasto que se apunta enseguida lo referencie sin esperar al pull),
--      `user_id` NULL, rol `member`, estado `active` y el nombre cifrado. Es la forma que ya tienen los miembros
--      migrados sin reclamar (G6), que el cliente ya sabe leer.
--   §3 `join_group`: rama nueva para personas ANTES del rebind legacy. Quien abre el enlace ocupa el sitio reservado y
--      queda `active` (sin `pendingApproval`); devuelve `is_person: true` para que el Worker avise a quien la creó. Ya
--      dentro: no-op (`changed:false`). Sitio ocupado por otra cuenta: `yala_invalid_invite` (una persona no tiene
--      tercero). Las ramas de los grupos normales NO cambian.
--
-- SEGURIDAD. `security definer`, como `create_group` y `join_group`. Solo crea filas en un grupo NUEVO (aborta si la zona
-- existe), así que no da forma de meter un miembro en un grupo ajeno. El sitio reservado no es una cuenta: nadie puede
-- leer nada con él (la RLS va por `user_id`). Saltar la aprobación solo aplica a `is_person`, y `is_person` solo lo
-- escribe el admin (policy `split_groups_update`), que es quien aprobaría.
--
-- ORDEN DE DESPLIEGUE. 1) esta migración (STAGING; producción cuando Jürgen lo decida, junto con g37_01, que tampoco está
-- en producción). 2) el Worker con `create_person_group` en la allowlist. 3) la app. Contra un Worker viejo la app recibe
-- 404 y lo enseña como error: no deja nada a medias (server-first).
--
-- IDEMPOTENTE. `create or replace`. Aborta si falta `split_groups.is_person` (g37_01) o si `join_group` no está en la
-- versión medida (md5 de prosrc en staging, 2026-11-26: 4982b50d…), salvo que ya sea la de esta migración.
-- Marcha atrás: `g38_01_rollback.sql`. Aplicar: `bash qa/cloud/g38_01-remote.sh staging apply`.
-- =====================================================================================================


set local lock_timeout = '5s';

-- §1 · precondiciones
do $$
declare
  v_src text;
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public'
                  and table_name = 'split_groups' and column_name = 'is_person') then
    raise exception 'g38_01 ABORTA: falta split_groups.is_person (aplica g37_01 antes)';
  end if;
  select prosrc into v_src from pg_proc where oid = 'public.join_group(text, text, text, text)'::regprocedure;
  if md5(v_src) is distinct from '4982b50de23df93ed8f9c8bc369e9e17'
     and position('g38_01 · PERSONA' in v_src) = 0 then
    raise exception 'g38_01 ABORTA: join_group no está en la versión medida (md5 %)', md5(v_src);
  end if;
end;
$$;

-- §2 · create_person_group
create or replace function public.create_person_group(
  p_group_id text, p_name text, p_currency_code text, p_icon_name text, p_color_hex text,
  p_display_name text, p_person_member_key text, p_key text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_uid     uuid := (select auth.uid());
  v_hlc     text;
  v_name    text;
  v_display text;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  if p_group_id is null or length(p_group_id) < 8 or length(p_group_id) > 120 then
    raise exception 'yala_invalid_group_id' using errcode = 'P0001';
  end if;
  v_name    := btrim(coalesce(p_name, ''));
  v_display := btrim(coalesce(p_display_name, ''));
  if v_name = '' or length(v_name) > 80
     or v_display = '' or length(v_display) > 80
     or p_currency_code is null or length(p_currency_code) <> 3
     or p_person_member_key is null or length(p_person_member_key) < 8 or length(p_person_member_key) > 120
     or p_person_member_key = v_uid::text then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  if exists (select 1 from split_groups where group_id = p_group_id) then
    raise exception 'yala_group_exists' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  begin
    insert into split_groups (
      group_id, name, icon_name, color_hex, currency_code,
      simplify_debts, show_debts_in_single_currency, members_can_invite,
      default_split_type, is_archived, is_hidden_for_all, owner_user_id,
      created_at, field_hlcs, hlc, deleted, schema_version, is_person
    ) values (
      p_group_id, pgp_sym_encrypt(v_name, p_key), p_icon_name, p_color_hex, p_currency_code,
      false, false, false,
      'equal', false, false, v_uid,
      now(), jsonb_build_object('meta', v_hlc), v_hlc, false, 1, true
    );
  exception when unique_violation then
    raise exception 'yala_group_exists' using errcode = 'P0001';
  end;

  insert into group_members (
    group_id, member_key, user_id, display_name, role, status,
    joined_at, field_hlcs, hlc, deleted, schema_version
  ) values
    (p_group_id, v_uid::text, v_uid, pgp_sym_encrypt(v_display, p_key), 'admin', 'active',
     now(), jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1),
    (p_group_id, p_person_member_key, null, pgp_sym_encrypt(v_name, p_key), 'member', 'active',
     now(), jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1);

  return jsonb_build_object('group_id', p_group_id, 'member_key', v_uid::text,
                            'person_member_key', p_person_member_key);
end $function$;

revoke all on function public.create_person_group(text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.create_person_group(text, text, text, text, text, text, text, text) to authenticated;

-- §3 · join_group con la rama de persona
create or replace function public.join_group(
  p_token text, p_display_name text, p_key text, p_legacy_member_key text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_uid      uuid := (select auth.uid());
  v_hlc      text;
  v_display  text;
  v_group    text;
  v_archived boolean;
  v_person   boolean;
  v_inv      record;
  v_row      record;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  select * into v_inv from group_invites where token = p_token for update;
  -- Las CUATRO causas que sí describen un enlace inservible siguen colapsadas a propósito: distinguirlas
  -- sí sería un oráculo (permitiría sondear qué tokens existen).
  if v_inv.token is null
     or v_inv.revoked = true
     or (v_inv.expires_at is not null and v_inv.expires_at <= now())
     or (v_inv.max_uses is not null and v_inv.uses >= v_inv.max_uses) then
    raise exception 'yala_invalid_invite' using errcode = 'P0001';
  end if;
  v_group := v_inv.group_id;
  -- g13_03: el token era válido, pero el grupo ya no está. g13_05 aprovecha la MISMA lectura para
  -- traerse `is_archived` — una consulta, no dos, y el estado del grupo se decide en un solo sitio.
  -- g38_01: la misma lectura trae también si el grupo es una persona (`is_person`, g37_01).
  select coalesce(s.is_archived, false), coalesce(s.is_person, false) into v_archived, v_person
    from split_groups s where s.group_id = v_group and s.deleted = false;
  if not found then
    raise exception 'yala_group_deleted' using errcode = 'P0001';
  end if;

  v_display := btrim(coalesce(p_display_name, ''));
  if v_display = '' or length(v_display) > 80 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  -- g38_01 · PERSONA (Compartido, lote 3). Una persona es un grupo de dos: quien la creó y un sitio reservado con el
  -- nombre que le puso (`create_person_group`, user_id null). Quien abre el enlace OCUPA ese sitio y entra activo,
  -- sin aprobación: no hay a nadie más a quien pedir permiso. Si ya está dentro, no cambia nada. Si el sitio ya lo
  -- ocupó otra cuenta, el enlace no sirve: una persona nunca tiene un tercero (mismo código que un enlace inservible,
  -- sin oráculo).
  if v_person then
    select * into v_row from group_members
      where group_id = v_group and user_id = v_uid and deleted = false
      order by member_key asc limit 1 for update;
    if v_row.member_key is not null then
      return jsonb_build_object('group_id', v_group, 'member_key', v_row.member_key,
                                'status', v_row.status, 'rebound', false, 'changed', false, 'is_person', true);
    end if;
    if v_archived then
      raise exception 'yala_group_archived' using errcode = 'P0001';
    end if;
    select * into v_row from group_members
      where group_id = v_group and user_id is null and deleted = false and role = 'member'
      order by joined_at asc, member_key asc limit 1 for update;
    if v_row.member_key is null then
      raise exception 'yala_invalid_invite' using errcode = 'P0001';
    end if;
    update group_members set
      user_id      = v_uid,
      display_name = pgp_sym_encrypt(v_display, p_key),
      status       = 'active',
      hlc          = v_hlc,
      updated_at   = now(),
      field_hlcs   = jsonb_set(
                       jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc)),
                       '{profile}', to_jsonb(v_hlc))
      where group_id = v_group and member_key = v_row.member_key;
    update group_invites set uses = uses + 1 where token = p_token;
    return jsonb_build_object('group_id', v_group, 'member_key', v_row.member_key,
                              'status', 'active', 'rebound', true, 'changed', true, 'is_person', true);
  end if;

  -- 4. REBIND legacy: la fila del member migrado existe SIN reclamar (user_id null). Queda pendingApproval.
  --    NO se gatea por archivado: esa fila ya está en el grupo (es reclamar el sitio propio, no entrar).
  if p_legacy_member_key is not null then
    select * into v_row from group_members
      where group_id = v_group and member_key = p_legacy_member_key for update;
    if v_row.member_key is not null and v_row.user_id is null then
      update group_members set
        user_id      = v_uid,
        display_name = pgp_sym_encrypt(v_display, p_key),
        status       = 'pendingApproval',
        deleted      = false,
        deleted_hlc  = null,
        hlc          = v_hlc,
        updated_at   = now(),
        field_hlcs   = jsonb_set(
                         jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc)),
                         '{profile}', to_jsonb(v_hlc))
        where group_id = v_group and member_key = p_legacy_member_key;
      update group_invites set uses = uses + 1 where token = p_token;
      return jsonb_build_object('group_id', v_group, 'member_key', p_legacy_member_key,
                                'status', 'pendingApproval', 'rebound', true, 'changed', true);
    end if;
  end if;

  -- 5. Ya-member por user_id.
  select * into v_row from group_members
    where group_id = v_group and user_id = v_uid
    order by member_key asc limit 1 for update;
  if v_row.member_key is not null then
    if v_row.deleted = false and v_row.status in ('active', 'pendingApproval') then
      -- NO-OP: sigues como estabas. `changed:false` es lo que evita que el re-tap del enlace vuelva a
      -- despertar a los admins. Es la ÚNICA rama que no escribe nada. Tampoco se gatea por archivado:
      -- quien ya está dentro re-tapeando su enlace no debe recibir un aviso donde hoy no pasa nada.
      return jsonb_build_object('group_id', v_group, 'member_key', v_row.member_key,
                                'status', v_row.status, 'rebound', false, 'changed', false);
    else
      -- g13_05: RE-ENTRADA de quien está fuera (rejected/left/removed/deleted). Es entrada nueva.
      if v_archived then
        raise exception 'yala_group_archived' using errcode = 'P0001';
      end if;
      update group_members set
        status       = 'pendingApproval',
        deleted      = false,
        deleted_hlc  = null,
        display_name = pgp_sym_encrypt(v_display, p_key),
        hlc          = v_hlc,
        updated_at   = now(),
        field_hlcs   = jsonb_set(
                         jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc)),
                         '{profile}', to_jsonb(v_hlc))
        where group_id = v_group and member_key = v_row.member_key;
      update group_invites set uses = uses + 1 where token = p_token;
      return jsonb_build_object('group_id', v_group, 'member_key', v_row.member_key,
                                'status', 'pendingApproval', 'rebound', false, 'changed', true);
    end if;
  end if;

  -- 6. INSERT nuevo member (pendingApproval). g13_05: el caso del ticket — entrada nueva pura.
  if v_archived then
    raise exception 'yala_group_archived' using errcode = 'P0001';
  end if;
  insert into group_members (
    group_id, member_key, user_id, display_name, role, status,
    joined_at, field_hlcs, hlc, deleted, schema_version
  ) values (
    v_group, v_uid::text, v_uid, pgp_sym_encrypt(v_display, p_key), 'member', 'pendingApproval',
    now(), jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1
  );
  update group_invites set uses = uses + 1 where token = p_token;
  return jsonb_build_object('group_id', v_group, 'member_key', v_uid::text,
                            'status', 'pendingApproval', 'rebound', false, 'changed', true);
end $function$;

-- §4 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_src text := (select prosrc from pg_proc where oid = 'public.join_group(text, text, text, text)'::regprocedure);
begin
  if position('g38_01 · PERSONA' in v_src) = 0 then
    raise exception 'g38_01: join_group sin la rama de persona';
  end if;
  -- las cuatro claves `changed` de g13_04 siguen ahí, más las dos de la persona: 4 × true y 2 × false.
  if array_length(string_to_array(v_src, $q$'changed', true$q$), 1) - 1 <> 4
     or array_length(string_to_array(v_src, $q$'changed', false$q$), 1) - 1 <> 2 then
    raise exception 'g38_01: join_group no tiene las claves changed esperadas';
  end if;
  if not has_function_privilege('authenticated', 'public.create_person_group(text, text, text, text, text, text, text, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.create_person_group(text, text, text, text, text, text, text, text)', 'EXECUTE') then
    raise exception 'g38_01: EXECUTE de create_person_group mal otorgado';
  end if;
  if not has_function_privilege('authenticated', 'public.join_group(text, text, text, text)', 'EXECUTE') then
    raise exception 'g38_01: authenticated perdió EXECUTE en join_group';
  end if;
  raise notice 'g38_01 OK';
end;
$$;

-- g38_01 · banco: casos contra la migración, dentro de UNA transacción que el `raise` final deshace entera.
-- Lo arma `g38_01-remote.sh test`: cuerpo de la migración (sin begin/commit) + este fichero. No deja nada en la base.
do $bench$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  gid text := 'SplitGroup-' || gen_random_uuid()::text;
  gid2 text := 'SplitGroup-' || gen_random_uuid()::text;
  pkey text := gen_random_uuid()::text;
  tok text; tok2 text;
  r jsonb;
  out jsonb := '[]'::jsonb;
  n int; st text; uid uuid; isp boolean;
  procedure_dummy int;
begin
  insert into auth.users (id, aud, role, email) values
    (a, 'authenticated', 'authenticated', 'g38a-' || a || '@bench.invalid'),
    (b, 'authenticated', 'authenticated', 'g38b-' || b || '@bench.invalid'),
    (c, 'authenticated', 'authenticated', 'g38c-' || c || '@bench.invalid');

  -- A crea la persona «Marta»
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  r := public.create_person_group(gid, 'Marta', 'PEN', 'person.fill', '#14B8A6', 'Jürgen', pkey, 'k');
  perform set_config('role', 'postgres', true);
  select count(*) into n from group_members where group_id = gid and deleted = false;
  select is_person into isp from split_groups where group_id = gid;
  select status, user_id into st, uid from group_members where group_id = gid and member_key = pkey;
  out := out || jsonb_build_object('caso', 'crear_persona_dos_miembros', 'ok', n = 2 and isp and st = 'active' and uid is null,
                                   'detalle', jsonb_build_object('n', n, 'is_person', isp, 'status', st));

  -- crear otra con la misma zona: yala_group_exists
  begin
    perform set_config('role', 'authenticated', true);
    perform public.create_person_group(gid, 'Otra', 'PEN', 'person.fill', '#14B8A6', 'Jürgen', gen_random_uuid()::text, 'k');
    out := out || jsonb_build_object('caso', 'zona_repetida', 'ok', false);
  exception when others then
    out := out || jsonb_build_object('caso', 'zona_repetida', 'ok', sqlerrm = 'yala_group_exists', 'detalle', sqlerrm);
  end;
  perform set_config('role', 'postgres', true);

  -- clave del sitio reservado igual a la del dueño: yala_bad_input
  begin
    perform set_config('role', 'authenticated', true);
    perform public.create_person_group('SplitGroup-' || gen_random_uuid(), 'X', 'PEN', 'person.fill', '#14B8A6', 'J', a::text, 'k');
    out := out || jsonb_build_object('caso', 'clave_del_dueno', 'ok', false);
  exception when others then
    out := out || jsonb_build_object('caso', 'clave_del_dueno', 'ok', sqlerrm = 'yala_bad_input', 'detalle', sqlerrm);
  end;
  perform set_config('role', 'postgres', true);

  -- A invita; B abre el enlace: ocupa el sitio y entra activo
  perform set_config('role', 'authenticated', true);
  tok := public.create_group_invite(gid, 2592000, null);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.join_group(tok, 'Marta Pérez', 'k', null);
  perform set_config('role', 'postgres', true);
  select status, user_id into st, uid from group_members where group_id = gid and member_key = pkey;
  select count(*) into n from group_members where group_id = gid and deleted = false;
  out := out || jsonb_build_object('caso', 'entra_sin_aprobacion', 'ok',
    r->>'status' = 'active' and (r->>'changed')::boolean and (r->>'is_person')::boolean and r->>'member_key' = pkey
    and st = 'active' and uid = b and n = 2, 'detalle', r);

  -- B vuelve a abrirlo: no cambia nada
  perform set_config('role', 'authenticated', true);
  r := public.join_group(tok, 'Marta Pérez', 'k', null);
  perform set_config('role', 'postgres', true);
  out := out || jsonb_build_object('caso', 'retap_no_op', 'ok', r->>'status' = 'active' and not (r->>'changed')::boolean, 'detalle', r);

  -- C (un tercero) con el mismo enlace: no entra
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.join_group(tok, 'Intruso', 'k', null);
    out := out || jsonb_build_object('caso', 'tercero_no_entra', 'ok', false);
  exception when others then
    out := out || jsonb_build_object('caso', 'tercero_no_entra', 'ok', sqlerrm = 'yala_invalid_invite', 'detalle', sqlerrm);
  end;
  perform set_config('role', 'postgres', true);
  select count(*) into n from group_members where group_id = gid;
  out := out || jsonb_build_object('caso', 'persona_sigue_de_dos', 'ok', n = 2, 'detalle', n);

  -- NO REGRESIÓN: un grupo normal sigue pidiendo aprobación
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  perform public.create_group(gid2, 'Viaje', 'PEN', 'airplane', '#8B5CF6', 'Jürgen', 'equal', 'k', false, false, false);
  tok2 := public.create_group_invite(gid2, 2592000, null);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.join_group(tok2, 'Marta', 'k', null);
  perform set_config('role', 'postgres', true);
  out := out || jsonb_build_object('caso', 'grupo_normal_pide_aprobacion', 'ok',
    r->>'status' = 'pendingApproval' and (r->>'changed')::boolean and r->'is_person' is null, 'detalle', r);

  raise exception 'G38BENCH %', out::text;
end;
$bench$;

rollback;
