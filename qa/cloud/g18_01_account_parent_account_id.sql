-- =====================================================================================================
-- g18_01 · tarjeta con varias divisas: `accounts.parent_account_id`
--
-- QUÉ GANA EL USUARIO. Una tarjeta peruana cobra en soles y en dólares por separado. En Yala será una cuenta
-- principal (la de soles) y una LÍNEA por cada divisa extra: otra cuenta de una sola divisa que apunta a la
-- principal. Esta columna es ese enlace en la nube. Sin ella, la línea que alguien vincule en un teléfono en
-- Modo Nube no llega a sus otros teléfonos. Decisión A1 de Jürgen (2026-10-09), entrega 1 del ticket
-- `multi-currency-accounts-1-model-and-sync`.
--
-- QUÉ ES. Una columna `uuid` NULLABLE con el `shortcutID` de la principal, que es su `sync_id` en `accounts`
-- (`capability_manifest.json`: `sync_id_source = Account.shortcutID`). NULL = cuenta normal o principal.
-- Sin FK a propósito: una línea puede llegar antes que su principal (dos teléfonos, orden de subida), y la app
-- la lee como cuenta suelta hasta que llegue (`AccountLineLogic`). Una FK rechazaría esa fila entera.
--
-- === POR QUÉ NO HACE FALTA NADA MÁS ===
--   · Grants: los de las 16 tablas personales son a nivel TABLA (`GRANT SELECT,INSERT,UPDATE TO authenticated`,
--     cabecera de `supabase-staging.ddl`), así que la columna nueva los hereda. Distinto de `split_groups`, cuyo
--     UPDATE es por columna (g14_01). El §2 lo COMPRUEBA en vez de suponerlo, y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila: no miran columnas.
--
-- === EL ORDEN DE DESPLIEGUE, Y NO TIENE EXCEPCIÓN ===
--   1. Esta migración (staging → sonda → producción).
--   2. El Worker con `manifest_version: 2` (`npm run deploy:staging` / `deploy:production`). Al revés, el Merkle
--      del Worker pediría `parent_account_id` a PostgREST en una tabla que no la tiene → 400 → 502 en cada
--      verificación de cada teléfono 2.2 (los 2.1 piden `v1`, que no la incluye: con solo 2.1 no se nota nada,
--      y por eso el humo del runbook no basta y el paso que lo prueba es la consulta de la columna).
--   3. La app. Desde 2.2 la app declara la versión del manifest que el Worker ANUNCIA (`SyncCapability.swift`):
--      con un Worker viejo no emite ni hashea la columna, así que la app puede salir antes que 1-2 sin romper
--      nada; lo que no puede es salir el Worker antes que esta migración.
--
-- === IDEMPOTENTE ===
--   `add column if not exists`. Re-aplicarla es un no-op; con la columna ya creada con OTRO tipo aborta (§2).
--   Transacción propia: si una comprobación falla, no queda nada a medias.
--
-- Marcha atrás: `g18_01_rollback.sql` (solo mientras ninguna fila tenga un enlace).
-- =====================================================================================================

begin;

-- §1 · la columna
alter table public.accounts add column if not exists parent_account_id uuid;

comment on column public.accounts.parent_account_id is
  'Tarjeta con varias divisas: sync_id (Account.shortcutID) de la cuenta principal si esta cuenta es una línea en otra divisa. NULL = cuenta normal o principal. Sin FK: una línea puede llegar antes que su principal. g18_01, 2026-10-18.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_nullable text;
begin
  select data_type, is_nullable into v_type, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'accounts' and column_name = 'parent_account_id';
  if v_type is distinct from 'uuid' then
    raise exception 'g18_01: accounts.parent_account_id existe con tipo % (se esperaba uuid)', v_type;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g18_01: accounts.parent_account_id no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.accounts', 'parent_account_id', 'SELECT')
     or not has_column_privilege('authenticated', 'public.accounts', 'parent_account_id', 'INSERT')
     or not has_column_privilege('authenticated', 'public.accounts', 'parent_account_id', 'UPDATE') then
    raise exception 'g18_01: authenticated no hereda SELECT/INSERT/UPDATE en accounts.parent_account_id (¿grants por columna?)';
  end if;
  raise notice 'g18_01 OK · accounts.parent_account_id uuid nullable, grants heredados';
end;
$$;

commit;
