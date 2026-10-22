-- mcp0_03_rollback — deshace mcp0_03_hook_keys_on_session (SOLO STAGING): el hook vuelve a decidir por el claim
-- `client_id` (cuerpo de mcp0_02, md5 ab0f247643cc82fa54a18079579f733a).
--
-- OJO: con esto vuelve el hueco de la review — un token reemitido tras verificar MFA sale con role=authenticated.
-- Solo tiene sentido si se revierte también el Worker y se apaga MFA de otra forma.

do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null or cur not in ('0a03fb943169e9fcee294fca49710398', 'ab0f247643cc82fa54a18079579f733a') then
    raise exception 'mcp0_03_rollback: el hook no es el de mcp0_03 ni el de mcp0_02 (md5 %). No se toca.', cur;
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

grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;
