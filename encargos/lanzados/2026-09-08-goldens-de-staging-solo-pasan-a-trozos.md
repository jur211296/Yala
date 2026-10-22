# Los 25 goldens de staging dan ~15/25: timeouts, cero aserciones — causa sin encontrar

## Contexto
Ticket: `tickets/backlog/goldens-de-staging-solo-pasan-a-trozos.md` (medium).
Cola mediums (Jürgen 2026-09-08): tras vaciar high. Orden: este → familia chat ×3 → FX ×3.

Estado previo: 14-15/25 en tres corridas; todos los fallos son timeouts; cuatro hipótesis caídas. Siguiente medición escrita en el ticket: instrumentar `pull()` y contar viajes. Sospechoso: 677 grupos acumulados de `jwtA`.

## Que se pide
AC del ticket: encontrar la causa real, arreglarla o dejar medición + ticket hijo si el fix no cabe aquí. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Cola siguiente (no la lances tú)
Tras /cerrar-total Frank lanza: `chat-draft-sign-can-contradict-its-subcategory`.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.

## Como se sabe que esta bien
- Causa encontrada y AC del ticket; o medición + tickets hijos claros. PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
