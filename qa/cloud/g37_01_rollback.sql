-- g37_01 · marcha atrás: el reader vuelve a su versión de g14_01 (sin `is_person`) y la columna se retira.
-- Antes de aplicarla en un entorno con personas marcadas, comprueba qué app las escribió: una app v4 contra un Worker v4
-- volvería a subir la marca en el siguiente cambio de la meta y el push daría 42703.
begin;

set local lock_timeout = '5s';

drop function if exists public.groups_pull_rows_split_groups(text, bigint, int, text);
create function public.groups_pull_rows_split_groups(
  p_group_id text, p_after_seq bigint, p_limit int, p_key text
) returns table(
  group_id text, name text, icon_name text, color_hex text, currency_code text,
  simplify_debts boolean, show_debts_in_single_currency boolean, members_can_invite boolean,
  default_split_type text, is_archived boolean, is_hidden_for_all boolean, owner_user_id uuid,
  created_at timestamptz, field_hlcs jsonb, hlc text, deleted boolean, deleted_hlc text,
  server_seq bigint, schema_version integer, updated_at timestamptz,
  budget_limit_amount text
) language sql security invoker stable set search_path = public, extensions as $$
  select
    t.group_id, public.yala_try_decrypt(t.name, p_key), t.icon_name, t.color_hex, t.currency_code,
    t.simplify_debts, t.show_debts_in_single_currency, t.members_can_invite,
    t.default_split_type, t.is_archived, t.is_hidden_for_all, t.owner_user_id,
    t.created_at, t.field_hlcs, t.hlc, t.deleted, t.deleted_hlc,
    t.server_seq, t.schema_version, t.updated_at,
    public.yala_try_decrypt(t.budget_limit_amount, p_key)
  from public.split_groups t
  where t.group_id = p_group_id and t.server_seq > p_after_seq
  order by t.server_seq asc
  limit p_limit
$$;

revoke all on function public.groups_pull_rows_split_groups(text, bigint, int, text) from public, anon;
grant execute on function public.groups_pull_rows_split_groups(text, bigint, int, text) to authenticated;

alter table public.split_groups drop column if exists is_person;

commit;
