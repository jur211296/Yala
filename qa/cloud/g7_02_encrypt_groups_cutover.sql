-- g7_02_encrypt_groups_cutover (2026-07-16, incremento G7 — cifrado pgcrypto de columnas de grupos, FASE B):
-- CUTOVER DDL SIN LLAVE. Requiere que g7_01 esté aplicada Y que `g7_recrypt_corpus('<llave>')` haya corrido
-- (idealmente re-corrido como cinturón m12 INMEDIATAMENTE antes de aplicar este archivo — cubre writes en la
-- ventana entre fases; sin ello un row con `<col> not null` y `<col>_enc null` perdería su plaintext en el DROP).
--
-- Hace, en orden:
--   1. DROP de las 8 columnas plaintext + RENAME `<col>_enc` → `<col>` (todas quedan NULLABLE — verificado que
--      NINGUNA de las 8 es NOT NULL hoy, AJUSTE review M6). Tras esto las 8 columnas SON bytea at-rest.
--   2. Regenerar los column-UPDATE grants de las 4 tablas con † en su lista (AJUSTE review C5, CRÍTICO): el DROP
--      mata el grant por-columna (ata por attnum) y el RENAME del `_enc` NO lo resucita. Sin regenerarlos,
--      apply_group_delta (INVOKER) recibiría insufficient_privilege → sanitizado a yala_not_authorized → push en
--      NOOP SILENCIOSO. group_members está FREEZE (muta solo por RPC DEFINER) — sin grant.
--   3. Re-crear los 6 RPCs escritores de † con `p_key text` (DROP de la firma ACTUAL primero — AJUSTE review C4:
--      create-or-replace con firma nueva crearía OVERLOAD → PGRST203/llamada a la vieja). `search_path = public,
--      extensions` en TODOS (AJUSTE review C3: pgp_sym_* no resolvería con `public` pelado). NINGÚN escritor gana
--      `exception when others → yala_bad_key` (AJUSTE review C2b: tragaría yala_group_exists/bad_input/etc y la
--      sanitización insufficient_privilege; pgp_sym_encrypt no falla con inputs válidos — el write-path no necesita
--      handler nuevo). El manejo de fallo de descifrado vive SOLO en yala_try_decrypt (g7_01).
--   4. Crear 5 RPCs LECTORES `groups_pull_rows_<tabla>` SECURITY INVOKER (RLS del caller arbitra) que descifran
--      las † — los amounts como `text` (string decimal exacto escala-4, resolución C1). El Worker cambia de leer
--      `select=*` (GET) a llamar estos RPCs (POST body — la llave JAMÁS en URL/query, §6).
--   5. Crear la función gate `yala_logging_settings()` que consume el golden §16e.
--
-- === Cirugía de apply_group_delta (AJUSTE review C2a) ===
--   Las columnas † se QUITAN del jsonb ANTES de `jsonb_populate_record` (su columna física es bytea → un populate
--   desde el JSON plaintext fallaría) en AMBAS ramas (INSERT-fresh y UPDATE). En la value-list se emite
--   `pgp_sym_encrypt(...)` con tri-estado NULL explícito: un unit que setea `note=null` → NULL bytea (jamás cifrar
--   la string "null"); columna ausente de la unit → no se toca. Los AMOUNTS se cifran como
--   `((v_win->>'amount')::numeric(18,4))::text` — normaliza la escala ("30" → "30.0000"), byte-idéntico al recrypt
--   de la fase intermedia y a lo que el Merkle servía pre-G7. `'amount'` es la ÚNICA columna † numérica (el resto
--   son text); si en el futuro se cifrara otra numérica, extender el CASE `when c = 'amount'`.
--
-- === Aplicación (loop principal, MCP, contexto service) === ver cabecera de g7_01. Registrar md5s en README.

set local check_function_bodies = off;

-- ============================================================================
-- 1. Cutover de columnas: DROP plaintext + RENAME `_enc` → nombre canónico (todas NULLABLE).
-- ============================================================================
alter table public.split_groups     drop column name;
alter table public.split_groups     rename column name_enc to name;

alter table public.group_members     drop column display_name;
alter table public.group_members     rename column display_name_enc to display_name;

alter table public.split_expenses    drop column amount;
alter table public.split_expenses    rename column amount_enc to amount;
alter table public.split_expenses    drop column expense_description;
alter table public.split_expenses    rename column expense_description_enc to expense_description;
alter table public.split_expenses    drop column note;
alter table public.split_expenses    rename column note_enc to note;

