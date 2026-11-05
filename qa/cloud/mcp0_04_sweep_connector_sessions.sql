-- mcp0_04_sweep_connector_sessions (2026-11-05 — SOLO STAGING)
--
-- QUÉ HACE. Un barrido diario (pg_cron, 04:17 UTC) cierra las sesiones de Supabase del conector de Claude que ya no
-- tienen conexión viva en el Worker: las del cliente OAuth del Worker sin uso en 31 días, o con más de 91 días.
-- Borrar la fila de `auth.sessions` borra en cascada sus refresh tokens: la sesión queda cerrada igual que con logout.
--
-- POR QUÉ. Ticket `claude-mcp-revoke-from-claude-leaves-supabase-session`. Desconectar desde Claude ya cierra la sesión
-- (Worker, `revoke.ts`). Quedan dos casos sin credencial con que cerrarla, porque la sesión vive cifrada en un grant que
-- ya no existe: (1) reconectar la misma app de Claude, que retira el grant anterior, y (2) el grant que caduca en el KV
-- por 30 días sin uso o 90 desde que se autorizó. Decidido el 2026-11-05 (opción 1A de la sesión del encargo).
--
-- POR QUÉ ESOS UMBRALES. El grant del Worker muere a los 30 días sin uso (`GRANT_IDLE_SECONDS`) o a los 90 desde
-- autorizar (`GRANT_MAX_AGE_SECONDS`), ambos en `mcp/src/tokens.ts`. Mientras vive, cada refresh de Claude refresca la
-- sesión de Supabase y GoTrue mueve `refreshed_at`/`updated_at`. Una sesión sin refrescar en 31 días, o creada hace
-- más de 91, ya no tiene grant que la use: un día de margen sobre cada tope.
--
-- QUÉ NO TOCA. Solo filas con `oauth_client_id` = el cliente del Worker. Las sesiones de la app (SIWA, Google, sin
-- cliente OAuth) y las de cualquier otro cliente quedan fuera. Una sesión huérfana por reconexión vive hasta 31 días:
-- es de solo lectura (`yala_mcp_reader`) y nadie tiene su refresh.
--
-- La función no se expone: se le quita EXECUTE a anon, authenticated y public (PostgREST publica `public`).
--
-- PRODUCCIÓN: NO. Con el id del cliente de producción, por `mcp/RUNBOOK-produccion.md`. Marcha atrás:
-- mcp0_04_rollback.sql.

create extension if not exists pg_cron;

create or replace function public.yala_mcp_sweep_connector_sessions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  worker_client constant uuid := '65fb5767-59a5-4f50-b77c-7970e67589c5';
  n integer;
begin
  delete from auth.sessions s
  where s.oauth_client_id = worker_client
    and (
      greatest(s.created_at, coalesce(s.updated_at, s.created_at), coalesce(s.refreshed_at at time zone 'UTC', s.created_at))
        < now() - interval '31 days'
      or s.created_at < now() - interval '91 days'
    );
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke execute on function public.yala_mcp_sweep_connector_sessions() from anon, authenticated, public;

-- Idempotente: si el job ya existe con este nombre, cron.schedule lo reemplaza.
select cron.schedule('yala-mcp-sweep-connector-sessions', '17 4 * * *', 'select public.yala_mcp_sweep_connector_sessions()');
