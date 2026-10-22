# Si el dispositivo que vació no llega a reponer, lo que prometió reponer no vuelve: arreglarlo

## Contexto
Cola A (tickets de cloud/sync con riesgo real para el usuario, una sesión a la vez). El PR #290 (`a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`, mergeado a 2.1) hizo que, tras «Vaciar datos» en un dispositivo sin Grupos, los demás no pierdan los gastos y liquidaciones de grupo: el dispositivo que vació «promete» reponer su parte y los receptores la excluyen. Residual encontrado ahí: `tickets/backlog/wipe-division-exclusion-trusts-the-origin-to-converge.md` (medium). Si el origen no vuelve a abrirse o no llega a reponer, lo prometido no vuelve nunca: el usuario se queda sin gastos de grupo. Lee el ticket, el PR #290 y su ticket (ahora en qa) antes de tocar nada.

## Que se pide
- Reproducir con test el caso: origen que promete y nunca repone; hoy los receptores no recuperan esas filas.
- Arreglo robusto: que lo prometido acabe volviendo aunque el origen no converja (por ejemplo, un techo tras el que el receptor deja de confiar en la promesa y repone él, sin duplicar cuando el origen sí reponga tarde). Elige la opción robusta y de buena práctica; no preguntes por detalles de producto.
- Tests unitarios/integración que fijen: origen que nunca repone, origen que repone tarde (sin copias dobles), origen que repone a tiempo (sin cambio).

## Que NO hay que tocar
- No cambiar el comportamiento ya fijado por #287, #289 y #290 salvo lo necesario para este caso.
- Nada de la UI ni del carril adaptativo iPad (otra sesión trabaja en paralelo en `iphone-large-text-sizes-break-layouts`).
- Simuladores: NO uses los que empiezan por `YalaLane-Adapt-` (son del carril adaptativo). Nada de `simctl shutdown all`, `erase all` ni `killall Simulator`.
- Los otros residuales de #290 (low) quedan en backlog; no los metas aquí.

## Como se sabe que esta bien
- Tests nuevos en verde y gate verde; UI tests del CI son advisory (patrón flaky ya documentado en 2.1, contrasta con la base).
- PR contra 2.1 mergeado; ticket movido a qa con guion corto de device-QA con dos dispositivos si hace falta, o a done si los tests lo cubren; `docs/TICKETS.md` al día.
- Residuales o decisiones nuevas → ticket propio en `tickets/` antes de cerrar.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. Es horario diurno: puedes usar AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR o dejaste preview/artifact listo; (3) terminaste el ticket y vas a /cerrar-total, con un resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo y no tienes siguiente paso claro, una vez y no en bucle. NO avises por un test rojo que vas a reclasificar, un build que vas a reintentar ni ruido de CI advisory.

## Paso 0

Decisiones tomadas antes de escribir código (MODO AUTÓNOMO: auto-contestadas con la opción recomendada).

1. **Quién repone lo que el origen prometió y no llegó: el receptor, pasado un techo.** Al resolver el reparto
   (`GroupsRemoteWipeDivision.resolveIfArrived`), el receptor apunta en local la **promesa**: los ids que excluyó y desde
   cuándo confía. Cada arranque, detrás de los gates de la convergencia y justo después de ella, la revisa.
2. **«Ya llegó» = hay aquí alguna fila de ese id POSTERIOR a la señal** (una transacción o un borrador con su
   `splitExpenseID` / `splitSettlementID`; una anterior la sube tarde un tercer dispositivo y su corte se la llevará). El corte del receptor se llevó todo lo anterior a la señal y su convergencia excluye esos ids, así
   que una fila presente la trajo el espejo desde el origen (o el sync de grupos la re-puenteó entera). Lo que llega sale de
   la promesa para siempre.
3. **Techo: 72 horas desde el arranque que resuelve el reparto** (reloj local). La primera versión contaba desde que se
   empezó a esperar (`Awaiting.since`) y la review la tumbó: un reparto tardío daba la promesa por vencida en el mismo
   arranque que la apuntaba.
   La convergencia del origen corre en su siguiente arranque en frío, que suele ser en horas; tres días lo cubren sin dejar
   a la persona una semana sin sus gastos de grupo. Pasado el techo, el receptor re-puentea lo prometido que siga faltando
   y que tenga en local (liquidaciones: confirmadas y fuera de grupos ocultos, los filtros de la convergencia), y suelta la
   promesa. Lo no atendido va a `GroupsPendingBridgeIntent` con canal `.backend`, como en la convergencia.
4. **Sin copias dobles cuando el origen repone tarde:**
   - antes del techo, o después pero antes de que el receptor arranque: sus filas ya están aquí → no se re-puentea;
   - después de que el receptor repusiera: el origen converge detrás de la quiescencia del import, con las filas del
     receptor ya bajadas, y `bridgeExpense`/`bridgeSettlement` concilian por id (conservan la real, rehacen la virtual y
     sus borradores). Queda el residual de siempre —los dos puentean antes de cruzarse por el espejo—, que el siguiente
     re-puente concilia. **No** se añade una nota «me hice cargo» en el iCloud-KV: más superficie en la cuota
     (`wipe-division-kv-key-has-no-quota-ceiling`) para cerrar una ventana de segundos.
5. **Mientras se espera el reparto de una señal más nueva, la promesa vieja no se toca**: el reparto nuevo decide, y al
   resolverse **sustituye** la promesa (como la exclusión). Vacía, la retira.
6. **El relevo de persona retira la promesa**, junto a la espera (`removeGroupsDomainPreferenceKeys`). Prefijo
   `fullModeActivation.*`: sobrevive al reset de preferencias del borrado.
7. **Lo que no cambia:** `markPending()`, `markPending(excluding:)`, el orden tardío, el reparto del origen y el mecanismo
   de declaraciones. Nada de UI.
8. **Tests:** repro primero (el caso del ticket en rojo con la función vacía), luego origen que nunca repone, que repone
   tarde antes y después del techo, que repone a tiempo, parcial, y el scan de cableado en `retryPendingBridges`.
   Review adversarial (sync/grupos): toca sync de grupos y dinero.
