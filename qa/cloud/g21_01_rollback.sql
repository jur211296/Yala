-- g21_01 · marcha atrás de `cashflow_lines.amount_changes_raw`.
--
-- Solo mientras NINGUNA línea tenga cambios: borrar la columna con datos perdería los «desde este mes» de quien ya
-- los apuntó. Con datos, aborta sin tocar nada. Antes, vuelve al Worker anterior (`npx wrangler rollback <id>`): el
-- Worker con `manifest_version: 3` pide la columna en el Merkle y daría 502 sin ella. Ojo: `wrangler rollback` se salta
-- el guard del `predeploy`, y un teléfono que aún tenga apuntado «backend = 3» manda la columna a un Worker v2 hasta que
-- su siguiente pull apunte la 2 (`unknown_column`, la fila entera rechazada en ese hueco).

begin;

-- El conteo y el `drop` bajo el MISMO lock (el molde de g18_01_rollback).
lock table public.cashflow_lines in access exclusive mode;

do $$
declare
  v_with_changes bigint;
begin
  -- Idempotente: sin la columna (ya se retiró), no hay nada que contar.
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'cashflow_lines' and column_name = 'amount_changes_raw'
  ) then
    return;
  end if;
  execute 'select count(*) from public.cashflow_lines where amount_changes_raw is not null' into v_with_changes;
  if v_with_changes > 0 then
    raise exception 'g21_01_rollback: % línea(s) con cambios; no se borra la columna', v_with_changes;
  end if;
end;
$$;

alter table public.cashflow_lines drop column if exists amount_changes_raw;

commit;
