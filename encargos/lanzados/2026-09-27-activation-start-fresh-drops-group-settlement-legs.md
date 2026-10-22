# Tras «Activar Yala completo → Restaurar → Empezar desde cero», las liquidaciones de grupo vuelven a lo personal

## Contexto
Cola A autónoma Yala (riesgo real: pérdida de datos — patas de liquidación de grupo desaparecen de lo personal). Acaba de mergear a 2.1 el PR #281 (`late-notice-of-a-welcome-private-session-purges-groups-joined-later`): el aviso tardío de quien empezó en el Welcome privado ya no se lleva los grupos a los que se unió después. Base: rama `2.1` con #281.

Residual medium aparcado a propósito en el cierre de #280 (`activation-private-gate-leaves-a-late-notice-that-purges-groups`): `tickets/backlog/activation-start-fresh-drops-group-settlement-legs.md`.

Síntoma: activo Yala completo, entro en Restaurar y elijo «Empezar desde cero». Mis grupos y saldos siguen bien, pero en mis cuentas personales los cobros y pagos de grupo que ya había liquidado desaparecen: la cuenta de grupos cuenta lo que presté sin descontar lo que ya me devolvieron.

Medido en el ticket: el borrado es `.importedRows` (`DataWipeService.wipeAllUserData` borra toda `TransactionItem`, también patas con `splitSettlementID`). Después solo se pide `GroupsBridgeRestoreConvergenceStore.markPending()` (`ContentView.performICloudZoneAndImportedRowsWipe`), y esa convergencia re-puentea solo GASTOS (`settlementIDs: []`). El aviso tardío de quien activó ya re-arma las patas (`armSettlementLegsAfterLateWipe` en #280); aquí no se copió porque la sesión todavía es solo-grupos y re-puentear liquidaciones ahí puede crear la forma de solo-grupos que la convergencia posterior no sabe fundir. Hay que decidir cuándo pedirlo (¿tras `completeFullActivation`?).

Hora Lima ~13:52 domingo (diurno 06:00–21:00). Norma Jürgen 22-sep / 24-sep: tú eliges la opción robusta / good-practice (la Recommended del AskUserQuestion) y sigues sin preguntar a Jürgen por producto/techos/copy. Solo paras si hace falta su device, secretos o acceso. De 06:00–21:00 Lima sí puedes AskUserQuestion de producto/acceso real; para elecciones de producto elige robusto/Recommended sin preguntar a Jürgen salvo device/secretos/demasiado consecuente.

MODO AUTÓNOMO — override explícito: la regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa hasta gate/PR/merge/`/cerrar-total` sin pedir continuar. Solo AskUserQuestion real de producto/acceso en horario 06:00–21:00 Lima; fuera de eso elige la opción recomendada o aparca en ticket si es demasiado importante.

## Que se pide
Cierra el ticket `activation-start-fresh-drops-group-settlement-legs`:
1. Tras «Empezar desde cero» dentro de la activación (Restaurar), las liquidaciones confirmadas vuelven a lo personal.
2. Ninguna liquidación sale dos veces.
3. Decisión robusta del «cuándo»: el ticket sugiere tras `completeFullActivation` para no crear la forma solo-grupos a medias. Elige Recommended / good-practice, mide, documenta por qué. Reutiliza el mecanismo de #280 (`armSettlementLegsAfterLateWipe` o el equivalente correcto) si aplica; no inventes un segundo camino paralelo si uno basta.
4. Tests que fijen: wipe `.importedRows` de activación → patas de liquidación reaparecen en lo personal; no hay duplicados.
5. Board al día: ticket a qa o done según criterio del repo; hallazgos nuevos → ticket propio en backlog antes de cerrar; actualiza `docs/TICKETS.md`.
6. Cierra con `/cerrar-total` (worktree de `lanzar-sesion`).

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- No paralelizar otro modelo semántico ni otro encargo Cola A
- No inventar alcance: residuals low de #281 (`groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start` y hermanos) y el medium `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud` son otros tickets; no los metas en este PR salvo que el mismo cambio los cubra de verdad y lo documentes
- Device-QA opcional: no bloquees el merge esperando iPhone

## Como se sabe que esta bien
- Criterios de aceptación del ticket en verde (tests + lectura del camino activación → Restaurar → Empezar desde cero → convergencia / re-arm de patas)
- PR mergeado a 2.1
- Board y `docs/TICKETS.md` coherentes
- `/cerrar-total` limpio

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿Cuándo se re-puentean las liquidaciones?** En la convergencia (`GroupsBridgeRestoreConvergence.convergeIfPending`),
   que ya espera a la sesión privada y es durable. No «tras `completeFullActivation`» a mano (un corte entre el eje y ese
   paso dejaría la petición sin consumidor), ni armando `GroupsPendingBridgeIntent` al borrar (su retome no espera a la
   sesión privada: en solo-grupos crea la pata sin borrador y la da por atendida).
2. **¿Un camino o dos?** Uno: el aviso tardío (#280) deja de armar la intención y pide lo mismo que «Empezar desde cero».
3. **¿Qué liquidaciones?** Las confirmadas que se quedaron SIN NINGUNA pata. Cualquier pata indica que alguien la
   re-puenteó después del borrado; re-puentearla otra vez duplicaría el borrador de un pago ya aprobado (la aprobación
   crea la transacción real sin `splitSettlementID`, `DraftService` D7). Hallazgo de la review, corrige el criterio
   inicial «sin pata real».
4. **Tests**: comportamiento con el bridge real y el borrado real (aislado con `.wipeAppGroupMirrorIsolated`) + scans.
5. **Ticket a `qa`** con guion opcional de iPhone; hallazgos fuera de alcance a backlog.
