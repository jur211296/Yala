-- supabase-groups-staging.ddl — snapshot-contract of the Grupos→backend staging schema (project fostjbbwstyuunmmefuk).
-- Groups live on a SEPARATE channel from the personal Modo Nube schema (supabase-staging.ddl): the sequence
-- axis is PER GROUP (group_seq_counters / stamp_group_seq), the PK is (group_id, sync_id) / (group_id, member_key),
-- and RLS is by MEMBERSHIP (is_group_member / is_group_writer / is_group_admin) instead of (auth.uid() = user_id).
--
-- This file is the OFFLINE mold of the live staging schema and is composed of two applied migrations, verbatim:
--   §1 g1_01_groups_infra_tables  — tables, per-group seq trigger, membership helpers, RLS policies, grants.
--   §2 g1_02_groups_rpcs          — the 9 membership/invite/rename RPCs + the column-level UPDATE grants (hallazgo #1).
-- Regenerate on any groups-schema change by concatenating the two applied migrations (keep §1 verbatim from the
-- live g1_01, minus the re-apply prelude/incident header; append the full g1_02). Staging-only until the flag gate.
-- Vocabulary parity with the app (SplitMember.swift): status ∈ {active,pendingApproval,rejected,left,removed}; role ∈ {admin,member}.
--
-- SYNC NOTE (G2): group_members is PULL-ONLY on the sync channel — the client NEVER pushes it (no PATCH, no
-- apply_group_delta write). §2 revokes ALL direct UPDATE on group_members from authenticated; the only client
-- write path is the RPC update_member_display_name (rename, unidad 'profile'); every membership mutation goes
-- through the SECURITY DEFINER RPCs. Financial content SELECT (split_expenses/shares/settlements) is gated to
-- ACTIVE writers (is_group_writer), not is_group_member — a pendingApproval member cannot read group content.


-- ============================================================================
-- §1 — g1_01_groups_infra_tables (Grupos→backend G1, diseño §3/§4)
-- ============================================================================
-- check_function_bodies off: los helpers referencian group_members antes de que el orden textual la cree.
set local check_function_bodies = off;

-- ============ eje server_seq POR GRUPO (gemelo de sync_seq_counters) ============
create table public.group_seq_counters (group_id text primary key, seq bigint not null default 0);

create function public.stamp_group_seq() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into group_seq_counters (group_id, seq) values (new.group_id, 1)
  on conflict (group_id) do update set seq = group_seq_counters.seq + 1 returning seq into new.server_seq;
  return new;
end $$;

-- HLC servidor para escrituras de RPCs (formato c1 46 chars; nodeID ceros = "server").
create function public.server_hlc() returns text language sql volatile set search_path = public as
$$ select to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') || '-0000-0000000000000000' $$;

-- ============ helpers de membership (SECURITY DEFINER: evitan la recursión RLS sobre group_members) ============
create function public.is_group_member(p_group_id text) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from group_members m where m.group_id = p_group_id
    and m.user_id = (select auth.uid()) and m.deleted = false and m.status in ('active','pendingApproval'))
$$;

create function public.is_group_writer(p_group_id text) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from group_members m where m.group_id = p_group_id
    and m.user_id = (select auth.uid()) and m.deleted = false and m.status = 'active')
$$;

create function public.is_group_admin(p_group_id text) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from group_members m where m.group_id = p_group_id
    and m.user_id = (select auth.uid()) and m.deleted = false and m.status = 'active' and m.role = 'admin')
$$;

revoke all on function public.is_group_member(text), public.is_group_writer(text), public.is_group_admin(text), public.server_hlc() from public, anon;
grant execute on function public.is_group_member(text), public.is_group_writer(text), public.is_group_admin(text) to authenticated;

