-- =====================================================================================================
-- g27_01 · Grupos de la nube: solo el dueño o un admin activo escriben saldos iniciales (2026-10-31, card 6n1o)
--
-- QUÉ GANA EL USUARIO. Hasta hoy la app era la única que decidía quién gestiona los saldos iniciales de un grupo
-- (PR #714: el dueño o cualquier admin activo). El servidor dejaba escribirlos a cualquier miembro activo, así que una
-- versión vieja, una app modificada o un PATCH directo podían cambiar el saldo de partida de todo el grupo. Desde aquí
-- el servidor exige lo mismo que la app, y cuando rechaza lo dice con un código que la app traduce a un mensaje claro.
--
-- MEDIDO ANTES (Management API, los dos proyectos, 2026-10-31). `split_expenses` y `split_shares` tienen las mismas
-- políticas en staging y producción (select/insert/update con `is_group_writer`), `apply_group_delta` es SECURITY
-- INVOKER con el mismo md5 (61c38595cdd8b7b0ab043437f49a7f2c) y el único otro escritor de esas tablas es
-- `g7_recrypt_corpus` (SECURITY DEFINER, sin grant a authenticated). `migrate_group` no tiene ruta en el gateway: no
-- hay subida de historial que pase por aquí.
--
-- POR QUÉ UN TRIGGER Y NO UNA POLÍTICA. Un UPDATE que la RLS filtra afecta 0 filas: `apply_group_delta` contesta
-- `noop not_authorized_or_gone` y la app PURGA ese cambio sin decir nada. Una política no puede explicar el motivo.
-- El trigger lanza un código propio (P0001) que el RPC deja pasar (solo captura `insufficient_privilege`), el gateway
-- lo expone porque casa con `^yala_[a-z_]+$` y la app lo guarda en el dead-letter y lo enseña. Alcanza también al
-- PATCH directo de PostgREST. Las políticas existentes no se tocan.
--
-- LA REGLA (`opening_balance_guard`, BEFORE INSERT OR UPDATE en `split_expenses` y `split_shares`):
--   0. Borrar lo que ya está borrado (OLD y NEW con `deleted`) no se juzga: es el reenvío de un tombstone cuya
--      respuesta se perdió (el tombstone no avanza `hlc`, así que `apply_group_delta` repite el UPDATE). Juzgarlo
--      rechazaba en falso, con el servidor ya en el estado bueno, si entre medias al autor le quitaron el admin.
--   1. Solo juzga filas de saldo inicial: un gasto con `is_opening_balance` en OLD o en NEW; un reparto cuyo gasto
--      (por OLD o NEW `expense_id`) es saldo inicial en el servidor. Un reparto cuyo gasto aún no llegó no se juzga.
--   2. Quien no es miembro activo pasa sin juicio y lo rechaza la RLS de siempre (`yala_not_authorized`): así el
--      trigger no le cuenta nada del grupo a alguien de fuera. Sin sesión (`auth.uid()` nulo) nadie es miembro: las
--      migraciones y `g7_recrypt_corpus` pasan por aquí, sin un atajo aparte que ningún caso distinguiría.
--   3. Grupo sin fila o con `split_groups.deleted = true` → `yala_opening_balance_group_closed`. Es el «congelado»
--      del servidor: la copia congelada de verdad vive en CloudKit y no llega aquí. Archivado NO cuenta: la app deja
--      escribir en grupos archivados.
--   4. Ni dueño (`owner_user_id = auth.uid()`) ni admin activo (`is_group_admin`) → `yala_opening_balance_not_admin`.
--      Espejo de `OpeningBalancePermissionLogic.canManage`.
--   5. Editar o borrar un saldo inicial VIVO con una liquidación confirmada y viva que toque a su gente →
--      `yala_opening_balance_locked`. Espejo de `confirmedSettlementsBlock` (app 2.1 y 2.2). Su gente es la arista que
--      el saldo YA TIENE en el servidor: el acreedor guardado, los deudores con reparto vivo y, en un reparto que cambia,
--      su `member_key` de antes. Un reparto que se mueve de gasto juzga los dos (el de origen y el de destino).
--      Crear no se bloquea (la app crea uno nuevo cuando el viejo está bloqueado), y el PRIMER reparto de un gasto
--      tampoco: un gasto que nunca tuvo reparto se está creando. Esa exención es la que separa crear de editar sin
--      depender del orden en que llegan los deltas, porque una edición borra repartos que ya existen.
--
-- POR QUÉ LA ARISTA DE ANTES Y NO LA NUEVA (review adversarial del 2026-10-31). Una edición llega en varios deltas
-- (gasto, repartos viejos borrados, repartos nuevos) y cada uno se juzga solo. Si el bloqueo mirase también los valores
-- NUEVOS, en una carrera (alguien confirma un pago que el editor aún no vio) el delta que trae a la persona saldada se
-- rechazaría y los demás entrarían: un saldo a medias, con importes que dejan de cuadrar en todos los teléfonos. Con la
-- arista de antes, los deltas de una edición ven a la misma gente y salen juntos. Lo que se cede: en esa carrera, mover
-- un saldo HACIA alguien recién saldado entra entero. Fuera de la carrera la app ya lo bloquea antes de subir.
--
-- RESIDUALES ASUMIDOS. (a) Si el cambio de acreedor llega ANTES que los repartos y el acreedor nuevo está saldado, los
-- repartos lo ven y se rechazan: a medias otra vez, solo en esa carrera y con ese orden. (b) Un miembro normal puede
-- subir un reparto de un gasto que aún no llegó (no hay saldo que juzgar); si después un admin crea ese saldo con ese
-- mismo `sync_id`, el reparto queda colgado de él. Necesita conocer el UUID del gasto antes de que exista.
--
-- QUÉ NO TOCA. Ninguna política, ninguna tabla ni columna, ningún RPC, ninguna fila existente.
--
-- IDEMPOTENTE: `create or replace` + `drop trigger if exists`. Marcha atrás: `g27_01_rollback.sql`.
-- BANCO LOCAL: `bash qa/cloud/g27_01-local-test.sh` (Postgres 17 desechable con el DDL real; casos + mutantes).
-- Orden de despliegue: la migración antes que la app (la app solo añade cómo enseñar los tres códigos).
-- =====================================================================================================

create or replace function public.opening_balance_guard() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid         uuid;              -- se lee solo para filas de saldo inicial (abajo, paso 4)
  v_gid         text := new.group_id;
  v_is_ob       boolean := false;  -- la fila es de un saldo inicial
  v_lock_exps   uuid[] := array[]::uuid[];  -- saldos vivos que esta escritura edita o borra (sujetos al bloqueo)
  v_extra       text[] := array[]::text[];  -- gente de la fila que se escribe (el `member_key` de antes de un reparto)
  v_exp         uuid;
  v_members     text[];
  v_owner       uuid;
  v_gdeleted    boolean;
  -- El gasto de destino (NEW.expense_id) y el de origen (OLD.expense_id, si cambia) de un reparto.
  v_new_ob      boolean;
  v_new_del     boolean;
  v_old_ob      boolean;
  v_old_del     boolean;
begin
  -- 0. Borrar lo ya borrado: reenvío de un tombstone, sin juicio.
  if tg_op = 'UPDATE' and old.deleted and new.deleted then
    return new;
  end if;

  -- 1. ¿Es una fila de saldo inicial?
  if tg_table_name = 'split_expenses' then
    v_is_ob := coalesce(new.is_opening_balance, false)
               or (tg_op = 'UPDATE' and coalesce(old.is_opening_balance, false));
    if not v_is_ob then
      return new;
    end if;
    if tg_op = 'UPDATE' and coalesce(old.is_opening_balance, false) and not old.deleted then
      v_lock_exps := array[new.sync_id];
    end if;
  elsif tg_table_name = 'split_shares' then
    if new.expense_id is not null then
      select e.is_opening_balance, e.deleted into v_new_ob, v_new_del
        from split_expenses e where e.group_id = new.group_id and e.sync_id = new.expense_id;
    end if;
    if tg_op = 'UPDATE' and old.expense_id is not null and old.expense_id is distinct from new.expense_id then
      select e.is_opening_balance, e.deleted into v_old_ob, v_old_del
        from split_expenses e where e.group_id = old.group_id and e.sync_id = old.expense_id;
    end if;
    v_is_ob := coalesce(v_new_ob, false) or coalesce(v_old_ob, false);
    if not v_is_ob then
      return new;
    end if;
    -- Editar: cambiar un reparto que ya existe, o añadir uno a un gasto que ya tuvo alguno (crear su primer reparto
    -- no es editar). Un reparto que cambia de gasto edita los dos.
    if coalesce(v_new_ob, false) and not coalesce(v_new_del, true)
       and (tg_op = 'UPDATE'
            or exists (select 1 from split_shares s
                        where s.group_id = new.group_id and s.expense_id = new.expense_id
                          and s.sync_id <> new.sync_id)) then
      v_lock_exps := v_lock_exps || new.expense_id;
    end if;
    if coalesce(v_old_ob, false) and not coalesce(v_old_del, true) then
      v_lock_exps := v_lock_exps || old.expense_id;
    end if;
    if tg_op = 'UPDATE' then
      v_extra := array[old.member_key];
    end if;
  else
    return new;
  end if;

  -- 2. Quien no es miembro activo (ni nadie sin sesión): lo rechaza la RLS de siempre, sin contarle nada.
  if not is_group_writer(v_gid) then
    return new;
  end if;

  -- 3. Grupo cerrado en el servidor.
  select g.owner_user_id, g.deleted into v_owner, v_gdeleted from split_groups g where g.group_id = v_gid;
  if not found or v_gdeleted then
    raise exception 'yala_opening_balance_group_closed' using errcode = 'P0001';
  end if;

  -- 4. Dueño o admin activo. `auth.uid()` se lee aquí y no al declarar: el trigger corre en TODA escritura de las dos
  -- tablas (también las de mantenimiento, como la normalización de hlc01) y lo de fuera de un saldo no lo necesita.
  v_uid := (select auth.uid());
  if not (v_owner is not distinct from v_uid or is_group_admin(v_gid)) then
    raise exception 'yala_opening_balance_not_admin' using errcode = 'P0001';
  end if;

  -- 5. Bloqueo por pago confirmado, con la arista que cada saldo YA TIENE en el servidor.
  foreach v_exp in array v_lock_exps loop
    v_members := v_extra
      || coalesce((select array[e.paid_by_member_key] from split_expenses e
                    where e.group_id = v_gid and e.sync_id = v_exp), array[]::text[])
      || coalesce((select array_agg(s.member_key) from split_shares s
                    where s.group_id = v_gid and s.expense_id = v_exp and s.deleted = false), array[]::text[]);
    if exists (select 1 from split_settlements st
                where st.group_id = v_gid and st.deleted = false and st.is_confirmed is true
                  and (st.from_member_key = any (v_members) or st.to_member_key = any (v_members))) then
      raise exception 'yala_opening_balance_locked' using errcode = 'P0001';
    end if;
  end loop;

  return new;
end;
$$;

revoke all on function public.opening_balance_guard() from public, anon, authenticated;

drop trigger if exists opening_balance_guard on public.split_expenses;
create trigger opening_balance_guard before insert or update on public.split_expenses
  for each row execute function public.opening_balance_guard();

drop trigger if exists opening_balance_guard on public.split_shares;
create trigger opening_balance_guard before insert or update on public.split_shares
  for each row execute function public.opening_balance_guard();
