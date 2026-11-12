-- g25_01 · marcha atrás: devuelve `groups_forget_user(p_key text)` a su cuerpo del DDL (§2 de
-- `supabase-groups-staging.ddl`, «8. groups_forget_user», verbatim; md5(prosrc) 4cd0a3cbc080002c476523a2d5f47766).
--
-- No reescribe filas: los admins que ya promovió g25_01 se quedan admin (son el estado real del grupo). La respuesta
-- vuelve a sus tres claves (sin `admins_promoted`). `create or replace` conserva los grants. Idempotente: con el cuerpo
-- ya en el del DDL, no cambia nada. GUARDA: aborta sin tocar nada si el cuerpo vivo no es ni el de g25_01 ni el del DDL.

do $$
declare
  v_fu text;
begin
  select md5(p.prosrc) into v_fu from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'groups_forget_user' and p.pronargs = 1;
  if v_fu is null or v_fu not in ('4cd0a3cbc080002c476523a2d5f47766', 'fb2263667e3565f84cbad009c7df1d17') then
    raise exception 'g25_01_rollback: groups_forget_user no es ni el cuerpo de g25_01 ni el del DDL (md5 %); no se toca nada', v_fu;
  end if;
end;
$$;

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
    'memberships_anonymized',  v_anon
  );
end $$;

do $$
begin
  if (select md5(prosrc) from pg_proc where oid = 'public.groups_forget_user(text)'::regprocedure) <> '4cd0a3cbc080002c476523a2d5f47766' then
    raise exception 'g25_01_rollback: groups_forget_user no volvió al cuerpo del DDL';
  end if;
  if not has_function_privilege('authenticated', 'public.groups_forget_user(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.groups_forget_user(text)', 'EXECUTE') then
    raise exception 'g25_01_rollback: los grants de groups_forget_user cambiaron';
  end if;
  raise notice 'g25_01_rollback OK · groups_forget_user, como en el DDL';
end;
$$;
