-- g29_01 · marcha atrás: `split_expenses.last_edited_by_member_key` y `split_settlements.recorded_by_member_key`.
--
-- ANTES, el Worker anterior (`npx wrangler rollback <id>`): el Worker con el manifest de Grupos v3 pide las columnas al
-- reader en el pull y en el Merkle. Un teléfono que aún tenga apuntado «backend = 3» manda las columnas a un Worker v2
-- hasta que su siguiente pull apunte la 2 (`unknown_column`, definitivo): en ese hueco caen sus altas de gastos y de
-- liquidaciones. Por eso el rollback del Worker es el último recurso.
--
-- Borrar las columnas con datos solo pierde quién hizo cada cambio: los avisos vuelven a atribuirlo al pagador, como
-- antes de g29_01. No aborta con datos, a propósito: no es un dato del usuario que no se pueda reconstruir.

begin;

set local lock_timeout = '5s';

-- Readers de antes (los de `supabase-groups-staging.ddl` §5 previo a g29_01), con su EXECUTE.
drop function if exists public.groups_pull_rows_split_expenses(text, bigint, int, text);
create function public.groups_pull_rows_split_expenses(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, sync_id uuid, amount text, currency_code text, expense_description text,
  note text, date timestamptz, created_at timestamptz, paid_by_member_key text, split_type text,
  is_settled boolean, is_opening_balance boolean, subcategory_name text, field_hlcs jsonb,
  hlc text, deleted boolean, deleted_hlc text, server_seq bigint, schema_version integer, updated_at timestamptz
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.sync_id,
    public.yala_try_decrypt(t.amount, p_key), t.currency_code,
    public.yala_try_decrypt(t.expense_description, p_key),
    public.yala_try_decrypt(t.note, p_key),
    t.date, t.created_at, t.paid_by_member_key, t.split_type,
    t.is_settled, t.is_opening_balance, t.subcategory_name, t.field_hlcs,
    t.hlc, t.deleted, t.deleted_hlc, t.server_seq, t.schema_version, t.updated_at
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
  deleted_hlc text, server_seq bigint, schema_version integer, updated_at timestamptz
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, t.sync_id, t.from_member_key, t.to_member_key,
    public.yala_try_decrypt(t.amount, p_key), t.currency_code,
    public.yala_try_decrypt(t.note, p_key), t.date, t.is_confirmed, t.field_hlcs,
    t.hlc, t.deleted, t.deleted_hlc, t.server_seq, t.schema_version, t.updated_at
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

alter table public.split_expenses drop column if exists last_edited_by_member_key;
alter table public.split_settlements drop column if exists recorded_by_member_key;

commit;
