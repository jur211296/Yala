-- =====================================================================================================
-- g8_03 · Audiencias de push para eventos de MEMBRESÍA
--
-- POR QUÉ EXISTE. Hasta hoy el único resolver de tokens es `get_group_push_tokens` (g8_02), que sirve a
-- un solo caso: «despierta a los co-members ACTIVOS de un grupo, menos al autor». Para los eventos de
-- membresía no vale, y no por matices — por dos huecos que lo hacen inservible:
--
--   (a) Avisar a los ADMIN de que alguien pide entrar: la función no filtra por `role` ni lo devuelve,
--       así que notificaría a TODO el grupo. Una solicitud de entrada es asunto de quien puede
--       aprobarla.
--   (b) Avisar a quien acabas de RECHAZAR o EXPULSAR: es literalmente imposible. `remove_member` deja
--       al target en `status = 'rejected'|'removed'` (ddl:596) y el `and gm.status = 'active'` del
--       resolver lo excluye por completo. La persona a la que hay que avisar es, por definición, la
--       que la función nunca devuelve.
--
-- MODELO DE AMENAZA, y por qué la segunda función NO acepta un uuid suelto. Una función «dame los
-- tokens de este usuario» sería más potente que las dos de g8_02 y su única contención serían los
-- grants. Se acota a `(p_group_id, p_member_key)`: sólo devuelve tokens de alguien que ES o FUE
-- miembro de ESE grupo, que es exactamente el conjunto sobre el que el Worker tiene algo que decir.
-- El `member_key` además no lo elige el Worker: viene del RETORNO del propio RPC de membresía.
--
-- Y se resuelve el `user_id` DENTRO de la función, no fuera: para un member legacy re-vinculado
-- (`join_group`, ddl:466-484) el `member_key` es la clave legacy y NO el uuid, así que un Worker que
-- intentara mapear key→uuid por su cuenta acertaría sólo con los members nacidos en el backend.
--
-- GRANTS: mismo trato que g8_02 — `revoke` nombrando `public` EXPLÍCITO (authenticated es miembro de
-- PUBLIC) y DESPUÉS del create; `grant` sólo a `yala_push`, el rol de máquina del fan-out.
-- =====================================================================================================

-- -----------------------------------------------------------------------------------------------------
-- 1. get_group_admin_push_tokens — audiencia «quién puede aprobar esto»
--
-- Espejo de get_group_push_tokens salvo por `and gm.role = 'admin'`. Conserva el `status = 'active'`:
-- un admin que ya no está activo no debe recibir el aviso. Y conserva la exclusión del autor, que aquí
-- es el solicitante: si además fuera admin (no puede serlo al pedir entrada, pero la función no lo
-- asume) no se avisa a sí mismo.
-- -----------------------------------------------------------------------------------------------------
create or replace function public.get_group_admin_push_tokens(
  p_group_id text,
  p_exclude_user_id uuid
)
returns table(user_id uuid, device_token text, platform text)
language plpgsql security definer stable set search_path = public as $$
begin
  return query
    select pt.user_id, pt.device_token, pt.platform
    from push_tokens pt
    join group_members gm on gm.user_id = pt.user_id and gm.group_id = p_group_id
    where gm.user_id is not null
      and gm.deleted = false
      and gm.status = 'active'
      and gm.role = 'admin'
      and pt.user_id <> p_exclude_user_id;
end $$;

revoke all on function public.get_group_admin_push_tokens(text, uuid) from public, anon, authenticated;
grant execute on function public.get_group_admin_push_tokens(text, uuid) to yala_push;

-- -----------------------------------------------------------------------------------------------------
-- 2. get_group_member_push_tokens — audiencia «esta persona concreta»
--
-- SIN filtro de `status`, y ésa es la razón de existir: el rechazado y el expulsado son justo los que
-- `get_group_push_tokens` no puede devolver. SÍ conserva `deleted = false`: una fila borrada no es un
-- miembro del que haya nada que decir.
--
-- Resuelve por `member_key` dentro de la propia función (ver la nota de arriba sobre members legacy).
-- -----------------------------------------------------------------------------------------------------
create or replace function public.get_group_member_push_tokens(
  p_group_id text,
  p_member_key text
)
returns table(user_id uuid, device_token text, platform text)
language plpgsql security definer stable set search_path = public as $$
begin
  return query
    select pt.user_id, pt.device_token, pt.platform
    from push_tokens pt
    join group_members gm on gm.user_id = pt.user_id
    where gm.group_id = p_group_id
      and gm.member_key = p_member_key
      and gm.user_id is not null
      and gm.deleted = false;
end $$;

revoke all on function public.get_group_member_push_tokens(text, text) from public, anon, authenticated;
grant execute on function public.get_group_member_push_tokens(text, text) to yala_push;
