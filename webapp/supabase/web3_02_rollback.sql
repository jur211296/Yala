-- Marcha atrás de web3_02_grupos_escritura (SOLO STAGING). Deja a la web otra vez de solo lectura en Grupos.
-- Orden: primero el hook (los tokens nuevos vuelven a `yala_mcp_reader`), después lo que añadía el rol, y el rol al
-- final. Un token `yala_web` ya emitido deja de servir cuando el rol desaparece (PostgREST no puede entrar con él): hasta
-- que caduca (como mucho una hora; la web renueva 60 s antes) sus lecturas fallan con 503 y la página pide reintentar.
-- Para no esperar, quitar `yala_web` de `WEB_ROLES` (`webapp/src/worker/verify.ts`) y desplegar: la web cierra esas
-- sesiones y se vuelve a entrar.

create or replace function public.yala_mcp_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  worker_client constant uuid := '65fb5767-59a5-4f50-b77c-7970e67589c5';
  web_client constant uuid := '03e0f13b-818f-4a93-8e69-701ea6343fda';
  claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  claim_cid text := nullif(claims->>'client_id', '');
  sid text := nullif(claims->>'session_id', '');
  session_cid uuid;
begin
  if sid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select s.oauth_client_id into session_cid from auth.sessions s where s.id = sid::uuid;
  end if;
  if claim_cid is null and session_cid is null then
    return jsonb_build_object('claims', claims);
  end if;
  if claim_cid in (worker_client::text, web_client::text) or session_cid in (worker_client, web_client) then
    return jsonb_build_object('claims', jsonb_set(claims, '{role}', to_jsonb('yala_mcp_reader'::text)));
  end if;
  return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', 'Este cliente no puede conectarse a Yala.'));
end;
$$;
grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;

drop function if exists public.web_add_group_row(text, text, uuid, jsonb, jsonb, text, text);
drop function if exists public.web_add_group_expense(text, uuid, jsonb, jsonb, jsonb, text, text);
drop function if exists public.web_add_group_settlement(text, uuid, jsonb, jsonb, text, text);
drop function if exists public.web_group_active_member(text, text);
drop function if exists public.web_group_write_guard(text);
drop policy if exists web_writer_insert on public.split_expenses;
drop policy if exists web_writer_insert on public.split_shares;
drop policy if exists web_writer_insert on public.split_settlements;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'yala_web') then
    revoke insert on public.split_expenses, public.split_shares, public.split_settlements from yala_web;
    revoke execute on function public.apply_group_delta(text, text, uuid, text, jsonb, jsonb, text, text, integer) from yala_web;
    revoke execute on function public.create_group_invite(text, integer, integer) from yala_web;
    revoke usage on schema public, auth, extensions from yala_web;
    revoke yala_mcp_reader from yala_web;
    revoke yala_web from authenticator;
    drop role yala_web;
  end if;
end $$;
