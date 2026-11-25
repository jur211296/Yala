-- g36_01 · marcha atrás de `inbox_drafts.join_record_raw`.
--
-- Solo mientras NINGÚN borrador tenga algo unido: borrarla con datos dejaría sin «Separar» a quien ya unió algo (el
-- borrador unido se queda, pero lo absorbido se perdería en los teléfonos que lo bajen de la nube). Con datos, aborta sin
-- tocar nada. Antes, vuelve al Worker anterior (`npx wrangler rollback <id>`): el Worker con `manifest_version: 11` pide
-- la columna en el Merkle y daría 502 sin ella.

begin;

-- El conteo y el `drop` bajo el MISMO lock (el molde de g18_01_rollback).
lock table public.inbox_drafts in access exclusive mode;

do $$
declare
  v_count bigint := 0;
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'inbox_drafts'
             and column_name = 'join_record_raw') then
    execute 'select count(*) from public.inbox_drafts where join_record_raw is not null' into v_count;
  end if;
  if v_count > 0 then
    raise exception 'g36_01_rollback: % borrador(es) con algo unido; no se borra la columna', v_count;
  end if;
end;
$$;

alter table public.inbox_drafts drop column if exists join_record_raw;

commit;
