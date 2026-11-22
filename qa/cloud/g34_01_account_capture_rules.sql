-- =====================================================================================================
-- g34_01 · reglas de captura de una cuenta: `accounts.capture_rules_raw` (manifest v9)
--
-- QUÉ GANA EL USUARIO. Desde 2.3 una cuenta guarda sus reglas de captura («cuando leo un pago que dice “zip”, va a Zip
-- Visa»; parte 2 de la cuenta sola al leer, 2026-11-21). Por iCloud el campo viaja (`CD_captureRulesRaw`); en Modo Nube,
-- sin esta columna, el otro teléfono no vería las reglas.
--
-- QUÉ ES. Una columna `text` NULLABLE con el JSON de las reglas (`AccountCaptureRule`). NULL = sin reglas, como toda
-- cuenta de antes. Nunca lleva saldos ni números de cuenta.
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g18_01, g26_01 y g32_01)
--   · Grants a nivel TABLA: la columna los hereda. El §2 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 9`. Al revés, el Merkle del Worker pediría la columna a PostgREST en una tabla
--      que no la tiene → 502 en cada verificación de cada teléfono que hable v9.
--   3. La app. La app declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v8 no emite ni hashea
--      la columna (la apunta y la sube al llegar la v9), así que puede salir antes que 1-2.
--
-- === IDEMPOTENTE ===  `add column if not exists`; con una columna ya creada con OTRO tipo aborta (§2).
--
-- Marcha atrás: `g34_01_rollback.sql` (solo mientras ninguna cuenta tenga reglas).
-- =====================================================================================================

begin;

-- §1 · la columna
alter table public.accounts add column if not exists capture_rules_raw text;

comment on column public.accounts.capture_rules_raw is
  'Reglas de captura de la cuenta (JSON de AccountCaptureRule). NULL = sin reglas. g34_01, 2026-11-21.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_nullable text;
begin
  select data_type, is_nullable into v_type, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'accounts' and column_name = 'capture_rules_raw';
  if v_type is distinct from 'text' then
    raise exception 'g34_01: accounts.capture_rules_raw existe con tipo % (se esperaba text)', v_type;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g34_01: accounts.capture_rules_raw no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.accounts', 'capture_rules_raw', 'SELECT')
     or not has_column_privilege('authenticated', 'public.accounts', 'capture_rules_raw', 'INSERT')
     or not has_column_privilege('authenticated', 'public.accounts', 'capture_rules_raw', 'UPDATE') then
    raise exception 'g34_01: authenticated no hereda SELECT/INSERT/UPDATE en accounts.capture_rules_raw';
  end if;
  raise notice 'g34_01 OK · accounts.capture_rules_raw text nullable, grants heredados';
end;
$$;

commit;
