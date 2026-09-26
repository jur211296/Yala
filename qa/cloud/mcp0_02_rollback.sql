-- mcp0_02_rollback — deshace mcp0_02_oauth_client_allowlist (SOLO STAGING): el hook vuelve al cuerpo de mcp0_01,
-- que da `yala_mcp_reader` a CUALQUIER cliente OAuth (md5 5a048417a612be4ceea44ee89ce969f6).
--
-- OJO: con esto, y con el DCR de Supabase encendido, cualquiera puede registrar un cliente y recibir un token que
-- cambia la cuenta (el hueco de claude-mcp-oauth-token-can-change-the-account). Revertir esto solo tiene sentido si se
-- revierte también el Worker (la versión de la fase 0) — ver docs/RUNBOOK-staging-ddl.md.

do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null or cur not in ('ab0f247643cc82fa54a18079579f733a', '5a048417a612be4ceea44ee89ce969f6') then
    raise exception 'mcp0_02_rollback: el hook no es el de mcp0_02 ni el de mcp0_01 (md5 %). No se toca.', cur;
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
  if cid is not null then
    claims := jsonb_set(claims, '{role}', to_jsonb('yala_mcp_reader'::text));
  end if;
  return jsonb_build_object('claims', claims);
end;
$$;

grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;
