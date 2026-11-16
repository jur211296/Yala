-- web1_01_bandeja_y_sesiones (2026-11-14, lote 1 de Yala web — SOLO STAGING)
--
-- QUÉ HACE. Tres cosas, todas aditivas:
--   1. El rol de solo lectura (`yala_mcp_reader`, de mcp0_01) puede leer de `inbox_drafts` SOLO las columnas que enseña
--      la Bandeja de la web (`webapp/src/worker/data.ts`, `INBOX_COLUMNS`, más las de los filtros), con la misma política
--      que sus otras 9 tablas: solo las filas propias. Nada de `raw_text` (lo que dictó o fotografió la persona): el rol
--      lo comparte el conector de Claude, que no tiene ninguna herramienta que lo lea y no tiene por qué poder.
--   2. `yala_web_close_session(p_session_id)`: cierra UNA sesión de Supabase de la web a distancia («Navegadores
--      conectados» en el iPhone y «Sesiones» en la web). Solo borra sesiones del cliente OAuth de la web Y de quien
--      llama (`auth.uid()`): con un id ajeno o de otro cliente no hace nada y devuelve false. Y solo la puede usar la
--      app (token sin `client_id`) o la propia web: con un token del conector de Claude, que comparte rol, no hace
--      nada. Borrar la fila de `auth.sessions` borra en cascada sus refresh tokens, y `GET /auth/v1/user` deja de
--      aceptar sus tokens al momento.
--   3. El barrido diario de sesiones huérfanas del cliente web (el análogo de mcp0_04 para el conector): una sesión web
--      que caduca en el KV deja viva su sesión de Supabase (de solo lectura, y nadie tiene su refresh). Umbrales: un día
--      sobre los topes de la web (30 días sin uso, 90 desde que se entró; `webapp/src/worker/session.ts`).
--
-- PRODUCCIÓN: NO. Con el id del cliente web de producción, cuando exista. Marcha atrás: web1_01_rollback.sql.

-- 1 · La Bandeja en lectura ----------------------------------------------------------------------------------------
revoke select on public.inbox_drafts from yala_mcp_reader;
grant select (sync_id, note, amount, date, cached_currency_code, cached_account_name, cached_subcategory_name,
  source_type_raw, evidence, created_at, needs_user_input, status_raw, deleted, user_id)
  on public.inbox_drafts to yala_mcp_reader;
drop policy if exists mcp_reader_select_own on public.inbox_drafts;
create policy mcp_reader_select_own on public.inbox_drafts
  for select to yala_mcp_reader using ((select auth.uid()) = user_id);

-- 2 · Cerrar una sesión web a distancia ----------------------------------------------------------------------------
create or replace function public.yala_web_close_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  web_client constant uuid := '03e0f13b-818f-4a93-8e69-701ea6343fda';
  caller uuid := (select auth.uid());
  caller_client text := coalesce((select auth.jwt()) ->> 'client_id', '');
  n integer;
begin
  if caller is null or p_session_id is null then
    return false;
  end if;
  -- La app (sin cliente OAuth) o la web. El conector de Claude comparte el rol de lectura y no cierra nada.
  if caller_client <> '' and caller_client <> web_client::text then
    return false;
  end if;
  delete from auth.sessions s
  where s.id = p_session_id
    and s.user_id = caller
    and s.oauth_client_id = web_client;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

revoke execute on function public.yala_web_close_session(uuid) from public, anon;
grant execute on function public.yala_web_close_session(uuid) to authenticated, yala_mcp_reader;

-- 3 · Barrido diario de sesiones web huérfanas ---------------------------------------------------------------------
create extension if not exists pg_cron;

create or replace function public.yala_web_sweep_sessions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  web_client constant uuid := '03e0f13b-818f-4a93-8e69-701ea6343fda';
  n integer;
begin
  delete from auth.sessions s
  where s.oauth_client_id = web_client
    and (
      greatest(s.created_at, coalesce(s.updated_at, s.created_at), coalesce(s.refreshed_at at time zone 'UTC', s.created_at))
        < now() - interval '31 days'
      or s.created_at < now() - interval '91 days'
    );
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke execute on function public.yala_web_sweep_sessions() from anon, authenticated, public;

select cron.schedule('yala-web-sweep-sessions', '27 4 * * *', 'select public.yala_web_sweep_sessions()');
