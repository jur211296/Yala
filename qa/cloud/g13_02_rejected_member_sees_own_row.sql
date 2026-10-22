-- =====================================================================================================
-- g13_02 · Quien fue RECHAZADO puede leer SU PROPIA fila de membresía (y solo la suya)
--
-- QUÉ LE PASA AL USUARIO HOY. Pide entrar a un grupo por un enlace, el admin le dice que no, y el grupo
-- DESAPARECE de su lista sin una palabra. Parece que la app se rompió o que el enlace nunca sirvió.
-- El copy del aviso existe desde hace tiempo en los 16 idiomas (`groups.invite.rejected.*`) y el cliente
-- sabe pintarlo: lo único que falta es que el dato llegue al teléfono.
--
-- POR QUÉ NO BASTABA CON TOCAR EL GATEWAY, que es lo que decía el ticket. La policy de SELECT de
-- `group_members` es `is_group_member(group_id)`, y ese helper exige `status in
-- ('active','pendingApproval')`. En cuanto la fila pasa a `rejected`, quien la posee deja de poder leer
-- NINGUNA fila de ese grupo — ni la suya. La RLS lo bloquea por sí sola, así que cambiar el filtro del
-- Worker no habría movido una sola pantalla.
--
-- Y LA CORRECCIÓN APARENTE ES LA PELIGROSA. Añadir `rejected` a `is_group_member` habría dejado al
-- rechazado leer TODAS las filas de `group_members` de ese grupo, porque la policy es por GRUPO, no por
-- fila: vería la lista completa de miembros de un grupo al que no le dejaron entrar. Ese es el oráculo
-- que el owner descartó explícitamente el 2026-09-03. Por eso el helper NO se toca: se añade una policy
-- nueva, y su `using` nombra las dos condiciones que la acotan —`user_id` propio Y `status = 'rejected'`.
--
-- POR QUÉ ES SEGURO AMPLIAR ESTE SELECT, medido en producción el 2026-09-03:
--   · Las policies permisivas de SELECT se combinan con OR, y en esta tabla solo hay dos (ninguna
--     restrictiva) ⇒ esto SUMA un caso, no relaja el que ya había.
--   · `authenticated` tiene SOLO `select` sobre `group_members` (el `update` se revocó con el freeze de
--     la unidad de membresía) ⇒ ampliar la lectura no abre ninguna escritura.
--   · `is_group_member` lo usan exactamente dos policies (`group_members_select` y `split_groups_select`)
--     y ninguna vista lo nombra ⇒ al no tocarlo, nada más cambia de comportamiento.
--   · Los cinco lectores del pull (`groups_pull_rows_*`) son SECURITY INVOKER ⇒ filtran fila a fila con
--     la RLS de quien llama. No hay puerta trasera que devuelva de más.
--
-- EL «UNA SOLA VEZ» NO LO DA ESTA POLICY, y conviene no confundirlo: una policy no tiene memoria, deja
-- la fila legible siempre. Lo da el cursor: `group_members_stamp` sella un `server_seq` nuevo en el
-- UPDATE de `remove_member` y los lectores filtran `server_seq > p_after_seq`, así que la transición
-- viaja en la primera página que la alcance y no vuelve. Corolario: si el cursor se resetea
-- (reinstalación), el aviso se entrega otra vez — asumido, y es la razón de que descartarlo sea LOCAL.
--
-- FRONTERA DELIBERADA: solo `rejected`, no `removed`. `remove_member` deja `rejected` si el objetivo
-- estaba pendiente y `removed` si estaba activo. A quien EXPULSAN de un grupo le sigue desapareciendo en
-- silencio, exactamente como hoy. Cerrarlo aquí sería una línea (`status in ('rejected','removed')`),
-- pero necesita copy nuevo y decidir qué se le dice a alguien a quien han sacado, que no es lo mismo que
-- un «no te aceptaron». Decisión del owner del 2026-09-03: ahora no.
--
-- BORRADO DE CUENTA: el camino RGPD queda cerrado sin tocar nada. `groups_forget_user` anonimiza las
-- filas del que se borra (`user_id = null`, status `removed`), así que dejan de casar este `using` por sí
-- solas.
-- =====================================================================================================

create policy group_members_select_own_rejected
  on public.group_members
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    and status = 'rejected'
  );

-- -----------------------------------------------------------------------------------------------------
-- VERIFICACIÓN (ejecutar tras aplicar; las tres tienen que cumplirse)
--
--   1. La policy existe y su `using` nombra las dos condiciones:
--        select polname, pg_get_expr(polqual, polrelid)
--          from pg_policy p join pg_class c on c.oid = p.polrelid
--         where c.relname = 'group_members';
--      → group_members_select_own_rejected debe aparecer, con `user_id = auth.uid()` Y `status =
--        'rejected'`. Si falta la segunda, la policy deja ver TODAS tus filas de todos los grupos.
--
--   2. `is_group_member` NO cambió (es lo que mantiene cerrado el oráculo):
--        select prosrc from pg_proc where proname = 'is_group_member';
--      → sigue diciendo `status in ('active','pendingApproval')`.
--
--   3. `authenticated` sigue sin poder escribir:
--        select privilege_type from information_schema.role_table_grants
--         where table_name = 'group_members' and grantee = 'authenticated';
--      → SELECT y nada más.
-- -----------------------------------------------------------------------------------------------------
