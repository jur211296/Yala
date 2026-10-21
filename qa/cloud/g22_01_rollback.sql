-- g22_01 · marcha atrás: borra `set_member_role` y devuelve `remove_member` y `leave_group` a su cuerpo del DDL (§2 de
-- `supabase-groups-staging.ddl`, verbatim).
--
-- No reescribe filas: los roles que ya cambió `set_member_role` y los `role = 'member'` que dejaron las salidas se
-- quedan como están (son el estado real del grupo). Idempotente: con los dos cuerpos ya en el del DDL y sin la función,
-- no cambia nada. GUARDA: aborta sin tocar nada si alguno de los dos cuerpos no es ni el de g22_01 ni el del DDL.
--
-- ANTES, vuelve al Worker anterior o quita `set_member_role` de su allowlist: con el Worker nuevo y sin la función,
-- PostgREST contesta 404 y el gateway lo colapsa a 502 `yala_unavailable`, que la app enseña como el error genérico
-- cada vez que un admin intenta hacer o quitar admin. Y una app que ya lo ofrece seguirá ofreciéndolo.

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
    raise exception 'g22_01_rollback: remove_member no es ni el cuerpo de g22_01 ni el del DDL (md5 %); no se toca nada', v_rm;
  end if;
  if v_lg is null or v_lg not in ('a4bbcff1bca1ac1cec09f372d577d1cc', 'f4820b999e862b2f0ee6192855982318') then
    raise exception 'g22_01_rollback: leave_group no es ni el cuerpo de g22_01 ni el del DDL (md5 %); no se toca nada', v_lg;
  end if;
end;
$$;

drop function if exists public.set_member_role(text, text, text);

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
    hlc        = v_hlc,
    updated_at = now(),
    field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
    where group_id = p_group_id and member_key = v_target.member_key;

  return jsonb_build_object('group_id', p_group_id, 'member_key', v_target.member_key, 'status', 'left');
end $$;

do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = 'set_member_role') then
    raise exception 'g22_01_rollback: set_member_role sigue existiendo (¿otra firma?)';
  end if;
  if (select md5(prosrc) from pg_proc where oid = 'public.remove_member(text, text)'::regprocedure) <> 'e716f203c405437c95c82e47deae61b5'
     or (select md5(prosrc) from pg_proc where oid = 'public.leave_group(text)'::regprocedure) <> 'a4bbcff1bca1ac1cec09f372d577d1cc' then
    raise exception 'g22_01_rollback: remove_member / leave_group no volvieron al cuerpo del DDL';
  end if;
  raise notice 'g22_01_rollback OK · set_member_role retirada; remove_member y leave_group, como en el DDL';
end;
$$;
