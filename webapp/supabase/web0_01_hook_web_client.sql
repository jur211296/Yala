-- web0_01_hook_web_client (2026-11-13, lote 0 de Yala web — SOLO STAGING)
--
-- QUÉ HACE. El hook de token de Supabase (`yala_mcp_access_token_hook`, de mcp0_03) reconoce un SEGUNDO cliente OAuth:
-- «Yala web (staging)» (`03e0f13b-…`, confidencial, registrado el 2026-11-13). Sus tokens salen con
-- `role = yala_mcp_reader`, igual que los del conector de Claude: la web lee y no puede escribir (decisión D8 de
-- docs/web-app/index.html). Todo lo demás del hook queda igual: decide por el cliente de la SESIÓN (mcp0_03), el login
-- normal de la app no cambia, y cualquier otro cliente OAuth sigue sin token (403).
--
-- POR QUÉ AQUÍ Y NO EN qa/cloud/. El encargo del lote 0 se queda dentro de `webapp/`. Si se mueve, que se mueva con su
-- marcha atrás y su md5.
--
-- Guarda: solo se aplica sobre el cuerpo de mcp0_03 o sobre sí misma.
-- Medido al aplicar (2026-11-13): md5 antes 0a03fb943169e9fcee294fca49710398 → después, el que anota el README de
-- webapp/ (sección «Supabase staging»).
--
-- PRODUCCIÓN: NO. En producción, con los ids de producción y después del runbook del conector. Marcha atrás:
-- web0_01_rollback.sql (vuelve al cuerpo de mcp0_03).

do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null or cur not in ('0a03fb943169e9fcee294fca49710398', '120f45468bc1db690a4c5655e7a7d48c') then
    raise exception 'web0_01: el hook no es el de mcp0_03 (md5 %). No se toca.', cur;
  end if;
end $$;

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
  -- El cliente OAuth persiste en la sesión. Un token reemitido para ella (p. ej. tras verificar MFA) no trae el
  -- claim client_id, pero la sesión sigue siendo del mismo cliente: por eso se mira la sesión. Solo se lee si el
  -- session_id tiene forma de uuid, para no romper un login por un cast. Un fallo de la lectura propaga y GoTrue no
  -- emite el token (falla cerrado).
  if sid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select s.oauth_client_id into session_cid from auth.sessions s where s.id = sid::uuid;
  end if;

  -- Ni el claim ni la sesión traen cliente: login normal de la app. Intacto.
  if claim_cid is null and session_cid is null then
    return jsonb_build_object('claims', claims);
  end if;

  -- Es un token de un cliente OAuth. Solo el conector y Yala web reciben token, y de solo lectura.
  if claim_cid in (worker_client::text, web_client::text) or session_cid in (worker_client, web_client) then
    return jsonb_build_object('claims', jsonb_set(claims, '{role}', to_jsonb('yala_mcp_reader'::text)));
  end if;

  -- Cualquier otro cliente OAuth: sin token. GoTrue devuelve este error antes de firmar nada.
  return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', 'Este cliente no puede conectarse a Yala.'));
end;
$$;

grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;
