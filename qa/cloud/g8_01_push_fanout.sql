-- g8_01_push_fanout (2026-07-16, incremento G8-1 — APNs server-side, fan-out de silent push):
-- 2 RPCs de soporte del fan-out de push del canal Grupos→backend. `push_tokens` YA EXISTE (DDL contrato
-- :247-260, PK (user_id, device_token), RLS per-user) — este archivo NO la recrea.
--
--   1. `get_group_push_tokens(p_group_id)` — devuelve los device tokens de los CO-MEMBERS ACTIVOS del
--      grupo (excluyendo al caller). Lo llama el fan-out con el JWT del AUTOR del push, tras aplicar un
--      delta, para saber a quién despertar con un silent push (`content-available:1`).
--   2. `prune_push_token(p_user_id, p_device_token)` — borra el PAR EXACTO. Lo llama el fan-out cuando
--      APNs devuelve `BadDeviceToken`/`Unregistered` (best-effort; el re-registro por boot auto-sana).
--
-- Rieles (molde de los RPCs de grupos, supabase-groups-staging.ddl §2): SECURITY DEFINER + `set search_path
-- = public`; guard `auth.uid() is null → yala_not_authorized` PRIMERO; errores SANITIZADOS `yala_*` (errcode
-- P0001) que JAMÁS interpolan inputs; grants REVOKE public/anon + GRANT authenticated (molde claim_account /
-- migrate_group). El Worker JAMÁS usa service_role — reenvía el JWT del usuario; la RLS de push_tokens +
-- estos guards arbitran. server_seq/HLC no aplican (push_tokens no es tabla de sync — sin trigger de seq).
--
-- =====================================================================================================
-- === MODELO DE AMENAZA REAL de get_group_push_tokens (decisión de sesión — RATIFICAR por owner) ===
-- =====================================================================================================
-- PostgREST expone TODA función con EXECUTE-a-authenticated en `/rest/v1/rpc/<fn>` a cualquier usuario
-- autenticado. Como este RPC solo exige `is_group_member(p_group_id)` del caller, la consecuencia es:
-- **cualquier co-member de un grupo puede ENUMERAR los device_tokens de sus co-members de ESE grupo, bajo
-- demanda** (acotado a los grupos que comparte). Esto es ESTRUCTURAL con el invariante multi-sitio "el
-- Worker jamás usa service_role" (no hay forma de que solo el Worker llame al RPC — el JWT del usuario es
-- el único transporte, y el usuario lo posee).
--   Impacto ACOTADO y ACEPTADO: un device token APNs NO permite enviar pushes sin la APNs Auth Key del
--   developer (secret server-side) — un token filtrado es inerte para un tercero. El único abuso práctico
--   con las primitivas expuestas es el PRUNE de un token co-member (ver el residual de griefing abajo).
--   La divulgación (un co-member sabe QUÉ tokens tienen sus co-members, sin poder usarlos) queda aceptada
--   y documentada. Endurecer esto exigiría romper el invariante de service_role o un attestation por
--   request — fuera de v1.
--
-- === pendingApproval EXCLUIDO (AJUSTE review #5) ===
-- El fan-out solo apunta a `status = 'active'`. Un member `pendingApproval` NO es `is_group_writer` → su
-- RLS no le deja leer el CONTENIDO del grupo; despertarlo con un silent push de "hay contenido nuevo"
-- dispararía un pull que no puede materializar nada → ruido + batería. Su meta (la rara que sí ve) la
-- cubre la CADENCIA de pull, no el push. Por eso el fan-out lo omite.
--
-- === RESIDUAL multi-device del AUTOR (AJUSTE review #6, aceptado v1) ===
-- `gm.user_id <> auth.uid()` excluye TODOS los devices del propio autor (el que escribió el delta). Si el
-- autor tiene un SEGUNDO device, ese device NO recibe el silent push y espera a la cadencia de pull. En la
-- era CloudKit el push llegaba per-device (incluido el otro device del autor). Se acepta como residual v1:
-- el costo es latencia (segundos-minutos de cadencia) en el segundo device del mismo usuario, no pérdida
-- de datos. Reintroducir el self-push exigiría un `sender_device_id` en el wire para excluir solo el
-- device emisor — diferido.

-- =====================================================================================================
-- 1. get_group_push_tokens — tokens de los co-members ACTIVOS del grupo (excluye al caller).
-- =====================================================================================================
-- plpgsql (no SQL puro) para poder RAISE el guard sanitizado: auth.uid() null O caller no-member →
-- yala_not_authorized (nunca "leak by empty result" ambiguo). Las columnas OUT se qualifican con alias en
-- el select para no colisionar con los nombres de parámetro de salida.
create or replace function public.get_group_push_tokens(p_group_id text)
returns table(user_id uuid, device_token text, platform text)
language plpgsql security definer stable set search_path = public as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  -- Membership del CALLER (no del target): sin esto un authenticated cualquiera enumeraría tokens de un
  -- grupo ajeno pasando su group_id. is_group_member es SECURITY DEFINER stable (usa auth.uid()).
  if not is_group_member(p_group_id) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  return query
    select pt.user_id, pt.device_token, pt.platform
    from push_tokens pt
    join group_members gm on gm.user_id = pt.user_id and gm.group_id = p_group_id
    where gm.user_id is not null
      and gm.user_id <> v_uid          -- excluye TODOS los devices del autor (residual multi-device)
      and gm.deleted = false
      and gm.status = 'active';         -- pendingApproval EXCLUIDO (no es writer → no ve contenido)
end $$;

revoke all on function public.get_group_push_tokens(text) from public, anon;
grant execute on function public.get_group_push_tokens(text) to authenticated;

-- =====================================================================================================
-- 2. prune_push_token — borra el PAR EXACTO (user_id, device_token). Best-effort del fan-out.
-- =====================================================================================================
-- SECURITY DEFINER: corre como owner de la función (bypassa la RLS delete `user_id=auth.uid()` de
-- push_tokens) → puede borrar el token de OTRO usuario. Por eso el GUARD DE RADIO (AJUSTE review #2b):
-- permitir SOLO si `p_user_id = auth.uid()` O el caller comparte un grupo ACTIVO con p_user_id — bloquea
-- borrar tokens de no-co-members.
--   RESIDUAL de griefing ACEPTADO: un co-member SÍ puede borrar el token de otro co-member (dentro del
--   radio). El daño es que ese member deja de recibir silent pushes hasta su próximo boot — el
--   re-registro por boot (PushTokenRegistrar.attemptUpload) lo AUTO-SANA, y sin-push ≠ sin-sync (la
--   cadencia de pull sigue). Blast-radius mínimo, auto-curable.
create or replace function public.prune_push_token(p_user_id uuid, p_device_token text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := (select auth.uid());
  v_deleted integer;
begin
  if v_uid is null then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  -- Guard de radio: dueño del token, o co-member de un grupo activo compartido con p_user_id.
  if p_user_id <> v_uid and not exists (
    select 1
    from group_members gm1
    join group_members gm2 on gm2.group_id = gm1.group_id
    where gm1.user_id = v_uid      and gm1.deleted = false and gm1.status = 'active'
      and gm2.user_id = p_user_id  and gm2.deleted = false and gm2.status = 'active'
  ) then
    raise exception 'yala_not_authorized' using errcode = 'P0001';
  end if;
  delete from push_tokens where user_id = p_user_id and device_token = p_device_token;
  get diagnostics v_deleted = row_count;
  return jsonb_build_object('pruned', v_deleted);
end $$;

revoke all on function public.prune_push_token(uuid, text) from public, anon;
grant execute on function public.prune_push_token(uuid, text) to authenticated;

notify pgrst, 'reload schema';
