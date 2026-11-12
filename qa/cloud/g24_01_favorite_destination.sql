-- =====================================================================================================
-- g24_01 · favoritos: `favorite_payments.destination_account_ref`
--
-- QUÉ GANA EL USUARIO. Desde 2.2 un favorito de transferencia guarda origen y destino (UX 2.2 · L2-14). Por iCloud el
-- destino ya viaja; en Modo Nube un favorito de transferencia creado en un teléfono llegaba al otro sin destino
-- (card da5d). Esta columna es ese dato en la nube.
--
-- QUÉ ES. Una columna `uuid` NULLABLE con el `shortcutID` de la cuenta destino, como `account_ref`. NULL = el favorito
-- no es de transferencia, o es uno de antes de 2.2 sin destino.
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g18_01 y g21_01)
--   · Grants a nivel TABLA en las 16 tablas personales: la columna los hereda. El §2 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 4`. Al revés, el Merkle del Worker pediría `destination_account_ref` a
--      PostgREST en una tabla que no la tiene → 502 en cada verificación de cada teléfono que hable v4.
--   3. La app. La app declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v3 no emite ni
--      hashea la columna, así que puede salir antes que 1-2.
--
-- === IDEMPOTENTE ===  `add column if not exists`; con la columna ya creada con OTRO tipo aborta (§2).
--
-- Marcha atrás: `g24_01_rollback.sql` (solo mientras ningún favorito tenga destino).
-- =====================================================================================================

begin;

-- §1 · la columna
alter table public.favorite_payments add column if not exists destination_account_ref uuid;

comment on column public.favorite_payments.destination_account_ref is
  'Favoritos (UX 2.2 · L2-14, card da5d): cuenta destino de un favorito de transferencia (shortcutID). NULL = sin destino. g24_01, 2026-10-25.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_nullable text;
begin
  select data_type, is_nullable into v_type, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'favorite_payments' and column_name = 'destination_account_ref';
  if v_type is distinct from 'uuid' then
    raise exception 'g24_01: favorite_payments.destination_account_ref existe con tipo % (se esperaba uuid)', v_type;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g24_01: favorite_payments.destination_account_ref no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.favorite_payments', 'destination_account_ref', 'SELECT')
     or not has_column_privilege('authenticated', 'public.favorite_payments', 'destination_account_ref', 'INSERT')
     or not has_column_privilege('authenticated', 'public.favorite_payments', 'destination_account_ref', 'UPDATE') then
    raise exception 'g24_01: authenticated no hereda SELECT/INSERT/UPDATE en favorite_payments.destination_account_ref';
  end if;
  raise notice 'g24_01 OK · favorite_payments.destination_account_ref uuid nullable, grants heredados';
end;
$$;

commit;
