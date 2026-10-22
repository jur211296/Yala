-- =====================================================================================================
-- g13_04 · `join_group` dice si hubo TRANSICIÓN REAL, para que el fan-out deje de avisar por un no-op
--
-- QUÉ LE PASA AL USUARIO HOY. Pedí entrar a un grupo y espero aprobación. Toco otra vez el enlace
-- —porque no sé si se envió, o porque me lo reenvían— y al admin le llega OTRA notificación de
-- solicitud pendiente. Tantas como veces toque. Para él parece que insisto; no ha pasado nada nuevo.
--
-- POR QUÉ PASA, y por qué el arreglo es aquí y no en el Worker. El guardián del fan-out
-- (`gateway/src/groups/rpc.ts::notifyMembershipChange`) ya está escrito para evitar exactamente esto y
-- su comentario lo promete, pero sólo puede mirar el `status` del retorno — y el `status` es AMBIGUO:
-- vale `pendingApproval` tanto para «acaba de quedar pendiente» como para «ya estaba pendiente y no ha
-- cambiado nada». El filtro tapa el caso `active` y deja pasar el `pendingApproval`, que es el del
-- re-tap. **El Worker no puede distinguirlos porque el RPC no se lo dice.** Por eso el campo nace aquí.
--
-- POR QUÉ NO SIRVE `rebound`, medido antes de escribir esto. Es la respuesta obvia y es falsa: de las
-- cuatro ramas que retornan, `rebound` sólo es `true` en el rebind legacy. Las ramas de re-activación
-- (rejected/removed → pendingApproval) y de alta nueva devuelven `rebound:false` y SÍ son transiciones
-- reales que el admin debe ver. Gatear por `rebound` apagaría los avisos legítimos.
--
-- QUÉ CAMBIA. Un campo `changed` en las CUATRO ramas de retorno. `false` sólo en la rama no-op
-- «ya eras miembro y sigues igual»; `true` en las tres que escriben. Nada más: ni una condición, ni una
-- escritura, ni el valor de `status`/`rebound`/`group_id`/`member_key`. Es puramente aditivo.
--
-- COMPATIBILIDAD, medida antes de escribir esto (las dos direcciones, porque el despliegue no es atómico):
--   · Cliente iOS: `JoinGroupResult` (`GroupsMembershipClient.swift:79-90`) es `Decodable` con
--     `CodingKeys` explícitas, y `JSONDecoder` IGNORA las claves desconocidas ⇒ una clave nueva no
--     rompe ninguna versión publicada. **Cero cambio de cliente.**
--   · Worker viejo + esta migración: el campo llega y nadie lo mira ⇒ comportamiento de hoy. INERTE.
--   · Worker nuevo + servidor sin migrar: el gate trata la AUSENCIA de `changed` como «avisa» a
--     propósito (ver el comentario del guardián) ⇒ comportamiento de hoy, nunca un aviso perdido.
--   ⇒ **Ningún orden de despliegue pierde un aviso legítimo.** El orden recomendado sigue siendo
--     SQL primero y Worker después, porque es el único en que el arreglo entra en vigor de una vez.
--
-- EL CASO QUE NO HAY QUE APAGAR (hermano `rejected-member-cold-tap-does-nothing`): a quien rechazaron,
-- tocar un enlace nuevo lo devuelve a `pendingApproval` por la rama de re-activación → `changed:true` →
-- el admin SÍ se entera, que es justo lo que ese ticket arregló. Y si vuelve a tocar una segunda vez, ya
-- cae en la rama no-op → `changed:false` → silencio. Una solicitud, un aviso.
--
-- Base: g13_03 (`yala_group_deleted`). Verificado contra el `prosrc` VIVO de producción antes de
-- escribir: idéntico al fichero de g13_03 salvo los comentarios explicativos, que a prod se promueven
-- condensados. Este cuerpo conserva sólo los comentarios de estructura, para que repo y prod coincidan.
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
  if v_inv.token is null
     or v_inv.revoked = true
     or (v_inv.expires_at is not null and v_inv.expires_at <= now())
     or (v_inv.max_uses is not null and v_inv.uses >= v_inv.max_uses) then
    raise exception 'yala_invalid_invite' using errcode = 'P0001';
  end if;
  v_group := v_inv.group_id;
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
      -- despertar a los admins. Es la ÚNICA rama que no escribe nada.
      return jsonb_build_object('group_id', v_group, 'member_key', v_row.member_key,
                                'status', v_row.status, 'rebound', false, 'changed', false);
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
                                'status', 'pendingApproval', 'rebound', false, 'changed', true);
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
                            'status', 'pendingApproval', 'rebound', false, 'changed', true);
end $function$;

-- -----------------------------------------------------------------------------------------------------
-- VERIFICACIÓN (tras aplicar)
--
--   1. Las cuatro ramas informan la transición, y exactamente una dice `false`:
--        select
--          (select count(*) from regexp_matches(prosrc, '''changed'', true', 'g'))  as ramas_true,
--          (select count(*) from regexp_matches(prosrc, '''changed'', false', 'g')) as ramas_false
--        from pg_proc where proname = 'join_group';
--      → ramas_true = 3, ramas_false = 1. Si `ramas_false` fuese 0 el arreglo no hace nada; si fuese
--        >1 se apagó un aviso legítimo (la re-activación de un rechazado, o un alta nueva).
--
--   2. g13_03 sigue en pie (esta migración se apoya en ella, no la sustituye):
--        select prosrc from pg_proc where proname = 'join_group';
--      → `yala_group_deleted` UNA vez y `yala_invalid_invite` UNA vez.
--
--   3. Los grants no cambiaron (`create or replace` los conserva, pero se comprueba):
--        select grantee, privilege_type from information_schema.routine_privileges
--         where routine_name = 'join_group';
--
--   4. Comportamiento, contra la BD (lo que de verdad importa): con un usuario ya `pendingApproval`,
--      llamar `join_group` con el mismo token devuelve `changed:false`; el primer join de un usuario
--      nuevo devuelve `changed:true`. El escenario completo de las cuatro ramas está en el sandbox
--      transaccional que corrió esta migración — ver la entrada g13_04 de este README.
-- -----------------------------------------------------------------------------------------------------
