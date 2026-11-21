-- g33_01 · marcha atrás de los límites del flujo de caja con pagos y en otra moneda.
--
-- Solo mientras NINGUNA línea tenga valor en las cuatro columnas: con datos, aborta sin tocar nada. Antes, vuelve al
-- Worker anterior (`npx wrangler rollback <id>`): el Worker con `manifest_version: 8` pide las columnas en el Merkle y
-- daría 502 sin ellas.

begin;

set local lock_timeout = '5s';

lock table public.cashflow_lines in access exclusive mode;

do $$
declare
  v_rows bigint := 0;
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public'
             and table_name = 'cashflow_lines' and column_name = 'scheduled_payment_ids_raw') then
    execute 'select count(*) from public.cashflow_lines where scheduled_payment_ids_raw is not null
             or limit_extra_amount is not null or limit_currency_code is not null or limit_foreign_amount is not null'
      into v_rows;
  end if;
  if v_rows > 0 then
    raise exception 'g33_01_rollback: % línea(s) con valor en las columnas nuevas; no se retira nada', v_rows;
  end if;
end;
$$;

alter table public.cashflow_lines drop column if exists scheduled_payment_ids_raw;
alter table public.cashflow_lines drop column if exists limit_extra_amount;
alter table public.cashflow_lines drop column if exists limit_currency_code;
alter table public.cashflow_lines drop column if exists limit_foreign_amount;

commit;
