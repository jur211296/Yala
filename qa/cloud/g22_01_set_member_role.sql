-- =====================================================================================================
-- g22_01 · Grupos de la nube: `set_member_role` — hacer o dejar de ser admin de un grupo (2026-10-21)
--          y salir del grupo (expulsado o por cuenta propia) deja de ser admin
--
-- QUÉ GANA EL USUARIO. En un grupo de la nube, el admin puede hacer admin a otro miembro o quitárselo. Hasta hoy la app
-- no lo ofrecía: `group_members` está congelado para UPDATE directo y no había RPC que cambiara un rol, así que
-- `GroupService.changeRole` lanzaba `backendActionUnavailable` (auditoría UX 2.2 · L19-3, decisión B de Jürgen:
-- construirlo en el servidor). Y quien sale de un grupo deja de ser admin: hasta hoy volvía a serlo al re-entrar.
--
-- §1 · `public.set_member_role(p_group_id text, p_member_key text, p_role text) returns jsonb`, NUEVA. SECURITY
-- DEFINER con `search_path = public` (molde de `remove_member` / `approve_member`, §2 de `supabase-groups-staging.ddl`).
-- Reglas, en este orden:
--   1. sin `auth.uid()`, o quien llama no es admin ACTIVO del grupo (`is_group_admin`) → `yala_not_authorized`;
--   2. `p_role` fuera de {admin, member} → `yala_bad_input`;
--   3. el objetivo es la fila de `group_members` de ese grupo y ese `member_key`, viva y ACTIVA; si no
--      → `yala_member_not_found`. Un pendiente se aprueba (`approve_member`), no se asciende;
--   4. el objetivo es el creador (`user_id = split_groups.owner_user_id`, comparado por `user_id` como
--      `remove_member`: cubre al creador con `member_key` legacy) y se le quiere quitar el admin
--      → `yala_cannot_change_owner_role`;
--   5. hacer admin a un hueco sin reclamar (`user_id is null`, miembro de un grupo migrado de CloudKit que nadie ha
--      reclamado) → `yala_member_not_eligible`: no hay persona detrás que pueda administrar;
--   6. quitar el admin al último admin activo CON CUENTA → `yala_last_admin`. Los huecos admin sin reclamar no cuentan
--      (co-admins de un grupo migrado): con ellos el grupo se quedaría sin nadie que pueda administrar. Con el creador
--      siempre admin casi nunca salta; sí en un grupo con `owner_user_id` nulo (la cuenta del creador se borró:
--      `on delete set null`), donde el único admin que queda se lo quitaría a sí mismo;
--   7. el objetivo ya tiene ese rol → devuelve sin escribir nada (`changed: false`);
--   8. si no, escribe `role`, `hlc = server_hlc()`, `updated_at` y `field_hlcs.membership` (la unidad de coherencia en
--      la que ya escriben el rol `transfer_group_ownership` y `groups_forget_user`: el rol va con el estado, medido en
--      el DDL), y devuelve `{group_id, member_key, role, changed: true}`.
-- `server_seq` lo pone el trigger `stamp_group_seq`; el HLC lo acota `cap_future_hlc` (hlc01). Errores: constantes
-- `yala_*` con errcode P0001, sin interpolar ningún input (el gateway los pasa tal cual como 400 `yala_rpc_error`).
--
-- EL CANDADO, que no estaba en lo decidido. Pasada la regla 1, una sola sentencia bloquea (`for update`, ordenada por
-- `member_key`) las filas de los admins activos del grupo Y la del objetivo, y la regla 1 se vuelve a mirar. Sin él,
-- dos admins que se quitan el admin el uno al otro a la vez pasan los dos la regla 6 (cada uno ve al otro todavía
-- admin) y el grupo se queda sin ninguno; el segundo, además, actuaría ya sin serlo. Con él, el segundo espera al
-- primero y la segunda mirada de la regla 1, que es otra sentencia y ve lo ya confirmado, lo para con
-- `yala_not_authorized`. Lo prueba el caso de concurrencia del banco.
--   Sobre el interbloqueo: lo que evita un ciclo NO es «un orden fijo» a secas, sino que cada llamada pida TODAS sus
-- filas de `group_members` en esa única sentencia ordenada. Por eso el objetivo va dentro (si se bloqueara aparte,
-- después, dos llamadas podrían cruzarse: A tiene los admins y espera al objetivo X; B tiene X y espera a un admin).
-- `remove_member` toma el mismo candado (§2); `approve_member` y `leave_group` bloquean una sola fila; el contador de
-- `server_seq` (`group_seq_counters`, por el trigger) se pide siempre después, al escribir. Es un razonamiento sobre el
-- código, no una medición: el banco prueba la carrera de dos admins, no la ausencia de interbloqueos.
--
-- §2 · `remove_member` y `leave_group`, REDEFINIDAS con el cambio mínimo sobre su cuerpo del DDL (§2 de
-- `supabase-groups-staging.ddl`, que no ha cambiado desde g1_02/g7_02: ninguna migración de `qa/cloud/` los redefine):
--   · las dos escriben además `role = 'member'`. Hasta hoy solo cambiaban `status`, así que un admin expulsado o que se
--     iba conservaba `role = 'admin'`; la re-entrada (`join_group`) y el rebind legacy dejan `pendingApproval` SIN tocar
--     el rol, y al aprobarla volvía a ser admin sin que nadie lo decidiera (y la fila pendiente enseñaba la insignia).
--     La fila del creador no llega nunca a esa escritura: `remove_member` lo rechaza (`yala_cannot_remove_owner`) y
--     `leave_group` también (`yala_owner_cannot_leave`). El rol va en la misma unidad `membership` que el estado, así
--     que el sello de `field_hlcs` no cambia;
--   · `remove_member` toma además el candado de set_member_role (admins activos + objetivo, ordenado) y vuelve a mirar
--     que quien llama sigue siendo admin: un admin al que le acaban de quitar el admin ya no expulsa a nadie.
--   GUARDA: antes de tocar nada, el md5(prosrc) de cada una tiene que ser el del cuerpo del DDL (remove_member
--   e716f203c405437c95c82e47deae61b5, leave_group a4bbcff1bca1ac1cec09f372d577d1cc) o el de esta migración
--   (efce7084cb5cb5c902948f156c09f148 y f4820b999e862b2f0ee6192855982318: re-aplicar). Si el cuerpo vivo es otro, aborta la transacción entera sin tocar nada. RIESGO
--   conocido: los md5 de partida salen del DDL cargado en el banco, no de una lectura de staging o producción; si el
--   cuerpo vivo difiere del molde aunque sea en un espacio (lo que le pasó a g17_01), la guarda aborta. Se mide antes
--   con la consulta del runbook.
--
-- QUÉ NO TOCA. Ninguna tabla ni columna, ningún otro RPC, ninguna columna † (no llama a pgcrypto ⇒ el gateway NO le
-- inyecta `p_key`: fuera de `RPC_NEEDS_ENC_KEY`), ni el owner del grupo: dar o quitar el admin no transfiere la
-- propiedad (eso es `transfer_group_ownership`). No reescribe filas existentes: quien ya salió siendo admin ANTES de
-- esta migración conserva `role = 'admin'` hasta su próxima salida (ver residuales). Sin push.
--
-- RESIDUALES CONOCIDOS (también en el ticket `groups-set-member-role-deploy`):
--   · carrera con `transfer_group_ownership` / `groups_forget_user`: eligen al heredero leyendo sin candado («admin
--     primero») y solo le escriben `role = 'admin'` si al leer no lo era. Si `set_member_role` le quita el admin a ese
--     heredero a la vez, el grupo puede quedar con un creador que no es admin;
--   · filas que salieron siendo admin antes de g22_01: conservan `role = 'admin'`, y si re-entran y se aprueban vuelven
--     a ser admin (no hay backfill: reescribirlas movería el HLC de filas ajenas);
--   · `leave_group` no mira si quedan admins: un admin que sale mientras otro se quita el admin puede dejar el grupo
--     sin admins (como hoy);
--   · en el teléfono de otro admin el creador no está marcado (`isGroupOwner` es local del teléfono del creador), así
--     que la app le ofrece quitarle el admin; el servidor lo rechaza con `yala_cannot_change_owner_role`.
--
-- IDEMPOTENTE. `create or replace` + grants, con la guarda aceptando también el cuerpo de g22_01. Marcha atrás:
-- `g22_01_rollback.sql` (devuelve los dos cuerpos del DDL, con su propia guarda, y borra set_member_role).
--
-- BANCO LOCAL: `bash qa/cloud/g22_01-local-test.sh` (Postgres 17 desechable con el DDL real de Grupos). Cada mutante,
-- una copia de este fichero con una regla quitada, tiene que tumbar SU caso: sin la regla 4, sin la 5, sin la 6, sin
-- el `user_id is not null` de la 6, sin el candado, sin el reset de rol de `remove_member` y sin el de `leave_group`.
--
-- Orden de despliegue: este DDL → el Worker con `set_member_role` en su allowlist → la app que lo llama. Al revés, el
-- Worker devolvería 404 `unknown rpc` (sin DDL, PostgREST 404 → 502 `yala_unavailable`) y la app enseñaría el error
-- genérico; nada se rompe ni se escribe a medias. El §2 no depende del orden: la app no cambia de forma de respuesta.
-- =====================================================================================================

