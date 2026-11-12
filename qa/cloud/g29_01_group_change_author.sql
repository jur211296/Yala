-- =====================================================================================================
-- g29_01 · Grupos: quién creó o editó un gasto, y quién registró una liquidación, viajan por el canal
--
-- QUÉ GANA EL USUARIO. El aviso local de un gasto de grupo («🧾 Ana agregó 'Cena' — te toca S/ 40») ya no le
-- sale a quien hizo el cambio en su OTRO dispositivo. Hasta hoy el teléfono guardaba el autor
-- (`SplitExpense.lastEditedByMemberID`, `SplitSettlement.recordedByMemberID`) pero el canal no lo llevaba: en el
-- iPad de la misma cuenta el campo llegaba vacío, el aviso caía al pagador como autor, y si Jürgen apuntaba en su
-- iPhone un gasto que pagó Ana, su iPad le enseñaba «Ana agregó…». Lo mismo con «X te pagó» de una liquidación
-- que registró él mismo. Card xi74 (2026-11-02).
--
-- QUÉ ES. Dos columnas `text` NULLABLE, en claro como `paid_by_member_key` (un id de miembro, no un monto ni un
-- texto del usuario: el modelo de amenaza de G7 cifra montos y textos libres):
--   · `split_expenses.last_edited_by_member_key`  ← `SplitExpense.lastEditedByMemberID`
--   · `split_settlements.recorded_by_member_key`  ← `SplitSettlement.recordedByMemberID`
-- NULL = no se sabe (filas anteriores, o escritas por una app que no la conoce): el cliente cae al pagador.
--
-- === QUÉ TOCA Y QUÉ NO ===
--   · `apply_group_delta` NO cambia: las columnas en claro entran por `jsonb_populate_record` (v_plain_fields), y
--     ninguna de las dos es † (no va en `v_tcols`). md5 vivo en los dos entornos el 2026-11-02: ae78bce6….
--   · El UPDATE de `authenticated` es POR COLUMNA en las tablas de Grupos (hallazgo #1 de G1) y NO se hereda: sin el
--     grant, el push daría 42501 → `yala_not_authorized` y se rechazaría el delta ENTERO, no solo el campo. El INSERT
--     y el SELECT sí se heredan del grant de tabla; el §4 lo comprueba.
--   · Los readers del pull (`groups_pull_rows_<tabla>`) devuelven columnas explícitas: la nueva va AL FINAL (el gateway
--     lee por nombre). Cambiar el RETURNS TABLE exige DROP + CREATE, y el DROP se lleva el EXECUTE: se re-otorga aquí,
--     dentro de la transacción, sin ventana con el reader ausente.
--   · El trigger `opening_balance_guard` (g27_01) y `cap_future_hlc` (hlc01) son por fila: no les afecta.
--
-- === EL ORDEN DE DESPLIEGUE ===
--   1. Esta migración (staging → producción).
--   2. El Worker con `group_capability_manifest.json` v3 (las dos columnas con `since: 3`). Al revés, el Merkle y el pull
--      del Worker pedirían al reader una columna que no devuelve.
--   3. La app. Declara la versión que el Worker ANUNCIA (`GroupsSyncCapability`): contra un Worker v2 no emite ni hashea
--      las columnas, así que puede salir antes que 1-2; lo que no subió lo re-emite al cruzar a v3.
--   Un Worker v2 con esta migración aplicada ignora la columna extra del reader (lee por nombre): orden 1 → 2 sin hueco.
--
-- === IDEMPOTENTE === `add column if not exists`; los readers se recrean enteros. Con una columna ya creada con OTRO
-- tipo, o con un reader que no estaba en la versión esperada, aborta entera (§1 y §4).
--
-- Marcha atrás: `g29_01_rollback.sql`.
-- =====================================================================================================

begin;

set local lock_timeout = '5s';

-- §1 · los readers tienen que estar en la versión medida (md5 de prosrc, idénticos en staging y producción el
-- 2026-11-02). Si alguien los cambió después, se re-verifica antes de pisarlos. Una segunda pasada encuentra el
-- reader ya recreado: se acepta también el md5 de llegada (idempotente).
do $$
declare
  v_exp text;
  v_set text;
begin
  select md5(prosrc) into v_exp from pg_proc
   where oid = 'public.groups_pull_rows_split_expenses(text, bigint, int, text)'::regprocedure;
  select md5(prosrc) into v_set from pg_proc
   where oid = 'public.groups_pull_rows_split_settlements(text, bigint, int, text)'::regprocedure;
  if v_exp is distinct from '3d9232840c64c84aaaddfc88215f5132'
     and not exists (select 1 from information_schema.columns where table_schema = 'public'
                      and table_name = 'split_expenses' and column_name = 'last_edited_by_member_key') then
    raise exception 'g29_01 ABORTA: groups_pull_rows_split_expenses no está en la versión medida (md5 %)', v_exp;
  end if;
  if v_set is distinct from '1d4b3c20ec010e217a89715293216cd5'
     and not exists (select 1 from information_schema.columns where table_schema = 'public'
                      and table_name = 'split_settlements' and column_name = 'recorded_by_member_key') then
    raise exception 'g29_01 ABORTA: groups_pull_rows_split_settlements no está en la versión medida (md5 %)', v_set;
  end if;
end;
$$;

-- §2 · las columnas y su grant de UPDATE (por columna, no se hereda)
alter table public.split_expenses add column if not exists last_edited_by_member_key text;
alter table public.split_settlements add column if not exists recorded_by_member_key text;
grant update (last_edited_by_member_key) on public.split_expenses to authenticated;
grant update (recorded_by_member_key) on public.split_settlements to authenticated;

comment on column public.split_expenses.last_edited_by_member_key is
  'Grupos: miembro que creó o editó por última vez el gasto (SplitExpense.lastEditedByMemberID). NULL = no se sabe. g29_01, 2026-11-02.';
comment on column public.split_settlements.recorded_by_member_key is
  'Grupos: miembro que registró la liquidación (SplitSettlement.recordedByMemberID). NULL = no se sabe. g29_01, 2026-11-02.';

-- §3 · readers del pull con la columna nueva AL FINAL
drop function if exists public.groups_pull_rows_split_expenses(text, bigint, int, text);
create function public.groups_pull_rows_split_expenses(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, sync_id uuid, amount text, currency_code text, expense_description text,
  note text, date timestamptz, created_at timestamptz, paid_by_member_key text, split_type text,
  is_settled boolean, is_opening_balance boolean, subcategory_name text, field_hlcs jsonb,
  hlc text, deleted boolean, deleted_hlc text, server_seq bigint, schema_version integer, updated_at timestamptz,
  last_edited_by_member_key text
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.sync_id,
    public.yala_try_decrypt(t.amount, p_key), t.currency_code,
    public.yala_try_decrypt(t.expense_description, p_key),
    public.yala_try_decrypt(t.note, p_key),
    t.date, t.created_at, t.paid_by_member_key, t.split_type,
    t.is_settled, t.is_opening_balance, t.subcategory_name, t.field_hlcs,
    t.hlc, t.deleted, t.deleted_hlc, t.server_seq, t.schema_version, t.updated_at,
    t.last_edited_by_member_key
  from public.split_expenses t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

drop function if exists public.groups_pull_rows_split_settlements(text, bigint, int, text);
create function public.groups_pull_rows_split_settlements(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, sync_id uuid, from_member_key text, to_member_key text, amount text, currency_code text,
  note text, date timestamptz, is_confirmed boolean, field_hlcs jsonb, hlc text, deleted boolean,
  deleted_hlc text, server_seq bigint, schema_version integer, updated_at timestamptz,
  recorded_by_member_key text
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.sync_id, t.from_member_key, t.to_member_key,
    public.yala_try_decrypt(t.amount, p_key), t.currency_code,
    public.yala_try_decrypt(t.note, p_key), t.date, t.is_confirmed, t.field_hlcs,
    t.hlc, t.deleted, t.deleted_hlc, t.server_seq, t.schema_version, t.updated_at,
    t.recorded_by_member_key
  from public.split_settlements t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

revoke all on function
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  from public, anon;
grant execute on function
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  to authenticated;

-- §4 · comprobaciones: aborta la transacción entera si algo no es lo esperado
do $$
declare
  r record;
begin
  for r in select * from (values ('split_expenses', 'last_edited_by_member_key'),
                                 ('split_settlements', 'recorded_by_member_key')) v(t, c) loop
    if (select data_type from information_schema.columns
         where table_schema = 'public' and table_name = r.t and column_name = r.c) is distinct from 'text' then
      raise exception 'g29_01: %.% no es text', r.t, r.c;
    end if;
    if not has_column_privilege('authenticated', 'public.' || r.t, r.c, 'SELECT')
       or not has_column_privilege('authenticated', 'public.' || r.t, r.c, 'INSERT')
       or not has_column_privilege('authenticated', 'public.' || r.t, r.c, 'UPDATE') then
      raise exception 'g29_01: authenticated sin SELECT/INSERT/UPDATE en %.%', r.t, r.c;
    end if;
  end loop;
  if pg_get_function_result('public.groups_pull_rows_split_expenses(text, bigint, int, text)'::regprocedure)
       not like '%last_edited_by_member_key text)' then
    raise exception 'g29_01: el reader de split_expenses no devuelve last_edited_by_member_key al final';
  end if;
  if pg_get_function_result('public.groups_pull_rows_split_settlements(text, bigint, int, text)'::regprocedure)
       not like '%recorded_by_member_key text)' then
    raise exception 'g29_01: el reader de split_settlements no devuelve recorded_by_member_key al final';
  end if;
  if not has_function_privilege('authenticated', 'public.groups_pull_rows_split_expenses(text, bigint, int, text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.groups_pull_rows_split_settlements(text, bigint, int, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.groups_pull_rows_split_expenses(text, bigint, int, text)', 'EXECUTE') then
    raise exception 'g29_01: EXECUTE de los readers mal otorgado';
  end if;
  raise notice 'g29_01 OK';
end;
$$;

commit;
