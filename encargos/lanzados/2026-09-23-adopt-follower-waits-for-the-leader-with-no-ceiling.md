# Si entras en tu cuenta mientras otro teléfono la activa, la espera ya no se queda sin fin

## Contexto
Cola A autónoma (Frank). Acaba de mergear #227 (`reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`) a 2.1: un fallo de iCloud de una pasada ya no cancela la vuelta cobrando horas de espera ajenas. Ticket a done sin device-QA.

Siguiente: `adopt-follower-waits-for-the-leader-with-no-ceiling` (medium, modo-nube/migración/adopt). Sale del Paso 0 de `adopt-claim-stays-parked-with-no-ceiling` (#221): la fase `waitingForLeader` no está en `ForwardStepPhase`, así que el techo y el «Cancelar» del claim no la cubren. Con sesión borrada o 403 persistente el seguidor se queda para siempre en «esperando a otro dispositivo». Además, si cancelas el claim y el servidor contesta `claiming_in_progress`, aterrizas en esa espera y pierdes el «sí» de cancelar.

Horario Lima diurno (antes de 21:00): usa AskUserQuestion para las decisiones de producto del ticket. Recomendación robusta (no la más simple) si hace falta anclar opciones:
1) Techo: fallos definitivos (sesión borrada / 403 / cuenta no disponible) salen pronto o al instante con texto por motivo, alineado con el claim del adopt; mientras el líder trabaja de verdad, el plazo largo es el de red/stall (72 h), no el corto de «no avanza el paso».
2) «Cancelar la activación» sí en `waitingForLeader`, con la misma salida de marca `adoptClaimExitRaw` (vuelve a «Activar la nube en este dispositivo»), y que recupere el «sí» perdido tras `claiming_in_progress`.

## Que se pide
Implementar el ticket `adopt-follower-waits-for-the-leader-with-no-ceiling` según las decisiones de producto (AskUserQuestion). Criterios del ticket: un seguidor con sesión borrada o 403 persistente no se queda en `waitingForLeader` para siempre; test con fallo persistente midiendo el cambio de fase. Cubrir también el «Cancelar» que se pierde al pasar de claim → `waitingForLeader` si la decisión lo incluye.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge a 2.1 y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. La regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda suspendida en este encargo: implementa hasta el cierre sin pedir permiso para continuar. Solo para ante decisión/acceso real (AskUserQuestion de día). Board: create/move directo.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR o dejaste preview/artifact listo; (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle. NO avises por: test rojo que vas a reclasificar, build que vas a reintentar, ni ruido de CI advisory.

## Que NO hay que tocar
- `marketing/` ni Web/ (Lola).
- No reabrir `adopt-claim-stays-parked-with-no-ceiling` ni el techo de reverse-upload de #227 salvo colateral medido → ticket nuevo.
- No inventar device-QA si el escenario no se monta a voluntad; si no hace falta QA manual, a `done` con la nota habitual.

## Como se sabe que esta bien
- Criterios del ticket cumplidos y medidos con test.
- Gate verde; review + mutantes al criterio del repo.
- Ticket a `done` o `qa` según toque; `docs/TICKETS.md` al día; PR mergeado a 2.1; `/cerrar-total`.

## Paso 0 — decisiones (2026-09-23, 20:05 Lima)

Producto, contestado por Jürgen con AskUserQuestion (las dos recomendaciones):

1. **Techo como el del 22 %.** Sesión borrada por el SDK o 403: 15 min ACUMULADOS y sale con su texto. Sin respuesta
   útil del servidor (red, 401 con la sesión guardada): 72 h. **Cada `claiming_in_progress` es avance**: prueba que el
   líder tiene el lease vivo, así que reinicia los dos relojes; un líder vivo con mucho corpus nunca echa al seguidor.
   La tarjeta de espera avisa del 403 o de la sesión borrada en cuanto lo ve (el mismo aviso del 22 %).
2. **«Cancelar la activación» también en `waitingForLeader`**, con el diálogo del adopt y la marca `adoptClaimExitRaw`.
   Recupera el «sí» que hoy se pierde al pasar de claim a `waitingForLeader`.

Técnico, asumido (default sensato, sin preguntar):

- **Mecanismo**: `waitingForLeader` entra en `ForwardStepPhase` (raw `waitingForLeader`, valor nuevo del canario
  `cloudForwardStepWaiting`/`cloudForwardStepAborted`), usa `observeForwardStepStall` y los cuatro `forwardStepStall*`.
  Sin campo nuevo en `MigrationState`: no hay schema bump.
- **El avance se sella en dos sitios**: al ENTRAR en la fase (el claim que la produce contestó `claiming_in_progress`) y
  en cada poll que vuelve a contestarlo.
- **Salida = la del claim del adopt**: `failedRollback` con `[.rollback]`, `AdoptClaimExit(reason)`, textos existentes
  (`storage.failed.adopt*`, `storage.progress.adopt*`, `storage.confirm.cancelAdoptBody`). Sin claves nuevas de l10n.
- **`AdoptClaimScope.isAdoptClaim` pasa a cubrir `waitingForLeader`** (con la intención de adoptar, como el claim): un solo
  predicado para la marca, el cuerpo del diálogo y el aviso.
- **El Welcome no cambia**: ya pinta `.failed` con su «Reintentar»; su «Cancelar» es de
  `welcome-adopt-effect-failure-has-no-reason-and-no-cancel`.
- **Device-QA**: el escenario pide dos iPhone y un líder parado a media activación; no se monta a voluntad ⇒ `done`
  con la nota habitual si los tests lo cubren.
- Review adversarial: sí (sync/migración). Mutantes sobre los términos nuevos.
