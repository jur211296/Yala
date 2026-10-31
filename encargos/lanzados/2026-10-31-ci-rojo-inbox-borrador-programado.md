---
esfuerzo: medium
release: no
---
# 2.2 en rojo: test del borrador programado del Inbox

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `ci-rojo-inbox-borrador-programado` · Sesión cola **S30r** · al cerrar → **S32** (`eliminar-cuenta-icloud-privado`).

## Contexto
Tras mergear el PR #706, el push a 2.2 quedó en rojo: falla `InboxDismissScheduledDraftTests/payingEarlyOnTheDayOfAnOccurrenceCoveredByAnotherTransaction_advances()` en los unit tests pure-logic, incluso con reintento (run 41170656373, HEAD 0c0619d0, 23:57 hora de Lima). Otro run del mismo merge salió verde, así que puede depender de la fecha o la hora.

Cards:
- `tablero ver tablero-2-2-en-rojo-falla-el-test-del-borrador-p-y0w5`

## Qué se pide
1. Reproduce el fallo (también con la fecha y la zona del run: cerca de medianoche en Lima y en UTC) y encuentra la causa.
2. Si es el test, hazlo determinista con reloj inyectado o fechas fijas; si es el código, arregla la causa raíz con un test que lo cubra.
3. Busca otros tests del Inbox o de borradores programados con el mismo patrón de reloj real y corrígelos.
4. El mismo test rojo bloquea también el PR #707 (editar cuenta de doble línea) y puede bloquear el de formularios-modelo-borrado. Cuando tu PR mergee, haz que los PRs abiertos de 2.2 vuelvan a correr CI (rebase sobre origin/2.2 o rerun) y confirma que entran en la cola de merge.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Nada fuera del Inbox y sus tests salvo que la causa lo exija. Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿Test o código?** Test. La app ancla el pago mensual a `dayOfMonth` (31-oct → 30-nov → 31-dic), contrato ya fijado con fechas fijas en `ScheduledPaymentDoubleAdvanceTests.singleVsDoubleAdvance_monthEndClamping`. El oráculo del test encadenaba «siguiente + 1 mes» (30-nov + 1 = 30-dic). Rojo cada día 29-31 seguido de un mes más corto; no depende de la hora. Medido con un script de Calendar: 30-oct OK, 31-oct / 31-ago / 29-ene / 31-ene ROJO.
2. **¿Reloj inyectado?** No. `createAdvancedDraft` y `processDuePayments` leen `Date.now` en producción; inyectarlo toca código fuera de la causa. Se corrige el oráculo (dos meses desde la ocurrencia de hoy, que Calendar ajusta igual que la app) y el día límite queda cubierto por el caso de fechas fijas existente. Opción conservadora y reversible.
3. **Otras instancias.** Barridos los 13 ficheros de tests que tocan pagos programados/Inbox: los demás oráculos mensuales parten de la ocurrencia original (correctos); `ScheduledIdenticalDraftsTests:251` solo necesita una fecha distinta. Ninguna otra.
4. **Capturas:** no aplica (solo tests).
5. **Device-QA:** no aplica → card a done.
