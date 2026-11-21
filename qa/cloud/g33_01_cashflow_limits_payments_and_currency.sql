-- =====================================================================================================
-- g33_01 · Flujo de caja: límites atados a varios pagos planificados y en otra moneda (manifest v8)
--
-- QUÉ GANA EL USUARIO. Una línea del flujo de caja puede sumar varios pagos planificados (Suscripciones = Netflix +
-- Spotify + iCloud) más un extra, y un monto fijo puede ir en otra moneda (la renta en USD) y convertirse cada mes con el
-- promedio del tipo de cambio. Sin estas columnas, el otro teléfono de la misma cuenta vería solo el primer pago y el
-- monto fijo en la moneda del flujo, convertido el día que se guardó.
--
-- QUÉ ES. Cuatro columnas NULLABLE en `cashflow_lines`, sin CHECK (un teléfono más nuevo no puede ver rechazada la fila
-- ENTERA por un formato que este servidor no conoce, como g21_01 y g32_01):
--   · scheduled_payment_ids_raw text     — los `ScheduledPayment.id` de la línea, separados por coma, en orden
--   · limit_extra_amount       numeric(18,4) — el extra, en la moneda del flujo
--   · limit_currency_code      text     — la moneda del monto fijo; NULL = la del flujo
--   · limit_foreign_amount     numeric(18,4) — el monto fijo en esa moneda
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g21_01 y g32_01)
--   · Grants a nivel TABLA: las columnas los heredan. El §2 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 8`. Al revés, su Merkle pediría columnas que la tabla no tiene → 502.
--   3. La app. Declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v7 ni emite ni hashea las
--      columnas; lo que la persona cambia en ellas se apunta y sube al pasar a v8.
--
-- === IDEMPOTENTE ===  `add column if not exists`.
--
-- Marcha atrás: `g33_01_rollback.sql` (solo mientras ninguna línea tenga valor en las cuatro).
-- Conductor: `bash qa/cloud/g33_01-remote.sh <staging|production> <state|apply|rollback>`.
-- ESTADO (2026-11-20): SIN APLICAR en ningún entorno (la sesión que la escribió no tenía la credencial).
-- =====================================================================================================

begin;

set local lock_timeout = '5s';

-- §1 · las columnas
alter table public.cashflow_lines add column if not exists scheduled_payment_ids_raw text;
alter table public.cashflow_lines add column if not exists limit_extra_amount numeric(18,4);
alter table public.cashflow_lines add column if not exists limit_currency_code text;
alter table public.cashflow_lines add column if not exists limit_foreign_amount numeric(18,4);

comment on column public.cashflow_lines.scheduled_payment_ids_raw is
  'Pagos planificados de la línea (ScheduledPayment.id separados por coma, en orden). NULL = el de scheduled_payment_ref. g33_01, 2026-11-20.';
comment on column public.cashflow_lines.limit_extra_amount is
  'Extra que se suma a los pagos de la línea, en la moneda del flujo. NULL = sin extra. g33_01.';
comment on column public.cashflow_lines.limit_currency_code is
  'Moneda del monto fijo de la línea. NULL = la del flujo. g33_01.';
comment on column public.cashflow_lines.limit_foreign_amount is
  'Monto fijo en limit_currency_code; manual_amount guarda el convertido. g33_01.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_col text;
  v_type text;
  v_nullable text;
  v_esperado text;
begin
  foreach v_col in array array['scheduled_payment_ids_raw', 'limit_extra_amount', 'limit_currency_code',
                               'limit_foreign_amount'] loop
    select data_type, is_nullable into v_type, v_nullable
      from information_schema.columns
     where table_schema = 'public' and table_name = 'cashflow_lines' and column_name = v_col;
    v_esperado := case when v_col in ('limit_extra_amount', 'limit_foreign_amount') then 'numeric' else 'text' end;
    if v_type is distinct from v_esperado then
      raise exception 'g33_01: cashflow_lines.% existe con tipo % (se esperaba %)', v_col, v_type, v_esperado;
    end if;
    if v_nullable <> 'YES' then
      raise exception 'g33_01: cashflow_lines.% no es nullable', v_col;
    end if;
    if not has_column_privilege('authenticated', 'public.cashflow_lines', v_col, 'SELECT')
       or not has_column_privilege('authenticated', 'public.cashflow_lines', v_col, 'INSERT')
       or not has_column_privilege('authenticated', 'public.cashflow_lines', v_col, 'UPDATE') then
      raise exception 'g33_01: authenticated no hereda SELECT/INSERT/UPDATE en cashflow_lines.%', v_col;
    end if;
  end loop;
  raise notice 'g33_01 OK · cuatro columnas nullable en cashflow_lines';
end;
$$;

commit;
