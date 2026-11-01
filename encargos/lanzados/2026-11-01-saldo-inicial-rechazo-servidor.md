---
esfuerzo: high
release: no
---
# Cuando el servidor rechaza un saldo inicial, descartarlo en el teléfono y no apagar la verificación del grupo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `saldo-inicial-rechazo-servidor` · Sesión cola **S35j** · al cerrar → **S36** (`barrido-qa-2-2-b`).

## Contexto
Hallazgo del cierre de `saldos-iniciales-servidor-admins` (PR #716). Ahora el servidor rechaza saldos iniciales de quien no es dueño ni admin, o de grupos congelados o con pago confirmado. Pero el teléfono sigue guardando localmente el saldo rechazado y deja de verificar ese grupo.

Cards:
- `tablero ver tablero-un-saldo-inicial-que-el-servidor-rechaza-e6fd`

## Qué se pide
1. Reproduce el caso: un miembro normal (o un grupo congelado) intenta guardar un saldo inicial, y el servidor lo rechaza.
2. Ante un rechazo de permisos del servidor, revierte o descarta el cambio local (no lo dejes pendiente ni reintentes sin fin) y muestra un mensaje claro en español neutro.
3. La verificación y la sincronización del grupo siguen activas después del rechazo; un error de un registro no puede apagar la verificación del grupo entero.
4. Distingue el rechazo por permisos (definitivo) de los errores de red (reintentables).
5. Agrega tests unitarios del flujo de rechazo y un XCUITest si aplica. Deja capturas antes y después en `capturas/`.

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Al abrir el PR, pasa las cards a «in qa» de Jürgen (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Las políticas ni las RPC de Supabase, que ya quedaron en PR #716.
- La lógica de migración y congelado.
- marketing/ ni Web/.
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Un saldo rechazado no queda en el teléfono.
- Se ve un mensaje claro.
- El grupo sigue verificándose y sincronizando.
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0

Medido en el árbol (`origin/2.2`, d1dd356):

- Hoy un rechazo `upstream_400:yala_opening_balance_{not_admin,locked,group_closed}` deja la fila de outbox en dead-letter
  para siempre (`GroupsSyncClient.applyResults`), el Merkle del grupo se salta mientras exista (`verifyGroupIntegrity`,
  guard 2) y el teléfono conserva su versión: el apply del pull pisa sin LWW, pero el servidor no vuelve a mandar una
  fila que no cambió.
- 5xx/429 ya son pasajeros (la fila sigue pendiente) y un fallo de red no trae resultados: el reintento ya existe. Lo
  definitivo son los tres códigos; `yala_not_authorized` sigue con su re-drive al aprobar al miembro.

Decisiones (autónomo; la opción más reversible y de menor alcance):

1. **Dónde.** Un paso nuevo del ciclo, `settleRejectedOpeningBalances`, entre el push y el pull. `applyResults` no
   cambia: sigue marcando el dead-letter y dejando el aviso. El paso lee esas dead-letters por su motivo, así que cura
   también las que ya dejó un 2.1 en el teléfono (el trigger g27_01 está en producción).
2. **Qué hace.** En un `saveWithAuthor` (el drain no lo captura y no vuelve a subir nada): borra la fila de outbox,
   borra la copia local del gasto o reparto rechazado (si el servidor lo tiene, vuelve con el re-pull; si era nuevo, no
   vuelve) y pone a 0 el cursor de ESE grupo. Tras el save, des-puentea los gastos borrados; el re-pull los vuelve a
   puentear si existen. Save fallido ⇒ `rollback()` (molde del apply): un borrado sucio en el contexto compartido lo
   capturaría el drain y subiría un tombstone.
3. **Cursor a 0.** La regla del cursor prohíbe el reset EXTERNO por una página en vuelo y por «Empezar de cero». Aquí
   corre síncrono entre el push y el pull del mismo ciclo (igual que la subida de versión de u8cl) y solo sobre grupos
   con una fila de outbox de esta sesión. Los avisos de «gasto modificado» de ese re-pull se callan con el mismo
   conjunto de u8cl (`capabilityRepullZones`).
4. **Solo filas de la sesión** (`GroupsOutboxOwnershipLogic.isUploadable`): una dead-letter de otra cuenta no se toca.
5. **Merkle.** Sin dead-letter, el grupo vuelve a verificarse. No se toca el guard: una dead-letter de otro código sigue
   saltándolo, como antes.
6. **Aviso.** Se conserva (título y motivo de 6n1o); la última frase pasa de «Los demás miembros no verán este cambio»
   a decir que el saldo volvió a como está en el grupo, en los 16 idiomas. **Sale al descartar, no al rechazar** (cambio
   tras la review): solo es verdad tras el save del descarte, y así avisa también de lo que descarta de una versión
   anterior.
7. **Fuera:** políticas/RPC (PR #716), migración y congelado, marketing/ y Web/. La inferencia sin medir de la card (zona
   migrada que resuelve «yo» por una fila heredada con admin) va a una card propia.

### Tras la review adversarial (dos lentes: sync/pérdida de datos y tests)

- **Corregido:** el re-pull desde 0 pisaba una edición de OTRO gasto del grupo que siguiera en el History sin drenar (la
  edita la persona mientras el push vuela). El descarte vuelve a drenar pegado al reset, y un grupo con algo vivo en el
  outbox espera al ciclo siguiente (rastro `openingBalanceRejectionDeferred`).
- **Corregido:** el aviso salía aunque el descarte fallara, y no salía por las dead-letters de 2.1. Ahora sale tras el save.
- **Tests endurecidos:** el puente del saldo (su movimiento en la cuenta virtual) se va y vuelve con el rollback; el stub
  del ciclo solo baja la fila pedida desde 0; fuera el test del prefijo (lo cubre el ciclo).
- **Card nueva:** los repartos de un saldo NUEVO rechazado quedan huérfanos en servidor y teléfono (el trigger no juzga
  un reparto sin gasto). No cambian ningún saldo. `tablero-los-repartos-de-un-saldo-inicial-nuevo-q-m76a`.
- **Residuales aceptados:** si el pull falla tras el descarte, el saldo editado no se ve hasta el siguiente pull completo;
  un tombstone rechazado puede re-emitirse si el drain relee el History (sin token o con token incomparable) y vuelve a
  rechazarse y descartarse, acotado a esa ventana.
