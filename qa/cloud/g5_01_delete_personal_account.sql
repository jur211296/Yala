-- g5_01_delete_personal_account (2026-07-16, incremento G5-D1 — decisión de SESIÓN, a ratificar por el owner):
-- `delete_personal_account()` es la contraparte PERSONAL de `groups_forget_user()` (§15 solo decidió la
-- parte de GRUPOS). Semántica CONGELADA: **HARD DELETE** de TODO el corpus personal del caller — la cuenta
-- MUERE (borrado GDPR), no hay semántica de sync que preservar (a diferencia de un tombstone, que existe
-- para que el borrado CONVERJA a otros devices; aquí no queda cuenta a la que converger). Esta decisión NO
-- está registrada en el diseño §15 — es de esta sesión, razonada, y debe RATIFICARSE por el owner.
--
-- Alcance (todas las filas con user_id = auth.uid()):
--   - las 16 tablas de dominio per-user (accounts, budgets, cashflow_lines, cashflow_overrides,
--     cashflow_plans, categories, exchange_rates, favorite_payments, group_bridge_prefs, inbox_drafts,
--     merchant_memory, notification_items, scheduled_payments, subcategories, tags, tx_items)
--   - user_preferences + sync_seq_counters + attest_keys + report_claims
--   - la fila `profiles` del usuario (PK = id = sub).
--
-- NO toca:
--   - las tablas de GRUPOS (split_*, group_*, push_tokens) — eso es `groups_forget_user()`, que el
--     cliente llama APARTE ANTES de este RPC (anonimización de member + transferencia/tombstone de grupos).
--   - `auth.users` — el gateway JAMÁS usa service_role, y este RPC corre como owner de la función pero
--     no borra la identidad de auth. RESIDUAL DOCUMENTADO (decisión owner post-v1 / Admin API): el borrado
--     del registro `auth.users` queda pendiente; los datos personales y la fila de perfil mueren igual.
--   - `attest_keys` aquí es ESPEJO LÓGICO — el hogar real del material de App Attest es Cloudflare D1
--     (el binding físico del device sobrevive en D1; borrarlo es pendiente-owner separado). Se borra la
--     fila lógica de Postgres para no dejar rastro de identidad en el canal personal.
--
-- Semántica del schema verificada (2026-07-16):
--   - `stamp_server_seq` es BEFORE INSERT OR UPDATE → NO dispara en DELETE (los counters no re-incrementan).
--   - SECURITY DEFINER corre como owner de la función (idéntico a `groups_forget_user`) → bypass de RLS y
--     del REVOKE DELETE del rol `authenticated` (tombstone = UPDATE en el canal de sync; aquí es DELETE real).
--   - Orden de deletes LIBRE: las tablas per-user referencian `auth.users(id)`, ninguna referencia
--     `profiles` ni entre sí (verificado en supabase-staging.ddl) → sin dependencias de FK internas.
--   - Guard `auth.uid()` NULL → `yala_not_authorized` (errcode P0001) — molde exacto de los RPCs de grupos.

