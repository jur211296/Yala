-- =====================================================================================================
-- g21_01 · flujo de caja: `cashflow_lines.amount_changes_raw`
--
-- QUÉ GANA EL USUARIO. En el plan de flujo de caja, «Ajustar monto → noviembre y los siguientes» cambiaba también
-- setiembre y octubre. Ahora la línea guarda desde qué mes vale el monto nuevo (decisión A de Jürgen, auditoría
-- UX 2.2 · L18-8). Esta columna es ese dato en la nube: sin ella, un cambio hecho en un teléfono en Modo Nube no
-- llega a sus otros teléfonos.
--
-- QUÉ ES. Una columna `text` NULLABLE con los cambios tal cual los guarda la app: `yyyy-MM=monto` separados por coma
-- (`CashFlowAmountChangeLogic`). NULL = la línea no tiene cambios «desde este mes». La app descarta al leer una
-- entrada que no entiende, así que no hace falta un CHECK.
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g18_01)
--   · Grants a nivel TABLA en las 16 tablas personales: la columna los hereda. El §2 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 3`. Al revés, el Merkle del Worker pediría `amount_changes_raw` a PostgREST en
--      una tabla que no la tiene → 502 en cada verificación de cada teléfono que hable v3.
--   3. La app. La app declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v2 no emite ni
--      hashea la columna, así que puede salir antes que 1-2.
--
-- === IDEMPOTENTE ===  `add column if not exists`; con la columna ya creada con OTRO tipo aborta (§2).
--
-- Marcha atrás: `g21_01_rollback.sql` (solo mientras ninguna fila tenga cambios).
-- =====================================================================================================

begin;

-- §1 · la columna
alter table public.cashflow_lines add column if not exists amount_changes_raw text;

comment on column public.cashflow_lines.amount_changes_raw is
  'Flujo de caja (UX 2.2 · L18-8): cambios de monto «desde este mes» de la línea, yyyy-MM=monto separados por coma. NULL = sin cambios. g21_01, 2026-10-21.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_nullable text;
begin
  select data_type, is_nullable into v_type, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'cashflow_lines' and column_name = 'amount_changes_raw';
  if v_type is distinct from 'text' then
    raise exception 'g21_01: cashflow_lines.amount_changes_raw existe con tipo % (se esperaba text)', v_type;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g21_01: cashflow_lines.amount_changes_raw no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.cashflow_lines', 'amount_changes_raw', 'SELECT')
     or not has_column_privilege('authenticated', 'public.cashflow_lines', 'amount_changes_raw', 'INSERT')
     or not has_column_privilege('authenticated', 'public.cashflow_lines', 'amount_changes_raw', 'UPDATE') then
    raise exception 'g21_01: authenticated no hereda SELECT/INSERT/UPDATE en cashflow_lines.amount_changes_raw';
  end if;
  raise notice 'g21_01 OK · cashflow_lines.amount_changes_raw text nullable, grants heredados';
end;
$$;

commit;
