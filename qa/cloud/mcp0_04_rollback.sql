-- mcp0_04_rollback — deshace mcp0_04_sweep_connector_sessions (SOLO STAGING): quita el job y la función.
-- No desinstala pg_cron: otro job podría usarlo. Las sesiones ya barridas no vuelven (estaban sin grant que las usara).

select cron.unschedule('yala-mcp-sweep-connector-sessions')
where exists (select 1 from cron.job where jobname = 'yala-mcp-sweep-connector-sessions');

drop function if exists public.yala_mcp_sweep_connector_sessions();
