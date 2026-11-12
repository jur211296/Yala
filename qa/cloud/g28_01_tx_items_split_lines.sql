-- =====================================================================================================
-- g28_01 · Grupos B: `tx_items.split_lines_raw`, tu parte de un gasto de grupo en líneas
--
-- QUÉ GANA EL USUARIO. Desde 2.2 tu parte de un gasto de grupo puede partirse en líneas (gasto o recarga): la recarga
-- de S/ 500 a tu Sip más S/ 10 de comisión, en vez de un gasto de 510 (diseño en
-- `docs/disenos/grupos-tu-parte-en-lineas/README.md`, «Versión final acordada»). Las líneas son una receta que guarda
-- UNA pata del gasto, y el puente deriva de ella las demás en cada pasada. En Modo Nube, sin esta columna, tu otro
-- teléfono no vería la receta y su puente volvería a dejar tu parte en una sola línea.
--
-- QUÉ ES. Una columna `text` NULLABLE con la receta tal cual la guarda la app (`GroupSplitLinesRecipe`). NULL = sin
-- receta. Sin CHECK a propósito: lo que no se entiende, o es de una versión posterior, la app lo lee sin romper y no lo
-- reescribe; un CHECK aquí rechazaría la fila ENTERA de un teléfono más nuevo.
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g21_01 y g26_01)
--   · Grants a nivel TABLA en las 16 tablas personales: la columna los hereda. El §2 lo comprueba y aborta si no.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--   · El conector `mcp/` lee `tx_items` con columnas explícitas: no la pide ni la necesita.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 6`. Al revés, el Merkle del Worker pediría `split_lines_raw` a PostgREST en una
--      tabla que no la tiene → 502 en cada verificación de cada teléfono que hable v6.
--   3. La app. La app declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v5 no emite ni hashea
--      la columna, así que puede salir antes que 1-2.
--
-- === IDEMPOTENTE ===  `add column if not exists`; con la columna ya creada con OTRO tipo aborta (§2).
--
-- Marcha atrás: `g28_01_rollback.sql` (solo mientras ningún movimiento tenga receta).
-- =====================================================================================================

begin;

-- `tx_items` es la tabla con más tráfico: el `add column` es solo de metadatos, pero pide un lock exclusivo. Si no lo
-- consigue en 5 s, aborta entera y se vuelve a lanzar (molde de hlc01_cap_future_hlc).
set local lock_timeout = '5s';

-- §1 · la columna
alter table public.tx_items add column if not exists split_lines_raw text;

comment on column public.tx_items.split_lines_raw is
  'Grupos B (card 1): tu parte de un gasto de grupo en líneas, receta del puente (GroupSplitLinesRecipe). NULL = sin receta. g28_01, 2026-11-01.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_nullable text;
begin
  select data_type, is_nullable into v_type, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'tx_items' and column_name = 'split_lines_raw';
  if v_type is distinct from 'text' then
    raise exception 'g28_01: tx_items.split_lines_raw existe con tipo % (se esperaba text)', v_type;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g28_01: tx_items.split_lines_raw no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.tx_items', 'split_lines_raw', 'SELECT')
     or not has_column_privilege('authenticated', 'public.tx_items', 'split_lines_raw', 'INSERT')
     or not has_column_privilege('authenticated', 'public.tx_items', 'split_lines_raw', 'UPDATE') then
    raise exception 'g28_01: authenticated no hereda SELECT/INSERT/UPDATE en tx_items.split_lines_raw';
  end if;
  raise notice 'g28_01 OK · tx_items.split_lines_raw text nullable, grants heredados';
end;
$$;

commit;
