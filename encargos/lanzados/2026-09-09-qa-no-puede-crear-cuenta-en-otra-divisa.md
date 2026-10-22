# No se puede crear una cuenta en otra divisa (bloquea Device-QA FX)

## Contexto
Ticket: buscar `qa-no-puede-crear-cuenta-en-otra-divisa` en `tickets/` (high).
Hallazgo del barrido QA (#109): bloquea ~4 tickets de FX que no necesitan teléfono físico — solo una cuenta en otra divisa en simulador/seeds.

## Que se pide
AC del ticket: que se pueda crear (o seed-ear) una cuenta en otra divisa para QA/simulador. Board + `docs/TICKETS.md` al día. Desbloquear los FX que dependían de esto.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.

## Como se sabe que esta bien
- AC del ticket; se puede crear/seed cuenta en otra divisa; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