-- §0 · guarda de los dos cuerpos que se redefinen. Ver la cabecera.
do $$
declare
  v_rm text;
  v_lg text;
begin
  select md5(p.prosrc) into v_rm from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'remove_member' and p.pronargs = 2;
  select md5(p.prosrc) into v_lg from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'leave_group' and p.pronargs = 1;
  if v_rm is null or v_rm not in ('e716f203c405437c95c82e47deae61b5', 'efce7084cb5cb5c902948f156c09f148') then
    raise exception 'g22_01: remove_member no es ni el cuerpo del DDL ni el de g22_01 (md5 %); no se toca nada', v_rm;
  end if;
  if v_lg is null or v_lg not in ('a4bbcff1bca1ac1cec09f372d577d1cc', 'f4820b999e862b2f0ee6192855982318') then
    raise exception 'g22_01: leave_group no es ni el cuerpo del DDL ni el de g22_01 (md5 %); no se toca nada', v_lg;
  end if;
end;
$$;

-- §1 · set_member_role
create or replace function public.set_member_role(p_group_id text, p_member_key text, p_role text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_hlc    text;
  v_target record;
  v_owner  uuid;
  v_others integer;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- 1. Quien llama: admin ACTIVO (is_group_admin ya exige status = 'active'). Quien no lo es sale aquí, sin bloquear
  --    nada de un grupo ajeno.
  if not is_group_admin(p_group_id) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- Candado (ver la cabecera): los admins activos del grupo Y el objetivo, en UNA sentencia ordenada por member_key.
  -- La regla 1 se vuelve a mirar DESPUÉS: es otra sentencia, así que ve lo que confirmó quien tenía el candado antes,
  -- y quien acaba de dejar de ser admin ya no pasa.
  perform 1 from group_members
    where group_id = p_group_id and deleted = false
      and ((status = 'active' and role = 'admin') or member_key = p_member_key)
    order by member_key
    for update;
  if not is_group_admin(p_group_id) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- 2. El rol pedido.
  if p_role is null or p_role not in ('admin', 'member') then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  -- 3. El objetivo: vivo y ACTIVO en este grupo. Su fila ya está bloqueada por el candado de arriba.
  select * into v_target from group_members
    where group_id = p_group_id and member_key = p_member_key
      and deleted = false and status = 'active'
    for update;
  if v_target.member_key is null then
    raise exception 'yala_member_not_found' using errcode = 'P0001';
  end if;

  -- 4. Al creador no se le quita el admin. Por user_id, como remove_member (cubre el member_key legacy).
  select owner_user_id into v_owner from split_groups where group_id = p_group_id;
  if p_role = 'member' and v_owner is not null and v_target.user_id = v_owner then
    raise exception 'yala_cannot_change_owner_role' using errcode = 'P0001';
  end if;

  -- 5. Un hueco sin reclamar no puede ser admin: no hay cuenta detrás.
  if p_role = 'admin' and v_target.user_id is null then
    raise exception 'yala_member_not_eligible' using errcode = 'P0001';
  end if;

  -- 6. No se deja el grupo sin admins activos CON CUENTA: un hueco admin sin reclamar no puede administrar.
  if p_role = 'member' and v_target.role = 'admin' then
    select count(*) into v_others from group_members
      where group_id = p_group_id and member_key <> p_member_key
        and deleted = false and status = 'active' and role = 'admin' and user_id is not null;
    if v_others = 0 then
      raise exception 'yala_last_admin' using errcode = 'P0001';
    end if;
  end if;

  -- 7. Ya lo tiene: nada que escribir (un reintento tras una respuesta perdida cae aquí).
  if v_target.role is not distinct from p_role then
    return jsonb_build_object('group_id', p_group_id, 'member_key', p_member_key,
                              'role', p_role, 'changed', false);
  end if;

  -- 8. La escritura. El rol vive en la unidad `membership`, como en transfer_group_ownership.
  v_hlc := server_hlc();
  update group_members set
    role       = p_role,
    hlc        = v_hlc,
    updated_at = now(),
    field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
    where group_id = p_group_id and member_key = p_member_key;

  return jsonb_build_object('group_id', p_group_id, 'member_key', p_member_key,
                            'role', p_role, 'changed', true);
end $$;

-- Grants de EXECUTE: molde de los RPCs de grupos (revocar de public/anon, otorgar solo a authenticated).
revoke all on function public.set_member_role(text, text, text) from public, anon;
grant execute on function public.set_member_role(text, text, text) to authenticated;

-- §2 · remove_member y leave_group: cuerpo del DDL + `role = 'member'` (+ el candado en remove_member). `create or
-- replace` conserva sus grants (revoke public/anon, execute a authenticated, §2 del DDL).
create or replace function public.remove_member(p_group_id text, p_member_key text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_hlc    text;
  v_target record;
  v_owner  uuid;
  v_new    text;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  if not is_group_admin(p_group_id) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- g22_01: candado de las filas que esta llamada va a tocar o a contar (los admins activos y el objetivo), en UNA
  -- sentencia ordenada por member_key, y la regla del admin otra vez: es otra sentencia y ve lo que confirmó quien
  -- tenía el candado antes (molde de set_member_role).
  perform 1 from group_members
    where group_id = p_group_id and deleted = false
      and ((status = 'active' and role = 'admin') or member_key = p_member_key)
    order by member_key
    for update;
  if not is_group_admin(p_group_id) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  select * into v_target from group_members
    where group_id = p_group_id and member_key = p_member_key
      and deleted = false and status in ('active', 'pendingApproval')
    for update;
  if v_target.member_key is null then
    raise exception 'yala_member_not_found' using errcode = 'P0001';
  end if;

  -- Comparar por user_id (cubre owner con member_key legacy).
  select owner_user_id into v_owner from split_groups where group_id = p_group_id;
  if v_owner is not null and v_target.user_id = v_owner then
    raise exception 'yala_cannot_remove_owner' using errcode = 'P0001';
  end if;

  v_new := case when v_target.status = 'pendingApproval' then 'rejected' else 'removed' end;
  v_hlc := server_hlc();
  update group_members set
    status     = v_new,
    role       = 'member',   -- g22_01: quien sale expulsado deja de ser admin
    hlc        = v_hlc,
    updated_at = now(),
    field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
    where group_id = p_group_id and member_key = p_member_key;

  return jsonb_build_object('group_id', p_group_id, 'member_key', p_member_key, 'status', v_new);
end $$;

create or replace function public.leave_group(p_group_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_hlc    text;
  v_target record;
  v_owner  uuid;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  select * into v_target from group_members
    where group_id = p_group_id and user_id = v_uid
      and deleted = false and status in ('active', 'pendingApproval')
    order by member_key asc limit 1 for update;
  if v_target.member_key is null then
    raise exception 'yala_member_not_found' using errcode = 'P0001';
  end if;

  select owner_user_id into v_owner from split_groups where group_id = p_group_id;
  if v_owner is not null and v_owner = v_uid then
    raise exception 'yala_owner_cannot_leave' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();
  update group_members set
    status     = 'left',
    role       = 'member',   -- g22_01: quien se va deja de ser admin
    hlc        = v_hlc,
    updated_at = now(),
    field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
    where group_id = p_group_id and member_key = v_target.member_key;

  return jsonb_build_object('group_id', p_group_id, 'member_key', v_target.member_key, 'status', 'left');
end $$;

-- Comprobación: aborta la transacción entera si algo no quedó como se espera.
do $$
begin
  if not has_function_privilege('authenticated', 'public.set_member_role(text, text, text)', 'EXECUTE') then
    raise exception 'g22_01: authenticated no puede ejecutar set_member_role';
  end if;
  if has_function_privilege('anon', 'public.set_member_role(text, text, text)', 'EXECUTE') then
    raise exception 'g22_01: anon puede ejecutar set_member_role';
  end if;
  if (select md5(prosrc) from pg_proc where oid = 'public.remove_member(text, text)'::regprocedure) <> 'efce7084cb5cb5c902948f156c09f148' then
    raise exception 'g22_01: remove_member no quedó con el cuerpo esperado';
  end if;
  if (select md5(prosrc) from pg_proc where oid = 'public.leave_group(text)'::regprocedure) <> 'f4820b999e862b2f0ee6192855982318' then
    raise exception 'g22_01: leave_group no quedó con el cuerpo esperado';
  end if;
  if not has_function_privilege('authenticated', 'public.remove_member(text, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.remove_member(text, text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.leave_group(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.leave_group(text)', 'EXECUTE') then
    raise exception 'g22_01: los grants de remove_member / leave_group cambiaron';
  end if;
  raise notice 'g22_01 OK · set_member_role creada; remove_member y leave_group dejan role = member; grants intactos';
end;
$$;
