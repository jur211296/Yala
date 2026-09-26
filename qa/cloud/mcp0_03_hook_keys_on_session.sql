-- mcp0_03_hook_keys_on_session (2026-09-26, review adversarial — SOLO STAGING)
--
-- QUÉ HACE. El hook deja de decidir solo por el claim `client_id` y decide por el cliente OAuth de la SESIÓN
-- (`auth.sessions.oauth_client_id`). Así, TODO token emitido para una sesión del cliente del Worker sale con
-- `role = yala_mcp_reader`, no solo el primero.
--
-- POR QUÉ. Lo cazó la review (2026-09-26). GoTrue reemite un token para la MISMA sesión al verificar un factor MFA
-- (`updateMFASessionAndClaims` en `internal/api/token.go:380`), y esa reemisión NO lleva el claim `client_id`. Con
-- el hook de `mcp0_02`, que miraba el claim, ese token salía con `role = authenticated`: escribe todo. Con el Worker
-- comprometido —que tiene la sesión de solo lectura— alguien haría enroll+verify de un TOTP y tendría un token que
-- borra las finanzas. Mirar la sesión, y no el claim, lo cierra para el MFA y para cualquier otro camino futuro que
-- reemita un token sin `client_id`.
--
-- EL HOOK PASA A LEER `auth.sessions`, y eso es un cambio respecto a mcp0_01/02, que no leían nada. Es aceptable:
-- GoTrue ya lee esa tabla en cada petición autenticada, así que el hook no añade una dependencia nueva. Si esa
-- lectura fallara, el hook fallaría y GoTrue no emitiría el token: falla CERRADO. El `session_id` de un token lo pone
-- GoTrue y siempre es un uuid; aun así, se comprueba su forma antes de castear, para que un claim raro no rompa un
-- login por una excepción de cast. `supabase_auth_admin` (quien invoca el hook) tiene SELECT sobre `auth.sessions`.
--
-- Guarda: solo se aplica sobre el cuerpo de mcp0_02 o sobre sí misma.
--
-- PRODUCCIÓN: NO. En producción, con el id del cliente de producción. Marcha atrás: mcp0_03_rollback.sql (vuelve a
-- mcp0_02).

do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null or cur not in ('ab0f247643cc82fa54a18079579f733a', '0a03fb943169e9fcee294fca49710398') then
    raise exception 'mcp0_03: el hook no es el de mcp0_02 (md5 %). No se toca.', cur;
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
