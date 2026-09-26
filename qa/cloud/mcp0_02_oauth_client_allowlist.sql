-- mcp0_02_oauth_client_allowlist (2026-09-26, conector de Claude — SOLO STAGING)
--
-- QUÉ HACE. Cambia el hook de mcp0_01 para que Supabase solo emita tokens OAuth a UN cliente: el del Worker del
-- conector (`65fb5767-…`, confidencial, registrado el 2026-09-26). Ese sale con `role = yala_mcp_reader`, como antes.
-- A CUALQUIER OTRO `client_id` el hook le niega el token (error 403). El login de la app, que no lleva `client_id`,
-- sale intacto.
--
-- POR QUÉ. Desde el ADR «El conector de Claude emite sus propios tokens» (docs/DECISIONS.md), Claude ya no recibe un
-- token de Supabase: se lo da el Worker. GoTrue acepta cualquier token del usuario en `/auth/v1/user*` sin mirar el
-- cliente, así que el único que puede tener uno es el Worker, que no pide nada de eso (`mcp/src/egress.ts`). Esta
-- lista lo garantiza también en Supabase: aunque alguien reencienda el DCR o reuse un cliente de la fase 0, no hay
-- token. Los 4 clientes públicos de la fase 0 siguen registrados (borrarlos exige service_role) y se quedan sin token.
--
-- ES UN CAMBIO DE UNA FUNCIÓN. No toca políticas, rol ni GRANTs. Marcha atrás: mcp0_02_rollback.sql (vuelve al
-- cuerpo de mcp0_01, md5 5a048417a612be4ceea44ee89ce969f6).
--
-- PRODUCCIÓN: NO. Allí el cliente del Worker tendrá otro id; esta migración se reescribe con él en la fase 1.

-- Guarda: solo se aplica sobre el cuerpo de mcp0_01 o sobre sí misma (re-aplicar no hace nada).
do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null or cur not in ('5a048417a612be4ceea44ee89ce969f6', 'ab0f247643cc82fa54a18079579f733a') then
    raise exception 'mcp0_02: el hook no es el de mcp0_01 (md5 %). No se toca.', cur;
  end if;
end $$;

create or replace function public.yala_mcp_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  cid text := coalesce(nullif(claims->>'client_id', ''), nullif(event->>'client_id', ''));
begin
  -- Login de la app (SIWA/Google nativo, contraseña de los tests): sin client_id, sale intacto.
  if cid is null then
    return jsonb_build_object('claims', claims);
  end if;
  -- El cliente OAuth del Worker del conector de Claude (staging): token de solo lectura en la base.
  if cid = '65fb5767-59a5-4f50-b77c-7970e67589c5' then
    return jsonb_build_object('claims', jsonb_set(claims, '{role}', to_jsonb('yala_mcp_reader'::text)));
  end if;
  -- Cualquier otro cliente OAuth: sin token. GoTrue devuelve este error antes de firmar nada.
  return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', 'Este cliente no puede conectarse a Yala.'));
end;
$$;

-- Lo invoca Auth como supabase_auth_admin. Nadie más: si no, sería un RPC expuesto en PostgREST.
grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;
