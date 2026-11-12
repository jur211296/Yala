-- g24_01 · marcha atrás de `favorite_payments.destination_account_ref`.
--
-- Solo mientras NINGÚN favorito tenga destino: borrar la columna con datos perdería el destino de quien ya lo guardó.
-- Con datos, aborta sin tocar nada. Antes, vuelve al Worker anterior (`npx wrangler rollback <id>`): el Worker con
-- `manifest_version: 4` pide la columna en el Merkle y daría 502 sin ella. Ojo: `wrangler rollback` se salta el guard
-- del `predeploy`, y un teléfono que aún tenga apuntado «backend = 4» manda la columna a un Worker v3 hasta que su
-- siguiente pull apunte la 3 (`unknown_column`, la fila entera rechazada en ese hueco).

begin;

-- El conteo y el `drop` bajo el MISMO lock (el molde de g18_01_rollback).
lock table public.favorite_payments in access exclusive mode;

do $$
declare
  v_with_destination bigint;
begin
  -- Idempotente: sin la columna (ya se retiró), no hay nada que contar.
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'favorite_payments' and column_name = 'destination_account_ref'
  ) then
    return;
  end if;
  execute 'select count(*) from public.favorite_payments where destination_account_ref is not null' into v_with_destination;
  if v_with_destination > 0 then
    raise exception 'g24_01_rollback: % favorito(s) con destino; no se borra la columna', v_with_destination;
  end if;
end;
$$;

alter table public.favorite_payments drop column if exists destination_account_ref;

commit;
