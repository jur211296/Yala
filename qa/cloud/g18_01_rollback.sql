-- g18_01 · marcha atrás de `accounts.parent_account_id`.
--
-- Solo mientras NINGUNA fila tenga un enlace: borrar la columna con datos perdería las líneas de las tarjetas de
-- quien ya las vinculó, y eso no se recupera. Con datos, aborta sin tocar nada.
-- Antes de aplicarla, vuelve al Worker anterior (`npx wrangler rollback <id>`): el Worker con `manifest_version: 2`
-- pide la columna en el Merkle y daría 502 sin ella.

begin;

-- El conteo y el `drop` bajo el MISMO lock: sin él, un Worker con la versión 2 todavía vivo podía escribir un enlace
-- entre el conteo y el `alter`, y el `drop` se lo llevaría (review del 2026-10-18).
lock table public.accounts in access exclusive mode;

do $$
declare
  v_linked bigint;
begin
  select count(*) into v_linked from public.accounts where parent_account_id is not null;
  if v_linked > 0 then
    raise exception 'g18_01_rollback: % cuenta(s) con enlace; no se borra la columna', v_linked;
  end if;
end;
$$;

alter table public.accounts drop column if exists parent_account_id;

commit;