-- ============ split_groups (meta del grupo; group_id PRESERVA el string cloudKitZoneID) ============
create table public.split_groups (
  group_id text primary key,
  name text,
  icon_name text,
  color_hex text,
  currency_code text,
  simplify_debts boolean,
  show_debts_in_single_currency boolean,
  members_can_invite boolean,
  default_split_type text,
  is_archived boolean,
  is_hidden_for_all boolean,
  owner_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz,
  field_hlcs jsonb,
  hlc text not null,
  deleted boolean not null default false,
  deleted_hlc text,
  server_seq bigint not null,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now()
);
create index split_groups_seq on public.split_groups (group_id, server_seq);
create trigger split_groups_stamp before insert or update on public.split_groups
  for each row execute function public.stamp_group_seq();
alter table public.split_groups enable row level security;
create policy split_groups_select on public.split_groups for select to authenticated using (is_group_member(group_id));
create policy split_groups_update on public.split_groups for update to authenticated using (is_group_admin(group_id));
revoke all on public.split_groups from anon, authenticated;
grant select, update on public.split_groups to authenticated; -- INSERT solo vía RPC create_group

-- ============ group_members (member_key = sub para nuevos, userRecordID legacy para migrados) ============
create table public.group_members (
  group_id text not null,
  member_key text not null,
  user_id uuid references auth.users(id) on delete set null,
  display_name text,
  role text,
  status text,
  joined_at timestamptz,
  field_hlcs jsonb,
  hlc text not null,
  deleted boolean not null default false,
  deleted_hlc text,
  server_seq bigint not null,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, member_key)
);
create index group_members_seq on public.group_members (group_id, server_seq);
create index group_members_user on public.group_members (user_id);
create trigger group_members_stamp before insert or update on public.group_members
  for each row execute function public.stamp_group_seq();
alter table public.group_members enable row level security;
create policy group_members_select on public.group_members for select to authenticated using (is_group_member(group_id));
create policy group_members_update_own on public.group_members for update to authenticated
  using (user_id = (select auth.uid()) and is_group_writer(group_id));
revoke all on public.group_members from anon, authenticated;
grant select, update on public.group_members to authenticated; -- INSERT y mutaciones de membership solo vía RPCs

-- ============ split_expenses ============
create table public.split_expenses (
  group_id text not null,
  sync_id uuid not null,
  amount numeric(18,4),
  currency_code text,
  expense_description text,
  note text,
  date timestamptz,
  created_at timestamptz,
  paid_by_member_key text,
  split_type text,
  is_settled boolean,
  is_opening_balance boolean,
  subcategory_name text,
  field_hlcs jsonb,
  hlc text not null,
  deleted boolean not null default false,
  deleted_hlc text,
  server_seq bigint not null,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, sync_id)
);
create index split_expenses_seq on public.split_expenses (group_id, server_seq);
create trigger split_expenses_stamp before insert or update on public.split_expenses
  for each row execute function public.stamp_group_seq();
alter table public.split_expenses enable row level security;
create policy split_expenses_select on public.split_expenses for select to authenticated using (is_group_member(group_id));
create policy split_expenses_insert on public.split_expenses for insert to authenticated with check (is_group_writer(group_id));
create policy split_expenses_update on public.split_expenses for update to authenticated using (is_group_writer(group_id));
revoke all on public.split_expenses from anon, authenticated;
grant select, insert, update on public.split_expenses to authenticated;

-- ============ split_shares ============
create table public.split_shares (
  group_id text not null,
  sync_id uuid not null,
  expense_id uuid,
  member_key text,
  amount numeric(18,4),
  is_paid boolean,
  field_hlcs jsonb,
  hlc text not null,
  deleted boolean not null default false,
  deleted_hlc text,
  server_seq bigint not null,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, sync_id)
);
create index split_shares_seq on public.split_shares (group_id, server_seq);
create trigger split_shares_stamp before insert or update on public.split_shares
  for each row execute function public.stamp_group_seq();
alter table public.split_shares enable row level security;
create policy split_shares_select on public.split_shares for select to authenticated using (is_group_member(group_id));
create policy split_shares_insert on public.split_shares for insert to authenticated with check (is_group_writer(group_id));
create policy split_shares_update on public.split_shares for update to authenticated using (is_group_writer(group_id));
revoke all on public.split_shares from anon, authenticated;
grant select, insert, update on public.split_shares to authenticated;

