-- g7_01_encrypt_groups_columns (2026-07-16, incremento G7 — cifrado pgcrypto de columnas de grupos, FASE A):
-- DDL SIN LLAVE (la llave JAMÁS en un archivo de migración ni en schema_migrations — decisión congelada §6 del
-- brief). Añade la columna espejo `<col>_enc bytea` nullable para las 8 columnas † a cifrar, crea el motor de
-- re-cifrado idempotente `g7_recrypt_corpus(p_key)` (SERVICE-ONLY) y el wrapper de descifrado tolerante-por-fila
-- `yala_try_decrypt(p_c, p_key)`. La FASE B (g7_02) hace el cutover (DROP plaintext + RENAME _enc + RPCs).
--
-- === Modelo de amenaza (decisión de sesión §1/§5) ===
--   Proteger DUMPS/BACKUPS lógicos: una fila filtrada de un dump no debe revelar montos ni descripciones. La
--   llave viaja como ARGUMENTO de request (`p_key text`) — NUNCA residente en la DB (GUC/pg_db_role_setting/Vault
--   aparecerían en el dump y matarían el modelo). La RLS sigue arbitrando ANTES de descifrar (los readers son
--   SECURITY INVOKER); el cifrado NO reemplaza el control de acceso, lo COMPLEMENTA a nivel de datos-en-reposo.
--
-- === Columnas † a cifrar (8 — §5 del brief; las 2 últimas por modelo de amenaza, a RATIFICAR por el owner) ===
--   split_groups.name · group_members.display_name ·
--   split_expenses.amount · split_expenses.expense_description · split_expenses.note ·
--   split_settlements.amount · split_settlements.note (note = † genérico del diseño) ·
--   split_shares.amount (sin ella un dump reconstruye expenses.amount sumando shares → anula el cifrado).
--   NO se cifra: currency_code (parte de las unidades gmoney/smoney; cifrarlo rompería queries), member_keys,
--   fechas, flags, sync_id, hlc, field_hlcs.
--
-- === Representación de los AMOUNTS (resolución review C1) ===
--   Los amounts se cifran como `pgp_sym_encrypt(amount::text, p_key)`. `numeric(18,4)::text` PRESERVA la escala
--   ("30" → "30.0000"), así el reader los sirve como STRING decimal exacto escala-4 y el canon del Merkle del
--   Worker toma la rama STRING (decimal exacto) en vez de `decimalFixedFromDouble` — cierra la divergencia latente
--   con >15 dígitos que la regla canon.ts:13-14 ("JAMÁS float") prohíbe. Byte-idéntico a lo que el Merkle servía
--   pre-G7 (`amount::text`).
--
-- === Aplicación (loop principal, MCP, contexto service) ===
--   1. Aplicar ESTE archivo verbatim como migración `g7_01_encrypt_groups_columns` (DDL, sin llave).
--   2. PASO INTERMEDIO (NO migración — execute_sql directo, para que la llave no toque schema_migrations ni el
--      log de DDL): `select public.g7_recrypt_corpus('<LLAVE_STAGING>');` — cifra el corpus existente. Idempotente
--      (re-ejecutable). Los params quedan normalizados en pg_stat_statements (verificado por el spike G0).
--   3. Re-ejecutar `select public.g7_recrypt_corpus('<LLAVE_STAGING>');` INMEDIATAMENTE antes de aplicar g7_02
--      (cinturón m12: cubre cualquier write ocurrido en la ventana entre fases — staging sin tráfico, pero belt).
--   4. Aplicar g7_02_encrypt_groups_cutover (cutover DDL sin llave).
--   La llave se guarda en `~/Secrets/yala-groups-enc/staging.key` + `gateway/.dev.vars` (JAMÁS commiteada; prod
--   lleva una llave DISTINTA que genera el owner).

create extension if not exists pgcrypto with schema extensions;

-- ============================================================================
-- 1. Columnas espejo `<col>_enc bytea` NULLABLE (aditivo, instantáneo — sin reescritura de tabla).
-- ============================================================================
alter table public.split_groups       add column if not exists name_enc bytea;
alter table public.group_members       add column if not exists display_name_enc bytea;
alter table public.split_expenses      add column if not exists amount_enc bytea;
alter table public.split_expenses      add column if not exists expense_description_enc bytea;
alter table public.split_expenses      add column if not exists note_enc bytea;
alter table public.split_settlements   add column if not exists amount_enc bytea;
alter table public.split_settlements   add column if not exists note_enc bytea;
alter table public.split_shares        add column if not exists amount_enc bytea;

-- ============================================================================
-- 2. g7_recrypt_corpus(p_key) — motor de re-cifrado IDEMPOTENTE, SERVICE-ONLY.
-- ============================================================================
-- Copia plaintext→cifrado para las 8 columnas SOLO donde `<col>_enc is null and <col> is not null`
-- (idempotente: una 2ª corrida no re-cifra lo ya cifrado ni toca filas nuevas ya cubiertas). Amounts como
-- `pgp_sym_encrypt(amount::text, p_key)` (escala-4 preservada). Devuelve counts por columna (jsonb).
-- REVOKE all de public/anon/authenticated → solo ejecutable en contexto SERVICE (nadie con JWT la invoca).
-- NOTA m11 (BENIGNO): cada UPDATE dispara `stamp_group_seq` → re-estampa server_seq del corpus tocado. Aceptado:
-- staging sin tráfico, clientes re-pull idempotente, goldens crean grupos frescos por corrida. NO se deshabilita
-- el trigger (exige ownership y abre ventana).
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

-- ============================================================================
-- 3. yala_try_decrypt(p_c, p_key) — descifrado TOLERANTE POR FILA.
-- ============================================================================
-- SECURITY DEFINER (owner) + `set search_path = public, extensions` (AJUSTE review m13: así los readers INVOKER
-- que la invocan NO dependen de un EXECUTE de pgp_sym_decrypt concedido a authenticated). Atrapa el fallo de
-- descifrado POR LLAMADA (por fila×columna) → NULL: una fila envenenada (bytea basura escrito por un member
-- malicioso vía PostgREST directo) NO revienta la página del pull/merkle — devuelve NULL en esa columna y el
-- canario de divergencia del Merkle la delata. Sin este wrapper, un INSERT directo de bytea basura sería un DoS
-- de lectura del grupo entero. El cuerpo tiene UNA sola operación falible (pgp_sym_decrypt) tras el guard de NULL,
-- así que `when others` está de-facto acotado al fallo de descifrado (mismo patrón que el spike G0); no enmascara
-- errores de otras operaciones porque no hay otras.
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

notify pgrst, 'reload schema';
