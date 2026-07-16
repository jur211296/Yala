-- g8_02_push_machine_role (2026-07-16, incremento G8-3 — credencial de máquina `yala_push`):
-- DECISIÓN OWNER (2026-07-16): el owner RECHAZÓ el modelo de amenaza aceptado en G8-1 ("cualquier co-member
-- puede ENUMERAR los device_tokens de sus co-members bajo demanda") y pidió la arquitectura robusta a largo
-- plazo. Esta migración implementa esa decisión:
--
--   1. Un ROL Postgres `yala_push` de scope MÍNIMO (login=false; solo `usage` sobre el schema public +
--      EXECUTE sobre exactamente 2 funciones — cero grants de tabla, sin BYPASSRLS).
--   2. Los 2 RPCs de push (`get_group_push_tokens`, `prune_push_token`) dejan de ser callables por
--      `authenticated`: se REVOCA EXECUTE de public/anon/authenticated y se OTORGA SOLO a `yala_push`.
--   3. El Worker los llama con un JWT DE MÁQUINA firmado con el legacy secret del proyecto, cuyo claim
--      `role: yala_push` hace que PostgREST/authenticator ejecute `SET ROLE yala_push` — el único rol con
--      EXECUTE. Ningún cliente `authenticated` puede ya llamarlos (recibe 403 + 42501 insufficient_privilege).
--
-- CAMBIO DE POSTURA vs G8-1 (decisión owner, supersede el §"MODELO DE AMENAZA" de g8_01_push_fanout.sql):
--   - La ENUMERACIÓN de device_tokens por co-members MUERE: los RPCs ya no son alcanzables con el JWT del
--     usuario. La divulgación aceptada en G8-1 deja de existir.
--   - El GRIEFING del prune (un co-member borrando el token de otro) MUERE por la misma razón.
--   - El fan-out deja de depender del JWT del AUTOR del push → el residual "JWT-expiry en la ventana" se cierra
--     (la credencial de máquina tiene exp de 10 años; no expira a mitad de un waitUntil).
--
-- EL INVARIANTE MULTI-SITIO se REFINA, no se rompe: "el Worker jamás posee una credencial que pueda leer
-- DATOS DE USUARIO". `yala_push` NO puede leer datos de usuario — solo EXECUTE sobre 2 funciones de
-- infraestructura de push (device tokens opacos, inertes sin la APNs Auth Key). No es service_role ni tiene
-- BYPASSRLS ni grants de tabla; su scope es exactamente esas 2 funciones.
--
-- ⚠️ DURABILIDAD DEL LEGACY SECRET (AJUSTE review #5): el JWT de máquina se firma HS256 con el LEGACY JWT
--   secret del proyecto (el simétrico histórico, verificado válido). El proyecto emite los JWT de USUARIO con
--   ES256/JWKS (asimétrico). Si el owner algún día COMPLETA la rotación de firmas y REVOCA el legacy secret,
--   PostgREST dejará de aceptar este JWT de máquina → el fan-out morirá EN SILENCIO (401 best-effort; la
--   cadencia de pull cubre el sync — SIN pérdida de datos, pero el push se apaga invisible). El canario
--   observable ya existe: el `console.log("[groups-fanout] … upstream ${status} …")` del fan-out — un 401
--   recurrente ahí = legacy secret revocado → re-acuñar el JWT con el signing key vigente (mint-push-role-jwt.mjs)
--   y `wrangler secret put PUSH_ROLE_JWT`.
--
-- =====================================================================================================
-- === POR QUÉ SIN GUARD DE ROL EN EL CUERPO (AJUSTE review #1, BLOQUEANTE resuelto) ===
-- =====================================================================================================
-- Estas 2 funciones son SECURITY DEFINER. DENTRO de una SECURITY DEFINER, `current_user` = OWNER de la
-- función (el rol que la creó), JAMÁS `yala_push` — y `session_user` = `authenticator` (PostgREST hace SET
-- ROLE, que NO cambia session_user). Por lo tanto un guard tipo `if current_user <> 'yala_push'` ROMPERÍA la
-- función para TODOS los callers, incluido el Worker. El único control de acceso correcto y suficiente son los
-- GRANTS: un caller sin el rol `yala_push` ni siquiera llega a EJECUTAR el cuerpo (PostgREST rechaza con 403
-- 42501 al intentar el CALL sin EXECUTE). Por eso: CERO guard de rol / `auth.uid()` dentro del cuerpo; los
-- GRANTS son el ÚNICO control (más simple, sin las trampas de current_user/session_user). Verificado por el
-- review adversarial pre-aplicación.

-- =====================================================================================================
-- 0. Rol de máquina `yala_push` — scope mínimo (idempotente).
-- =====================================================================================================
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'yala_push') then
    create role yala_push nologin;
  end if;
end $$;

-- authenticator (el rol de login de PostgREST) debe ser MIEMBRO de yala_push para poder `SET ROLE yala_push`
-- cuando el JWT trae `role: yala_push`. usage on schema public: para resolver las funciones del schema.
grant yala_push to authenticator;
grant usage on schema public to yala_push;

-- =====================================================================================================
-- 1. get_group_push_tokens — LA FIRMA CAMBIA → DROP de la vieja (text) primero (AJUSTE review #1/#6).
-- =====================================================================================================
-- Firma nueva: (p_group_id text, p_exclude_user_id uuid, p_exclude_device_token text default null).
-- Sin `auth.uid()` ni guard de rol (grants-only). Filtro: members ACTIVOS no-deleted del grupo con user_id
-- no nulo. Exclusión del emisor:
--   - p_exclude_device_token NON-NULL → excluye SOLO el par (p_exclude_user_id, ese token); los DEMÁS devices
--     del autor SÍ entran → cierra el residual multi-device del autor de G8-1 (el 2º device del autor recibe
--     el silent push).
--   - p_exclude_device_token NULL → fallback G8-1: excluye TODOS los tokens de p_exclude_user_id.
drop function if exists public.get_group_push_tokens(text);

create or replace function public.get_group_push_tokens(
  p_group_id text,
  p_exclude_user_id uuid,
  p_exclude_device_token text default null
)
returns table(user_id uuid, device_token text, platform text)
language plpgsql security definer stable set search_path = public as $$
begin
  -- Sin guard de auth/rol: los GRANTS (EXECUTE solo a yala_push) son el control. Las columnas OUT se
  -- qualifican con alias en el select para no colisionar con los nombres de parámetro de salida.
  return query
    select pt.user_id, pt.device_token, pt.platform
    from push_tokens pt
    join group_members gm on gm.user_id = pt.user_id and gm.group_id = p_group_id
    where gm.user_id is not null
      and gm.deleted = false
      and gm.status = 'active'          -- pendingApproval EXCLUIDO (no es writer → no ve contenido)
      and case
            when p_exclude_device_token is not null
              -- excluir SOLO el device emisor; los otros devices del autor SÍ entran (multi-device cerrado)
              then not (pt.user_id = p_exclude_user_id and pt.device_token = p_exclude_device_token)
            else
              -- fallback G8-1: excluir TODOS los devices del autor
              pt.user_id <> p_exclude_user_id
          end;
end $$;

-- AJUSTE review #4 (load-bearing): CREATE FUNCTION otorga EXECUTE a PUBLIC por DEFAULT y `authenticated` es
-- miembro de PUBLIC → el REVOKE debe nombrar `public` EXPLÍCITO (además de anon/authenticated) y correr
-- DESPUÉS del CREATE (molde g8_01:77). GRANT EXECUTE SOLO a `yala_push`.
revoke all on function public.get_group_push_tokens(text, uuid, text) from public, anon, authenticated;
grant execute on function public.get_group_push_tokens(text, uuid, text) to yala_push;

-- =====================================================================================================
-- 2. prune_push_token — la firma NO cambia (AJUSTE review #6): create or replace (sin DROP). Cuerpo sin
--    guard de radio ni auth.uid() (grants-only) — el radio de G8-1 protegía contra callers `authenticated`
--    maliciosos; ahora SOLO yala_push (el Worker, infraestructura confiable) puede llamarla.
-- =====================================================================================================
create or replace function public.prune_push_token(p_user_id uuid, p_device_token text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_deleted integer;
begin
  delete from push_tokens where user_id = p_user_id and device_token = p_device_token;
  get diagnostics v_deleted = row_count;
  return jsonb_build_object('pruned', v_deleted);
end $$;

revoke all on function public.prune_push_token(uuid, text) from public, anon, authenticated;
grant execute on function public.prune_push_token(uuid, text) to yala_push;

notify pgrst, 'reload schema';

-- Nota kill-safe (AJUSTE #5 del diseño): si esta migración corre y el Worker VIEJO (que aún llama los RPCs con
-- el JWT del autor) sigue desplegado un instante, el fan-out fallará silencioso (403 42501, best-effort,
-- console.log) — SIN pérdida (la cadencia de pull cubre). El deploy del Worker nuevo va inmediatamente después.