create or replace function public.delete_personal_account() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := (select auth.uid());
  v_accounts            integer;
  v_budgets             integer;
  v_cashflow_lines      integer;
  v_cashflow_overrides  integer;
  v_cashflow_plans      integer;
  v_categories          integer;
  v_exchange_rates      integer;
  v_favorite_payments   integer;
  v_group_bridge_prefs  integer;
  v_inbox_drafts        integer;
  v_merchant_memory     integer;
  v_notification_items  integer;
  v_scheduled_payments  integer;
  v_subcategories       integer;
  v_tags                integer;
  v_tx_items            integer;
  v_user_preferences    integer;
  v_sync_seq_counters   integer;
  v_attest_keys         integer;
  v_report_claims       integer;
  v_profiles            integer;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;

  -- 16 tablas de dominio per-user. Patrón WITH ... DELETE RETURNING → count (molde groups_forget_user LOOP 2).
  with d as (delete from accounts            where user_id = v_uid returning 1) select count(*) into v_accounts           from d;
  with d as (delete from budgets             where user_id = v_uid returning 1) select count(*) into v_budgets            from d;
  with d as (delete from cashflow_lines      where user_id = v_uid returning 1) select count(*) into v_cashflow_lines     from d;
  with d as (delete from cashflow_overrides  where user_id = v_uid returning 1) select count(*) into v_cashflow_overrides from d;
  with d as (delete from cashflow_plans      where user_id = v_uid returning 1) select count(*) into v_cashflow_plans     from d;
  with d as (delete from categories          where user_id = v_uid returning 1) select count(*) into v_categories         from d;
  with d as (delete from exchange_rates      where user_id = v_uid returning 1) select count(*) into v_exchange_rates     from d;
  with d as (delete from favorite_payments   where user_id = v_uid returning 1) select count(*) into v_favorite_payments  from d;
  with d as (delete from group_bridge_prefs  where user_id = v_uid returning 1) select count(*) into v_group_bridge_prefs from d;
  with d as (delete from inbox_drafts        where user_id = v_uid returning 1) select count(*) into v_inbox_drafts       from d;
  with d as (delete from merchant_memory     where user_id = v_uid returning 1) select count(*) into v_merchant_memory    from d;
  with d as (delete from notification_items  where user_id = v_uid returning 1) select count(*) into v_notification_items from d;
  with d as (delete from scheduled_payments  where user_id = v_uid returning 1) select count(*) into v_scheduled_payments from d;
  with d as (delete from subcategories       where user_id = v_uid returning 1) select count(*) into v_subcategories      from d;
  with d as (delete from tags                where user_id = v_uid returning 1) select count(*) into v_tags               from d;
  with d as (delete from tx_items            where user_id = v_uid returning 1) select count(*) into v_tx_items           from d;

  -- Prefs + eje de server_seq + identidad lógica + dedup de reportes.
  with d as (delete from user_preferences    where user_id = v_uid returning 1) select count(*) into v_user_preferences   from d;
  with d as (delete from sync_seq_counters   where user_id = v_uid returning 1) select count(*) into v_sync_seq_counters  from d;
  with d as (delete from attest_keys         where user_id = v_uid returning 1) select count(*) into v_attest_keys        from d;
  with d as (delete from report_claims       where user_id = v_uid returning 1) select count(*) into v_report_claims      from d;

  -- La fila de perfil (PK = id = sub). Última por claridad; sin dependientes que la referencien.
  with d as (delete from profiles            where id = v_uid returning 1) select count(*) into v_profiles           from d;

  return jsonb_build_object(
    'accounts',            v_accounts,
    'budgets',             v_budgets,
    'cashflow_lines',      v_cashflow_lines,
    'cashflow_overrides',  v_cashflow_overrides,
    'cashflow_plans',      v_cashflow_plans,
    'categories',          v_categories,
    'exchange_rates',      v_exchange_rates,
    'favorite_payments',   v_favorite_payments,
    'group_bridge_prefs',  v_group_bridge_prefs,
    'inbox_drafts',        v_inbox_drafts,
    'merchant_memory',     v_merchant_memory,
    'notification_items',  v_notification_items,
    'scheduled_payments',  v_scheduled_payments,
    'subcategories',       v_subcategories,
    'tags',                v_tags,
    'tx_items',            v_tx_items,
    'user_preferences',    v_user_preferences,
    'sync_seq_counters',   v_sync_seq_counters,
    'attest_keys',         v_attest_keys,
    'report_claims',       v_report_claims,
    'profiles',            v_profiles
  );
end $$;

-- Grants de EXECUTE: revocar de public/anon, otorgar solo a authenticated (molde exacto
-- supabase-groups-staging.ddl:806-827 — REVOKE ALL ... FROM public, anon; GRANT EXECUTE ... TO authenticated).
-- SECURITY DEFINER + este grant = solo un usuario autenticado invoca; corre como owner (bypass RLS/REVOKE
-- DELETE) sobre EXCLUSIVAMENTE su propia fila (WHERE user_id = auth.uid() en cada delete).
revoke all on function public.delete_personal_account() from public, anon;
grant execute on function public.delete_personal_account() to authenticated;
