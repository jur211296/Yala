-- mcp0_01_readonly_role (2026-09-26, fase 0 del plugin de Yala para Claude — SOLO STAGING)
--
-- QUÉ HACE. Un token que Supabase emite a un cliente OAuth (Claude) sale con el claim `client_id`. El hook de
-- abajo le cambia `role` de `authenticated` a `yala_mcp_reader`, y PostgREST hace `SET ROLE yala_mcp_reader` al
-- recibirlo. Ese rol solo puede LEER, y solo sus propias filas, en las 9 tablas que usa el MCP.
--
-- POR QUÉ UN ROL Y NO POLÍTICAS RESTRICTIVE. `authenticated` tiene INSERT/UPDATE en 20 tablas y EXECUTE en 11
-- funciones SECURITY DEFINER que escriben (`delete_personal_account`, `create_group`, `join_group`…). Una
-- política por tabla no alcanza a esas funciones: corren como su dueño. Un rol sin esos GRANTS no llega ni a
-- ejecutarlas. Es el molde de `yala_push` (g8_02).
--
-- ES ADITIVO. No modifica ninguna política, función ni GRANT existente: crea un rol, 9 políticas SELECT para ese
-- rol y una función de hook. Marcha atrás: mcp0_01_rollback.sql.
--
-- LO QUE ESTE FICHERO NO HACE. Activar el hook. Eso es configuración de Auth (Management API,
-- `hook_custom_access_token_enabled` + `_uri`), no DDL; en staging se activó el 2026-09-26, ANTES que el servidor
-- OAuth (ver tickets/done/claude-mcp-activate-oauth-in-staging.md). Mientras el hook esté apagado, los tokens de Claude salen
-- con `role = authenticated` y el MCP los rechaza (falla cerrado, ver mcp/src/auth.ts).
--
-- PRODUCCIÓN: NO. Este fichero no se aplica a `kefvaiymtgytemwbltlz` hasta la fase 1, y por el runbook.

-- 1. Rol de solo lectura (idempotente). nologin: solo se entra por SET ROLE desde authenticator.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'yala_mcp_reader') then
    create role yala_mcp_reader nologin;
  end if;
end $$;

grant yala_mcp_reader to authenticator;
grant usage on schema public to yala_mcp_reader;

-- 2. SELECT sobre las 9 tablas que lee el MCP, y ninguna escritura.
grant select on public.accounts, public.tx_items, public.categories, public.subcategories, public.tags,
  public.budgets, public.scheduled_payments, public.user_preferences, public.exchange_rates
  to yala_mcp_reader;

-- 3. Una política SELECT por tabla, para este rol. Las existentes son `to authenticated` (o public) y no se tocan.
do $$
declare t text;
begin
  foreach t in array array['accounts','tx_items','categories','subcategories','tags','budgets',
                           'scheduled_payments','user_preferences','exchange_rates'] loop
    execute format('drop policy if exists mcp_reader_select_own on public.%I', t);
    execute format(
      'create policy mcp_reader_select_own on public.%I for select to yala_mcp_reader using ((select auth.uid()) = user_id)',
      t);
  end loop;
end $$;

-- 4. El hook. Se decide por `client_id`: solo lo llevan los tokens emitidos a un cliente OAuth. Se mira en los
--    claims y en la raíz del evento, porque la documentación de Supabase lo enseña en los dos sitios.
--    El login de la app (SIWA/Google nativo, contraseña de los tests) no lleva `client_id` y sale intacto.
--    `stable` y sin lecturas: si este hook falla, falla TODO login del proyecto, así que no puede depender de nada.
create or replace function public.yala_mcp_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  cid text := coalesce(nullif(claims->>'client_id', ''), nullif(event->>'client_id', ''));
begin
  if cid is not null then
    claims := jsonb_set(claims, '{role}', to_jsonb('yala_mcp_reader'::text));
  end if;
  return jsonb_build_object('claims', claims);
end;
$$;

-- Lo invoca Auth como supabase_auth_admin. Nadie más: si no, sería un RPC expuesto en PostgREST.
grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;
