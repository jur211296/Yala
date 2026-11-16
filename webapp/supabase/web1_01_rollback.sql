-- Marcha atrás de web1_01_bandeja_y_sesiones (SOLO STAGING). Deja el rol de solo lectura con sus 9 tablas de mcp0_01.

select cron.unschedule('yala-web-sweep-sessions')
where exists (select 1 from cron.job where jobname = 'yala-web-sweep-sessions');
drop function if exists public.yala_web_sweep_sessions();

drop function if exists public.yala_web_close_session(uuid);

drop policy if exists mcp_reader_select_own on public.inbox_drafts;
revoke select on public.inbox_drafts from yala_mcp_reader;
revoke select (sync_id, note, amount, date, cached_currency_code, cached_account_name, cached_subcategory_name,
  source_type_raw, evidence, created_at, needs_user_input, status_raw, deleted, user_id)
  on public.inbox_drafts from yala_mcp_reader;
