-- g12_01_delete_account_auth_users (2026-07-16, gate §12 Bloque B2 — decisión owner: HARD DELETE
-- RATIFICADO + cerrar el residual de `auth.users`): `delete_personal_account()` ahora TAMBIÉN borra la
-- identidad de GoTrue del caller (`auth.users where id = auth.uid()`) como ÚLTIMO paso. Cierra el gap
-- GDPR documentado en g5_01 (la fila retenía email/phone/raw_user_meta_data con el nombre de SIWA tras
-- un "borrado GDPR").
--
-- POR QUÉ esta vía y no una credencial de máquina ni la Admin API (informe explorador + PoC 2026-07-16):
--   - Admin API / secret keys (`sb_secret_*`): SIN scoping — siempre service_role+BYPASSRLS. Meterla en
--     el Worker rompe el invariante ("el Worker jamás posee credencial que lea datos de usuario") en el
--     núcleo. DESCARTADA.
--   - Rol de máquina `yala_deleter` (molde yala_push): tomaría un uuid arbitrario → credencial capaz de
--     borrar CUALQUIER cuenta (catastrófico e irreversible, sin el 2º pilar de G8-3 [datos inertes]).
--     DESCARTADA.
--   - AQUÍ el borrado queda atado al `auth.uid()` del CALLER por construcción: cero superficie nueva,
--     cero credencial nueva, el Worker sigue sin tocar `auth`. El invariante queda intacto sin refinarlo.
--
-- PoC de privilegio (staging, 2026-07-16, EN VIVO): owner de la función = postgres;
-- has_table_privilege(postgres, auth.users, DELETE) = true; función SECURITY DEFINER de prueba ejecutó
-- el DELETE sin error. En Supabase el rol postgres NO es superuser pero SÍ tiene DELETE sobre auth.users.
--
-- ⚠️ SUPUESTO LOAD-BEARING (review adversarial 2026-07-16): `auth.users` tiene RLS HABILITADO con CERO
-- policies (owner supabase_auth_admin) → sin nada más, el DELETE del camino definer sería default-deny y
-- borraría 0 filas EN SILENCIO. Lo que lo hace funcionar es `pg_roles.rolbypassrls = true` del rol
-- `postgres` (verificado en vivo en staging). ASSERT al promover a cualquier entorno:
--   select rolbypassrls from pg_roles where rolname='postgres';  -- debe ser true
-- Y el observable en la verificación WIRE es `auth_users: 1` en la respuesta (si diera 0, el gap sigue
-- abierto en silencio).
--
-- Efectos en cascada VERIFICADOS en la instancia (pg_constraint, 2026-07-16):
--   - `public.profiles.id` → auth.users(id) ON DELETE CASCADE (el delete explícito de profiles queda
--     como BELT — corre antes y reporta su count real; la cascada barre lo que quedara).
--   - Las 20 tablas per-user del canal personal: ON DELETE CASCADE (belt de los deletes explícitos, que
--     se CONSERVAN por los counts del jsonb y por claridad).
--   - Grupos: split_groups.owner_user_id / group_members.user_id / group_invites.created_by → SET NULL;
--     push_tokens → CASCADE. ⚠️ El SET NULL NO SUSTITUYE a `groups_forget_user()` (no bumpea hlc/field_hlcs
--     [los co-members podrían no aplicarlo por LWW], no pone el sentinel __deleted_user__ ni status=removed,
--     no transfiere/tombstonea grupos del owner) — en el flujo del cliente el forget corre ANTES y la
--     cascada matchea 0 filas; como belt del path que se salta el forget es INCOMPLETA (documentado).
--   - Internas de GoTrue: identities, sessions, mfa_factors, one_time_tokens, oauth_*, webauthn_* —
--     todas ON DELETE CASCADE. Cero triggers no-internos sobre auth.users.
--
-- Semántica post-borrado (doc Supabase + diseño):
--   - El JWT del caller EN VUELO sigue válido hasta expirar (verificación stateless por JWKS — el paso
--     4a del cliente [SIWA revoke, B1] sigue funcionando tras este RPC).
--   - Un Sign in with Apple POSTERIOR del mismo Apple ID acuña un usuario NUEVO (sub distinto) — la
--     cuenta borrada NO renace. Coherente con la semántica "la cuenta MUERE".
--   - Orden interno: deletes explícitos primero (counts exactos) → profiles → auth.users AL FINAL.
--
-- Residual documentado (mismo residual que dejaría el Admin API deleteUser): `auth.audit_log_entries` y
-- `auth.flow_state` NO tienen FK a auth.users — las trazas de auditoría de GoTrue (payload con email/IP)
-- SOBREVIVEN al delete. Residual-owner, fuera del alcance de este RPC.
--
-- El resto del cuerpo es VERBATIM g5_01 salvo: v_auth_users (declare) + el delete de auth.users + la key
-- 'auth_users' del jsonb + el COMENTARIO de la línea de profiles reemplazado ("Última por claridad…" →
-- "belt — la cascada…"; solo-comentario, cero comportamiento).

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
  v_auth_users          integer;
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

  -- La fila de perfil (belt — la cascada de auth.users también la barrería; explícita por el count).
  with d as (delete from profiles            where id = v_uid returning 1) select count(*) into v_profiles           from d;

  -- g12_01: la identidad de GoTrue, AL FINAL (cierra el gap GDPR; cascadas verificadas en el header).
  with d as (delete from auth.users          where id = v_uid returning 1) select count(*) into v_auth_users         from d;

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
    'profiles',            v_profiles,
    'auth_users',          v_auth_users
  );
end $$;

-- Grants: create or replace CONSERVA el ACL existente; se re-declaran como belt idempotente (molde g5_01).
revoke all on function public.delete_personal_account() from public, anon;
grant execute on function public.delete_personal_account() to authenticated;
