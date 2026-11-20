-- =====================================================================================================
-- g32_01 · Pagos planificados: logo propio con una foto (`scheduled_payments.custom_logo_ref` + bucket privado)
--
-- QUÉ GANA EL USUARIO. Un pago planificado cuyo comercio no está en el banco de logos (colegio, alquiler, gimnasio, la
-- tienda del barrio) puede llevar una foto como logo. En Modo Nube la foto vive en Supabase Storage y el pago guarda
-- solo su referencia; sin esto, el otro teléfono de la misma cuenta enseñaría el icono por defecto.
--
-- QUÉ ES.
--   §1 · `scheduled_payments.custom_logo_ref text` NULLABLE: el nombre del archivo dentro de la carpeta del usuario
--        (`<uuid>.jpg`, dentro de la carpeta `<user_id>/` del bucket). NULL = sin foto. Sin CHECK, por lo mismo que g28_01: un teléfono más nuevo
--        no puede ver rechazada la fila ENTERA por un formato que este servidor no conoce.
--   §2 · Bucket PRIVADO `scheduled-payment-logos`: solo JPEG, hasta 100 KB (la app sube 256 × 256 px, 10–30 KB).
--   §3 · Cuatro políticas sobre `storage.objects`, una por verbo: cada usuario solo lee, sube, cambia y borra lo que
--        cuelga de su carpeta (`<auth.uid()>/…`). El rol `anon` no tiene ninguna.
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g21_01, g26_01 y g28_01)
--   · Grants a nivel TABLA: la columna los hereda. El §4 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 7`. Al revés, su Merkle pediría `custom_logo_ref` a una tabla sin ella → 502.
--   3. La app. Declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v6 ni emite ni hashea la
--      columna, y la foto se queda en ese teléfono hasta que el Worker suba.
--
-- === IDEMPOTENTE ===  `add column if not exists`, `on conflict do nothing` y `drop policy if exists` antes de crear.
--
-- Marcha atrás: `g32_01_rollback.sql` (solo mientras ningún pago tenga foto y el bucket esté vacío).
-- =====================================================================================================

begin;

set local lock_timeout = '5s';

-- §1 · la columna
alter table public.scheduled_payments add column if not exists custom_logo_ref text;

comment on column public.scheduled_payments.custom_logo_ref is
  'Logo propio del pago (foto). Ruta dentro de <user_id>/ en el bucket scheduled-payment-logos. NULL = sin foto. g32_01, 2026-11-20.';

-- §2 · el bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scheduled-payment-logos', 'scheduled-payment-logos', false, 102400, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = 102400, allowed_mime_types = array['image/jpeg'];

-- §3 · las políticas: la primera carpeta del objeto es el usuario
drop policy if exists "scheduled_payment_logos_select_own" on storage.objects;
drop policy if exists "scheduled_payment_logos_insert_own" on storage.objects;
drop policy if exists "scheduled_payment_logos_update_own" on storage.objects;
drop policy if exists "scheduled_payment_logos_delete_own" on storage.objects;

create policy "scheduled_payment_logos_select_own" on storage.objects for select to authenticated
  using (bucket_id = 'scheduled-payment-logos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "scheduled_payment_logos_insert_own" on storage.objects for insert to authenticated
  with check (bucket_id = 'scheduled-payment-logos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "scheduled_payment_logos_update_own" on storage.objects for update to authenticated
  using (bucket_id = 'scheduled-payment-logos' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'scheduled-payment-logos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "scheduled_payment_logos_delete_own" on storage.objects for delete to authenticated
  using (bucket_id = 'scheduled-payment-logos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- §4 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_nullable text;
  v_public boolean;
  v_policies int;
begin
  select data_type, is_nullable into v_type, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'scheduled_payments' and column_name = 'custom_logo_ref';
  if v_type is distinct from 'text' then
    raise exception 'g32_01: scheduled_payments.custom_logo_ref existe con tipo % (se esperaba text)', v_type;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g32_01: scheduled_payments.custom_logo_ref no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.scheduled_payments', 'custom_logo_ref', 'SELECT')
     or not has_column_privilege('authenticated', 'public.scheduled_payments', 'custom_logo_ref', 'INSERT')
     or not has_column_privilege('authenticated', 'public.scheduled_payments', 'custom_logo_ref', 'UPDATE') then
    raise exception 'g32_01: authenticated no hereda SELECT/INSERT/UPDATE en scheduled_payments.custom_logo_ref';
  end if;
  select public into v_public from storage.buckets where id = 'scheduled-payment-logos';
  if v_public is distinct from false then
    raise exception 'g32_01: el bucket scheduled-payment-logos no existe o es público';
  end if;
  select count(*) into v_policies from pg_policies
   where schemaname = 'storage' and tablename = 'objects' and policyname like 'scheduled_payment_logos_%';
  if v_policies <> 4 then
    raise exception 'g32_01: se esperaban 4 políticas del bucket y hay %', v_policies;
  end if;
  raise notice 'g32_01 OK · custom_logo_ref text nullable, bucket privado, 4 políticas';
end;
$$;

commit;
