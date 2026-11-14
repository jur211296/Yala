-- Marcha atrás de web3_01_grupos_lectura (solo staging): quita políticas, GRANTs y el helper.
revoke execute on function
  public.groups_pull_rows_split_groups(text, bigint, int, text),
  public.groups_pull_rows_group_members(text, bigint, int, text),
  public.groups_pull_rows_split_expenses(text, bigint, int, text),
  public.groups_pull_rows_split_shares(text, bigint, int, text),
  public.groups_pull_rows_split_settlements(text, bigint, int, text)
  from yala_mcp_reader;
revoke execute on function public.is_group_member(text), public.is_group_writer(text),
  public.yala_try_decrypt(bytea, text) from yala_mcp_reader;
drop policy if exists web_reader_select on public.split_groups;
drop policy if exists web_reader_select on public.group_members;
drop policy if exists web_reader_select on public.split_expenses;
drop policy if exists web_reader_select on public.split_shares;
drop policy if exists web_reader_select on public.split_settlements;
revoke select on public.split_groups, public.group_members, public.split_expenses, public.split_shares,
  public.split_settlements from yala_mcp_reader;
drop function if exists public.yala_is_web_reader();
