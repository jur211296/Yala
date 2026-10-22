# La cola del reparador no tiene salida para filas de tasas parciales

## Contexto
Ticket: `tickets/backlog/repair-queue-has-no-exit-for-partial-rate-rows.md` (high).
Nace de la review de fx-manual-writes (#94): el reparador pregunta si existe la *fila* de tasas, no si trae la *divisa*, así que recorre transacciones provisionales en cada arranque sin poder curarlas.

Cola high/medium autónoma (Frank): tras /cerrar-total → mediums recientes (tests-sqlite / panel tasas / groups-stats / …). `groups-owner-debt-no-heir-dead-end` y `diez-worktrees-comparten-un-simulador` esperan decisión Jürgen. DNS web sigue blocked a su acceso.

## Que se pide
Implementar según ticket + AC: salida honesta para el caso partial-rate-rows (no spin infinito en arranque). Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No revertir fx-manual-writes salvo que el ticket lo pida explícitamente.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
