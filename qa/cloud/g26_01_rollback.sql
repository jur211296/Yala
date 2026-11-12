-- g26_01 · marcha atrás de `accounts.credit_card_statement_day` y `accounts.credit_card_reminder_days_before`.
--
-- Solo mientras NINGUNA cuenta tenga valor en ellas: borrarlas con datos perdería el día de corte o el aviso de quien ya
-- los guardó. Con datos, aborta sin tocar nada. Antes, vuelve al Worker anterior (`npx wrangler rollback <id>`): el Worker
-- con `manifest_version: 5` pide las columnas en el Merkle y daría 502 sin ellas. Ojo: `wrangler rollback` se salta el
-- guard del `predeploy`, y un teléfono que aún tenga apuntado «backend = 5» manda las columnas a un Worker v4 hasta que su
-- siguiente pull apunte la 4 (`unknown_column`, la fila entera rechazada en ese hueco).

begin;

-- El conteo y el `drop` bajo el MISMO lock (el molde de g18_01_rollback).
lock table public.accounts in access exclusive mode;

do $$
declare
  v_with_values bigint := 0;
  v_count bigint;
begin
  -- Idempotente y columna a columna: la que ya se retiró no se cuenta.
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'accounts'
             and column_name = 'credit_card_statement_day') then
    execute 'select count(*) from public.accounts where credit_card_statement_day is not null' into v_count;
    v_with_values := v_with_values + v_count;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'accounts'
             and column_name = 'credit_card_reminder_days_before') then
    execute 'select count(*) from public.accounts where coalesce(credit_card_reminder_days_before, 0) <> 0' into v_count;
    v_with_values := v_with_values + v_count;
  end if;
  if v_with_values > 0 then
    raise exception 'g26_01_rollback: % cuenta(s) con día de corte o días de aviso; no se borran las columnas', v_with_values;
  end if;
end;
$$;

alter table public.accounts drop column if exists credit_card_statement_day;
alter table public.accounts drop column if exists credit_card_reminder_days_before;

commit;
