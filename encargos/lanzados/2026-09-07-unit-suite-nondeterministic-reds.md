# YalaTests completa da rojos DISTINTOS en cada corrida (todos pasan aislados)

## Contexto
Ticket: `tickets/backlog/unit-suite-nondeterministic-reds.md` (high).

El gate se apoya en esta suite; los rojos bailan y pasan aislados. Hipótesis fuertes: source-scans bajo carga de disco/FS; no orden global (CI limpio pasa entero). Medir con disk-report antes.

Cola high autónoma (Frank): tras /cerrar-total → rojo-xcuitest-runner-muere-tras-el-primer-caso → (web DNS prep; dead-end owner espera decisión Jürgen).

## Que se pide
AC del ticket: causa con evidencia; suite completa estable en dos corridas; flaky residual → Lista Negra con owner/deadline. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No declarar «preexistente» sin evidencia.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1 (o cierre honesto si es solo infra/documentación de causa); board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
