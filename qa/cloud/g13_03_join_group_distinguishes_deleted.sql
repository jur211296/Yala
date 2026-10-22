-- =====================================================================================================
-- g13_03 · `join_group` distingue «el grupo fue borrado» de un enlace inválido
--
-- QUÉ LE PASA AL USUARIO HOY. Abre un enlace de un grupo que su creador borró, y la app le dice: «Este
-- enlace ya no es válido o expiró. **Pídele al admin que regenere uno.**» Ese consejo es imposible de
-- seguir: no hay grupo al que volver ni enlace que regenerar. La persona lo intenta, pide el enlace, le
-- vuelve a fallar, y no tiene forma de enterarse de lo que pasó.
--
-- POR QUÉ PASA. `join_group` colapsa CINCO causas en un mismo `yala_invalid_invite`: token inexistente ·
-- revocado · caducado · agotado · **grupo borrado**. El cliente las clasifica todas igual y pinta el
-- mismo texto. Las cuatro primeras sí describen un enlace que no sirve y el consejo encaja; la quinta no.
--
-- POR QUÉ NO ROMPE EL NO-ORÁCULO, que es la razón de que las cinco estuvieran juntas. El `raise` que se
-- cambia es el SEGUNDO, y solo se alcanza **después** de que el token pasara las cuatro validaciones:
-- existe, no está revocado, no ha caducado y no está agotado. Es decir, quien recibe este error tiene un
-- token REAL que alguien le dio — ya sabía que el grupo existió. Con un token inventado se cae en el
-- primer `raise`, que sigue siendo `yala_invalid_invite` y no dice nada. No se puede sondear.
--
-- COMPATIBILIDAD CON CLIENTES VIEJOS, medida antes de escribir esto: `GroupsRPCError.init(yalaCode:)`
-- devuelve `nil` para un código desconocido y el llamador lo convierte en `.permanentRejected`, NUNCA en
-- `.transient` (regla A5 del canal: un 400 permanente reintentado sería un bucle). ⇒ una app que no
-- conozca `yala_group_deleted` lo trata como rechazo permanente y muestra su mensaje genérico, que es
-- exactamente lo que hace hoy. **Se puede aplicar antes de publicar la app, sin romper a nadie.**
--
-- El resto de la función no se toca: ni el rebind legacy, ni el ya-member, ni el insert.
-- =====================================================================================================

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
  -- QUINTA causa, y la única que cambia: el token era válido, pero el grupo ya no está. Quien llega aquí
  -- tenía un token real ⇒ decirle la verdad no le revela nada que no supiera, y le ahorra perseguir un
  -- enlace nuevo que nadie puede darle.
  if not exists (select 1 from split_groups where group_id = v_group and deleted = false) then
    raise exception 'yala_group_deleted' using errcode = 'P0001';
  end if;

  v_display := btrim(coalesce(p_display_name, ''));
  if v_display = '' or length(v_display) > 80 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  -- 4. REBIND legacy: la fila del member migrado existe SIN reclamar (user_id null). Queda pendingApproval.
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
                                'status', 'pendingApproval', 'rebound', true);
    end if;
  end if;

  -- 5. Ya-member por user_id.
  select * into v_row from group_members
    where group_id = v_group and user_id = v_uid
    order by member_key asc limit 1 for update;
  if v_row.member_key is not null then
    if v_row.deleted = false and v_row.status in ('active', 'pendingApproval') then
      return jsonb_build_object('group_id', v_group, 'member_key', v_row.member_key,
                                'status', v_row.status, 'rebound', false);
    else
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
                                'status', 'pendingApproval', 'rebound', false);
    end if;
  end if;

  -- 6. INSERT nuevo member (pendingApproval).
  insert into group_members (
    group_id, member_key, user_id, display_name, role, status,
    joined_at, field_hlcs, hlc, deleted, schema_version
  ) values (
    v_group, v_uid::text, v_uid, pgp_sym_encrypt(v_display, p_key), 'member', 'pendingApproval',
    now(), jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1
  );
  update group_invites set uses = uses + 1 where token = p_token;
  return jsonb_build_object('group_id', v_group, 'member_key', v_uid::text,
                            'status', 'pendingApproval', 'rebound', false);
end $function$;

-- -----------------------------------------------------------------------------------------------------
-- VERIFICACIÓN (tras aplicar)
--
--   1. La función distingue los dos casos:
--        select prosrc from pg_proc where proname = 'join_group';
--      → tiene que aparecer `yala_group_deleted` UNA vez y `yala_invalid_invite` UNA vez.
--        Si `yala_invalid_invite` desapareció, se rompió el no-oráculo de las otras cuatro causas.
--
--   2. Los grants no cambiaron (`create or replace` los conserva, pero se comprueba):
--        select grantee, privilege_type from information_schema.routine_privileges
--         where routine_name = 'join_group';
--
--   3. El golden `3-quater` de `gateway/test/groups.goldens.test.ts` pasa contra la BD.
-- -----------------------------------------------------------------------------------------------------
