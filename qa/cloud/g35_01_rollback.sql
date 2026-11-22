-- g35_01 · marcha atrás de `accounts.credit_limit`.
--
-- Solo mientras NINGUNA cuenta tenga límite: borrarla con datos perdería el límite de quien ya lo guardó. Con datos,
-- aborta sin tocar nada. Antes, vuelve al Worker anterior (`npx wrangler rollback <id>`): el Worker con
-- `manifest_version: 10` pide la columna en el Merkle y daría 502 sin ella.

begin;

-- El conteo y el `drop` bajo el MISMO lock (el molde de g18_01_rollback).
lock table public.accounts in access exclusive mode;

do $$
declare
  v_count bigint := 0;
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'accounts'
             and column_name = 'credit_limit') then
    execute 'select count(*) from public.accounts where credit_limit is not null' into v_count;
  end if;
  if v_count > 0 then
    raise exception 'g35_01_rollback: % cuenta(s) con límite de tarjeta; no se borra la columna', v_count;
  end if;
end;
$$;

alter table public.accounts drop column if exists credit_limit;

commit;