-- ============ split_settlements ============
create table public.split_settlements (
  group_id text not null,
  sync_id uuid not null,
  from_member_key text,
  to_member_key text,
  amount numeric(18,4),
  currency_code text,
  note text,
  date timestamptz,
  is_confirmed boolean,
  field_hlcs jsonb,
  hlc text not null,
  deleted boolean not null default false,
  deleted_hlc text,
  server_seq bigint not null,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, sync_id)
);
create index split_settlements_seq on public.split_settlements (group_id, server_seq);
create trigger split_settlements_stamp before insert or update on public.split_settlements
  for each row execute function public.stamp_group_seq();
alter table public.split_settlements enable row level security;
create policy split_settlements_select on public.split_settlements for select to authenticated using (is_group_member(group_id));
create policy split_settlements_insert on public.split_settlements for insert to authenticated with check (is_group_writer(group_id));
create policy split_settlements_update on public.split_settlements for update to authenticated using (is_group_writer(group_id));
revoke all on public.split_settlements from anon, authenticated;
grant select, insert, update on public.split_settlements to authenticated;

-- ============ group_invites (tokens revocables; gestionados SOLO por RPC — sin tail de sync) ============
create table public.group_invites (
  token text primary key,
  group_id text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked boolean not null default false,
  uses integer not null default 0,
  max_uses integer
);
create index group_invites_group on public.group_invites (group_id);
alter table public.group_invites enable row level security;
create policy group_invites_select on public.group_invites for select to authenticated using (is_group_admin(group_id));
revoke all on public.group_invites from anon, authenticated;
grant select on public.group_invites to authenticated;

-- ============ push_tokens (registro APNs per-user, G8; DELETE permitido — no es tabla tombstone) ============
create table public.push_tokens (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_token text not null,
  platform text,
  updated_at timestamptz not null default now(),
  primary key (user_id, device_token)
);
alter table public.push_tokens enable row level security;
create policy push_tokens_select on public.push_tokens for select to authenticated using (user_id = (select auth.uid()));
create policy push_tokens_insert on public.push_tokens for insert to authenticated with check (user_id = (select auth.uid()));
create policy push_tokens_update on public.push_tokens for update to authenticated using (user_id = (select auth.uid()));
create policy push_tokens_delete on public.push_tokens for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.push_tokens from anon, authenticated;
grant select, insert, update, delete on public.push_tokens to authenticated;

-- group_seq_counters: deny-all para clientes (fix del linter); el trigger SECURITY DEFINER escribe igual.
alter table public.group_seq_counters enable row level security;
revoke all on public.group_seq_counters from anon, authenticated;


-- ============================================================================
-- §2 — g1_02_groups_rpcs (los 9 RPCs de membresía/invitación/rename + cierre de escalada por columnas)
-- ============================================================================
-- Rieles (todos los RPCs): SECURITY DEFINER + search_path fijado (public; +extensions SOLO en create_group_invite
-- por gen_random_bytes); guard `if v_uid is null then raise 'yala_not_authorized'` primero; errores SANITIZADOS
-- yala_* (errcode P0001) que JAMÁS interpolan inputs; toda escritura estampa hlc=server_hlc() y updated_at=now()
-- (server_seq lo pone stamp_group_seq); field_hlcs POR UNIDAD DE COHERENCIA (group_members → profile/membership;
-- split_groups → meta).
set local check_function_bodies = off;

