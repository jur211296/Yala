-- g38_01 · marcha atrás: retira `create_person_group` y devuelve `join_group` a g13_05 (md5 4982b50d…).
-- Las personas ya creadas siguen existiendo con su sitio reservado; con el join_group de g13_05, quien abra su enlace
-- entra como pendiente de aprobación, como en un grupo normal.
begin;
set local lock_timeout = '5s';
drop function if exists public.create_person_group(text, text, text, text, text, text, text, text);
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
  select coalesce(s.is_archived, false) into v_archived
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

do $$
begin
  if (select md5(prosrc) from pg_proc where oid = 'public.join_group(text, text, text, text)'::regprocedure)
     is distinct from '4982b50de23df93ed8f9c8bc369e9e17' then
    raise exception 'g38_01 rollback: join_group no volvió a la versión g13_05';
  end if;
  raise notice 'g38_01 rollback OK';
end;
$$;
commit;
