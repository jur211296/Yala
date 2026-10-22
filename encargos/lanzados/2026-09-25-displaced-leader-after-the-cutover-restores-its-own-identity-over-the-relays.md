# El líder desplazado tras el cutover no debe devolverse su identidad sobre la del relevo (ni duplicar)

## Contexto
Cola A autónoma (mediums del callejón nube). Acaba de mergearse #244 (`relay-row-rekeyed-then-deleted-tombstones-the-leader-identity`): los borrados de filas re-identificadas ya salen con las dos identidades. Residual de esa review (lente de pérdida de datos): ticket `tickets/backlog/displaced-leader-after-the-cutover-restores-its-own-identity-over-the-relays.md`.

Caso de usuario: el primer teléfono activa la nube, llega al último paso y se queda sin red; el segundo toma el relevo y termina; cuando el primero vuelve, entra como uno más. Si iCloud le había traído las identidades del relevo, `restoreRelayIdentities` (#243) en el reconcile de `done` del líder desplazado (delante de `resolvePostCutoverLease`) puede devolver a las filas vivas la identidad que ESE teléfono acuñó. Las salidas `finishedHere` / `finishedElsewhere` se unen sin el linaje del adopt, así que nada las re-identifica después. Inferido: el sync normal subiría esas filas como nuevas → duplicados. Los borrados ya están cubiertos por #244.

ARRANCAS EN CONTEXTO LIMPIO. Lee el ticket, #243/#244 y el código de `restoreRelayIdentities` / reconcile post-cutover antes de tocar nada.

## Que se pide
1. Mueve el ticket a `in-progress` y actualiza `docs/TICKETS.md` al empezar.
2. Cierra el hueco: la restauración de identidades del relevo NO debe correr en el líder desplazado tras el cutover de forma que pise las identidades del relevo legítimo. El criterio del ticket: decidir (y aplicar) si la restauración corre solo en quien conserva el lease, o solo antes de perderlo — medido contra el caso del relevo legítimo, que SÍ la necesita.
3. Opción robusta ya elegida (noche / Frank): preferir «solo quien conserva el lease» (o equivalente que preserve el relevo y bloquee al desplazado post-cutover). No la opción más simple si deja un fail-open.
4. Cobertura: test(s) que fallen antes y pasen después; mutantes del tramo si aplica al patrón del callejón.
5. Gate verde; PR a `2.1`; merge; board a `done` (sin device-QA salvo que el fix solo se pueda ver en iPhone — entonces `qa` y dilo en el aviso); `docs/TICKETS.md` al día; `/cerrar-total`.
6. Bugs/decisiones nuevas de camino → ticket propio en backlog antes de cerrar (no solo en ESTADO).

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corres el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo: implementa hasta el cierre. Solo para ante decisión/acceso real de Jürgen (device, secretos, irreversible). Son las ~03:08 Lima (nocturno): elige la opción recomendada/robusta sin AskUserQuestion; si es demasiado grave para asumir, aplaza en ticket propio y cierra lo demás.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Que NO hay que tocar
- `marketing/` ni Web/.
- No reabrir el diseño de #244 (tombstones duales) salvo que el fix lo exija de forma medible.
- No device-QA a Jürgen salvo que el cierre sea imposible de demostrar sin iPhone.

## Como se sabe que esta bien
- El líder desplazado post-cutover no pisa las identidades del relevo ni sube filas vivas como nuevas por ese camino.
- El relevo legítimo sigue pudiendo restaurar las identidades que necesita.
- Ticket en `done` (o `qa` justificado), índice al día, PR mergeado a `2.1`, `/cerrar-total` limpio.

## Paso 0

Decisiones de la sesión nocturna, sin Jürgen delante: auto-contestadas y revisadas tras la review adversarial.

1. **Primera decisión, retirada:** mover la restauración detrás de `resolvePostCutoverLease` y correrla solo en `.leads` /
   `.finishedHere`. Se implementó con dos tests. Los tests mataron 6 mutantes, incluido el código de antes.
2. **La review la tumbó, y lo medí:**
   - el runtime arranca con el reconcile pendiente, porque `canRunDomain` no mira los efectos pendientes;
   - detrás de la petición de red, su pull duplicaba en el relevo legítimo, que con g16_04 es el caso principal.
3. **La premisa del ticket es falsa (medido).** Al reconcile de `done` solo llega quien pasó su cutover, y al cutover solo
   se entra con la verificación en `.match`, cuya hoja del Merkle lleva el `sync_id`. El backend ya tiene la identidad
   que se restaura. Además, desde g16_04 el caso solo llega con la cuenta volviendo a iCloud.
4. **Decisión final:** el ticket va a `discarded` y el código queda igual. Se añaden:
   - el porqué, escrito en el efecto y en el docblock;
   - un test que fija la restauración antes de la primera petición de red, en las cinco respuestas del lease;
   - la regla corregida;
   - el hallazgo del runtime, anotado en `cloud-engine-can-start-with-a-reverse-abort-pending` (ya existía; no hay
     ticket nuevo).
5. **Descartado también:** el ticket que abrí para `startParallelHistoryCapture`. Su premisa cae por lo mismo, así que no
   llegó a commitearse.
6. **Device-QA:** no hace falta, no hay cambio de comportamiento.
