-- mcp0_01_rollback — deshace mcp0_01_readonly_role (SOLO STAGING).
-- ORDEN: primero apaga el hook en la configuración de Auth (Management API:
--   hook_custom_access_token_enabled = false). Si borras la función con el hook encendido, falla TODO login.
do $$
declare t text;
begin
  foreach t in array array['accounts','tx_items','categories','subcategories','tags','budgets',
                           'scheduled_payments','user_preferences','exchange_rates'] loop
    execute format('drop policy if exists mcp_reader_select_own on public.%I', t);
  end loop;
end $$;

drop function if exists public.yala_mcp_access_token_hook(jsonb);

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'yala_mcp_reader') then
    revoke select on public.accounts, public.tx_items, public.categories, public.subcategories, public.tags,
      public.budgets, public.scheduled_payments, public.user_preferences, public.exchange_rates
      from yala_mcp_reader;
    revoke usage on schema public from yala_mcp_reader;
    revoke yala_mcp_reader from authenticator;
    drop role yala_mcp_reader;
  end if;
end $$;
