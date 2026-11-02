-- g28_01 · marcha atrás de `tx_items.split_lines_raw`.
--
-- Solo mientras NINGÚN movimiento tenga receta: borrarla con datos perdería las líneas de tu parte de quien ya las
-- guardó. Con datos, aborta sin tocar nada. Antes, vuelve al Worker anterior (`npx wrangler rollback <id>`): el Worker
-- con `manifest_version: 6` pide la columna en el Merkle y daría 502 sin ella. Ojo: `wrangler rollback` se salta el
-- guard del `predeploy`, y un teléfono que aún tenga apuntado «backend = 6» manda la columna a un Worker v5 hasta que su
-- siguiente pull apunte la 5 (`unknown_column`). En ese hueco caen TODAS las altas de movimientos de ese teléfono, no
-- solo las que llevan receta: un alta emite todas las columnas, también `split_lines_raw: null`. Y no se reintentan
-- (`unknown_column` es definitivo). Por eso el rollback del Worker v6 es el último recurso, no el primero.

begin;

set local lock_timeout = '5s';

-- El conteo y el `drop` bajo el MISMO lock (el molde de g18_01_rollback).
lock table public.tx_items in access exclusive mode;

do $$
declare
  v_count bigint := 0;
begin
  -- Idempotente: si la columna ya se retiró no hay nada que contar.
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tx_items'
             and column_name = 'split_lines_raw') then
    execute 'select count(*) from public.tx_items where split_lines_raw is not null' into v_count;
  end if;
  if v_count > 0 then
    raise exception 'g28_01_rollback: % movimiento(s) con receta de líneas; no se borra la columna', v_count;
  end if;
end;
$$;

alter table public.tx_items drop column if exists split_lines_raw;

commit;
