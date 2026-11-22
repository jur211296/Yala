-- =====================================================================================================
-- g35_01 · límite de una tarjeta de crédito: `accounts.credit_limit` (manifest v10)
--
-- QUÉ GANA EL USUARIO. Desde 2.3 una tarjeta de crédito puede guardar su límite, y la hoja de la cuenta dice «16 % usado ·
-- 6,720.00 disponible de 8,000.00» (decisión de Jürgen del 22-nov-2026, opción A). Por iCloud el campo viaja
-- (`CD_creditLimit`); en Modo Nube, sin esta columna, el otro teléfono no vería el límite.
--
-- QUÉ ES. Una columna `numeric(18,4)` NULLABLE, en la divisa de la cuenta. NULL = sin límite, como toda cuenta de antes.
-- El cliente nunca escribe 0 ni negativos (los guarda como NULL).
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g18_01, g26_01, g32_01 y g34_01)
--   · Grants a nivel TABLA: la columna los hereda. El §2 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 10`. Al revés, el Merkle del Worker pediría la columna a PostgREST en una tabla
--      que no la tiene → 502 en cada verificación de cada teléfono que hable v10.
--   3. La app. La app declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v9 no emite ni hashea
--      la columna (la apunta y la sube al llegar la v10), así que puede salir antes que 1-2.
--
-- === IDEMPOTENTE ===  `add column if not exists`; con una columna ya creada con OTRO tipo aborta (§2).
--
-- Marcha atrás: `g35_01_rollback.sql` (solo mientras ninguna cuenta tenga límite).
-- =====================================================================================================

begin;

-- §1 · la columna
alter table public.accounts add column if not exists credit_limit numeric(18,4);

comment on column public.accounts.credit_limit is
  'Límite de la tarjeta de crédito, en la divisa de la cuenta. NULL = sin límite. g35_01, 2026-11-22.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_scale int;
  v_nullable text;
begin
  select data_type, numeric_scale, is_nullable into v_type, v_scale, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'accounts' and column_name = 'credit_limit';
  if v_type is distinct from 'numeric' or v_scale is distinct from 4 then
    raise exception 'g35_01: accounts.credit_limit existe con tipo % escala % (se esperaba numeric, 4)', v_type, v_scale;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g35_01: accounts.credit_limit no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.accounts', 'credit_limit', 'SELECT')
     or not has_column_privilege('authenticated', 'public.accounts', 'credit_limit', 'INSERT')
     or not has_column_privilege('authenticated', 'public.accounts', 'credit_limit', 'UPDATE') then
    raise exception 'g35_01: authenticated no hereda SELECT/INSERT/UPDATE en accounts.credit_limit';
  end if;
  raise notice 'g35_01 OK · accounts.credit_limit numeric(18,4) nullable, grants heredados';
end;
$$;

commit;
