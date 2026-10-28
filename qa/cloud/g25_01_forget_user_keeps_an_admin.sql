-- =====================================================================================================
-- g25_01 · Grupos de la nube: borrar la cuenta (`groups_forget_user`) nunca deja un grupo vivo sin admin (2026-10-28)
--
-- QUÉ GANA EL USUARIO. Cuando alguien borra su cuenta, los grupos en los que sigue habiendo gente siguen teniendo a
-- alguien que los pueda administrar (aprobar solicitudes, expulsar, hacer admin a otro). Hasta hoy podía quedar un
-- grupo vivo en el que nadie con cuenta era admin, y nadie podía arreglarlo desde la app.
--
-- EL INVARIANTE. Todo grupo con `split_groups.deleted = false` en el que quede algún miembro activo con cuenta
-- conserva ≥1 fila de `group_members` con `deleted = false`, `status = 'active'`, `role = 'admin'` y
-- `user_id is not null`.
--
-- EL HUECO (medido en el DDL, §2 de `supabase-groups-staging.ddl`, «8. groups_forget_user»). El loop1 solo mira los
-- grupos que la persona POSEE (`owner_user_id = v_uid`): les busca heredero y lo hace admin, o los tombstonea. Después,
-- la anonimización deja TODAS sus filas de miembro con `user_id = null` y `status = 'removed'`. En un grupo que NO
-- posee —un grupo «sin creador» (`owner_user_id` null: migrado, o cuyo dueño se borró por la FK `on delete set null`)—
-- donde ella era el ÚLTIMO admin activo con cuenta, la anonimización se lleva al último admin usable.
--
-- §1 · `groups_forget_user(p_key text)`, REDEFINIDA con el cuerpo del DDL y UN paso nuevo entre el loop1 y la
-- anonimización. Para cada grupo no borrado (en orden de `group_id`, como el loop1) donde quien llama es miembro
-- `active` con `role = 'admin'` y NO queda otro admin activo con cuenta distinto de él, promueve a `admin` al heredero
-- con el MISMO criterio del loop1: fila `deleted = false`, `status = 'active'`, `user_id is not null and user_id <>
-- v_uid`, orden `(role = 'admin') desc, joined_at asc, member_key asc`. Estampa `hlc`, `updated_at` y
-- `field_hlcs.membership` con el mismo `v_hlc` de toda la llamada (el rol vive en la unidad `membership`, como en el
-- loop1, `transfer_group_ownership` y `set_member_role`). Sin heredero no hace nada: no queda nadie con cuenta.
--   · Los grupos que posee ya los resolvió el loop1: el heredero sale admin, así que el paso nuevo los salta; los
--     tombstoneados tienen `deleted = true` y tampoco entran.
--   · El paso NO toca `owner_user_id`: un grupo sin creador sigue sin creador. Dar la propiedad es otra decisión.
--   · La respuesta conserva sus tres claves (`groups_transferred`, `groups_tombstoned`, `memberships_anonymized`) y
--     añade `admins_promoted`, el número de grupos donde el paso nuevo hizo admin a alguien. El gateway y la app
--     leen la respuesta como objeto: una clave de más no rompe a nadie.
--   Lo demás, igual: `security definer`, `search_path = public, extensions`, el errcode P0001 de
--   `yala_not_authorized` y los grants (`create or replace` los conserva: revoke public/anon, execute a authenticated).
--
-- GUARDA. Antes de tocar nada, el md5(prosrc) vivo tiene que ser el del cuerpo del DDL
-- (4cd0a3cbc080002c476523a2d5f47766, medido cargando el DDL en el banco local) o el de esta migración
-- (fb2263667e3565f84cbad009c7df1d17: re-aplicar). Si es otro, aborta la transacción entera. RIESGO conocido (el de
-- g17_01 y g22_01): el md5 de partida sale del DDL cargado en el banco, no de staging ni de producción; si el cuerpo
-- vivo difiere aunque sea en un espacio, la guarda aborta. Se mide antes con
--   select md5(prosrc) from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure;
--
-- QUÉ NO TOCA. Ninguna tabla ni columna, ningún otro RPC, ninguna fila ya existente fuera de la llamada (no repara
-- grupos que ya estén sin admin hoy), ni `owner_user_id`. La firma no cambia ⇒ el gateway sigue inyectando `p_key`.
--
-- RESIDUALES CONOCIDOS.
--   · Como el loop1, el paso nuevo lee sin candado. Si a la vez otro admin del grupo se quita el admin
--     (`set_member_role`) o se va (`leave_group`), el paso puede ver «queda otro admin» y no promover, y el grupo
--     quedarse sin ninguno.
--   · Otros caminos que dejan un grupo sin admin con cuenta siguen abiertos (fuera del alcance): `leave_group` y
--     `remove_member` de un admin en un grupo sin creador, y borrar un usuario de `auth.users` sin pasar por aquí
--     (la FK `on delete set null` anula `user_id` sin tocar roles).
--
-- IDEMPOTENTE. `create or replace`, con la guarda aceptando también el cuerpo de g25_01. Marcha atrás:
-- `g25_01_rollback.sql` (devuelve el cuerpo del DDL, con su propia guarda).
--
-- BANCO LOCAL: `bash qa/cloud/g25_01-local-test.sh` (Postgres 17 desechable con el DDL real de Grupos). Cada mutante,
-- una copia de este fichero con una pieza quitada, tiene que tumbar SU caso.
--
-- Orden de despliegue: indiferente. La app no depende de `admins_promoted`.
-- =====================================================================================================