-- ============================================================================
-- 1. create_group — crea el grupo y su fila owner (admin/active). Claim ligero de profiles.
-- ============================================================================
create or replace function public.create_group(
  p_group_id text,
  p_name text,
  p_currency_code text,
  p_icon_name text,
  p_color_hex text,
  p_display_name text,
  p_default_split_type text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := (select auth.uid());
  v_hlc     text;
  v_name    text;
  v_display text;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- Validación de LONGITUD/PRESENCIA (el cliente es SSOT de divisas/contenido).
  if p_group_id is null or length(p_group_id) < 8 or length(p_group_id) > 120 then
    raise exception 'yala_invalid_group_id' using errcode = 'P0001';
  end if;
  v_name    := btrim(coalesce(p_name, ''));
  v_display := btrim(coalesce(p_display_name, ''));
  if v_name = '' or length(v_name) > 120
     or v_display = '' or length(v_display) > 80
     or p_currency_code is null or length(p_currency_code) <> 3 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  -- Ya existe (aunque esté deleted): NO reusar group_id.
  if exists (select 1 from split_groups where group_id = p_group_id) then
    raise exception 'yala_group_exists' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  -- Claim LIGERO: soporta la persona solo-grupos sin cuenta personal claimeada.
  -- profiles solo tiene `id` NOT NULL sin default (verificado) → on conflict do nothing es seguro (no pisa datos).
  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  -- TOCTOU: el `if exists` de arriba es un fast-path; dos create_group concurrentes con el mismo group_id
  -- lo esquivan → el PK de split_groups lanza unique_violation, que traducimos al MISMO yala_group_exists
  -- sanitizado (JAMÁS filtramos el sqlerrm crudo).
  begin
    insert into split_groups (
      group_id, name, icon_name, color_hex, currency_code,
      simplify_debts, show_debts_in_single_currency, members_can_invite,
      default_split_type, is_archived, is_hidden_for_all, owner_user_id,
      created_at, field_hlcs, hlc, deleted, schema_version
    ) values (
      p_group_id, v_name, p_icon_name, p_color_hex, p_currency_code,
      null, null, false,                    -- el cliente decide simplify/show; members_can_invite conservador
      p_default_split_type, false, false, v_uid,
      now(), jsonb_build_object('meta', v_hlc), v_hlc, false, 1
    );
  exception when unique_violation then
    raise exception 'yala_group_exists' using errcode = 'P0001';
  end;

  insert into group_members (
    group_id, member_key, user_id, display_name, role, status,
    joined_at, field_hlcs, hlc, deleted, schema_version
  ) values (
    p_group_id, v_uid::text, v_uid, v_display, 'admin', 'active',
    now(), jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1
  );

  return jsonb_build_object('group_id', p_group_id, 'member_key', v_uid::text);
end $$;

-- ============================================================================
-- 2. create_group_invite — token opaco revocable. +extensions por gen_random_bytes (pgcrypto).
-- ============================================================================
create or replace function public.create_group_invite(
  p_group_id text,
  p_ttl_seconds integer default 2592000,
  p_max_uses integer default null
) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_uid   uuid := (select auth.uid());
  v_token text;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- Admin, o (miembros-pueden-invitar activado Y writer). Grupo inexistente/deleted → mismo yala_not_authorized.
  if not (
    is_group_admin(p_group_id)
    or (coalesce((select members_can_invite from split_groups
                   where group_id = p_group_id and deleted = false), false)
        and is_group_writer(p_group_id))
  ) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  if p_ttl_seconds is null or p_ttl_seconds < 300 or p_ttl_seconds > 31536000
     or (p_max_uses is not null and (p_max_uses < 1 or p_max_uses > 1000)) then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  v_token := encode(gen_random_bytes(16), 'hex');
  insert into group_invites (token, group_id, created_by, expires_at, max_uses)
  values (v_token, p_group_id, v_uid, now() + make_interval(secs => p_ttl_seconds), p_max_uses);

  return v_token;
end $$;

-- ============================================================================
-- 3. join_group — orden exacto: invite → validar → claim → rebind legacy → ya-member → insert.
-- ============================================================================
create or replace function public.join_group(
  p_token text,
  p_display_name text,
  p_legacy_member_key text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
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

  -- 1. Lookup invite FOR UPDATE (serializa el conteo de uses). Cualquier fallo → yala_invalid_invite uniforme.
  select * into v_inv from group_invites where token = p_token for update;
  if v_inv.token is null
     or v_inv.revoked = true
     or (v_inv.expires_at is not null and v_inv.expires_at <= now())
     or (v_inv.max_uses is not null and v_inv.uses >= v_inv.max_uses) then
    raise exception 'yala_invalid_invite' using errcode = 'P0001';
  end if;
  v_group := v_inv.group_id;
  -- El grupo del invite debe existir y no estar tombstoneado (token viejo de un grupo olvidado → invalid).
  if not exists (select 1 from split_groups where group_id = v_group and deleted = false) then
    raise exception 'yala_invalid_invite' using errcode = 'P0001';
  end if;

  -- 2. Validar display_name.
  v_display := btrim(coalesce(p_display_name, ''));
  if v_display = '' or length(v_display) > 80 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  -- 3. Claim ligero de profiles. profiles solo tiene `id` NOT NULL sin default → on conflict do nothing es seguro.
  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  -- 4. REBIND legacy: la fila del member migrado de CloudKit existe SIN reclamar (user_id null, cualquier status/deleted).
  --    La fila rebindeada queda 'pendingApproval', NUNCA 'active': el member_key legacy es ENUMERABLE por
  --    cualquier pending member (group_members_select usa is_group_member, que incluye pending), así que
  --    activar directo sería un bypass de la aprobación + impersonación del historial del member migrado.
  --    El historial se recupera igual (member_key preservado → shares/expenses/settlements viejos siguen
  --    apuntando a él); el admin aprueba después con approve_member.
  if p_legacy_member_key is not null then
    select * into v_row from group_members
      where group_id = v_group and member_key = p_legacy_member_key for update;
    if v_row.member_key is not null and v_row.user_id is null then
      update group_members set
        user_id      = v_uid,
        display_name = v_display,
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
      -- IDEMPOTENTE: no muta, no consume uso.
      return jsonb_build_object('group_id', v_group, 'member_key', v_row.member_key,
                                'status', v_row.status, 'rebound', false);
    else
      -- REVIVIR (left/removed/rejected o deleted): vuelve a pendingApproval.
      update group_members set
        status       = 'pendingApproval',
        deleted      = false,
        deleted_hlc  = null,
        display_name = v_display,
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

  -- 6. INSERT nuevo member (pendingApproval — paridad con el flujo de aprobación).
  insert into group_members (
    group_id, member_key, user_id, display_name, role, status,
    joined_at, field_hlcs, hlc, deleted, schema_version
  ) values (
    v_group, v_uid::text, v_uid, v_display, 'member', 'pendingApproval',
    now(), jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1
  );
  update group_invites set uses = uses + 1 where token = p_token;
  return jsonb_build_object('group_id', v_group, 'member_key', v_uid::text,
                            'status', 'pendingApproval', 'rebound', false);
end $$;

-- ============================================================================
-- 4. approve_member — admin aprueba un pendingApproval → active.
-- ============================================================================
create or replace function public.approve_member(p_group_id text, p_member_key text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_hlc    text;
  v_target record;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  if not is_group_admin(p_group_id) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  -- FOR UPDATE: bloquea la fila target contra un approve/remove concurrente.
  select * into v_target from group_members
    where group_id = p_group_id and member_key = p_member_key
      and deleted = false and status = 'pendingApproval'
    for update;
  if v_target.member_key is null then
    raise exception 'yala_member_not_found' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();
  update group_members set
    status     = 'active',
    hlc        = v_hlc,
    updated_at = now(),
    field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
    where group_id = p_group_id and member_key = p_member_key;

  return jsonb_build_object('group_id', p_group_id, 'member_key', p_member_key, 'status', 'active');
end $$;

-- ============================================================================
-- 5. remove_member — admin expulsa. pendingApproval→rejected, active→removed. NUNCA al owner.
-- ============================================================================
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

-- ============================================================================
-- 6. leave_group — el propio member se va. El owner NO puede irse (debe transferir vía forget).
-- ============================================================================
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

-- ============================================================================
-- 7. revoke_invite — admin invalida un token. Sin oráculo: token inexistente Y caller-no-admin → mismo yala_invalid_invite.
-- ============================================================================
create or replace function public.revoke_invite(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := (select auth.uid());
  v_group text;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- Sin oráculo: token inexistente y caller-no-admin devuelven el MISMO yala_invalid_invite (no revela si
  -- un token existe a quien no administra su grupo).
  select group_id into v_group from group_invites where token = p_token;
  if v_group is null then
    raise exception 'yala_invalid_invite' using errcode = 'P0001';
  end if;
  if not is_group_admin(v_group) then
    raise exception 'yala_invalid_invite' using errcode = 'P0001';
  end if;

  update group_invites set revoked = true where token = p_token;
  return jsonb_build_object('revoked', true);
end $$;

-- ============================================================================
-- 8. groups_forget_user — borrado de Grupos (privacidad). Loop1 ownership, luego Loop2 anonimización.
-- ============================================================================
create or replace function public.groups_forget_user() returns jsonb
language plpgsql security definer set search_path = public as $$
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

  -- LOOP 1 — resolver ownership de CADA grupo que posee v_uid (split_groups.owner_user_id es la autoridad).
  for v_grp in
    select group_id from split_groups
      where owner_user_id = v_uid and deleted = false
      order by group_id asc
  loop
    -- Candidato: activo, user_id no null, != v_uid; primero admin más antiguo (tiebreak member_key),
    -- si no hay admin → el member activo más antiguo (se promueve a admin).
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
      -- Sin candidato → TOMBSTONE grupo + TODOS sus members. (split_expenses/shares/settlements NO se
      -- tocan: quedan inalcanzables vía RLS al no quedar members — residual documentado, G7 crypto los cubre.)
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

  -- LOOP 2 — anonimizar TODAS las filas de v_uid (cualquier status/deleted). Sentinel '__deleted_user__'
  -- que el cliente localiza (decisión owner). DESPUÉS de resolver ownership.
  with anonymized as (
    update group_members set
      user_id      = null,
      display_name = '__deleted_user__',
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

-- ============================================================================
-- 9. update_member_display_name — rename de la fila propia (unidad 'profile'). group_members pierde TODO
--    update directo (revoke total abajo); el rename del cliente pasa SOLO por aquí (PULL-ONLY en G2).
-- ============================================================================
create or replace function public.update_member_display_name(p_group_id text, p_display_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := (select auth.uid());
  v_hlc     text;
  v_display text;
  v_target  record;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  v_display := btrim(coalesce(p_display_name, ''));
  if v_display = '' or length(v_display) > 80 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  -- Fila propia (activa o pendingApproval), bloqueada FOR UPDATE.
  select * into v_target from group_members
    where group_id = p_group_id and user_id = v_uid
      and deleted = false and status in ('active', 'pendingApproval')
    order by member_key asc limit 1 for update;
  if v_target.member_key is null then
    raise exception 'yala_member_not_found' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();
  update group_members set
    display_name = v_display,
    hlc          = v_hlc,
    updated_at   = now(),
    field_hlcs   = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{profile}', to_jsonb(v_hlc))
    where group_id = p_group_id and member_key = v_target.member_key;

  return jsonb_build_object('group_id', p_group_id, 'member_key', v_target.member_key,
                            'display_name', v_display);
end $$;

-- ============================================================================
-- Endurecimiento SELECT del contenido financiero: un member PENDINGAPPROVAL (sala de espera) NO debe leer
-- expenses/shares/settlements — solo un writer ACTIVO. Las policies SELECT de g1_01 usaban is_group_member
-- (incluye pending), así que un pending veía el contenido del grupo antes de ser aprobado. split_groups y
-- group_members SE QUEDAN con is_group_member: la sala de espera necesita ver el grupo y el roster.
-- ============================================================================
drop policy split_expenses_select on public.split_expenses;
create policy split_expenses_select on public.split_expenses for select to authenticated using (is_group_writer(group_id));
drop policy split_shares_select on public.split_shares;
create policy split_shares_select on public.split_shares for select to authenticated using (is_group_writer(group_id));
drop policy split_settlements_select on public.split_settlements;
create policy split_settlements_select on public.split_settlements for select to authenticated using (is_group_writer(group_id));

-- ============================================================================
-- Grants de EXECUTE: revocar de public/anon, otorgar solo a authenticated.
-- ============================================================================
revoke all on function
  public.create_group(text, text, text, text, text, text, text),
  public.create_group_invite(text, integer, integer),
  public.join_group(text, text, text),
  public.approve_member(text, text),
  public.remove_member(text, text),
  public.leave_group(text),
  public.revoke_invite(text),
  public.update_member_display_name(text, text),
  public.groups_forget_user()
  from public, anon;
grant execute on function
  public.create_group(text, text, text, text, text, text, text),
  public.create_group_invite(text, integer, integer),
  public.join_group(text, text, text),
  public.approve_member(text, text),
  public.remove_member(text, text),
  public.leave_group(text),
  public.revoke_invite(text),
  public.update_member_display_name(text, text),
  public.groups_forget_user()
  to authenticated;

-- ============================================================================
-- Hallazgo #1 — CIERRE de la escalada por columnas (column-level UPDATE grants; sin triggers ni GUCs).
-- Las policies UPDATE de g1_01 (group_members_update_own, split_groups_update) permiten al cliente PATCHear
-- su fila vía PostgREST; sin restricción de columnas, un member podría escalar role='admin' o auto-aprobarse
-- status='active'. Cierre: group_members pierde TODO update directo (FREEZE total, rename vía RPC);
-- split_groups conserva un grant de columnas acotado (sin owner_user_id/group_id/created_at) que el canal
-- de sync G2 necesita. Los RPCs SECURITY DEFINER corren como owner de la función (bypass de column
-- privileges), así que approve/remove/leave/join/forget/rename siguen funcionando.
-- server_seq queda FUERA de todos los grants (el trigger stamp_group_seq lo pisa igual — defensa doble).
-- ============================================================================

-- group_members: FREEZE TOTAL de la unidad membership — el cliente PIERDE todo update directo. No se
-- re-otorga NINGUNA columna: el rename (unidad 'profile') pasa por el RPC update_member_display_name y toda
-- mutación de membresía por los RPCs SECURITY DEFINER (bypass de los grants de columna). ⇒ group_members
-- será PULL-ONLY en el canal de sync G2: el cliente jamás la empuja por PATCH ni apply_group_delta.
-- La policy group_members_update_own (g1_01) queda VIGENTE pero INERTE sin grant — se deja como defensa en
-- profundidad (si un re-grant futuro reintrodujera columnas, la policy aún acota a la fila propia).
revoke update on public.group_members from authenticated;

-- split_groups: meta editable + tombstone por sync (la policy update ya exige is_group_admin). El grant SE
-- MANTIENE porque el canal G2 (apply_group_delta SECURITY INVOKER) lo necesita. owner_user_id/group_id/
-- created_at fuera (la transferencia de ownership es RPC-only). Residual ACEPTADO: un admin malicioso podría
-- estampar field_hlcs futuros en la unidad 'meta' y envenenar el merge cliente de una transferencia de
-- ownership posterior (impacto: display stale en clientes; el server SIEMPRE tiene la verdad — owner_user_id
-- es server-only y la RLS lo protege).
revoke update on public.split_groups from authenticated;
grant update (name, icon_name, color_hex, currency_code, simplify_debts, show_debts_in_single_currency,
              members_can_invite, default_split_type, is_archived, is_hidden_for_all,
              hlc, field_hlcs, deleted, deleted_hlc, schema_version, updated_at)
  on public.split_groups to authenticated;

-- Higiene en las 3 tablas de contenido: re-grant de TODO menos (group_id, sync_id, server_seq) —
-- el canal G2 nunca necesita mover una fila de grupo/identidad, y el PK-move es patológico.
revoke update on public.split_expenses from authenticated;
grant update (amount, currency_code, expense_description, note, date, created_at, paid_by_member_key,
              split_type, is_settled, is_opening_balance, subcategory_name,
              field_hlcs, hlc, deleted, deleted_hlc, schema_version, updated_at)
  on public.split_expenses to authenticated;

revoke update on public.split_shares from authenticated;
grant update (expense_id, member_key, amount, is_paid,
              field_hlcs, hlc, deleted, deleted_hlc, schema_version, updated_at)
  on public.split_shares to authenticated;

revoke update on public.split_settlements from authenticated;
grant update (from_member_key, to_member_key, amount, currency_code, note, date, is_confirmed,
              field_hlcs, hlc, deleted, deleted_hlc, schema_version, updated_at)
  on public.split_settlements to authenticated;
