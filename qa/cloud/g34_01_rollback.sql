-- g34_01 · marcha atrás de `accounts.capture_rules_raw`.
--
-- Solo mientras NINGUNA cuenta tenga reglas: borrarla con datos perdería las reglas de quien ya las guardó. Con datos,
-- aborta sin tocar nada. Antes, vuelve al Worker anterior (`npx wrangler rollback <id>`): el Worker con
-- `manifest_version: 9` pide la columna en el Merkle y daría 502 sin ella.

begin;

-- El conteo y el `drop` bajo el MISMO lock (el molde de g18_01_rollback).
lock table public.accounts in access exclusive mode;

do $$
declare
  v_count bigint := 0;
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'accounts'
             and column_name = 'capture_rules_raw') then
    execute 'select count(*) from public.accounts where capture_rules_raw is not null' into v_count;
  end if;
  if v_count > 0 then
    raise exception 'g34_01_rollback: % cuenta(s) con reglas de captura; no se borra la columna', v_count;
  end if;
end;
$$;

alter table public.accounts drop column if exists capture_rules_raw;

commit;