-- §0 · guarda del cuerpo que se redefine. Ver la cabecera.
do $$
declare
  v_fu text;
begin
  select md5(p.prosrc) into v_fu from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'groups_forget_user' and p.pronargs = 1;
  if v_fu is null or v_fu not in ('4cd0a3cbc080002c476523a2d5f47766', 'fb2263667e3565f84cbad009c7df1d17') then
    raise exception 'g25_01: groups_forget_user no es ni el cuerpo del DDL ni el de g25_01 (md5 %); no se toca nada', v_fu;
  end if;
end;
$$;

-- §1 · groups_forget_user: cuerpo del DDL + el paso «ningún grupo vivo sin admin con cuenta».
create or replace function public.groups_forget_user(p_key text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_uid         uuid := (select auth.uid());
  v_hlc         text;
  v_grp         record;
  v_cand        record;
  v_transferred integer := 0;
  v_tombstoned  integer := 0;
  v_anon        integer := 0;
  v_promoted    integer := 0;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  v_hlc := server_hlc();

  for v_grp in
    select group_id from split_groups
      where owner_user_id = v_uid and deleted = false
      order by group_id asc
  loop
    select * into v_cand from group_members
      where group_id = v_grp.group_id and deleted = false and status = 'active'
        and user_id is not null and user_id <> v_uid
      order by (coalesce(role, '') = 'admin') desc, joined_at asc, member_key asc
      limit 1;

    if v_cand.member_key is not null then
      if v_cand.role is distinct from 'admin' then
        update group_members set
          role       = 'admin',
          hlc        = v_hlc,
          updated_at = now(),
          field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
          where group_id = v_grp.group_id and member_key = v_cand.member_key;
      end if;
      update split_groups set
        owner_user_id = v_cand.user_id,
        hlc           = v_hlc,
        updated_at    = now(),
        field_hlcs    = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{meta}', to_jsonb(v_hlc))
        where group_id = v_grp.group_id;
      v_transferred := v_transferred + 1;
    else
      update split_groups set
        deleted     = true,
        deleted_hlc = v_hlc,
        hlc         = v_hlc,
        updated_at  = now(),
        field_hlcs  = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{meta}', to_jsonb(v_hlc))
        where group_id = v_grp.group_id;
      update group_members set
        deleted     = true,
        deleted_hlc = v_hlc,
        hlc         = v_hlc,
        updated_at  = now(),
        field_hlcs  = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
        where group_id = v_grp.group_id and deleted = false;
      v_tombstoned := v_tombstoned + 1;
    end if;
  end loop;

  -- g25_01 ▶ paso nuevo: en los grupos vivos donde quien se borra era el último admin activo CON CUENTA (los que no
  -- posee: los suyos ya los resolvió el loop1), el heredero del loop1 pasa a admin antes de la anonimización.
  for v_grp in
    select g.group_id from split_groups g
      where g.deleted = false
        and exists (select 1 from group_members me
                     where me.group_id = g.group_id and me.user_id = v_uid and me.deleted = false
                       and me.status = 'active' and me.role = 'admin')
        and not exists (select 1 from group_members o
                         where o.group_id = g.group_id and o.deleted = false and o.status = 'active'
                           and o.role = 'admin' and o.user_id is not null and o.user_id <> v_uid)
      order by g.group_id asc
  loop
    -- Heredero: el criterio del loop1, verbatim en su contenido.
    select * into v_cand from group_members m
      where m.group_id = v_grp.group_id and m.deleted = false and m.status = 'active'
        and m.user_id is not null and m.user_id <> v_uid
      order by (coalesce(m.role, '') = 'admin') desc, m.joined_at asc, m.member_key asc
      limit 1;

    -- Sin heredero no queda nadie con cuenta en el grupo: no hay a quién hacer admin.
    if v_cand.member_key is not null then
      update group_members set
        role       = 'admin',
        hlc        = v_hlc,
        updated_at = now(),
        field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
        where group_id = v_grp.group_id and member_key = v_cand.member_key;
      v_promoted := v_promoted + 1;
    end if;
  end loop;
  -- g25_01 ◀ fin del paso nuevo

  with anonymized as (
    update group_members set
      user_id      = null,
      display_name = pgp_sym_encrypt('__deleted_user__', p_key),
      status       = 'removed',
      hlc          = v_hlc,
      updated_at   = now(),
      field_hlcs   = jsonb_set(
                       jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc)),
                       '{profile}', to_jsonb(v_hlc))
      where user_id = v_uid
    returning 1
  )
  select count(*) into v_anon from anonymized;

  delete from push_tokens where user_id = v_uid;

  return jsonb_build_object(
    'groups_transferred',      v_transferred,
    'groups_tombstoned',       v_tombstoned,
    'memberships_anonymized',  v_anon,
    'admins_promoted',         v_promoted
  );
end $$;

-- Comprobación: aborta la transacción entera si algo no quedó como se espera.
do $$
begin
  if (select md5(prosrc) from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure) <> 'fb2263667e3565f84cbad009c7df1d17' then
    raise exception 'g25_01: groups_forget_user no quedó con el cuerpo esperado';
  end if;
  if not has_function_privilege('authenticated', 'public.groups_forget_user(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.groups_forget_user(text)', 'EXECUTE') then
    raise exception 'g25_01: los grants de groups_forget_user cambiaron';
  end if;
  if not (select prosecdef from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure) then
    raise exception 'g25_01: groups_forget_user dejó de ser SECURITY DEFINER';
  end if;
  raise notice 'g25_01 OK · groups_forget_user promueve un admin antes de anonimizar; grants intactos';
end;
$$;
