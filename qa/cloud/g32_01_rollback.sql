-- g32_01 · marcha atrás del logo propio de los pagos planificados.
--
-- Solo mientras NINGÚN pago tenga foto y el bucket esté vacío: con datos, aborta sin tocar nada. Antes, vuelve al
-- Worker anterior (`npx wrangler rollback <id>`): el Worker con `manifest_version: 7` pide la columna en el Merkle y
-- daría 502 sin ella. Un teléfono que aún tenga apuntado «backend = 7» manda la columna a un Worker v6 hasta que su
-- siguiente pull apunte la 6 (`unknown_column`): por eso el rollback del Worker es el último recurso.

begin;

set local lock_timeout = '5s';

lock table public.scheduled_payments in access exclusive mode;

do $$
declare
  v_rows bigint := 0;
  v_objects bigint := 0;
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public'
             and table_name = 'scheduled_payments' and column_name = 'custom_logo_ref') then
    execute 'select count(*) from public.scheduled_payments where custom_logo_ref is not null' into v_rows;
  end if;
  select count(*) into v_objects from storage.objects where bucket_id = 'scheduled-payment-logos';
  if v_rows > 0 or v_objects > 0 then
    raise exception 'g32_01_rollback: % pago(s) con foto y % archivo(s) en el bucket; no se retira nada', v_rows, v_objects;
  end if;
end;
$$;

drop policy if exists "scheduled_payment_logos_select_own" on storage.objects;
drop policy if exists "scheduled_payment_logos_insert_own" on storage.objects;
drop policy if exists "scheduled_payment_logos_update_own" on storage.objects;
drop policy if exists "scheduled_payment_logos_delete_own" on storage.objects;
delete from storage.buckets where id = 'scheduled-payment-logos';
alter table public.scheduled_payments drop column if exists custom_logo_ref;

commit;
