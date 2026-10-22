-- =====================================================================================================
-- g13_05 · un grupo ARCHIVADO no acepta miembros nuevos
--
-- QUÉ LE PASA AL USUARIO HOY. El dueño archiva un grupo —lo guarda, lo saca de su lista activa— y el
-- enlace de invitación que repartió **sigue funcionando**. Quien lo tapea entra como `pendingApproval`
-- a un grupo que ya nadie mira, y se queda esperando una aprobación que no va a llegar. La app, además,
-- tiene desde hace meses un texto traducido a 16 idiomas (`groups.reconnect.archived.*`) que promete
-- justo lo contrario, y por eso no se podía enseñar sin mentir.
--
-- MEDIDO, NO INFERIDO (2026-09-06, contra la función VIVA de producción, en sandbox transaccional):
-- `join_group('TOK', …)` sobre un grupo con `is_archived = true` y `deleted = false` devolvió
-- `{"status":"pendingApproval","changed":true,…}`, dejó **1 fila** en `group_members` y **consumió un
-- uso** del invite. El `prosrc` de producción no menciona `is_archived` ni una vez; en todo el esquema,
-- esa columna solo aparece en `create_group`, `migrate_group` y `groups_pull_rows_split_groups` — es
-- decir, siempre como dato que se TRANSPORTA, nunca como puerta que decide.
--
-- DECISIÓN (Jürgen, 2026-09-06). Se hace verdad el comportamiento, no se reescribe el texto: es lo que
-- «archivado» significa para cualquiera, y el copy ya existe.
--
-- DÓNDE VA EL GATE, Y POR QUÉ NO ARRIBA DEL TODO. Ponerlo junto al chequeo de `deleted` habría sido una
-- línea, y habría estado mal: el AC dice que **quien ya está dentro no se ve afectado**, y por esa
-- función pasan cuatro caminos distintos, no uno.
--
--   1. REBIND legacy (`p_legacy_member_key`, fila con `user_id null`) → **PASA**. Esa fila ya existe en
--      el grupo: la creó `migrate_group` por alguien que YA era miembro en CloudKit y todavía no la ha
--      reclamado. No es una entrada nueva, es recuperar el acceso al historial propio. Bloquearlo dejaría
--      a esa persona sin sus propios gastos por una acción —archivar— que es reversible y que ni siquiera
--      es suya.
--   2. YA-MEMBER activo o pendiente → **PASA**, y sigue siendo el no-op `changed:false` de g13_04. Es la
--      rama del re-tap: quien ya está dentro vuelve a tocar su enlace. Cortarla aquí le pintaría un aviso
--      de error donde hoy no pasa absolutamente nada — exactamente «verse afectado».
--   3. YA-MEMBER en estado terminal (`rejected` / `left` / `removed`, o `deleted`) → **RECHAZA**. Esa
--      persona NO está dentro: la rechazaron, se fue o la expulsaron, y no tiene acceso al grupo. Volver
--      a pedir entrada es una entrada nueva.
--   4. INSERT de miembro nuevo → **RECHAZA**. El caso del ticket.
--
-- Consecuencia deliberada: un intento rechazado **no consume uso del invite** (`uses` se incrementa solo
-- en las ramas que escriben, todas posteriores al `raise`). Archivar y desarchivar no gasta invitaciones.
--
-- DESARCHIVAR REABRE LA ENTRADA SIN MÁS. El gate lee la columna en el momento de la llamada; no hay
-- estado derivado, ni marca en el invite, ni nada que limpiar. `is_archived = false` y el enlace de
-- siempre vuelve a funcionar.
--
-- NO ROMPE EL NO-ORÁCULO. Igual que g13_03: este `raise` vive **después** de las cuatro validaciones del
-- token (existe · no revocado · no caducado · con usos), así que quien lo recibe ya tenía un token REAL
-- que alguien le dio — ya sabía que ese grupo existe. Con un token inventado se sigue cayendo en el
-- primer `raise`, que es `yala_invalid_invite` y no dice nada. No se puede sondear.
--
-- COMPATIBILIDAD CON CLIENTES VIEJOS, medida antes de escribir esto: `GroupsRPCError.init(yalaCode:)`
-- devuelve `nil` para un código desconocido y el llamador lo convierte en `.permanentRejected`, NUNCA en
-- `.transient` (regla A5). ⇒ una app que no conozca `yala_group_archived` lo trata como rechazo
-- permanente y enseña su mensaje genérico — peor texto, pero comportamiento correcto: **no entra**, que
-- es justo lo que este cambio existe para conseguir. **Se puede aplicar antes de publicar la app.**
--
-- `coalesce(is_archived, false)` NO es decorativo: la columna es `boolean` NULLABLE y sin default
-- (`supabase-groups-staging.ddl:109`), así que un grupo que nunca escribió el campo la tiene a NULL.
-- Sin el `coalesce`, `if v_archived then` con NULL no entra —el resultado sería el correcto por
-- accidente— y cualquier reescritura futura a `if not v_archived` invertiría el sentido en silencio.
--
-- BASE: el `prosrc` VIVO de producción (4321 chars, md5 0ca909811e2ce272b92a725e46828d6c), no el molde
-- del repo, que iba dos migraciones por detrás. Lo único que se añade es `v_archived`, su lectura y los
-- dos `raise`. Rebind legacy, no-op del re-tap, revive e insert quedan byte a byte como estaban.
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

-- -----------------------------------------------------------------------------------------------------
-- VERIFICACIÓN (tras aplicar)
--
--   1. Los códigos conviven, cada uno una vez:
--        select prosrc from pg_proc where proname = 'join_group';
--      → `yala_group_archived` ×2 (re-entrada + insert) · `yala_group_deleted` ×1 · `yala_invalid_invite`
--        ×1. Si `yala_invalid_invite` desapareció, se rompió el no-oráculo de las otras cuatro causas.
--
--   2. Las cuatro claves `changed` de g13_04 siguen ahí:
--        `'changed', true` ×3 · `'changed', false` ×1.
--
--   3. Los grants no cambiaron (`create or replace` los conserva, pero se comprueba):
--        select grantee, privilege_type from information_schema.routine_privileges
--         where routine_name = 'join_group';
--
--   4. Los cuatro caminos, ejercitados en sandbox transaccional (`begin … rollback`) sobre un grupo con
--      `is_archived = true`: rebind legacy PASA · re-tap de miembro activo PASA con `changed:false` ·
--      re-entrada de `rejected` RECHAZA · alta nueva RECHAZA. Y sobre el mismo grupo desarchivado, el
--      alta nueva vuelve a PASAR sin tocar nada más.
--
--   5. El cuerpo de ESTE fichero y el `prosrc` de producción coinciden byte a byte:
--        md5 `4982b50de23df93ed8f9c8bc369e9e17`, 5365 chars (comprobado el 2026-09-06 tras aplicar).
--      No es ceremonia: la primera versión de este fichero difería de lo aplicado en UN comentario, y
--      así es exactamente como nació el drift que esta migración viene a cerrar.
--
--   6. Los 25 goldens de Grupos (`gateway/test/groups.goldens.test.ts`) no miran este código de error;
--      el gateway propaga cualquier `/^yala_[a-z_]+$/` como 400 con el código preservado
--      (`gateway/src/groups/rpc.ts`), así que no necesita cambios ni despliegue.
-- -----------------------------------------------------------------------------------------------------
