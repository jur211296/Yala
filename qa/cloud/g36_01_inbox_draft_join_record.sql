-- =====================================================================================================
-- g36_01 · lo que la Bandeja unió al llegar: `inbox_drafts.join_record_raw` (manifest v11)
--
-- QUÉ GANA EL USUARIO. Desde 2.3 el mismo consumo que llega por Apple Pay, el aviso del banco y el correo del banco es UN
-- pendiente en la Bandeja, no tres, y «Separar» lo deshace (lote 2 de la Bandeja sin duplicados, decisión de Jürgen del
-- 24-nov-2026). Lo que se unió viaja en este campo; por iCloud viaja en `CD_joinRecordRaw`. En Modo Nube, sin esta
-- columna, el otro teléfono vería el borrador unido pero no podría separarlo.
--
-- QUÉ ES. Una columna `text` NULLABLE con el JSON de `InboxJoinRecord`. NULL = nada unido, como todo borrador de antes.
--
-- === POR QUÉ NO HACE FALTA NADA MÁS === (lo mismo que g34_01 y g35_01)
--   · Grants a nivel TABLA para `authenticated`: la columna los hereda. El §2 lo comprueba y aborta si no.
--   · El rol de lectura de Yala web y del conector de IA (`yala_mcp_reader`, web1_01) lee `inbox_drafts` con grants por
--     COLUMNA: la nueva NO le llega, a propósito (lleva el texto de los avisos absorbidos). El §2 lo comprueba.
--   · `apply_delta` escribe con `jsonb_populate_record`: una columna nueva no cambia su cuerpo.
--   · RLS, `stamp_server_seq` y `cap_future_hlc` son por fila.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `manifest_version: 11`. Al revés, el Merkle del Worker pediría la columna a PostgREST en una tabla
--      que no la tiene → 502 en cada verificación de cada teléfono que hable v11.
--   3. La app. La app declara la versión que el Worker ANUNCIA (`SyncCapability`): con un Worker v10 no emite ni hashea
--      la columna (la apunta y la sube al llegar la v11), así que puede salir antes que 1-2.
--
-- === IDEMPOTENTE ===  `add column if not exists`; con una columna ya creada con OTRO tipo aborta (§2).
--
-- Marcha atrás: `g36_01_rollback.sql` (solo mientras ningún borrador tenga algo unido).
-- =====================================================================================================

begin;

-- §1 · la columna
alter table public.inbox_drafts add column if not exists join_record_raw text;

comment on column public.inbox_drafts.join_record_raw is
  'Lo que la Bandeja unió al llegar (JSON de InboxJoinRecord). NULL = nada unido. g36_01, 2026-11-24.';

-- §2 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  v_type text;
  v_nullable text;
begin
  select data_type, is_nullable into v_type, v_nullable
    from information_schema.columns
   where table_schema = 'public' and table_name = 'inbox_drafts' and column_name = 'join_record_raw';
  if v_type is distinct from 'text' then
    raise exception 'g36_01: inbox_drafts.join_record_raw existe con tipo % (se esperaba text)', v_type;
  end if;
  if v_nullable <> 'YES' then
    raise exception 'g36_01: inbox_drafts.join_record_raw no es nullable';
  end if;
  if not has_column_privilege('authenticated', 'public.inbox_drafts', 'join_record_raw', 'SELECT')
     or not has_column_privilege('authenticated', 'public.inbox_drafts', 'join_record_raw', 'INSERT')
     or not has_column_privilege('authenticated', 'public.inbox_drafts', 'join_record_raw', 'UPDATE') then
    raise exception 'g36_01: authenticated no hereda SELECT/INSERT/UPDATE en inbox_drafts.join_record_raw';
  end if;
  if exists (select 1 from pg_roles where rolname = 'yala_mcp_reader')
     and has_column_privilege('yala_mcp_reader', 'public.inbox_drafts', 'join_record_raw', 'SELECT') then
    raise exception 'g36_01: yala_mcp_reader puede leer inbox_drafts.join_record_raw (sus grants deberían ser por columna)';
  end if;
  raise notice 'g36_01 OK · inbox_drafts.join_record_raw text nullable, grants heredados, fuera del rol de lectura web';
end;
$$;

commit;
