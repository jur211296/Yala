-- tel01_stats_counts (2026-11-06, telemetría propia · decisión 5: «Grupos, Nube y Pro se cuentan desde el servidor»).
--
-- El panel (`panel/`, Worker aparte del gateway) pide cada día UNOS CUANTOS NÚMEROS de la base: cuántos grupos hay y
-- cuántos tuvieron movimiento, cuántas invitaciones se usaron, cuántas cuentas tienen sus finanzas en la nube. Nada por
-- persona: la función devuelve un solo objeto JSON de conteos.
--
-- Molde `yala_push` (g8_02_push_machine_role.sql), con el mismo razonamiento:
--   1. Un rol de máquina `yala_stats` (nologin) con `usage` sobre `public` y EXECUTE sobre UNA función. Cero grants de
--      tabla, sin BYPASSRLS. No puede leer datos de usuario: solo llamar a `yala_stats_counts()`, que devuelve números.
--   2. La función es SECURITY DEFINER (necesita contar filas que RLS esconde) y SIN guard de rol en el cuerpo: dentro de
--      una SECURITY DEFINER `current_user` es el dueño, así que el único control correcto son los GRANTS (ver §«POR QUÉ
--      SIN GUARD» de g8_02).
--   3. El panel la llama con un JWT de máquina firmado con el legacy secret del proyecto y claim `role: yala_stats`
--      (`panel/scripts/mint-stats-role-jwt.mjs`). Mismo riesgo de durabilidad que `PUSH_ROLE_JWT`: si se revoca el
--      legacy secret, el conteo deja de llegar (el panel lo dice: «sin datos de la base»), sin tocar nada más.
--
-- Qué cuenta (todo excluye tombstones `deleted = true`):
--   groups_total          grupos vivos y no archivados
--   groups_active_7d      grupos con un gasto creado o una liquidación tocada en los últimos 7 días
--   groups_new_7d         grupos creados en los últimos 7 días
--   members_active        miembros con status 'active' y cuenta (user_id no nulo)
--   members_joined_7d     de ellos, los que entraron en los últimos 7 días
--   invites_created_7d    invitaciones creadas en los últimos 7 días
--   invites_used_7d       de ellas, las que alguien usó (uses > 0)
--   expenses_7d           gastos compartidos creados en los últimos 7 días
--   accounts_complete     cuentas con sus finanzas personales en la nube (profiles.kind = 'complete')
--   accounts_groups_only  cuentas solo de Grupos
--   push_devices          teléfonos con token de avisos registrado
--
-- Aplicar: staging primero (proyecto fostjbbwstyuunmmefuk), luego producción (kefvaiymtgytemwbltlz). Rollback:
-- tel01_rollback.sql. Idempotente.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'yala_stats') then
    create role yala_stats nologin;
  end if;
end $$;

grant yala_stats to authenticator;
grant usage on schema public to yala_stats;

create or replace function public.yala_stats_counts()
returns jsonb
language sql security definer stable set search_path = public as $$
  select jsonb_build_object(
    'groups_total',        (select count(*) from split_groups where not deleted and coalesce(is_archived, false) = false),
    'groups_active_7d',    (select count(distinct g) from (
                              select group_id as g from split_expenses
                               where not deleted and created_at >= now() - interval '7 days'
                              union
                              select group_id from split_settlements  -- sin created_at: cuenta el último cambio
                               where not deleted and updated_at >= now() - interval '7 days'
                            ) a),
    'groups_new_7d',       (select count(*) from split_groups where not deleted and created_at >= now() - interval '7 days'),
    'members_active',      (select count(*) from group_members where not deleted and status = 'active' and user_id is not null),
    'members_joined_7d',   (select count(*) from group_members where not deleted and status = 'active' and user_id is not null
                              and joined_at >= now() - interval '7 days'),
    'invites_created_7d',  (select count(*) from group_invites where created_at >= now() - interval '7 days'),
    'invites_used_7d',     (select count(*) from group_invites where created_at >= now() - interval '7 days' and uses > 0),
    'expenses_7d',         (select count(*) from split_expenses where not deleted and created_at >= now() - interval '7 days'),
    'accounts_complete',   (select count(*) from profiles where kind = 'complete'),
    'accounts_groups_only',(select count(*) from profiles where kind = 'groups_only'),
    'push_devices',        (select count(distinct device_token) from push_tokens)
  );
$$;

revoke all on function public.yala_stats_counts() from public, anon, authenticated;
grant execute on function public.yala_stats_counts() to yala_stats;

-- Comprobación tras aplicar (como dueño): debe devolver un objeto con las 11 claves.
--   select public.yala_stats_counts();
-- Y con el JWT de un usuario normal, PostgREST debe responder 403 / 42501:
--   curl -X POST "$SUPABASE_URL/rest/v1/rpc/yala_stats_counts" -H "apikey: $ANON" -H "Authorization: Bearer $USER_JWT"
