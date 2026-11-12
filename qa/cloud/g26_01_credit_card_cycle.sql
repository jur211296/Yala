-- =====================================================================================================
-- g26_01 · tarjeta de crédito: `accounts.credit_card_statement_day` y `accounts.credit_card_reminder_days_before`
--
-- QUÉ GANA EL USUARIO. Desde 2.2 una tarjeta de crédito guarda su día de corte y cuántos días antes del pago quiere el
-- aviso (card nmtk). Con eso la ficha separa lo facturado de lo que entra en el siguiente corte, y el aviso llega con el
-- importe. Por iCloud los dos campos ya viajan; en Modo Nube, sin estas columnas, el otro teléfono no los vería.
--
-- QUÉ ES. Dos columnas `integer` NULLABLE:
--   · `credit_card_statement_day` (1…28). NULL = sin día de corte, como toda tarjeta de antes de 2.2.
--   · `credit_card_reminder_days_before` (0, 1, 3 o 5). NULL = una fila de un teléfono que aún no la conocía (= 0).
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g18_01, g21_01 y g24_01)
--   · Grants a nivel TABLA en las 16 tablas personales: las columnas los heredan. El §2 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 5`. Al revés, el Merkle del Worker pediría las columnas a PostgREST en una tabla
--      que no las tiene → 502 en cada verificación de cada teléfono que hable v5.
--   3. La app. La app declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v4 no emite ni hashea
--      las columnas, así que puede salir antes que 1-2.
--
-- === IDEMPOTENTE ===  `add column if not exists`; con una columna ya creada con OTRO tipo aborta (§2).
--
-- Marcha atrás: `g26_01_rollback.sql` (solo mientras ninguna tarjeta tenga día de corte ni días de aviso).
-- =====================================================================================================

begin;

-- §1 · las columnas
alter table public.accounts add column if not exists credit_card_statement_day integer;
alter table public.accounts add column if not exists credit_card_reminder_days_before integer;

comment on column public.accounts.credit_card_statement_day is
  'Tarjeta de crédito (card nmtk): día de corte 1…28. NULL = sin día de corte. g26_01, 2026-10-27.';
comment on column public.accounts.credit_card_reminder_days_before is
  'Tarjeta de crédito (card nmtk): días antes del pago para el aviso (0, 1, 3, 5). NULL = 0. g26_01, 2026-10-27.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_col text;
  v_type text;
  v_nullable text;
begin
  foreach v_col in array array['credit_card_statement_day', 'credit_card_reminder_days_before'] loop
    select data_type, is_nullable into v_type, v_nullable
      from information_schema.columns
     where table_schema = 'public' and table_name = 'accounts' and column_name = v_col;
    if v_type is distinct from 'integer' then
      raise exception 'g26_01: accounts.% existe con tipo % (se esperaba integer)', v_col, v_type;
    end if;
    if v_nullable <> 'YES' then
      raise exception 'g26_01: accounts.% no es nullable', v_col;
    end if;
    if not has_column_privilege('authenticated', 'public.accounts', v_col, 'SELECT')
       or not has_column_privilege('authenticated', 'public.accounts', v_col, 'INSERT')
       or not has_column_privilege('authenticated', 'public.accounts', v_col, 'UPDATE') then
      raise exception 'g26_01: authenticated no hereda SELECT/INSERT/UPDATE en accounts.%', v_col;
    end if;
  end loop;
  raise notice 'g26_01 OK · accounts.credit_card_statement_day y credit_card_reminder_days_before integer nullable, grants heredados';
end;
$$;

commit;