alter table public.split_settlements drop column amount;
alter table public.split_settlements rename column amount_enc to amount;
alter table public.split_settlements drop column note;
alter table public.split_settlements rename column note_enc to note;

alter table public.split_shares      drop column amount;
alter table public.split_shares      rename column amount_enc to amount;

-- ============================================================================
-- 2. Column-UPDATE grants REGENERADOS (verbatim de supabase-groups-staging.ddl §2 hallazgo #1).
-- ============================================================================
revoke update on public.split_groups from authenticated;
grant update (name, icon_name, color_hex, currency_code, simplify_debts, show_debts_in_single_currency,
              members_can_invite, default_split_type, is_archived, is_hidden_for_all,
              hlc, field_hlcs, deleted, deleted_hlc, schema_version, updated_at)
  on public.split_groups to authenticated;

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
-- 3. yala_logging_settings() — gate §16e (la llave JAMÁS en logs).
-- ============================================================================
-- Devuelve los settings de logging que garantizan que la llave (viaja como argumento) no aterrice en ningún log.
-- El golden g7-logging-settings asserta {log_statement:"ddl", log_min_duration_statement:"-1",
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

-- ============================================================================
-- 4. RPCs escritores re-creados con p_key + cifrado de † (DROP firma vieja primero — C4).
-- ============================================================================

-- ---- create_group ---------------------------------------------------------
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

-- ---- join_group -----------------------------------------------------------
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

-- ---- approve_member / remove_member / leave_group / revoke_invite ----------
-- SIN cambios (no escriben columnas †). NO se re-crean aquí.

-- ---- groups_forget_user ---------------------------------------------------
-- El sentinel display_name '__deleted_user__' TAMBIÉN se cifra (la columna es uniformemente bytea).
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

-- ---- update_member_display_name -------------------------------------------
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

-- ---- migrate_group --------------------------------------------------------
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

-- ---- apply_group_delta (cirugía C2a: † fuera de jsonb_populate_record + pgp_sym_encrypt en la value-list) ----
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

-- ============================================================================
-- 5. RPCs LECTORES groups_pull_rows_<tabla> — SECURITY INVOKER (RLS del caller) + descifrado de †.
-- ============================================================================
-- returns table con TODAS las columnas (mismo orden/nombre que la tabla), los AMOUNTS como `text` (string decimal
-- exacto escala-4 — resolución C1), los demás † descifrados a text. `where group_id = p_group_id and server_seq >
-- p_after_seq order by server_seq asc limit p_limit`. GRANT a authenticated (un caller sin llave solo obtiene NULLs
-- en las †, sin fuga). yala_try_decrypt es SECURITY DEFINER (g7_01) → el reader INVOKER no depende de un EXECUTE de
-- pgp_sym_decrypt para authenticated. Keyset por server_seq: el Merkle los reusa (entityHash ordena los leaves por
-- syncId internamente → el orden de recolección es irrelevante; M8: no estable ante updates concurrentes a mitad de
-- paginación — irrelevante en beta, corpus < pageSize 1000).

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

-- ============================================================================
-- 6. Grants de EXECUTE: revocar de public/anon, otorgar solo a authenticated (firmas NUEVAS — AJUSTE review C4).
-- ============================================================================
revoke all on function
  public.create_group(text, text, text, text, text, text, text, text, boolean, boolean, boolean),
  public.join_group(text, text, text, text),
  public.groups_forget_user(text),
  public.update_member_display_name(text, text, text),
  public.migrate_group(text, jsonb, jsonb, text),
  public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer),
  public.groups_pull_rows_split_groups(text, bigint, int, text),
  public.groups_pull_rows_group_members(text, bigint, int, text),
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_shares(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  from public, anon;
grant execute on function
  public.create_group(text, text, text, text, text, text, text, text, boolean, boolean, boolean),
  public.join_group(text, text, text, text),
  public.groups_forget_user(text),
  public.update_member_display_name(text, text, text),
  public.migrate_group(text, jsonb, jsonb, text),
  public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer),
  public.groups_pull_rows_split_groups(text, bigint, int, text),
  public.groups_pull_rows_group_members(text, bigint, int, text),
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_shares(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  to authenticated;

notify pgrst, 'reload schema';
