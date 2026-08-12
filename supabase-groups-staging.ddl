-- supabase-groups-staging.ddl — snapshot-contract of the Grupos→backend staging schema (project fostjbbwstyuunmmefuk).
-- Groups live on a SEPARATE channel from the personal Modo Nube schema (supabase-staging.ddl): the sequence
-- axis is PER GROUP (group_seq_counters / stamp_group_seq), the PK is (group_id, sync_id) / (group_id, member_key),
-- and RLS is by MEMBERSHIP (is_group_member / is_group_writer / is_group_admin) instead of (auth.uid() = user_id).
--
-- This file is the OFFLINE mold of the live staging schema, composed of the applied migrations, verbatim:
--   §1 g1_01_groups_infra_tables  — tables, per-group seq trigger, membership helpers, RLS policies, grants.
--   §2 g1_02_groups_rpcs          — the 9 membership/invite/rename RPCs + the column-level UPDATE grants (hallazgo #1).
--   §3 g2_01_apply_group_delta    — the push RPC of the sync channel (LWW per coherence unit, tombstone, group-scoped key).
--   §4 g6_01_migrate_group        — the migrate_group RPC (live CloudKit groups → backend: historical meta + members).
--   §5 g7_encrypt_groups          — pgcrypto at-rest encryption of the 8 † columns (bytea), the SECURITY INVOKER
--                                   groups_pull_rows_* readers, g7_recrypt_corpus / yala_try_decrypt / yala_logging_settings.
--   §6 g8_01_push_fanout + g8_02_push_machine_role — APNs fan-out support. g8_01 shipped the 2 RPCs to authenticated;
--                                   g8_02 (owner decision 2026-07-16) SUPERSEDES that model: a machine role `yala_push`
--                                   (EXECUTE-only, no table grants, no BYPASSRLS), get_group_push_tokens re-signed to
--                                   (p_group_id, p_exclude_user_id, p_exclude_device_token) with NO body guard (grants-only),
--                                   both RPCs REVOKED from authenticated and GRANTed only to yala_push. §6 shows the FINAL
--                                   post-g8_02 state (the g8_01 enumeration threat is dead).
--   §7 g10_01_transfer_group_ownership — the D10 batch "leave all my groups": hands ONE group's ownership to the
--                                   eligible heir (heir criterion VERBATIM from groups_forget_user loop1) and nothing
--                                   else. NEVER tombstones when there is no heir. No † columns ⇒ no p_key.
--   §8 g13_01_groups_consents     — the server-side GDPR record of the Groups consent (chip C1): one APPEND-ONLY
--                                   table (grant WITHOUT update/delete — the invariant is enforced by the grant,
--                                   not by a client convention) + record_groups_consent / groups_consent_state.
--                                   Account-scoped, like groups_forget_user: everything derives from auth.uid().
--                                   No † columns ⇒ no p_key.
-- Applied migrations (staging): g1_01, g1_02, g2_01, g6_01, and — 2026-07-16 —
--   g7_01_encrypt_groups_columns + g7_02_encrypt_groups_cutover (the G7 cutover: the 8 † columns become bytea NULLABLE,
--   and create_group / join_group / groups_forget_user / update_member_display_name / migrate_group / apply_group_delta
--   gain a p_key text argument) + g8_01_push_fanout + g8_02_push_machine_role. The G7 changes are woven IN-PLACE into
--   §1–§4 plus the new §5; g8_02 is woven IN-PLACE into §6 (the machine role + re-signed RPCs + machine-role grants).
--   Then — 2026-07-20 — g10_01_transfer_group_ownership (§7).
-- Regenerate on any groups-schema change by concatenating the applied migrations.
-- NOT staging-only anymore: the whole groups stack was PROMOTED TO PRODUCTION on 2026-07-16 (gate §12 Bloque A,
--   13 migrations) and g10_01 followed on 2026-07-21 — staging↔prod parity is verified by md5(pg_get_functiondef),
--   34/34 functions (see qa/cloud/README). This file still mirrors STAGING by name, but today both envs match.
-- KNOWN LAG (do not read as parity): g12_02_lock_down_stamp_group_seq (grants-only on stamp_group_seq, applied in
--   BOTH envs 2026-07-16) is NOT woven here — it changes no function body, only its ACL.
-- Vocabulary parity with the app (SplitMember.swift): status ∈ {active,pendingApproval,rejected,left,removed}; role ∈ {admin,member}.
--
-- SYNC NOTE (G2): the client PUSHES only split_groups (meta, update-only) + the 3 content tables via apply_group_delta
-- (§3, SECURITY INVOKER — RLS + column grants arbitrate); group_members is PULL-ONLY (the client NEVER pushes it: no
-- PATCH, no apply_group_delta write — the RPC rejects it with yala_bad_request). §2 revokes ALL direct UPDATE on
-- group_members from authenticated; the only client write path is the RPC update_member_display_name (rename, unidad
-- 'profile'); every membership mutation goes through the SECURITY DEFINER RPCs. Financial content SELECT
-- (split_expenses/shares/settlements) is gated to ACTIVE writers (is_group_writer), not is_group_member — a
-- pendingApproval member cannot read group content.


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

-- G7 (g7_02 cutover, 2026-07-16): the 8 columns marked `-- †` below are `bytea` at-rest (pgp_sym_encrypt; the key is
-- passed per-request, never resident). Physically the cutover DROP+RENAME moved each renamed column to the END of its
-- table's ordinal order; this legible mold keeps them IN-PLACE in the original semantic order — which is also the order
-- the groups_pull_rows_* readers (§5) return (they decrypt † back to text / decimal-scale-4, so the wire shape is
-- unchanged). See §5 for the extension, readers and helpers.

-- ============ split_groups (meta del grupo; group_id PRESERVA el string cloudKitZoneID) ============
create table public.split_groups (
  group_id text primary key,
  name bytea,  -- † G7: bytea at-rest (was text)
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
  display_name bytea,  -- † G7: bytea at-rest (was text)
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
  amount bytea,  -- † G7: bytea at-rest (was numeric(18,4); reader decrypts to text decimal scale-4)
  currency_code text,
  expense_description bytea,  -- † G7: bytea at-rest (was text)
  note bytea,  -- † G7: bytea at-rest (was text)
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
  amount bytea,  -- † G7: bytea at-rest (was numeric(18,4); reader decrypts to text decimal scale-4)
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
  amount bytea,  -- † G7: bytea at-rest (was numeric(18,4); reader decrypts to text decimal scale-4)
  currency_code text,
  note bytea,  -- † G7: bytea at-rest (was text)
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
-- g3_01_create_group_full_meta (2026-07-15): +3 params con DEFAULT (simplify/show/members_can_invite)
-- — la firma previa dejaba simplify/show en NULL y members_can_invite fijo, y como split_groups es
-- push:update_only el INSERT local jamás emite → divergencia local↔server permanente (clase Merkle-FX).
-- DROP de la firma de 7 args primero (create-or-replace con firma distinta = OVERLOAD → PGRST203).
-- coalesce(_, false): columnas sin NULL para que el Merkle canónico no distinga null-vs-false.
-- G7 (g7_02): +p_key text (before the 3 booleans) — name/display_name are now encrypted with pgp_sym_encrypt; DROP the
-- 10-arg signature first (create-or-replace with a new signature = OVERLOAD → PGRST203) + search_path adds `extensions`.
drop function if exists public.create_group(text, text, text, text, text, text, text, boolean, boolean, boolean);
create function public.create_group(
  p_group_id text,
  p_name text,
  p_currency_code text,
  p_icon_name text,
  p_color_hex text,
  p_display_name text,
  p_default_split_type text,
  p_key text,
  p_simplify_debts boolean default false,
  p_show_debts_in_single_currency boolean default false,
  p_members_can_invite boolean default false
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_uid     uuid := (select auth.uid());
  v_hlc     text;
  v_name    text;
  v_display text;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

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

  if exists (select 1 from split_groups where group_id = p_group_id) then
    raise exception 'yala_group_exists' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  begin
    insert into split_groups (
      group_id, name, icon_name, color_hex, currency_code,
      simplify_debts, show_debts_in_single_currency, members_can_invite,
      default_split_type, is_archived, is_hidden_for_all, owner_user_id,
      created_at, field_hlcs, hlc, deleted, schema_version
    ) values (
      p_group_id, pgp_sym_encrypt(v_name, p_key), p_icon_name, p_color_hex, p_currency_code,
      coalesce(p_simplify_debts, false), coalesce(p_show_debts_in_single_currency, false),
      coalesce(p_members_can_invite, false),
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
    p_group_id, v_uid::text, v_uid, pgp_sym_encrypt(v_display, p_key), 'admin', 'active',
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
-- G7 (g7_02): +p_key text — display_name is encrypted with pgp_sym_encrypt in the rebind/revive/insert branches; DROP
-- the 3-arg signature first + search_path adds `extensions`.
drop function if exists public.join_group(text, text, text);
create function public.join_group(
  p_token text,
  p_display_name text,
  p_key text,
  p_legacy_member_key text default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
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
    raise exception 'yala_invalid_invite' using errcode = 'P0001';
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
-- G7 (g7_02): +p_key text — the sentinel display_name '__deleted_user__' is ALSO encrypted (the column is uniformly
-- bytea); DROP the 0-arg signature first + search_path adds `extensions`.
drop function if exists public.groups_forget_user();
create function public.groups_forget_user(p_key text) returns jsonb
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

-- ============================================================================
-- 9. update_member_display_name — rename de la fila propia (unidad 'profile'). group_members pierde TODO
--    update directo (revoke total abajo); el rename del cliente pasa SOLO por aquí (PULL-ONLY en G2).
-- ============================================================================
-- G7 (g7_02): +p_key text — display_name is encrypted with pgp_sym_encrypt; DROP the 2-arg signature first +
-- search_path adds `extensions`.
drop function if exists public.update_member_display_name(text, text);
create function public.update_member_display_name(p_group_id text, p_display_name text, p_key text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
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

  select * into v_target from group_members
    where group_id = p_group_id and user_id = v_uid
      and deleted = false and status in ('active', 'pendingApproval')
    order by member_key asc limit 1 for update;
  if v_target.member_key is null then
    raise exception 'yala_member_not_found' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();
  update group_members set
    display_name = pgp_sym_encrypt(v_display, p_key),
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
-- G7 (g7_02): EXECUTE grants regenerados con las firmas NUEVAS (create_group / join_group / update_member_display_name
-- / groups_forget_user ganaron p_key text). create_group_invite / approve_member / remove_member / leave_group /
-- revoke_invite SIN cambios (no escriben columnas †).
revoke all on function
  public.create_group(text, text, text, text, text, text, text, text, boolean, boolean, boolean),
  public.create_group_invite(text, integer, integer),
  public.join_group(text, text, text, text),
  public.approve_member(text, text),
  public.remove_member(text, text),
  public.leave_group(text),
  public.revoke_invite(text),
  public.update_member_display_name(text, text, text),
  public.groups_forget_user(text)
  from public, anon;
grant execute on function
  public.create_group(text, text, text, text, text, text, text, text, boolean, boolean, boolean),
  public.create_group_invite(text, integer, integer),
  public.join_group(text, text, text, text),
  public.approve_member(text, text),
  public.remove_member(text, text),
  public.leave_group(text),
  public.revoke_invite(text),
  public.update_member_display_name(text, text, text),
  public.groups_forget_user(text)
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
-- G7 (g7_02): estos column-UPDATE grants fueron REGENERADOS VERBATIM (mismas columnas) tras el DROP+RENAME de las 8
-- columnas † — el DROP mata el grant por-columna (ata por attnum) y el RENAME del `_enc` NO lo resucita; sin
-- regenerarlos apply_group_delta (INVOKER) recibiría insufficient_privilege → push en NOOP silencioso.
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


-- ============================================================================
-- §3 — g2_01_apply_group_delta (RPC de push del canal de sync Grupos→backend)
-- ============================================================================
-- g2_01_apply_group_delta — RPC del canal de sync Grupos→backend (G2).
-- Gemelo ESTRUCTURAL de apply_delta (canal personal): PATCH por unidad de coherencia con field_hlcs,
-- LWW por HLC textual (>), tombstone row-level con guard delete-vs-upsert §d.4bis, jsonb_populate_record
-- para castear fields. Diferencias vs el molde:
--   1. clave (group_id, sync_id) para las 3 tablas de CONTENIDO (split_expenses/shares/settlements).
--   2. rama ESPECIAL split_groups: clave group_id (p_sync_id se IGNORA, puede venir null); UPDATE-ONLY —
--      los grupos nacen SOLO vía create_group, JAMÁS por INSERT aquí (upsert/tombstone de inexistente = noop).
--   3. group_members (pull-only) y cualquier otra entidad → yala_bad_request (sin interpolar p_entity).
--   4. GET DIAGNOSTICS tras CADA UPDATE dinámico: bajo la RLS de grupos un UPDATE puede afectar 0 filas
--      aunque el SELECT viera la fila (split_groups: SELECT es is_group_member pero UPDATE exige is_group_admin
--      → un member no-admin vería la meta pero el UPDATE la excluiría en silencio) → noop not_authorized_or_gone.
--   5. La RLS decide en silencio: INSERT que viola WITH CHECK lanza 42501 (insufficient_privilege); se
--      envuelve el cuerpo de escritura y se sanitiza a yala_not_authorized (sin oráculo de existencia).
-- SECURITY INVOKER (implícito, igual que apply_delta): la RLS de membership + los column grants de G1 arbitran.

-- === G7 (g7_02) — cirugía de apply_group_delta (AJUSTE review C2a) ===
--   +p_key text (7ª posición, tras p_field_hlcs). Las columnas † se QUITAN del jsonb ANTES de jsonb_populate_record
--   (su columna física es bytea → un populate desde el JSON plaintext fallaría) en AMBAS ramas (INSERT-fresh y UPDATE)
--   y en la value-list se emite pgp_sym_encrypt(...) con tri-estado NULL explícito: un unit que setea note=null → NULL
--   bytea (jamás cifrar la string "null"); columna ausente de la unit → no se toca. Los AMOUNTS se cifran como
--   ((v_win->>'amount')::numeric(18,4))::text — normaliza la escala ("30" → "30.0000"), byte-idéntico al recrypt de la
--   fase intermedia y a lo que el Merkle servía pre-G7. 'amount' es la ÚNICA columna † numérica. DROP de la firma de 8
--   args primero (C4); search_path adds `extensions` (C3: pgp_sym_* no resuelve con `public` pelado).
drop function if exists public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, integer);
create function public.apply_group_delta(
  p_entity text, p_group_id text, p_sync_id uuid, p_op text,
  p_fields jsonb, p_field_hlcs jsonb, p_key text,
  p_row_hlc text default null, p_schema_version integer default 1)
 returns jsonb
 language plpgsql
 set search_path = public, extensions
as $function$
declare
  c_tables constant text[] := array['split_expenses','split_shares','split_settlements'];
  v_uid           uuid := auth.uid();
  v_is_group_meta boolean := (p_entity = 'split_groups');
  v_found         boolean;
  v_exists        boolean := false;
  v_deleted       boolean;
  v_deleted_hlc   text;
  v_row_hlc       text;
  v_stored_fh     jsonb;
  v_delta_hlc     text;
  v_reinstates    boolean;
  v_unit          text;
  v_uhlc          text;
  v_floor         text;
  v_win_fields    jsonb := '{}'::jsonb;
  v_new_fh        jsonb;
  v_applied       text[] := array[]::text[];
  v_cols          text[];
  v_collist       text;
  v_vallist       text;
  v_rowcount      bigint;
  -- G7: columnas † (cifradas at-rest) por entidad + set derivado por delta.
  v_tcols         text[];
  v_enc_cols      text[];
  v_plain_fields  jsonb;
  v_plain_cols    text[];
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  if not v_is_group_meta and not (p_entity = any (c_tables)) then
    raise exception 'yala_bad_request' using errcode = 'P0001';
  end if;

  -- G7: columnas † de esta entidad (group_members es pull-only → jamás llega aquí).
  v_tcols := case p_entity
               when 'split_expenses'    then array['amount','expense_description','note']
               when 'split_shares'      then array['amount']
               when 'split_settlements' then array['amount','note']
               when 'split_groups'      then array['name']
               else array[]::text[]
             end;

  begin
    -------------------------------------------------- estado actual (la RLS restringe la visibilidad)
    if v_is_group_meta then
      execute
        'select true, deleted, deleted_hlc, hlc, field_hlcs from public.split_groups where group_id = $1'
        into v_found, v_deleted, v_deleted_hlc, v_row_hlc, v_stored_fh
        using p_group_id;
    else
      execute format(
        'select true, deleted, deleted_hlc, hlc, field_hlcs from public.%I where group_id = $1 and sync_id = $2',
        p_entity)
        into v_found, v_deleted, v_deleted_hlc, v_row_hlc, v_stored_fh
        using p_group_id, p_sync_id;
    end if;
    v_exists := coalesce(v_found, false);

    ------------------------------------------------------------------------ TOMBSTONE (row-level)
    -- Los tombstones NO escriben columnas † (solo deleted/deleted_hlc) → sin cirugía.
    if p_op = 'tombstone' then
      if not v_exists then
        if v_is_group_meta then
          return jsonb_build_object('op','tombstone','noop',true,'reason','group_not_found');
        end if;
        execute format(
          'insert into public.%I (group_id, sync_id, deleted, deleted_hlc, hlc, field_hlcs, schema_version)
           values ($1, $2, true, $3, coalesce($3, ''''), ''{}''::jsonb, $4)', p_entity)
          using p_group_id, p_sync_id, p_row_hlc, p_schema_version;
        return jsonb_build_object('op','tombstone','inserted',true,'applied',true,'noop',false);
      end if;
      if p_row_hlc > coalesce(v_row_hlc, '') then
        if v_is_group_meta then
          execute
            'update public.split_groups set deleted = true, deleted_hlc = $2, updated_at = now()
             where group_id = $1'
            using p_group_id, p_row_hlc;
        else
          execute format(
            'update public.%I set deleted = true, deleted_hlc = $3, updated_at = now()
             where group_id = $1 and sync_id = $2', p_entity)
            using p_group_id, p_sync_id, p_row_hlc;
        end if;
        get diagnostics v_rowcount = row_count;
        if v_rowcount = 0 then
          return jsonb_build_object('op','tombstone','noop',true,'reason','not_authorized_or_gone');
        end if;
        return jsonb_build_object('op','tombstone','applied',true,'noop',false);
      end if;
      return jsonb_build_object('op','tombstone','applied',false,'noop',true,'reason','stale_tombstone');
    end if;

    ------------------------------------------------------------------------------- UPSERT
    v_delta_hlc := (select max(value) from jsonb_each_text(p_field_hlcs));
    if v_delta_hlc is null then
      raise exception 'yala_bad_request' using errcode = 'P0001';
    end if;

    -------- fila INEXISTENTE
    if not v_exists then
      if v_is_group_meta then
        return jsonb_build_object('op','upsert','noop',true,'reason','group_not_found');
      end if;
      for v_unit in select key from jsonb_each_text(p_field_hlcs) loop
        v_win_fields := v_win_fields || coalesce(p_fields -> v_unit, '{}'::jsonb);
        v_applied := array_append(v_applied, v_unit);
      end loop;
      select array_agg(k) into v_cols from jsonb_object_keys(v_win_fields) k;

      if v_cols is null then
        execute format(
          'insert into public.%I (group_id, sync_id, field_hlcs, hlc, deleted, deleted_hlc, schema_version)
           values ($1, $2, $3, $4, false, null, $5)', p_entity)
          using p_group_id, p_sync_id, p_field_hlcs, v_delta_hlc, p_schema_version;
      else
        -- G7: separar † del resto (las † NO pasan por jsonb_populate_record — su columna física es bytea).
        v_enc_cols     := (select array_agg(c) from unnest(v_tcols) c where v_win_fields ? c);
        v_plain_fields := case when v_enc_cols is null then v_win_fields else v_win_fields - v_enc_cols end;
        select array_agg(k) into v_plain_cols from jsonb_object_keys(v_plain_fields) k;
        v_collist := concat_ws(', ',
          (select string_agg(format('%I', k), ', ') from unnest(coalesce(v_plain_cols, array[]::text[])) k),
          (select string_agg(format('%I', c), ', ') from unnest(coalesce(v_enc_cols, array[]::text[])) c));
        v_vallist := concat_ws(', ',
          (select string_agg(format('r.%I', k), ', ') from unnest(coalesce(v_plain_cols, array[]::text[])) k),
          (select string_agg(
             case when c = 'amount'
               then format('case when ($7->>%L) is null then null else pgp_sym_encrypt((($7->>%L)::numeric(18,4))::text, $8) end', c, c)
               else format('case when ($7->>%L) is null then null else pgp_sym_encrypt(($7->>%L), $8) end', c, c)
             end, ', ')
           from unnest(coalesce(v_enc_cols, array[]::text[])) c));
        execute format(
          'insert into public.%I (group_id, sync_id, %s, field_hlcs, hlc, deleted, deleted_hlc, schema_version)
           select $1, $2, %s, $4, $5, false, null, $6
           from jsonb_populate_record(null::public.%I, $3) r',
          p_entity, v_collist, v_vallist, p_entity)
          using p_group_id, p_sync_id, v_plain_fields, p_field_hlcs, v_delta_hlc, p_schema_version, v_win_fields, p_key;
      end if;
      return jsonb_build_object('op','upsert','inserted',true,'applied_units',to_jsonb(v_applied),'noop',false);
    end if;

    -------- fila EXISTENTE: guard delete-vs-upsert ROW-LEVEL (§d.4bis congelado)
    v_reinstates := (v_delta_hlc > coalesce(v_deleted_hlc, ''));
    if v_deleted and not v_reinstates then
      return jsonb_build_object('op','upsert','noop',true,'reason','stale_over_tombstone');
    end if;

    for v_unit, v_uhlc in select key, value from jsonb_each_text(p_field_hlcs) loop
      v_floor := coalesce(v_stored_fh ->> v_unit, '');
      if v_deleted then v_floor := greatest(v_floor, coalesce(v_deleted_hlc, '')); end if;
      if v_uhlc > v_floor then
        v_win_fields := v_win_fields || coalesce(p_fields -> v_unit, '{}'::jsonb);
        v_applied := array_append(v_applied, v_unit);
      end if;
    end loop;

    if array_length(v_applied, 1) is null and not (v_deleted and v_reinstates) then
      return jsonb_build_object('op','upsert','noop',true,'reason','all_units_stale');
    end if;

    v_new_fh := coalesce(v_stored_fh, '{}'::jsonb);
    foreach v_unit in array v_applied loop
      v_new_fh := v_new_fh || jsonb_build_object(v_unit, p_field_hlcs ->> v_unit);
    end loop;

    select array_agg(k) into v_cols from jsonb_object_keys(v_win_fields) k;

    if v_cols is null then
      if v_is_group_meta then
        execute
          'update public.split_groups set deleted = false, deleted_hlc = null,
             field_hlcs = $2, hlc = coalesce((select max(value) from jsonb_each_text($2)), $3),
             schema_version = $4, updated_at = now()
           where group_id = $1'
          using p_group_id, v_new_fh, v_delta_hlc, p_schema_version;
      else
        execute format(
          'update public.%I set deleted = false, deleted_hlc = null,
             field_hlcs = $3, hlc = coalesce((select max(value) from jsonb_each_text($3)), $4),
             schema_version = $5, updated_at = now()
           where group_id = $1 and sync_id = $2', p_entity)
          using p_group_id, p_sync_id, v_new_fh, v_delta_hlc, p_schema_version;
      end if;
      get diagnostics v_rowcount = row_count;
    else
      -- G7: separar † del resto. v_collist es position-independiente (se computa una vez); v_vallist se construye
      -- POR RAMA con las posiciones EXACTAS de su USING (sin params sin referenciar): la rama split_groups omite
      -- p_sync_id (win=$6, key=$7); la de contenido lo incluye (win=$7, key=$8).
      v_enc_cols     := (select array_agg(c) from unnest(v_tcols) c where v_win_fields ? c);
      v_plain_fields := case when v_enc_cols is null then v_win_fields else v_win_fields - v_enc_cols end;
      select array_agg(k) into v_plain_cols from jsonb_object_keys(v_plain_fields) k;
      v_collist := concat_ws(', ',
        (select string_agg(format('%I', k), ', ') from unnest(coalesce(v_plain_cols, array[]::text[])) k),
        (select string_agg(format('%I', c), ', ') from unnest(coalesce(v_enc_cols, array[]::text[])) c));
      if v_is_group_meta then
        v_vallist := concat_ws(', ',
          (select string_agg(format('r.%I', k), ', ') from unnest(coalesce(v_plain_cols, array[]::text[])) k),
          (select string_agg(
             case when c = 'amount'
               then format('case when ($6->>%L) is null then null else pgp_sym_encrypt((($6->>%L)::numeric(18,4))::text, $7) end', c, c)
               else format('case when ($6->>%L) is null then null else pgp_sym_encrypt(($6->>%L), $7) end', c, c)
             end, ', ')
           from unnest(coalesce(v_enc_cols, array[]::text[])) c));
        execute format(
          'update public.split_groups as t set (%s) = (select %s from jsonb_populate_record(null::public.split_groups, $2) r),
             field_hlcs = $3, hlc = (select max(value) from jsonb_each_text($3)),
             deleted = case when $4 then false else t.deleted end,
             deleted_hlc = case when $4 then null else t.deleted_hlc end,
             schema_version = $5, updated_at = now()
           where t.group_id = $1',
          v_collist, v_vallist)
          using p_group_id, v_plain_fields, v_new_fh, (v_deleted and v_reinstates), p_schema_version, v_win_fields, p_key;
      else
        v_vallist := concat_ws(', ',
          (select string_agg(format('r.%I', k), ', ') from unnest(coalesce(v_plain_cols, array[]::text[])) k),
          (select string_agg(
             case when c = 'amount'
               then format('case when ($7->>%L) is null then null else pgp_sym_encrypt((($7->>%L)::numeric(18,4))::text, $8) end', c, c)
               else format('case when ($7->>%L) is null then null else pgp_sym_encrypt(($7->>%L), $8) end', c, c)
             end, ', ')
           from unnest(coalesce(v_enc_cols, array[]::text[])) c));
        execute format(
          'update public.%I as t set (%s) = (select %s from jsonb_populate_record(null::public.%I, $3) r),
             field_hlcs = $4, hlc = (select max(value) from jsonb_each_text($4)),
             deleted = case when $5 then false else t.deleted end,
             deleted_hlc = case when $5 then null else t.deleted_hlc end,
             schema_version = $6, updated_at = now()
           where t.group_id = $1 and t.sync_id = $2',
          p_entity, v_collist, v_vallist, p_entity)
          using p_group_id, p_sync_id, v_plain_fields, v_new_fh, (v_deleted and v_reinstates), p_schema_version, v_win_fields, p_key;
      end if;
      get diagnostics v_rowcount = row_count;
    end if;

    if v_rowcount = 0 then
      return jsonb_build_object('op','upsert','noop',true,'reason','not_authorized_or_gone');
    end if;

    return jsonb_build_object(
      'op','upsert','applied_units',to_jsonb(v_applied),
      'resurrected', (v_deleted and v_reinstates), 'noop', false);

  exception
    when insufficient_privilege then
      raise exception 'yala_not_authorized' using errcode = 'P0001';
  end;
end;
$function$;

-- Grants: revocar de public/anon, otorgar solo a authenticated (la RLS de membership arbitra dentro). Firma NUEVA (+p_key).
revoke all on function public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer) from public, anon;
grant execute on function public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer) to authenticated;

-- ============================================================================
-- §4 — g6_01_migrate_group (Grupos→backend G6-1, migración de grupos VIVOS de CloudKit al backend)
-- ============================================================================
-- migrate_group(p_group_id, p_meta, p_members) — crea EN UNA TRANSACCIÓN ATÓMICA el split_groups con su META
-- HISTÓRICA (created_at del payload, NO now()) + los N group_members TAL CUAL (member_key legacy, status/role/
-- joined_at históricos). Cierra §9 (D7: el OWNER migra el grupo entero y luego RE-INVITA — el rebind por
-- legacy_member_key de join_group [L442-461] reclama las filas placeholder user_id NULL). NO extiende
-- create_group (fuerza owner member_key=sub → rompería las FKs del historial del owner; fuerza created_at=now()).
-- IDEMPOTENTE-SUAVE: el uploader one-shot reintenta tras timeout → si el grupo existe con ESTE owner,
-- {already:true, group_id, owner_user_id, server_seq} SIN tocar nada (ignora p_members del reintento; gana el
-- 1er intento, sin reconciliación de drift); con OTRO owner → yala_group_exists. member_key duplicado en el
-- payload → yala_bad_input ANTES del PK (evita el unique_violation crudo → 502 → retry-loop eterno del
-- uploader) + cinturón exception when unique_violation. Riesgo ACEPTADO: squat de group_id (DoS insider-only —
-- exige el zoneID de 128 bits visible solo para members; placeholders reclamables solo con token del caller).
-- server_seq lo pone SIEMPRE el trigger stamp_group_seq. Contrato completo + decisiones owner (R10 / token-en-
-- marcador / drift / squat / owner-debe-traer-member_key-legacy) en qa/cloud/g6_01_migrate_group.sql (2026-07-16).
-- G7 (g7_02): +p_key text — la meta name y cada display_name se cifran con pgp_sym_encrypt; DROP de la firma de 3 args
-- primero + search_path adds `extensions`.
drop function if exists public.migrate_group(text, jsonb, jsonb);
create function public.migrate_group(
  p_group_id text,
  p_meta jsonb,
  p_members jsonb,
  p_key text
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_uid       uuid := (select auth.uid());
  v_hlc       text;
  v_existing  record;
  v_owners    integer;
  v_total     integer;
  v_distinct  integer;
  v_name      text;
  v_currency  text;
  v_member    jsonb;
  v_mkey      text;
  v_role      text;
  v_status    text;
  v_display   text;
  v_is_owner  boolean;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  if p_group_id is null or length(p_group_id) < 8 or length(p_group_id) > 120 then
    raise exception 'yala_invalid_group_id' using errcode = 'P0001';
  end if;

  select owner_user_id, server_seq into v_existing
    from split_groups where group_id = p_group_id;
  if found then
    if v_existing.owner_user_id = v_uid then
      return jsonb_build_object('already', true, 'group_id', p_group_id,
                                'owner_user_id', v_existing.owner_user_id, 'server_seq', v_existing.server_seq);
    else
      raise exception 'yala_group_exists' using errcode = 'P0001';
    end if;
  end if;

  v_name     := btrim(coalesce(p_meta->>'name', ''));
  v_currency := coalesce(p_meta->>'currency_code', '');
  if v_name = '' or length(v_name) > 120 or length(v_currency) <> 3 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  if p_members is null or jsonb_typeof(p_members) <> 'array' or jsonb_array_length(p_members) = 0 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;
  select count(*) filter (where coalesce((e->>'is_owner')::boolean, false)) into v_owners
    from jsonb_array_elements(p_members) e;
  if v_owners <> 1 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;
  select count(*), count(distinct e->>'member_key') into v_total, v_distinct
    from jsonb_array_elements(p_members) e;
  if v_total <> v_distinct then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  v_hlc := server_hlc();

  insert into profiles (id) values (v_uid) on conflict (id) do nothing;

  begin
    insert into split_groups (
      group_id, name, icon_name, color_hex, currency_code,
      simplify_debts, show_debts_in_single_currency, members_can_invite,
      default_split_type, is_archived, is_hidden_for_all, owner_user_id,
      created_at, field_hlcs, hlc, deleted, schema_version
    ) values (
      p_group_id, pgp_sym_encrypt(v_name, p_key), p_meta->>'icon_name', p_meta->>'color_hex', v_currency,
      coalesce((p_meta->>'simplify_debts')::boolean, false),
      coalesce((p_meta->>'show_debts_in_single_currency')::boolean, false),
      coalesce((p_meta->>'members_can_invite')::boolean, false),
      p_meta->>'default_split_type', false, false, v_uid,
      coalesce((p_meta->>'created_at')::timestamptz, now()),
      jsonb_build_object('meta', v_hlc), v_hlc, false, 1
    );
  exception when unique_violation then
    raise exception 'yala_group_exists' using errcode = 'P0001';
  end;

  for v_member in select value from jsonb_array_elements(p_members)
  loop
    v_mkey     := btrim(coalesce(v_member->>'member_key', ''));
    v_role     := coalesce(v_member->>'role', '');
    v_status   := coalesce(v_member->>'status', '');
    v_display  := btrim(coalesce(v_member->>'display_name', ''));
    v_is_owner := coalesce((v_member->>'is_owner')::boolean, false);
    if v_mkey = '' or v_display = '' or length(v_display) > 80
       or v_role not in ('admin', 'member')
       or v_status not in ('active', 'pendingApproval', 'left', 'removed') then
      raise exception 'yala_bad_input' using errcode = 'P0001';
    end if;
    insert into group_members (
      group_id, member_key, user_id, display_name, role, status,
      joined_at, field_hlcs, hlc, deleted, schema_version
    ) values (
      p_group_id, v_mkey,
      case when v_is_owner then v_uid else null end,
      pgp_sym_encrypt(v_display, p_key), v_role, v_status,
      coalesce((v_member->>'joined_at')::timestamptz, now()),
      jsonb_build_object('profile', v_hlc, 'membership', v_hlc), v_hlc, false, 1
    );
  end loop;

  return jsonb_build_object('already', false, 'group_id', p_group_id, 'owner_user_id', v_uid);

exception
  when unique_violation then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  when invalid_datetime_format or datetime_field_overflow or invalid_text_representation then
    raise exception 'yala_bad_input' using errcode = 'P0001';
end $$;

-- g6_02_revoke_migrate_group_execute (2026-07-28): `authenticated` YA NO puede ejecutarla, y por eso
-- este bloque incluye ahora ese rol en el revoke en vez de otorgarle EXECUTE (idiom de
-- `get_group_push_tokens` más abajo). La Fase 1 de la simplificación de Grupos borró el cliente de
-- migración y cerró la ruta del gateway (`POST /groups/rpc/migrate_group` → 404), decidiendo NO
-- dropear la función. Pero el 404 solo cierra la puerta de la APP —el cliente habla únicamente con el
-- Worker— y PostgREST es público: con un JWT de usuario la función seguía invocable vía
-- `/rest/v1/rpc/migrate_group`. Aplicado a los DOS entornos el mismo día, para que no divergieran en
-- grants. La función sigue en la base, inerte de verdad; el golden que afirma el 404 no cambia.
revoke all on function public.migrate_group(text, jsonb, jsonb, text) from public, anon, authenticated;


-- ============================================================================
-- §5 — g7_encrypt_groups (g7_01_encrypt_groups_columns + g7_02_encrypt_groups_cutover, 2026-07-16)
-- ============================================================================
-- Cifrado pgcrypto de las 8 columnas † (bytea at-rest) — protege DUMPS/BACKUPS lógicos: una fila filtrada no revela
-- montos ni descripciones. La llave viaja como ARGUMENTO de request (p_key text), NUNCA residente en la DB. La RLS
-- sigue arbitrando ANTES de descifrar (los readers son SECURITY INVOKER). El cutover de columnas (DROP plaintext +
-- RENAME _enc → nombre), los 6 RPCs escritores con p_key y los column-UPDATE grants regenerados están tejidos IN-PLACE
-- en §1–§4. Aquí quedan: la extensión, el motor de recrypt SERVICE-ONLY, el wrapper de descifrado tolerante-por-fila,
-- el gate de logging §16e y los 5 RPCs LECTORES groups_pull_rows_* (el Worker pasa de GET select=* a llamarlos por POST
-- — la llave JAMÁS en URL/query). NOTA: las columnas espejo <col>_enc que g7_01 creó fueron DROPeadas por el cutover de
-- g7_02 (ADD+RENAME), así que NO existen en el estado vivo — este mold refleja el estado FINAL.
set local check_function_bodies = off;

create extension if not exists pgcrypto with schema extensions;

-- ---- g7_recrypt_corpus(p_key) — motor de re-cifrado IDEMPOTENTE, SERVICE-ONLY (g7_01) ----
-- Copia plaintext→cifrado para las 8 columnas SOLO donde `<col>_enc is null and <col> is not null` (idempotente).
-- Amounts como pgp_sym_encrypt(amount::text, p_key) (escala-4 preservada). Devuelve counts por columna (jsonb).
-- REVOKE all de public/anon/authenticated → solo ejecutable en contexto SERVICE. Se aplicó vía execute_sql directo
-- (NO migración: la llave no toca schema_migrations). NOTA: las columnas <col>_enc que referencia YA NO existen tras
-- el cutover — la función queda como artefacto histórico del estado vivo (creada por g7_01, jamás DROPeada).
create or replace function public.g7_recrypt_corpus(p_key text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_counts jsonb := '{}'::jsonb;
  n bigint;
begin
  update public.split_groups set name_enc = pgp_sym_encrypt(name, p_key)
    where name_enc is null and name is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('split_groups.name', n);

  update public.group_members set display_name_enc = pgp_sym_encrypt(display_name, p_key)
    where display_name_enc is null and display_name is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('group_members.display_name', n);

  update public.split_expenses set amount_enc = pgp_sym_encrypt(amount::text, p_key)
    where amount_enc is null and amount is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('split_expenses.amount', n);

  update public.split_expenses set expense_description_enc = pgp_sym_encrypt(expense_description, p_key)
    where expense_description_enc is null and expense_description is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('split_expenses.expense_description', n);

  update public.split_expenses set note_enc = pgp_sym_encrypt(note, p_key)
    where note_enc is null and note is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('split_expenses.note', n);

  update public.split_settlements set amount_enc = pgp_sym_encrypt(amount::text, p_key)
    where amount_enc is null and amount is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('split_settlements.amount', n);

  update public.split_settlements set note_enc = pgp_sym_encrypt(note, p_key)
    where note_enc is null and note is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('split_settlements.note', n);

  update public.split_shares set amount_enc = pgp_sym_encrypt(amount::text, p_key)
    where amount_enc is null and amount is not null;
  get diagnostics n = row_count; v_counts := v_counts || jsonb_build_object('split_shares.amount', n);

  return v_counts;
end $$;

revoke all on function public.g7_recrypt_corpus(text) from public, anon, authenticated;

-- ---- yala_try_decrypt(p_c, p_key) — descifrado TOLERANTE POR FILA (g7_01) ----
-- SECURITY DEFINER + search_path = public, extensions (los readers INVOKER que la invocan NO dependen de un EXECUTE de
-- pgp_sym_decrypt concedido a authenticated). Atrapa el fallo de descifrado POR LLAMADA → NULL: una fila envenenada
-- (bytea basura escrito por un member malicioso vía PostgREST directo) NO revienta la página del pull/merkle — devuelve
-- NULL en esa columna y el canario de divergencia del Merkle la delata. UNA sola operación falible tras el guard de NULL.
create or replace function public.yala_try_decrypt(p_c bytea, p_key text) returns text
language plpgsql security definer set search_path = public, extensions as $$
begin
  if p_c is null then
    return null;
  end if;
  return pgp_sym_decrypt(p_c, p_key);
exception when others then
  return null;
end $$;

revoke all on function public.yala_try_decrypt(bytea, text) from public, anon;
grant execute on function public.yala_try_decrypt(bytea, text) to authenticated;

-- ---- yala_logging_settings() — gate §16e (la llave JAMÁS en logs) (g7_02) ----
-- Devuelve los settings de logging que garantizan que la llave (viaja como argumento) no aterrice en ningún log. El
-- golden g7-logging-settings asserta {log_statement:"ddl", log_min_duration_statement:"-1",
-- log_parameter_max_length_on_error:"0"}. Si el owner cambia estos settings el golden lo delata.
create or replace function public.yala_logging_settings() returns jsonb
language sql security definer stable set search_path = public as $$
  select jsonb_build_object(
    'log_statement', current_setting('log_statement', true),
    'log_min_duration_statement', current_setting('log_min_duration_statement', true),
    'log_parameter_max_length_on_error', current_setting('log_parameter_max_length_on_error', true)
  )
$$;
revoke all on function public.yala_logging_settings() from public, anon;
grant execute on function public.yala_logging_settings() to authenticated;

-- ---- RPCs LECTORES groups_pull_rows_<tabla> — SECURITY INVOKER (RLS del caller) + descifrado de † (g7_02) ----
-- returns table con TODAS las columnas (mismo orden/nombre que la tabla — ORDEN SEMÁNTICO), los AMOUNTS como `text`
-- (string decimal exacto escala-4, resolución C1), los demás † descifrados a text. `where group_id = p_group_id and
-- server_seq > p_after_seq order by server_seq asc limit p_limit`. GRANT a authenticated (un caller sin llave solo
-- obtiene NULLs en las †, sin fuga). El Worker cambia de leer select=* (GET) a llamar estos RPCs (POST body).
create or replace function public.groups_pull_rows_split_groups(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, name text, icon_name text, color_hex text, currency_code text,
  simplify_debts boolean, show_debts_in_single_currency boolean, members_can_invite boolean,
  default_split_type text, is_archived boolean, is_hidden_for_all boolean, owner_user_id uuid,
  created_at timestamptz, field_hlcs jsonb, hlc text, deleted boolean, deleted_hlc text,
  server_seq bigint, schema_version integer, updated_at timestamptz
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, public.yala_try_decrypt(t.name, p_key), t.icon_name, t.color_hex, t.currency_code,
    t.simplify_debts, t.show_debts_in_single_currency, t.members_can_invite,
    t.default_split_type, t.is_archived, t.is_hidden_for_all, t.owner_user_id,
    t.created_at, t.field_hlcs, t.hlc, t.deleted, t.deleted_hlc,
    t.server_seq, t.schema_version, t.updated_at
  from public.split_groups t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

create or replace function public.groups_pull_rows_group_members(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, member_key text, user_id uuid, display_name text, role text, status text,
  joined_at timestamptz, field_hlcs jsonb, hlc text, deleted boolean, deleted_hlc text,
  server_seq bigint, schema_version integer, updated_at timestamptz
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.member_key, t.user_id, public.yala_try_decrypt(t.display_name, p_key), t.role, t.status,
    t.joined_at, t.field_hlcs, t.hlc, t.deleted, t.deleted_hlc,
    t.server_seq, t.schema_version, t.updated_at
  from public.group_members t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

create or replace function public.groups_pull_rows_split_expenses(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, sync_id uuid, amount text, currency_code text, expense_description text,
  note text, date timestamptz, created_at timestamptz, paid_by_member_key text, split_type text,
  is_settled boolean, is_opening_balance boolean, subcategory_name text, field_hlcs jsonb,
  hlc text, deleted boolean, deleted_hlc text, server_seq bigint, schema_version integer, updated_at timestamptz
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.sync_id,
    public.yala_try_decrypt(t.amount, p_key), t.currency_code,
    public.yala_try_decrypt(t.expense_description, p_key),
    public.yala_try_decrypt(t.note, p_key),
    t.date, t.created_at, t.paid_by_member_key, t.split_type,
    t.is_settled, t.is_opening_balance, t.subcategory_name, t.field_hlcs,
    t.hlc, t.deleted, t.deleted_hlc, t.server_seq, t.schema_version, t.updated_at
  from public.split_expenses t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

create or replace function public.groups_pull_rows_split_shares(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, sync_id uuid, expense_id uuid, member_key text, amount text, is_paid boolean,
  field_hlcs jsonb, hlc text, deleted boolean, deleted_hlc text,
  server_seq bigint, schema_version integer, updated_at timestamptz
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.sync_id, t.expense_id, t.member_key,
    public.yala_try_decrypt(t.amount, p_key), t.is_paid,
    t.field_hlcs, t.hlc, t.deleted, t.deleted_hlc,
    t.server_seq, t.schema_version, t.updated_at
  from public.split_shares t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

create or replace function public.groups_pull_rows_split_settlements(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, sync_id uuid, from_member_key text, to_member_key text, amount text, currency_code text,
  note text, date timestamptz, is_confirmed boolean, field_hlcs jsonb, hlc text, deleted boolean,
  deleted_hlc text, server_seq bigint, schema_version integer, updated_at timestamptz
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.sync_id, t.from_member_key, t.to_member_key,
    public.yala_try_decrypt(t.amount, p_key), t.currency_code,
    public.yala_try_decrypt(t.note, p_key), t.date, t.is_confirmed, t.field_hlcs,
    t.hlc, t.deleted, t.deleted_hlc, t.server_seq, t.schema_version, t.updated_at
  from public.split_settlements t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

-- Grants de EXECUTE de los 5 RPCs lectores: revocar de public/anon, otorgar solo a authenticated.
revoke all on function
  public.groups_pull_rows_split_groups(text, bigint, int, text),
  public.groups_pull_rows_group_members(text, bigint, int, text),
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_shares(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  from public, anon;
grant execute on function
  public.groups_pull_rows_split_groups(text, bigint, int, text),
  public.groups_pull_rows_group_members(text, bigint, int, text),
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_shares(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  to authenticated;

-- ============================================================================================
-- §6 — g8_01_push_fanout + g8_02_push_machine_role (2026-07-16): RPCs de soporte del fan-out APNs.
-- ESTADO FINAL post-g8_02 (verbatim de la migración g8_02; g8_02 SUPERSEDE las funciones de g8_01).
-- ============================================================================================

-- DECISIÓN OWNER (2026-07-16, g8_02_push_machine_role): el owner RECHAZÓ el modelo de amenaza de g8_01
-- ("cualquier co-member puede ENUMERAR device_tokens de sus co-members bajo demanda") y pidió la
-- arquitectura robusta a largo plazo. g8_02 la implementa:
--   1. Un ROL Postgres `yala_push` de scope MÍNIMO (nologin; solo `usage` sobre public + EXECUTE sobre 2
--      funciones — CERO grants de tabla, sin BYPASSRLS).
--   2. get_group_push_tokens se RE-FIRMA a (p_group_id, p_exclude_user_id, p_exclude_device_token) — la
--      exclusión pasa de auth.uid() a parámetros (el Worker no lleva el JWT del autor); el device emisor
--      opcional cierra el residual multi-device del autor de g8_01.
--   3. Ambos RPCs pierden todo guard de auth/rol en el cuerpo (SECURITY DEFINER → current_user = OWNER, no
--      el rol del caller; un guard por current_user rompería la función para el Worker). Los GRANTS son el
--      ÚNICO control: REVOKE de public/anon/authenticated + GRANT SOLO a yala_push.
-- El Worker los llama con un JWT DE MÁQUINA (HS256, legacy secret, claim role=yala_push, exp 10 años). Un
-- cliente `authenticated` que los llame recibe 403 + code 42501 (insufficient_privilege). La ENUMERACIÓN
-- del modelo g8_01 MUERE; el griefing del prune muere; el fan-out deja de depender del JWT del autor.
-- ⚠️ DURABILIDAD: si el owner revoca el legacy secret (rotación de firmas), el JWT de máquina deja de ser
--   aceptado → el fan-out muere en silencio (401; la cadencia de pull cubre). Canario: `console.log
--   "upstream 401"` del fan-out. `push_tokens` YA EXISTE (DDL contrato :247-260) — no se recrea.

-- =====================================================================================================
-- 0. Rol de máquina `yala_push` — scope mínimo (idempotente).
-- =====================================================================================================
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'yala_push') then
    create role yala_push nologin;
  end if;
end $$;
grant yala_push to authenticator;   -- authenticator debe poder SET ROLE yala_push (claim role del JWT)
grant usage on schema public to yala_push;

-- =====================================================================================================
-- 1. get_group_push_tokens — firma NUEVA (p_group_id, p_exclude_user_id, p_exclude_device_token). SIN
--    guard de auth/rol (grants-only). Exclusión del device emisor: token NON-NULL → excluir SOLO ese par
--    (multi-device del autor cerrado); NULL → fallback g8_01 (excluir todos los devices del autor).
-- =====================================================================================================
drop function if exists public.get_group_push_tokens(text);

create or replace function public.get_group_push_tokens(
  p_group_id text,
  p_exclude_user_id uuid,
  p_exclude_device_token text default null
)
returns table(user_id uuid, device_token text, platform text)
language plpgsql security definer stable set search_path = public as $$
begin
  return query
    select pt.user_id, pt.device_token, pt.platform
    from push_tokens pt
    join group_members gm on gm.user_id = pt.user_id and gm.group_id = p_group_id
    where gm.user_id is not null
      and gm.deleted = false
      and gm.status = 'active'          -- pendingApproval EXCLUIDO (no es writer → no ve contenido)
      and case
            when p_exclude_device_token is not null
              then not (pt.user_id = p_exclude_user_id and pt.device_token = p_exclude_device_token)
            else pt.user_id <> p_exclude_user_id
          end;
end $$;

-- AJUSTE #4: REVOKE nombra `public` EXPLÍCITO (authenticated es miembro de PUBLIC) y corre DESPUÉS del
-- CREATE; GRANT SOLO a yala_push (el único rol que puede EXECUTE tras g8_02).
revoke all on function public.get_group_push_tokens(text, uuid, text) from public, anon, authenticated;
grant execute on function public.get_group_push_tokens(text, uuid, text) to yala_push;

-- =====================================================================================================
-- 2. prune_push_token — firma SIN cambio (create or replace). Cuerpo sin guard de radio ni auth.uid()
--    (grants-only): el radio de g8_01 protegía de callers authenticated maliciosos; ahora SOLO yala_push.
-- =====================================================================================================
create or replace function public.prune_push_token(p_user_id uuid, p_device_token text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_deleted integer;
begin
  delete from push_tokens where user_id = p_user_id and device_token = p_device_token;
  get diagnostics v_deleted = row_count;
  return jsonb_build_object('pruned', v_deleted);
end $$;

revoke all on function public.prune_push_token(uuid, text) from public, anon, authenticated;
grant execute on function public.prune_push_token(uuid, text) to yala_push;



-- ============================================================================
-- §7 — g10_01_transfer_group_ownership (D10, batch "salir de todos mis grupos")
-- ============================================================================
-- Transfiere el ownership de UN grupo backend al co-member elegible más antiguo y NADA MÁS. El caller
-- (orquestador batch) llama leave_group justo después — ya pasa el guard yala_owner_cannot_leave porque
-- owner_user_id ya no es él. Diferencias vs groups_forget_user (§5): opera sobre UN grupo (sin loop), NO
-- anonimiza al caller, NO borra push_tokens, y **JAMÁS tombstonea** cuando no hay heredero (invariante D10:
-- nunca destruir datos de terceros) → {transferred:false, reason:'no_eligible_owner'} y el cliente lo manda
-- a "necesitan tu decisión". IDEMPOTENTE-SUAVE: grupo inexistente/deleted/owner distinto → {already:true}
-- sin tocar nada ⇒ retry-transient SEGURO. Heredero VERBATIM de groups_forget_user loop1: (role='admin')
-- desc, joined_at asc, member_key asc; user_id not null (los placeholders NULL de un grupo legacy migrado
-- sin reclamar NUNCA son herederos: no hay auth.user al que ceder), status='active', <> caller.
-- NO escribe columnas † ⇒ search_path = public SIN extensions, y NO entra en RPC_NEEDS_ENC_KEY del gateway.
--
-- ⚠️ TEXTO VERBATIM DE LO APLICADO (no del .sql del repo): qa/cloud/g10_01_transfer_group_ownership.sql
-- lleva los comentarios extendidos, y lo aplicado en AMBOS envs los tiene condensados. Como este archivo es
-- el molde OFFLINE del schema VIVO y pg_get_functiondef SÍ incluye los comentarios del cuerpo, aquí va el
-- texto aplicado — el que produce md5 dd3a049c793f6fe2479552ac0c7fba3f en staging Y en prod. El código es
-- idéntico al del .sql (normalizados ambos: 5ac870418e96cfdd80ba024ad35c8c18).

create or replace function public.transfer_group_ownership(p_group_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := (select auth.uid());
  v_hlc   text;
  v_owner uuid;
  v_found boolean;
  v_cand  record;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  if p_group_id is null or length(p_group_id) < 8 or length(p_group_id) > 120 then
    raise exception 'yala_invalid_group_id' using errcode = 'P0001';
  end if;

  select owner_user_id into v_owner from split_groups
    where group_id = p_group_id and deleted = false;
  v_found := found;
  if not v_found or v_owner is distinct from v_uid then
    return jsonb_build_object('transferred', false, 'already', true,
                              'new_owner_member_key', null, 'reason', null, 'group_id', p_group_id);
  end if;

  select * into v_cand from group_members
    where group_id = p_group_id and deleted = false and status = 'active'
      and user_id is not null and user_id <> v_uid
    order by (coalesce(role, '') = 'admin') desc, joined_at asc, member_key asc
    limit 1;

  if v_cand.member_key is null then
    return jsonb_build_object('transferred', false, 'already', false,
                              'new_owner_member_key', null, 'reason', 'no_eligible_owner', 'group_id', p_group_id);
  end if;

  v_hlc := server_hlc();

  if v_cand.role is distinct from 'admin' then
    update group_members set
      role       = 'admin',
      hlc        = v_hlc,
      updated_at = now(),
      field_hlcs = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{membership}', to_jsonb(v_hlc))
      where group_id = p_group_id and member_key = v_cand.member_key;
  end if;

  update split_groups set
    owner_user_id = v_cand.user_id,
    hlc           = v_hlc,
    updated_at    = now(),
    field_hlcs    = jsonb_set(coalesce(field_hlcs, '{}'::jsonb), '{meta}', to_jsonb(v_hlc))
    where group_id = p_group_id;

  return jsonb_build_object('transferred', true, 'already', false,
                            'new_owner_member_key', v_cand.member_key,
                            'new_owner_user_id', v_cand.user_id,
                            'reason', null, 'group_id', p_group_id);
end $$;

-- Grants: molde de grupos (REVOKE public/anon + GRANT authenticated). Resultado verificado en AMBOS envs:
-- proacl {postgres=X/postgres, authenticated=X/postgres, service_role=X/postgres}.
revoke all on function public.transfer_group_ownership(text) from public, anon;
grant execute on function public.transfer_group_ownership(text) to authenticated;

-- ============================================================================
-- §8 — g13_01_groups_consents (chip C1: el registro server-side del consent de Grupos)
-- ============================================================================
-- POR QUÉ. El consent de Grupos vivía en dos `PrefSyncKey` cuyo destino era una propiedad del INSTANTE en
-- que se escribían: con `storageMode == .icloud` —el default del parque— acababan en el iCloud KV del Apple
-- ID y jamás llegaban a Yala, mientras Grupos va al 100 % sin exigir Modo Nube. ⇒ para el grueso de los
-- usuarios el registro NO existía en ningún sitio que Yala controle (RGPD Art. 7.1). Para casi todos, esto
-- lo CREA; no lo mueve de canal.
--
-- APPEND-ONLY POR EL GRANT. `authenticated` recibe SOLO `select, insert`. Sin `update` ni `delete`, un
-- `clear()` del cliente mal colocado no puede borrar nada remoto: cierra por construcción el incidente
-- `bdbc46d1` (el `.int(0)` del outbox de prefs pisando por LWW el epoch de una cuenta VIVA, porque el wire
-- de prefs no tiene tombstone). Dos policies, no cuatro — la AUSENCIA es el invariante.
--
-- PK `(user_id, text_version)`: idempotencia con `on conflict do nothing` (aceptar dos veces no duplica NI
-- re-fecha) + historia (qué versión se aceptó y cuándo cada una, que es lo que el Art. 7.1 pide demostrar).
-- Molde de forma: `claim_report` (supabase-staging.ddl).
--
-- `p_accepted_at` VIAJA DEL CLIENTE a propósito: el epoch es la hora de la ACEPTACIÓN, jamás la del
-- reintento que consiguió red (mismo criterio que el paso 5-bis del cutover, que re-emite el epoch
-- PERSISTIDO y nunca `now()`). Por eso se acota: futuro → CLAMP a now() (un reloj adelantado no registra
-- una aceptación que no ocurrió, pero tampoco pierde su registro — un 400 aquí sería PERMANENTE sobre la
-- aceptación del usuario); antigüedad absurda (< 2015) → RECHAZO.
--
-- ALCANCE-CUENTA dentro del namespace de grupos, precedente exacto `groups_forget_user`: que el consent sea
-- un hecho de la cuenta no lo saca de `/groups/rpc/:fn`. Sin columnas † ⇒ NO entra en RPC_NEEDS_ENC_KEY.

create table public.groups_consents (
  user_id      uuid        not null references auth.users(id) on delete cascade,
  text_version integer     not null,
  accepted_at  timestamptz not null,
  -- Por dónde entró (organizer|invite|tab|onboarding). Diagnóstico, NUNCA PII: acotado a 32 chars en el RPC.
  path         text,
  -- Cuándo lo recibió el SERVIDOR. Distinto de `accepted_at` a propósito: la diferencia entre ambos ES la
  -- ventana en que el intent durable estuvo armado sin red, y es la única forma de verla desde fuera.
  recorded_at  timestamptz not null default now(),
  primary key (user_id, text_version)
);

alter table public.groups_consents enable row level security;
create policy groups_consents_select on public.groups_consents
  for select to authenticated using (user_id = (select auth.uid()));
create policy groups_consents_insert on public.groups_consents
  for insert to authenticated with check (user_id = (select auth.uid()));
revoke all on public.groups_consents from anon, authenticated;
grant select, insert on public.groups_consents to authenticated;

-- SECURITY INVOKER: corre con el JWT del usuario ⇒ la RLS de arriba arbitra y `auth.uid()` es la ÚNICA
-- fuente del user_id (el gateway filtra el body por su PARAM_ALLOWLIST y jamás inyecta identidad).
create function public.record_groups_consent(
  p_text_version integer,
  p_accepted_at  timestamptz,
  p_path         text default null
) returns jsonb
  language plpgsql security invoker set search_path = public as $$
declare
  v_uid      uuid := (select auth.uid());
  v_at       timestamptz;
  v_inserted boolean;
  v_ver      integer;
  v_acc      timestamptz;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  if p_text_version is null or p_text_version < 1 or p_text_version > 10000 then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  if p_accepted_at is null then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  if p_accepted_at < timestamptz '2015-01-01T00:00:00Z' then
    raise exception 'yala_bad_input' using errcode = 'P0001';
  end if;

  v_at := least(p_accepted_at, now());

  insert into groups_consents (user_id, text_version, accepted_at, path)
  values (v_uid, p_text_version, v_at, left(p_path, 32))
  on conflict (user_id, text_version) do nothing;
  v_inserted := found;

  select gc.text_version, gc.accepted_at into v_ver, v_acc
    from groups_consents gc where gc.user_id = v_uid
    order by gc.text_version desc limit 1;

  return jsonb_build_object('text_version', v_ver, 'accepted_at', v_acc, 'inserted', v_inserted);
end $$;

revoke all on function public.record_groups_consent(integer, timestamptz, text) from public, anon;
grant execute on function public.record_groups_consent(integer, timestamptz, text) to authenticated;

-- La LECTURA: es lo que hace que entrar con tu cuenta en un iPad nuevo no vuelva a preguntarte. NO entra
-- por el canal de prefs a propósito (la frontera M1 sigue cerrada); molde exacto de /account/entitlement.
-- Shape UNIFORME con nulls cuando no hay aceptación: dos ramas de decode en el cliente es donde nacen los `try?`.
create function public.groups_consent_state() returns jsonb
  language plpgsql security invoker set search_path = public as $$
declare
  v_uid uuid := (select auth.uid());
  v_ver integer;
  v_acc timestamptz;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  select gc.text_version, gc.accepted_at into v_ver, v_acc
    from groups_consents gc where gc.user_id = v_uid
    order by gc.text_version desc limit 1;

  return jsonb_build_object('text_version', v_ver, 'accepted_at', v_acc);
end $$;

revoke all on function public.groups_consent_state() from public, anon;
grant execute on function public.groups_consent_state() to authenticated;
