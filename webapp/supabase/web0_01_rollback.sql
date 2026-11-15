-- web0_01_rollback (2026-11-13 — SOLO STAGING)
--
-- Vuelve el hook al cuerpo de mcp0_03: solo el conector de Claude recibe token. Las sesiones de Yala web dejan de poder
-- refrescar (el hook responde 403) y la web, que exige `yala_mcp_reader`, deja de dejar entrar: falla cerrado.
--
-- Guarda: solo se aplica sobre el cuerpo de web0_01.

do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null or cur not in ('120f45468bc1db690a4c5655e7a7d48c', '0a03fb943169e9fcee294fca49710398') then
    raise exception 'web0_01_rollback: el hook no es el de web0_01 (md5 %). No se toca.', cur;
  end if;
end $$;

create or replace function public.yala_mcp_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  worker_client constant uuid := '65fb5767-59a5-4f50-b77c-7970e67589c5';
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

  -- Es un token de un cliente OAuth. Solo el del Worker recibe token, y de solo lectura.
  if claim_cid = worker_client::text or session_cid = worker_client then
    return jsonb_build_object('claims', jsonb_set(claims, '{role}', to_jsonb('yala_mcp_reader'::text)));
  end if;

  -- Cualquier otro cliente OAuth: sin token. GoTrue devuelve este error antes de firmar nada.
  return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', 'Este cliente no puede conectarse a Yala.'));
end;
$$;

grant execute on function public.yala_mcp_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.yala_mcp_access_token_hook(jsonb) from authenticated, anon, public;
