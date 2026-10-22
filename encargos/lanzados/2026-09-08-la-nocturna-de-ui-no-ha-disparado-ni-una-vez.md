# La nocturna de UI no ha disparado ni una vez (cron)

## Contexto
Ticket: `tickets/backlog/la-nocturna-de-ui-no-ha-disparado-ni-una-vez.md` (medium).

Tras verificar en prod el timeout del CI: los topes aguantan, pero cero runs `event: schedule` — la nocturna de UI (cron 17 8 * * *) no ha sonado. A mano (workflow_dispatch) sí funciona.

Cola autónoma (Frank): highs de código hechos; dead-end owner y DNS web esperan a Jürgen. Tras /cerrar-total seguir con mediums del board.

## Que se pide
Identificar por qué el cron no dispara y arreglarlo (o documentar causa+mitigación con evidencia). Board + `docs/TICKETS.md` al día. Criterio del ticket.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No reabrir el timeout de build+unit ya mergeado en #93 salvo colisión.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`. Idealmente evidencia de un schedule run (o ventana de mañana 03:17 documentada).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
