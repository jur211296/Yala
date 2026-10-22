# El dueño de un grupo con deuda puede transferirlo y salir («Transferir y salir»)

## Contexto
Ticket: `tickets/backlog/groups-owner-transfer-and-leave.md` (high). Sale de la decisión de Jürgen del 2026-09-06 sobre el residual de `groups-leave-rpc-error-10`: el dueño con deuda de terceros se queda sin salida — «Salir» no aplica (es dueño) y «Eliminar» está deshabilitado por deuda del grupo.

**Decisión Jürgen (2026-09-06) — no repreguntar:** ofrecer «Transferir y salir». El RPC de transferencia ya existe en servidor; falta la hoja en iOS. «Eliminar» sigue bloqueado con deuda. No permitir eliminar con deuda.

Quien arranca: contexto limpio. Lee el ticket entero y confirma el RPC en el DDL de prod antes de UI.

## Que se pide
Implementar según el ticket y su AC:
- Dueño ve «Transferir y salir» cuando hay ≥1 otro miembro activo (y el caso con deuda de terceros deja de ser callejón sin salida).
- Flujo: elegir nuevo dueño → transferir → salir; el grupo y las deudas siguen vivos.
- «Eliminar» permanece bloqueado si hay deuda; el copy no debe pedir al dueño liquidar deudas ajenas — debe apuntar a transferir.
- Confirmar nombre/contrato del RPC de transferencia en DDL prod antes de cablear.
- Tests + gate; device-QA según AC del ticket.
- Board: mover ticket; actualizar `docs/TICKETS.md` (índice = disco).

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No revertir el bloqueo de «Eliminar» con deuda.
- No inventar otra salida de producto (borrar con deuda, etc.).
- No tocar el kill-switch / pending-member salvo residual inevitable documentado en ticket propio.

## Como se sabe que esta bien
- AC del ticket cumplidos.
- Gate verde; PR mergeado a 2.1; board + `docs/TICKETS.md` al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
