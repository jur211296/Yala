---
esfuerzo: high
release: no
---
# Endurecer en Supabase (RLS, políticas y RPC) para que solo el dueño y los admins activos escriban saldos iniciales del grupo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `saldos-iniciales-servidor-admins` · Sesión cola **S35i** · al cerrar → **S35b** (`sheets-detent-glass`).

## Contexto
Jürgen (31-oct 12:38): «Endurece en el servidor».
Tras `grupos-admin-saldo-inicial` (PR #714), el servidor Supabase deja escribir saldos iniciales de grupo a cualquier miembro activo, y solo la app decide quién es admin.

Cards:
- `tablero ver tablero-el-servidor-solo-deja-al-dueno-y-a-los-a-6n1o`

## Qué se pide
1. Revisa las políticas RLS y las RPC que tocan los saldos iniciales de grupo. Insertar, editar y borrar debe exigir rol dueño o admin activo del grupo. También debe rechazarse si el grupo está congelado (migrado) o si aplica el bloqueo por pago confirmado.
2. Escribe una migración versionada y reversible. Deja en el PR el script de reversión.
3. Agrega tests de políticas: miembro normal rechazado, admin aceptado, dueño aceptado, ex-miembro rechazado, grupo congelado rechazado y pago confirmado rechazado.
4. Aplica **primero en staging** y prueba con un miembro normal (rechazo) y un admin (OK).
5. Comprueba que las versiones de la app en producción, **1.0 y 2.1** (donde solo el dueño edita), siguen funcionando con las nuevas políticas.
6. Después aplica la migración en **producción** y verifica con las mismas pruebas.
7. En la app, si el servidor rechaza, muestra un mensaje de error claro y en español neutro, no un error genérico.

Si algo de producción sale mal, revierte la migración en producción, verifica que quedó como antes y deja la card en **blocked** explicando qué pasó. No reintentes.

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Al abrir el PR, pasa las cards a «in qa» de Jürgen (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Otras tablas ni políticas que no sean las de los saldos iniciales.
- La lógica de migración y congelado.
- marketing/ ni Web/.
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Las políticas y las RPC exigen dueño o admin activo, y los tests están verdes.
- Staging y producción están verificados.
- 1.0 y 2.1 siguen funcionando.
- La app muestra un error claro cuando el servidor rechaza.
- Se hizo una review adversarial del diff y de la migración.
- El PR va a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0

Medido el 2026-10-31 por Management API en staging (`fostjbbwstyuunmmefuk`) y producción (`kefvaiymtgytemwbltlz`):
políticas de `split_expenses`/`split_shares` idénticas en los dos (`is_group_writer` en select/insert/update),
`apply_group_delta` SECURITY INVOKER con el mismo md5 `61c38595…`, y ningún otro escritor de esas tablas salvo
`g7_recrypt_corpus` (DEFINER). El servidor no conoce «congelado»: no hay columna, y la copia congelada vive en
CloudKit, así que sus escrituras no llegan a Supabase.

| Decisión | Elegido | Por qué |
|---|---|---|
| Dónde se exige | Trigger `BEFORE INSERT OR UPDATE` en `split_expenses` y `split_shares`, no políticas RLS nuevas | Un `UPDATE` que la RLS filtra devuelve 0 filas: `apply_group_delta` contesta `noop not_authorized_or_gone`, la app lo PURGA y el cambio se pierde sin aviso. El trigger lanza un código propio que llega a la app (punto 7). Alcanza también al PATCH directo de PostgREST. Las políticas existentes no se tocan |
| Quién gestiona | Miembro activo (`is_group_writer`) **y** (`owner_user_id = auth.uid()` **o** `is_group_admin`) | Espejo de `OpeningBalancePermissionLogic`: el dueño conserva el permiso aunque su rol no diga admin (grupos migrados) |
| Qué fila es «saldo inicial» | Gasto con `is_opening_balance` en OLD o NEW; reparto cuyo gasto (OLD o NEW `expense_id`) es saldo inicial en el servidor | Cubre convertir un gasto normal en saldo inicial y al revés, y mover un reparto de uno a otro. Un reparto cuyo gasto aún no llegó no se juzga: sin el gasto no hay saldo |
| «Congelado» en el servidor | Grupo sin fila o con `split_groups.deleted = true` | Es lo único «cerrado» que el servidor tiene. Archivado NO: la app deja escribir en grupos archivados |
| Bloqueo por pago confirmado | Editar o borrar un saldo inicial VIVO (gasto o reparto) si una liquidación confirmada y viva toca a la arista que el saldo YA TIENE en el servidor (acreedor guardado, deudores vivos, el miembro de antes del reparto). Un reparto que cambia de gasto juzga los dos. Crear no se bloquea; el primer reparto tampoco | Espejo de `confirmedSettlementsBlock`. La arista de antes (y no la nueva) es lo que hace que los deltas de una misma edición salgan juntos: con la nueva, una carrera dejaba un saldo a medias (review adversarial) |
| Quién queda fuera del candado | Solo `current_user = authenticated` | `g7_recrypt_corpus` y las migraciones corren como dueño |
| Códigos | `yala_opening_balance_not_admin` · `yala_opening_balance_locked` · `yala_opening_balance_group_closed` | El gateway los deja pasar (`^yala_[a-z_]+$`) y la app los guarda en el dead-letter |
| App | Alerta en el detalle del grupo con el motivo, en español neutro, cuando una subida vuelve con uno de esos códigos | No hay ninguna superficie hoy para un rechazo del servidor en Grupos |
| Producción | Mismas pruebas dentro de una transacción con `ROLLBACK` (datos sintéticos, sin columnas cifradas → sin llave de prod) | No hay usuarios de prueba en prod y no se deja residuo |

Residual asumido: en una carrera (alguien confirma un pago que el editor aún no vio) mover un saldo HACIA esa persona
entra entero; y si el cambio de acreedor llega antes que los repartos, esos repartos se rechazan. Fuera de la carrera la app
ya lo bloquea antes de subir. Un reenvío de un borrado ya aplicado no se juzga (rechazarlo era un falso positivo).
